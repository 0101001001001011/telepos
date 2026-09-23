/// Съёмочная дорожка урока 7 «Первая продажа и смена» — один непрерывный дубль.
///
/// # Правила, которые здесь выполняются
///
/// `docs/video-production.md`, разделы 6 и 7: один непрерывный дубль без
/// звука, курсор ведётся к цели с паузой полсекунды до и после нажатия,
/// ровное 16:9, часы заморожены, в кадре нет личных данных.
///
/// Имена отметок `[VIDEO-MARK]` совпадают с именами `@`-блоков в
/// `docs/internal/video/07-narration.txt`.
///
/// # Чем этот урок отличается от пятого
///
/// Глава 5 обещала «продай и напечатай, ничего не купив» и потому поднимала
/// эмулятор принтера. Здесь принтера НЕТ намеренно: урок про деньги, а не
/// про бумагу, и честный ответ кассы «задание принято в очередь, бумаги
/// пока нет» — часть того, что глава показывает. Дорожка о нём и говорит.
///
/// # Что проверяется прямо в дубле
///
/// Съёмка — тоже замер. Три утверждения проверяются по кадру, и каждое
/// однажды было неверным:
///
/// * купюры в счётчике — американские, а не казахстанские (найдено
///   2026-09-21, три источника номиналов);
/// * сумма закрытия названа в валюте кассы, а не «KZT» (2026-09-22);
/// * дата открытия смены написана по-американски (2026-09-22: экран считал
///   её своим форматировщиком, в порядке СНГ, на кассе любой страны).
///
/// # Запуск
///
///     flutter test integration_test/video_shift_test.dart -d windows
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

import 'support/cursor.dart';

const _frozenClock = '12:30';

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

    // Тот же магазин, что во всех главах цикла: «Northwind Trading»,
    // касса «Till-1», кассир Anna Whitfield. Части не должны рассыпаться на
    // несвязанные куски.
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
    await (db.update(
      db.thisPosEntries,
    )..where((tp) => tp.rId.equals(true))).write(
      const ThisPosEntriesCompanion(
        id: Value(1),
        storeAddress: Value('1600 Blake Street, Denver, CO 80202'),
      ),
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

  testWidgets('урок 7: первая продажа и смена, один дубль', (tester) async {
    final filmingStartedAt = DateTime.now();
    final cursor = CursorDriver.attach('TelePOS');

    void mark(String block) {
      final at = DateTime.now().difference(filmingStartedAt).inMilliseconds;
      // ignore: avoid_print
      print('[VIDEO-MARK] $block ${(at / 1000).toStringAsFixed(3)}');
    }

    Future<void> hold(Duration duration) async {
      final end = DateTime.now().add(duration);
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<void> tapOne(Finder finder, String what, {bool last = false}) async {
      expect(
        finder,
        findsWidgets,
        reason: 'шаг «$what»: в кадре нет того, на что надо нажать',
      );
      final target = last ? finder.last : finder.first;

      // `ensureVisible` только НАЧИНАЕТ прокрутку: без `pumpAndSettle`
      // центр цели считается по будущему положению, и нажатие уходит мимо.
      // Так на съёмке главы 8 была нажата невидимая кнопка сохранения.
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await hold(const Duration(milliseconds: 700));

      if (cursor != null) {
        await cursor.moveTo(tester, tester.getCenter(target));
        await hold(const Duration(milliseconds: 500));
      }

      final hit = tester.hitTestOnBinding(tester.getCenter(target));
      expect(
        hit.path.length,
        greaterThan(2),
        reason:
            'шаг «$what»: в точке нажатия нет виджета — цель за краем экрана '
            'или закрыта чем-то сверху',
      );

      await tester.tap(target);
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      if (cursor != null) await hold(const Duration(milliseconds: 500));
    }

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

    // ── intro ───────────────────────────────────────────────────────────────
    router.go('/shift');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    mark('intro');

    // Купюры — АМЕРИКАНСКИЕ. До 2026-09-21 номиналов было три источника, и
    // на американской кассе кассир пересчитывал казахстанские купюры,
    // которых не существует, и не мог пересчитать доллар и двадцатку.
    expect(
      find.text('20'),
      findsWidgets,
      reason: 'в счётчике купюр нет двадцатки — номиналы взяты не у страны',
    );
    expect(
      find.text('2000'),
      findsNothing,
      reason: 'в счётчике купюр казахстанский номинал',
    );
    await hold(const Duration(seconds: 30));

    // ── open ────────────────────────────────────────────────────────────────
    mark('open');
    await tapOne(find.text('Open shift'), 'открытие смены');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final openingCash = find.byKey(const ValueKey('shift-opening-cash'));
    if (openingCash.evaluate().isNotEmpty) {
      await tester.enterText(openingCash.first, '200');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
    }
    await hold(const Duration(seconds: 6));
    await tapOne(find.text('Opening shift'), 'подтверждение открытия');
    await hold(const Duration(seconds: 12));

    // ── screen ──────────────────────────────────────────────────────────────
    mark('screen');

    // Дата открытия — ПО-АМЕРИКАНСКИ. Экран считал её своим форматировщиком
    // в порядке СНГ на кассе любой страны: «05.09.2026» для американца —
    // девятое мая, а не пятое сентября.
    expect(
      find.textContaining(RegExp(r'Opened: \d{1,2}/\d{1,2}/\d{4}')),
      findsWidgets,
      reason:
          'дата открытия смены написана не по-американски — экран снова '
          'считает её своим способом',
    );

    // Сумма открытия УЧТЕНА. Дубль 1 снял «Expected in register 0.00» при
    // двухстах долларах в ящике: `find.byType(TextField).first` попадал не
    // в окно открытия, а в поле вкладки «Total». Дорожка при этом говорит
    // «это отправная точка для всего, что касса посчитает сегодня» — кадр
    // ей противоречил.
    expect(
      find.text('200.00'),
      findsWidgets,
      reason:
          'ожидаемое в ящике не равно сумме открытия — двести долларов не '
          'ввелись, и дубль показывает не то, что говорит дорожка',
    );
    await hold(const Duration(seconds: 27));

    // ── sale ────────────────────────────────────────────────────────────────
    router.go('/sale');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    mark('sale');
    await tester.enterText(find.byType(TextField).first, '4607001');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    await hold(const Duration(seconds: 4));

    await tapOne(find.text('PAY'), 'переход к оплате');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final bill = find.text('5');
    if (bill.evaluate().isNotEmpty) {
      await tapOne(bill, 'внесение купюры 5 долларов');
    }
    await tapOne(find.text('PAY'), 'завершение оплаты', last: true);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await hold(const Duration(seconds: 14));

    // ── reports ─────────────────────────────────────────────────────────────
    router.go('/shift');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    mark('reports');

    // Двести открытия плюс три с половиной продажи. Ровно то, о чём
    // дорожка говорит: касса ведёт свой счёт, и он складывается.
    expect(
      find.text('203.50'),
      findsWidgets,
      reason:
          'ожидаемое в ящике не сложилось из открытия и продажи — счёт '
          'кассы не тот, о котором говорит урок',
    );
    await hold(const Duration(seconds: 22));

    // ── zreport ─────────────────────────────────────────────────────────────
    mark('zreport');
    await tapOne(find.text('Print Z-report'), 'снятие Z-отчёта');

    // Проверка ВПЛОТНУЮ к нажатию: плашка живёт восемь секунд. Смотреть
    // позже значило бы измерить её исчезновение, а не молчание кассы.
    expect(
      find.textContaining('accepted into the print queue'),
      findsWidgets,
      reason:
          'касса обязана СКАЗАТЬ, что бумаги пока нет и задание ждёт — на '
          'этом и построен блок дорожки',
    );
    await hold(const Duration(seconds: 24));

    // ── close ───────────────────────────────────────────────────────────────
    mark('close');
    await tapOne(find.text('Close shift'), 'закрытие смены');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Сумма закрытия — в валюте КАССЫ. До 2026-09-22 словарь нёс «KZT»
    // прямо в тексте, и окно закрытия американской смены называло тенге.
    expect(
      find.textContaining(RegExp(r'Amount to be recorded: .*\$')),
      findsWidgets,
      reason: 'сумма закрытия названа не в валюте кассы',
    );
    await hold(const Duration(seconds: 20));

    if (find.text('Close with discrepancy').evaluate().isNotEmpty) {
      await tapOne(
        find.text('Close with discrepancy'),
        'закрытие с расхождением',
      );
    } else {
      await tapOne(find.text('Close'), 'подтверждение закрытия', last: true);
    }
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // ── after ───────────────────────────────────────────────────────────────
    mark('after');
    expect(
      find.text('Shift closed'),
      findsWidgets,
      reason: 'смена не закрылась — дубль показывает не то, что обещает',
    );
    await hold(const Duration(seconds: 20));
  });
}
