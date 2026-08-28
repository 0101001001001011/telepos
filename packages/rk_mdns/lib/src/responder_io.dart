// The responder, driven from Dart — and never from the interface isolate.
//
// See `worker_io.dart` for why there are two isolates behind each one of
// these.

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'mdns_event.dart';
import 'service.dart';
import 'status.dart';
import 'worker_io.dart';

/// What came back from an attempt to announce.
///
/// A value and not an exception (И144): "port 5353 is taken" is an ordinary
/// answer on a machine where Chrome is running, and the caller decides whether
/// that is worth telling an operator.
class MdnsResponderStart {
  const MdnsResponderStart._(this.status, this.responder, this.detail);

  /// What happened.
  final RkMdnsStatus status;

  /// Non-null exactly when [status] is [RkMdnsStatus.ok].
  final MdnsResponder? responder;

  /// One line for a log. Never the sole carrier of meaning.
  final String? detail;

  /// Whether the responder is running.
  bool get isOk => status == RkMdnsStatus.ok;

  @override
  String toString() =>
      'MdnsResponderStart(${status.name}${detail == null ? '' : ', $detail'})';
}

/// A live announcement.
class MdnsResponder {
  MdnsResponder._(
    this._commands,
    this._pollIsolate,
    this._events,
    this._requestedInstance,
    this._initialState,
  );

  final CommandChannel _commands;
  final Isolate _pollIsolate;
  final Stream<ResponderEvent> _events;
  final String _requestedInstance;
  final ResponderState _initialState;

  bool _stopped = false;

  /// Everything the responder does, in the order it does it.
  ///
  /// Probes, the conflict if there is one, the claim, each announcement, each
  /// question answered, and the goodbye.
  Stream<ResponderEvent> get events => _events;

  /// The state as it was the moment the responder started.
  ///
  /// Enough to know the name and the interfaces straight away; use [state] for
  /// anything that can change, which after a probe is most of it.
  ResponderState get initialState => _initialState;

  /// Whether the name in use is the one that was asked for.
  ///
  /// `false` means another host on this network already answers to it and this
  /// responder moved to `<name>-2`. That is a setup mistake with a visible
  /// consequence — a tablet looking for `till-3` finds the other machine — so
  /// it is a property rather than a log line.
  Future<bool> get hasRequestedName async {
    final current = await state();
    if (current == null) return false;
    return current.instance.startsWith('$_requestedInstance.');
  }

  /// Announces the service. Never throws.
  static Future<MdnsResponderStart> start(
    ServiceAnnouncement announcement, {
    List<String>? candidatePaths,
  }) async {
    final commands = await CommandChannel.spawn(candidatePaths);
    if (commands == null) {
      return const MdnsResponderStart._(
        RkMdnsStatus.unsupported,
        null,
        'the native library could not be loaded; call probeNativeLibrary() '
        'for which of missing, wrong file or wrong ABI it was',
      );
    }

    final started = await commands.send(
      StartCommand(WorkerKind.responder, announcement.toJson()),
    );
    if (started is! StartedReply) {
      await commands.dispose();
      return MdnsResponderStart._(
        started is StatusReply ? started.status : RkMdnsStatus.unrecognised,
        null,
        started is StatusReply ? started.detail : 'unexpected reply',
      );
    }

    final eventPort = ReceivePort();
    final pollIsolate = await Isolate.spawn(
      pollLoop,
      PollRequest(
        kind: WorkerKind.responder,
        handle: started.handle,
        candidatePaths: candidatePaths,
        events: eventPort.sendPort,
      ),
      debugName: 'rk_mdns-responder-poll',
    );

    final events = eventPort
        .map((message) => ResponderEvent.fromJson(message as String))
        .asBroadcastStream();

    return MdnsResponderStart._(
      RkMdnsStatus.ok,
      MdnsResponder._(
        commands,
        pollIsolate,
        events,
        announcement.instanceName,
        _parseState(started.stateJson),
      ),
      null,
    );
  }

  /// What the responder ended up with — the names, the addresses, and what
  /// each interface has carried.
  ///
  /// Null once stopped, or if the handle went away.
  Future<ResponderState?> state() async {
    if (_stopped) return null;
    final reply = await _commands.send(const StateCommand());
    if (reply is! JsonReply) return null;
    return _parseState(reply.json);
  }

  /// Withdraws the announcement and stops.
  ///
  /// Returns only after the goodbye — the same records with a lifetime of
  /// zero, RFC 6762 §10.1 — has gone out. That is what stops a tablet holding
  /// a dead service in its cache for the next two minutes, and it is why this
  /// is worth awaiting rather than firing and forgetting.
  ///
  /// Calling it twice is not an error. Never throws.
  Future<RkMdnsStatus> stop() async {
    if (_stopped) return RkMdnsStatus.notRunning;
    _stopped = true;
    final reply = await _commands.send(const StopCommand());
    _pollIsolate.kill(priority: Isolate.immediate);
    await _commands.dispose();
    return reply is StatusReply ? reply.status : RkMdnsStatus.unrecognised;
  }
}

ResponderState _parseState(String? json) {
  if (json == null) {
    return const ResponderState(
      instance: '',
      host: '',
      addresses: <String>[],
      claimed: false,
      interfaces: <InterfaceReport>[],
    );
  }
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, Object?>) throw const FormatException();
    return ResponderState.fromJson(decoded);
  } on Object {
    return const ResponderState(
      instance: '',
      host: '',
      addresses: <String>[],
      claimed: false,
      interfaces: <InterfaceReport>[],
    );
  }
}
