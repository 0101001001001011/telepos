/// The API a caller sees: asynchronous, and never on the interface isolate.
///
/// Every native call in this package happens on a worker isolate (И145). That
/// is not caution about speed — `rkz_subscriber_recv` blocks by design, and a
/// blocked interface isolate is a frozen till. The worker owns every handle,
/// so the native library is also only ever touched from one thread.
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'bindings.dart';
import 'config.dart';
import 'library.dart';
import 'native.dart';
import 'status.dart';

export 'native.dart' show ZenohSample;

/// How long the worker sleeps when no subscription had anything to give.
///
/// Small enough that it adds no latency worth naming, large enough that an
/// idle till is not spinning a core. Samples are drained with a zero timeout,
/// so this is the only thing standing between a message and its handler.
const Duration _idlePause = Duration(milliseconds: 5);

/// A live Zenoh session.
///
/// Close it. Everything declared on it dies with it, and the native side has
/// no finaliser: `dart:ffi` handles are not garbage collected (И146).
class ZenohSession {
  ZenohSession._(this._isolate, this._toWorker, this._fromWorker, this.zid);

  final Isolate _isolate;
  final SendPort _toWorker;
  final ReceivePort _fromWorker;

  /// This session's Zenoh ID, as it was when the session opened.
  ///
  /// **A handle, not an address.** Unless the configuration pinned it, the
  /// next time this till starts it will have a different one, and anything
  /// that stored this value is holding something that routes nowhere — with
  /// no error to say so. Address peers by their durable identity.
  final String zid;

  final Map<int, Completer<Object?>> _pending = {};
  final Map<int, StreamController<ZenohSample>> _streams = {};
  var _nextRequest = 1;
  var _closed = false;

  /// Open a session.
  ///
  /// Throws [RkzException] if Zenoh refuses the configuration, and
  /// [RkzLibraryNotFound] if the native library is not where it was expected.
  static Future<ZenohSession> open(
    ZenohConfig config, {
    String? libraryPath,
  }) async {
    final refusal = config.refusalReason;
    if (refusal != null) {
      throw RkzException(RkzErrorKind.invalidConfig, refusal);
    }

    final fromWorker = ReceivePort();
    final ready = Completer<Object?>();
    late final StreamSubscription<dynamic> subscription;

    final isolate = await Isolate.spawn(
      _workerMain,
      _WorkerStart(fromWorker.sendPort, config, libraryPath),
      debugName: 'rk_zenoh',
      errorsAreFatal: true,
    );

    // The session does not exist yet when the port starts delivering, and a
    // sample can arrive in the same turn as the handshake. Messages are held
    // until there is something to hand them to rather than dropped.
    ZenohSession? session;
    final held = <Object?>[];
    subscription = fromWorker.listen((message) {
      if (!ready.isCompleted) {
        ready.complete(message);
        return;
      }
      final current = session;
      if (current == null) {
        held.add(message);
      } else {
        current._onWorkerMessage(message);
      }
    });

    final first = await ready.future;
    if (first is _WorkerFailed) {
      await subscription.cancel();
      fromWorker.close();
      isolate.kill(priority: Isolate.immediate);
      throw first.toException();
    }
    final started = first as _WorkerReady;
    final opened = ZenohSession._(
      isolate,
      started.toWorker,
      fromWorker,
      started.zid,
    );
    session = opened;
    for (final message in held) {
      opened._onWorkerMessage(message);
    }
    return opened;
  }

  void _onWorkerMessage(Object? message) {
    switch (message) {
      case _Reply(:final id, :final value, :final failure):
        final completer = _pending.remove(id);
        if (completer == null) return;
        if (failure != null) {
          completer.completeError(failure.toException());
        } else {
          completer.complete(value);
        }
      case _SampleEvent(:final subscriptionId, :final sample):
        _streams[subscriptionId]?.add(sample);
      case _SubscriptionEnded(:final subscriptionId, :final failure):
        final controller = _streams.remove(subscriptionId);
        if (controller == null) return;
        if (failure != null) controller.addError(failure.toException());
        controller.close();
    }
  }

  Future<Object?> _ask(String op, [Map<String, Object?> args = const {}]) {
    if (_closed) {
      throw RkzException(RkzErrorKind.sessionClosed, 'the session is closed');
    }
    final id = _nextRequest++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _toWorker.send(_Request(id, op, args));
    return completer.future;
  }

  /// The Zenoh IDs currently reachable from this session.
  ///
  /// A snapshot of who is connected now. It is not a directory and must not be
  /// cached as one: see the note on [zid].
  Future<List<String>> peerZids() async =>
      ((await _ask('peerZids')) as List).cast<String>();

  /// Publish [payload] at [key].
  ///
  /// Succeeding means Zenoh accepted it, **not** that anyone received it. A
  /// put with no matching subscriber anywhere is a success that delivers
  /// nothing, which is why a peer's address has to be current.
  Future<void> put(
    String key,
    Uint8List payload, {
    CongestionControl congestion = CongestionControl.block,
    Priority priority = Priority.data,
  }) async {
    await _ask('put', {
      'key': key,
      'payload': payload,
      'congestion': congestion.wireName,
      'priority': priority.wireName,
    });
  }

  /// Remove the value at [key].
  Future<void> delete(String key) async {
    await _ask('delete', {'key': key});
  }

  /// Subscribe to a key expression.
  Future<ZenohSubscription> subscribe(String keyExpr) =>
      _subscribe('subscribe', keyExpr);

  /// Watch peers coming and going.
  ///
  /// A `put` when a peer declares a liveliness token, a `delete` when it drops
  /// one or dies. **There is no history**: tokens declared before this call
  /// are not replayed, because replaying them is `.history(true)`, which is
  /// part of Zenoh's unstable API and therefore outside this package. A late
  /// joiner has to ask rather than listen.
  Future<ZenohSubscription> watchLiveliness(String keyExpr) =>
      _subscribe('watchLiveliness', keyExpr);

  Future<ZenohSubscription> _subscribe(String op, String keyExpr) async {
    final id = (await _ask(op, {'key': keyExpr})) as int;
    final controller = StreamController<ZenohSample>.broadcast();
    _streams[id] = controller;
    return ZenohSubscription._(this, id, keyExpr, controller);
  }

  /// Announce that this session is alive at [keyExpr].
  ///
  /// Put the durable identity in the key — `telepos/alive/till-17`, not the
  /// Zenoh ID — so peers learn who is present rather than which ephemeral
  /// handle is present.
  Future<ZenohLivelinessToken> declareLiveliness(String keyExpr) async {
    final id = (await _ask('declareLiveliness', {'key': keyExpr})) as int;
    return ZenohLivelinessToken._(this, id, keyExpr);
  }

  /// Close the session, free every handle, and stop the worker isolate.
  ///
  /// Idempotent, because the shutdown path is exactly where a second call is
  /// likely.
  Future<void> close() async {
    if (_closed) return;
    try {
      await _ask('close');
    } on RkzException {
      // Already gone; there is nothing better to do while closing.
    }
    _closed = true;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          RkzException(RkzErrorKind.sessionClosed, 'the session was closed'),
        );
      }
    }
    _pending.clear();
    for (final controller in _streams.values) {
      await controller.close();
    }
    _streams.clear();
    _fromWorker.close();
    _isolate.kill(priority: Isolate.beforeNextEvent);
  }
}

/// A live subscription.
class ZenohSubscription {
  ZenohSubscription._(this._session, this._id, this.keyExpr, this._controller);

  final ZenohSession _session;
  final int _id;
  final StreamController<ZenohSample> _controller;

  /// The key expression this subscription was declared with.
  final String keyExpr;

  /// The samples, as they arrive.
  ///
  /// A broadcast stream: samples that arrive before anyone listens are lost,
  /// which matches what the fabric does. Buffering them here would invent a
  /// durability this package does not have — see the note about history in
  /// [ZenohSession.watchLiveliness].
  Stream<ZenohSample> get samples => _controller.stream;

  /// Stop receiving and free the native subscription.
  Future<void> close() async {
    await _session._ask('dropSubscriber', {'id': _id});
    await _session._streams.remove(_id)?.close();
  }
}

/// A declared liveliness token. Dropping it is how a peer says it is gone.
class ZenohLivelinessToken {
  ZenohLivelinessToken._(this._session, this._id, this.keyExpr);

  final ZenohSession _session;
  final int _id;

  /// The key expression this token was declared at.
  final String keyExpr;

  /// Withdraw the token, telling watchers this session has gone.
  Future<void> close() async {
    await _session._ask('dropLivelinessToken', {'id': _id});
  }
}

// ------------------------------------------------------------- the worker --

class _WorkerStart {
  _WorkerStart(this.toMain, this.config, this.libraryPath);

  final SendPort toMain;
  final ZenohConfig config;
  final String? libraryPath;
}

class _WorkerReady {
  _WorkerReady(this.toWorker, this.zid);

  final SendPort toWorker;
  final String zid;
}

class _WorkerFailed {
  _WorkerFailed(this.kind, this.message, this.wireName, {this.attempts});

  final String kind;
  final String message;
  final String? wireName;

  /// Set only when the library could not be found, so the caller gets back the
  /// exception that names every path rather than a generic backend failure.
  /// Losing that distinction turns "you have not built the library" into "the
  /// fabric is broken", which is a different afternoon.
  final Map<String, String>? attempts;

  Exception toException() {
    final where = attempts;
    if (where != null) return RkzLibraryNotFound(where);
    return RkzException(RkzErrorKind.parse(kind), message, wireName: wireName);
  }

  static _WorkerFailed from(Object error) => switch (error) {
    RkzLibraryNotFound(:final attempts) => _WorkerFailed(
      RkzErrorKind.backend.wireName,
      error.toString(),
      null,
      attempts: attempts,
    ),
    RkzException(:final kind, :final message, :final wireName) => _WorkerFailed(
      kind.wireName,
      message,
      wireName,
    ),
    _ => _WorkerFailed(RkzErrorKind.backend.wireName, error.toString(), null),
  };
}

class _Request {
  _Request(this.id, this.op, this.args);

  final int id;
  final String op;
  final Map<String, Object?> args;
}

class _Reply {
  _Reply(this.id, this.value, this.failure);

  final int id;
  final Object? value;
  final _WorkerFailed? failure;
}

class _SampleEvent {
  _SampleEvent(this.subscriptionId, this.sample);

  final int subscriptionId;
  final ZenohSample sample;
}

class _SubscriptionEnded {
  _SubscriptionEnded(this.subscriptionId, this.failure);

  final int subscriptionId;
  final _WorkerFailed? failure;
}

Future<void> _workerMain(_WorkerStart start) async {
  final commands = ReceivePort();
  final NativeSession session;
  final RkzBindings bindings;
  try {
    bindings = RkzBindings(openNativeLibrary(path: start.libraryPath));
    session = NativeSession.open(bindings, start.config);
  } on Object catch (e) {
    commands.close();
    start.toMain.send(_WorkerFailed.from(e));
    return;
  }

  start.toMain.send(_WorkerReady(commands.sendPort, session.zid));

  final live = <int>{};
  var running = true;

  commands.listen((message) {
    if (message is! _Request) return;
    Object? value;
    _WorkerFailed? failure;
    try {
      switch (message.op) {
        case 'peerZids':
          value = session.peerZids;
        case 'put':
          session.put(
            message.args['key']! as String,
            message.args['payload']! as Uint8List,
            congestion: CongestionControl.values.firstWhere(
              (c) => c.wireName == message.args['congestion'],
            ),
            priority: Priority.values.firstWhere(
              (p) => p.wireName == message.args['priority'],
            ),
          );
        case 'delete':
          session.delete(message.args['key']! as String);
        case 'subscribe':
          final id = session.declareSubscriber(message.args['key']! as String);
          live.add(id);
          value = id;
        case 'watchLiveliness':
          final id = session.declareLivelinessSubscriber(
            message.args['key']! as String,
          );
          live.add(id);
          value = id;
        case 'declareLiveliness':
          value = session.declareLivelinessToken(
            message.args['key']! as String,
          );
        case 'dropSubscriber':
          final id = message.args['id']! as int;
          live.remove(id);
          session.dropSubscriber(id);
        case 'dropLivelinessToken':
          session.dropLivelinessToken(message.args['id']! as int);
        case 'close':
          running = false;
          live.clear();
          session.close();
        default:
          failure = _WorkerFailed(
            RkzErrorKind.unrecognised.wireName,
            'no such operation: ${message.op}',
            message.op,
          );
      }
    } on Object catch (e) {
      failure = _WorkerFailed.from(e);
    }
    start.toMain.send(_Reply(message.id, value, failure));
  });

  // Drain every subscription with a zero timeout, then yield. Yielding is what
  // lets the command port above be serviced at all: the native receive is
  // synchronous, so nothing else on this isolate runs while it is in progress.
  while (running) {
    var delivered = false;
    for (final id in live.toList()) {
      try {
        while (true) {
          final sample = session.recv(id, 0);
          if (sample == null) break;
          delivered = true;
          start.toMain.send(_SampleEvent(id, sample));
        }
      } on RkzException catch (e) {
        live.remove(id);
        start.toMain.send(_SubscriptionEnded(id, _WorkerFailed.from(e)));
      }
    }
    await Future<void>.delayed(delivered ? Duration.zero : _idlePause);
  }

  commands.close();
}
