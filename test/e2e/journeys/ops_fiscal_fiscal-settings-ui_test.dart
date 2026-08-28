library;

import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/data/fiscal/fiscal_settings_store.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_provider_registry.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/presentation/controllers/settings/fiscal_settings_controller.dart';

class _FakeWebkassaProvider implements FiscalProvider {
  _FakeWebkassaProvider(this.config);
  final FiscalSettings config;

  @override
  String get id => FiscalOperatorType.webkassa.id;

  @override
  FiscalCapabilities get capabilities =>
      const FiscalCapabilities(implicitShift: true, supportsLocalModule: true);

  @override
  String? validateConfig(FiscalSettings c) {
    if ((c.apiKey ?? '').isEmpty) return 'Не указан X-API-Key';
    if ((c.login ?? '').isEmpty) return 'Не указан логин';
    return null;
  }

  @override
  Future<FiscalAuthResult> authorize(FiscalSettings config) async =>
      FiscalAuthResult.ok(token: 'tok');
  @override
  Future<FiscalResult> fiscalizeSale(FiscalSaleRequest req) async =>
      FiscalResult.ok(fiscalSign: 'WK-${req.localOperationId}');
  @override
  Future<FiscalResult> fiscalizeRefund(FiscalRefundRequest req) async =>
      FiscalResult.ok(fiscalSign: 'WK-R');
  @override
  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req) async =>
      FiscalResult.ok(fiscalSign: 'WK-P');
  @override
  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req) async =>
      FiscalResult.ok(fiscalSign: 'WK-PR');
  @override
  Future<FiscalResult> moneyIn(FiscalMoneyRequest req) async =>
      FiscalResult.ok(fiscalSign: 'WK-IN');
  @override
  Future<FiscalResult> moneyOut(FiscalMoneyRequest req) async =>
      FiscalResult.ok(fiscalSign: 'WK-OUT');
  @override
  Future<FiscalResult> openShift(FiscalShiftRequest req) async =>
      const FiscalResult(success: true);
  @override
  Future<FiscalReportResult> closeShift(FiscalShiftRequest req) async =>
      const FiscalReportResult(result: FiscalResult(success: true));
  @override
  Future<FiscalReportResult> xReport(FiscalShiftRequest req) async =>
      const FiscalReportResult(result: FiscalResult(success: true));
  @override
  Future<FiscalResult> correctionReceipt(FiscalCorrectionRequest req) async =>
      FiscalResult.unsupported('correctionReceipt');
  @override
  Future<FiscalStatus> getStatus() async =>
      const FiscalStatus(configured: true, active: true, online: true);
}

ProviderContainer _container(SharedPreferences prefs) {
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      fiscalProviderRegistryProvider.overrideWith((ref) {
        final r = FiscalProviderRegistry();
        r.register(FiscalOperatorType.webkassa, _FakeWebkassaProvider.new);
        return r;
      }),
    ],
  );
}

FiscalSaleRequest _sampleSale() => FiscalSaleRequest(
  idempotencyKey: 'idem-1',
  localOperationId: 42,
  positions: const [],
  payments: const [],
  totalDiscount: Decimal.zero,
  totalMarkup: Decimal.zero,
  occurredAt: DateTime(2026, 6, 1),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'default is none -> POS usable offline: NoOp provider, sale never blocks',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final c = _container(prefs);
      addTearDown(c.dispose);

      final state = c.read(fiscalSettingsControllerProvider);
      expect(state.settings.operatorType, FiscalOperatorType.none);
      expect(state.settings.isEnabled, isFalse);

      final ctrl = c.read(fiscalSettingsControllerProvider.notifier);
      final provider = ctrl.resolveProvider();
      expect(provider.id, 'noop', reason: 'none resolves to NoOp');

      final r = await provider.fiscalizeSale(_sampleSale());
      expect(
        r.queued,
        isTrue,
        reason: 'sale completes locally, fiscal deferred',
      );
      expect(r.hasFiscalSign, isFalse);

      expect(await ctrl.save(), isTrue);
    },
  );

  test('select WebKassa + creds -> persist -> reload reflects every field & '
      'operator-default base URL', () async {
    final prefs = await SharedPreferences.getInstance();
    final c = _container(prefs);
    addTearDown(c.dispose);

    final ctrl = c.read(fiscalSettingsControllerProvider.notifier);

    ctrl.selectOperator(FiscalOperatorType.webkassa);
    var working = c.read(fiscalSettingsControllerProvider).settings;
    expect(working.operatorType, FiscalOperatorType.webkassa);
    expect(
      working.baseUrl,
      'https://devkkm.webkassa.kz',
      reason: 'operator-default test URL applied on select',
    );

    ctrl.update(
      working.copyWith(
        login: 'cashier@shop.kz',
        password: 's3cret',
        apiKey: 'X-API-KEY-123',
        cashboxUniqueNumber: 'SWK00033717',
        registrationNumber: 'РНМ-998877',
        localModuleUrl: FiscalDefaults.localModuleUrl,
        isVatPayer: true,
        vatRatePercent: Decimal.parse('12'),
      ),
    );

    expect(await ctrl.save(), isTrue, reason: 'valid WebKassa config saves');
    expect(prefs.getString(FiscalSettingsStore.prefsKey), isNotNull);

    final c2 = _container(prefs);
    addTearDown(c2.dispose);
    final reloaded = c2.read(fiscalSettingsControllerProvider).settings;
    expect(reloaded.operatorType, FiscalOperatorType.webkassa);
    expect(reloaded.login, 'cashier@shop.kz');
    expect(reloaded.password, 's3cret');
    expect(reloaded.apiKey, 'X-API-KEY-123');
    expect(reloaded.cashboxUniqueNumber, 'SWK00033717');
    expect(reloaded.registrationNumber, 'РНМ-998877');
    expect(reloaded.baseUrl, 'https://devkkm.webkassa.kz');
    expect(reloaded.localModuleUrl, FiscalDefaults.localModuleUrl);
    expect(reloaded.isVatPayer, isTrue);
    expect(reloaded.vatRatePercent, Decimal.parse('12'));

    final provider = c2
        .read(fiscalSettingsControllerProvider.notifier)
        .resolveProvider();
    expect(provider.id, FiscalOperatorType.webkassa.id);
    final sale = await provider.fiscalizeSale(_sampleSale());
    expect(sale.success, isTrue);
    expect(sale.fiscalSign, 'WK-42');
  });

  test('switching operator changes the resolved provider', () async {
    final prefs = await SharedPreferences.getInstance();
    final c = _container(prefs);
    addTearDown(c.dispose);
    final ctrl = c.read(fiscalSettingsControllerProvider.notifier);

    ctrl.selectOperator(FiscalOperatorType.webkassa);
    ctrl.update(
      c
          .read(fiscalSettingsControllerProvider)
          .settings
          .copyWith(login: 'u', apiKey: 'k'),
    );
    expect(ctrl.resolveProvider().id, FiscalOperatorType.webkassa.id);

    ctrl.selectOperator(FiscalOperatorType.kassa24);
    expect(
      ctrl.resolveProvider().id,
      'noop',
      reason: 'unregistered operator falls back to NoOp (offline-first)',
    );

    ctrl.selectOperator(FiscalOperatorType.none);
    expect(ctrl.resolveProvider().id, 'noop');
  });

  test(
    'validation blocks save for incomplete WebKassa creds (none never does)',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final c = _container(prefs);
      addTearDown(c.dispose);
      final ctrl = c.read(fiscalSettingsControllerProvider.notifier);

      ctrl.selectOperator(FiscalOperatorType.webkassa);
      ctrl.update(
        c.read(fiscalSettingsControllerProvider).settings.copyWith(login: 'u'),
      );
      expect(await ctrl.save(), isFalse);
      expect(
        c.read(fiscalSettingsControllerProvider).validationError,
        isNotNull,
      );
      expect(
        prefs.getString(FiscalSettingsStore.prefsKey),
        isNull,
        reason: 'invalid config not persisted',
      );

      ctrl.selectOperator(FiscalOperatorType.none);
      expect(await ctrl.save(), isTrue);
    },
  );

  test(
    'store: corrupt prefs blob loads as disabled (never breaks the POS)',
    () async {
      SharedPreferences.setMockInitialValues({
        FiscalSettingsStore.prefsKey: 'not-json{',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = FiscalSettingsStore(prefs);
      final loaded = store.load();
      expect(loaded.operatorType, FiscalOperatorType.none);
      expect(loaded.isEnabled, isFalse);
    },
  );

  test('store: raw JSON round-trip keeps operator + Decimal НДС', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = FiscalSettingsStore(prefs);

    final settings = FiscalSettings(
      operatorType: FiscalOperatorType.kassa24,
      testMode: false,
      login: 'shop',
      cashboxUniqueNumber: 'ZNM-1',
      vatRatePercent: Decimal.parse('16'),
    );
    expect(await store.save(settings), isTrue);

    final raw = prefs.getString(FiscalSettingsStore.prefsKey)!;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    expect(json['operatorType'], FiscalOperatorType.kassa24.value);
    expect(json['vatRatePercent'], '16');

    final back = store.load();
    expect(back.operatorType, FiscalOperatorType.kassa24);
    expect(back.testMode, isFalse);
    expect(back.vatRatePercent, Decimal.parse('16'));
  });
}
