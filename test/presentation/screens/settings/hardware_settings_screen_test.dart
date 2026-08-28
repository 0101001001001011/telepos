/// Задача 1 (обязательная) волны правок фазы 2: `sessionLost()` был написан,
/// задокументирован и покрыт тестами — но ни один экран не звал его. Этот
/// экран — единственная браузерная точка, достижимая по нажатию, у которой
/// сразу три места ловят провод: загрузка ([HardwareSettingsScreen]'s
/// `_loadSettings`), сохранение (`_saveSettings`) и проверка устройства
/// (`_DeviceBindingEditorState._runCheck`). До правки все три ловили
/// `SessionLost` голым `catch` наравне с обрывом связи и молчали или рисовали
/// его в панели устройства — ровно тот дефект, ради избавления от которого
/// делалась задача 4, переехавший на слой выше.
///
/// `_SpyLoginNotifier` подменяет `LoginNotifier` целиком — этому файлу важно
/// только то, что экран **зовёт** `sessionLost()` и уходит на `/login`, а не
/// то, что делает сам нотифаер внутри (это уже доказано
/// `test/presentation/auth/session_expiry_test.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/domain/device/device_check.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_discovery.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/auth/login_controller.dart';
import 'package:telepos/presentation/screens/settings/hardware_settings_screen.dart';

import '../../auth/support/fakes.dart';

class _SpyLoginNotifier extends LoginNotifier {
  int sessionLostCalls = 0;
  SessionLost? lastError;

  @override
  LoginState build() => const LoginState();

  @override
  void sessionLost(SessionLost error) {
    sessionLostCalls++;
    lastError = error;
    state = state.copyWith(
      isAuthenticated: false,
      sessionEndedReason: 'error.session_ended',
    );
  }
}

/// [throwOnForTerminal]/[throwOnSave] — что бросить, если задано; `null` —
/// вызов проходит как обычно. Отдельные поля, а не общее одно:
/// `_loadSettings()` и `_saveSettings()` ловят провод порознь, и тест должен
/// уметь целить каждый по отдельности. Оба — `final`, заданные конструктором:
/// `DeviceBindingRepository` помечен `@immutable`, и оба всё равно нужны
/// только до пампа виджета (`_loadSettings()`) либо после, но известны заранее
/// — мутировать их посреди теста не требуется.
class _FakeDeviceBindingRepository implements DeviceBindingRepository {
  _FakeDeviceBindingRepository({
    List<DeviceBinding> seed = const [],
    this.throwOnForTerminal,
    this.throwOnSave,
  }) : _bindings = List.of(seed);

  final List<DeviceBinding> _bindings;

  final Object? throwOnForTerminal;
  final Object? throwOnSave;

  @override
  Future<List<DeviceBinding>> forTerminal(int terminalId) async {
    final error = throwOnForTerminal;
    if (error != null) throw error;
    return List.of(_bindings);
  }

  @override
  Stream<List<DeviceBinding>> watchForTerminal(int terminalId) =>
      Stream.value(List.of(_bindings));

  @override
  Future<void> save(int terminalId, DeviceBinding binding) async {
    final error = throwOnSave;
    if (error != null) throw error;
    _bindings.add(binding);
  }
}

class _FakeDeviceCheck implements DeviceCheck {
  Object? throwOnCheck;

  @override
  Future<DeviceCheckOutcome> check({
    required int terminalId,
    required DeviceClass deviceClass,
  }) async {
    final error = throwOnCheck;
    if (error != null) throw error;
    return DeviceCheckOutcome.ok();
  }
}

/// Пункт 4 второго круга разбора (2026-08-21): пятое место — поиск
/// устройств — этого файла (и вообще ни одного файла) не задело.
class _FakeDeviceDiscovery implements DeviceDiscovery {
  Object? throwOnFind;

  @override
  Future<DeviceDiscoveryResult> find(DeviceClass deviceClass) async {
    final error = throwOnFind;
    if (error != null) throw error;
    return const DeviceDiscoveryResult();
  }
}

/// Ровно то же исключение, каким сторож кассы отвечает на просроченный или
/// неизвестный токен (`WireDenied.unauthorized`, докстринг `session_lost.dart`).
const _sessionLost = SessionLost(
  'terminals.deviceCheck: сеанс неизвестен или истёк',
);

/// Единственный реальный профиль без параметров подключения — экран рисует
/// кнопку «проверить устройство» только когда выбранный `profileId` находится
/// в каталоге (`DeviceBindingEditor._selectedProfile`), так что для проверки
/// нужен настоящий id, а не любая строка.
const _scannerProfileId = 'scanner.usb.hid';

/// Профиль **с** параметром подключения (`comPort`) — в отличие от
/// [_scannerProfileId], у него есть кнопка «искать» рядом с полем: поиск
/// устройств рисуется на класс с непустым `connectionParams`
/// (`DeviceBindingEditor._buildParamFields`), а у весов он есть.
const _scaleProfileId = 'scale.cas.pd2';

Future<({ProviderContainer container, _SpyLoginNotifier spy})> _pumpScreen(
  WidgetTester tester, {
  required DeviceBindingRepository bindingRepo,
  required DeviceCheck deviceCheck,
  DeviceDiscovery? deviceDiscovery,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  GetIt.instance
    ..registerSingleton<DeviceProfileCatalog>(BuiltinDeviceProfileCatalog())
    ..registerSingleton<DeviceBindingRepository>(bindingRepo)
    ..registerSingleton<TerminalRepository>(
      FakeTerminalRepository(
        self: () async => const Terminal(
          id: 1,
          name: 'Касса-1',
          pointMode: PointMode.cashier,
        ),
      ),
    )
    ..registerSingleton<DeviceCheck>(deviceCheck);
  if (deviceDiscovery != null) {
    GetIt.instance.registerSingleton<DeviceDiscovery>(deviceDiscovery);
  }

  final spy = _SpyLoginNotifier();
  final container = ProviderContainer(
    overrides: [
      loginControllerProvider.overrideWith(() => spy),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.hardwareSettings,
    routes: [
      GoRoute(
        path: AppRoutes.hardwareSettings,
        builder: (context, state) => const HardwareSettingsScreen(),
      ),
      // Плейсхолдер, а не настоящий `LoginScreen`: этому тесту важно, что
      // экран действительно уходит на `AppRoutes.login`, а не что рисует
      // сам вход — у того свой файл.
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('LOGIN_STUB'))),
      ),
    ],
  );

  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
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
    ),
  );
  await tester.pumpAndSettle();

  return (container: container, spy: spy);
}

void main() {
  tearDown(() => GetIt.instance.reset());

  testWidgets(
    'загрузка настроек: SessionLost гасит сеанс и уводит на вход, не открывает '
    'экран с умолчаниями',
    (tester) async {
      final bindingRepo = _FakeDeviceBindingRepository(
        throwOnForTerminal: _sessionLost,
      );
      final result = await _pumpScreen(
        tester,
        bindingRepo: bindingRepo,
        deviceCheck: _FakeDeviceCheck(),
      );

      expect(
        result.spy.sessionLostCalls,
        1,
        reason:
            'красный без правки: голый `catch (_)` глотал SessionLost и '
            'открывал экран с умолчаниями, будто ничего не случилось',
      );
      expect(result.spy.lastError, same(_sessionLost));
      expect(
        find.text('LOGIN_STUB'),
        findsOneWidget,
        reason: 'экран обязан увести на вход, а не остаться с умолчаниями',
      );
      expect(find.byType(HardwareSettingsScreen), findsNothing);
    },
  );

  testWidgets(
    'сохранение: SessionLost гасит сеанс и уводит на вход, а не улетает в '
    'необработанный Future нажатия «Сохранить»',
    (tester) async {
      final bindingRepo = _FakeDeviceBindingRepository(
        seed: const [
          DeviceBinding(
            deviceClass: DeviceClass.scanner,
            profileId: _scannerProfileId,
          ),
        ],
        throwOnSave: _sessionLost,
      );
      final result = await _pumpScreen(
        tester,
        bindingRepo: bindingRepo,
        deviceCheck: _FakeDeviceCheck(),
      );

      final l10n = AppLocalizations.of(
        tester.element(find.byType(HardwareSettingsScreen)),
      )!;
      await tester.tap(find.text(l10n.globalSave));
      await tester.pumpAndSettle();

      expect(
        result.spy.sessionLostCalls,
        1,
        reason:
            'красный без правки: SessionLost улетал сквозь `_saveSettings`, '
            'брошенный в `onPressed` как необработанный Future — ни '
            'зелёного снекбара, ни красного, ни экрана входа',
      );
      expect(result.spy.lastError, same(_sessionLost));
      expect(find.text('LOGIN_STUB'), findsOneWidget);
    },
  );

  testWidgets(
    'проверка устройства: SessionLost гасит сеанс и уводит на вход, а не '
    'рисуется в панели рядом с «касса не отвечает»',
    (tester) async {
      final bindingRepo = _FakeDeviceBindingRepository(
        seed: const [
          DeviceBinding(
            deviceClass: DeviceClass.scanner,
            profileId: _scannerProfileId,
          ),
        ],
      );
      final deviceCheck = _FakeDeviceCheck();
      final result = await _pumpScreen(
        tester,
        bindingRepo: bindingRepo,
        deviceCheck: deviceCheck,
      );

      deviceCheck.throwOnCheck = _sessionLost;

      expect(
        find.byKey(const Key('device_check_button')),
        findsOneWidget,
        reason:
            'предпосылка — привязка с настоящим profileId обязана открыть '
            'кнопку проверки',
      );
      await tester.tap(find.byKey(const Key('device_check_button')));
      await tester.pumpAndSettle();

      expect(
        result.spy.sessionLostCalls,
        1,
        reason:
            'красный без правки: голый `catch (e)` заворачивал SessionLost '
            'в DeviceCheckOutcome.unexpectedError и рисовал в той же панели, '
            'что и неотвечающую кассу',
      );
      expect(result.spy.lastError, same(_sessionLost));
      expect(find.text('LOGIN_STUB'), findsOneWidget);
      expect(
        find.byKey(const Key('device_check_outcome')),
        findsNothing,
        reason:
            'SessionLost не имеет права стать обычным исходом проверки — '
            'экран уже ушёл на вход',
      );
    },
  );

  testWidgets('поиск устройств: SessionLost гасит сеанс и уводит на вход, а не '
      'открывает диалог «эти источники опросить не удалось»', (tester) async {
    // Пункт 4 второго круга разбора (2026-08-21): пятое место одной и той
    // же болезни — `WtDeviceDiscovery.find` заворачивала `SessionLost` в
    // `failedSources` наравне с обрывом связи, а этот экран поверх неё
    // ловил всё голым `catch (e)`. До этой правки поиск устройств не был
    // задет ни в первом круге задачи 4, ни в первой волне — этого теста
    // не было ни в одном файле.
    final bindingRepo = _FakeDeviceBindingRepository(
      seed: const [
        DeviceBinding(
          deviceClass: DeviceClass.scale,
          profileId: _scaleProfileId,
        ),
      ],
    );
    final discovery = _FakeDeviceDiscovery();
    final result = await _pumpScreen(
      tester,
      bindingRepo: bindingRepo,
      deviceCheck: _FakeDeviceCheck(),
      deviceDiscovery: discovery,
    );

    discovery.throwOnFind = _sessionLost;

    final searchButton = find.byKey(
      const Key('search_${_scaleProfileId}_comPort'),
    );
    expect(
      searchButton,
      findsOneWidget,
      reason:
          'предпосылка — привязка весов с настоящим profileId и '
          'параметром подключения обязана открыть кнопку «искать»',
    );
    await tester.tap(searchButton);
    await tester.pumpAndSettle();

    expect(
      result.spy.sessionLostCalls,
      1,
      reason:
          'красный без правки: голый `catch (e)` в `_search` заворачивал '
          'SessionLost в снекбар с текстом исключения — кассир не уходил '
          'на вход, а сеанс не гас',
    );
    expect(result.spy.lastError, same(_sessionLost));
    expect(find.text('LOGIN_STUB'), findsOneWidget);
    expect(
      find.byKey(const Key('discovery_failed_sources')),
      findsNothing,
      reason:
          'SessionLost не имеет права стать обычным диалогом «источники '
          'не опрошены» — экран уже ушёл на вход',
    );
  });
}
