// Дом терминала — куда `getPostLoginRoute()` ведёт вошедшего там, где базы
// нет (`HostCapabilities.ownsData == false`, задача 12 плана
// `2026-08-20-browser-terminal-login.md`). Все данные экрана уже приехали в
// `AuthSession` при входе и лежат в `AppState`
// (`lib/presentation/controllers/app/app_state_controller.dart`) — здесь
// сеется прямо в него, а не через настоящий вход, потому что это тест самого
// экрана, а не провода: вход по проводу уже проверен задачами 10-11.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/constants/enums/operating_mode.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/screens/terminal/terminal_home_screen.dart';

/// Сеанс, каким его видит экран, — три поля, которые задача и просит:
/// имя, состояние смены, действующие права. Полного `AuthSession` тут не
/// нужно: `TerminalHomeScreen` читает не его, а уже разложенный `AppState`.
typedef _Session = ({String name, bool shiftOpen, Set<String> permissions});

_Session sessionOf({
  required String name,
  required bool shiftOpen,
  required Set<String> permissions,
}) => (name: name, shiftOpen: shiftOpen, permissions: permissions);

/// Заглушка на месте настоящего `LoginScreen`.
///
/// Настоящий тянет `AuthRepository`/`TerminalIdentity`/`TerminalRepository`
/// через `GetIt` — поднимать их здесь означало бы тестировать вход, который
/// уже проверен своими файлами (`login_controller_test.dart`,
/// `wt_setup_router_test.dart`). Этому тесту нужно только одно: что дом
/// терминала на кнопке выхода действительно уходит на `AppRoutes.login`, а не
/// куда придётся, — и для этого достаточно узнаваемого экрана на том месте.
class _LoginStub extends StatelessWidget {
  const _LoginStub();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('LOGIN_STUB')));
}

/// Заглушка на месте настоящего `HardwareSettingsScreen` — по той же причине:
/// этому тесту важно, что плитка ведёт на `AppRoutes.hardwareSettings`, а не
/// что рисует сам экран оборудования (у него свой тестовый файл).
class _HardwareSettingsStub extends StatelessWidget {
  const _HardwareSettingsStub();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('HARDWARE_SETTINGS_STUB')));
}

/// Заглушка на месте настоящего `SessionsScreen` — пункт 6 закрытия долга
/// безопасности, правка «второй порядок»: этому тесту важно, что плитка
/// ведёт на `AppRoutes.sessions`, а не что рисует сам экран сеансов (у него
/// свой тестовый файл, `sessions_screen_test.dart`).
class _SessionsStub extends StatelessWidget {
  const _SessionsStub();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('SESSIONS_STUB')));
}

/// [AppStateNotifier.build] заводит два `Timer.periodic` (часы в шапке,
/// опрос свободного места). Это ничему не мешает в приложении, но
/// `testWidgets` поднимает тело теста в `FakeAsync`-зоне и требует, чтобы к
/// концу теста живых таймеров не осталось, — а `container.dispose()` из
/// `addTearDown` физически не успевает сработать раньше этой проверки:
/// `_verifyInvariants` — часть тела теста, `addTearDown` — то, что бежит
/// после него. Настоящему экрану эти таймеры не нужны вовсе (он не читает
/// ни часы, ни хранилище), поэтому здесь стоит тот же приём, что уже
/// применён в `test/helpers/mock_providers.dart`
/// (`MockAppStateNotifier`) и `test/integration/test_utils.dart` —
/// подмена `Notifier`, у которой `build()` ничего не заводит, а
/// изменяющие методы работают по-настоящему, а не заглушкой в никуда: этому
/// тесту важно, что `setUserInfo`/`setShiftOpened`/`logout` действительно
/// меняют состояние, которое читает экран.
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
  void setShiftOpened(bool isOpened) {
    state = state.copyWith(isShiftOpened: isOpened);
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

/// Поднимает [TerminalHomeScreen] настоящей темой приложения и настоящими
/// делегатами локализации — не голым `MaterialApp`, как это сделано в
/// 29 файлах, которые правились до этой задачи (см. бриф задачи 12).
///
/// Маршрутизатор — свой, крошечный, а не `createSetupRouter()`: тому и так
/// есть отдельный сторож (`browser_routes_test.dart`,
/// `wt_setup_router_test.dart`), а этому тесту нужно только проверить, что
/// сам экран уходит по объявленным путям, когда его на них зовут.
Widget terminalHomeUnderTest({required _Session session}) {
  final container = ProviderContainer(
    overrides: [appStateProvider.overrideWith(_TestAppStateNotifier.new)],
  );
  addTearDown(container.dispose);

  container.read(appStateProvider.notifier)
    ..setUserInfo(id: 1, name: session.name, role: 0, permissions: session.permissions)
    ..setShiftOpened(session.shiftOpen);

  final router = GoRouter(
    initialLocation: AppRoutes.terminalHome,
    routes: [
      GoRoute(
        path: AppRoutes.terminalHome,
        builder: (context, state) => const TerminalHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const _LoginStub(),
      ),
      GoRoute(
        path: AppRoutes.hardwareSettings,
        builder: (context, state) => const _HardwareSettingsStub(),
      ),
      GoRoute(
        path: AppRoutes.sessions,
        builder: (context, state) => const _SessionsStub(),
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
  testWidgets('дом терминала показывает вошедшего и состояние смены', (
    tester,
  ) async {
    await tester.pumpWidget(
      terminalHomeUnderTest(
        session: sessionOf(
          name: 'Айгуль',
          shiftOpen: true,
          permissions: {'nav.sale'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Айгуль'), findsOneWidget);
    expect(find.textContaining('Смена открыта'), findsOneWidget);
  });

  // Красный без ветвления по `isShiftOpened` в экране: если бы строка была
  // одна и та же независимо от состояния, этот тест и предыдущий требовали
  // бы двух разных текстов от одного и того же кода и один из них падал бы.
  testWidgets('закрытая смена читается как закрытая, а не как открытая', (
    tester,
  ) async {
    await tester.pumpWidget(
      terminalHomeUnderTest(
        session: sessionOf(
          name: 'Айгуль',
          shiftOpen: false,
          permissions: const {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Смена закрыта'), findsOneWidget);
    expect(find.textContaining('Смена открыта'), findsNothing);
  });

  testWidgets('кнопки без права не показываются вовсе', (tester) async {
    await tester.pumpWidget(
      terminalHomeUnderTest(
        session: sessionOf(
          name: 'Айгуль',
          shiftOpen: false,
          permissions: const {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Не «показать и не дать нажать»: раздел 11 требует ограничения на уровне
    // данных, и показанная кнопка, которая ничего не делает, — обещание,
    // которого система не держит.
    expect(find.text('Оборудование'), findsNothing);
  });

  // Дополняет предыдущий тест с другой стороны: мало спрятать плитку без
  // права — обязана показаться и заработать, когда право есть. Тест,
  // который проверяет только «спрятано», зазеленел бы и на экране, который
  // не строит эту плитку вообще никогда.
  testWidgets('право settings.hardware показывает плитку и она ведёт куда обещано', (
    tester,
  ) async {
    await tester.pumpWidget(
      terminalHomeUnderTest(
        session: sessionOf(
          name: 'Айгуль',
          shiftOpen: true,
          permissions: {PermissionKeys.settingsHardware},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tile = find.text('Оборудование');
    expect(tile, findsOneWidget);

    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.text('HARDWARE_SETTINGS_STUB'), findsOneWidget);
  });

  // Пункт 6 закрытия долга безопасности, правка «второй порядок»: тот же
  // приём, что уже проверен парой тестов выше для «Оборудование» —
  // settings.hardware и settings.users фильтруют независимые плитки.
  testWidgets('без settings.users плитка «Активные сеансы» не строится', (
    tester,
  ) async {
    await tester.pumpWidget(
      terminalHomeUnderTest(
        session: sessionOf(
          name: 'Айгуль',
          shiftOpen: false,
          permissions: const {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Активные сеансы'), findsNothing);
  });

  testWidgets(
    'право settings.users показывает плитку «Активные сеансы» и она ведёт '
    'куда обещано',
    (tester) async {
      await tester.pumpWidget(
        terminalHomeUnderTest(
          session: sessionOf(
            name: 'Айгуль',
            shiftOpen: true,
            permissions: {PermissionKeys.settingsUsers},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tile = find.text('Активные сеансы');
      expect(tile, findsOneWidget);

      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(find.text('SESSIONS_STUB'), findsOneWidget);
    },
  );

  testWidgets('выход гасит сеанс и уводит на вход', (tester) async {
    await tester.pumpWidget(
      terminalHomeUnderTest(
        session: sessionOf(
          name: 'Айгуль',
          shiftOpen: true,
          permissions: {PermissionKeys.settingsHardware},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Айгуль'), findsOneWidget);

    await tester.tap(find.text('Выход'));
    await tester.pumpAndSettle();

    // Уводит на вход...
    expect(find.text('LOGIN_STUB'), findsOneWidget);
    // ...и гасит сеанс, а не просто уходит с экрана, на котором он был виден:
    // если бы `_logout` звал только `context.go` без `AppStateNotifier.logout()`,
    // это не поймал бы ни один из двух `expect` — общий предок разобран, а
    // это нашло бы то же имя в другом дереве, если бы состояние утекло.
    final leftoverName = find.text('Айгуль');
    expect(leftoverName, findsNothing);
  });
}
