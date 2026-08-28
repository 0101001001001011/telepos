/// The isolate every native call runs on.
///
/// И145: no call into the native part happens on the interface isolate. Not a
/// `compute()` per call either — that spawns an isolate each time, and the
/// key store would have to be reopened with it. One long-lived worker owns the
/// handle for the life of the object, which is also what keeps the private
/// key in one place.
library;

import 'dart:async';
import 'dart:isolate';

import '../errors.dart';
import 'engine.dart';
import 'library.dart';

/// A long-lived isolate holding one open key store.
final class PkiWorker {
  PkiWorker._(this._isolate, this._commands, this._answers, this._exit);

  final Isolate _isolate;
  final SendPort _commands;
  final ReceivePort _answers;
  final ReceivePort _exit;

  final Map<int, Completer<String>> _pending = <int, Completer<String>>{};
  int _nextId = 0;
  bool _closed = false;

  /// Starts a worker and opens the store inside it.
  static Future<PkiResult<PkiWorker>> spawn({
    required String configJson,
    String? libraryPath,
  }) async {
    final handshake = ReceivePort();
    final Isolate isolate;
    try {
      isolate = await Isolate.spawn<List<Object?>>(_main, <Object?>[
        handshake.sendPort,
        configJson,
        libraryPath,
      ], debugName: 'rk_pki');
    } catch (e) {
      handshake.close();
      return PkiErr<PkiWorker>(
        NativeFault('cannot start the rk_pki worker isolate: $e'),
      );
    }

    final first = await handshake.first;
    handshake.close();
    if (first is! SendPort) {
      isolate.kill(priority: Isolate.immediate);
      final envelope = first is String
          ? first
          : '{"ok":false,"error":{"kind":"nativeFault",'
                '"detail":"the worker said nothing intelligible"}}';
      return PkiErr<PkiWorker>(_errorOf(envelope));
    }

    final answers = ReceivePort();
    final exit = ReceivePort();
    isolate.addOnExitListener(exit.sendPort);
    final worker = PkiWorker._(isolate, first, answers, exit);
    worker._listen();
    first.send(<Object?>['attach', answers.sendPort]);
    return PkiOk<PkiWorker>(worker);
  }

  void _listen() {
    _answers.listen((Object? message) {
      if (message is List<Object?> && message.length == 2) {
        final id = message[0];
        final json = message[1];
        if (id is int && json is String) {
          _pending.remove(id)?.complete(json);
        }
      }
    });
    _exit.listen((_) {
      // The worker died. Every caller waiting on it gets a value, not a
      // hang: a request that can never be answered is a failure.
      for (final completer in _pending.values) {
        completer.complete(
          '{"ok":false,"error":{"kind":"nativeFault",'
          '"detail":"the rk_pki worker isolate stopped"}}',
        );
      }
      _pending.clear();
      _closed = true;
    });
  }

  /// Runs one operation. Always completes: a failure is a value.
  Future<String> call(String op, String requestJson) {
    if (_closed) {
      return Future<String>.value(
        '{"ok":false,"error":{"kind":"nativeFault",'
        '"detail":"the rk_pki worker is closed"}}',
      );
    }
    final id = _nextId++;
    final completer = Completer<String>();
    _pending[id] = completer;
    _commands.send(<Object?>['call', id, op, requestJson]);
    return completer.future;
  }

  /// Closes the store and stops the isolate. Idempotent.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _commands.send(<Object?>['close']);
    // Give the worker a moment to release the handle deterministically before
    // the isolate is torn down.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    _isolate.kill(priority: Isolate.beforeNextEvent);
    _answers.close();
    _exit.close();
  }

  static PkiError _errorOf(String envelope) {
    // The handshake failure arrives already shaped as an envelope.
    final decoded = RegExp(r'"kind"\s*:\s*"([^"]+)"').firstMatch(envelope);
    final detail = RegExp(r'"detail"\s*:\s*"([^"]*)"').firstMatch(envelope);
    return switch (decoded?.group(1)) {
      'nativeUnavailable' => NativeUnavailable(detail?.group(1) ?? envelope),
      'badRequest' => BadRequest(detail?.group(1) ?? envelope),
      'keystoreUnavailable' => KeystoreUnavailable(
        detail?.group(1) ?? envelope,
      ),
      _ => NativeFault(detail?.group(1) ?? envelope),
    };
  }
}

/// The worker's own body. Everything below this line runs off the interface
/// isolate, and the engine handle never leaves it.
void _main(List<Object?> boot) {
  final handshake = boot[0]! as SendPort;
  final configJson = boot[1]! as String;
  final libraryPath = boot[2] as String?;

  final library = RkPkiLibrary.open(path: libraryPath);
  if (library case PkiErr<RkPkiLibrary>(:final error)) {
    handshake.send(
      '{"ok":false,"error":{"kind":"${error.kind}",'
      '"detail":${_quote(error.detail ?? '')}}}',
    );
    return;
  }
  final opened = NativeEngine.open(
    (library as PkiOk<RkPkiLibrary>).value,
    configJson,
  );
  if (opened case PkiErr<NativeEngine>(:final error)) {
    handshake.send(
      '{"ok":false,"error":{"kind":"${error.kind}",'
      '"detail":${_quote(error.detail ?? '')}}}',
    );
    return;
  }
  final engine = (opened as PkiOk<NativeEngine>).value;

  final commands = ReceivePort();
  handshake.send(commands.sendPort);

  SendPort? answers;
  commands.listen((Object? message) {
    if (message is! List<Object?> || message.isEmpty) return;
    switch (message[0]) {
      case 'attach':
        answers = message[1] as SendPort;
      case 'call':
        final id = message[1]! as int;
        final op = message[2]! as String;
        final request = message[3]! as String;
        answers?.send(<Object?>[id, engine.call(op, request)]);
      case 'close':
        // Deterministic release, here, now — not at some later collection.
        engine.close();
        commands.close();
    }
  });
}

String _quote(String text) =>
    '"${text.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('\n', ' ')}"';
