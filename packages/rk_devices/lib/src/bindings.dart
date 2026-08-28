// The raw C signatures, and nothing else.
//
// Kept apart from the typed API so that the shape of the ABI is readable in
// one place and reviewable against `rust/include/rk_devices.h` line by line.

import 'dart:ffi';

import 'package:ffi/ffi.dart';

typedef _U32Fn = Uint32 Function();
typedef _U16Fn = Uint16 Function();
typedef _SizeFn = Size Function();

typedef NativeVersion =
    Int32 Function(Pointer<Utf8>, Size, Pointer<Utf8>, Size);
typedef DartVersion = int Function(Pointer<Utf8>, int, Pointer<Utf8>, int);

typedef NativeProvokePanic = Int32 Function(Pointer<Utf8>, Size);
typedef DartProvokePanic = int Function(Pointer<Utf8>, int);

typedef NativeWireReports =
    Int32 Function(Pointer<Utf8>, Pointer<Uint8>, Pointer<Utf8>, Size);
typedef DartWireReports =
    int Function(Pointer<Utf8>, Pointer<Uint8>, Pointer<Utf8>, int);

typedef NativeWireResolve =
    Int32 Function(
      Pointer<Utf8>,
      Size,
      Pointer<Utf8>,
      Size,
      Pointer<Utf8>,
      Size,
      Pointer<Size>,
      Pointer<Utf8>,
      Size,
    );
typedef DartWireResolve =
    int Function(
      Pointer<Utf8>,
      int,
      Pointer<Utf8>,
      int,
      Pointer<Utf8>,
      int,
      Pointer<Size>,
      Pointer<Utf8>,
      int,
    );

typedef NativeScaleRequest =
    Int32 Function(
      Pointer<Utf8>,
      Pointer<Uint8>,
      Size,
      Pointer<Size>,
      Pointer<Utf8>,
      Size,
    );
typedef DartScaleRequest =
    int Function(
      Pointer<Utf8>,
      Pointer<Uint8>,
      int,
      Pointer<Size>,
      Pointer<Utf8>,
      int,
    );

typedef NativeScaleParse =
    Int32 Function(
      Pointer<Utf8>,
      Pointer<Uint8>,
      Size,
      Pointer<Utf8>,
      Size,
      Pointer<Int64>,
      Pointer<Uint32>,
      Pointer<Utf8>,
      Size,
      Pointer<Utf8>,
      Size,
      Pointer<Utf8>,
      Size,
      Pointer<Size>,
      Pointer<Utf8>,
      Size,
    );
typedef DartScaleParse =
    int Function(
      Pointer<Utf8>,
      Pointer<Uint8>,
      int,
      Pointer<Utf8>,
      int,
      Pointer<Int64>,
      Pointer<Uint32>,
      Pointer<Utf8>,
      int,
      Pointer<Utf8>,
      int,
      Pointer<Utf8>,
      int,
      Pointer<Size>,
      Pointer<Utf8>,
      int,
    );

typedef NativeStabilizerInit =
    Int32 Function(Pointer<Uint8>, Uint32, Uint32, Pointer<Utf8>, Size);
typedef DartStabilizerInit =
    int Function(Pointer<Uint8>, int, int, Pointer<Utf8>, int);

typedef NativeStabilizerOffer =
    Int32 Function(
      Pointer<Uint8>,
      Uint32,
      Pointer<Utf8>,
      Int64,
      Uint32,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Size,
      Pointer<Utf8>,
      Size,
    );
typedef DartStabilizerOffer =
    int Function(
      Pointer<Uint8>,
      int,
      Pointer<Utf8>,
      int,
      int,
      Pointer<Utf8>,
      Pointer<Utf8>,
      int,
      Pointer<Utf8>,
      int,
    );

typedef NativeDisplayGeometry =
    Int32 Function(
      Pointer<Utf8>,
      Pointer<Uint32>,
      Pointer<Uint32>,
      Pointer<Utf8>,
      Size,
    );
typedef DartDisplayGeometry =
    int Function(
      Pointer<Utf8>,
      Pointer<Uint32>,
      Pointer<Uint32>,
      Pointer<Utf8>,
      int,
    );

typedef NativeDisplayEncode =
    Int32 Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Uint32,
      Uint32,
      Uint32,
      Pointer<Uint8>,
      Size,
      Pointer<Uint8>,
      Size,
      Pointer<Size>,
      Pointer<Size>,
      Pointer<Utf8>,
      Size,
    );
typedef DartDisplayEncode =
    int Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      int,
      int,
      int,
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
      Pointer<Size>,
      Pointer<Size>,
      Pointer<Utf8>,
      int,
    );

typedef NativeDrawerPulse =
    Int32 Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Uint32,
      Uint32,
      Pointer<Uint8>,
      Size,
      Pointer<Size>,
      Pointer<Utf8>,
      Size,
    );
typedef DartDrawerPulse =
    int Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      int,
      int,
      Pointer<Uint8>,
      int,
      Pointer<Size>,
      Pointer<Utf8>,
      int,
    );

typedef NativeDrawerReporting =
    Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Size, Pointer<Utf8>, Size);
typedef DartDrawerReporting =
    int Function(Pointer<Utf8>, Pointer<Utf8>, int, Pointer<Utf8>, int);

typedef NativeDrawerDefaults =
    Int32 Function(Pointer<Uint32>, Pointer<Uint32>, Pointer<Utf8>, Size);
typedef DartDrawerDefaults =
    int Function(Pointer<Uint32>, Pointer<Uint32>, Pointer<Utf8>, int);

typedef NativeMdbCommandByte =
    Int32 Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Uint8>,
      Pointer<Utf8>,
      Size,
    );
typedef DartMdbCommandByte =
    int Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Uint8>,
      Pointer<Utf8>,
      int,
    );

typedef NativeMdbChecksum =
    Int32 Function(Pointer<Uint8>, Size, Pointer<Uint8>, Pointer<Utf8>, Size);
typedef DartMdbChecksum =
    int Function(Pointer<Uint8>, int, Pointer<Uint8>, Pointer<Utf8>, int);

typedef NativeMdbEncode =
    Int32 Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Uint8>,
      Size,
      Pointer<Uint16>,
      Size,
      Pointer<Size>,
      Pointer<Utf8>,
      Size,
    );
typedef DartMdbEncode =
    int Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Uint8>,
      int,
      Pointer<Uint16>,
      int,
      Pointer<Size>,
      Pointer<Utf8>,
      int,
    );

typedef NativeMdbEncodeRaw =
    Int32 Function(
      Uint8,
      Pointer<Uint8>,
      Size,
      Pointer<Uint16>,
      Size,
      Pointer<Size>,
      Pointer<Utf8>,
      Size,
    );
typedef DartMdbEncodeRaw =
    int Function(
      int,
      Pointer<Uint8>,
      int,
      Pointer<Uint16>,
      int,
      Pointer<Size>,
      Pointer<Utf8>,
      int,
    );

typedef NativeMdbDecode =
    Int32 Function(
      Pointer<Uint16>,
      Size,
      Pointer<Utf8>,
      Size,
      Pointer<Uint8>,
      Size,
      Pointer<Size>,
      Pointer<Size>,
      Pointer<Utf8>,
      Size,
    );
typedef DartMdbDecode =
    int Function(
      Pointer<Uint16>,
      int,
      Pointer<Utf8>,
      int,
      Pointer<Uint8>,
      int,
      Pointer<Size>,
      Pointer<Size>,
      Pointer<Utf8>,
      int,
    );

/// Every symbol this package looks up, resolved once at load time.
///
/// Resolving eagerly is deliberate: a missing symbol is a mismatched build,
/// and finding out at load is a diagnosable failure while finding out on the
/// first sale is not.
class RkDevicesBindings {
  RkDevicesBindings(DynamicLibrary lib)
    : abiVersion = lib.lookupFunction<_U32Fn, int Function()>(
        'rk_devices_abi_version',
      ),
      statusCapacity = lib.lookupFunction<_SizeFn, int Function()>(
        'rk_devices_status_capacity',
      ),
      version = lib.lookupFunction<NativeVersion, DartVersion>(
        'rk_devices_version',
      ),
      provokePanic = lib.lookupFunction<NativeProvokePanic, DartProvokePanic>(
        'rk_devices_provoke_panic_for_test',
      ),
      wireReportsPartialWrites = lib
          .lookupFunction<NativeWireReports, DartWireReports>(
            'rk_devices_wire_reports_partial_writes',
          ),
      wireResolve = lib.lookupFunction<NativeWireResolve, DartWireResolve>(
        'rk_devices_wire_resolve',
      ),
      scaleWeightRequest = lib
          .lookupFunction<NativeScaleRequest, DartScaleRequest>(
            'rk_devices_scale_weight_request',
          ),
      scaleTareRequest = lib
          .lookupFunction<NativeScaleRequest, DartScaleRequest>(
            'rk_devices_scale_tare_request',
          ),
      scaleParse = lib.lookupFunction<NativeScaleParse, DartScaleParse>(
        'rk_devices_scale_parse',
      ),
      stabilizerSize = lib.lookupFunction<_SizeFn, int Function()>(
        'rk_devices_stabilizer_size',
      ),
      stabilizerAlign = lib.lookupFunction<_SizeFn, int Function()>(
        'rk_devices_stabilizer_align',
      ),
      stabilizerInit = lib
          .lookupFunction<NativeStabilizerInit, DartStabilizerInit>(
            'rk_devices_stabilizer_init',
          ),
      stabilizerOffer = lib
          .lookupFunction<NativeStabilizerOffer, DartStabilizerOffer>(
            'rk_devices_stabilizer_offer',
          ),
      displayGeometry = lib
          .lookupFunction<NativeDisplayGeometry, DartDisplayGeometry>(
            'rk_devices_display_geometry',
          ),
      displayEncode = lib
          .lookupFunction<NativeDisplayEncode, DartDisplayEncode>(
            'rk_devices_display_encode',
          ),
      drawerPulse = lib.lookupFunction<NativeDrawerPulse, DartDrawerPulse>(
        'rk_devices_drawer_pulse',
      ),
      drawerReporting = lib
          .lookupFunction<NativeDrawerReporting, DartDrawerReporting>(
            'rk_devices_drawer_reporting',
          ),
      drawerDefaultPulseMs = lib
          .lookupFunction<NativeDrawerDefaults, DartDrawerDefaults>(
            'rk_devices_drawer_default_pulse_ms',
          ),
      mdbResponseWindowMs = lib.lookupFunction<_U32Fn, int Function()>(
        'rk_devices_mdb_response_window_ms',
      ),
      mdbBitTimeUs = lib.lookupFunction<_U32Fn, int Function()>(
        'rk_devices_mdb_bit_time_us',
      ),
      mdbModeBit = lib.lookupFunction<_U16Fn, int Function()>(
        'rk_devices_mdb_mode_bit',
      ),
      mdbCommandByte = lib
          .lookupFunction<NativeMdbCommandByte, DartMdbCommandByte>(
            'rk_devices_mdb_command_byte',
          ),
      mdbChecksum = lib.lookupFunction<NativeMdbChecksum, DartMdbChecksum>(
        'rk_devices_mdb_checksum',
      ),
      mdbEncode = lib.lookupFunction<NativeMdbEncode, DartMdbEncode>(
        'rk_devices_mdb_encode',
      ),
      mdbEncodeRaw = lib.lookupFunction<NativeMdbEncodeRaw, DartMdbEncodeRaw>(
        'rk_devices_mdb_encode_raw',
      ),
      mdbDecode = lib.lookupFunction<NativeMdbDecode, DartMdbDecode>(
        'rk_devices_mdb_decode',
      );

  final int Function() abiVersion;
  final int Function() statusCapacity;
  final DartVersion version;
  final DartProvokePanic provokePanic;
  final DartWireReports wireReportsPartialWrites;
  final DartWireResolve wireResolve;
  final DartScaleRequest scaleWeightRequest;
  final DartScaleRequest scaleTareRequest;
  final DartScaleParse scaleParse;
  final int Function() stabilizerSize;
  final int Function() stabilizerAlign;
  final DartStabilizerInit stabilizerInit;
  final DartStabilizerOffer stabilizerOffer;
  final DartDisplayGeometry displayGeometry;
  final DartDisplayEncode displayEncode;
  final DartDrawerPulse drawerPulse;
  final DartDrawerReporting drawerReporting;
  final DartDrawerDefaults drawerDefaultPulseMs;
  final int Function() mdbResponseWindowMs;
  final int Function() mdbBitTimeUs;
  final int Function() mdbModeBit;
  final DartMdbCommandByte mdbCommandByte;
  final DartMdbChecksum mdbChecksum;
  final DartMdbEncode mdbEncode;
  final DartMdbEncodeRaw mdbEncodeRaw;
  final DartMdbDecode mdbDecode;
}
