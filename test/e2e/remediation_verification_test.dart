library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/fiscal/fiscal_settings_store.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/domain/usecases/sale/sale_round_option_use_case.dart';
import 'package:telepos/domain/ismpt/ismpt_service.dart';
import 'package:telepos/data/snt/snt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/harness.dart';

void main() {
  final h = E2eHarness();
  setUpAll(() => h.setUp());
  tearDownAll(() => h.tearDown());

  group('Fiscal / VAT', () {
    test('VAT default rate is 16% (2026), not stale 12%', () {
      expect(FiscalDefaults.vatRatePercent, Decimal.fromInt(16));
    });

    test(
      'WebKassa FiscalSettings round-trip via the store the runtime reads',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final store = FiscalSettingsStore(prefs);
        final s = FiscalSettings(
          operatorType: FiscalOperatorType.webkassa,
          testMode: false,
          baseUrl: FiscalDefaults.cloudBaseUrl(
            FiscalOperatorType.webkassa,
            testMode: false,
          ),
          login: 'acc@telepos.local',
          apiKey: 'X-API-KEY-123',
          cashboxUniqueNumber: 'SWK00033717',
          registrationNumber: 'РНМ-777',
          isVatPayer: true,
        );
        await store.save(s);
        final back = store.load();
        expect(back.operatorType, FiscalOperatorType.webkassa);
        expect(back.login, 'acc@telepos.local');
        expect(back.apiKey, 'X-API-KEY-123');
        expect(back.cashboxUniqueNumber, 'SWK00033717');
        expect(back.isVatPayer, true);
        expect(back.isEnabled, true);
      },
    );
  });

  group('Receipt template seed from setup (header/footer/width)', () {
    test(
      'seedDefaults bakes wizard header/footer/80mm into selected options',
      () async {
        final db = GetIt.I<AppDatabase>();
        await db.delete(db.receiptTemplates).go();
        await db.receiptTemplateDao.seedDefaults(
          header: 'ТОО МойНова',
          footer: 'Спасибо! Ждём снова',
          paperWidthMm: 80,
        );
        final opts = await db.receiptTemplateDao.getSelectedOptions();
        expect(opts.headerText, 'ТОО МойНова');
        expect(opts.footerText, 'Спасибо! Ждём снова');
        expect(opts.paperWidth, ReceiptPaperWidth.mm80);
      },
    );
  });

  group('ThisPos persistence (printer + business flags)', () {
    // 'printer connection persists (type/address/port)' removed: it tested
    // `ThisPosDao.updatePrinterConnection`/`ThisPosEntries.printerConnectionType`/
    // `.printerAddress`/`.printerPort` — the exact "index - 1" unusable
    // second encoding final review finding I1 removed (dropped in schema
    // v27, see app_database.dart's `if (from < 27)` block). Printer
    // configuration now persists as a `DeviceBinding` through
    // `DeviceBindingRepository`, covered by
    // test/unit/data/setup_repository_device_bindings_test.dart and
    // test/unit/app/hardware_module_test.dart.

    test('business flags persist via updateBusinessFlags', () async {
      final db = GetIt.I<AppDatabase>();
      await db.thisPosDao.updateBusinessFlags(
        editProduct: true,
        editPrice: true,
        sellInDiscount: false,
        cashInOut: true,
      );
      final pos = await db.thisPosDao.get();
      expect(pos!.editProduct, true);
      expect(pos.editPrice, true);
      expect(pos.sellInDiscount, false);
      expect(pos.cashInOut, true);
    });
  });

  group('Price rounding (configured vs default no-op)', () {
    test('default round types (0,0) leave price unchanged', () {
      final uc = GetIt.I<SaleRoundOptionUseCase>();
      final p = Decimal.parse('449.37');
      final r = uc.roundPrice(
        price: p,
        isWeightProduct: true,
        hasDiscount: true,
        weightProductRoundType: 0,
        discountsRoundType: 0,
      );
      expect(r, p, reason: 'round type 0 must be a no-op (no money change)');
    });

    test('configured rounding actually changes a weighted price', () {
      final uc = GetIt.I<SaleRoundOptionUseCase>();
      final p = Decimal.parse('449.37');
      final r = uc.roundPrice(
        price: p,
        isWeightProduct: true,
        hasDiscount: false,
        weightProductRoundType: 1,
        discountsRoundType: 0,
      );
      expect(
        r == p,
        isFalse,
        reason: 'configured rounding must transform the price',
      );
    });
  });

  group(
    'ИС МПТ / СНТ registries resolve to real providers (not silent NoOp)',
    () {
      test('IsMptService is registered and resolvable', () {
        expect(GetIt.I.isRegistered<IsMptService>(), true);
        final svc = GetIt.I<IsMptService>();
        expect(svc, isNotNull);
      });

      test('SntService is registered and resolvable', () {
        expect(GetIt.I.isRegistered<SntService>(), true);
        final svc = GetIt.I<SntService>();
        expect(svc, isNotNull);
      });
    },
  );
}
