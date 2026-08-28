// The browser and the one-shot resolver, driven from Dart.
//
// See `worker_io.dart` for why there are two isolates behind a running
// browser, and why the two one-shot calls go to a throwaway one.

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'mdns_event.dart';
import 'service.dart';
import 'status.dart';
import 'worker_io.dart';

/// What came back from an attempt to browse.
class MdnsBrowserStart {
  const MdnsBrowserStart._(this.status, this.browser, this.detail);

  /// What happened.
  final RkMdnsStatus status;

  /// Non-null exactly when [status] is [RkMdnsStatus.ok].
  final MdnsBrowser? browser;

  /// One line for a log.
  final String? detail;

  /// Whether the browser is running.
  bool get isOk => status == RkMdnsStatus.ok;

  @override
  String toString() =>
      'MdnsBrowserStart(${status.name}${detail == null ? '' : ', $detail'})';
}

/// A running browse.
class MdnsBrowser {
  MdnsBrowser._(this._commands, this._pollIsolate, this._events);

  final CommandChannel _commands;
  final Isolate _pollIsolate;
  final Stream<BrowserEvent> _events;

  bool _stopped = false;

  /// Services appearing, resolving and going away.
  ///
  /// A [ServiceLost] is the half a stream of answers cannot give: without a
  /// cache and its lifetimes there is no way to tell a service that stopped
  /// answering from a datagram that got lost.
  Stream<BrowserEvent> get events => _events;

  /// Starts browsing. Never throws.
  static Future<MdnsBrowserStart> start(
    BrowseRequest request, {
    List<String>? candidatePaths,
  }) async {
    final commands = await CommandChannel.spawn(candidatePaths);
    if (commands == null) {
      return const MdnsBrowserStart._(
        RkMdnsStatus.unsupported,
        null,
        'the native library could not be loaded; call probeNativeLibrary() '
        'for which of missing, wrong file or wrong ABI it was',
      );
    }

    final started = await commands.send(
      StartCommand(WorkerKind.browser, request.toJson()),
    );
    if (started is! StartedReply) {
      await commands.dispose();
      return MdnsBrowserStart._(
        started is StatusReply ? started.status : RkMdnsStatus.unrecognised,
        null,
        started is StatusReply ? started.detail : 'unexpected reply',
      );
    }

    final eventPort = ReceivePort();
    final pollIsolate = await Isolate.spawn(
      pollLoop,
      PollRequest(
        kind: WorkerKind.browser,
        handle: started.handle,
        candidatePaths: candidatePaths,
        events: eventPort.sendPort,
      ),
      debugName: 'rk_mdns-browser-poll',
    );

    final events = eventPort
        .map((message) => BrowserEvent.fromJson(message as String))
        .asBroadcastStream();

    return MdnsBrowserStart._(
      RkMdnsStatus.ok,
      MdnsBrowser._(commands, pollIsolate, events),
      null,
    );
  }

  /// Stops browsing. Calling it twice is not an error. Never throws.
  Future<RkMdnsStatus> stop() async {
    if (_stopped) return RkMdnsStatus.notRunning;
    _stopped = true;
    final reply = await _commands.send(const StopCommand());
    _pollIsolate.kill(priority: Isolate.immediate);
    await _commands.dispose();
    return reply is StatusReply ? reply.status : RkMdnsStatus.unrecognised;
  }
}

/// Asks for one `<name>.local` and waits for an answer.
///
/// An empty [HostAddresses.addresses] is an answer, not a failure: on a
/// network that filters multicast it is the **expected** one, and throwing
/// would make a filtered network indistinguishable from a broken call.
///
/// Null means there is no native library in this process at all — a different
/// thing again, and worth telling apart.
Future<HostAddresses?> resolveHost(
  HostQuery query, {
  List<String>? candidatePaths,
}) async {
  final json = await OneShot.resolveHost(query.toJson(), candidatePaths);
  if (json == null) return null;
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, Object?>) return null;
    return HostAddresses.fromJson(decoded);
  } on Object {
    return null;
  }
}

/// The interfaces this host would announce on, without starting anything.
///
/// Exists because "the service is invisible" has two causes that look
/// identical from another machine — a network that filters multicast, and a
/// host announcing out of the wrong door — and only this tells them apart.
///
/// Null means there is no native library in this process.
Future<List<MdnsInterface>?> mdnsInterfaces({
  bool includeLoopback = false,
  List<String>? candidatePaths,
}) async {
  final json = await OneShot.interfaces(includeLoopback, candidatePaths);
  if (json == null) return null;
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List<Object?>) return null;
    return decoded
        .whereType<Map<Object?, Object?>>()
        .map((e) => MdnsInterface.fromJson(e.cast<String, Object?>()))
        .toList(growable: false);
  } on Object {
    return null;
  }
}
