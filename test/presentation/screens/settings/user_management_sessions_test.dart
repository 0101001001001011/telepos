/// Задача 19 закрытия долга безопасности завела вызов
/// `SessionRegistry.revokeAll()` из смены PIN, деактивации и удаления
/// пользователя — он существовал с задачи 9 и не звался ни одной строкой
/// рабочего кода. Правка после неё сузила это до
/// `SessionRegistry.revokeForUser(userId)`: `revokeAll()` гасил **всю**
/// кассу разом — смена PIN одного кассира вышибала бы коллег, работающих на
/// той же кассе, посреди смены. Эти тесты доказывают, что щелчок в этом
/// экране доходит до настоящего `SessionRegistry`, живого get_it-синглтона,
/// гасит сеанс затронутого пользователя и не трогает сторонний — тем же
/// приёмом, что `auth_settings_screen_test.dart` уже доказывает для
/// `SessionRegistry.idleTimeout`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/core/security/pin_credential.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/user_management_screen.dart';

void main() {
  late AppDatabase db;
  late SessionRegistry registry;
  const ownerId = 1;
  const cashierId = 2;

  ({String token, int userId}) mintUnrelatedSession() {
    // Сеанс постороннего кассира — единственный способ отличить узкий
    // отзыв от `revokeAll()`: если он погаснет вместе со своим, правка не
    // сузила ничего.
    final session = registry.mint(
      userId: 999,
      name: 'Сторонний кассир',
      role: 'cashier',
      permissions: const {},
      operatingMode: 0,
      pointMode: 'cashier',
      shiftOpen: false,
      terminalId: 42,
    );
    return (token: session.token, userId: 999);
  }

  setUp(() async {
    GetIt.I.allowReassignment = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    GetIt.I.registerSingleton<AppDatabase>(db);
    registry = SessionRegistry();
    GetIt.I.registerSingleton<SessionRegistry>(registry);

    await db.userDao.insertUser(
      UsersCompanion.insert(
        id: const Value(ownerId),
        name: const Value('Владелец Аскар'),
        role: const Value(0),
        status: const Value('active'),
        editTime: const Value(1000),
        passwordEnc: const Value('irrelevant-hash'),
      ),
    );
    await db.userDao.insertUser(
      UsersCompanion.insert(
        id: const Value(cashierId),
        name: const Value('Кассир Бота'),
        role: const Value(3),
        status: const Value('active'),
        editTime: const Value(1000),
        passwordEnc: Value(PinCredential.create('1234')),
      ),
    );
  });

  tearDown(() async {
    await db.close();
    await GetIt.I.reset();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
          supportedLocales: const [Locale('ru'), Locale('en')],
          locale: const Locale('ru'),
          home: const UserManagementScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapDigit(WidgetTester tester, String digit) async {
    // Диалог — единственный `Dialog` на экране; фон (список пользователей)
    // может показывать те же цифры в других местах, поэтому цифра ищется
    // внутри диалога, а не по всему дереву.
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text(digit)),
      warnIfMissed: false,
    );
    await tester.pump();
  }

  testWidgets('смена PIN кассира гасит его сеансы и не трогает сторонний', (
    tester,
  ) async {
    final unrelated = mintUnrelatedSession();
    final ownSession = registry.mint(
      userId: cashierId,
      name: 'Кассир Бота',
      role: 'cashier',
      permissions: const {},
      operatingMode: 0,
      pointMode: 'cashier',
      shiftOpen: false,
      terminalId: 1,
    );
    expect(registry.outstanding, 2);

    await pumpScreen(tester);
    await tester.tap(find.text('Кассир Бота'));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('PIN'));
    await tester.pumpAndSettle();

    for (final digit in ['5', '6', '7', '8']) {
      await tapDigit(tester, digit);
    }
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(ElevatedButton, 'Сохранить');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(
      registry.lookup(ownSession.token),
      isNull,
      reason:
          'смена PIN обязана погасить живой сеанс, выписанный на этого '
          'кассира — иначе сеанс на прежнем, уже смененном PIN жил бы до '
          'истечения по бездействию',
    );
    expect(
      registry.lookup(unrelated.token),
      isNotNull,
      reason:
          'сторонний кассир на той же кассе не должен вылетать из-за '
          'чужой смены PIN — это и есть отличие revokeForUser от '
          'revokeAll',
    );
    expect(registry.outstanding, 1);
  });

  testWidgets(
    'блокировка кассира гасит его сеанс, не трогает сторонний; повторное '
    'сохранение уже заблокированного — не гасит ничего',
    (tester) async {
      final unrelated = mintUnrelatedSession();
      registry.mint(
        userId: cashierId,
        name: 'Кассир Бота',
        role: 'cashier',
        permissions: const {},
        operatingMode: 0,
        pointMode: 'cashier',
        shiftOpen: false,
        terminalId: 1,
      );
      expect(registry.outstanding, 2);

      await pumpScreen(tester);
      await tester.tap(find.text('Кассир Бота'));
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SwitchListTile, 'Активен'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Сохранить'));
      await tester.pumpAndSettle();

      expect(
        registry.outstanding,
        1,
        reason:
            'деактивация обязана погасить сеанс заблокированного кассира и '
            'оставить сторонний сеанс живым',
      );
      expect(registry.lookup(unrelated.token), isNotNull);

      // Второй заход: пользователь уже blocked, повторное сохранение того
      // же состояния не должно вышибать заново заведённый сеанс — ни его
      // собственный, ни чужой.
      final freshSession = registry.mint(
        userId: cashierId,
        name: 'Кассир Бота',
        role: 'cashier',
        permissions: const {},
        operatingMode: 0,
        pointMode: 'cashier',
        shiftOpen: false,
        terminalId: 5,
      );

      await tester.tap(find.text('Кассир Бота'));
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Сохранить'));
      await tester.pumpAndSettle();

      expect(
        registry.lookup(freshSession.token),
        isNotNull,
        reason:
            'повторное сохранение уже заблокированного пользователя не '
            'должно вышибать заново заведённый сеанс того же пользователя',
      );
    },
  );

  testWidgets('удаление пользователя гасит его сеанс и не трогает сторонний', (
    tester,
  ) async {
    final unrelated = mintUnrelatedSession();
    registry.mint(
      userId: cashierId,
      name: 'Кассир Бота',
      role: 'cashier',
      permissions: const {},
      operatingMode: 0,
      pointMode: 'cashier',
      shiftOpen: false,
      terminalId: 1,
    );
    expect(registry.outstanding, 2);

    await pumpScreen(tester);
    await tester.tap(find.text('Кассир Бота'));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить').last);
    await tester.pumpAndSettle();

    expect(registry.outstanding, 1);
    expect(registry.lookup(unrelated.token), isNotNull);
  });
}
