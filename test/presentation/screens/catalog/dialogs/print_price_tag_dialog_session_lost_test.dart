/// Задача 7 волны правок фазы 2: `PrintPriceTagDialog._findLabelPrinterBinding()`
/// звало `DeviceBindingRepository.forTerminal()` через голый `catch (_)`,
/// не учитывавший `SessionLost` вовсе — истёкший сеанс превращался в
/// «принтер не настроен», а не в уход на вход.
///
/// `PrintPriceTagDialog` — не `ConsumerStatefulWidget` (обычный `State`),
/// поэтому доступ к `loginControllerProvider` идёт через
/// `ProviderScope.containerOf`, а не через `ref` — хост этого теста должен
/// дать диалогу настоящий `ProviderScope` в дереве, как это делает
/// `main_web.dart` в реальной кассе.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/data/database/app_database.dart' hide Terminal;
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/auth/login_controller.dart';
import 'package:telepos/presentation/screens/catalog/dialogs/print_price_tag_dialog.dart';

import '../../../auth/support/fakes.dart';

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
  _FakeDeviceBindingRepository({this.throwOnForTerminal});

  final Object? throwOnForTerminal;

  @override
  Future<List<DeviceBinding>> forTerminal(int terminalId) async {
    final error = throwOnForTerminal;
    if (error != null) throw error;
    return const [];
  }

  @override
  Stream<List<DeviceBinding>> watchForTerminal(int terminalId) =>
      const Stream.empty();

  @override
  Future<void> save(int terminalId, DeviceBinding binding) async {}
}

const _sessionLost = SessionLost(
  'terminals.deviceCheck: сеанс неизвестен или истёк',
);

void main() {
  tearDown(() => GetIt.instance.reset());

  testWidgets(
    'печать ценника: SessionLost при чтении привязки гасит сеанс и уводит '
    'на вход, а не рисуется как «принтер не настроен»',
    (tester) async {
      // Настоящая база, а не двойник: диалог сам заводит шаблоны по
      // умолчанию (`dao.seedDefaults()`) и без хотя бы одного шаблона кнопка
      // печати остаётся выключенной (`_selected == null`) — тест не дошёл
      // бы до вызова `_findLabelPrinterBinding()` вовсе.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      GetIt.instance
        ..registerSingleton<AppDatabase>(db)
        ..registerSingleton<DeviceProfileCatalog>(BuiltinDeviceProfileCatalog())
        ..registerSingleton<DeviceBindingRepository>(
          _FakeDeviceBindingRepository(throwOnForTerminal: _sessionLost),
        )
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
        initialLocation: '/catalog',
        routes: [
          GoRoute(
            path: '/catalog',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => PrintPriceTagDialog.show(
                    context,
                    products: [
                      PriceTagProduct(
                        name: 'Тест-товар',
                        barcode: '4607001000001',
                        price: Decimal.fromInt(1000),
                      ),
                    ],
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
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

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.print));
      await tester.pumpAndSettle();

      expect(
        spy.sessionLostCalls,
        1,
        reason:
            'красный без правки: голый `catch (_)` в '
            '`_findLabelPrinterBinding()` глотал SessionLost и показывал '
            '"принтер не настроен"',
      );
      expect(spy.lastError, same(_sessionLost));
      expect(find.text('LOGIN_STUB'), findsOneWidget);
    },
  );
}
