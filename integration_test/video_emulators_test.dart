/// Съёмочная дорожка урока 5 «Эмуляторы» — один непрерывный дубль.
///
/// # Правила, которые здесь выполняются
///
/// `docs/video-production.md`, разделы 6 и 7: один непрерывный дубль без
/// звука, курсор ведётся к цели с паузой полсекунды до и после нажатия,
/// ровное 16:9, часы заморожены, в кадре нет личных данных.
///
/// Имена отметок `[VIDEO-MARK]` совпадают с именами `@`-блоков в
/// `docs/internal/video/05-narration.txt`.
///
/// # Чем этот урок отличается от восьмого
///
/// Урок 8 привязывал принтер к ВНЕШНЕМУ эмулятору, запущенному отдельной
/// командой. Здесь не запускается ничего: сокет поднимает сама касса, и
/// это и есть обещание главы — «продай и напечатай, ничего не купив».
///
/// # Запуск
///
///     flutter test integration_test/video_emulators_test.dart -d windows
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
import 'package:telepos/app/router/app_routes.dart';
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

    // Касса настроена: глава 5 идёт после мастера, и повторять его незачем.
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
    await (db.update(db.thisPosEntries)..where((tp) => tp.rId.equals(true)))
        .write(
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

  testWidgets('урок 5: эмуляторы, один дубль', (tester) async {
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
    router.go(AppRoutes.emulatorSettings);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    mark('intro');
    // Двадцать восемь: на пробном проходе вступление не укладывалось в
    // двадцать четыре на две секунды.
    await hold(const Duration(seconds: 28));

    // ── screen ──────────────────────────────────────────────────────────────
    mark('screen');
    expect(
      find.text('Off: no socket is open'),
      findsWidgets,
      reason:
          'выключенный прибор обязан говорить, что сокета НЕТ вовсе: это не '
          'то же, что прибор, который отвечает молчанием',
    );
    await hold(const Duration(seconds: 25));

    // ── printer ─────────────────────────────────────────────────────────────
    mark('printer');
    await tapOne(
      find.ancestor(
        of: find.text('Receipt printer and cash drawer'),
        matching: find.byType(SwitchListTile),
      ),
      'включение эмулятора принтера',
    );
    await hold(const Duration(seconds: 6));
    expect(
      find.text('Emulator address'),
      findsWidgets,
      reason: 'включённый эмулятор обязан назвать адрес, иначе привязывать не к чему',
    );
    await hold(const Duration(seconds: 22));

    // ── bind ────────────────────────────────────────────────────────────────
    mark('bind');
    await tapOne(
      find.text('Write into the printer binding'),
      'запись адреса в привязку',
    );
    // Проверка ВПЛОТНУЮ к нажатию: касса говорит плашкой, а плашка гаснет
    // за четыре секунды. Первая редакция смотрела после шести и не нашла
    // ничего — это было свойство проверки, а не молчание кассы.
    expect(
      find.text('The printer binding now points at the emulator'),
      findsWidgets,
      reason: 'касса обязана СКАЗАТЬ, что привязка изменилась',
    );
    await hold(const Duration(seconds: 22));

    // Приборы собираются при сборке графа — до привязки. Без пересборки чек
    // ушёл бы в принтер, которого этот процесс не знает. Тот же перезапуск,
    // только без потери кадра.
    await registerHardwareServices(GetIt.I, logger: app_log.talker);

    // ── sale ────────────────────────────────────────────────────────────────
    router.go('/shift');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    mark('sale');
    await tapOne(find.text('Open shift'), 'открытие смены');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final openingCash = find.byType(TextField);
    if (openingCash.evaluate().isNotEmpty) {
      await tester.enterText(openingCash.first, '200');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
    }
    await tapOne(find.text('Opening shift'), 'подтверждение открытия смены');
    await tester.pumpAndSettle(const Duration(seconds: 2));

    router.go('/sale');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(
      find.text('Shift is closed'),
      findsNothing,
      reason: 'шторка закрытой смены в кадре — продажа снимется пустой',
    );

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
    await hold(const Duration(seconds: 6));

    // ── diagnostics ─────────────────────────────────────────────────────────
    router.go(AppRoutes.diagnostics);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    mark('diagnostics');
    await hold(const Duration(seconds: 6));
    await tapOne(find.byType(ExpansionTile), 'раскрытие задания печати');

    // Несущее утверждение главы: чек ДОШЁЛ до эмулятора и читается текстом.
    //
    // Без него дубль мог бы снять задание, застрявшее в очереди, и выдать
    // это за напечатанный чек. «Принято в очередь» и «напечатано» — разные
    // предложения, и урок обещает второе.
    expect(
      find.textContaining('Northwind Trading'),
      findsWidgets,
      reason:
          'в разобранном задании нет шапки чека — значит до сокета он не '
          'дошёл, и глава обещает то, чего не происходит',
    );
    await hold(const Duration(seconds: 24));

    // ── drawer ──────────────────────────────────────────────────────────────
    mark('drawer');
    await tapOne(
      find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Cash drawer'),
      ),
      'вкладка «Cash drawer»',
    );
    await hold(const Duration(seconds: 24));

    // ── others ──────────────────────────────────────────────────────────────
    router.go(AppRoutes.emulatorSettings);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    mark('others');
    await hold(const Duration(seconds: 30));

    // ── honest ──────────────────────────────────────────────────────────────
    mark('honest');
    await hold(const Duration(seconds: 28));

    // ── help ────────────────────────────────────────────────────────────────
    mark('help');
    await hold(const Duration(seconds: 32));
  });
}
