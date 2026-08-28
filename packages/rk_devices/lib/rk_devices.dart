/// Device protocols that carry their own timing — framed, parsed, and never
/// waited on.
///
/// Weighing scales, customer displays, cash drawers and MDB vending framing:
/// one implementation of each conversation, instead of one per transport.
///
/// ## The rule this package is shaped by
///
/// **Timing that a peripheral controller owns stays there.** MDB's
/// five-millisecond reply window and a stepper's microsecond pulses are held
/// by hardware timers and UARTs, not by a general-purpose host running a
/// till. So this package speaks protocols and holds no deadlines: it frames,
/// parses and reports.
///
/// Concretely, the native library performs no I/O, opens nothing, sleeps
/// never and spawns no thread. Every call is a pure function of its
/// arguments. That is what makes "no device failure may block taking money"
/// structural here rather than promised — nothing that cannot wait can make
/// anyone wait.
///
/// The one place time appears is [Stabilizer], and it holds no clock either:
/// the caller supplies the elapsed time on every offer, and its budget is a
/// [Duration] rather than a number of attempts.
///
/// ## Getting a library
///
/// ```dart
/// final devices = RkDevices.tryOpen();
/// if (devices == null) {
///   // No native library for this host. That is a third state, not an
///   // error — see DrawerPulseUnsupportedHere.
/// }
/// ```
///
/// The native crate lives in `rust/` inside this package and builds to a
/// `cdylib`/`staticlib` with a plain C ABI. Wiring it into a Flutter build is
/// deliberately not this package's business.
library;

export 'src/library.dart' show RkDevices, Stabilizer;
export 'src/model.dart'
    show
        DisplayBytes,
        DisplayGeometry,
        DisplayModel,
        DisplayOp,
        DrawerModel,
        DrawerPin,
        DrawerPulse,
        DrawerPulseBytes,
        DrawerPulseRefused,
        DrawerPulseUnsupportedHere,
        DrawerReporting,
        Heard,
        MdbAck,
        MdbAddress,
        MdbBadChecksum,
        MdbBlock,
        MdbIncomplete,
        MdbNak,
        MdbReply,
        MdbRet,
        RkDevicesException,
        RkDevicesUnavailable,
        ScaleFrame,
        ScaleGarbageFrame,
        ScaleIncompleteFrame,
        ScaleMeasure,
        ScaleProtocol,
        ScaleReadingFrame,
        ScaleStability,
        SettleVerdict,
        WeightReading,
        WeightUnit,
        WriteContinue,
        WriteDone,
        WriteResume,
        WriteUnknown,
        Wire;

import 'dart:typed_data';

import 'src/library.dart';
import 'src/model.dart';

/// The version this package reports about itself.
const String rkDevicesVersion = '0.2.2';

/// Whether a native rk_devices library could be loaded on this host.
///
/// `false` on any platform the crate was not built for. Honest about it: a
/// caller that asks gets a straight answer instead of a method that throws on
/// use.
bool get hasNativeDevices => RkDevices.tryOpen() != null;

/// The cash-drawer pulse, with all three outcomes a drawer has ever had.
///
/// [DrawerPulseBytes] the bytes to send; [DrawerPulseRefused] the request was
/// wrong; [DrawerPulseUnsupportedHere] there is no native library on this
/// host at all. The third is not an error to be logged and retried — it is a
/// fact about the machine, and collapsing it into the second is exactly what
/// `CashDrawerResult.notSupported` exists to prevent.
///
/// Whether the drawer physically opened is a question nobody can answer: the
/// kick wire is one-directional, and [RkDevices.drawerReporting] says so.
DrawerPulse cashDrawerPulse({
  DrawerModel model = DrawerModel.escposKick,
  DrawerPin pin = DrawerPin.pin2,
  Duration? on,
  Duration? off,
}) {
  final devices = RkDevices.tryOpen();
  if (devices == null) {
    return DrawerPulseUnsupportedHere(
      'no rk_devices native library on this host'
      '${RkDevices.lastLoadFailure == null ? '' : ': '
                '${RkDevices.lastLoadFailure}'}',
    );
  }
  return devices.drawerPulse(model: model, pin: pin, on: on, off: off);
}

/// A convenience over [RkDevices.resolveWrite] for the common shape: hand it
/// the payload and what the wire said, get back the bytes still to send.
///
/// Returns `null` when there is nothing left to send, and throws
/// [RkDevicesUnavailable] when the write outcome is unknowable — because at
/// that point the honest answer is not a smaller buffer but a decision one
/// layer up, where the job's identity makes a repeat safe.
Uint8List? remainingAfterWrite({
  required RkDevices devices,
  required Wire wire,
  required Uint8List payload,
  required int? accepted,
}) {
  final resume = devices.resolveWrite(
    wire: wire,
    total: payload.length,
    accepted: accepted,
  );
  return switch (resume) {
    WriteDone() => null,
    WriteContinue(:final offset) => Uint8List.sublistView(payload, offset),
    WriteUnknown() => throw const RkDevicesUnavailable(
      'the transport cannot say how much of the buffer reached the device; '
      'retry the whole job by its identifier, not the bytes',
    ),
  };
}
