// The endpoint, driven from Dart — and never from the interface isolate.
//
// **И145 is the shape of this file.** Two things here would stall a UI: the
// poll call blocks a thread until an event arrives or the wait runs out, and
// a reliable send waits for the stream to be opened and flushed. Both live on
// helper isolates, and the interface isolate only ever sends and receives
// messages.
//
// Two isolates and not one, deliberately. The poller spends its life inside a
// blocking call; if commands shared that isolate, every stop and every send
// would queue behind the current wait. A `stop` that takes a fifth of a second
// to be noticed is the difference between a clean shutdown and one that looks
// hung.

import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:isolate';

import 'package:ffi/ffi.dart' show Utf8, calloc, malloc;
import 'package:ffi/ffi.dart' show StringUtf8Pointer, Utf8Pointer;

import 'bindings_io.dart';
import 'loader_io.dart';
import 'quic_event.dart';
import 'status.dart';

/// How long the poller waits inside one native call.
///
/// Not a latency: an event arriving during the wait returns at once. It is how
/// long a stopped endpoint can take to notice it should exit, so it is short.
const Duration _pollSlice = Duration(milliseconds: 200);

/// What a caller has to say to start an endpoint.
class QuicServerConfig {
  const QuicServerConfig({
    required this.bindAddress,
    required this.certificateChainPem,
    required this.privateKeyPem,
    this.path = '/rk',
    this.idleTimeout = const Duration(seconds: 30),
  });

  /// `"0.0.0.0:4433"`. A port of 0 asks the operating system to choose, and
  /// [QuicServer.port] then reports what it chose.
  final String bindAddress;

  /// The chain, leaf first. PEM is how a certificate *travels*; it is the same
  /// DER `rk_pki` deals in on the other side of the wire.
  final String certificateChainPem;

  /// The leaf's private key, PKCS#8 PEM.
  final String privateKeyPem;

  /// The path a client connects to. Anything else is refused, so a stray
  /// connection is never mistaken for a session.
  final String path;

  /// How long a silent session may stay open.
  ///
  /// There is no value meaning "never", and that is the point: a browser tab
  /// killed by the operating system sends nothing, so without a bound the
  /// endpoint would hold the session and go on believing someone is there.
  final Duration idleTimeout;

  Map<String, Object?> toJson() => {
    'bindAddress': bindAddress,
    'certificateChainPem': certificateChainPem,
    'privateKeyPem': privateKeyPem,
    'path': path,
    'idleTimeoutMs': idleTimeout.inMilliseconds,
  };
}

/// What came back from an attempt to start.
///
/// A record and not an exception (И144): "the port is taken" is an ordinary
/// answer on a till where something else may already be serving, and the
/// caller decides whether that is worth telling an operator.
class QuicServerStart {
  const QuicServerStart._(this.status, this.server, this.detail);

  final RkQuicStatus status;

  /// Non-null exactly when [status] is [RkQuicStatus.ok].
  final QuicServer? server;

  /// One line for a log. Never the sole carrier of meaning.
  final String? detail;

  bool get isOk => status == RkQuicStatus.ok;

  @override
  String toString() =>
      'QuicServerStart(${status.name}${detail == null ? '' : ', $detail'})';
}

/// A running endpoint.
class QuicServer {
  QuicServer._(this._commands, this._pollIsolate, this._events, this.port);

  final _CommandChannel _commands;
  final Isolate _pollIsolate;
  final Stream<QuicEvent> _events;

  /// The port actually bound.
  final int port;

  bool _stopped = false;

  /// Events, in the order the endpoint saw them.
  ///
  /// This is the whole point of the package: the server speaks first, and this
  /// is where a caller hears it.
  Stream<QuicEvent> get events => _events;

  /// Starts an endpoint. Never throws.
  static Future<QuicServerStart> start(
    QuicServerConfig config, {
    List<String>? candidatePaths,
  }) async {
    final commands = await _CommandChannel.spawn(candidatePaths);
    if (commands == null) {
      return const QuicServerStart._(
        RkQuicStatus.unsupported,
        null,
        'the native library could not be loaded; call probeNativeLibrary() '
        'for which of missing, wrong file or wrong ABI it was',
      );
    }

    final started = await commands.send(_StartCommand(config.toJson()));
    if (started is! _StartedReply) {
      await commands.dispose();
      return QuicServerStart._(
        started is _StatusReply ? started.status : RkQuicStatus.unrecognised,
        null,
        started is _StatusReply ? started.detail : 'unexpected reply',
      );
    }

    final eventPort = ReceivePort();
    final pollIsolate = await Isolate.spawn(
      _pollLoop,
      _PollRequest(
        handle: started.handle,
        candidatePaths: candidatePaths,
        events: eventPort.sendPort,
      ),
      debugName: 'rk_quic-poll',
    );

    final events = eventPort
        .map((message) => QuicEvent.fromJson(message as String))
        .asBroadcastStream();

    return QuicServerStart._(
      RkQuicStatus.ok,
      QuicServer._(commands, pollIsolate, events, started.port),
      null,
    );
  }

  /// Sends UTF-8 to one session.
  ///
  /// [reliable] picks the road: a stream is ordered and retransmitted, for a
  /// change that must not be lost; a datagram is neither, for the current
  /// value of something that will be sent again.
  ///
  /// [RkQuicStatus.peerGone] means the session went away — a fact, not a
  /// fault, and the signal to stop writing to it.
  Future<RkQuicStatus> send(
    int sessionId,
    String message, {
    bool reliable = true,
  }) async {
    if (_stopped) return RkQuicStatus.notRunning;
    final reply = await _commands.send(
      _SendCommand(sessionId, message, reliable),
    );
    return reply is _StatusReply ? reply.status : RkQuicStatus.unrecognised;
  }

  /// Writes one frame into a bidirectional stream the peer opened.
  ///
  /// The stream stays open. Which kind of exchange this is — an answer, a
  /// subscription, a run reporting progress — belongs to the caller and not to
  /// the transport, so ending it is a separate call to [closeStream].
  ///
  /// The ids come from [StreamOpened] and [StreamData]. Answering the session
  /// instead of the stream would leave a browser with several questions in
  /// flight unable to tell which reply is which, which is the whole reason
  /// this is not [send].
  ///
  /// [RkQuicStatus.unknownHandle] means the stream is gone — closed, or its
  /// session ended. [RkQuicStatus.peerGone] means the write found the peer
  /// absent. Both are facts about the peer, not faults, and both are the
  /// signal to stop producing for it.
  Future<RkQuicStatus> sendOn(
    int sessionId,
    int streamId,
    String message,
  ) async {
    if (_stopped) return RkQuicStatus.notRunning;
    final reply = await _commands.send(
      _StreamSendCommand(sessionId, streamId, message),
    );
    return reply is _StatusReply ? reply.status : RkQuicStatus.unrecognised;
  }

  /// Finishes this side of a bidirectional stream.
  ///
  /// Calling it twice is not an error: the second call answers
  /// [RkQuicStatus.unknownHandle], because during teardown a second close is
  /// ordinary and making it a failure only teaches callers to ignore the
  /// return value.
  Future<RkQuicStatus> closeStream(int sessionId, int streamId) async {
    if (_stopped) return RkQuicStatus.notRunning;
    final reply = await _commands.send(
      _StreamCloseCommand(sessionId, streamId),
    );
    return reply is _StatusReply ? reply.status : RkQuicStatus.unrecognised;
  }

  /// Stops the endpoint and frees everything it owns.
  ///
  /// Calling it twice is not an error. Never throws.
  Future<RkQuicStatus> stop() async {
    if (_stopped) return RkQuicStatus.notRunning;
    _stopped = true;
    final reply = await _commands.send(const _StopCommand());
    _pollIsolate.kill(priority: Isolate.immediate);
    await _commands.dispose();
    return reply is _StatusReply ? reply.status : RkQuicStatus.unrecognised;
  }
}

// --- the isolates -----------------------------------------------------------

class _PollRequest {
  const _PollRequest({
    required this.handle,
    required this.candidatePaths,
    required this.events,
  });
  final int handle;
  final List<String>? candidatePaths;
  final SendPort events;
}

/// The poller. Opens the library itself — an isolate cannot be handed a
/// resolved function pointer, and re-opening an already-mapped file is cheap.
void _pollLoop(_PollRequest request) {
  final bindings = _openBindings(request.candidatePaths);
  if (bindings == null) return;

  final out = calloc<ffi.Pointer<Utf8>>();
  try {
    while (true) {
      final status = statusFromWireName(
        bindings
            .serverPoll(request.handle, _pollSlice.inMilliseconds, out)
            .toDartString(),
      );
      if (status == RkQuicStatus.ok) {
        final pointer = out.value;
        if (pointer != ffi.nullptr) {
          final json = pointer.toDartString();
          // Freed immediately, by the side that allocated it (И146). Holding
          // it until the message is delivered would tie native memory to a
          // Dart queue nobody is watching the length of.
          bindings.stringFree(pointer);
          out.value = ffi.nullptr;
          request.events.send(json);
        }
        continue;
      }
      if (status == RkQuicStatus.wouldBlock) continue;
      // unknownHandle means the endpoint was stopped: leaving is correct, and
      // anything else here would spin.
      return;
    }
  } finally {
    calloc.free(out);
  }
}

/// One isolate for the short calls, so they never queue behind a poll.
class _CommandChannel {
  _CommandChannel._(this._isolate, this._toWorker, this._replies);

  final Isolate _isolate;
  final SendPort _toWorker;
  final Stream<Object?> _replies;

  static Future<_CommandChannel?> spawn(List<String>? candidatePaths) async {
    final probe = probeNativeLibrary(candidatePaths: candidatePaths);
    if (!probe.isUsable) return null;

    final handshake = ReceivePort();
    final isolate = await Isolate.spawn(
      _commandLoop,
      _CommandStart(handshake.sendPort, candidatePaths),
      debugName: 'rk_quic-commands',
    );
    final replies = handshake.asBroadcastStream();
    final toWorker = await replies.first as SendPort;
    return _CommandChannel._(isolate, toWorker, replies);
  }

  Future<Object?> send(Object command) {
    final reply = _replies.first;
    _toWorker.send(command);
    return reply;
  }

  Future<void> dispose() async {
    _isolate.kill(priority: Isolate.immediate);
  }
}

class _CommandStart {
  const _CommandStart(this.reply, this.candidatePaths);
  final SendPort reply;
  final List<String>? candidatePaths;
}

class _StartCommand {
  const _StartCommand(this.configJson);
  final Map<String, Object?> configJson;
}

class _SendCommand {
  const _SendCommand(this.sessionId, this.message, this.reliable);
  final int sessionId;
  final String message;
  final bool reliable;
}

class _StreamSendCommand {
  const _StreamSendCommand(this.sessionId, this.streamId, this.message);
  final int sessionId;
  final int streamId;
  final String message;
}

class _StreamCloseCommand {
  const _StreamCloseCommand(this.sessionId, this.streamId);
  final int sessionId;
  final int streamId;
}

class _StopCommand {
  const _StopCommand();
}

class _StartedReply {
  const _StartedReply(this.handle, this.port);
  final int handle;
  final int port;
}

class _StatusReply {
  const _StatusReply(this.status, this.detail);
  final RkQuicStatus status;
  final String? detail;
}

void _commandLoop(_CommandStart start) {
  final inbox = ReceivePort();
  start.reply.send(inbox.sendPort);

  final bindings = _openBindings(start.candidatePaths);
  if (bindings == null) {
    start.reply.send(
      const _StatusReply(RkQuicStatus.unsupported, 'no library'),
    );
    return;
  }

  var handle = 0;

  inbox.listen((message) {
    switch (message) {
      case _StartCommand(:final configJson):
        final json = jsonEncode(configJson).toNativeUtf8();
        final out = calloc<ffi.Uint64>();
        try {
          final status = statusFromWireName(
            bindings.serverStart(json, out).toDartString(),
          );
          if (status != RkQuicStatus.ok) {
            start.reply.send(_StatusReply(status, bindings.takeLastError()));
            return;
          }
          handle = out.value;
          final portOut = calloc<ffi.Uint16>();
          try {
            bindings.serverLocalPort(handle, portOut);
            start.reply.send(_StartedReply(handle, portOut.value));
          } finally {
            calloc.free(portOut);
          }
        } finally {
          // Allocated by Dart, freed by Dart. The native side never took it.
          malloc.free(json);
          calloc.free(out);
        }

      case _SendCommand(:final sessionId, :final message, :final reliable):
        final payload = message.toNativeUtf8();
        try {
          final status = statusFromWireName(
            bindings
                .sessionSend(handle, sessionId, payload, reliable ? 1 : 0)
                .toDartString(),
          );
          start.reply.send(
            _StatusReply(
              status,
              status == RkQuicStatus.ok ? null : bindings.takeLastError(),
            ),
          );
        } finally {
          malloc.free(payload);
        }

      case _StreamSendCommand(:final sessionId, :final streamId, :final message):
        final payload = message.toNativeUtf8();
        try {
          final status = statusFromWireName(
            bindings
                .streamSend(handle, sessionId, streamId, payload)
                .toDartString(),
          );
          start.reply.send(
            _StatusReply(
              status,
              status == RkQuicStatus.ok ? null : bindings.takeLastError(),
            ),
          );
        } finally {
          // Allocated by Dart, freed by Dart (И146). The native side borrowed
          // it for the length of the call and never took ownership.
          malloc.free(payload);
        }

      case _StreamCloseCommand(:final sessionId, :final streamId):
        final status = statusFromWireName(
          bindings.streamClose(handle, sessionId, streamId).toDartString(),
        );
        start.reply.send(
          _StatusReply(
            status,
            status == RkQuicStatus.ok ? null : bindings.takeLastError(),
          ),
        );

      case _StopCommand():
        final status = statusFromWireName(
          bindings.serverStop(handle).toDartString(),
        );
        start.reply.send(_StatusReply(status, null));

      default:
        start.reply.send(
          const _StatusReply(RkQuicStatus.unrecognised, 'unknown command'),
        );
    }
  });
}

RkQuicBindings? _openBindings(List<String>? candidatePaths) {
  final probe = probeNativeLibrary(candidatePaths: candidatePaths);
  if (!probe.isUsable || probe.path == null) return null;
  try {
    return RkQuicBindings(ffi.DynamicLibrary.open(probe.path!));
  } on Object {
    // The probe just opened it, so this only happens if the file changed
    // underneath. Still a value: an isolate that throws reports nowhere.
    return null;
  }
}
