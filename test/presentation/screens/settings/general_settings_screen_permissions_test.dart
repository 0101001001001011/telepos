/// Правка «второй порядок» закрытия долга безопасности (2026-08-22),
/// пункт 3: `general_settings_screen.dart` не проверял ни одного права
/// (`grep` по `hasPermission`/`routeToPermissionKey` в файле был пуст).
/// Администратор без `settings.users` видел плитки «Пользователи», «Вход и
/// сеанс», «Активные сеансы», нажимал — и молча оказывался на продаже
/// (десктопный `redirect`, `app_router.dart`, уводит на дом без единого
/// слова). Одиннадцать плиток были видимо-мёртвыми.
///
/// Этот тест — то же самое, чем `terminal_home_screen_test.dart` уже проверяет
/// дом терминала: подмена `AppStateNotifier`, реальная тема и локализация,
/// плитка либо не строится вовсе без права (раздел 11 управляющего документа —
/// не «показать и не дать нажать»), либо строится и ведёт по объявленному
/// маршруту, когда право есть.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/constants/enums/operating_mode.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/screens/settings/general_settings_screen.dart';
import 'package:telepos/domain/shift/shift_status.dart';
import '../../../support/till_currency.dart';
import 'package:get_it/get_it.dart';

/// Тот же приём, что уже стоит в `terminal_home_screen_test.dart`:
/// `AppStateNotifier.build()` заводит таймеры (часы, опрос места), которые
/// `testWidgets` не прощает живыми к концу теста, а настоящему экрану они не
/// нужны — читается только `AppState.permissions`.
class _TestAppStateNotifier extends Notifier<AppState>
    implements AppStateNotifier {
  @override
  AppState build() => const AppState();

  @override
  void setPosInfo({String? name}) {
    state = state.copyWith(posName: name, clearPosName: name == null);
  }

  @override
  void setUserInfo({
    int? id,
    String? name,
    int? role,
    Set<String>? permissions,
  }) {
    state = state.copyWith(
      userId: id,
      clearUserId: id == null,
      userName: name,
      clearUserName: name == null,
      userRole: role,
      clearUserRole: role == null,
      permissions: permissions,
    );
  }

  @override
  void setTestUser({required int userId, String? userName}) {
    state = state.copyWith(userId: userId, userName: userName ?? 'Test User');
  }

  @override
  void setShift(ShiftStatus shift) {
    state = state.copyWith(shift: shift);
  }

  @override
  void setConnectionStatus(ConnectionStatus status) {
    state = state.copyWith(connectionStatus: status);
  }

  @override
  void dismissStorageWarning() {
    state = state.copyWith(showStorageWarning: false);
  }

  @override
  void setOperatingMode(OperatingMode mode) {
    state = state.copyWith(operatingMode: mode);
  }

  @override
  void logout() {
    state = state.copyWith(
      clearUserId: true,
      clearUserName: true,
      clearUserRole: true,
      permissions: const {},
    );
  }
}

class _Stub extends StatelessWidget {
  const _Stub(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}

/// Тот же экран, что видит вошедший в кассу оператор — реальная тема,
/// реальные делегаты локализации, а не голый `MaterialApp`.
Widget generalSettingsUnderTest({
  required Set<String> permissions,
  required SharedPreferences prefs,
}) {
  final container = ProviderContainer(
    overrides: [
      appStateProvider.overrideWith(_TestAppStateNotifier.new),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(container.dispose);

  container
      .read(appStateProvider.notifier)
      .setUserInfo(id: 1, name: 'Тест', role: 1, permissions: permissions);

  final router = GoRouter(
    initialLocation: AppRoutes.settings,
    routes: [
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const GeneralSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.userManagement,
        builder: (context, state) => const _Stub('USER_MANAGEMENT_STUB'),
      ),
      GoRoute(
        path: AppRoutes.authSettings,
        builder: (context, state) => const _Stub('AUTH_SETTINGS_STUB'),
      ),
      GoRoute(
        path: AppRoutes.sessions,
        builder: (context, state) => const _Stub('SESSIONS_STUB'),
      ),
      GoRoute(
        path: AppRoutes.terminalServiceSettings,
        builder: (context, state) => const _Stub('TERMINAL_SERVICE_STUB'),
      ),
      // Разбор фазы 1 работы «знакомство терминала с кассой» (2026-08-23),
      // блокер 2: до этой правки ни один тест не падал, если убрать плитку
      // «Привязка терминала» из хаба или ключ права у маршрута — щуп
      // `test/manual/wt_pairing_probe.dart` помечен `manual` и пропускается
      // набором безусловно, он стенд, а не сторож.
      GoRoute(
        path: AppRoutes.terminalPairing,
        builder: (context, state) => const _Stub('TERMINAL_PAIRING_STUB'),
      ),
      GoRoute(
        path: AppRoutes.applianceSettings,
        builder: (context, state) => const _Stub('APPLIANCE_STUB'),
      ),
      GoRoute(
        path: AppRoutes.printerSettings,
        builder: (context, state) => const _Stub('PRINTER_STUB'),
      ),
    ],
  );

  return UncontrolledProviderScope(
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
  );
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    registerTillCurrency();
  });

  tearDown(() async => GetIt.I.reset());

  testWidgets(
    'без settings.users плитки «Пользователи», «Вход и сеанс», «Активные '
    'сеансы» не строятся вовсе',
    (tester) async {
      await tester.pumpWidget(
        generalSettingsUnderTest(permissions: const {}, prefs: prefs),
      );
      await tester.pumpAndSettle();

      // Не «показать и не дать нажать» (раздел 11 управляющего документа):
      // плитка отсутствует, а не выключена.
      expect(find.text('Пользователи'), findsNothing);
      expect(find.text('Вход и сеанс'), findsNothing);
      expect(find.text('Активные сеансы'), findsNothing);
    },
  );

  testWidgets(
    'без settings.terminalService/settings.appliance/settings.printer '
    'соответствующие плитки тоже не строятся',
    (tester) async {
      await tester.pumpWidget(
        generalSettingsUnderTest(permissions: const {}, prefs: prefs),
      );
      await tester.pumpAndSettle();

      expect(find.text('Браузерные терминалы'), findsNothing);
      expect(find.text('Система (TelePOS OS)'), findsNothing);
      expect(find.text('Принтер'), findsNothing);
    },
  );

  testWidgets(
    'settings.users показывает все три плитки периметра и каждая ведёт на '
    'объявленный маршрут',
    (tester) async {
      await tester.pumpWidget(
        generalSettingsUnderTest(
          permissions: {PermissionKeys.settingsUsers},
          prefs: prefs,
        ),
      );
      await tester.pumpAndSettle();

      final usersTile = find.text('Пользователи');
      expect(usersTile, findsOneWidget);
      await tester.tap(usersTile);
      await tester.pumpAndSettle();
      expect(find.text('USER_MANAGEMENT_STUB'), findsOneWidget);
    },
  );

  testWidgets('settings.terminalService показывает ровно эту плитку и ведёт на '
      '/terminal-service-settings — самый острый маршрут пункта 1', (
    tester,
  ) async {
    await tester.pumpWidget(
      generalSettingsUnderTest(
        permissions: {PermissionKeys.settingsTerminalService},
        prefs: prefs,
      ),
    );
    await tester.pumpAndSettle();

    final tile = find.text('Браузерные терминалы');
    expect(tile, findsOneWidget);
    // Соседняя, независимая плитка права остаётся скрытой — доказывает,
    // что видимость идёт по конкретному ключу, а не по «хоть что-то есть».
    expect(find.text('Пользователи'), findsNothing);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('TERMINAL_SERVICE_STUB'), findsOneWidget);
  });

  testWidgets(
    'без settings.users плитка «Привязка терминала» не строится — разбор '
    'фазы 1 работы «знакомство терминала с кассой» (2026-08-23), блокер 2: '
    'до этого теста ни один сторож не краснел, если убрать плитку или её '
    'ключ права',
    (tester) async {
      await tester.pumpWidget(
        generalSettingsUnderTest(permissions: const {}, prefs: prefs),
      );
      await tester.pumpAndSettle();

      expect(find.text('Привязка терминала'), findsNothing);
    },
  );

  testWidgets(
    'settings.users показывает плитку «Привязка терминала» и она ведёт на '
    '/terminal-pairing',
    (tester) async {
      await tester.pumpWidget(
        generalSettingsUnderTest(
          permissions: {PermissionKeys.settingsUsers},
          prefs: prefs,
        ),
      );
      await tester.pumpAndSettle();

      final tile = find.text('Привязка терминала');
      expect(tile, findsOneWidget);

      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.text('TERMINAL_PAIRING_STUB'), findsOneWidget);
    },
  );

  testWidgets(
    'плитки без ключа права (демо-данные, проверка обновлений) видны всегда '
    '— решение, а не пробел',
    (tester) async {
      await tester.pumpWidget(
        generalSettingsUnderTest(permissions: const {}, prefs: prefs),
      );
      await tester.pumpAndSettle();

      expect(find.text('Обновление приложения'), findsOneWidget);
      expect(find.text('Демо данные'), findsOneWidget);
    },
  );
}
