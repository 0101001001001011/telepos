import 'package:meta/meta.dart';

/// The three И142 barcode rules — how long an accepted barcode may be, and
/// how long a keyboard-wedge scanner's inter-character gap may grow before
/// the accumulated buffer counts as a finished barcode.
///
/// **Not device settings, and deliberately not on `DeviceBinding`/
/// `DeviceProfile`** (И141 vs И142): every HID scanner sends characters the
/// same way regardless of manufacturer, and none of these three values takes
/// part in addressing a device. They decide *which read value to accept* —
/// an installation-wide business rule. That is why they live on
/// `ThisPosEntries` (`lib/data/database/tables/this_pos_tables.dart`,
/// schema v27 for the two lengths, v28 for [scannerTimeoutMs]) and why this
/// contract exists separately from `DeviceBindingRepository`.
///
/// **Why a contract at all** (plan 2b, task 3): schema v28 gave
/// `scannerTimeoutMs` a column, a migration carrying the legacy
/// `hardware_settings` value forward, and a live reader
/// (`lib/presentation/common/mixins/barcode_scanner_mixin.dart`) — but no
/// writer. An operator could not set any of the three from anywhere in the
/// interface, which fails the rule that everything is configured from the
/// interface (docs/system-architecture.md, section 8 and section 20). The
/// settings screen that writes them must not import `lib/data/` (И5), so
/// "add a control" and "add a domain contract to write through" are the same
/// piece of work.
@immutable
class ScannerRules {
  /// Throws [ArgumentError] rather than silently accepting a pair that can
  /// never match anything (min above max) or a bound the decoder cannot act
  /// on. Validated here, in the domain, so both the settings screen and any
  /// other future writer get the same answer — this is the second of the
  /// four validation levels in docs/system-architecture.md, not a UI
  /// convenience.
  ScannerRules({
    required this.barcodeMinLength,
    required this.barcodeMaxLength,
    required this.scannerTimeoutMs,
  }) {
    if (barcodeMinLength != null && barcodeMinLength! < 1) {
      throw ArgumentError.value(
        barcodeMinLength,
        'barcodeMinLength',
        'Минимальная длина штрихкода должна быть не меньше 1',
      );
    }
    if (barcodeMaxLength != null && barcodeMaxLength! < 1) {
      throw ArgumentError.value(
        barcodeMaxLength,
        'barcodeMaxLength',
        'Максимальная длина штрихкода должна быть не меньше 1',
      );
    }
    if (barcodeMinLength != null &&
        barcodeMaxLength != null &&
        barcodeMinLength! > barcodeMaxLength!) {
      throw ArgumentError.value(
        barcodeMinLength,
        'barcodeMinLength',
        'Минимальная длина штрихкода больше максимальной '
            '($barcodeMinLength > $barcodeMaxLength) — такому правилу не '
            'удовлетворяет ни один штрихкод',
      );
    }
    if (scannerTimeoutMs != null && scannerTimeoutMs! < 1) {
      throw ArgumentError.value(
        scannerTimeoutMs,
        'scannerTimeoutMs',
        'Промежуток между символами сканера должен быть не меньше 1 мс',
      );
    }
  }

  /// `null` means "never set" — the reader falls back to
  /// [defaultBarcodeMinLength]. Kept distinct from the default value itself
  /// so an installation that has never configured this is distinguishable
  /// from one that deliberately set the same number.
  final int? barcodeMinLength;

  final int? barcodeMaxLength;

  /// Milliseconds — the unit is in the name, per plan 2's lesson about
  /// `paperWidth` holding characters while being compared with millimetres.
  final int? scannerTimeoutMs;

  /// The values the live keyboard-wedge decoder falls back to when a rule is
  /// unset. Declared here, in the domain, and read by that decoder
  /// (`lib/presentation/common/mixins/barcode_scanner_mixin.dart`) so the
  /// number a settings screen shows as "по умолчанию" cannot drift away from
  /// the number the decoder actually uses — two copies of a default is the
  /// plausible-wrong-value shape this project keeps getting bitten by.
  static const int defaultBarcodeMinLength = 4;
  static const int defaultBarcodeMaxLength = 30;
  static const int defaultScannerTimeoutMs = 80;

  /// Every rule unset — what an installation that has never configured them
  /// reads back.
  static ScannerRules get unset => ScannerRules(
    barcodeMinLength: null,
    barcodeMaxLength: null,
    scannerTimeoutMs: null,
  );

  int get effectiveBarcodeMinLength =>
      barcodeMinLength ?? defaultBarcodeMinLength;
  int get effectiveBarcodeMaxLength =>
      barcodeMaxLength ?? defaultBarcodeMaxLength;
  int get effectiveScannerTimeoutMs =>
      scannerTimeoutMs ?? defaultScannerTimeoutMs;

  @override
  String toString() =>
      'ScannerRules(barcodeMinLength: $barcodeMinLength, '
      'barcodeMaxLength: $barcodeMaxLength, '
      'scannerTimeoutMs: $scannerTimeoutMs)';
}

/// Читает правила — и только читает. Задача 45.
///
/// Тому, кто **применяет** правила к скану (`BarcodeScannerMixin` — продажа
/// и возврат), запись не нужна: сузить договор до чтения значит, что такой
/// читатель не может записать их даже по ошибке.
///
/// **Вторая половина прежнего довода снята пунктом 11 ревизии 2026-09-19.**
/// Она гласила, что на браузерном терминале записи «и нет»: правила —
/// настройка кассы. Это перестало быть правдой — запись есть
/// (`TillOps.scannerRulesSave`, право `settings.hardware`), и
/// `WtScannerRules` реализует [ScannerRulesRepository] целиком. Довод
/// оставлен здесь названным, а не стёрт: следующий читатель иначе решит,
/// что разделение заведено зря.
abstract interface class ScannerRulesReader {
  Future<ScannerRules> read();
}

/// Reads and writes the installation's [ScannerRules].
///
/// [save] writes all three at once, deliberately: they are edited together
/// on one form and their validity is a property of the triple (min ≤ max),
/// not of each value alone. A per-field setter would let a caller step
/// through an invalid intermediate state and persist it.
abstract interface class ScannerRulesRepository implements ScannerRulesReader {
  @override
  Future<ScannerRules> read();

  /// Throws [ArgumentError] if [rules] does not validate — the same check
  /// [ScannerRules]' constructor makes, repeated at the storage boundary so
  /// an implementation handed a hand-built instance cannot write nonsense.
  Future<void> save(ScannerRules rules);
}
