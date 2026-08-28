/// Задача 21 закрытия долга безопасности: смена PIN, смена прав и удаление
/// кассира в `UserManagementScreen` пишут в журнал событий безопасности.
/// Тот же приём, что `user_management_sessions_test.dart` (задача 19) уже
/// использует для проверки `SessionRegistry.revokeForUser` — щелчок в
/// реальном экране доходит до настоящего get_it-синглтона.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/backend/security_journal.dart';
import 'package:telepos/core/security/pin_credential.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/user_management_screen.dart';

void main() {
  late AppDatabase db;
  const cashierId = 2;

  setUp(() async {
    GetIt.I.allowReassignment = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    GetIt.I.registerSingleton<AppDatabase>(db);
    GetIt.I.registerSingleton<SecurityJournal>(SecurityJournal(db.securityEventDao));
    // Мастер настройки — иначе `terminalDao.self()` (актёрский терминал
    // экрана, см. `_actingTerminalId`) отдаёт `null`.
    await db.terminalDao.ensureSelf(fallbackName: 'Касса-1');

    await db.userDao.insertUser(
      UsersCompanion.insert(
        id: const Value(1),
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
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text(digit)),
      warnIfMissed: false,
    );
    await tester.pump();
  }

  testWidgets(
    'ГЛАВНЫЙ ТЕСТ: смена PIN кассира пишет user.pinChanged с его userId',
    (tester) async {
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

      await tester.tap(find.widgetWithText(ElevatedButton, 'Сохранить'));
      await tester.pumpAndSettle();
      // Запись — `unawaited`: пропускаем ход событийного цикла до чтения.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));

      final rows = await db.securityEventDao.findAll();
      final pinRows = rows.where(
        (r) => r.eventType == SecurityEventType.pinChanged,
      );
      expect(pinRows, hasLength(1));
      expect(pinRows.single.userId, cashierId);
    },
  );

  testWidgets(
    'ГЛАВНЫЙ ТЕСТ: смена прав кассира пишет user.permissionsChanged с его '
    'userId',
    (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('Кассир Бота'));
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pumpAndSettle();

      // Сохранение без смены PIN всё равно пишет права — экран всегда
      // отправляет явный набор (докстринг `_save`).
      await tester.tap(find.widgetWithText(ElevatedButton, 'Сохранить'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));

      final rows = await db.securityEventDao.findAll();
      final permRows = rows.where(
        (r) => r.eventType == SecurityEventType.permissionsChanged,
      );
      expect(permRows, hasLength(1));
      expect(permRows.single.userId, cashierId);
    },
  );

  testWidgets(
    'ГЛАВНЫЙ ТЕСТ (БЛОКЕР 1): заведение нового кассира пишет user.created — '
    'до этой правки заведение с PIN и полным набором прав было единственным '
    'действием формы без единого следа в журнале',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'Новый Кассир',
      );

      await tester.tap(find.text('PIN'));
      await tester.pumpAndSettle();
      for (final digit in ['1', '2', '3', '4']) {
        await tapDigit(tester, digit);
      }
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Сохранить'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));

      final users = await db.userDao.findAll();
      final created = users.singleWhere((u) => u.name == 'Новый Кассир');

      final rows = await db.securityEventDao.findAll();
      final createdRows = rows.where(
        (r) => r.eventType == SecurityEventType.userCreated,
      );
      expect(createdRows, hasLength(1));
      expect(createdRows.single.userId, created.id);
      expect(
        createdRows.single.outcome,
        'cashier',
        reason: 'умолчание дропдауна роли в форме заведения — кассир '
            '(_selectedRole = widget.user?.role ?? 3)',
      );
    },
  );

  testWidgets(
    'ГЛАВНЫЙ ТЕСТ (БЛОКЕР 1): повышение кассира до владельца пишет '
    'user.roleChanged — до этой правки при роли «владелец» не писалось ни '
    'одной строки, хотя updateUser(role: ...) выполнялся',
    (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('Кассир Бота'));
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      // `.last`, не голый finder: фон (список пользователей) уже показывает
      // бейдж «Владелец» у другого, засеянного пользователя — тем же
      // приёмом, что и `find.text(digit)` в `tapDigit` рядом.
      await tester.tap(find.text('Владелец').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Сохранить'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));

      final rows = await db.securityEventDao.findAll();
      final roleRows = rows.where(
        (r) => r.eventType == SecurityEventType.roleChanged,
      );
      expect(
        roleRows,
        hasLength(1),
        reason: 'смена роли обязана оставить след даже когда роль — '
            'владелец',
      );
      expect(roleRows.single.userId, cashierId);
      expect(roleRows.single.outcome, 'cashier->owner');

      // Права НЕ пишутся при повышении до владельца (Правка Б-3) — и это
      // по-прежнему так: permissionsChanged не заводится вовсе, потому что
      // сама запись прав не происходит (см. докстринг `_save`).
      final permRows = rows.where(
        (r) => r.eventType == SecurityEventType.permissionsChanged,
      );
      expect(
        permRows,
        isEmpty,
        reason: 'при повышении до владельца userPermissionDao.setPermissions '
            'не зовётся вовсе — событие о незаписанных правах было бы '
            'неправдой',
      );
    },
  );

  testWidgets(
    'смена роли кассир→администратор пишет и roleChanged, и '
    'permissionsChanged — оба события, каждое своё',
    (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('Кассир Бота'));
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Администратор'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Сохранить'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));

      final rows = await db.securityEventDao.findAll();
      final roleRows = rows.where(
        (r) => r.eventType == SecurityEventType.roleChanged,
      );
      expect(roleRows, hasLength(1));
      expect(roleRows.single.outcome, 'cashier->administrator');

      final permRows = rows.where(
        (r) => r.eventType == SecurityEventType.permissionsChanged,
      );
      expect(
        permRows,
        hasLength(1),
        reason: 'администратор — не владелец, права пишутся, значит и своё '
            'событие тоже',
      );
    },
  );

  testWidgets(
    'сохранение БЕЗ смены роли не пишет roleChanged — не выдумывает событие '
    'там, где роль не менялась',
    (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('Кассир Бота'));
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Сохранить'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));

      final rows = await db.securityEventDao.findAll();
      final roleRows = rows.where(
        (r) => r.eventType == SecurityEventType.roleChanged,
      );
      expect(roleRows, isEmpty);
    },
  );

  testWidgets(
    'ГЛАВНЫЙ ТЕСТ: удаление кассира пишет user.deleted с его userId',
    (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('Кассир Бота'));
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить').last);
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));

      final rows = await db.securityEventDao.findAll();
      final delRows = rows.where(
        (r) => r.eventType == SecurityEventType.userDeleted,
      );
      expect(delRows, hasLength(1));
      expect(delRows.single.userId, cashierId);
    },
  );
}
