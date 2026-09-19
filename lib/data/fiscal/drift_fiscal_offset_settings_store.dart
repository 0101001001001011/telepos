import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';

/// [FiscalOffsetSettingsStore] над строкой `ThisPos` (v47).
class DriftFiscalOffsetSettingsStore implements FiscalOffsetSettingsStore {
  DriftFiscalOffsetSettingsStore(this._db);

  final AppDatabase _db;

  @override
  Future<FiscalOffsetSettings> load() => _db.thisPosDao.offsetFiscalSettings();

  @override
  Future<void> save(FiscalOffsetSettings settings) async {
    final touched = await _db.thisPosDao.saveOffsetFiscalSettings(settings);
    if (touched == 0) {
      // Настройка без строки кассы не записалась бы никуда, и экран
      // показал бы «сохранено» при неизменной базе.
      throw StateError('касса не настроена: строки ThisPos нет');
    }
  }
}
