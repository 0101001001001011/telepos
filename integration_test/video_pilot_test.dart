/// Съёмочная дорожка урока 1.3 «Принтер и ящик» — один непрерывный дубль.
///
/// # Правила, которые здесь выполняются
///
/// `docs/video-production.md`, разделы 6 и 7: один непрерывный дубль без
/// звука, курсор ведётся к цели с паузой полсекунды до и после нажатия,
/// ровное 16:9 (размер задаёт `record_window.ps1`), часы заморожены, в кадре
/// нет личных данных, ничего не выжигается.
///
/// Имена отметок `[VIDEO-MARK]` совпадают с именами `@`-блоков в
/// `docs/internal/video/01-narration.txt` — это вся связь между текстом и
/// картинкой, отдельной таблицы соответствий нет намеренно.
///
/// # Почему продажа, а не кнопка «Check device»
///
/// Кнопка проверки устройства отвечает русской строкой «Пробный чек
/// напечатан», и на английской кассе она остаётся русской:
/// `DeviceCheckOutcome` везёт готовый текст, собранный в слое данных, и
/// уезжает с ним по проводу. Починка требует кодов вместо текста, то есть
/// смены контракта провода, — отдельная работа, не правка перед съёмкой.
/// Настоящая продажа эту строку обходит и показывает более верный путь: так
/// печатает магазин.
///
/// # Запуск
///
///     flutter test integration_test/video_pilot_test.dart -d windows
///
/// Нужен эмулятор ESC/POS на 127.0.0.1:8987:
///
///     dart run test/emulators/escpos/emulator.dart --port 8987 --control 8988
library;

import 'dart:convert';
import 'dart:io';

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
import 'package:telepos/domain/tax/tax_preset.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/screens/settings/hardware_settings_screen.dart'
    show DeviceBindingEditor;

import 'support/cursor.dart';

Decimal _d(String v) => Decimal.parse(v);

/// Часы, замороженные на демо-значении: правила запрещают часы в кадре, а
/// настоящее время вдобавок делает дубли несравнимыми между собой.
const _frozenClock = '12:30';

/// Адрес эмулятора ESC/POS — он же произносится в кадре как адрес принтера.
const _printerHost = '127.0.0.1';
const _printerPort = '8987';

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
    iinbin: '841234567',
    cashBoxName: 'Till-1',
    // США: индекс 4 в `CountryCode`. Он решает на чеке три вещи — сторону
    // знака валюты, наличие фискализации и умолчание уклада налога.
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
          // Адрес печатается на чеке. До схемы v56 его негде было задать, и
          // на бумаге его не было ни в одной стране.
          storeAddress: Value('1600 Blake Street, Denver, CO 80202'),
        ),
      );

  // Налоговая настройка — настоящим поставляемым набором, а не руками.
  //
  // Настоящим намеренно: дубль обязан показывать то, что получит зритель,
  // применив тот же набор у себя. Засеять руками значило бы снять кассу,
  // которой ни у кого не будет.
  final denver = TaxPreset.fromJson(
    json.decode(File('assets/tax_presets/us-co-denver.json').readAsStringSync())
        as Map<String, Object?>,
  );
  final taxCategories = await db.taxSettingsDao.applyPreset(denver);

  final cashierId = await db.userDao.createCashier(
    name: 'Anna Whitfield',
    passwordEnc: null,
  );
  // Пустая таблица прав читается как «не разрешено ничего»: переходы
  // маршрутизатором молча уехали бы на отказ, в кадре оказался бы чужой
  // экран, а прогон остался бы зелёным — redirect ошибкой не считается.
  await db.userPermissionDao.setPermissions(cashierId, {
    for (final key in PermissionKeys.allPermissions) key: true,
  });

  // Два товара с РАЗНОЙ облагаемостью — иначе в кадре не видно, ради чего
  // категории заведены: молоко Денвер облагает своими 5,15 % при том, что
  // штат еду для дома освободил, а кофе идёт по полным 9,15 %.
  final products = [
    (
      ucode: 1001,
      barcode: 4607001,
      name: 'Milk, 1 gal',
      price: '4.29',
      category: taxCategories['food-home'],
    ),
    (
      ucode: 1002,
      barcode: 4607002,
      name: 'Hot coffee, large',
      price: '3.50',
      category: taxCategories['standard'],
    ),
    (
      ucode: 1003,
      barcode: 4607003,
      name: 'White bread',
      price: '3.29',
      category: taxCategories['food-home'],
    ),
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
            taxCategoryId: Value(p.category),
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

  testWidgets('урок 1.3: принтер и ящик, один дубль', (tester) async {
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

      // Прокрутка ДОВОДИТСЯ до конца, а не продвигается на кадр.
      //
      // `ensureVisible` её только запускает. После одного `pump()` кнопка
      // ещё едет, и `getCenter` даёт точку, где она БУДЕТ. Курсор приезжал
      // туда раньше кнопки и жал по пустому месту: на записи урока 1.3 это
      // выглядело как нажатие невидимой кнопки «Сохранить» — заметил
      // заказчик, глядя дубль, 2026-09-21.
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();

      // Кнопка обязана постоять в кадре ДО нажатия: зритель должен успеть
      // увидеть, куда едет курсор.
      await hold(tester, const Duration(milliseconds: 700));

      if (cursor != null) {
        await cursor.moveTo(tester, tester.getCenter(target));
        await hold(tester, const Duration(milliseconds: 500));
      }

      // Промах мимо виджета — отказ, а не строчка в выводе. Без этого
      // нажатие мимо цели оставляет прогон зелёным, а на записи остаётся
      // щелчок в пустоту.
      final hit = tester.hitTestOnBinding(tester.getCenter(target));
      expect(
        hit.path.length,
        greaterThan(2),
        reason:
            'шаг «$what»: в точке нажатия нет виджета — цель за краем '
            'экрана или закрыта чем-то сверху',
      );

      await tester.tap(target);
      await tester.pump();
      if (cursor != null) await hold(tester, const Duration(milliseconds: 500));
    }

    final router = await pumpApp(tester);

    // ── intro ───────────────────────────────────────────────────────────────
    mark('intro');
    await hold(tester, const Duration(seconds: 9));
    await tapOne(find.text('Anna Whitfield'), 'выбор кассира');
    await tapOne(find.text('Login without PIN'), 'вход без PIN');
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // ── bind ────────────────────────────────────────────────────────────────
    router.go('/printer-settings');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    mark('bind');
    await hold(tester, const Duration(seconds: 4));

    expect(
      find.text('Printer settings'),
      findsWidgets,
      reason:
          'после перехода в кадре не экран принтера — вероятно, отказ по '
          'правам увёл маршрутизатор в сторону, а прогон этого ошибкой не '
          'считает',
    );

    // Выключатель ищем ВНУТРИ редактора привязки: на экране есть ещё
    // очередь печати со своими органами управления, и `byType(Switch)` без
    // якоря однажды поймает чужой.
    await tapOne(
      find.descendant(
        of: find.byType(DeviceBindingEditor),
        matching: find.byType(Switch),
      ),
      'включение принтера',
    );
    await hold(tester, const Duration(seconds: 2));

    await tapOne(
      find.text('ESC/POS receipt printer, 80 mm'),
      'выбор модели принтера',
    );
    await hold(tester, const Duration(seconds: 2));

    await tester.enterText(
      find.byKey(const Key('param_printer.escpos.80mm_ipAddress')),
      _printerHost,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await hold(tester, const Duration(seconds: 2));

    // ── width ───────────────────────────────────────────────────────────────
    mark('width');
    await tester.enterText(
      find.byKey(const Key('param_printer.escpos.80mm_port')),
      _printerPort,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await hold(tester, const Duration(seconds: 3));

    // Ширина ленты — то, ради чего в тексте отдельный блок: восемьдесят
    // миллиметров это сорок восемь знаков в строке, пятьдесят восемь —
    // тридцать два.
    await tapOne(find.text('80'), 'выбор ширины ленты 80 мм');
    await hold(tester, const Duration(seconds: 3));

    await tapOne(find.text('Save'), 'сохранение привязки принтера');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await hold(tester, const Duration(seconds: 4));

    // Приборы собираются один раз, при сборке графа, — то есть на пустой
    // базе, до всякой привязки (оттого на экране и висит плашка «изменения
    // применяются при следующем запуске кассы»). Без пересборки чек ушёл бы
    // в принтер, которого этот процесс не знает, и вкладка Printer показала
    // бы отказ вместо принятого задания — ровно то, чего урок обещает не
    // показывать. Это не подмена ради съёмки, а тот самый перезапуск, только
    // без потери кадра.
    await registerHardwareServices(GetIt.I, logger: app_log.talker);

    // ── sale ────────────────────────────────────────────────────────────────
    // Без открытой смены экран продажи закрыт шторкой и обёрнут в
    // `IgnorePointer`: товар в чек не попадёт, а прогон останется зелёным.
    router.go('/shift');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tapOne(find.text('Open shift'), 'открытие смены');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final openingCash = find.byType(TextField);
    if (openingCash.evaluate().isNotEmpty) {
      // Долларами, а не тенге: касса в кадре американская.
      await tester.enterText(openingCash.first, '200');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
    }
    await tapOne(find.text('Opening shift'), 'подтверждение открытия смены');
    await tester.pumpAndSettle(const Duration(seconds: 2));

    router.go('/sale');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    mark('sale');
    await hold(tester, const Duration(seconds: 3));

    expect(
      find.text('Shift is closed'),
      findsNothing,
      reason: 'шторка закрытой смены в кадре — продажа снимется пустой',
    );

    // Два товара, и не для красоты: молоко — еда для дома, кофе — обычный
    // товар. Штат Колорадо еду для дома не облагает, Денвер облагает, и в
    // чеке это две разные ставки. Один товар показал бы одну цифру и не
    // объяснил бы, зачем вообще категории.
    for (final barcode in ['4607001', '4607002']) {
      await tester.enterText(find.byType(TextField).first, barcode);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      await hold(tester, const Duration(seconds: 2));
    }
    await hold(tester, const Duration(seconds: 2));

    await tapOne(find.text('PAY'), 'переход к оплате');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await hold(tester, const Duration(seconds: 2));

    // Десятидолларовая купюра: итог около восьми долларов, сдача видна в
    // кадре. Номиналы берёт `Currency.usd` — [100, 50, 20, 10, 5, 2, 1].
    final bill = find.text('10');
    if (bill.evaluate().isNotEmpty) {
      await tapOne(bill, 'внесение купюры 10 долларов');
      await hold(tester, const Duration(seconds: 2));
    }
    await tapOne(find.text('PAY'), 'завершение оплаты', last: true);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    // Семь, а не четыре: блок @sale вырос на фразу про налог сверх цены, и
    // в прежнее окно текст не укладывался.
    await hold(tester, const Duration(seconds: 7));

    // ── printer-tab ─────────────────────────────────────────────────────────
    router.go('/diagnostics');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    mark('printer-tab');
    await hold(tester, const Duration(seconds: 5));

    // Задание раскрывается В КАДРЕ: закадровый текст обещает «чек текстом,
    // раскодированный из байтов, ушедших в порт», а свёрнутая плитка его не
    // показывает. Первый дубль снял именно так — слова шли поверх картинки,
    // которая их не подтверждала.
    await tapOne(find.byType(ExpansionTile), 'раскрытие задания печати');
    await hold(tester, const Duration(seconds: 11));

    // ── drawer-tab ──────────────────────────────────────────────────────────
    await tapOne(
      find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Cash drawer'),
      ),
      'вкладка «Cash drawer»',
    );
    mark('drawer-tab');
    await hold(tester, const Duration(seconds: 19));

    // ── empty ───────────────────────────────────────────────────────────────
    await tapOne(
      find.descendant(of: find.byType(TabBar), matching: find.text('Scales')),
      'вкладка «Scales»',
    );
    mark('empty');
    await hold(tester, const Duration(seconds: 9));
    await tapOne(
      find.descendant(of: find.byType(TabBar), matching: find.text('Display')),
      'вкладка «Display»',
    );
    await hold(tester, const Duration(seconds: 8));

    // ── close ───────────────────────────────────────────────────────────────
    await tapOne(
      find.descendant(of: find.byType(TabBar), matching: find.text('Printer')),
      'возврат на вкладку «Printer»',
    );
    mark('close');
    await hold(tester, const Duration(seconds: 13));

    // ── help ────────────────────────────────────────────────────────────────
    // Обязательный блок по правилам (раздел 5): чем кончается ролик, если не
    // вышло. Отдельным `@`-блоком, а не припиской к последнему шагу.
    // Двадцать две секунды, а не двенадцать: по бюджету 2,4 слова в
    // секунду текст этого блока на двенадцати не помещался с превышением
    // на восемьдесят процентов, а сокращать «куда писать, если не вышло»
    // значит оставить человека без ответа ради хронометража.
    mark('help');
    // Двадцать шесть, а не двадцать две: запись обрывается вместе с
    // приложением и успевает отрезать хвост. На дубле 21 сентября
    // последнему блоку осталось 20,3 секунды при нужных 21,2 — текст в
    // кадр не укладывался.
    await hold(tester, const Duration(seconds: 26));
  });
}
