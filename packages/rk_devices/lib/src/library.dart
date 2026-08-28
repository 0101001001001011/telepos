// The typed API over the C ABI.
//
// Every buffer that crosses the boundary is allocated here and freed here, in
// a `finally`, on the same line of reasoning as И146: the native side
// allocates nothing a caller must free, so "who frees what" has a one-word
// answer — Dart does, deterministically, and the garbage collector is never
// asked about native memory at all.

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'model.dart';

/// A loaded rk_devices native library.
///
/// Nothing on this class waits, blocks, or touches a device. Every method is
/// a pure function of its arguments: bytes in, bytes out. That is what makes
/// И30 — "no device failure may block taking money" — structural rather than
/// promised, because there is no wait here to be unbounded.
class RkDevices {
  RkDevices._(this._bindings) : _statusCap = _bindings.statusCapacity() {
    final abi = _bindings.abiVersion();
    if (abi != supportedAbiVersion) {
      throw RkDevicesUnavailable(
        'rk_devices native library speaks ABI $abi, this binding speaks '
        '$supportedAbiVersion',
      );
    }
  }

  /// The ABI generation this Dart binding was written against. A library
  /// reporting anything else is refused at load rather than called blind.
  static const int supportedAbiVersion = 1;

  final RkDevicesBindings _bindings;
  final int _statusCap;

  static RkDevices? _cached;
  static Object? _cachedFailure;

  /// Load the native library, or throw [RkDevicesUnavailable].
  ///
  /// Search order: [path] if given, then `RK_DEVICES_LIBRARY` from the
  /// environment, then the platform's default name through the system loader,
  /// then a cargo output directory beside the package — which is how the
  /// tests in this repository find it, and how a developer building the crate
  /// by hand finds it too.
  factory RkDevices.open({String? path}) {
    final attempts = <String>[];
    for (final candidate in _candidates(path)) {
      try {
        return RkDevices._(RkDevicesBindings(DynamicLibrary.open(candidate)));
      } on Object catch (e) {
        attempts.add('$candidate: $e');
      }
    }

    // Apple, and only when nothing was opened by name: under `use_frameworks!`
    // the pod is a framework whose binary already carries this library --
    // apple/build_rust.sh produces a STATIC archive and the podspec pulls it
    // in with `-force_load`, so no `.dylib` exists anywhere to open. The
    // symbols are in the process image instead.
    //
    // Tried last rather than first because an explicit path, the environment
    // variable and a developer's cargo output must keep beating convention.
    //
    // Measured 2026-08-03, the first time this package was ever built for
    // Apple: before this branch existed, macOS asked for a `.dylib` that is
    // never produced and iOS fell through to the Linux name and asked for a
    // `.so`.
    if (Platform.isIOS || Platform.isMacOS) {
      try {
        final process = DynamicLibrary.process();
        // Proving the symbol is there, not merely that a handle came back:
        // `DynamicLibrary.process()` succeeds on a process that never linked
        // this library, and the failure would surface later as a lookup
        // crash somewhere else entirely.
        process.lookup<NativeFunction<Uint32 Function()>>(
          'rk_devices_abi_version',
        );
        return RkDevices._(RkDevicesBindings(process));
      } on Object catch (e) {
        attempts.add('process image: $e');
      }
    }

    throw RkDevicesUnavailable(
      'no rk_devices native library could be loaded. Tried:\n'
      '${attempts.join('\n')}',
    );
  }

  /// The same, returning `null` instead of throwing.
  ///
  /// The result is cached, including the failure: a host without the library
  /// does not get a load attempt per sale.
  static RkDevices? tryOpen({String? path}) {
    if (_cached != null) return _cached;
    if (_cachedFailure != null && path == null) return null;
    try {
      final lib = RkDevices.open(path: path);
      _cached = lib;
      return lib;
    } on Object catch (e) {
      _cachedFailure = e;
      return null;
    }
  }

  /// Why [tryOpen] returned `null`, if it has.
  static Object? get lastLoadFailure => _cachedFailure;

  /// Forget a cached library or load failure. For tests.
  static void resetCache() {
    _cached = null;
    _cachedFailure = null;
  }

  static Iterable<String> _candidates(String? explicit) sync* {
    if (explicit != null) {
      yield explicit;
      return;
    }
    final fromEnv = Platform.environment['RK_DEVICES_LIBRARY'];
    if (fromEnv != null && fromEnv.isNotEmpty) yield fromEnv;

    final base = Platform.isWindows
        ? 'rk_devices.dll'
        : Platform.isMacOS || Platform.isIOS
        ? 'librk_devices.dylib'
        : 'librk_devices.so';

    // The framework binary, for a Flutter application built with
    // `use_frameworks!`. Ahead of the bare name because that is where the
    // library actually is on Apple; the bare name stays for a developer who
    // built the crate into a dylib by hand.
    if (Platform.isIOS || Platform.isMacOS) {
      yield 'rk_devices.framework/rk_devices';
    }
    yield base;

    // Development and test: the crate builds into `rust/target/<profile>`.
    // Walk a few levels up so `dart test` from the package root and from the
    // repository root both find it.
    var dir = Directory.current;
    for (var depth = 0; depth < 4; depth++) {
      for (final profile in const ['release', 'debug']) {
        yield '${dir.path}/packages/rk_devices/rust/target/$profile/$base';
        yield '${dir.path}/rust/target/$profile/$base';
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  }

  /// The native crate's own version.
  String get version => _withStatus('rk_devices_version', (status) {
    final out = calloc<Uint8>(32);
    try {
      final rc = _bindings.version(out.cast<Utf8>(), 32, status, _statusCap);
      _check(rc, status, 'rk_devices_version');
      return out.cast<Utf8>().toDartString();
    } finally {
      calloc.free(out);
    }
  });

  /// Deliberately panics inside the native library and returns the status
  /// name it came back as. Always `'panic'`.
  ///
  /// Exists so a consumer can *prove* И144 — a native failure is a returned
  /// value, not an unwind into a foreign stack and not an abort — rather than
  /// take it on faith. A stub that returned `'panic'` without panicking would
  /// pass a test that only checked the string; this one really panics.
  String provokePanicForTest() {
    final status = calloc<Uint8>(_statusCap);
    try {
      final rc = _bindings.provokePanic(status.cast<Utf8>(), _statusCap);
      if (rc != 1) {
        throw StateError('expected a caught panic, got return code $rc');
      }
      return status.cast<Utf8>().toDartString();
    } finally {
      calloc.free(status);
    }
  }

  // -------------------------------------------------------------------------
  // Partial writes
  // -------------------------------------------------------------------------

  /// Whether a transport can say how much of a buffer it accepted.
  bool wireReportsPartialWrites(Wire wire) =>
      _withStatus('rk_devices_wire_reports_partial_writes', (status) {
        final name = wire.wireName.toNativeUtf8();
        final out = calloc<Uint8>();
        try {
          final rc = _bindings.wireReportsPartialWrites(
            name,
            out,
            status,
            _statusCap,
          );
          _check(rc, status, 'rk_devices_wire_reports_partial_writes');
          return out.value != 0;
        } finally {
          calloc.free(name);
          calloc.free(out);
        }
      });

  /// Turn "the wire said this" into "you may do that".
  ///
  /// [accepted] is the byte count the transport returned, or `null` when the
  /// write failed and carried no count. A count from a transport that cannot
  /// produce one — a socket, a raw USB node — is refused rather than
  /// believed: resuming from an invented offset sends the wrong bytes.
  WriteResume resolveWrite({
    required Wire wire,
    required int total,
    required int? accepted,
  }) => _withStatus('rk_devices_wire_resolve', (status) {
    final wireName = wire.wireName.toNativeUtf8();
    final reportName = (accepted == null ? 'failed' : 'accepted')
        .toNativeUtf8();
    final action = calloc<Uint8>(16);
    final offset = calloc<Size>();
    try {
      final rc = _bindings.wireResolve(
        wireName,
        total,
        reportName,
        accepted ?? 0,
        action.cast<Utf8>(),
        16,
        offset,
        status,
        _statusCap,
      );
      _check(rc, status, 'rk_devices_wire_resolve');
      return switch (action.cast<Utf8>().toDartString()) {
        'done' => const WriteDone(),
        'continue' => WriteContinue(offset.value),
        'unknown' => const WriteUnknown(),
        final other => throw StateError('unknown resume action: $other'),
      };
    } finally {
      calloc.free(wireName);
      calloc.free(reportName);
      calloc.free(action);
      calloc.free(offset);
    }
  });

  // -------------------------------------------------------------------------
  // Scales
  // -------------------------------------------------------------------------

  /// The bytes that ask a scale for its weight.
  Uint8List scaleWeightRequest(ScaleProtocol protocol) => _bytesFromNamed(
    protocol.wireName,
    _bindings.scaleWeightRequest,
    16,
    'rk_devices_scale_weight_request',
  );

  /// The bytes that zero a scale's pan.
  Uint8List scaleTareRequest(ScaleProtocol protocol) => _bytesFromNamed(
    protocol.wireName,
    _bindings.scaleTareRequest,
    16,
    'rk_devices_scale_tare_request',
  );

  /// Read one line out of a scale's byte stream.
  ScaleFrame scaleParse(ScaleProtocol protocol, Uint8List data) =>
      _withStatus('rk_devices_scale_parse', (status) {
        final name = protocol.wireName.toNativeUtf8();
        final input = calloc<Uint8>(data.isEmpty ? 1 : data.length);
        final kind = calloc<Uint8>(16);
        final scaled = calloc<Int64>();
        final decimals = calloc<Uint32>();
        final unit = calloc<Uint8>(8);
        final stability = calloc<Uint8>(16);
        final measure = calloc<Uint8>(16);
        final consumed = calloc<Size>();
        try {
          input.asTypedList(data.isEmpty ? 1 : data.length).setAll(0, data);
          final rc = _bindings.scaleParse(
            name,
            input,
            data.length,
            kind.cast<Utf8>(),
            16,
            scaled,
            decimals,
            unit.cast<Utf8>(),
            8,
            stability.cast<Utf8>(),
            16,
            measure.cast<Utf8>(),
            16,
            consumed,
            status,
            _statusCap,
          );
          _check(rc, status, 'rk_devices_scale_parse');
          return switch (kind.cast<Utf8>().toDartString()) {
            'incomplete' => const ScaleIncompleteFrame(),
            'garbage' => ScaleGarbageFrame(consumed.value),
            'reading' => ScaleReadingFrame(
              consumed.value,
              WeightReading(
                scaled: scaled.value,
                decimals: decimals.value,
                unit: WeightUnit.byWireName(unit.cast<Utf8>().toDartString()),
                stability: ScaleStability.byWireName(
                  stability.cast<Utf8>().toDartString(),
                ),
                measure: ScaleMeasure.byWireName(
                  measure.cast<Utf8>().toDartString(),
                ),
              ),
            ),
            final other => throw StateError('unknown frame kind: $other'),
          };
        } finally {
          calloc.free(name);
          calloc.free(input);
          calloc.free(kind);
          calloc.free(scaled);
          calloc.free(decimals);
          calloc.free(unit);
          calloc.free(stability);
          calloc.free(measure);
          calloc.free(consumed);
        }
      });

  /// Start a settling rule.
  ///
  /// [budget] bounds the wait **in time**, not in attempts — a port that
  /// answers every five milliseconds and one that answers every five seconds
  /// must not get different real deadlines from the same number (И30).
  ///
  /// [neededRepeats] consecutive equal settled readings are required before
  /// the verdict is [SettleVerdict.settled]; one reproduces the behaviour
  /// this replaces, which took the first settled reading it saw.
  ///
  /// The returned rule owns native memory and must be [Stabilizer.dispose]d.
  Stabilizer stabilizer({required Duration budget, int neededRepeats = 1}) {
    final size = _bindings.stabilizerSize();
    final state = calloc<Uint8>(size);
    final status = calloc<Uint8>(_statusCap);
    try {
      final rc = _bindings.stabilizerInit(
        state,
        neededRepeats,
        budget.inMilliseconds,
        status.cast<Utf8>(),
        _statusCap,
      );
      if (rc != 0) {
        calloc.free(state);
        _check(rc, status.cast<Utf8>(), 'rk_devices_stabilizer_init');
      }
      return Stabilizer._(this, state);
    } finally {
      calloc.free(status);
    }
  }

  // -------------------------------------------------------------------------
  // Customer displays
  // -------------------------------------------------------------------------

  /// Lines and columns, as fixed by the manufacturer.
  DisplayGeometry displayGeometry(DisplayModel model) =>
      _withStatus('rk_devices_display_geometry', (status) {
        final name = model.wireName.toNativeUtf8();
        final lines = calloc<Uint32>();
        final columns = calloc<Uint32>();
        try {
          final rc = _bindings.displayGeometry(
            name,
            lines,
            columns,
            status,
            _statusCap,
          );
          _check(rc, status, 'rk_devices_display_geometry');
          return DisplayGeometry(lines.value, columns.value);
        } finally {
          calloc.free(name);
          calloc.free(lines);
          calloc.free(columns);
        }
      });

  /// Build the bytes for one display operation.
  ///
  /// Throws [RkDevicesException] with status `unsupported_operation` when the
  /// model cannot do it — an eight-character single-line display has no
  /// second line and no cursor — and `out_of_range` for a line, column or
  /// brightness the model does not have. Neither is silently adjusted:
  /// adjusting would put the price on the wrong row and report success.
  DisplayBytes displayEncode({
    required DisplayModel model,
    required DisplayOp op,
    int line = 0,
    int column = 0,
    int brightness = 0,
    String text = '',
  }) => _withStatus('rk_devices_display_encode', (status) {
    final modelName = model.wireName.toNativeUtf8();
    final opName = op.wireName.toNativeUtf8();
    final textUtf8 = text.toNativeUtf8();
    final textLen = textUtf8.length;
    const cap = 512;
    final out = calloc<Uint8>(cap);
    final outLen = calloc<Size>();
    final subs = calloc<Size>();
    try {
      final rc = _bindings.displayEncode(
        modelName,
        opName,
        line,
        column,
        brightness,
        textUtf8.cast<Uint8>(),
        textLen,
        out,
        cap,
        outLen,
        subs,
        status,
        _statusCap,
      );
      _check(rc, status, 'rk_devices_display_encode');
      return DisplayBytes(
        Uint8List.fromList(out.asTypedList(outLen.value)),
        subs.value,
      );
    } finally {
      calloc.free(modelName);
      calloc.free(opName);
      calloc.free(textUtf8);
      calloc.free(out);
      calloc.free(outLen);
      calloc.free(subs);
    }
  });

  // -------------------------------------------------------------------------
  // Cash drawers
  // -------------------------------------------------------------------------

  /// Whether anything can be learned about the drawer over the same wire.
  DrawerReporting drawerReporting(DrawerModel model) =>
      _withStatus('rk_devices_drawer_reporting', (status) {
        final name = model.wireName.toNativeUtf8();
        final out = calloc<Uint8>(24);
        try {
          final rc = _bindings.drawerReporting(
            name,
            out.cast<Utf8>(),
            24,
            status,
            _statusCap,
          );
          _check(rc, status, 'rk_devices_drawer_reporting');
          return DrawerReporting.byWireName(out.cast<Utf8>().toDartString());
        } finally {
          calloc.free(name);
          calloc.free(out);
        }
      });

  /// The pulse this product has always sent: 64 ms on, 320 ms off.
  ({Duration on, Duration off}) get drawerDefaultPulse => _withStatus(
    'rk_devices_drawer_default_pulse_ms',
    (status) {
      final on = calloc<Uint32>();
      final off = calloc<Uint32>();
      try {
        final rc = _bindings.drawerDefaultPulseMs(on, off, status, _statusCap);
        _check(rc, status, 'rk_devices_drawer_default_pulse_ms');
        return (
          on: Duration(milliseconds: on.value),
          off: Duration(milliseconds: off.value),
        );
      } finally {
        calloc.free(on);
        calloc.free(off);
      }
    },
  );

  /// The kick pulse, as bytes. Never throws: the refusal is a value, because
  /// the caller of a drawer is usually mid-sale and has three things it might
  /// do rather than two.
  DrawerPulse drawerPulse({
    DrawerModel model = DrawerModel.escposKick,
    DrawerPin pin = DrawerPin.pin2,
    Duration? on,
    Duration? off,
  }) {
    final status = calloc<Uint8>(_statusCap);
    final modelName = model.wireName.toNativeUtf8();
    final pinName = pin.wireName.toNativeUtf8();
    final out = calloc<Uint8>(16);
    final outLen = calloc<Size>();
    try {
      final defaults = drawerDefaultPulse;
      final rc = _bindings.drawerPulse(
        modelName,
        pinName,
        (on ?? defaults.on).inMilliseconds,
        (off ?? defaults.off).inMilliseconds,
        out,
        16,
        outLen,
        status.cast<Utf8>(),
        _statusCap,
      );
      if (rc != 0) {
        return DrawerPulseRefused(
          rc == 2 ? 'buffer_too_small' : status.cast<Utf8>().toDartString(),
        );
      }
      return DrawerPulseBytes(
        Uint8List.fromList(out.asTypedList(outLen.value)),
      );
    } finally {
      calloc.free(status);
      calloc.free(modelName);
      calloc.free(pinName);
      calloc.free(out);
      calloc.free(outLen);
    }
  }

  // -------------------------------------------------------------------------
  // MDB
  // -------------------------------------------------------------------------

  /// The window a peripheral has to begin replying.
  ///
  /// A number to configure a bridge microcontroller with. Nothing in this
  /// package waits, so nothing in it can enforce this.
  Duration get mdbResponseWindow =>
      Duration(milliseconds: _bindings.mdbResponseWindowMs());

  /// One bit time at 9600 baud, in microseconds. Same caveat.
  int get mdbBitTimeMicroseconds => _bindings.mdbBitTimeUs();

  /// The ninth-bit mask: `0x100` in every word this package produces.
  int get mdbModeBit => _bindings.mdbModeBit();

  /// The command byte for a named command on a named peripheral.
  int mdbCommandByte(MdbAddress address, String command) =>
      _withStatus('rk_devices_mdb_command_byte', (status) {
        final addressName = address.wireName.toNativeUtf8();
        final commandName = command.toNativeUtf8();
        final out = calloc<Uint8>();
        try {
          final rc = _bindings.mdbCommandByte(
            addressName,
            commandName,
            out,
            status,
            _statusCap,
          );
          _check(rc, status, 'rk_devices_mdb_command_byte');
          return out.value;
        } finally {
          calloc.free(addressName);
          calloc.free(commandName);
          calloc.free(out);
        }
      });

  /// The eight-bit sum that closes an MDB block.
  int mdbChecksum(Uint8List data) =>
      _withStatus('rk_devices_mdb_checksum', (status) {
        final input = calloc<Uint8>(data.isEmpty ? 1 : data.length);
        final out = calloc<Uint8>();
        try {
          input.asTypedList(data.isEmpty ? 1 : data.length).setAll(0, data);
          final rc = _bindings.mdbChecksum(
            input,
            data.length,
            out,
            status,
            _statusCap,
          );
          _check(rc, status, 'rk_devices_mdb_checksum');
          return out.value;
        } finally {
          calloc.free(input);
          calloc.free(out);
        }
      });

  /// A master-to-peripheral frame as nine-bit words: bit 8 is the mode bit.
  Uint16List mdbEncode(MdbAddress address, String command, [Uint8List? data]) =>
      _withStatus('rk_devices_mdb_encode', (status) {
        final payload = data ?? Uint8List(0);
        final addressName = address.wireName.toNativeUtf8();
        final commandName = command.toNativeUtf8();
        final input = calloc<Uint8>(payload.isEmpty ? 1 : payload.length);
        const cap = 288;
        final out = calloc<Uint16>(cap);
        final outLen = calloc<Size>();
        try {
          input
              .asTypedList(payload.isEmpty ? 1 : payload.length)
              .setAll(0, payload);
          final rc = _bindings.mdbEncode(
            addressName,
            commandName,
            input,
            payload.length,
            out,
            cap,
            outLen,
            status,
            _statusCap,
          );
          _check(rc, status, 'rk_devices_mdb_encode');
          return Uint16List.fromList(out.asTypedList(outLen.value));
        } finally {
          calloc.free(addressName);
          calloc.free(commandName);
          calloc.free(input);
          calloc.free(out);
          calloc.free(outLen);
        }
      });

  /// The same frame, from a command byte the caller supplies.
  ///
  /// The way out of this package's transcribed command table: the MDB
  /// standard is not freely distributed, the table came from secondary
  /// sources, and nobody should be unable to talk to their own bridge because
  /// of that.
  Uint16List mdbEncodeRaw(int command, [Uint8List? data]) =>
      _withStatus('rk_devices_mdb_encode_raw', (status) {
        final payload = data ?? Uint8List(0);
        final input = calloc<Uint8>(payload.isEmpty ? 1 : payload.length);
        const cap = 288;
        final out = calloc<Uint16>(cap);
        final outLen = calloc<Size>();
        try {
          input
              .asTypedList(payload.isEmpty ? 1 : payload.length)
              .setAll(0, payload);
          final rc = _bindings.mdbEncodeRaw(
            command,
            input,
            payload.length,
            out,
            cap,
            outLen,
            status,
            _statusCap,
          );
          _check(rc, status, 'rk_devices_mdb_encode_raw');
          return Uint16List.fromList(out.asTypedList(outLen.value));
        } finally {
          calloc.free(input);
          calloc.free(out);
          calloc.free(outLen);
        }
      });

  /// Read one peripheral-to-master frame.
  MdbReply mdbDecode(Uint16List words) =>
      _withStatus('rk_devices_mdb_decode', (status) {
        final len = words.isEmpty ? 1 : words.length;
        final input = calloc<Uint16>(len);
        final kind = calloc<Uint8>(16);
        const payloadCap = 288;
        final payload = calloc<Uint8>(payloadCap);
        final payloadLen = calloc<Size>();
        final consumed = calloc<Size>();
        try {
          input.asTypedList(len).setAll(0, words);
          final rc = _bindings.mdbDecode(
            input,
            words.length,
            kind.cast<Utf8>(),
            16,
            payload,
            payloadCap,
            payloadLen,
            consumed,
            status,
            _statusCap,
          );
          _check(rc, status, 'rk_devices_mdb_decode');
          return switch (kind.cast<Utf8>().toDartString()) {
            'ack' => MdbAck(consumed.value),
            'nak' => MdbNak(consumed.value),
            'ret' => MdbRet(consumed.value),
            'incomplete' => const MdbIncomplete(),
            'bad_checksum' => MdbBadChecksum(consumed.value),
            'block' => MdbBlock(
              consumed.value,
              Uint8List.fromList(payload.asTypedList(payloadLen.value)),
            ),
            final other => throw StateError('unknown MDB reply kind: $other'),
          };
        } finally {
          calloc.free(input);
          calloc.free(kind);
          calloc.free(payload);
          calloc.free(payloadLen);
          calloc.free(consumed);
        }
      });

  // -------------------------------------------------------------------------
  // Plumbing
  // -------------------------------------------------------------------------

  T _withStatus<T>(String call, T Function(Pointer<Utf8> status) body) {
    final status = calloc<Uint8>(_statusCap);
    try {
      return body(status.cast<Utf8>());
    } finally {
      calloc.free(status);
    }
  }

  void _check(int rc, Pointer<Utf8> status, String call) {
    if (rc == 0) return;
    if (rc == 2) {
      throw RkDevicesException('status_buffer_too_small', call);
    }
    throw RkDevicesException(status.toDartString(), call);
  }

  Uint8List _bytesFromNamed(
    String name,
    DartScaleRequest fn,
    int cap,
    String call,
  ) => _withStatus(call, (status) {
    final namePtr = name.toNativeUtf8();
    final out = calloc<Uint8>(cap);
    final outLen = calloc<Size>();
    try {
      final rc = fn(namePtr, out, cap, outLen, status, _statusCap);
      _check(rc, status, call);
      return Uint8List.fromList(out.asTypedList(outLen.value));
    } finally {
      calloc.free(namePtr);
      calloc.free(out);
      calloc.free(outLen);
    }
  });

  RkDevicesBindings get bindingsForTesting => _bindings;

  int get statusCapacityForTesting => _statusCap;
}

/// The settling rule, holding native state the caller owns.
///
/// It has no clock: [offer] is told how much time has passed, and answers.
/// Nothing here sleeps, polls or blocks — the loop belongs to whoever owns
/// the port, and its budget is a duration rather than a number of tries.
class Stabilizer {
  Stabilizer._(this._owner, this._state);

  final RkDevices _owner;
  Pointer<Uint8>? _state;

  /// Offer one poll's worth of evidence.
  ///
  /// [elapsed] is measured from the moment the caller started asking, and is
  /// the only notion of time in the whole package.
  SettleVerdict offer({
    required Duration elapsed,
    required Heard heard,
    WeightReading? reading,
  }) {
    final state = _state;
    if (state == null) {
      throw StateError('Stabilizer used after dispose()');
    }
    if (heard == Heard.reading && reading == null) {
      throw ArgumentError('heard: reading requires a reading');
    }
    final status = calloc<Uint8>(_owner.statusCapacityForTesting);
    final heardName = heard.wireName.toNativeUtf8();
    final stabilityName = (reading?.stability ?? ScaleStability.unstable)
        .wireName
        .toNativeUtf8();
    final verdict = calloc<Uint8>(16);
    try {
      final rc = _owner.bindingsForTesting.stabilizerOffer(
        state,
        elapsed.inMilliseconds,
        heardName,
        reading?.scaled ?? 0,
        reading?.decimals ?? 0,
        stabilityName,
        verdict.cast<Utf8>(),
        16,
        status.cast<Utf8>(),
        _owner.statusCapacityForTesting,
      );
      if (rc != 0) {
        throw RkDevicesException(
          rc == 2
              ? 'status_buffer_too_small'
              : status.cast<Utf8>().toDartString(),
          'rk_devices_stabilizer_offer',
        );
      }
      return SettleVerdict.byWireName(verdict.cast<Utf8>().toDartString());
    } finally {
      calloc.free(status);
      calloc.free(heardName);
      calloc.free(stabilityName);
      calloc.free(verdict);
    }
  }

  /// Release the native state. Idempotent.
  ///
  /// Deterministic by construction: this is `calloc.free`, called by the
  /// caller, at a moment the caller chose. The garbage collector is never
  /// asked about it, which is what И146 requires.
  void dispose() {
    final state = _state;
    if (state == null) return;
    _state = null;
    calloc.free(state);
  }
}
