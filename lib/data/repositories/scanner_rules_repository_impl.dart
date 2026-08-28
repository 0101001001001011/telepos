import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/repositories/scanner_rules_repository.dart';

/// [ScannerRulesRepository] over `ThisPosEntries` — the installation-wide row
/// the three И142 rules were migrated onto (schema v27 for the two lengths,
/// v28 for `scannerTimeoutMs`).
///
/// The row can legitimately not exist yet: `configureDependencies` runs
/// before the setup wizard commits anything, and a settings screen must still
/// open on an installation that has never been set up (И30). [read] answers
/// [ScannerRules.unset] in that case rather than throwing, and [save]
/// reports the honest "there is nowhere to write yet" as a [StateError]
/// instead of silently updating zero rows and returning success — the
/// silent-zero-rows shape is exactly how a settings screen ends up claiming
/// it saved something it did not.
class LocalScannerRulesRepository implements ScannerRulesRepository {
  LocalScannerRulesRepository(this._db);

  final AppDatabase _db;

  @override
  Future<ScannerRules> read() async {
    final entry = await _db.thisPosDao.get();
    if (entry == null) return ScannerRules.unset;
    return ScannerRules(
      barcodeMinLength: entry.barcodeMinLength,
      barcodeMaxLength: entry.barcodeMaxLength,
      scannerTimeoutMs: entry.scannerTimeoutMs,
    );
  }

  @override
  Future<void> save(ScannerRules rules) async {
    // Re-validates by construction: `ScannerRules`' own constructor is where
    // the rule lives, so re-running it here catches an instance built by a
    // caller that bypassed validation (a `const`-less copy, a future
    // deserializer) without duplicating the rule itself.
    ScannerRules(
      barcodeMinLength: rules.barcodeMinLength,
      barcodeMaxLength: rules.barcodeMaxLength,
      scannerTimeoutMs: rules.scannerTimeoutMs,
    );

    final updated = await _db.thisPosDao.updateScannerRules(
      barcodeMinLength: rules.barcodeMinLength,
      barcodeMaxLength: rules.barcodeMaxLength,
      scannerTimeoutMs: rules.scannerTimeoutMs,
    );
    if (updated == 0) {
      throw StateError(
        'Настройки кассы ещё не созданы — правила сканирования сохранять '
        'некуда. Завершите мастер настройки.',
      );
    }
  }
}
