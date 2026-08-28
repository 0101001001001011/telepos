/// Задача 7 волны правок фазы 2: то же, что
/// `printer_settings_screen_session_lost_test.dart`, для соседнего экрана —
/// `LabelPrinterSettingsScreen` ловит `SessionLost` голым `catch` в своих
/// собственных `_loadSettings()`/`_saveSettings()`, не разделяемых ни с
/// `HardwareSettingsScreen`, ни с `PrinterSettingsScreen`. Общий у всех трёх
/// только `DeviceBindingEditor` (кнопка «проверить устройство»), уже
/// покрытая `hardware_settings_screen_test.dart` — один тест не мог бы
/// накрыть эти два места и то заодно.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/auth/login_controller.dart';
import 'package:telepos/presentation/screens/settings/label_printer_settings_screen.dart';

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

const _sessionLost = SessionLost(
  'terminals.deviceCheck: сеанс неизвестен или истёк',
);

const _labelPrinterProfileId = 'printer.label.zpl.104mm';

Future<({ProviderContainer container, _SpyLoginNotifier spy})> _pumpScreen(
  WidgetTester tester, {
  required DeviceBindingRepository bindingRepo,
}) async {
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
    );

  final spy = _SpyLoginNotifier();
  final container = ProviderContainer(
    overrides: [loginControllerProvider.overrideWith(() => spy)],
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.labelPrinterSettings,
    routes: [
      GoRoute(
        path: AppRoutes.labelPrinterSettings,
        builder: (context, state) => const LabelPrinterSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('LOGIN_STUB'))),
      ),
    ],
  );

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
    'загрузка настроек принтера этикеток: SessionLost гасит сеанс и уводит '
    'на вход, не открывает экран с умолчаниями',
    (tester) async {
      final bindingRepo = _FakeDeviceBindingRepository(
        throwOnForTerminal: _sessionLost,
      );
      final result = await _pumpScreen(tester, bindingRepo: bindingRepo);

      expect(
        result.spy.sessionLostCalls,
        1,
        reason:
            'красный без правки: голый `catch (_)` в `_loadSettings()` глотал '
            'SessionLost и открывал экран с умолчаниями',
      );
      expect(result.spy.lastError, same(_sessionLost));
      expect(find.text('LOGIN_STUB'), findsOneWidget);
      expect(find.byType(LabelPrinterSettingsScreen), findsNothing);
    },
  );

  testWidgets(
    'сохранение настроек принтера этикеток: SessionLost гасит сеанс и уводит '
    'на вход, а не остаётся отказом «неверный параметр»',
    (tester) async {
      final bindingRepo = _FakeDeviceBindingRepository(
        seed: const [
          DeviceBinding(
            deviceClass: DeviceClass.labelPrinter,
            profileId: _labelPrinterProfileId,
            parameters: {'ipAddress': '10.0.0.6', 'port': '9100'},
            options: {'paperWidthMm': '104', 'labelHeightMm': '40'},
          ),
        ],
        throwOnSave: _sessionLost,
      );
      final result = await _pumpScreen(tester, bindingRepo: bindingRepo);

      await tester.tap(find.byIcon(TeleposIcons.save));
      await tester.pumpAndSettle();

      expect(
        result.spy.sessionLostCalls,
        1,
        reason:
            'красный без правки: `_saveSettings()` не ловила `SessionLost` '
            'вовсе — отказ выглядел как «неверный параметр», а не как конец '
            'сеанса',
      );
      expect(result.spy.lastError, same(_sessionLost));
      expect(find.text('LOGIN_STUB'), findsOneWidget);
    },
  );
}
