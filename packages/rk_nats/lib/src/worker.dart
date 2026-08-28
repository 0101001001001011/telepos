/// The isolate that owns every native call.
///
/// I145: no call into the native library runs on the interface isolate. The
/// calls here block — a publish waits for the server's ack, and an ack that is
/// waited for is the only kind worth having — so running them on the isolate
/// that draws the screen would freeze it for as long as the disk takes.
///
/// Handles are integers rather than pointers, which is what makes this
/// arrangement simple: nothing unsafe is sent between isolates, and the worker
/// opens the library itself.
library;

import 'dart:async';
import 'dart:isolate';

import 'native_library.dart';

/// One request, on its way to the worker.
class _Request {
  _Request(this.id, this.symbol, this.body);

  final int id;
  final String symbol;
  final Map<String, Object?> body;
}

/// One reply, on its way back.
class _Reply {
  _Reply(this.id, this.body);

  final int id;
  final Map<String, Object?> body;
}

/// A long-lived isolate holding an open native library.
///
/// Long-lived rather than one isolate per call: spawning an isolate and opening
/// a shared library for every publish would cost more than the publish, and
/// the durability contract is already paying for a disk sync.
class RkNatsWorker {
  RkNatsWorker._(this._isolate, this._toWorker, this._fromWorker);

  /// Starts a worker that opens the library at [libraryPath].
  ///
  /// Fails with [RkNatsLibraryUnavailable] if the library cannot be opened, and
  /// does so before the worker is considered started, so a caller never holds a
  /// worker that cannot work.
  static Future<RkNatsWorker> start(String libraryPath) async {
    final fromWorker = ReceivePort();
    final ready = Completer<Object>();
    final pending = <int, Completer<Map<String, Object?>>>{};

    // One listener for the whole life of the port. A ReceivePort is a
    // single-subscription stream, so handing the handshake to a listener that
    // is later cancelled and replaced does not work — it throws on the second
    // listen, and only once a worker is actually started.
    final subscription = fromWorker.listen((message) {
      if (!ready.isCompleted) {
        ready.complete(message as Object);
        return;
      }
      if (message is _Reply) {
        pending.remove(message.id)?.complete(message.body);
      }
    });

    final isolate = await Isolate.spawn(
      _main,
      _Boot(fromWorker.sendPort, libraryPath),
      errorsAreFatal: true,
      debugName: 'rk_nats',
    );

    final first = await ready.future;
    if (first is String) {
      isolate.kill(priority: Isolate.immediate);
      await subscription.cancel();
      fromWorker.close();
      throw RkNatsLibraryUnavailable(first);
    }

    final worker = RkNatsWorker._(isolate, first as SendPort, fromWorker);
    worker._pending = pending;
    worker._subscription = subscription;
    return worker;
  }

  final Isolate _isolate;
  final SendPort _toWorker;
  final ReceivePort _fromWorker;
  late final Map<int, Completer<Map<String, Object?>>> _pending;
  late final StreamSubscription<Object?> _subscription;
  int _nextId = 1;
  bool _stopped = false;

  /// Sends one call to the worker and waits for its reply.
  Future<Map<String, Object?>> call(String symbol, Map<String, Object?> body) {
    if (_stopped) {
      // A value, not a throw: the caller is already branching on codes, and a
      // stopped worker is one more outcome rather than a different kind of
      // event (I144).
      return Future.value({
        'code': 'handleClosed',
        'message': 'this rk_nats worker has been stopped',
      });
    }
    final id = _nextId++;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    _toWorker.send(_Request(id, symbol, body));
    return completer.future;
  }

  /// Stops the worker.
  ///
  /// Any call still in flight is answered rather than left hanging: a future
  /// that never completes is the failure mode nobody can debug.
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.complete({
          'code': 'handleClosed',
          'message': 'the worker was stopped while this call was in flight',
        });
      }
    }
    _pending.clear();
    await _subscription.cancel();
    _fromWorker.close();
    _isolate.kill(priority: Isolate.immediate);
  }

  static void _main(_Boot boot) {
    final RkNatsNativeLibrary library;
    try {
      library = RkNatsNativeLibrary.open(boot.libraryPath);
    } on RkNatsLibraryUnavailable catch (error) {
      // Reported as a string, which is how the starter tells failure from the
      // SendPort it is expecting.
      boot.reply.send(error.message);
      return;
    }

    final inbox = ReceivePort();
    boot.reply.send(inbox.sendPort);
    inbox.listen((message) {
      if (message is! _Request) return;
      Map<String, Object?> body;
      try {
        body = library.call(message.symbol, message.body);
      } on Object catch (error) {
        // The native side turns its own failures into codes. This catches the
        // Dart-side ones — a symbol that vanished, a reply that was not JSON —
        // so that they arrive as codes too rather than as an isolate that dies
        // holding an uncompleted future.
        body = {'code': 'panic', 'message': '$error'};
      }
      boot.reply.send(_Reply(message.id, body));
    });
  }
}

class _Boot {
  _Boot(this.reply, this.libraryPath);

  final SendPort reply;
  final String libraryPath;
}
