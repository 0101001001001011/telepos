// The typed vocabulary: everything that crosses the FFI boundary as a name,
// with the name written down next to the case it belongs to.
//
// И147 in `docs/system-architecture.md`: enumerations cross by name, never by
// number. So each enum carries its own wire name rather than relying on
// `index` or on `Enum.name` happening to match — `massaK` is `massa_k` on the
// wire, and a rename on either side must be a visible edit here.

import 'dart:typed_data';

/// A native call that could not do what it was asked.
///
/// The failure crossed the boundary as a *value* — a status name — and this
/// exception is raised on the Dart side after reading it. Nothing ever
/// unwinds out of the Rust stack, which is what И144 requires; what Dart
/// chooses to do with the returned name afterwards is Dart's business.
class RkDevicesException implements Exception {
  const RkDevicesException(this.status, this.call);

  /// The status name, verbatim: `unknown_name`, `buffer_too_small`,
  /// `unsupported_operation`, `invalid_argument`, `invalid_utf8`,
  /// `out_of_range`, `panic`.
  final String status;

  /// Which entry point produced it.
  final String call;

  @override
  String toString() => 'RkDevicesException($call: $status)';
}

/// The native library could not be loaded on this host.
///
/// Not the same thing as a call failing. This is the "not supported on this
/// platform" outcome — the third state the product's cash-drawer result has
/// always had, and the one that must never be collapsed into "error".
class RkDevicesUnavailable implements Exception {
  const RkDevicesUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'RkDevicesUnavailable: $reason';
}

// ---------------------------------------------------------------------------
// Wires
// ---------------------------------------------------------------------------

/// The transports whose partial-write behaviour differs.
enum Wire {
  /// A serial port. `write()` returns how many bytes it accepted, so a
  /// remainder is a continuation.
  serial('serial'),

  /// A TCP socket. `add`/`flush` return nothing, so a failure says nothing
  /// about how much reached the wire.
  socket('socket'),

  /// A character device such as `/dev/usb/lp0`. Returns or throws; either way
  /// the driver may have taken part of the buffer.
  usbRaw('usb_raw');

  const Wire(this.wireName);

  final String wireName;
}

/// What may be done after a write, and nothing more.
sealed class WriteResume {
  const WriteResume();
}

/// Everything reached the wire.
final class WriteDone extends WriteResume {
  const WriteDone();

  @override
  String toString() => 'WriteDone()';
}

/// [offset] bytes reached the wire. Send `payload.sublist(offset)` next — and
/// only that. Starting over duplicates bytes the device has already acted on.
final class WriteContinue extends WriteResume {
  const WriteContinue(this.offset);

  final int offset;

  @override
  String toString() => 'WriteContinue($offset)';
}

/// How much reached the device is not knowable. Neither continuing nor
/// repeating is safe at the byte level; the decision belongs to whatever owns
/// the *job*, and is safe there only because a print job is idempotent by
/// identifier (И29).
final class WriteUnknown extends WriteResume {
  const WriteUnknown();

  @override
  String toString() => 'WriteUnknown()';
}

// ---------------------------------------------------------------------------
// Scales
// ---------------------------------------------------------------------------

enum ScaleProtocol {
  /// A line with a number somewhere in it; `~` or `M` means motion.
  generic('generic'),

  /// `ST,GS,+  1.234kg`.
  cas('cas'),

  /// `$  1.234`.
  massaK('massa_k');

  const ScaleProtocol(this.wireName);

  final String wireName;
}

/// The unit the scale itself named. Never converted by this package: a
/// conversion is a rounding decision about a number that is about to be
/// multiplied by a price.
enum WeightUnit {
  kilogram('kg'),
  gram('g'),
  pound('lb');

  const WeightUnit(this.wireName);

  final String wireName;

  static WeightUnit byWireName(String name) =>
      values.firstWhere((v) => v.wireName == name);
}

enum ScaleStability {
  stable('stable'),
  unstable('unstable'),
  overload('overload'),
  underload('underload');

  const ScaleStability(this.wireName);

  final String wireName;

  static ScaleStability byWireName(String name) =>
      values.firstWhere((v) => v.wireName == name);
}

enum ScaleMeasure {
  gross('gross'),
  net('net'),
  unknown('unknown');

  const ScaleMeasure(this.wireName);

  final String wireName;

  static ScaleMeasure byWireName(String name) =>
      values.firstWhere((v) => v.wireName == name);
}

/// One weight, exactly as the scale sent it.
///
/// [scaled] divided by ten to the [decimals] gives the value in [unit]. An
/// integer and an exponent rather than a `double`, for the same reason money
/// is not a `double` in this product. Convert with `Decimal.parse(
/// reading.toDecimalString())` if you have `package:decimal`; this package
/// deliberately does not depend on it, so that a caller with a different
/// numeric type is not forced into ours.
class WeightReading {
  const WeightReading({
    required this.scaled,
    required this.decimals,
    required this.unit,
    required this.stability,
    required this.measure,
  });

  final int scaled;
  final int decimals;
  final WeightUnit unit;
  final ScaleStability stability;
  final ScaleMeasure measure;

  /// The exact decimal, as text. Exact: no floating point is involved at any
  /// point between the scale's bytes and this string.
  String toDecimalString() {
    if (decimals == 0) return '$scaled';
    final negative = scaled < 0;
    final digits = scaled.abs().toString().padLeft(decimals + 1, '0');
    final cut = digits.length - decimals;
    return '${negative ? '-' : ''}${digits.substring(0, cut)}.'
        '${digits.substring(cut)}';
  }

  @override
  String toString() =>
      'WeightReading(${toDecimalString()} ${unit.wireName}, '
      '${stability.wireName}, ${measure.wireName})';
}

/// What one parse found in the buffer it was given.
sealed class ScaleFrame {
  const ScaleFrame(this.consumed);

  /// How many bytes of the input this frame accounted for. Drop them.
  final int consumed;
}

/// A complete, understood line.
final class ScaleReadingFrame extends ScaleFrame {
  const ScaleReadingFrame(super.consumed, this.reading);

  final WeightReading reading;

  @override
  String toString() => 'ScaleReadingFrame($consumed, $reading)';
}

/// A complete line this protocol cannot read. Skip [consumed] and keep going:
/// reporting this apart from [ScaleIncompleteFrame] is what lets a caller
/// resynchronise instead of stalling.
final class ScaleGarbageFrame extends ScaleFrame {
  const ScaleGarbageFrame(super.consumed);

  @override
  String toString() => 'ScaleGarbageFrame($consumed)';
}

/// No terminator yet. [consumed] is zero: keep the bytes and read more.
final class ScaleIncompleteFrame extends ScaleFrame {
  const ScaleIncompleteFrame() : super(0);

  @override
  String toString() => 'ScaleIncompleteFrame()';
}

/// What the caller heard on the wire since the last offer to a [Stabilizer].
enum Heard {
  /// A reading came out of a parse.
  reading('reading'),

  /// Bytes arrived but produced no reading. The scale is *there*.
  noise('noise'),

  /// Nothing arrived at all.
  silence('silence');

  const Heard(this.wireName);

  final String wireName;
}

/// The answer to "may I put this number on a receipt yet".
enum SettleVerdict {
  /// Settled. The last offered reading is the one to use.
  settled('settled'),

  /// Keep asking; the budget has not run out.
  notYet('not_yet'),

  /// The budget ran out while the scale was talking. It answered — it never
  /// settled. Tell the operator to take the item off and try again.
  expired('expired'),

  /// The budget ran out and nothing was ever heard. A cable or a port
  /// problem, not a weighing problem. Reporting both as one timeout is what
  /// used to send operators to look at the pan when the cable was out.
  noAnswer('no_answer');

  const SettleVerdict(this.wireName);

  final String wireName;

  static SettleVerdict byWireName(String name) =>
      values.firstWhere((v) => v.wireName == name);
}

// ---------------------------------------------------------------------------
// Customer displays
// ---------------------------------------------------------------------------

enum DisplayModel {
  /// One line of eight characters, no cursor addressing.
  led8('led8'),

  /// Two lines of twenty, `ESC $ column line` addressing.
  vfd20('vfd20'),

  /// Two lines of twenty. Declared separately by the device catalogue
  /// (2400 baud rather than 9600); same command set as [vfd20], which is
  /// what the product already does.
  lcd2x20('lcd2x20');

  const DisplayModel(this.wireName);

  final String wireName;
}

enum DisplayOp {
  reset('reset'),
  clear('clear'),
  home('home'),
  displayOn('display_on'),
  displayOff('display_off'),
  blink('blink'),
  setBrightness('set_brightness'),
  setCursor('set_cursor'),
  writeLine('write_line');

  const DisplayOp(this.wireName);

  final String wireName;
}

/// Bytes to send, and how many characters could not be sent as themselves.
class DisplayBytes {
  const DisplayBytes(this.bytes, this.substitutions);

  final Uint8List bytes;

  /// Characters replaced by a space because CP866 has no slot for them —
  /// every Kazakh and Kyrgyz letter, and `₸`. A non-zero count means the
  /// customer is being shown something other than what was asked for.
  final int substitutions;

  @override
  String toString() =>
      'DisplayBytes(${bytes.length} bytes, '
      '$substitutions substitutions)';
}

/// Lines and columns, fixed by the manufacturer.
class DisplayGeometry {
  const DisplayGeometry(this.lines, this.columns);

  final int lines;
  final int columns;

  @override
  String toString() => 'DisplayGeometry(${lines}x$columns)';
}

// ---------------------------------------------------------------------------
// Cash drawers
// ---------------------------------------------------------------------------

enum DrawerModel {
  /// The kick-out connector on an ESC/POS printer or a standalone interface
  /// board. Both cash-drawer profiles in the product catalogue.
  escposKick('escpos_kick');

  const DrawerModel(this.wireName);

  final String wireName;
}

enum DrawerPin {
  pin2('pin2'),
  pin5('pin5');

  const DrawerPin(this.wireName);

  final String wireName;
}

/// Whether anything can be learned about the drawer over the same wire.
enum DrawerReporting {
  /// Nothing comes back. A caller must not claim the drawer opened; the most
  /// it can honestly say is that the pulse was written.
  cannotReport('cannot_report');

  const DrawerReporting(this.wireName);

  final String wireName;

  static DrawerReporting byWireName(String name) =>
      values.firstWhere((v) => v.wireName == name);
}

/// The three outcomes of asking for a drawer pulse.
///
/// Three, not two — the same shape `CashDrawerResult` has always had in this
/// product, and for the same reason: "no drawer support on this platform" is
/// not an error to be logged and retried, it is a fact about the host.
sealed class DrawerPulse {
  const DrawerPulse();
}

/// Here are the bytes. Sending them is the caller's job, and whether the
/// drawer physically opened is nobody's: see [DrawerReporting.cannotReport].
final class DrawerPulseBytes extends DrawerPulse {
  const DrawerPulseBytes(this.bytes);

  final Uint8List bytes;

  @override
  String toString() => 'DrawerPulseBytes(${bytes.length})';
}

/// The request itself was wrong — a pulse longer than the protocol can carry,
/// an unknown model.
final class DrawerPulseRefused extends DrawerPulse {
  const DrawerPulseRefused(this.status);

  /// The status name, verbatim.
  final String status;

  @override
  String toString() => 'DrawerPulseRefused($status)';
}

/// There is no native rk_devices library on this host, so no drawer support
/// at all. Distinct from a failure, and it must stay distinct.
final class DrawerPulseUnsupportedHere extends DrawerPulse {
  const DrawerPulseUnsupportedHere(this.reason);

  final String reason;

  @override
  String toString() => 'DrawerPulseUnsupportedHere($reason)';
}

// ---------------------------------------------------------------------------
// MDB
// ---------------------------------------------------------------------------

enum MdbAddress {
  coinChanger('coin_changer'),
  cashless1('cashless_1'),
  commsGateway('comms_gateway'),
  billValidator('bill_validator'),
  cashless2('cashless_2');

  const MdbAddress(this.wireName);

  final String wireName;
}

/// What came back from a peripheral.
sealed class MdbReply {
  const MdbReply(this.consumed);

  /// How many nine-bit words this reply accounted for.
  final int consumed;
}

/// A data block whose checksum verified. [payload] excludes the checksum.
final class MdbBlock extends MdbReply {
  const MdbBlock(super.consumed, this.payload);

  final Uint8List payload;

  @override
  String toString() => 'MdbBlock($consumed, ${payload.length} bytes)';
}

/// `0x00` with the mode bit set.
final class MdbAck extends MdbReply {
  const MdbAck(super.consumed);

  @override
  String toString() => 'MdbAck()';
}

/// `0xFF` with the mode bit set — heard and refused.
final class MdbNak extends MdbReply {
  const MdbNak(super.consumed);

  @override
  String toString() => 'MdbNak()';
}

/// `0xAA` with the mode bit set — repeat the last block.
final class MdbRet extends MdbReply {
  const MdbRet(super.consumed);

  @override
  String toString() => 'MdbRet()';
}

/// No word with the mode bit set yet. Nothing may be dropped.
final class MdbIncomplete extends MdbReply {
  const MdbIncomplete() : super(0);

  @override
  String toString() => 'MdbIncomplete()';
}

/// A complete block whose checksum does not add up. Ask for a retransmit —
/// which in MDB is what `RET` is for.
final class MdbBadChecksum extends MdbReply {
  const MdbBadChecksum(super.consumed);

  @override
  String toString() => 'MdbBadChecksum($consumed)';
}
