/// **Задача 13: экран продажи в браузерной таблице маршрутов.**
///
/// До этой задачи весь узел продажи был проверен набором и ни разу не был
/// показан браузеру. Здесь проверяется то, чего чтение исходников доказать
/// не может, — четырьмя пробами, каждая про свою беду:
///
/// 1. **маршрут ведёт к экрану, а не к заглушке.** `/sale` в браузерной
///    таблице отсутствовал, и `errorBuilder` отдавал `WtNotPortedScreen`;
/// 2. **отказ кассы доезжает до кассира названным.** `SaleController`
///    кладёт в состояние ключ отказа (`_errorKeyOf`), а экран до этой
///    задачи читал из него **один** ключ — `kShiftOverAgeError`. Всё
///    прочее — «товар не найден», «касса не настроена», «чек уже поднят» —
///    ставилось в состояние и не показывалось никому;
/// 3. **экран не различает реализаций.** Один и тот же `SaleController`
///    обязан одинаково нарисовать чек и над кассовой корзиной
///    (`LocalCartService` прямо над drift), и над проводной
///    (`WtCartService` через настоящий `WtDispatcher` и настоящий
///    `TillWire` в петле). Разойдись они — и «работает на кассе» перестало
///    бы что-либо значить для браузера;
/// 4. **скан по проводу доходит до отрисовки.** Не «команда ушла», а
///    строка и итог на экране — то, ради чего задача и делается.
///
/// # Почему петля, а не подставной `CartService`
///
/// Подделка доказала бы, что экран умеет рисовать то, что ему дали. Здесь
/// под экраном настоящая касса: drift в памяти, `TillOperations` со
/// сторожем прав, `TillWire`, кадры провода, кодеки `SaleOps` — подставлен
/// только QUIC, которого под `flutter test` не существует. Тот же приём и
/// та же петля, которыми задача 12 проверяла корзину без экрана
/// (`wt_cart_service_test.dart`, группа «петля: терминал против настоящей
/// кассы»).
library;

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';

import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/router/setup_router.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart' hide Terminal;
import 'package:telepos/core/constants/enums/user_role.dart';
import 'package:telepos/data/discount/local_discount_policy.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/sale/local_sale_edit_terms.dart';
import 'package:telepos/data/services/currency_service_impl.dart';
import 'package:telepos/domain/sale/sale_edit_terms.dart';
import 'package:telepos/presentation/common/dialogs/discount_dialog.dart';
import 'package:telepos/presentation/common/widgets/keyboards/num_pad.dart';
import 'package:telepos/web/wt_sale_edit_terms.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/startup/boot_stage.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/domain/startup/startup_state_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart' show Terminal, PointMode;
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/setup_state.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/screens/auth/login_screen.dart';
import 'package:telepos/presentation/screens/sale/sale_screen.dart';
import 'package:telepos/presentation/screens/sale/widgets/sale_action_buttons.dart';
import 'package:telepos/presentation/screens/terminal/terminal_home_screen.dart';
import 'package:telepos/presentation/screens/sale/widgets/sale_total_panel.dart';
import 'package:telepos/web/wt_cart_service.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_not_ported_screen.dart';

import '../data/transport/till_operations_stubs.dart';
import '../helpers/mock_providers.dart' show MockAppStateNotifier;
import '../presentation/auth/support/fakes.dart';
import 'support/fake_dispatcher.dart';
import 'support/loopback.dart';

const _barcode = '4870001234567';
const _unknownBarcode = '4870009999999';
const _cashier = 4;
const _terminalId = 1;

Decimal _d(String v) => Decimal.parse(v);

/// Цифра → физическая клавиша: скан обязан прийти **событиями**, иначе
/// `BarcodeScannerMixin` его не соберёт (он слушает `HardwareKeyboard`).
const _digitKeys = <String, LogicalKeyboardKey>{
  '0': LogicalKeyboardKey.digit0,
  '1': LogicalKeyboardKey.digit1,
  '2': LogicalKeyboardKey.digit2,
  '3': LogicalKeyboardKey.digit3,
  '4': LogicalKeyboardKey.digit4,
  '5': LogicalKeyboardKey.digit5,
  '6': LogicalKeyboardKey.digit6,
  '7': LogicalKeyboardKey.digit7,
  '8': LogicalKeyboardKey.digit8,
  '9': LogicalKeyboardKey.digit9,
};

/// Настоящая касса на том конце провода.
///
/// Заводится всё, без чего продажа не начинается: название кассы, кассир,
/// открытая смена, товар с ценой. Список из четырёх товаров, а не из
/// одного, — правило `qa-depth`: с единственной записью «нашёл нужное» не
/// отличить от «вернул всё».
class _Till {
  late final AppDatabase db;
  late final Loopback loop;
  late final TillWire wire;
  late final LocalCartService local;
  late final WtCartService overWire;

  /// Условия правки строки по тому же проводу и тому же сеансу, что
  /// [overWire], — задача 44.
  late final SaleEditTermsReader terms;

  /// Права сеанса. По умолчанию — продажа плюс откладывание: подписка на
  /// пул закрыта `op.deferSale` нарочно (круг правки задачи 9), и без него
  /// список отложенных не приезжает вовсе.
  Future<void> open({
    Set<String> permissions = const {
      PermissionKeys.navSale,
      PermissionKeys.opDeferSale,
    },
  }) async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    loop = Loopback();

    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            cashBoxName: Value('Касса-петля'),
            // Задача 44: пробы скидки мерят право и предел, а не тумблер
            // «продажа со скидкой» — он включён, иначе касса отказывала бы
            // `denied_policy` раньше права.
            sellInDiscount: Value(true),
          ),
        );
    // Предел кассира — 15 %: проба «предел виден до ввода» обязана увидеть
    // число кассы, а не умолчание «сто процентов».
    await db
        .into(db.discountLimits)
        .insertOnConflictUpdate(
          DiscountLimitsCompanion.insert(
            role: Value(UserRole.cashier.index),
            maxPercentPerLine: Value(_d('15')),
          ),
        );
    await db
        .into(db.users)
        .insert(
          const UsersCompanion(id: Value(_cashier), name: Value('Айгуль')),
        );
    await db
        .into(db.shifts)
        .insert(
          ShiftsCompanion(
            userId: Value(_cashier),
            openTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
            isOpened: Value(true),
            isSynced: Value(false),
          ),
        );

    var ucode = 100;
    for (final (name, code, price) in [
      ('Молоко', _barcode, '500'),
      ('Кефир', '4870007654321', '499.995'),
      ('Дүкен нан', '4870001111111', '0.0005'),
      ('Ысык-Көл суу', '4870002222222', '1234567890123.123'),
    ]) {
      await db
          .into(db.productInfos)
          .insert(
            ProductInfosCompanion.insert(
              ucode: Value(ucode),
              barcode: int.parse(code),
              name: name,
              type: 0,
              measure: 0,
              quantity: Value(_d('100')),
            ),
          );
      await db
          .into(db.productPrices)
          .insert(
            ProductPricesCompanion.insert(
              ucode: Value(ucode),
              barcode: int.parse(code),
              sellingPrice: Value(_d(price)),
            ),
          );
      ucode += 100;
    }

    final logger = Talker();
    final sessions = SessionRegistry();
    final invites = PairingInvites();
    local = LocalCartService(
      db: db,
      logger: logger,
      initiation: SaleInitiationUseCaseImpl(db: db, logger: logger),
      deferred: DeferredSaleServiceImpl(db: db, logger: logger),
      rounding: SaleRoundOptionUseCaseImpl(),
      findByBarcode: FindByBarcodeUseCaseImpl(db: db, logger: logger),
      searchProducts: SearchProductInfoUseCaseImpl(db: db, logger: logger),
    );
    final operations = TillOperations(
      db: db,
      bootstrap: NoopBootstrap(),
      setup: NoopSetupRepository(),
      terminals: LocalTerminalRepository(db),
      invites: invites,
      deviceBindings: NoopDeviceBindingRepository(),
      auth: LocalAuthRepository(
        db: db,
        sessions: sessions,
        throttle: LoginThrottle(),
      ),
      cart: local,
      editTerms: LocalSaleEditTerms(
        db: db,
        discountPolicy: LocalDiscountPolicy(db),
        currency: CurrencyServiceImpl(db: db, logger: logger),
        logger: logger,
      ),
    );
    final session = sessions.mint(
      userId: _cashier,
      name: 'Айгуль',
      role: 'cashier',
      permissions: permissions,
      operatingMode: 0,
      pointMode: 'cashier',
      shiftOpen: true,
      terminalId: _terminalId,
    );
    wire = TillWire(
      loop,
      operations.askHandlers,
      watchHandlers: operations.watchHandlers,
      runHandlers: operations.runHandlers,
      guard: wireGuardForTill(
        db: db,
        access: {for (final op in TillOps.all) op.name: op.access},
        sessions: sessions,
      ),
    )..start();

    final browser = WtDispatcher(loop, tokens: FakeTokens(session.token));
    // Настоящий путь вкладки — `terminals.register` с одноразовым кодом.
    // `terminals.selfEnsure` перестал привязывать место задачей 19: он
    // сажал любую сессию на строку самой кассы, без кода и без секрета.
    await browser.ask<TerminalRegisterRequest, TerminalEnrollment>(
      TillOps.terminalRegister,
      (name: 'Вкладка', code: invites.mint().code),
    );
    overWire = WtCartService(browser);
    terms = WtSaleEditTerms(browser);
  }

  Future<void> close() async {
    await wire.stop();
    await loop.dispose();
    await db.close();
  }
}

/// Настроенная и поднявшаяся касса — ровно то состояние, в котором заставка
/// уходит на `/login`.
class _BootedTill implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async {
    onProgress(1.0, BootStage.ready);
    return AppInitStatus.success;
  }
}

class _AlreadyConfigured implements FirstLaunchRepository {
  @override
  Future<FirstLaunchResult> determineResult() async =>
      FirstLaunchResult.alreadyConfigured;

  @override
  Future<List<FoundBackup>> findAvailableBackups() async => const [];

  @override
  Future<bool> restoreFromBackup(
    FoundBackup backup, {
    BootProgress? onProgress,
  }) async => false;

  @override
  Future<bool> loadGlobalData({BootProgress? onProgress}) async => false;

  @override
  Future<String> startNewPos() async => '';
}

class _TillState implements StartupStateRepository {
  @override
  Stream<SetupState> watch() {
    late final StreamController<SetupState> out;
    out = StreamController<SetupState>(
      onListen: () => out.add(
        const SetupState(
          configured: true,
          hasUsers: true,
          companyName: 'ТОО Ромашка',
          cashBoxName: 'Касса-1',
        ),
      ),
    );
    return out.stream;
  }
}

Widget _terminal(SharedPreferences prefs, GoRouter router) => ProviderScope(
  overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  child: MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    routerConfig: router,
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  ),
);

/// Экран продажи без маршрутизатора — пробам 3 и 4 нужен сам экран, а не
/// путь к нему.
Widget _saleAlone(
  SharedPreferences prefs, {
  Set<String> permissions = const {
    PermissionKeys.navSale,
    PermissionKeys.opDeferSale,
    // Приёмка 2026-09-17: поле скидки в окне правки тоже читает право из
    // сеанса (`op.sellDiscount`) и без него заперто.
    PermissionKeys.opSellDiscount,
  },
}) => ProviderScope(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    // Задача 29: кнопка «Отложенные» читает право из сеанса экрана. Экран
    // здесь поднят без входа, и сеанс кладётся тем же набором, что у кассы
    // `_Till.open` по умолчанию, — иначе кнопка была бы заперта в каждой
    // пробе, а не в той, что про право.
    appStateProvider.overrideWith(
      () => MockAppStateNotifier(AppState(permissions: permissions)),
    ),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // `Scaffold` — не украшение: экран продажи его не содержит, в приложении
    // его даёт оболочка (`adaptive_scaffold.dart`), а `TextField` поиска без
    // `Material` над собой падает на первом же кадре.
    home: const Scaffold(body: SaleScreen(shiftClose: ShiftCloseAtTill())),
  ),
);

/// Даёт отработать **обеим** сторонам: настоящей и поддельной.
///
/// # Почему одного `pump` мало, и как это измерено
///
/// Тело `testWidgets` идёт под `FakeAsync`, а касса на том конце петли
/// поднята в `setUp` — то есть в **настоящей** зоне. `StreamController`
/// доставляет события в зоне, захваченной на `listen()`, поэтому кадры
/// провода и потоки drift уходят в настоящий цикл событий, который под
/// `FakeAsync` не крутится вовсе. Проба это и показала: `state.error` пуст,
/// отказа нет, строк тоже нет — команда просто не доехала.
///
/// Отсюда чередование: `runAsync` пускает настоящий цикл (там живёт касса),
/// `pump` — поддельный (там живёт контроллер экрана). Ни того, ни другого
/// по отдельности не хватает.
///
/// `pumpAndSettle` не годится и без этого: заставка держит индикатор свои
/// 300 мс, и сходимости у неё нет.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  late SharedPreferences prefs;
  late _Till till;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    // `talker` — late-поле, которое присваивает точка входа (в браузере это
    // `lib/web/main_web.dart`). Без него первый же `talker.warning` из
    // контроллера роняет тест `LateInitializationError`, и настоящая причина
    // красноты тонет в чужом исключении.
    installLogger(Talker());
  });

  // **Касса поднимается здесь, а не внутри `testWidgets`, и это не вкусовщина.**
  // Тело `testWidgets` идёт под `FakeAsync`: настоящие таймеры там не идут, и
  // `await till.open()` — открытие drift, 36 миграций, первый кадр провода —
  // не завершается никогда. Измерено: проба висела ровно 10 минут и падала
  // `TimeoutException`, ни разу не дойдя до `pumpWidget`. `setUp` живёт вне
  // поддельных часов, и там же ему место.
  setUp(() async {
    till = _Till();
    await till.open();
    GetIt.I
      ..registerSingleton<AppBootstrap>(_BootedTill())
      ..registerSingleton<FirstLaunchRepository>(_AlreadyConfigured())
      ..registerSingleton<StartupStateRepository>(_TillState())
      ..registerSingleton<AuthRepository>(FakeAuthRepository())
      ..registerSingleton<TerminalIdentity>(FakeTerminalIdentity())
      ..registerSingleton<TerminalRepository>(
        FakeTerminalRepository(
          self: () async => const Terminal(
            id: _terminalId,
            name: 'Касса-1',
            pointMode: PointMode.cashier,
          ),
        ),
      );
  });

  tearDown(() async {
    await GetIt.I.reset();
    await till.close();
  });

  group('маршрут продажи', () {
    testWidgets('/sale открывает настоящий экран продажи, а не заглушку', (
      tester,
    ) async {
      // Красный до задачи 13: `/sale` в браузерной таблице не объявлен,
      // ответ даёт `errorBuilder` — `WtNotPortedScreen`.
      tester.view.physicalSize = const Size(2048, 1536);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      GetIt.I.registerSingleton<CartService>(till.overWire);

      final router = createSetupRouter();
      await tester.pumpWidget(_terminal(prefs, router));
      await _settle(tester);
      _logIn(tester, permissions: {PermissionKeys.navSale});

      router.go(AppRoutes.sale);
      await _settle(tester);

      expect(
        find.byType(WtNotPortedScreen),
        findsNothing,
        reason:
            'заглушка здесь означает, что маршрута в таблице нет и ответил '
            'errorBuilder',
      );
      expect(find.byType(SaleScreen), findsOneWidget);
    });

    testWidgets('до продажи есть путь нажатием, а не только адресом', (
      tester,
    ) async {
      // **Требование координатора, и оно измерено дважды в этом дереве.**
      // `/sessions` и `/refund` уже жили заведёнными маршрутами, до которых
      // нельзя было дойти иначе как набрав адрес: сторож
      // `browser_routes_test.dart` проверяет «каждый переход ведёт на
      // объявленный маршрут» и **не проверяет обратного** — маршрут, на
      // который не ведёт ни один переход, ему безразличен по устройству.
      //
      // Поэтому здесь не чтение исходника, а нажатие: собранное дерево
      // **браузерной** таблицы (`createSetupRouter`), дом терминала,
      // настоящая плитка — и `SaleScreen` после тапа. Проверка на кассовом
      // доме доказала бы кнопку, до которой в браузере не дойти.
      tester.view.physicalSize = const Size(2048, 1536);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      GetIt.I.registerSingleton<CartService>(till.overWire);

      final router = createSetupRouter();
      await tester.pumpWidget(_terminal(prefs, router));
      await _settle(tester);
      _logIn(tester, permissions: {PermissionKeys.navSale});

      router.go(AppRoutes.terminalHome);
      await _settle(tester);
      expect(
        find.byType(TerminalHomeScreen),
        findsOneWidget,
        reason: 'предпосылка: вошедший попадает на дом терминала',
      );

      final tile = find.text('Продажа');
      expect(
        tile,
        findsOneWidget,
        reason:
            'дом терминала обязан давать путь до продажи нажатием — иначе '
            'маршрут есть, а дойти до него можно только адресной строкой',
      );

      await tester.tap(tile);
      await _settle(tester);

      expect(
        find.byType(SaleScreen),
        findsOneWidget,
        reason:
            'плитка обязана вести именно на `AppRoutes.sale`; подпись, '
            'ведущая не туда, здесь и ловится',
      );
    });

    testWidgets('кассиру без nav.sale плитки продажи не показывают', (
      tester,
    ) async {
      // Право показом — тем же приёмом, что у плиток оборудования и
      // сеансов. Не вместо проверки на кассе: `nav.sale` — довод каждой
      // операции `sale.*` в каталоге провода, и сторож отказывает до вызова
      // обработчика (И162). Здесь — чтобы кнопка не стояла у того, кому она
      // всё равно откажет.
      tester.view.physicalSize = const Size(2048, 1536);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final router = createSetupRouter();
      await tester.pumpWidget(_terminal(prefs, router));
      await _settle(tester);
      _logIn(tester, permissions: const {});

      router.go(AppRoutes.terminalHome);
      await _settle(tester);

      expect(find.byType(TerminalHomeScreen), findsOneWidget);
      expect(
        find.text('Продажа'),
        findsNothing,
        reason:
            'плитка, показанная всем, зеленит проверку на экране, который '
            'показывает кнопку тому, кому касса откажет',
      );
    });

    testWidgets('без права nav.sale на /sale не пускают', (tester) async {
      // Сторож входа таблицы (`PermissionKeys.routeToPermissionKey`) уже
      // знает `/sale` → `nav.sale`; проба закрепляет, что заведение
      // маршрута не открыло дверь всем вошедшим.
      tester.view.physicalSize = const Size(2048, 1536);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final router = createSetupRouter();
      await tester.pumpWidget(_terminal(prefs, router));
      await _settle(tester);
      _logIn(tester, permissions: const {});

      router.go(AppRoutes.sale);
      await _settle(tester);

      expect(find.byType(SaleScreen), findsNothing);
    });
  });

  group('отказ кассы доезжает до кассира названным', () {
    testWidgets('неизвестный штрихкод называет товар, а не молчит', (
      tester,
    ) async {
      // **Красный до задачи 13.** `SaleController._errorKeyOf` кладёт в
      // состояние `error.product_not_found:<штрихкод>`, а экран читал из
      // `state.error` ровно один ключ — `kShiftOverAgeError`. Кассир видел
      // ненажатую кнопку и пустую строку: отказ был, показать его было
      // нечем.
      tester.view.physicalSize = const Size(2048, 1536);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      GetIt.I.registerSingleton<CartService>(till.overWire);

      await tester.pumpWidget(_saleAlone(prefs));
      await _settle(tester);

      final element = tester.element(find.byType(SaleScreen));
      final container = ProviderScope.containerOf(element, listen: false);
      container
          .read(saleControllerProvider.notifier)
          .addByBarcode(_unknownBarcode);
      await _settle(tester);

      expect(
        find.textContaining('Товар не найден'),
        findsOneWidget,
        reason:
            'отказ кассы обязан доехать до кассира названным (И144), а не '
            'лечь в состояние экрана невидимым',
      );
      expect(find.textContaining(_unknownBarcode), findsOneWidget);
    });

    testWidgets('смена старше суток: браузер называет, где её закрыть, а не '
        'ведёт в заглушку', (tester) async {
      // Задачи 27 и 37. Красный на `9ac079a5` двумя дырами сразу: касса не
      // проверяла возраст смены при начале чека, а клиентская проверка в
      // браузере молча пропускалась (`ShiftService` не привязан → `catch` →
      // `true`) — диалога не было вовсе; а будь он, его кнопка «Закрыть
      // смену» вела бы в заглушку `/shift`.
      tester.view.physicalSize = const Size(2048, 1536);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final aged =
          DateTime.now()
              .subtract(const Duration(hours: 25))
              .millisecondsSinceEpoch ~/
          1000;
      await tester.runAsync(
        () => till.db
            .update(till.db.shifts)
            .write(ShiftsCompanion(openTime: Value(aged))),
      );
      GetIt.I.registerSingleton<CartService>(till.overWire);

      await tester.pumpWidget(_saleAlone(prefs));
      await _settle(tester);

      final dialog = find.byType(AlertDialog);
      expect(
        dialog,
        findsOneWidget,
        reason:
            'отказ кассы `shift_over_age` обязан доехать до кассира в браузере '
            'тем же диалогом, что и на кассе',
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining('Закройте смену на кассе'),
        ),
        findsOneWidget,
        reason: 'браузер смену не закрывает — кассир обязан узнать, где это',
      );
      expect(
        find.descendant(of: dialog, matching: find.byType(ElevatedButton)),
        findsNothing,
        reason:
            'кнопка перехода к смене в браузере вела в «пока только на '
            'кассе» — переход, который сработать не может',
      );
    });
  });

  group('экран не различает реализаций корзины', () {
    /// Что кассир видит на экране после скана — тремя строками.
    Future<({String name, String total, String positions, String? error})> scan(
      WidgetTester tester,
      CartService cart,
    ) async {
      GetIt.I.registerSingleton<CartService>(cart);
      await tester.pumpWidget(_saleAlone(prefs));
      await _settle(tester);

      final element = tester.element(find.byType(SaleScreen));
      final container = ProviderScope.containerOf(element, listen: false);
      container.read(saleControllerProvider.notifier).addByBarcode(_barcode);
      await _settle(tester);

      final state = container.read(saleControllerProvider);
      return (
        name: state.items.isEmpty ? '(строк нет)' : state.items.single.name,
        total: '${state.total}',
        positions: '${state.itemCount}',
        error: state.error,
      );
    }

    testWidgets('кассовая корзина: скан рисует строку и итог', (tester) async {
      tester.view.physicalSize = const Size(2048, 1536);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final seen = await scan(tester, till.local);

      expect(seen.error, isNull, reason: 'скан кончился отказом');
      expect(seen.name, 'Молоко');
      expect(seen.total, '500');
      expect(find.text('Молоко'), findsWidgets);
      expect(find.textContaining('500'), findsWidgets);
    });

    testWidgets('корзина по проводу: тот же экран рисует то же самое', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(2048, 1536);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final seen = await scan(tester, till.overWire);

      expect(seen.error, isNull, reason: 'скан по проводу кончился отказом');
      // Числа те же, что у кассовой реализации выше, и это единственное,
      // что здесь доказывается: `SaleController` под провод не правился и
      // не имеет права знать, какая реализация под ним.
      expect(seen.name, 'Молоко');
      expect(seen.total, '500');
      expect(seen.positions, '1');
      expect(find.text('Молоко'), findsWidgets);
      expect(
        find.textContaining('500'),
        findsWidgets,
        reason: 'итог по проводу обязан дойти до отрисовки, а не до лога',
      );
    });

    testWidgets('«Редактировать» в браузере есть — скидка достижима', (
      tester,
    ) async {
      // **История в два шага.** Н8 (2026-09-07): кнопка была видна, а нажатие
      // уходило в незарегистрированный `SaleCheckoutService` — молчаливый
      // бросок. Лечили тем, что кнопку **спрятали** проверкой
      // `isRegistered<SaleCheckoutService>()`, и эта проба утверждала
      // `findsNothing`. Живая приёмка 2026-09-13 измерила цену: скидку с
      // браузерного терминала ввести нельзя вовсе, и ни один тест об этом не
      // знает — прятанье сделало отсутствие договора режимом работы.
      //
      // Задачи 44–45: у экрана правки строки свой договор с проводной
      // реализацией (`SaleEditTermsReader` / `sale.editTerms`), и кнопка
      // стоит всегда. Незаведённый договор ловит сборочный сторож
      // `browser_routes_test.dart`, а не пустое место на экране.
      tester.view.physicalSize = const Size(2048, 1536);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      GetIt.I.registerSingleton<CartService>(till.overWire);

      await tester.pumpWidget(_saleAlone(prefs));
      await _settle(tester);

      expect(
        find.text('Редактировать'),
        findsOneWidget,
        reason:
            'кнопка правки строки — единственный вход в скидку; спрятанная, '
            'она делает скидку с терминала недостижимой целиком',
      );
      expect(
        find.text('Быстрые товары'),
        findsOneWidget,
        reason:
            'задача 45: у быстрых товаров свой проводной договор '
            '(`WtQuickProductCatalog`), и кнопка стоит всегда — тем же '
            'правилом, что «Редактировать»',
      );
      // Соседние кнопки на месте — иначе проба зеленела бы на пустом экране.
      expect(find.text('Отложить'), findsOneWidget);
      expect(find.text('Маркировка'), findsOneWidget);
    });

    testWidgets('отложенный чек: пул рисуется и поднимается кнопкой', (
      tester,
    ) async {
      // **Решение заказчика №3 — «несколько корзин это отложенные чеки».**
      // Одна проба на весь путь и **без единой подмены**: настоящий провод,
      // настоящий диалог, настоящая подписка `sale.deferredList`.
      //
      // # Почему здесь нет шва, хотя в первой редакции он был
      //
      // Первая редакция разводила это на две пробы — «провод» и «отрисовка с
      // подменённым потоком», — и оправдывала шов измерением: будто
      // `deferredCartsProvider` (`StreamProvider.autoDispose`) внутри
      // `testWidgets` пересоздаётся, даёт четыре кадра `sale.deferredList` за
      // один открытый диалог и остаётся в загрузке.
      //
      // **Измерение оказалось неверным.** Разбор посчитал сборки и удаления
      // провайдера счётчиком: `creates=1, disposes=0, loading=0` — и на
      // пустом пуле, и после откладывания. Настоящей причиной той красноты
      // было другое и названное: подписка на пул требует `op.deferSale`, а
      // сеанс петли имел лишь `nav.sale`, и поток приходил ошибкой
      // `forbidden: sale.deferredList: нет права op.deferSale`. Право
      // добавлено в сеанс `_Till`, шов снят, проба одна.
      //
      // Живой прогон координатора это же и подтвердил: диалог в браузере
      // открывается сразу и с содержимым.
      tester.view.physicalSize = const Size(2048, 1536);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      GetIt.I.registerSingleton<CartService>(till.overWire);
      await tester.pumpWidget(_saleAlone(prefs));
      await _settle(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SaleScreen)),
        listen: false,
      );
      final notifier = container.read(saleControllerProvider.notifier);

      // 1. Пустой пул — названным состоянием, а не пустотой: пустой
      // прямоугольник кассир читает как «не загрузилось».
      //
      // `ensureVisible` — не украшение: сетка действий с задачи 13 живёт в
      // прокручиваемой области (правка «клавиатура не прячет итог»), и на
      // 1024×768 нижние кнопки уезжают за её край.
      await tester.ensureVisible(find.text('Отложенные'));
      await _settle(tester);
      await tester.tap(find.text('Отложенные'));
      await _settle(tester);
      expect(find.text('Нет отложенных чеков'), findsOneWidget);
      expect(find.byIcon(Icons.restore), findsNothing);
      await tester.tap(find.text('Отмена'));
      await _settle(tester);

      // 2. Чек с товаром — и в пул.
      notifier.addByBarcode(_barcode);
      await _settle(tester);
      final deferred = container.read(saleControllerProvider).receiptNo;
      expect(deferred, isNotNull, reason: 'предпосылка: чек начат');

      notifier.deferSale();
      await _settle(tester);
      expect(
        container.read(saleControllerProvider).items,
        isEmpty,
        reason: 'после откладывания рабочий чек пуст',
      );

      // 3. Пул отдаёт карточку **подпиской**: диалог открывается уже после
      // того, как чек туда ушёл.
      await tester.ensureVisible(find.text('Отложенные').first);
      await _settle(tester);
      await tester.tap(find.text('Отложенные').first);
      await _settle(tester);

      expect(find.text('Нет отложенных чеков'), findsNothing);
      expect(
        find.textContaining('Чек № $deferred'),
        findsOneWidget,
        reason:
            'подписка `sale.deferredList` обязана доехать до отрисовки — это '
            'единственный поток, который браузерная продажа рисует сама',
      );
      expect(
        find.text('500.00 · Айгуль · Молоко'),
        findsOneWidget,
        reason:
            'подпись карточки — сумма, кассир и первый товар одной строкой: '
            'два чека на одну сумму по номеру и цене неразличимы, и узнаёт '
            'кассир свой чек именно этими двумя (докстринг `DeferredCart`)',
      );

      // 4. Подъём — тем же нажатием, каким это делает кассир.
      await tester.tap(find.byIcon(Icons.restore));
      await _settle(tester);

      final restored = container.read(saleControllerProvider);
      expect(
        restored.receiptNo,
        deferred,
        reason: 'поднят обязан быть тот самый чек, а не новый',
      );
      expect(restored.items, hasLength(1));
      expect('${restored.total}', '500');

      final rows = await till.db.select(till.db.saleProducts).get();
      expect(
        rows,
        hasLength(1),
        reason: 'строка всё это время лежала в базе кассы, а не во вкладке',
      );
    });

    testWidgets('на телефоне те же кнопки спрятаны в меню', (tester) async {
      // **Вторая половина Н8, и она была закрыта кодом без пробы.**
      // `SaleActionsFab` получил гейты в том же коммите, но не упоминается
      // **ни одним файлом** `test/` во всём дереве, а экранные пробы гоняются
      // на 2048×1536 — то есть на десктопной раскладке. Разбор снял оба гейта
      // у меню и получил `+870: All tests passed!`: на телефоне кассир
      // по-прежнему увидел бы «Редактировать» и получил молчаливый бросок.
      //
      // 400×700 логических точек — телефон: `sale_screen.dart` выбирает
      // `_MobileLayout` при ширине меньше 900, и действия там живут не сеткой,
      // а всплывающим меню.
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      GetIt.I.registerSingleton<CartService>(till.overWire);

      await tester.pumpWidget(_saleAlone(prefs));
      await _settle(tester);
      expect(
        find.byType(SaleActionsFab),
        findsOneWidget,
        reason:
            'предпосылка: на этой ширине действия живут в меню, а не сеткой',
      );

      // Товар в чеке — иначе меню почти пусто: половина пунктов стоит за
      // «есть выбранная строка», и проверять было бы нечего.
      ProviderScope.containerOf(
        tester.element(find.byType(SaleScreen)),
        listen: false,
      ).read(saleControllerProvider.notifier).addByBarcode(_barcode);
      await _settle(tester);

      await tester.tap(find.byType(SaleActionsFab));
      await _settle(tester);

      expect(
        find.text('Отложить'),
        findsOneWidget,
        reason: 'предпосылка: меню открылось и пункты в нём есть',
      );
      expect(
        find.text('Редактировать'),
        findsOneWidget,
        reason:
            'задачи 44–45: вход в скидку стоит в обеих раскладках — на '
            'телефоне меню, а не сетка, но тот же пункт',
      );
      expect(
        find.text('Быстрые товары'),
        findsOneWidget,
        reason:
            'задача 45: у быстрых товаров свой проводной договор '
            '(`WtQuickProductCatalog`), и кнопка стоит всегда — тем же '
            'правилом, что «Редактировать»',
      );
    });

    testWidgets('после скана поле поиска пусто, а не копит цифры', (
      tester,
    ) async {
      // **Н7, подтверждена живым прогоном координатора 2026-09-07.** После
      // двух сканов в поле поиска стояло `48700012345674870007654321`, после
      // десяти строка уходила за правый край: товар распознавался верно, а
      // кассир видел мусор, и ручной поиск после скана был сломан.
      //
      // Механизм — не «забыли позвать clear»: `BarcodeScannerMixin`
      // **съедает `Enter`** (`_onHardwareKey` возвращает `true`), поэтому
      // `onSubmitted` у поля, где очистка и стояла, не срабатывает при
      // сканировании вовсе. Цифры при этом миксин не съедает.
      //
      // Поэтому проба гонит **настоящие события клавиатуры**, а не зовёт
      // `addByBarcode` методом: иначе она прошла бы по тому пути, на котором
      // дефекта нет, и осталась бы зелёной при сломанном продукте.
      tester.view.physicalSize = const Size(2048, 1536);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      GetIt.I.registerSingleton<CartService>(till.overWire);
      await tester.pumpWidget(_saleAlone(prefs));
      await _settle(tester);

      // Текст — через канал ввода (`enterText`), `Enter` — событием
      // клавиатуры. **Именно так, и это измерено:** первая редакция пробы
      // слала все тринадцать цифр событиями (`sendKeyEvent`) — и была
      // зелёной с правкой и без неё. Причина: `TextField` во Flutter
      // получает текст от платформенного канала ввода, а не от
      // `HardwareKeyboard`; события цифр до поля не доходят вовсе, поле
      // оставалось пустым само по себе, и проверять было нечего.
      //
      // В браузере всё иначе: цифры приходят в DOM-поле, а `Enter`
      // перехватывает миксин. Эта пара — `enterText` плюс событие `Enter` —
      // и есть та же расстановка.
      // **Обе половины, и обе обязательны — измерено.**
      //
      // `enterText` кладёт цифры в поле: `TextField` во Flutter получает
      // текст от платформенного канала ввода, а не от `HardwareKeyboard`, и
      // событиями клавиш поле не наполняется вовсе (первая редакция пробы
      // слала только события — поле оставалось пустым само по себе, и проба
      // была зелёной с правкой и без неё).
      //
      // `sendKeyEvent` на те же цифры наполняет буфер миксина: он слушает
      // ровно `HardwareKeyboard`, и `enterText` до него не доходит (вторая
      // редакция слала только текст — строка в чек не попадала вовсе).
      //
      // В браузере обе половины даёт одно нажатие: символ уходит в
      // DOM-поле, а событие — в обработчик. Здесь они разведены, потому что
      // разведён сам `flutter_test`.
      await tester.enterText(find.byType(TextField).first, _barcode);
      for (final digit in _barcode.split('')) {
        await tester.sendKeyEvent(_digitKeys[digit]!);
      }
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        _barcode,
        reason: 'предпосылка: цифры скана легли в поле, как в браузере',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SaleScreen)),
        listen: false,
      );
      final state = container.read(saleControllerProvider);
      expect(
        state.items,
        hasLength(1),
        reason:
            'предпосылка пробы: скан клавиатурой обязан положить строку — '
            'если её нет, проверять пустоту поля бессмысленно',
      );

      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(
        field.controller?.text ?? '',
        isEmpty,
        reason:
            'после скана поле поиска обязано быть пустым: иначе следующий '
            'набор допишется к накопленному, и ручной поиск сломан',
      );
      expect(state.searchQuery, isEmpty);
    });

    testWidgets('десять быстрых сканов: все десять в чеке', (tester) async {
      // **Строка приёмки координатора, измеренная соседями против настоящей
      // кассы:** «кассир, отсканировавший десять товаров подряд, либо видит
      // все десять в чеке, либо видит, что девять не прошли; молчаливая
      // потеря — дефект».
      //
      // У соседей десять сканов, у которых `baseVersion` взят из **одного**
      // снимка подписки, дали `[v1, cart_stale ×9]` и одну строку вместо
      // десяти. Здесь проверяется мой вызывающий: сканы летят подряд, не
      // дожидаясь ни ответа, ни отрисовки — ровно так их шлёт клавиатурный
      // сканер.
      //
      // Почему у `SaleController` этого не происходит: `_meta()` зовётся
      // **внутри** тела, поставленного в очередь (`_command` →
      // `_enqueue(() async { … run(terminalId, _meta()) })`), то есть
      // `state.version` читается в свой ход, уже после `_applyView`
      // предыдущей команды. Снимок версии на момент постановки в очередь
      // здесь не берётся нигде — и эта проба сторожит именно это.
      //
      // **Чего здесь намеренно нет.** Подстановки `baseVersion` из ответа
      // предыдущей команды — ни в очереди, ни в контроллере. Она обнулила бы
      // сторож устаревшей версии против второй вкладки того же рабочего
      // места, и все пробы остались бы зелёными.
      tester.view.physicalSize = const Size(2048, 1536);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      GetIt.I.registerSingleton<CartService>(till.overWire);
      await tester.pumpWidget(_saleAlone(prefs));
      await _settle(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SaleScreen)),
        listen: false,
      );
      final notifier = container.read(saleControllerProvider.notifier);
      for (var i = 0; i < 10; i++) {
        notifier.addByBarcode(_barcode);
      }
      await _settle(tester);
      await _settle(tester);

      final state = container.read(saleControllerProvider);
      final applied = '${state.totalQuantity}';
      final refusalOnScreen = find.byType(SnackBar).evaluate().isNotEmpty;

      // Первым — то, что нельзя нарушить ни при каком исходе: **потеря не
      // бывает молчаливой**. Либо все десять в чеке, либо кассир видит
      // полосу отказа.
      //
      // Свидетельство — то, что **на экране**, а не то, что осталось в
      // поле. Причина названа кругом задачи 13 и осталась верной после
      // слияния с задачей 23, хотя механизм сменился: тогда экран сам звал
      // `clearError()` и остаточное состояние было пусто в обоих исходах;
      // теперь отказ снимает удавшаяся команда (`SaleState.fromCart` не
      // переносит `error`), и после десяти удавшихся сканов поле снова
      // пусто. То есть `state.error == null` в хорошем исходе — не
      // свидетельство отсутствия отказов, а лишь след последней команды.
      expect(
        applied == '10' || refusalOnScreen,
        isTrue,
        reason:
            'в чеке $applied вместо 10, и на экране нет ни одной полосы '
            'отказа — кассир не узнал, что девять сканов не прошли',
      );
      expect(applied, '10', reason: 'десять сканов — десять товаров в чеке');

      final rows = await till.db.select(till.db.saleProducts).get();
      final inDb = rows.fold<Decimal>(
        Decimal.zero,
        (sum, row) => sum + row.quantity,
      );
      expect(
        '$inDb',
        '10',
        reason:
            'экран мог нарисовать десять и не довезти их до кассы — считается '
            'то, что лежит в её базе',
      );
    });

    testWidgets('строка ушла в базу кассы, а не осталась в браузере', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(2048, 1536);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await scan(tester, till.overWire);

      final rows = await till.db.select(till.db.saleProducts).get();
      expect(
        rows,
        hasLength(1),
        reason:
            'корзиной владеет касса (решение 2 спеки) — нарисованная строка, '
            'которой нет в базе кассы, это вторая правда о деньгах',
      );
    });
  });

  /// Касса, у сеанса которой **нет** `op.deferSale`. Отдельной группой ради
  /// `setUp`: вторая касса нужна ровно одной пробе, а поднимать её каждому
  /// тесту файла — платить временем за то, чего он не проверяет.
  /// **Задачи 44–45: скидка с браузерного терминала.** Живая приёмка
  /// 2026-09-13: ввести скидку с терминала нельзя было вовсе — кнопка
  /// «Редактировать» пряталась, условий правки строки браузер прочесть не
  /// мог, а диалог скидки бросил бы на первом кадре (`CurrencyService`).
  ///
  /// Под экраном — настоящая касса на том конце петли: право
  /// `op.sellDiscount` проверяет её сторож, предел 15 % — её
  /// `LocalDiscountPolicy`, строку пишет её `LocalCartService`. Экран в
  /// браузере только командует.
  group('скидка с терминала', () {
    /// Экран продажи браузера с одной строкой «Молоко» (500) в чеке кассы.
    Future<ProviderContainer> saleWithLine(WidgetTester tester) async {
      tester.view.physicalSize = const Size(2048, 1536);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      GetIt.I
        ..registerSingleton<CartService>(till.overWire)
        ..registerSingleton<SaleEditTermsReader>(till.terms);

      await tester.pumpWidget(_saleAlone(prefs));
      await _settle(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SaleScreen)),
        listen: false,
      );
      container.read(saleControllerProvider.notifier).addByBarcode(_barcode);
      await _settle(tester);
      expect(
        container.read(saleControllerProvider).selectedItem?.name,
        'Молоко',
        reason: 'предпосылка: строка в чеке и выбрана',
      );
      return container;
    }

    Finder inDialog(Finder matching) =>
        find.descendant(of: find.byType(DiscountDialog), matching: matching);

    Future<void> openDiscount(WidgetTester tester) async {
      await tester.tap(find.text('Редактировать'));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('edit_item_discount')));
      await _settle(tester);
      expect(find.byType(DiscountDialog), findsOneWidget);
    }

    /// Набрать процент пальцем по numpad, применить и сохранить строку.
    Future<void> givePercent(WidgetTester tester, String digits) async {
      await openDiscount(tester);
      for (final digit in digits.split('')) {
        await tester.tap(
          find.descendant(of: find.byType(NumPad), matching: find.text(digit)),
        );
        await _settle(tester);
      }
      await tester.ensureVisible(inDialog(find.text('Применить')));
      await _settle(tester);
      await tester.tap(inDialog(find.text('Применить')));
      await _settle(tester);
      await tester.tap(find.text('Сохранить'));
      await _settle(tester);
    }

    testWidgets('предел кассы виден в браузере ДО ввода', (tester) async {
      await saleWithLine(tester);
      await openDiscount(tester);

      expect(
        inDialog(find.byKey(const Key('discount_limit_hint'))),
        findsOneWidget,
      );
      expect(
        inDialog(find.textContaining('Доступно до 15 %')),
        findsOneWidget,
        reason:
            'предел обязан прийти от кассы (DiscountLimits: кассир 15 %), а '
            'не умолчанием «сто процентов» и не молчанием',
      );

      // В режиме суммы — деньгами, в валюте кассы: 15 % от 500 = 75.
      await tester.tap(inDialog(find.text('Сумма')));
      await _settle(tester);
      expect(inDialog(find.textContaining('75.00 ₸')), findsOneWidget);
    });

    testWidgets('кассир без op.sellDiscount — отказ кассы словами, чек не '
        'тронут', (tester) async {
      final container = await saleWithLine(tester);
      await givePercent(tester, '10');

      final l10n = AppLocalizations.of(tester.element(find.byType(SaleScreen)))!;
      expect(
        find.text(l10n.errorNotAllowed),
        findsOneWidget,
        reason:
            'право проверяет касса по проводу, и её отказ обязан доехать до '
            'кассира фразой словаря, а не кодом протокола и не молчанием',
      );
      expect(container.read(saleControllerProvider).total, _d('500'));
      final rows = await tester.runAsync(
        () => till.db.select(till.db.saleProducts).get(),
      );
      expect(
        rows!.single.price,
        _d('500'),
        reason: 'отказ сторожа — чек в базе кассы не тронут',
      );
    });
  });

  group('скидка с терминала: кассир с правом', () {
    // Касса пересобирается с сеансом, несущим `op.sellDiscount`, — **в
    // `setUp`**, вне поддельных часов (докстринг внешнего `setUp`).
    setUp(() async {
      await till.close();
      till = _Till();
      await till.open(
        permissions: const {
          PermissionKeys.navSale,
          PermissionKeys.opDeferSale,
          PermissionKeys.opSellDiscount,
        },
      );
    });

    testWidgets('скидка ложится строкой в корзину кассы', (tester) async {
      tester.view.physicalSize = const Size(2048, 1536);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      GetIt.I
        ..registerSingleton<CartService>(till.overWire)
        ..registerSingleton<SaleEditTermsReader>(till.terms);

      await tester.pumpWidget(_saleAlone(prefs));
      await _settle(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SaleScreen)),
        listen: false,
      );
      container.read(saleControllerProvider.notifier).addByBarcode(_barcode);
      await _settle(tester);

      await tester.tap(find.text('Редактировать'));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('edit_item_discount')));
      await _settle(tester);
      for (final digit in ['1', '0']) {
        await tester.tap(
          find.descendant(of: find.byType(NumPad), matching: find.text(digit)),
        );
        await _settle(tester);
      }
      final apply = find.descendant(
        of: find.byType(DiscountDialog),
        matching: find.text('Применить'),
      );
      await tester.ensureVisible(apply);
      await _settle(tester);
      await tester.tap(apply);
      await _settle(tester);
      await tester.tap(find.text('Сохранить'));
      await _settle(tester);

      final state = container.read(saleControllerProvider);
      expect(state.error, isNull, reason: 'касса отказала: ${state.error}');
      expect(state.items.single.discount, _d('50'));
      expect(state.total, _d('450'));

      final rows = await tester.runAsync(
        () => till.db.select(till.db.saleProducts).get(),
      );
      expect(
        rows!.single.priceBefore,
        _d('500'),
        reason: 'цена до скидки в базе кассы',
      );
      expect(
        rows.single.price,
        _d('450'),
        reason:
            'скидка обязана лечь в базу кассы — корзиной владеет касса, '
            'браузер только командует',
      );
    });
  });

  group('право на пул отложенных', () {
    late _Till limited;

    setUp(() async {
      limited = _Till();
      await limited.open(permissions: const {PermissionKeys.navSale});
    });

    tearDown(() async => limited.close());

    testWidgets('кассиру без права кнопка заперта и пул не спрашивается', (
      tester,
    ) async {
      // Задача 29, браузерная половина: сеанс без `op.deferSale` — кнопка на
      // месте, нажатие называет причину словарём, диалог не строится, и
      // подписка `sale.deferredList` не уходит на кассу вовсе.
      tester.view.physicalSize = const Size(2048, 1536);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      GetIt.I.registerSingleton<CartService>(limited.overWire);

      await tester.pumpWidget(
        _saleAlone(prefs, permissions: const {PermissionKeys.navSale}),
      );
      await _settle(tester);
      await tester.ensureVisible(find.text('Отложенные'));
      await _settle(tester);
      await tester.tap(find.text('Отложенные'));
      await _settle(tester);

      expect(
        find.byKey(const Key('sale_deferred_list_denied_reason')),
        findsOneWidget,
        reason: 'причина названа до двери, а не за ней',
      );
      expect(
        find.textContaining('Недостаточно прав для этого действия'),
        findsNothing,
        reason: 'диалог не открывался — отказывать в нём нечему',
      );
    });

    testWidgets('кассиру без права откладывать — причина, а не код протокола', (
      tester,
    ) async {
      // **Внутри задачи 13, а не вне её:** её собственный пункт — «отказ
      // кассы доезжает до кассира названным», и восемь ключей состояния
      // экран этому научен. Диалог отложенных был девятым путём и рисовал
      //
      //   Error: WtProtocolError(forbidden: sale.deferredList: нет права
      //   op.deferSale)
      //
      // — код протокола, имя операции и внутренний ключ права в лицо
      // кассиру.
      //
      // Случай не редкий: подписка на пул закрыта `op.deferSale` намеренно
      // (пул отдаёт весь список кассы вместе с именами кассиров), значит его
      // видит **любой** кассир с правом продавать и без права откладывать.
      //
      // Отдельная касса с урезанным сеансом: право проверяет она, и подделать
      // его на этой стороне нечем. Поднимается в `setUp` группы, а не здесь:
      // тело `testWidgets` идёт под `FakeAsync`, и `await _Till.open()` там
      // не завершается никогда — измерено в самом начале работы, проба висела
      // десять минут и падала `TimeoutException`.
      tester.view.physicalSize = const Size(2048, 1536);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      GetIt.I.registerSingleton<CartService>(limited.overWire);

      // Задача 29: сеанс экрана **считает**, что право есть (умолчание
      // `_saleAlone`), а касса его не даёт — ровно случай, ради которого отказ
      // в диалоге остаётся, когда кнопка уже знает право: право отняли
      // посреди сеанса, а экран об этом ещё не знает. Защита — на кассе.
      await tester.pumpWidget(_saleAlone(prefs));
      await _settle(tester);
      await tester.ensureVisible(find.text('Отложенные'));
      await _settle(tester);
      await tester.tap(find.text('Отложенные'));
      // Два круга: отказ приходит по проводу уже после того, как диалог
      // построился и завёл подписку.
      await _settle(tester);
      await _settle(tester);

      // С 2026-09-15 — фраза словаря под код `forbidden`, а не текст кассы:
      // тот написан по-русски для журнала и несёт внутренний ключ права
      // (`deferred_sales_dialog.dart`, `_deferredErrorText`).
      expect(
        find.textContaining('Недостаточно прав для этого действия'),
        findsOneWidget,
        reason: 'причина названа словами словаря, а не обёрткой протокола',
      );
      expect(
        find.textContaining('op.deferSale'),
        findsNothing,
        reason: 'внутренний ключ права кассиру не адресован',
      );
      expect(
        find.textContaining('WtProtocolError'),
        findsNothing,
        reason: 'имя типа транспорта кассиру ничего не говорит',
      );
      expect(find.textContaining('Error:'), findsNothing);
    });
  });

  group('планшет: цели пальца и вёрстка', () {
    /// Наименьшая цель касания. 48 логических точек — величина, которую
    /// называют и Material, и HIG; палец не попадает точнее.
    const minTouch = 48.0;

    testWidgets('каждая нажимаемая цель не меньше 48 точек', (tester) async {
      // Планшет 1024×768 в логических точках — то, что стоит у кассира в
      // зале, и та же ширина, на которой экран выбирает `_TabletLayout`.
      tester.view.physicalSize = const Size(2048, 1536);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      GetIt.I.registerSingleton<CartService>(till.overWire);
      await tester.pumpWidget(_saleAlone(prefs));
      await _settle(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SaleScreen)),
        listen: false,
      );
      container.read(saleControllerProvider.notifier).addByBarcode(_barcode);
      await _settle(tester);

      final offenders = <String>[];

      void measure(Finder finder, String kind) {
        final count = finder.evaluate().length;
        for (var i = 0; i < count; i++) {
          final at = finder.at(i);
          final size = tester.getSize(at);
          // Нулевая — не цель, а служебный слой (`Material`, всплывающие
          // подсказки): нажать её нельзя ни пальцем, ни мышью.
          if (size.height == 0 || size.width == 0) continue;
          if (size.height + 0.01 < minTouch) {
            offenders.add(
              '$kind #$i: ${size.width.toStringAsFixed(1)}×'
              '${size.height.toStringAsFixed(1)}',
            );
          }
        }
      }

      measure(
        find.byWidgetPredicate(
          (w) => w is InkWell && (w.onTap != null || w.onLongPress != null),
        ),
        'InkWell',
      );
      measure(find.byType(IconButton), 'IconButton');

      expect(
        offenders,
        isEmpty,
        reason:
            'Экран продажи переехал на планшет (задача 13). Цель ниже '
            '$minTouch точек кассир промахивает, и промах в чеке — это '
            'выбранная не та строка, у которой сейчас поменяют цену.',
      );
    });

    testWidgets('вёрстка планшета не переполняется', (tester) async {
      // Найдено этими же пробами: `SaleTotalPanel` в правой колонке
      // планшета переполнял свою шапку на 68 точек — «Итог чека» плюс
      // значок режима не помещались в 307.6 точки ширины. Кассир видел
      // жёлто-чёрную штриховку поверх итога.
      tester.view.physicalSize = const Size(2048, 1536);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      GetIt.I.registerSingleton<CartService>(till.overWire);
      await tester.pumpWidget(_saleAlone(prefs));
      await _settle(tester);

      expect(
        tester.takeException(),
        isNull,
        reason: 'переполнение вёрстки — это спрятанное от кассира содержимое',
      );
    });

    testWidgets('экранная клавиатура не прячет итог', (tester) async {
      // Планшет: клавиатура занимает нижнюю треть. Правая колонка —
      // `Column` с фиксированными кнопкой оплаты и панелью итога внизу;
      // до правки лишнюю высоту забирал `Spacer`, а когда его не
      // оставалось — переполнялся низ, то есть **итог**.
      tester.view.physicalSize = const Size(2048, 1536);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      GetIt.I.registerSingleton<CartService>(till.overWire);
      await tester.pumpWidget(_saleAlone(prefs));
      await _settle(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SaleScreen)),
        listen: false,
      );
      container.read(saleControllerProvider.notifier).addByBarcode(_barcode);
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'предпосылка теста');

      // 340 точек — обычная высота экранной клавиатуры планшета в
      // альбомной ориентации.
      tester.view.viewInsets = FakeViewPadding(bottom: 340 * 2.0);
      await tester.pump();
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason: 'с поднятой клавиатурой вёрстка переполнилась',
      );
      final totalRect = tester.getRect(find.byType(SaleTotalPanel));
      final visibleBottom = tester.view.physicalSize.height / 2.0 - 340;
      expect(
        totalRect.bottom,
        lessThanOrEqualTo(visibleBottom + 0.5),
        reason:
            'итог уехал под клавиатуру: кассир не видит суммы, которую '
            'называет покупателю',
      );
    });
  });
}

/// Кладёт `AppState`, как это делает `LoginNotifier._onSession` на настоящем
/// сеансе.
void _logIn(WidgetTester tester, {Set<String> permissions = const {}}) {
  final context = tester.element(find.byType(LoginScreen));
  ProviderScope.containerOf(context, listen: false)
      .read(appStateProvider.notifier)
      .setUserInfo(id: 7, name: 'Айгуль', role: 0, permissions: permissions);
}
