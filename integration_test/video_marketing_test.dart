/// Съёмочная дорожка маркетингового ролика — один непрерывный дубль.
///
/// Снимается первым по решению заказчика 2026-09-21: без ролика о продукте
/// непонятно, что за серия. Заодно на нём обкатывается весь конвейер
/// передачи в SphereX.
///
/// # Правила, которые здесь выполняются
///
/// `docs/video-production.md`, разделы 6 и 7:
///
/// * **один непрерывный дубль**, резать на файлы не надо — раскладку дают
///   отметки `[VIDEO-MARK]`;
/// * **курсор ведётся к цели**, пауза полсекунды до и после нажатия;
/// * **ровное 16:9** — размер окна задаёт `record_window.ps1`, не тест;
/// * **в кадре нет часов** — время заморожено на демо-значении;
/// * **нет личных данных** — магазин, кассир и товары выдуманы;
/// * **ничего не выжигается** — ни подписей, ни стрелок, ни водяного знака.
///
/// # Имена отметок = имена `@`-блоков в narration.txt
///
/// Это вся связь между текстом и картинкой (раздел 5 правил). Отдельной
/// таблицы соответствий нет намеренно: она разъехалась бы с первой правкой.
///
/// # Запуск
///
///     flutter test integration_test/video_marketing_test.dart -d windows
///
/// Запись включается снаружи: `tools/record_window.ps1`.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';

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

import 'support/cursor.dart';

Decimal _d(String v) => Decimal.parse(v);

/// Часы в строке состояния, замороженные на демо-значении.
///
/// Правила запрещают часы в кадре. Настоящее время вдобавок делает дубли
/// неповторимыми: пересняли в другой час — кадры разошлись, и сравнить
/// новый дубль со старым нельзя.
const _frozenClock = '12:30';

/// Магазин, касса, кассир и товары — те же, что на снимках README.
///
/// Правила (раздел 4) требуют одних демо-данных на ролики и картинки: иначе
/// зритель, пришедший из статьи, увидит другую кассу и решит, что смотрит
/// не то.
Future<void> _seedInEnglish(AppDatabase db) async {
  await db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          id: const Value(1),
          name: const Value('Groceries'),
          createTime: DateTime.now(),
        ),
      );

  final posAccId = await db.accountDao.createPosAccount(name: 'Cash');
  final bankAccId = await db.accountDao.createAcquiringAccount(
    name: 'Card',
    acquirerId: 1,
  );

  await db.thisPosDao.insertInitialConfig(
    companyName: 'Northwind Trading',
    iinbin: '123456789012',
    cashBoxName: 'Till-1',
    countryCode: 0,
    currencyCode: 0,
    currencySymbol: '₸',
    currencyNameShort: 'KZT',
    paperWidth: 48,
    printerHeader: null,
    printerFooter: null,
    accountId: posAccId,
    acquiringAccountId: bankAccId,
    rsaPublicKey: null,
    sendToOfd: false,
    cashInOut: true,
  );
  await (db.update(db.thisPosEntries)..where((tp) => tp.rId.equals(true)))
      .write(const ThisPosEntriesCompanion(id: Value(1)));

  final cashierId = await db.userDao.createCashier(
    name: 'Anna Whitfield',
    passwordEnc: null,
  );
  // Пустая таблица прав читается как «не разрешено ничего», и переходы
  // маршрутизатором молча уехали бы на отказ — в кадре оказался бы не тот
  // экран, а прогон остался бы зелёным: redirect ошибкой не считается.
  await db.userPermissionDao.setPermissions(cashierId, {
    for (final key in PermissionKeys.allPermissions) key: true,
  });

  const products = [
    (ucode: 1001, barcode: 4607001, name: 'Milk, 1 L', price: '450'),
    (ucode: 1002, barcode: 4607002, name: 'White bread', price: '150'),
    (ucode: 1003, barcode: 4607003, name: 'Sugar, 1 kg', price: '280'),
    (ucode: 1004, barcode: 4607004, name: 'Butter, 200 g', price: '890'),
    (ucode: 1005, barcode: 4607005, name: 'Eggs, 10 pcs', price: '620'),
    (ucode: 1006, barcode: 4607006, name: 'Ground coffee', price: '3200'),
    (ucode: 1007, barcode: 4607007, name: 'Green tea', price: '1150'),
  ];

  for (final p in products) {
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: Value(p.ucode),
            barcode: Value(p.barcode),
            name: Value(p.name),
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
            ucode: Value(p.ucode),
            barcode: Value(p.barcode),
            sellingPrice: Value(_d(p.price)),
            wholesalePrice: Value(_d(p.price)),
          ),
        );
  }

  for (final p in products.take(4)) {
    await db.quickProductDao.addQuickProduct(ucode: p.ucode, orderName: p.name);
  }

  await _seedSalesHistory(db, cashierId, products);
}

/// История продаж за неделю — иначе отчёты в кадре пусты.
///
/// Пустой экран отчётов в ролике о продукте читается не как «мы только
/// поставили кассу», а как «продукт не работает». Это единственная причина,
/// по которой история вообще заводится: показать живую кассу, а не
/// нарисовать выручку.
///
/// Состояние `1`, а не `0`/`2`/`3`: отчёты считают продажи запросом
/// `state NOT IN (0, 2, 3)` (`report_dao.dart`) — чек в работе, занятый под
/// оплату и отложенный в выручку не попадают.
Future<void> _seedSalesHistory(
  AppDatabase db,
  int cashierId,
  List<({int ucode, int barcode, String name, String price})> products,
) async {
  final now = DateTime.now();
  var receiptNo = 100;

  for (var daysAgo = 6; daysAgo >= 0; daysAgo--) {
    // Три чека в день в разные часы — распределение по часам на сводке
    // должно быть похоже на торговый день, а не на один всплеск.
    for (final hour in const [10, 14, 18]) {
      final at = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
      ).subtract(Duration(days: daysAgo));
      final seconds = at.millisecondsSinceEpoch ~/ 1000;

      final first = products[(daysAgo + hour) % products.length];
      final second = products[(daysAgo + hour + 3) % products.length];
      final total = _d(first.price) + _d(second.price);

      receiptNo++;
      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: receiptNo,
              posId: 1,
              userId: cashierId,
              amount: total,
              time: seconds,
              state: const Value(1),
              terminalId: const Value(null),
            ),
          );

      for (final p in [first, second]) {
        await db
            .into(db.saleProducts)
            .insert(
              SaleProductsCompanion.insert(
                ucode: p.ucode,
                quantity: _d('1.000'),
                price: _d(p.price),
                priceBefore: _d(p.price),
                receiptNo: Value(receiptNo),
                posId: const Value(1),
              ),
            );
      }

      // Вид оплаты чередуется: круговая диаграмма способов оплаты из одного
      // сектора не диаграмма.
      await db
          .into(db.payments)
          .insert(
            PaymentsCompanion.insert(
              userId: cashierId,
              payeeAccountId: hour == 14 ? 2 : 1,
              amount: total,
              time: seconds,
              receiptNo: Value(receiptNo),
              posId: const Value(1),
              state: const Value(1),
            ),
          );
    }
  }
}

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
    // Регистрирует `main.dart`, а не `configureDependencies`, а `main()`
    // здесь не выполняется. Без этой строки вход без PIN бросает прямо из
    // обработчика нажатия, и дубль кончается на первом кадре.
    GetIt.I.registerSingleton<HostCapabilities>(HostCapabilities.desktop);
    await configureDependencies(logger: app_log.talker);
    await _seedInEnglish(db);
  });

  tearDownAll(() async {
    await db.close();
    await GetIt.I.reset();
  });

  /// Держит кадр, продолжая рисовать.
  ///
  /// `pumpAndSettle` для пауз не годится: он возвращается, как только дерево
  /// успокоилось, и экран сменился бы быстрее, чем его прочли.
  Future<void> hold(WidgetTester tester, Duration duration) async {
    final end = DateTime.now().add(duration);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<GoRouter> pumpApp(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    final router = createRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentTimeProvider.overrideWithValue(_frozenClock),
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
    return router;
  }

  testWidgets('маркетинговый дубль: один проход по продукту', (tester) async {
    final filmingStartedAt = DateTime.now();
    final cursor = CursorDriver.attach('TelePOS');

    void mark(String block) {
      final at = DateTime.now().difference(filmingStartedAt).inMilliseconds;
      // ignore: avoid_print
      print('[VIDEO-MARK] $block ${(at / 1000).toStringAsFixed(3)}');
    }

    Future<void> tapOne(Finder finder, String what, {bool last = false}) async {
      expect(
        finder,
        findsWidgets,
        reason: 'шаг «$what»: в кадре нет того, на что надо нажать',
      );
      final target = last ? finder.last : finder.first;
      await tester.ensureVisible(target);
      await tester.pump();
      if (cursor != null) {
        await cursor.moveTo(tester, tester.getCenter(target));
        await hold(tester, const Duration(milliseconds: 500));
      }
      await tester.tap(target);
      await tester.pump();
      if (cursor != null) await hold(tester, const Duration(milliseconds: 500));
    }

    final router = await pumpApp(tester);

    // ── intro ───────────────────────────────────────────────────────────────
    // Вступление держится дольше прочего: в него ложится обязательная
    // фраза про альфу (правила, часть 1), а по бюджету 2,4 слова в секунду
    // шести секунд на неё не хватает — замерено на втором дубле.
    mark('intro');
    await hold(tester, const Duration(seconds: 14));

    await tapOne(find.text('Anna Whitfield'), 'выбор кассира');
    await tapOne(find.text('Login without PIN'), 'вход без PIN');
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // ── shift ───────────────────────────────────────────────────────────────
    // Без открытой смены экран продажи закрыт шторкой `_ShiftClosedGate`
    // (`adaptive_scaffold.dart`): поверх лежит затемнение, а сам экран
    // обёрнут в `IgnorePointer`. Первый дубль это и снял — пустой чек под
    // модальным окном «Shift is closed». Смена открывается В КАДРЕ: это
    // честное начало торгового дня, а не техническая подготовка.
    router.go('/shift');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    mark('shift');
    await hold(tester, const Duration(seconds: 3));

    await tapOne(find.text('Open shift'), 'открытие смены');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final openingCash = find.byType(TextField);
    if (openingCash.evaluate().isNotEmpty) {
      await tester.enterText(openingCash.first, '50000');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      await hold(tester, const Duration(seconds: 2));
    }
    await tapOne(find.text('Opening shift'), 'подтверждение открытия смены');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await hold(tester, const Duration(seconds: 3));

    // ── sale ────────────────────────────────────────────────────────────────
    router.go('/sale');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    mark('sale');
    await hold(tester, const Duration(seconds: 3));

    expect(
      find.text('Shift is closed'),
      findsNothing,
      reason:
          'шторка закрытой смены в кадре — план продажи снимется пустым, '
          'как в первом дубле',
    );

    for (final code in const ['4607001', '4607006', '4607005']) {
      final search = find.byType(TextField);
      expect(
        search,
        findsWidgets,
        reason: 'на экране продажи нет поля поиска — товар не добавить',
      );
      await tester.enterText(search.first, code);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      await hold(tester, const Duration(seconds: 2));
    }
    await hold(tester, const Duration(seconds: 3));

    // ── catalog ─────────────────────────────────────────────────────────────
    router.go('/catalog');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    mark('catalog');
    await hold(tester, const Duration(seconds: 8));

    // ── reports ─────────────────────────────────────────────────────────────
    router.go('/reports');
    await tester.pumpAndSettle(const Duration(seconds: 3));
    mark('reports');
    await hold(tester, const Duration(seconds: 10));

    // ── hardware ────────────────────────────────────────────────────────────
    router.go('/printer-settings');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    mark('hardware');
    await hold(tester, const Duration(seconds: 9));

    // ── diagnostics ─────────────────────────────────────────────────────────
    router.go('/diagnostics');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    mark('diagnostics');
    await hold(tester, const Duration(seconds: 5));

    for (final tab in const ['Cash drawer', 'Scales']) {
      await tapOne(
        find.descendant(of: find.byType(TabBar), matching: find.text(tab)),
        'вкладка диагностики «$tab»',
      );
      await hold(tester, const Duration(seconds: 4));
    }

    // ── outro ───────────────────────────────────────────────────────────────
    router.go('/sale');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    // Концовка — призыв: бесплатно, открытый код, где взять. На шести
    // секундах второго дубля туда влезало четырнадцать слов, то есть
    // половина фразы.
    mark('outro');
    await hold(tester, const Duration(seconds: 18));
  });
}
