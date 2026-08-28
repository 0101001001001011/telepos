// The isolates, and why there are two of them per running object.
//
// **И145 is the shape of this file.** Two things here would stall a user
// interface: the poll call blocks a thread until an event arrives or the wait
// runs out, and `stop` blocks until the goodbye datagram has actually gone
// out. Both live on helper isolates, and the interface isolate only ever sends
// and receives messages.
//
// Two isolates and not one, deliberately. The poller spends its life inside a
// blocking call; if commands shared that isolate, every stop would queue
// behind the current wait. On a responder that is worse than a stall: the
// goodbye is what stops a tablet holding a dead till in its cache for two
// minutes, and a stop that is noticed a fifth of a second late is a goodbye
// that may not be sent at all when the process is being torn down around it.

import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:isolate';

import 'package:ffi/ffi.dart' show Utf8, calloc, malloc;
import 'package:ffi/ffi.dart' show StringUtf8Pointer, Utf8Pointer;

import 'bindings_io.dart';
import 'loader_io.dart';
import 'status.dart';

/// How long the poller waits inside one native call.
///
/// Not a latency: an event arriving during the wait returns at once. It is how
/// long a stopped object can take to notice it should exit, so it is short.
const Duration pollSlice = Duration(milliseconds: 200);

/// Which of the two kinds of object a channel is driving.
enum WorkerKind {
  /// A responder: probes, announces, answers, says goodbye.
  responder,

  /// A browser: asks, caches, reports what came and went.
  browser,
}

/// A status and the sentence behind it.
class StatusReply {
  /// One outcome of one call.
  const StatusReply(this.status, this.detail);

  /// What happened.
  final RkMdnsStatus status;

  /// One line for a log, when there is one.
  final String? detail;
}

/// A handle, and the first thing worth knowing about the object behind it.
class StartedReply {
  /// A live handle and the state it started in.
  const StartedReply(this.handle, this.stateJson);

  /// The handle the native side issued.
  final int handle;

  /// The responder's state as JSON, or null for a browser.
  final String? stateJson;
}

/// Some JSON the native side wrote.
class JsonReply {
  /// One JSON document.
  const JsonReply(this.json);

  /// The document.
  final String json;
}

/// One isolate for the short calls, so they never queue behind a poll.
class CommandChannel {
  CommandChannel._(this._isolate, this._toWorker, this._replies);

  final Isolate _isolate;
  final SendPort _toWorker;
  final Stream<Object?> _replies;

  /// Spawns the isolate, or answers null when there is no usable library.
  static Future<CommandChannel?> spawn(List<String>? candidatePaths) async {
    final probe = probeNativeLibrary(candidatePaths: candidatePaths);
    if (!probe.isUsable) return null;

    final handshake = ReceivePort();
    final isolate = await Isolate.spawn(
      _commandLoop,
      _CommandStart(handshake.sendPort, candidatePaths),
      debugName: 'rk_mdns-commands',
    );
    final replies = handshake.asBroadcastStream();
    final toWorker = await replies.first as SendPort;
    return CommandChannel._(isolate, toWorker, replies);
  }

  /// Sends one command and waits for its single reply.
  Future<Object?> send(Object command) {
    final reply = _replies.first;
    _toWorker.send(command);
    return reply;
  }

  /// Kills the isolate. Never throws.
  Future<void> dispose() async {
    _isolate.kill(priority: Isolate.immediate);
  }
}

// --- the commands ---------------------------------------------------------

class _CommandStart {
  const _CommandStart(this.reply, this.candidatePaths);
  final SendPort reply;
  final List<String>? candidatePaths;
}

/// Start a responder or a browser.
class StartCommand {
  /// The kind and its configuration.
  const StartCommand(this.kind, this.config);

  /// Which kind to start.
  final WorkerKind kind;

  /// The configuration, as the native side reads it.
  final Map<String, Object?> config;
}

/// Read a responder's state.
class StateCommand {
  /// No arguments; the handle is the channel's.
  const StateCommand();
}

/// Stop the object this channel started.
class StopCommand {
  /// No arguments; the handle is the channel's.
  const StopCommand();
}

/// What the poller needs to run.
class PollRequest {
  /// A handle, a kind, and somewhere to send what it finds.
  const PollRequest({
    required this.kind,
    required this.handle,
    required this.candidatePaths,
    required this.events,
  });

  /// Which poll entry point to call.
  final WorkerKind kind;

  /// The object to poll.
  final int handle;

  /// Where to find the library, when the default is not wanted.
  final List<String>? candidatePaths;

  /// Where the JSON goes.
  final SendPort events;
}

/// The poller. Opens the library itself — an isolate cannot be handed a
/// resolved function pointer, and re-opening an already-mapped file is cheap.
void pollLoop(PollRequest request) {
  final bindings = openBindings(request.candidatePaths);
  if (bindings == null) return;

  final poll = switch (request.kind) {
    WorkerKind.responder => bindings.responderPoll,
    WorkerKind.browser => bindings.browserPoll,
  };

  final out = calloc<ffi.Pointer<Utf8>>();
  try {
    while (true) {
      final status = statusFromWireName(
        poll(request.handle, pollSlice.inMilliseconds, out).toDartString(),
      );
      if (status == RkMdnsStatus.ok) {
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
      if (status == RkMdnsStatus.wouldBlock) continue;
      // unknownHandle means the object was stopped: leaving is correct, and
      // anything else here would spin.
      return;
    }
  } finally {
    calloc.free(out);
  }
}

void _commandLoop(_CommandStart start) {
  final inbox = ReceivePort();
  start.reply.send(inbox.sendPort);

  final bindings = openBindings(start.candidatePaths);
  if (bindings == null) {
    start.reply.send(const StatusReply(RkMdnsStatus.unsupported, 'no library'));
    return;
  }

  var handle = 0;
  var kind = WorkerKind.responder;

  inbox.listen((message) {
    switch (message) {
      case StartCommand(kind: final requested, config: final config):
        kind = requested;
        final json = jsonEncode(config).toNativeUtf8();
        final out = calloc<ffi.Uint64>();
        try {
          final startFn = switch (requested) {
            WorkerKind.responder => bindings.responderStart,
            WorkerKind.browser => bindings.browserStart,
          };
          final status = statusFromWireName(startFn(json, out).toDartString());
          if (status != RkMdnsStatus.ok) {
            start.reply.send(StatusReply(status, bindings.takeLastError()));
            return;
          }
          handle = out.value;
          start.reply.send(
            StartedReply(
              handle,
              requested == WorkerKind.responder
                  ? _readJson(
                      bindings,
                      (slot) => bindings.responderState(handle, slot),
                    )
                  : null,
            ),
          );
        } finally {
          // Allocated by Dart, freed by Dart. The native side never took it.
          malloc.free(json);
          calloc.free(out);
        }

      case StateCommand():
        final json = _readJson(
          bindings,
          (slot) => bindings.responderState(handle, slot),
        );
        if (json == null) {
          start.reply.send(
            StatusReply(RkMdnsStatus.unknownHandle, bindings.takeLastError()),
          );
        } else {
          start.reply.send(JsonReply(json));
        }

      case StopCommand():
        final stopFn = switch (kind) {
          WorkerKind.responder => bindings.responderStop,
          WorkerKind.browser => bindings.browserStop,
        };
        final status = statusFromWireName(stopFn(handle).toDartString());
        start.reply.send(StatusReply(status, null));

      default:
        start.reply.send(
          const StatusReply(RkMdnsStatus.unrecognised, 'unknown command'),
        );
    }
  });
}

/// Calls something that writes JSON through an out-parameter, and frees it.
String? _readJson(
  RkMdnsBindings bindings,
  ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Pointer<Utf8>>) call,
) {
  final out = calloc<ffi.Pointer<Utf8>>();
  try {
    final status = statusFromWireName(call(out).toDartString());
    if (status != RkMdnsStatus.ok) return null;
    final pointer = out.value;
    if (pointer == ffi.nullptr) return null;
    final json = pointer.toDartString();
    // Whoever allocated frees (И146).
    bindings.stringFree(pointer);
    return json;
  } finally {
    calloc.free(out);
  }
}

/// Opens the library, or answers null. Never throws.
RkMdnsBindings? openBindings(List<String>? candidatePaths) {
  final probe = probeNativeLibrary(candidatePaths: candidatePaths);
  if (!probe.isUsable || probe.path == null) return null;
  try {
    return RkMdnsBindings(
      probe.path == processImageCandidate
          ? ffi.DynamicLibrary.process()
          : ffi.DynamicLibrary.open(probe.path!),
    );
  } on Object {
    // The probe just opened it, so this only happens if the file changed
    // underneath. Still a value: an isolate that throws reports nowhere.
    return null;
  }
}

/// One blocking call on a throwaway isolate, for the two entry points that do
/// not need a handle.
///
/// `resolveHost` waits up to its own timeout inside the native call, so it
/// must not run on the caller's isolate; `interfaces` is fast but goes the
/// same way, because a caller should not have to know which of the two blocks.
class OneShot {
  const OneShot._();

  /// Resolves one `<name>.local`. Answers null when there is no library.
  static Future<String?> resolveHost(
    Map<String, Object?> query,
    List<String>? candidatePaths,
  ) async {
    return Isolate.run(() {
      final bindings = openBindings(candidatePaths);
      if (bindings == null) return null;
      final json = jsonEncode(query).toNativeUtf8();
      try {
        return _readJson(bindings, (slot) => bindings.resolveHost(json, slot));
      } finally {
        malloc.free(json);
      }
    }, debugName: 'rk_mdns-resolve');
  }

  /// Lists the interfaces. Answers null when there is no library.
  static Future<String?> interfaces(
    bool includeLoopback,
    List<String>? candidatePaths,
  ) async {
    return Isolate.run(() {
      final bindings = openBindings(candidatePaths);
      if (bindings == null) return null;
      return _readJson(
        bindings,
        (slot) => bindings.interfaces(includeLoopback ? 1 : 0, slot),
      );
    }, debugName: 'rk_mdns-interfaces');
  }
}
