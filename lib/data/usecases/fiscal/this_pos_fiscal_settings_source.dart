import 'package:decimal/decimal.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';

class ThisPosFiscalSettingsSource implements FiscalSettingsSource {
  ThisPosFiscalSettingsSource({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  @override
  Future<FiscalSettings> load() async {
    final pos = await _db.thisPosDao.get();
    if (pos == null) return FiscalSettings.disabled();

    final hasWebkassa =
        pos.sendToOfd && (pos.webkassaToken?.isNotEmpty ?? false);
    if (!hasWebkassa) return FiscalSettings.disabled();

    return FiscalSettings(
      operatorType: FiscalOperatorType.webkassa,
      testMode: false,
      baseUrl: pos.webkassaHost,
      isVatPayer: pos.isVatPayer,
      vatRatePercent: _defaultRate(pos.countryCode),
      printVatOnReceipt: pos.printVatOnReceipt,
    );
  }

  Decimal _defaultRate(int? countryCode) => FiscalDefaults.vatRatePercent;
}
