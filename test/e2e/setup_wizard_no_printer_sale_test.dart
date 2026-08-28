library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/services/global_product_import_service.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';

import 'support/harness.dart';

/// Fix round 1 (2026-07-30), И30: the setup wizard used to write its
/// equipment step into the `hardware_settings` blob — a key nothing reads
/// anymore. This is the sequencing defect the coordinator identified: the
/// reader was deleted in one task, the writer's rewrite was left for a
/// later one, so in between, a **brand-new** installation running the real
/// wizard got no device bindings at all. `test/e2e/no_printer_binding_sale_test.dart`
/// already proves a sale completes with no printer bound; this file proves
/// the same claim through the actual wizard commit path
/// (`SetupRepository.completeSetup`), not an empty database that happens to
/// look the same.
///
/// Uses `E2eHarness(seedData: false)` — the harness's own fixture data is
/// skipped so `completeSetup` is the only thing that creates the
/// installation, exactly as a real first boot would.
void main() {
  final h = E2eHarness();

  setUpAll(() => h.setUp(seedData: false));
  tearDownAll(() => h.tearDown());

  Future<void> render(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> tapText(WidgetTester t, String text, {bool last = false}) async {
    final f = find.text(text);
    if (f.evaluate().isEmpty) {
      throw TestFailure('tap target not found: "$text"');
    }
    await t.tap(last ? f.last : f.first);
    await render(t);
  }

  Future<void> tapButton(WidgetTester t, String text) async {
    final byType = find.byWidgetPredicate(
      (w) =>
          (w is ElevatedButton ||
          w is FilledButton ||
          w is TextButton ||
          w is OutlinedButton),
    );
    final f = find.descendant(of: byType, matching: find.text(text));
    if (f.evaluate().isEmpty) {
      await tapText(t, text, last: true);
      return;
    }
    await t.tap(f.last);
    await render(t);
  }

  Future<int> completedSaleCount() async {
    final rows = await h.db
        .customSelect('SELECT COUNT(*) AS c FROM sales WHERE state = 1')
        .get();
    return rows.first.read<int>('c');
  }

  testWidgets('a sale completes when the wizard configured no printer (И30)', (
    t,
  ) async {
    // The real wizard commit path — SetupDraft with the printer step
    // explicitly OFF, the same shape the actual first-launch screens hand
    // over, not a shortcut through seed().
    const draft = SetupDraft(
      countryIndex: 0,
      operatingModeIndex: 0,
      organization: OrganizationInfo(
        companyName: 'ТОО ТестПОС',
        taxId: '123456789012',
      ),
      posConfig: PosConfigInfo(cashBoxName: 'Касса-1'),
      fiscalConfig: FiscalConfigInfo(),
      businessRules: BusinessRulesConfigInfo(),
      equipment: EquipmentConfigInfo(printerEnabled: false),
      paymentTerminal: PaymentTerminalConfigInfo(),
      employees: [],
      firstUser: EmployeeInfo(),
    );

    // completeSetup's last step imports the real 100k+ product global
    // catalog bundled as an asset (GlobalProductImportService,
    // `lib/data/services/global_product_import_service.dart`) — real,
    // slow, and irrelevant to this test (`E2eHarness.setUp` registers it
    // for real, unlike the plain-Dart unit tests in
    // `setup_repository_device_bindings_test.dart`, which never register
    // it at all). Unregistering it here makes `_importGlobalProducts`
    // hit its own existing "service not available" catch — already
    // proven harmless — instead of actually importing tens of thousands
    // of rows this test does not need.
    if (GetIt.I.isRegistered<GlobalProductImportService>()) {
      GetIt.I.unregister<GlobalProductImportService>();
    }

    await GetIt.I<SetupRepository>().completeSetup(draft);

    expect(
      GetIt.I.isRegistered<PrinterManager>(),
      isFalse,
      reason:
          'hardware_module already resolved once, before this wizard run '
          '(configureDependencies runs on an empty database ahead of any '
          'test body — E2eHarness.setUp\'s doc comment). This asserts the '
          'wizard\'s printer-disabled step did not somehow register one; '
          'test/unit/data/setup_repository_device_bindings_test.dart '
          'proves the persisted-binding half directly.',
    );

    // completeSetup's own catalog import needs network access this test
    // environment does not have (and fails harmlessly, logged, non-fatal)
    // — seed a sellable product and a cashier directly, same as
    // E2eHarness.seed does for every other e2e test, so the sale itself
    // has something to work with.
    final db = h.db;
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: const Value(1),
            name: const Value('Продукты'),
            createTime: DateTime.now(),
          ),
        );
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: const Value(9001),
            barcode: const Value(4609001),
            name: const Value('Тестовый товар'),
            type: const Value(0),
            measure: const Value(0),
            quantity: Value(Decimal.parse('100')),
            categoryId: const Value(1),
            isDeleted: const Value(false),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion(
            ucode: const Value(9001),
            barcode: const Value(4609001),
            sellingPrice: Value(Decimal.parse('500')),
            wholesalePrice: Value(Decimal.parse('500')),
          ),
        );
    final cashierId = await db.userDao.createCashier(
      name: E2eHarness.cashierName,
      passwordEnc: null,
    );
    // Задача 14: `createCashier` строк прав не пишет, а после переворота
    // умолчания (задача 16) пустая таблица означает «ничего нельзя».
    // Права заводятся тем же вызовом, каким это делает рабочий код.
    await db.userPermissionDao.setPermissions(cashierId, {
      for (final key in PermissionKeys.allPermissions) key: true,
    });

    await h.pumpApp(t);
    await t.pump(const Duration(seconds: 1));
    await h.loginAsCashier(t);
    await render(t);

    h.router!.go('/shift');
    await render(t);
    await tapText(t, 'Открыть смену');
    await t.enterText(find.byType(TextField).last, '50000');
    await render(t);
    await tapButton(t, 'Открытие смены');
    await render(t);

    final before = await completedSaleCount();

    h.router!.go('/sale');
    await render(t);
    await t.enterText(find.byType(TextField).first, '4609001');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await render(t);

    await tapText(t, 'ОПЛАТИТЬ');
    final denom = find.text('1K');
    if (denom.evaluate().isNotEmpty) {
      await t.tap(denom.first);
      await render(t);
    }
    await tapText(t, 'ОПЛАТИТЬ', last: true);
    await render(t);
    await t.pump(const Duration(seconds: 1));

    final after = await completedSaleCount();

    expect(
      after,
      greaterThan(before),
      reason:
          'A sale must complete even though the wizard configured no '
          'printer at all — a missing device must never block taking '
          'money (И30).',
    );

    expect(GetIt.I.isRegistered<PrinterManager>(), isFalse);
  });
}
