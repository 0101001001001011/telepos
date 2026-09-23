/// Задача 19 закрытия долга безопасности: `SessionRegistry.revokeAll()`
/// существовал с задачи 9 и не звался ни одной строкой рабочего кода.
/// Эти тесты проверяют не отрисовку, а то, что щелчок доходит до самого
/// `SessionRegistry`, живьём — и что отзыв гасит подписку токена того же
/// сеанса, тем самым путём, которым отозванная вкладка уходит на вход сама
/// (задача 5, `LoginNotifier._onSession`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/domain/auth/session_admin.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/sessions_screen.dart';

void main() {
  late SessionRegistry registry;

  setUp(() {
    GetIt.I.allowReassignment = true;
    registry = SessionRegistry();
    // Правка «второй порядок» закрытия долга безопасности (2026-08-22),
    // пункт 6: контроллер экрана теперь читает узкий порт SessionAdmin, не
    // конкретный SessionRegistry (см. докстринг sessions_controller.dart) —
    // тот же приём, каким на настоящей кассе оба ключа биндятся на один
    // экземпляр (service_locator.dart). Регистрация под SessionRegistry
    // остаётся — некоторые тесты ниже читают её напрямую, чтобы завести
    // сеанс через registry.mint(...).
    GetIt.I.registerSingleton<SessionRegistry>(registry);
    GetIt.I.registerSingleton<SessionAdmin>(registry);
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ru')],
          locale: const Locale('ru'),
          home: const SessionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'пустой реестр показывает "никто не вошёл", не список из ничего',
    (tester) async {
      await pumpScreen(tester);

      expect(find.byKey(const ValueKey('sessions-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('sessions-list')), findsNothing);
    },
  );

  testWidgets('живой сеанс из настоящего SessionRegistry виден на экране', (
    tester,
  ) async {
    registry.mint(
      userId: 7,
      name: 'Айгуль',
      role: 'cashier',
      permissions: const {},
      operatingMode: 0,
      pointMode: 'cashier',
      shiftOpen: false,
      terminalId: 5,
    );

    await pumpScreen(tester);

    expect(find.text('Айгуль'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sessions-revoke-5')),
      findsOneWidget,
      reason: 'кнопка отзыва обязана называть тот же terminalId, что и сеанс',
    );
  });

  testWidgets(
    'щелчок «Завершить» и подтверждение доходят до настоящего SessionRegistry',
    (tester) async {
      final session = registry.mint(
        userId: 7,
        name: 'Айгуль',
        role: 'cashier',
        permissions: const {},
        operatingMode: 0,
        pointMode: 'cashier',
        shiftOpen: false,
        terminalId: 5,
      );

      await pumpScreen(tester);
      expect(registry.lookup(session.token), isNotNull);

      await tester.tap(find.byKey(const ValueKey('sessions-revoke-5')));
      await tester.pumpAndSettle();

      // Диалог подтверждения — кнопка «Завершить» внутри него.
      await tester.tap(find.text('Завершить').last);
      await tester.pumpAndSettle();

      expect(
        registry.lookup(session.token),
        isNull,
        reason:
            'щелчок не доехал до настоящего реестра — на кассе это осталось '
            'бы кнопкой, которую нечем нажать',
      );
      // Список сам обновился без перезахода на экран — тот же путь, что
      // используют auth.users/auth.session.
      expect(find.byKey(const ValueKey('sessions-empty')), findsOneWidget);
    },
  );

  testWidgets('отзыв доходит до подписки токена того же сеанса — путь, которым '
      'отозванная вкладка уходит на вход сама', (tester) async {
    final session = registry.mint(
      userId: 7,
      name: 'Айгуль',
      role: 'cashier',
      permissions: const {},
      operatingMode: 0,
      pointMode: 'cashier',
      shiftOpen: false,
      terminalId: 5,
    );

    final seen = <int?>[];
    final sub = registry
        .watch(session.token)
        .listen((s) => seen.add(s?.userId));
    addTearDown(() => sub.cancel());

    await pumpScreen(tester);
    await tester.pump();
    expect(seen, [7]);

    await tester.tap(find.byKey(const ValueKey('sessions-revoke-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Завершить').last);
    await tester.pumpAndSettle();

    expect(
      seen,
      [7, null],
      reason:
          'ровно то событие, на которое реагирует LoginNotifier '
          '(login_controller.dart, _onSession): вкладка уходит на вход '
          'без единого нажатия',
    );
  });

  testWidgets('отмена в диалоге ничего не гасит', (tester) async {
    final session = registry.mint(
      userId: 7,
      name: 'Айгуль',
      role: 'cashier',
      permissions: const {},
      operatingMode: 0,
      pointMode: 'cashier',
      shiftOpen: false,
      terminalId: 5,
    );

    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('sessions-revoke-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(registry.lookup(session.token), isNotNull);
  });
}
