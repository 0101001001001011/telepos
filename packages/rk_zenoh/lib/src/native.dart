/// The synchronous side of the binding: statuses to values, and who frees what.
///
/// **Everything in this file blocks.** It is called only from a worker isolate
/// (И145); the asynchronous API in `session.dart` is what a caller sees.
///
/// Memory (И146): every allocation made here is freed here, in a `finally`.
/// Every handle obtained from the library is released by exactly one matching
/// drop, and the Dart wrapper nulls its own pointer at that moment so a second
/// release cannot be issued from this side.
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'config.dart';
import 'status.dart';

/// Success, and the only status value with a meaning.
const int rkzOk = 0;

/// Read a NUL-terminated string the library lent us. Never frees it.
///
/// The pointer belongs to the native side for as long as it said it would —
/// until the next call on this thread for error text, until the sample is
/// dropped for a sample's key. Copying here is what makes those lifetimes
/// stop mattering to callers.
String readCString(Pointer<Char> ptr) =>
    ptr == nullptr ? '' : ptr.cast<Utf8>().toDartString();

/// Allocate a NUL-terminated copy of [value]. The caller frees it.
Pointer<Char> allocCString(String value) =>
    value.toNativeUtf8(allocator: calloc).cast<Char>();

/// Turn a non-zero status into the exception that describes it.
///
/// The status number itself is never interpreted: the kind arrives as a name.
Never throwLastError(RkzBindings b) {
  final name = readCString(b.lastErrorKind());
  final message = readCString(b.lastErrorMessage());
  final kind = RkzErrorKind.parse(name);
  throw RkzException(
    kind,
    message,
    wireName: kind == RkzErrorKind.unrecognised ? name : null,
  );
}

/// Run [call], and throw if it did not succeed.
void check(RkzBindings b, int status) {
  if (status != rkzOk) throwLastError(b);
}

/// Read a string the library writes into a buffer we own.
String readIntoBuffer(
  RkzBindings b,
  int Function(Pointer<Char> buffer, int capacity) call, {
  int capacity = 256,
}) {
  var size = capacity;
  // Grow rather than guess: the library reports `buffer_too_small` and writes
  // nothing, so retrying is safe and the caller never sees a truncated value.
  for (var attempt = 0; attempt < 8; attempt++) {
    final buffer = calloc<Uint8>(size).cast<Char>();
    try {
      final status = call(buffer, size);
      if (status == rkzOk) return readCString(buffer);
      final kind = RkzErrorKind.parse(readCString(b.lastErrorKind()));
      if (kind != RkzErrorKind.bufferTooSmall) throwLastError(b);
      size *= 4;
    } finally {
      calloc.free(buffer);
    }
  }
  throw RkzException(
    RkzErrorKind.bufferTooSmall,
    'the value did not fit in $size bytes after eight attempts',
  );
}

/// One received sample, already copied out of native memory.
class ZenohSample {
  ZenohSample(this.key, this.kind, this.payload);

  /// The key expression it arrived on.
  final String key;

  /// Whether the value was written or removed.
  final SampleKind kind;

  /// The bytes, owned by Dart. The native sample is already freed.
  final Uint8List payload;

  /// The payload decoded as UTF-8, for the common case.
  String get text => utf8.decode(payload);
}

/// A native session and the declarations made on it, driven synchronously.
///
/// The class owns every handle it creates and frees them in [close]; a caller
/// that forgets leaks native memory, which is why nothing outside this package
/// is given one of these directly.
class NativeSession {
  NativeSession._(this._b, this._session);

  final RkzBindings _b;
  RkzHandle _session;
  final Map<int, RkzHandle> _subscribers = {};
  final Map<int, RkzHandle> _tokens = {};
  var _nextId = 1;

  /// Open a session. Blocks until Zenoh has accepted the configuration.
  static NativeSession open(RkzBindings b, ZenohConfig config) {
    final cfgOut = calloc<RkzHandle>(1);
    RkzHandle cfg = nullptr;
    try {
      check(b, b.configNew(cfgOut));
      cfg = cfgOut.value;
      _applyConfig(b, cfg, config);

      final sessionOut = calloc<RkzHandle>(1);
      try {
        check(b, b.sessionOpen(cfg, sessionOut));
        return NativeSession._(b, sessionOut.value);
      } finally {
        calloc.free(sessionOut);
      }
    } finally {
      if (cfg != nullptr) b.configDrop(cfg);
      calloc.free(cfgOut);
    }
  }

  static void _applyConfig(RkzBindings b, RkzHandle cfg, ZenohConfig config) {
    void withString(String value, int Function(Pointer<Char>) call) {
      final ptr = allocCString(value);
      try {
        check(b, call(ptr));
      } finally {
        calloc.free(ptr);
      }
    }

    final extra = config.extraJson5;
    if (extra != null) {
      withString(extra, (p) => b.configSetExtraJson5(cfg, p));
    }
    withString(config.mode.wireName, (p) => b.configSetMode(cfg, p));
    switch (config.identity) {
      case EphemeralZenohId():
        break;
      case PinnedZenohId(:final hex):
        withString(hex, (p) => b.configPinZid(cfg, p));
      case DerivedZenohId(:final identity):
        withString(identity, (p) => b.configPinZidDerived(cfg, p));
    }
    for (final endpoint in config.connect) {
      withString(endpoint, (p) => b.configAddConnect(cfg, p));
    }
    for (final endpoint in config.listen) {
      withString(endpoint, (p) => b.configAddListen(cfg, p));
    }
    check(b, b.configSetMulticastScouting(cfg, config.multicastScouting));
    check(b, b.configSetGossipScouting(cfg, config.gossipScouting));
  }

  /// This session's Zenoh ID.
  ///
  /// A handle, not an address: it changes on every restart unless the
  /// configuration pinned it.
  String get zid => readIntoBuffer(
    _b,
    (buf, cap) => _b.sessionZid(_session, buf, cap),
    capacity: 64,
  );

  /// The Zenoh IDs currently reachable. A snapshot, not a directory.
  List<String> get peerZids {
    final joined = readIntoBuffer(
      _b,
      (buf, cap) => _b.sessionPeerZids(_session, buf, cap),
      capacity: 1024,
    );
    return joined.isEmpty ? const [] : joined.split('\n');
  }

  /// Publish [payload] at [key].
  void put(
    String key,
    Uint8List payload, {
    CongestionControl congestion = CongestionControl.block,
    Priority priority = Priority.data,
  }) {
    final keyPtr = allocCString(key);
    final congestionPtr = allocCString(congestion.wireName);
    final priorityPtr = allocCString(priority.wireName);
    final payloadPtr = calloc<Uint8>(payload.isEmpty ? 1 : payload.length);
    try {
      if (payload.isNotEmpty) {
        payloadPtr.asTypedList(payload.length).setAll(0, payload);
      }
      check(
        _b,
        _b.sessionPut(
          _session,
          keyPtr,
          payloadPtr,
          payload.length,
          congestionPtr,
          priorityPtr,
        ),
      );
    } finally {
      calloc.free(keyPtr);
      calloc.free(congestionPtr);
      calloc.free(priorityPtr);
      calloc.free(payloadPtr);
    }
  }

  /// Remove the value at [key].
  void delete(String key) {
    final keyPtr = allocCString(key);
    try {
      check(_b, _b.sessionDelete(_session, keyPtr));
    } finally {
      calloc.free(keyPtr);
    }
  }

  /// Declare a subscription, returning a local id for it.
  int declareSubscriber(String key) =>
      _declare(key, _b.subscriberDeclare, _subscribers);

  /// Declare a liveliness subscription, returning a local id for it.
  ///
  /// Samples arrive through [recv] like any other: a `put` when a peer appears
  /// and a `delete` when it goes.
  int declareLivelinessSubscriber(String key) =>
      _declare(key, _b.livelinessDeclareSubscriber, _subscribers);

  /// Declare a liveliness token, returning a local id for it.
  int declareLivelinessToken(String key) =>
      _declare(key, _b.livelinessDeclareToken, _tokens);

  int _declare(
    String key,
    int Function(RkzHandle, Pointer<Char>, Pointer<RkzHandle>) declare,
    Map<int, RkzHandle> into,
  ) {
    final keyPtr = allocCString(key);
    final out = calloc<RkzHandle>(1);
    try {
      check(_b, declare(_session, keyPtr, out));
      final id = _nextId++;
      into[id] = out.value;
      return id;
    } finally {
      calloc.free(keyPtr);
      calloc.free(out);
    }
  }

  /// Wait up to [timeoutMs] for the next sample on [subscriberId].
  ///
  /// Returns `null` on timeout, which is an ordinary outcome. The native
  /// sample is freed before this returns; what comes back is Dart's own copy.
  ZenohSample? recv(int subscriberId, int timeoutMs) {
    final handle = _subscribers[subscriberId];
    if (handle == null) {
      throw RkzException(
        RkzErrorKind.nullArgument,
        'no subscriber with id $subscriberId',
      );
    }
    final out = calloc<RkzHandle>(1);
    try {
      final status = _b.subscriberRecv(handle, timeoutMs, out);
      if (status != rkzOk) {
        final kind = RkzErrorKind.parse(readCString(_b.lastErrorKind()));
        if (kind == RkzErrorKind.timeout) return null;
        throwLastError(_b);
      }
      final sample = out.value;
      try {
        final key = readCString(_b.sampleKey(sample));
        final kind = SampleKind.parse(readCString(_b.sampleKind(sample)));
        final payloadPtr = calloc<Pointer<Uint8>>(1);
        final lengthPtr = calloc<Size>(1);
        try {
          check(_b, _b.samplePayload(sample, payloadPtr, lengthPtr));
          final length = lengthPtr.value;
          final bytes = length == 0
              ? Uint8List(0)
              : Uint8List.fromList(payloadPtr.value.asTypedList(length));
          return ZenohSample(key, kind, bytes);
        } finally {
          calloc.free(payloadPtr);
          calloc.free(lengthPtr);
        }
      } finally {
        // The single drop for this sample, and with it every pointer it lent.
        _b.sampleDrop(sample);
      }
    } finally {
      calloc.free(out);
    }
  }

  /// Release a subscription.
  void dropSubscriber(int id) {
    final handle = _subscribers.remove(id);
    if (handle != null) _b.subscriberDrop(handle);
  }

  /// Release a liveliness token, announcing that this session is gone.
  void dropLivelinessToken(int id) {
    final handle = _tokens.remove(id);
    if (handle != null) _b.livelinessTokenDrop(handle);
  }

  /// Close the session and free everything declared on it.
  ///
  /// Order matters: declarations first, then the session's network side, then
  /// the session handle. Freeing the session with a subscriber still alive is
  /// the one ordering the native side does not defend against.
  void close() {
    if (_session == nullptr) return;
    for (final id in _subscribers.keys.toList()) {
      dropSubscriber(id);
    }
    for (final id in _tokens.keys.toList()) {
      dropLivelinessToken(id);
    }
    _b.sessionClose(_session);
    _b.sessionDrop(_session);
    _session = nullptr;
  }
}
