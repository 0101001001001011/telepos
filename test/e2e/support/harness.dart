library;

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';

import 'package:telepos/app/config/background_task_manager.dart';
import 'package:telepos/app/di/service_locator.dart' show configureDependencies;
import 'package:telepos/app/router/app_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/theme/theme_mode_provider.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/print/print_queue_local.dart';
import 'package:telepos/domain/host/host_capabilities.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/auth/login_controller.dart';
import 'package:telepos/core/logging/app_talker.dart' as app_log;

Decimal d(String v) => Decimal.parse(v);

class E2eHarness {
  late AppDatabase db;

  GoRouter? router;

  static const cashierName = 'Кассир Айгуль';

  static bool _talkerInitialized = false;

  /// [seedData] defaults to `true` — the fixture data [seed] inserts directly
  /// (company, accounts, cashier, demo products), the shortcut almost every
  /// e2e test wants. Pass `false` when a test needs to drive the *real*
  /// first-launch commit path (`SetupRepository.completeSetup`, e.g. to
  /// prove what the setup wizard itself produces) instead of this shortcut —
  /// running both would create duplicate accounts/users.
  ///
  /// Either way, `configureDependencies` (and therefore `HardwareModule
  /// .registerHardwareServices`) runs on an **empty** database, before
  /// [seed] or `completeSetup` ever executes — there is no terminal yet, so
  /// no device bindings can resolve at that point regardless of what either
  /// path later inserts. A test that needs hardware resolved against data
  /// written after boot has to call `registerHardwareServices` again itself.
  Future<void> setUp({
    Map<String, Object> prefs = const {},
    bool seedData = true,
  }) async {
    BackgroundTaskManager.disabledForTests = true;
    SharedPreferences.setMockInitialValues(prefs);
    if (!_talkerInitialized) {
      app_log.installLogger(Talker());
      _talkerInitialized = true;
    }
    GetIt.I.allowReassignment = true;

    db = AppDatabase.forTesting(NativeDatabase.memory());
    GetIt.I.registerSingleton<AppDatabase>(db);
    GetIt.I.registerSingleton<Talker>(app_log.talker);
    // `configureDependencies` — тот же граф, что собирает `main.dart`, но
    // `HostCapabilities` там регистрирует не он, а сам `main()`, до вызова
    // `configureDependencies`. Этот стенд входит в дерево напрямую, минуя
    // `main()`, и с задачи 12 `getPostLoginRoute()` спрашивает
    // `GetIt<HostCapabilities>` при каждом настоящем входе
    // (`loginAsCashier` жмёт «Войти без PIN» взаправду) — без регистрации
    // здесь это бросало бы на первом же входе любого сценария, который через
    // харнесс логинится.
    GetIt.I.registerSingleton<HostCapabilities>(HostCapabilities.desktop);

    await configureDependencies(logger: app_log.talker);
    if (seedData) {
      await seed(db);
    }
  }

  Future<void> tearDown() async {
    await db.close();
    await GetIt.I.reset();
  }

  /// Открывает смену **явно** — на кассира, заведённого [seed].
  ///
  /// # Зачем это понадобилось: долг задачи 5
  ///
  /// До задачи 5 касса открывала смену сама, при первой же продаже, выбирая
  /// человека как `userId ?? последний ?? 1`. Задача 5 это сняла: деньги
  /// смены ложились бы на «последнего», которого никто не спрашивал, а с
  /// браузерного терминала чек начинал бы вовсе неизвестно кто
  /// (`SaleInitiationUseCaseImpl`: `no opened shift — refusing`).
  ///
  /// Девять сквозных сценариев на самооткрытие рассчитывали: они удаляют
  /// смены в `setUp` и сразу продают. Правильный ход — открыть смену в
  /// подготовке **названным** человеком, а не вернуть молчаливое
  /// самооткрытие: именно от него задача 5 и избавлялась.
  ///
  /// [openTime] берётся текущим намеренно: `ShiftService.isShiftOverAge`
  /// блокирует продажу на смене старше суток, и смена из 1970 года
  /// («openTime: 1000») упирается в этот сторож вместо того, чтобы помочь.
  /// Измерено пробой круга правки 1 задачи 8 — она на этом и споткнулась.
  Future<int> openShift({Decimal? openingCash}) async {
    final users = await db.userDao.findAll();
    final cashier = users.firstWhere(
      (u) => u.name == cashierName,
      orElse: () => users.first,
    );
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return db
        .into(db.shifts)
        .insert(
          ShiftsCompanion.insert(
            userId: cashier.id,
            openTime: now,
            isOpened: true,
            isSynced: false,
            openingCash: Value(openingCash ?? Decimal.zero),
          ),
        );
  }

  /// [theme] умолчанием остаётся светлой, чтобы не трогать три десятка
  /// сценариев. Параметр появился, когда тёмная тема была подключена: снимок
  /// оболочки обязан сниматься в обеих, и «работает в светлой» перестало быть
  /// ответом.
  ///
  /// [frozenTime] останавливает часы в шапке. Нужен снимкам: эталон, снятый в
  /// 21:19, назавтра расходится сам с собой на 90 точках, и проверка начинает
  /// падать от хода часов, а не от правки кода. Заморозить время можно только
  /// здесь — `ProviderScope` строится внутри.
  ///
  /// Параметром названо само время, а не список переопределений: тип `Override`
  /// из барреля `flutter_riverpod` 3.1.0 не экспортируется, и назвать его в
  /// сигнатуре нельзя, не потянув в тесты транзитивный `riverpod` прямой
  /// зависимостью.
  Future<void> pumpApp(
    WidgetTester tester, {
    String locale = 'ru',
    Size size = const Size(1600, 1000),
    ThemeData? theme,
    String? frozenTime,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = await SharedPreferences.getInstance();
    final router = createRouter();
    this.router = router;

    await tester.pumpWidget(
      PrintQueueLifetime(
        child: ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            if (frozenTime != null)
              currentTimeProvider.overrideWithValue(frozenTime),
          ],
          child: _ThemedApp(
            themeOverride: theme,
            router: router,
            locale: locale,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  Future<bool> loginAsCashier(WidgetTester tester) async {
    final userTile = find.text(cashierName);
    if (userTile.evaluate().isEmpty) return false;
    await tester.tap(userTile.first);
    await tester.pumpAndSettle();
    for (int i = 0; i < 4; i++) {
      final zero = find.text('0');
      if (zero.evaluate().isNotEmpty) {
        await tester.tap(zero.first);
        await tester.pump(const Duration(milliseconds: 80));
      }
    }
    await tester.pumpAndSettle(const Duration(seconds: 1));
    // Matches whichever locale the app was pumped in.
    var noPin = find.text('Войти без PIN');
    if (noPin.evaluate().isEmpty) {
      noPin = find.text('Login without PIN');
    }
    if (noPin.evaluate().isNotEmpty) {
      await tester.tap(noPin.first);
      await tester.pump();
      // Waits for the verification this tap started, rather than guessing a
      // duration. `LoginNotifier.attemptLogin()`'s "Войти без PIN" branch
      // (every cashier this harness ever seeds — `E2eHarness.seed`'s only
      // cashier has `passwordEnc: null`) calls `_verifyPin` directly, with
      // no debounce `Timer` in front of it: `pendingVerification` here is a
      // plain `Future` chained straight to `AuthRepository.login()`, not the
      // fake-clock `Timer` `_scheduleVerify` uses for typed-digit input —
      // that distinction is what makes a direct `await` safe here. It would
      // NOT be safe for a PIN-typing login (see the fake/real clock note in
      // `test/e2e/journeys/login_test.dart::enterPin`), but nothing that
      // goes through this harness ever types a PIN: every seeded and
      // wizard-created cashier `loginAsCashier` logs in is passwordless
      // (grep `loginAsCashier` — every caller's cashier is seeded with
      // `passwordEnc: null`).
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp).first),
      );
      await container
          .read(loginControllerProvider.notifier)
          .pendingVerification;
      await tester.pumpAndSettle();
    } else {
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
    return find.byType(Scaffold).evaluate().isNotEmpty;
  }

  /// Releases the widget tree deliberately, before a test body returns.
  ///
  /// Thin instance-method wrapper so call sites already reading
  /// `harness.…` (`test/golden/shell_look_test.dart`) keep working
  /// unchanged. See the top-level [releaseLoginScreen] below for why this
  /// exists — that is the one real implementation; this method is not it.
  Future<void> releaseScreen(WidgetTester tester) => releaseLoginScreen(tester);
}

/// Releases the widget tree deliberately, before a test body returns.
///
/// `AuthRepository.watchUsers()` (subscribed by `LoginNotifier.build()` the
/// moment `LoginScreen` builds) is drift's `watchActiveUsers()` under the
/// hood, and drift debounces a cancelled query subscription through a
/// zero-duration `Timer` (`StreamQueryStore.markAsClosed`) rather than
/// closing it synchronously — a normal coalescing trick for a widget that
/// resubscribes on the very next frame. `LoginNotifier.build()`'s own
/// `ref.onDispose` cancels that subscription once the tree is torn down —
/// and flutter_test's own automatic between-test reset is what tears it
/// down here, **after** a test's own body has already returned, which is
/// too late for a pump inside the body to flush the timer it creates.
/// Disposing explicitly, before the test body returns, brings the timer's
/// creation inside the window a pump here can still reach — a
/// **non-zero** duration pump is required to actually cross it; a bare
/// `pump()` (duration zero) does not.
///
/// One helper, three call sites that each render `/login` at some point in
/// the test — `E2eHarness.loginAsCashier` always starts there,
/// `real_screens_golden_test.dart` snapshots it directly, and
/// `login_test.dart` drives it by hand. Three near-identical private copies
/// of this used to exist, one per file, kept in sync only by a comment
/// asking nicely; a fourth screen hitting the same assertion
/// (`test/e2e/journeys/setup_wizard_test.dart`) is the measured reason not
/// to let a fifth private copy happen.
Future<void> releaseLoginScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

/// Гасит очередь печати вместе с деревом приложения.
///
/// **Зачем это в оснастке, а не в `tearDown` теста.** `PrintQueueLocal` заводит
/// таймер пробуждения, как только у неё появляется активное задание, — а после
/// любой продажи на терминале без принтера оно появляется. `flutter_test`
/// проверяет отсутствие незакрытых таймеров **внутри** `_runTestBody`, то есть
/// **до** того, как отработают `addTearDown`/`tearDown`: измерено, таймер,
/// снятый в `addTearDown`, всё равно роняет тест с «A Timer is still pending
/// even after the widget tree was disposed». Единственный крючок, который
/// успевает, — это `dispose()` виджета: дерево разбирается **до** проверки.
///
/// Отключить очередь в тестах было бы дешевле и неверно: тогда е2е-проверка
/// того, что чек переживает недоступный принтер, проверяла бы выключенную
/// подсистему. Здесь очередь работает по-настоящему и просто честно
/// останавливается вместе с приложением, как она останавливается и в жизни.
///
/// **[E2eHarness.pumpApp] оборачивает дерево этим сам.** Тест, который строит
/// своё дерево через `tester.pumpWidget`, обязан обернуть его сам — иначе
/// первая же продажа или возврат оставят таймер, и тест упадёт с «A Timer is
/// still pending», указывая на `PrintQueueLocal._armWake`. Так найдены
/// `sale_test.dart` и `refund_test.dart`.
class PrintQueueLifetime extends StatefulWidget {
  const PrintQueueLifetime({required this.child});

  final Widget child;

  @override
  State<PrintQueueLifetime> createState() => PrintQueueLifetimeState();
}

class PrintQueueLifetimeState extends State<PrintQueueLifetime> {
  @override
  void dispose() {
    if (GetIt.I.isRegistered<PrintQueue>()) {
      final queue = GetIt.I<PrintQueue>();
      if (queue is PrintQueueLocal) {
        // Не ожидается: `dispose()` — это `Future`, а `State.dispose`
        // синхронен. Внутри он первым делом снимает таймер, а это и есть то,
        // ради чего он здесь; дождаться текущего задания успеет `GetIt.reset`
        // в `tearDown` харнесса.
        unawaited(queue.dispose());
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> seed(AppDatabase db) async {
  await db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          id: const Value(1),
          name: const Value('Продукты'),
          createTime: DateTime.now(),
        ),
      );

  final posAccId = await db.accountDao.createPosAccount(name: 'Касса');
  final bankAccId = await db.accountDao.createAcquiringAccount(
    name: 'Kaspi Bank',
    acquirerId: 1,
  );

  await db.thisPosDao.insertInitialConfig(
    companyName: 'ТОО ТестПОС',
    iinbin: '123456789012',
    cashBoxName: 'Касса-1',
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

  await db.thisPosDao.updateBusinessFlags(
    editProduct: true,
    editPrice: true,
    sellInDiscount: true,
    cashInOut: true,
    allowBigAmount: true,
  );

  final cashierId = await db.userDao.createCashier(
    name: E2eHarness.cashierName,
    passwordEnc: null,
  );

  // Задача 14: `createCashier` не пишет ни одной строки прав. Сегодня это
  // безвредно — `UserPermissionDao.getAllowedKeys` на пустой таблице читает
  // «разрешено всё», ровно то, что нужно 57 файлам сценариев, подключающим
  // этот харнесс. Но задача 16 переворачивает это чтение на «пусто —
  // разрешено ничего», и тогда тот же кассир без единой строки в
  // `UserPermissions` останется без единого права. Харнесс не сужает набор
  // по роли (`PermissionKeys.roleDefaults[cashier]`) — сценарии ходят по
  // всей кассе, а не по рабочему месту кассира, — поэтому заводится полный
  // `PermissionKeys.allPermissions`, тем же вызовом (`setPermissions`), каким
  // это делает рабочий код (`setup_repository_local.dart`,
  // `user_management_screen.dart`), а не прямой записью в таблицу в обход.
  await db.userPermissionDao.setPermissions(cashierId, {
    for (final key in PermissionKeys.allPermissions) key: true,
  });

  const products = [
    (ucode: 1001, barcode: 4607001, name: 'Молоко 1л', price: '450'),
    (ucode: 1002, barcode: 4607002, name: 'Хлеб белый', price: '150'),
    (ucode: 1003, barcode: 4607003, name: 'Сахар 1кг', price: '280'),
    (ucode: 1004, barcode: 4607004, name: 'Масло сливочное', price: '890'),
    (ucode: 1005, barcode: 4607005, name: 'Яйца 10шт', price: '620'),
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
            quantity: Value(d('100')),
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
            sellingPrice: Value(d(p.price)),
            wholesalePrice: Value(d(p.price)),
          ),
        );
  }
  for (final p in products.take(3)) {
    await db.quickProductDao.addQuickProduct(ucode: p.ucode, orderName: p.name);
  }
}

/// Корень стенда, повторяющий выбор темы так же, как это делает продукт.
///
/// До 2026-08-28 стенд строил `MaterialApp.router` одной строкой
/// `theme: AppTheme.light` — без `darkTheme` и без `themeMode`. То есть **ни
/// один сквозной тест не мог поймать поломку выбора темы**: тёмной в стенде
/// не существовало как возможности, каким бы ни было значение в настройках.
///
/// Найдено при съёмке снимков для статьи: `theme_mode: 'dark'` в
/// `SharedPreferences` не давал тёмного экрана, и провайдер был ни при чём.
/// Тот же класс дефекта, что и незагруженный шрифт иконок
/// (`test/e2e/icon_font_renders_test.dart`): стенд молча показывал не то, что
/// показывает продукт, и все проверки при этом были зелёными.
///
/// Довод [themeOverride] сохранён: он нужен тестам, задающим тему прямо, мимо
/// настроек. Когда он не задан — работает та же связка из трёх строк, что и в
/// `lib/app/telepos_app.dart`.
class _ThemedApp extends ConsumerWidget {
  const _ThemedApp({
    required this.themeOverride,
    required this.router,
    required this.locale,
  });

  final ThemeData? themeOverride;
  final GoRouter router;
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: themeOverride ?? AppTheme.light,
      darkTheme: themeOverride ?? AppTheme.dark,
      themeMode: themeOverride != null ? ThemeMode.light : mode,
      routerConfig: router,
      supportedLocales: AppLocale.supportedLocales,
      locale: Locale(locale),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
