import 'dart:async';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';

import 'package:telepos/hardware/serial/serial_port_path.dart';

class ScalesService {
  ScalesService({
    Talker? logger,
    this.port,
    this.baudRate = 9600,
    this.protocol = ScalesProtocol.generic,
    this.stableDelayMs = 500,
  }) : _logger = logger;

  final Talker? _logger;

  final String? port;

  final int baudRate;

  final ScalesProtocol protocol;

  final int stableDelayMs;

  final _weightController = StreamController<ScalesReading>.broadcast();

  Stream<ScalesReading> get weightStream => _weightController.stream;

  ScalesReading? _lastReading;
  ScalesReading? get lastReading => _lastReading;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  RandomAccessFile? _portFile;

  Timer? _pollTimer;

  final _readBuffer = StringBuffer();

  Future<ScalesConnectResult> connect() async {
    if (port == null || port!.isEmpty) {
      return ScalesConnectResult.failure('Порт не указан');
    }

    try {
      _portFile = await openSerialPort(port!, mode: FileMode.append);

      _isConnected = true;
      _logger?.info('Scales connected on $port ($protocol)');

      _startPolling();

      return ScalesConnectResult.success();
    } catch (e) {
      _logger?.error('Scales connection failed: $e');
      return ScalesConnectResult.failure('Ошибка подключения: $e');
    }
  }

  Future<void> disconnect() async {
    _pollTimer?.cancel();
    _pollTimer = null;

    try {
      await _portFile?.close();
    } catch (_) {}
    _portFile = null;

    _isConnected = false;
    _readBuffer.clear();
    _logger?.info('Scales disconnected');
  }

  /// Waits for a weight the scale calls settled.
  ///
  /// The waiting itself is [awaitSettledReading]; this method only guards the
  /// connection and nudges the scale with its request command.
  Future<ScalesReading> requestWeight({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_isConnected || _portFile == null) {
      return ScalesReading.error('Весы не подключены');
    }

    final requestCmd = _getWeightRequestCommand();
    if (requestCmd != null) {
      try {
        await _portFile!.writeFrom(requestCmd);
        await _portFile!.flush();
      } catch (e) {
        return ScalesReading.error('Ошибка отправки команды: $e');
      }
    }

    return awaitSettledReading(weightStream, timeout);
  }

  Future<bool> tare() async {
    if (!_isConnected || _portFile == null) return false;

    final tareCmd = _getTareCommand();
    if (tareCmd == null) return false;

    try {
      await _portFile!.writeFrom(tareCmd);
      await _portFile!.flush();
      _logger?.debug('Tare command sent');
      return true;
    } catch (e) {
      _logger?.error('Tare failed: $e');
      return false;
    }
  }

  void setManualWeight(Decimal weight) {
    final reading = ScalesReading(
      weight: weight,
      unit: WeightUnit.kg,
      status: ScalesStatus.stable,
      isManual: true,
    );
    _lastReading = reading;
    _weightController.add(reading);
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _pollWeight();
    });
  }

  /// The over-capacity marker as ASCII scales write it: `OL`, `-OL-`, `OL kg`.
  /// Word-bounded so `TOLERANCE` and the like cannot trip it.
  static final RegExp _overloadToken = RegExp(r'\bOL\b');

  Future<void> _pollWeight() async {
    if (_portFile == null) return;

    try {
      final bytes = await _portFile!.read(64);
      if (bytes.isEmpty) return;

      final text = String.fromCharCodes(bytes);
      _readBuffer.write(text);

      final bufferStr = _readBuffer.toString();
      final lines = bufferStr.split(RegExp(r'[\r\n]+'));

      if (lines.length > 1) {
        for (int i = 0; i < lines.length - 1; i++) {
          final parsed = parseLine(lines[i]);
          if (parsed != null) {
            _lastReading = parsed;
            _weightController.add(parsed);
          }
        }
        _readBuffer.clear();
        _readBuffer.write(lines.last);
      }
    } catch (_) {}
  }

  /// One wire line to one reading, or `null` when the line carries no weight.
  ///
  /// Public because this — not the serial port — is where the money error of
  /// this class lives, and a wire format is only proved against the exact
  /// bytes real hardware emits. Pure: protocol and line in, reading out.
  ScalesReading? parseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    return switch (protocol) {
      ScalesProtocol.generic => _parseGeneric(trimmed),
      ScalesProtocol.cas => _parseCas(trimmed),
      ScalesProtocol.massaK => _parseMassaK(trimmed),
    };
  }

  ScalesReading? _parseGeneric(String line) {
    // Checked before the number, because an overloaded scale often sends the
    // marker with no number at all — `OL`, `-OL-`, `OL kg`. Word-bounded and
    // case-sensitive so it cannot fire on a stray "ol" inside a word.
    if (_overloadToken.hasMatch(line)) {
      return ScalesReading(weight: Decimal.zero, status: ScalesStatus.overload);
    }

    final field = _WeightField.parse(line);
    if (field == null) return null;

    final isStable = !line.contains('~') && !line.contains('M');

    return ScalesReading(
      weight: field.value,
      unit: field.unit,
      status: isStable ? ScalesStatus.stable : ScalesStatus.unstable,
    );
  }

  /// `<status>,<type>,<sign><padded number><unit>` — e.g. `ST,GS,-  0.500kg`.
  ///
  /// Status field: `ST` settled, `US` moving, `OL` over capacity. The sign
  /// sits at the left edge of a fixed-width, right-justified numeric slot, so
  /// the spaces between it and the digits are the normal case, not a defect
  /// of one unit.
  ScalesReading? _parseCas(String line) {
    final parts = line.split(',');
    final status = switch (parts.first.trim().toUpperCase()) {
      'ST' => ScalesStatus.stable,
      'OL' => ScalesStatus.overload,
      _ => ScalesStatus.unstable,
    };

    // The number on an overload line is not a weight — scales put the
    // full-scale value, blanks, or nothing there — so it is not read, and the
    // absence of a readable number does not suppress the report.
    if (status == ScalesStatus.overload) {
      return ScalesReading(weight: Decimal.zero, status: ScalesStatus.overload);
    }

    if (parts.length < 3) return null;

    final field = _WeightField.parse(parts[2]);
    if (field == null) return null;

    return ScalesReading(weight: field.value, unit: field.unit, status: status);
  }

  /// `<marker><padded number>` — `$` settled, anything else moving.
  ///
  /// No overload state here on purpose. This dialect's marker for over
  /// capacity is not established in this codebase, and guessing one would
  /// produce a false «перегрузка» that stops a sale outright — strictly worse
  /// than the honest "answers but never settles" that [requestWeight] now
  /// reports for it.
  ScalesReading? _parseMassaK(String line) {
    if (line.length < 2) return null;

    // The marker is only cut off when it is actually there. The old code cut
    // the first character unconditionally, which is a second money error of
    // the same family as the lost sign: this dialect's "not settled" marker is
    // a blank, `parseLine` trims, and so an unsettled `  12.345` arrived here
    // as `12.345` and was read as **2.345 kg** — the leading digit eaten as if
    // it were the marker. Plausible, and wrong by ten kilos.
    final isStable = line.startsWith('\$');

    final field = _WeightField.parse(isStable ? line.substring(1) : line);
    if (field == null) return null;

    return ScalesReading(
      weight: field.value,
      unit: field.unit,
      status: isStable ? ScalesStatus.stable : ScalesStatus.unstable,
    );
  }

  List<int>? _getWeightRequestCommand() {
    return switch (protocol) {
      ScalesProtocol.generic => [0x57, 0x0D],
      ScalesProtocol.cas => [0x57, 0x0D],
      ScalesProtocol.massaK => [0x4E, 0x0D],
    };
  }

  List<int>? _getTareCommand() {
    return switch (protocol) {
      ScalesProtocol.generic => [0x54, 0x0D],
      ScalesProtocol.cas => [0x54, 0x0D],
      ScalesProtocol.massaK => [0x54, 0x0D],
    };
  }

  void dispose() {
    disconnect();
    _weightController.close();
  }
}

/// Waits on [readings] for the first one a caller can act on.
///
/// Three outcomes, and they are deliberately three rather than two:
///
/// - a stable reading — returned as is;
/// - [ScalesStatus.overload] — returned **immediately**, without burning the
///   whole [timeout]. Over capacity is a fact the scale already knows and
///   reports; waiting ten seconds and then saying "вес не установился" tells
///   the cashier to keep waiting for something that will never happen;
/// - nothing settled in time — and here the message says *which* silence it
///   was. A scale that streamed readings the whole time but never settled is
///   a working scale with a moving load; a scale that sent nothing at all is a
///   wiring, baud-rate or protocol problem. Both used to produce the same
///   «Таймаут ожидания стабильного веса», so every caller that wanted to tell
///   them apart had to listen to the stream itself in parallel — which
///   `device_check_local.dart` does to this day.
///
/// A free function over a stream, not a private step of
/// [ScalesService.requestWeight], so that all three outcomes can be proved
/// without a serial port to open.
Future<ScalesReading> awaitSettledReading(
  Stream<ScalesReading> readings,
  Duration timeout,
) async {
  ScalesReading? lastHeard;
  final settled = Completer<ScalesReading>();

  final subscription = readings.listen((reading) {
    if (reading.hasError) return;
    lastHeard = reading;
    if (settled.isCompleted) return;
    if (reading.status == ScalesStatus.overload) {
      settled.complete(
        ScalesReading.error(
          'Перегрузка весов: вес превышает предел взвешивания',
          status: ScalesStatus.overload,
        ),
      );
    } else if (reading.isStable) {
      settled.complete(reading);
    }
  }, onError: (Object _) {});

  try {
    return await settled.future.timeout(timeout);
  } on TimeoutException {
    final waited = timeout.inSeconds >= 1
        ? '${timeout.inSeconds} с'
        : '${timeout.inMilliseconds} мс';
    final heard = lastHeard;
    if (heard == null) {
      return ScalesReading.error(
        'Весы не прислали ни одного показания за $waited',
      );
    }
    return ScalesReading.error(
      'Вес не установился за $waited. '
      'Последнее показание: ${heard.weight} ${heard.unit.name}',
    );
  } finally {
    await subscription.cancel();
  }
}

enum ScalesProtocol { generic, cas, massaK }

enum WeightUnit { kg, g, lb }

/// What the scale says about the reading, in the scale's own terms.
///
/// Three values, not a boolean. A boolean forces everything that is not
/// "settled" into "still moving", and over capacity is not a transient state
/// that waiting cures — it is a refusal, and it has to be reportable as one.
enum ScalesStatus { stable, unstable, overload }

/// One weight field lifted off the wire: the value with its sign, and the
/// unit that followed it.
///
/// The single place a serial weight becomes a [Decimal]. All three dialects
/// go through it, because all three right-justify the number inside a
/// fixed-width slot and all three can therefore pad between the sign and the
/// digits.
class _WeightField {
  const _WeightField(this.value, this.unit);

  final Decimal value;
  final WeightUnit unit;

  /// The shape a weight actually arrives in.
  ///
  /// `[ \t]*` between sign and digits is the whole point. A CAS scale writes
  /// a returned half-kilo as `-  0.500kg`: the sign is parked at the left
  /// edge of the numeric slot and the digits are pushed right. An expression
  /// that demands the sign touch the digits does not fail — it matches from
  /// the digits onward and reports `+0.500` for a `-0.500` reading, which is
  /// a refund booked as a sale.
  ///
  /// Only spaces and tabs, never `\s`: a `\s*` could reach across a line
  /// break and pick up the sign of the previous frame.
  static final RegExp _pattern = RegExp(
    r'(?<sign>[+-])?[ \t]*(?<num>\d+[.,]\d+)[ \t]*(?:(?<unit>kg|lb|g)s?\b)?',
    caseSensitive: false,
  );

  static _WeightField? parse(String text) {
    final match = _pattern.firstMatch(text);
    if (match == null) return null;

    // Reassembled from separate groups rather than stripped out of one blob.
    // Both would work here, but `Decimal.tryParse` rejects any internal
    // whitespace outright — measured: `Decimal.tryParse('-  0.500')` is
    // `null` — so widening the expression without also removing the padding
    // would trade a wrong sign for a dropped reading. Two groups make it
    // impossible to weld two adjacent numbers into one by accident.
    final sign = match.namedGroup('sign') ?? '';
    final digits = match.namedGroup('num')!.replaceAll(',', '.');

    final value = Decimal.tryParse('$sign$digits');
    if (value == null) return null;

    return _WeightField(value, _unitOf(match.namedGroup('unit')));
  }

  /// The unit the scale actually stated. Kilograms only when it stated
  /// nothing — assuming kilograms over a stated `g` turns 500 g into 500 kg.
  static WeightUnit _unitOf(String? token) {
    return switch (token?.toLowerCase()) {
      'g' => WeightUnit.g,
      'lb' => WeightUnit.lb,
      _ => WeightUnit.kg,
    };
  }
}

class ScalesReading {
  const ScalesReading({
    required this.weight,
    this.unit = WeightUnit.kg,
    this.status = ScalesStatus.unstable,
    this.isManual = false,
    this.errorMessage,
  });

  final Decimal weight;

  final WeightUnit unit;

  final ScalesStatus status;

  bool get isStable => status == ScalesStatus.stable;

  bool get isOverload => status == ScalesStatus.overload;

  final bool isManual;

  final String? errorMessage;

  bool get hasError => errorMessage != null;

  Decimal get weightKg {
    return switch (unit) {
      WeightUnit.kg => weight,
      WeightUnit.g => Decimal.parse(
        (weight / Decimal.fromInt(1000))
            .toDecimal(scaleOnInfinitePrecision: 6)
            .toString(),
      ),
      WeightUnit.lb => weight * Decimal.parse('0.453592'),
    };
  }

  factory ScalesReading.error(
    String message, {
    ScalesStatus status = ScalesStatus.unstable,
  }) {
    return ScalesReading(
      weight: Decimal.zero,
      status: status,
      errorMessage: message,
    );
  }

  @override
  String toString() {
    if (hasError) return 'Error: $errorMessage';
    final manual = isManual ? ' [manual]' : '';
    return '${weight.toStringAsFixed(3)} ${unit.name} (${status.name})$manual';
  }
}

class ScalesConnectResult {
  const ScalesConnectResult({required this.success, this.errorMessage});

  final bool success;
  final String? errorMessage;

  factory ScalesConnectResult.success() =>
      const ScalesConnectResult(success: true);
  factory ScalesConnectResult.failure(String message) =>
      ScalesConnectResult(success: false, errorMessage: message);
}
