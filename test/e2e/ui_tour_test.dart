library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

Future<void> dismissModals(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    final navs = find.byType(Navigator).evaluate();
    if (navs.isEmpty) break;
    final rootNav = tester.state<NavigatorState>(find.byType(Navigator).first);
    if (!rootNav.canPop()) break;
    rootNav.pop();
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  final h = E2eHarness();

  setUpAll(() => h.setUp());
  tearDownAll(() => h.tearDown());

  const routes = <(String, String)>[
    ('/sale', '03_sale'),
    ('/payment', '04_payment'),
    ('/refund', '05_refund'),
    ('/shift', '06_shift'),
    ('/history', '07_history'),
    ('/catalog', '08_catalog'),
    ('/reports', '09_reports'),
    ('/agent', '10_customers'),
    ('/supply', '11_supply'),
    ('/stock-registry', '12_stock_registry'),
    ('/movement', '13_movement'),
    ('/supplier-return', '14_supplier_return'),
    ('/cash-operation', '15_cash_operation'),
    ('/writeoff', '16_writeoff'),
    ('/inventory', '17_inventory'),
    ('/sync', '18_sync'),
    ('/additional', '19_additional'),
    ('/tables', '20_restaurant_tables'),
    ('/orders', '21_restaurant_orders'),
    ('/service-queue', '22_service_queue'),
    ('/service-intake', '23_service_intake'),
    ('/service-catalog', '24_service_catalog'),
    ('/wms', '25_wms_dashboard'),
    ('/wms-warehouses', '26_wms_warehouses'),
    ('/wms-batches', '27_wms_batches'),
    ('/wms-serials', '28_wms_serials'),
    ('/wms-cell-stock', '29_wms_cell_stock'),
    ('/wms-claims', '30_wms_claims'),
    ('/wms-marking', '31_wms_marking'),
    ('/wms-settings', '32_wms_settings'),
    ('/transport-settings', '33_transport_settings'),
    ('/printer-settings', '34_printer_settings'),
    ('/fiscal-settings', '35_fiscal_settings'),
    ('/restaurant-settings', '36_restaurant_settings'),
    ('/hardware-settings', '37_hardware_settings'),
    ('/appliance-settings', '38_appliance_settings'),
    ('/accounts-settings', '39_accounts_settings'),
    ('/user-management', '40_user_management'),
    ('/telegram-settings', '41_telegram_settings'),
    ('/settings', '42_general_settings'),
  ];

  Future<void> render(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 400));
  }

  final report = <String>[];

  void inspect(WidgetTester tester, String label) {
    final ex = tester.takeException();
    final hasErrorWidget = find.byType(ErrorWidget).evaluate().isNotEmpty;
    final textCount = find.byType(Text).evaluate().length;
    final buttons = find
        .byWidgetPredicate(
          (w) =>
              w is ElevatedButton ||
              w is FilledButton ||
              w is OutlinedButton ||
              w is TextButton ||
              w is IconButton,
        )
        .evaluate()
        .length;
    final flags = <String>[];
    if (ex != null) flags.add('EXCEPTION: $ex');
    if (hasErrorWidget) flags.add('ERROR_WIDGET');
    if (textCount < 3) flags.add('NEARLY_EMPTY(text=$textCount)');
    report.add(
      '$label | text=$textCount buttons=$buttons '
      '${flags.isEmpty ? "ok" : flags.join(" ; ")}',
    );
  }

  testWidgets('UI tour — capture every screen', (tester) async {
    await h.pumpApp(tester);
    await tester.pump(const Duration(seconds: 1));

    await render(tester);
    inspect(tester, '01_login');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('tour/01_login.png'),
    );

    final loggedIn = await h.loginAsCashier(tester);
    await render(tester);
    report.add('login.success=$loggedIn');

    inspect(tester, '02_after_login');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('tour/02_after_login.png'),
    );

    for (final r in routes) {
      try {
        h.router!.go(r.$1);
      } catch (e) {
        report.add('${r.$2} | NAVIGATE_THREW: $e');
      }
      await render(tester);
      inspect(tester, r.$2);
      try {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('tour/${r.$2}.png'),
        );
      } catch (e) {
        report.add('${r.$2} | GOLDEN_FAILED: $e');
      }
      await dismissModals(tester);
    }

    h.router!.go('/settings');
    await render(tester);

    // ignore: avoid_print
    print('\n===== UI TOUR REPORT =====');
    for (final line in report) {
      // ignore: avoid_print
      print('[tour] $line');
    }
    // ignore: avoid_print
    print('===== END UI TOUR REPORT =====\n');
  });
}
