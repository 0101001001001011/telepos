library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/supply/supply_screen.dart';
import 'package:telepos/presentation/screens/writeoff/writeoff_screen.dart';
import 'package:telepos/presentation/screens/wms/marking_codes_screen.dart';
import 'package:telepos/presentation/screens/wms/warehouse_management_screen.dart';
import 'package:telepos/presentation/screens/wms/wms_dashboard_screen.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();

  const localizationDelegates = <LocalizationsDelegate<Object?>>[
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  Future<GoRouter> pumpScreen(WidgetTester tester, Widget screen) async {
    final router = GoRouter(
      initialLocation: '/screen',
      routes: [
        GoRoute(path: '/screen', builder: (_, __) => screen),
        GoRoute(
          path: '/stock-registry',
          builder: (_, __) => const Scaffold(body: Text('STOCK_REGISTRY')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: router,
          supportedLocales: AppLocale.supportedLocales,
          locale: const Locale('ru'),
          localizationsDelegates: localizationDelegates,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<int> seedSupplier(AppDatabase db, {String name = 'ТОО Поставщик'}) {
    return db
        .into(db.agents)
        .insert(
          AgentsCompanion.insert(
            type: const Value(0),
            name: Value(name),
            isDeleted: const Value(false),
            editTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
          ),
        );
  }

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
    await seedSupplier(h.db);
  });
  tearDownAll(() => h.tearDown());

  void ignoreOverflowErrors() {
    final original = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final msg = details.exceptionAsString();
      if (msg.contains('A RenderFlex overflowed')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  void useMobileView(WidgetTester tester) {
    tester.view.physicalSize = const Size(440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  void useDesktopView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('WMS journey', () {
    testWidgets('Supply: create via UI persists to DB (create + read)', (
      tester,
    ) async {
      ignoreOverflowErrors();
      useMobileView(tester);
      await pumpScreen(tester, const SupplyScreen());

      expect(
        find.text('Приёмка товара'),
        findsWidgets,
        reason: 'Supply screen title (supplyTitle) should render',
      );

      await tester.tap(find.text('Выберите поставщика'));
      await tester.pumpAndSettle();
      final supplierTile = find.text('ТОО Поставщик');
      expect(
        supplierTile,
        findsWidgets,
        reason: 'Seeded supplier must appear in selection dialog',
      );
      await tester.tap(supplierTile.first);
      await tester.pumpAndSettle();

      final consignment = find.text('Консигнация');
      expect(
        consignment,
        findsOneWidget,
        reason: 'Consignment payment-type option must be present',
      );
      await tester.tap(consignment);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '4607001');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(TeleposIcons.add).first);
      await tester.pumpAndSettle();

      expect(
        find.text('Молоко 1л'),
        findsWidgets,
        reason: 'Add-product dialog should show the resolved product',
      );
      final addConfirm = find.text('Добавить');
      expect(
        addConfirm,
        findsOneWidget,
        reason: 'Calculator confirm "Добавить" must be present',
      );
      await tester.tap(addConfirm);
      await tester.pumpAndSettle();

      expect(
        find.text('Молоко 1л'),
        findsWidgets,
        reason: 'Added product must appear in the supply list',
      );

      final saveBtns = find.widgetWithText(TextButton, 'Сохранить');
      expect(saveBtns, findsWidgets, reason: 'Save action must be present');
      await tester.tap(saveBtns.first);
      await tester.pumpAndSettle();

      final supplies = await h.db.supplyDao.findAll();
      expect(
        supplies,
        isNotEmpty,
        reason: 'Supply must persist a row in `supplies`',
      );
      expect(
        supplies.first.amount,
        equals(Decimal.parse('450')),
        reason: 'Supply total must be exact (qty 1 x 450)',
      );
      final sp = await (h.db.select(
        h.db.supplyProducts,
      )..where((p) => p.supplyId.equals(supplies.first.id))).get();
      expect(sp, isNotEmpty, reason: 'SupplyProducts must persist the line');
      expect(sp.first.ucode, 1001);
    });

    testWidgets('Writeoff: create via UI persists to DB (create + read)', (
      tester,
    ) async {
      useMobileView(tester);
      await pumpScreen(tester, const WriteoffScreen());

      expect(
        find.text('Списание'),
        findsWidgets,
        reason: 'Writeoff screen title should render',
      );

      await tester.enterText(find.byType(TextField).first, '4607002');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        find.text('Хлеб белый'),
        findsWidgets,
        reason: 'Writeoff should add product by barcode',
      );

      final saveBtn = find.widgetWithText(TextButton, 'Сохранить');
      expect(saveBtn, findsWidgets, reason: 'Save action must be present');
      await tester.tap(saveBtn.first);
      await tester.pumpAndSettle();

      final writeoffs = await h.db.writeoffDao.findAll();
      expect(
        writeoffs,
        isNotEmpty,
        reason: 'Writeoff must persist a row in `writeoffs`',
      );
    });

    testWidgets('Warehouse: create + EDIT persists (guards #53)', (
      tester,
    ) async {
      ignoreOverflowErrors();
      useDesktopView(tester);
      await pumpScreen(tester, const WarehouseManagementScreen());

      expect(
        find.text('Склады и ячейки'),
        findsWidgets,
        reason: 'Warehouse management (desktop) header must render',
      );

      await tester.tap(find.text('Добавить склад').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Код склада'),
        'WH1',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Наименование'),
        'Главный склад',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Создать'));
      await tester.pumpAndSettle();

      expect(
        find.text('Главный склад'),
        findsWidgets,
        reason: 'Created warehouse must show in the list',
      );
      var rows = await h.db.warehouseDao.findAll();
      expect(
        rows.where((w) => w.name == 'Главный склад'),
        isNotEmpty,
        reason: 'Warehouse must persist',
      );

      final menuBtn = find.byType(PopupMenuButton<String>);
      expect(
        menuBtn,
        findsWidgets,
        reason: 'Warehouse row must expose an actions menu',
      );
      await tester.tap(menuBtn.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Редактировать').last);
      await tester.pumpAndSettle();

      final nameField = find.widgetWithText(TextField, 'Наименование');
      expect(
        nameField,
        findsOneWidget,
        reason: 'Edit dialog must render name field',
      );
      await tester.enterText(nameField, 'Склад переименован');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Сохранить'));
      await tester.pumpAndSettle();

      rows = await h.db.warehouseDao.findAll();
      expect(
        rows.where((w) => w.name == 'Склад переименован'),
        isNotEmpty,
        reason: 'Warehouse edit must persist the new name (#53)',
      );
      expect(
        rows.where((w) => w.name == 'Главный склад'),
        isEmpty,
        reason: 'Old name must be gone after edit',
      );
    });

    testWidgets('Marking codes tile opens a real screen (guards #52)', (
      tester,
    ) async {
      useMobileView(tester);
      await pumpScreen(tester, const MarkingCodesScreen());

      expect(
        find.text('Коды маркировки'),
        findsOneWidget,
        reason: 'Marking-codes screen must render its real title (#52)',
      );
      expect(
        find.text('Нет кодов маркировки'),
        findsOneWidget,
        reason: 'Empty marking list must show an honest empty-state',
      );
      expect(
        find.textContaining('в разработке'),
        findsNothing,
        reason: 'No placeholder text allowed',
      );

      await h.db
          .into(h.db.markingCodes)
          .insert(
            MarkingCodesCompanion.insert(
              code: '0104607001215AB',
              ucode: 1001,
              status: const Value(1),
              aggregationLevel: const Value(0),
            ),
          );
      await pumpScreen(tester, const MarkingCodesScreen());
      expect(
        find.text('0104607001215AB'),
        findsOneWidget,
        reason: 'Seeded marking code must be read from local DB',
      );
      expect(find.text('Нет кодов маркировки'), findsNothing);
    });

    testWidgets('WMS dashboard tiles show real counts (not "-")', (
      tester,
    ) async {
      ignoreOverflowErrors();
      await h.db.wmsConfigDao.saveConfig(
        const WmsConfigsCompanion(
          id: Value(1),
          cellStorageEnabled: Value(true),
          markingEnabled: Value(true),
        ),
      );
      await h.db.warehouseDao.insertWarehouse(
        WarehousesCompanion.insert(code: 'DASH', name: 'Склад дашборда'),
      );
      final realCount = (await h.db.warehouseDao.findAll()).length;
      expect(realCount, greaterThan(0));

      useDesktopView(tester);
      await pumpScreen(tester, const WmsDashboardScreen());

      expect(
        find.text('Склады'),
        findsWidgets,
        reason: 'Warehouses module card must render',
      );
      expect(
        find.text('$realCount'),
        findsWidgets,
        reason: 'Warehouses tile must show the REAL count ($realCount)',
      );
      expect(
        find.text('-'),
        findsNothing,
        reason: 'No tile may render a literal "-" placeholder count',
      );

      expect(
        find.text('Рекламации'),
        findsWidgets,
        reason: 'Claims module card must render with a real count badge',
      );
      expect(
        find.text('0'),
        findsWidgets,
        reason: 'Claims badge must show a real numeric count (0), not "-"',
      );
    });
  });
}
