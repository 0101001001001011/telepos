/// Пробный проход главы 7 «Первая продажа и смена» — БЕЗ записи.
///
/// # Зачем
///
/// Правила студии требуют пробный проход до съёмки, и он окупался каждый
/// раз: на мастере пятью находками, на эмуляторах одной. Здесь впервые
/// снимается ЗАКРЫТИЕ смены и Z-отчёт — то есть деньги, посчитанные за
/// день, и бумага, по которой за них отчитываются.
///
/// Проход печатает, что видит на каждом шаге, и по этому списку пишется
/// дорожка.
///
/// # Запуск
///
///     flutter test integration_test/shift_dry_run_test.dart -d windows
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';

import 'package:telepos/app/di/hardware_module.dart'
    show registerHardwareServices;
import 'package:telepos/app/di/service_locator.dart' show configureDependencies;
import 'package:telepos/app/router/app_router.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/logging/app_talker.dart' as app_log;
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/host/host_capabilities.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';

Decimal _d(String v) => Decimal.parse(v);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    app_log.installLogger(Talker());
    GetIt.I.allowReassignment = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    GetIt.I.registerSingleton<AppDatabase>(db);
    GetIt.I.registerSingleton<Talker>(app_log.talker);
    GetIt.I.registerSingleton<HostCapabilities>(HostCapabilities.desktop);
    await configureDependencies(logger: app_log.talker);

    final posAccId = await db.accountDao.createPosAccount(name: 'Cash');
    final bankAccId = await db.accountDao.createAcquiringAccount(
      name: 'Card',
      acquirerId: 1,
    );
    await db.thisPosDao.insertInitialConfig(
      companyName: 'Northwind Trading',
      iinbin: '841234567',
      cashBoxName: 'Till-1',
      countryCode: 4,
      currencyCode: 4,
      currencySymbol: r'$',
      currencyNameShort: 'USD',
      paperWidth: 48,
      printerHeader: null,
      printerFooter: null,
      accountId: posAccId,
      acquiringAccountId: bankAccId,
      rsaPublicKey: null,
      sendToOfd: false,
      cashInOut: true,
    );
    final cashierId = await db.userDao.createCashier(
      name: 'Anna Whitfield',
      passwordEnc: null,
    );
    await db.userPermissionDao.setPermissions(cashierId, {
      for (final key in PermissionKeys.allPermissions) key: true,
    });

    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: const Value(1),
            name: const Value('Groceries'),
            createTime: DateTime.now(),
          ),
        );
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: const Value(1001),
            barcode: const Value(4607001),
            name: const Value('Hot coffee, large'),
            type: const Value(0),
            measure: const Value(0),
            quantity: Value(_d('100')),
            categoryId: const Value(1),
            isDeleted: const Value(false),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion(
            ucode: const Value(1001),
            barcode: const Value(4607001),
            sellingPrice: Value(_d('3.50')),
            wholesalePrice: Value(_d('3.50')),
          ),
        );

    await registerHardwareServices(GetIt.I, logger: app_log.talker);
  });

  tearDownAll(() async => db.close());

  testWidgets('смена: открыть, продать, закрыть, снять Z', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final router = createRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentTimeProvider.overrideWithValue('12:30'),
        ],
        child: MaterialApp.router(
          title: 'TelePOS',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: router,
          supportedLocales: AppLocale.supportedLocales,
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));

    void describe(String where) {
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((d) => d != null && d!.trim().isNotEmpty)
          .map((d) => d!.trim())
          .toSet()
          .toList();
      // ignore: avoid_print
      print('[SHIFT] $where | ${texts.join(" · ")}');
    }

    Future<void> tapText(String label, {bool last = false}) async {
      final finder = find.text(label);
      if (finder.evaluate().isEmpty) {
        // ignore: avoid_print
        print('[SHIFT] кнопки «$label» НЕТ');
        return;
      }
      final target = last ? finder.last : finder.first;
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    router.go('/shift');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    describe('смена, до открытия');

    await tapText('Open shift');
    // Поле суммы открытия названо ключом, а не берётся первым попавшимся
    // `TextField`: первый дубль съёмки вводил 200 в поле вкладки «Итого»,
    // потому что диалог открытия — не единственное поле на экране.
    final cash = find.byKey(const ValueKey('shift-opening-cash'));
    expect(
      cash,
      findsOneWidget,
      reason: 'поле суммы открытия обязано быть названным',
    );
    await tester.enterText(cash.first, '200');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(
      tester.widget<TextField>(cash.first).controller?.text,
      '200',
      reason: 'введённое обязано остаться в поле, а не уехать в соседнее',
    );

    await tapText('Opening shift');
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // ── Объявленные подъёмные обязаны ДОЕХАТЬ до панели ─────────────────
    //
    // Здесь пробный проход и поймал денежный узел: в базе лежало 200, а
    // панель под подписью «Expected in register» показывала 0.00 —
    // объявление не доходило до счёта кассы, а панель показывала счёт.
    // Разбор нашёл за этим ещё пять сцепленных дефектов; сторож на всю
    // модель — `test/e2e/journeys/ops_cash_ledger_identity_test.dart`.
    final shift = await db.shiftDao.findOpenedShift();
    expect(
      shift?.openingCash,
      Decimal.parse('200'),
      reason: 'объявление обязано сохраниться в смене',
    );
    expect(
      find.text('200.00'),
      findsWidgets,
      reason: 'подъёмные обязаны быть видны на панели смены, а не только в '
          'базе: кассир сверяется с экраном, а не с таблицей',
    );
    describe('смена открыта');

    router.go('/sale');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.enterText(find.byType(TextField).first, '4607001');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    await tapText('PAY');
    await tapText('5');
    await tapText('PAY', last: true);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    describe('после продажи');

    router.go('/shift');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    describe('смена после продажи');

    // Деньги на экране смены обязаны быть в ВАЛЮТЕ КАССЫ. Касса заведена
    // американской (`currencyCode: 4`), и тенге здесь быть не может.
    final tengeOnShift = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((d) => d.contains('₸'))
        .toList();
    expect(
      tengeOnShift,
      isEmpty,
      reason: 'на американской кассе тенге быть не может: ${tengeOnShift.join(" · ")}',
    );

    // Z-отчёт печатается ДО закрытия: кнопка живёт на открытой смене и
    // называется «Print Z-report», а не «Z-report» — под вторым именем она
    // стоит только в узкой раскладке. Первый проход искал второе и решил,
    // что кнопки нет вовсе.
    await tapText('Print Z-report');
    describe('после Z-отчёта');

    await tapText('X-report');
    describe('после X-отчёта');

    // Закрытие смены — через ПОДТВЕРЖДЕНИЕ. Первый проход нажимал «Close
    // shift» и печатал «Shift opened»: окно подтверждения открывалось, и
    // проход его не проходил, а по снимку это выглядело как отказ кассы.
    await tapText('Close shift');
    describe('окно подтверждения закрытия');

    // В окне две кнопки: «Cancel» и «Close» (или «Close with discrepancy»,
    // если пересчёт разошёлся с журналом). Берём ту, что закрывает.
    if (find.text('Close with discrepancy').evaluate().isNotEmpty) {
      await tapText('Close with discrepancy');
    } else {
      await tapText('Close', last: true);
    }
    await tester.pumpAndSettle(const Duration(seconds: 3));
    describe('смена закрыта');
  });
}
