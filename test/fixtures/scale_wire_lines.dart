import 'package:decimal/decimal.dart';
import 'package:telepos/hardware/scales/scales_service.dart';

/// Lines a serial scale actually puts on the wire, with what each one must be
/// read as.
///
/// Shared and reusable on purpose (`qa-depth`, «правило нуля»): a wire corpus
/// rewritten per test file drifts, and half the tests then check a different
/// world. Anything that parses scale output reads its cases from here.
///
/// **On national characters.** `qa-depth` requires them wherever there is
/// sorting or string comparison. A serial weight line has neither — it is an
/// ASCII frame from a device, never user text, and nothing here is sorted or
/// searched. One Cyrillic line is present all the same ([_massaKCyrillicUnit]
/// below), because a scale whose display is in Russian can put `кг` in the
/// unit slot, and the corpus should state what happens then rather than leave
/// it to be discovered on a counter.
class ScaleWireLine {
  const ScaleWireLine({
    required this.protocol,
    required this.line,
    required this.what,
    this.weight,
    this.unit = WeightUnit.kg,
    this.status = ScalesStatus.stable,
    this.weightKg,
  });

  /// Which dialect this frame belongs to.
  final ScalesProtocol protocol;

  /// The frame itself, exactly as it arrives after `\r\n` splitting.
  final String line;

  /// What this frame is, in words — read by the failure message, so a red
  /// test says which real-world case broke rather than which array index.
  final String what;

  /// The weight this line must be read as, as a decimal literal.
  ///
  /// `null` means the strongest expectation in this corpus: **no reading at
  /// all.** These are the entries that keep the parsers from answering
  /// "нашёл вес" to something that is not one.
  final String? weight;

  /// The unit the frame states, or [WeightUnit.kg] when it states none.
  final WeightUnit unit;

  final ScalesStatus status;

  /// [weight] converted to kilograms, where that conversion is the point.
  final String? weightKg;

  Decimal? get expectedWeight => weight == null ? null : Decimal.parse(weight!);

  Decimal? get expectedWeightKg =>
      weightKg == null ? null : Decimal.parse(weightKg!);

  @override
  String toString() => '${protocol.name}: "$line" — $what';
}

/// A Massa-K frame from a scale whose display language is Russian.
const _massaKCyrillicUnit = ScaleWireLine(
  protocol: ScalesProtocol.massaK,
  line: r'$   1.250 кг',
  what: 'Cyrillic unit in the unit slot — falls back to kilograms, which is '
      'what «кг» means anyway',
  weight: '1.250',
);

/// Every case the three parsers are held to.
const scaleWireCorpus = <ScaleWireLine>[
  // ---------------------------------------------------------------- CAS ---
  // `<status>,<type>,<sign><right-justified number><unit>`. The sign sits at
  // the left edge of a fixed-width numeric slot, so padding between it and
  // the digits is the ordinary case.
  ScaleWireLine(
    protocol: ScalesProtocol.cas,
    line: 'ST,NT,-  0.500kg',
    what: 'PADDED NEGATIVE — net weight below zero after a tare, i.e. a '
        'return. The defect: the sign used to be dropped and half a kilo '
        'given back was booked as half a kilo sold',
    weight: '-0.500',
    weightKg: '-0.500',
  ),
  ScaleWireLine(
    protocol: ScalesProtocol.cas,
    line: 'ST,GS,+  1.250kg',
    what: 'padded positive — same slot, sign the other way',
    weight: '1.250',
  ),
  ScaleWireLine(
    protocol: ScalesProtocol.cas,
    line: 'ST,GS,   0.000kg',
    what: 'empty platform — zero, with the sign slot blank',
    weight: '0.000',
  ),
  ScaleWireLine(
    protocol: ScalesProtocol.cas,
    line: 'US,GS,+  0.732kg',
    what: 'unstable — the load is still moving',
    weight: '0.732',
    status: ScalesStatus.unstable,
  ),
  ScaleWireLine(
    protocol: ScalesProtocol.cas,
    line: 'OL,GS,+  9.999kg',
    what: 'OVERLOAD — over capacity; the number in the slot is the full-scale '
        'value, not a weight',
    weight: '0',
    status: ScalesStatus.overload,
  ),
  ScaleWireLine(
    protocol: ScalesProtocol.cas,
    line: 'ST,GS,+ 1005.0 g',
    what: 'gram mode, just over a kilo — the unit slot says «g» and must be '
        'believed; read as kilograms this is 1005 kg',
    weight: '1005.0',
    unit: WeightUnit.g,
    weightKg: '1.005',
  ),
  ScaleWireLine(
    protocol: ScalesProtocol.cas,
    line: 'ST,GS,-  500.0 g',
    what: 'gram mode AND a padded negative at once — both defects on one line',
    weight: '-500.0',
    unit: WeightUnit.g,
    weightKg: '-0.5',
  ),
  ScaleWireLine(
    protocol: ScalesProtocol.cas,
    line: 'ST,GS,+  0.0005kg',
    what: 'rounding boundary — half a gram, where the rounding direction shows',
    weight: '0.0005',
  ),
  ScaleWireLine(
    protocol: ScalesProtocol.cas,
    line: 'ST,GS,+  0.100kg',
    what: 'one tenth — half of the pair that a double would add up wrong',
    weight: '0.100',
  ),
  ScaleWireLine(
    protocol: ScalesProtocol.cas,
    line: 'ST,GS,+  0.200kg',
    what: 'two tenths — the other half of that pair',
    weight: '0.200',
  ),
  ScaleWireLine(
    protocol: ScalesProtocol.cas,
    line: 'ST,GS,',
    what: 'MUST NOT PARSE — a truncated frame carries no weight',
  ),
  ScaleWireLine(
    protocol: ScalesProtocol.cas,
    line: 'CAS PD-II  Ver 1.00',
    what: 'MUST NOT PARSE — the power-up banner; «1.00» is a firmware '
        'version, not a kilo',
  ),

  // ------------------------------------------------------------ Massa-K ---
  // `<marker><right-justified number>`. `$` settled, anything else moving.
  ScaleWireLine(
    protocol: ScalesProtocol.massaK,
    line: r'$ -  0.500',
    what: 'PADDED NEGATIVE — same slot layout, same dropped sign',
    weight: '-0.500',
  ),
  ScaleWireLine(
    protocol: ScalesProtocol.massaK,
    line: r'$    1.250',
    what: 'padded positive with no sign character at all',
    weight: '1.250',
  ),
  ScaleWireLine(
    protocol: ScalesProtocol.massaK,
    line: r'$    0.000',
    what: 'empty platform',
    weight: '0.000',
  ),
  _massaKCyrillicUnit,
  ScaleWireLine(
    protocol: ScalesProtocol.massaK,
    line: '   12.345',
    what: 'unstable — the marker slot is blank, and the line is trimmed before '
        'it gets here. The old code cut the first character regardless and '
        'read this as 2.345 kg',
    weight: '12.345',
    status: ScalesStatus.unstable,
  ),
  ScaleWireLine(
    protocol: ScalesProtocol.massaK,
    line: r'$',
    what: 'MUST NOT PARSE — marker with nothing behind it',
  ),
  ScaleWireLine(
    protocol: ScalesProtocol.massaK,
    line: '#####',
    what: 'MUST NOT PARSE — line noise from a wrong baud rate',
  ),

  // ------------------------------------------------------------ generic ---
  ScaleWireLine(
    protocol: ScalesProtocol.generic,
    line: '-  0.500 kg',
    what: 'PADDED NEGATIVE — bare weight line, sign padded away from the '
        'digits',
    weight: '-0.500',
  ),
  ScaleWireLine(
    protocol: ScalesProtocol.generic,
    line: '   1.250 kg',
    what: 'padded positive',
    weight: '1.250',
  ),
  ScaleWireLine(
    protocol: ScalesProtocol.generic,
    line: '0.000 kg',
    what: 'zero, unpadded',
    weight: '0.000',
  ),
  ScaleWireLine(
    protocol: ScalesProtocol.generic,
    line: r'~  0.732 kg',
    what: 'unstable — «~» is this dialect´s motion marker',
    weight: '0.732',
    status: ScalesStatus.unstable,
  ),
  ScaleWireLine(
    protocol: ScalesProtocol.generic,
    line: 'OL',
    what: 'OVERLOAD — the marker arrives with no number behind it at all',
    weight: '0',
    status: ScalesStatus.overload,
  ),
  ScaleWireLine(
    protocol: ScalesProtocol.generic,
    line: 'TOL 1.500 kg',
    what: 'a checkweighing tolerance marker — «TOL» contains «OL» and must '
        'not be taken for one',
    weight: '1.500',
  ),
  ScaleWireLine(
    protocol: ScalesProtocol.generic,
    line: 'ST,+00000.50 g',
    what: 'zero-padded gram frame — half a gram; read as kilograms it is half '
        'a tonne',
    weight: '00000.50',
    unit: WeightUnit.g,
    weightKg: '0.0005',
  ),
  ScaleWireLine(
    protocol: ScalesProtocol.generic,
    line: 'ERROR',
    what: 'MUST NOT PARSE — the scale reporting its own fault',
  ),
  ScaleWireLine(
    protocol: ScalesProtocol.generic,
    line: '------',
    what: 'MUST NOT PARSE — a blanked display',
  ),
];
