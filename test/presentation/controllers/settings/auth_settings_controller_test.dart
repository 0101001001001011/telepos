/// `AuthSettingsController` — пункт 7 брифа закрытия долга безопасности
/// (2026-08-22): раздел 15 архитектуры называет «изменение настроек» точкой,
/// обязанной оставлять след, а `/auth-settings` (вход без называния себя,
/// срок сеанса) до этой правки не писал в журнал вовсе.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/backend/security_journal.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/settings/auth_settings_controller.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    GetIt.I.allowReassignment = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    GetIt.I.registerSingleton<AppDatabase>(db);
    GetIt.I.registerSingleton<SecurityJournal>(
      SecurityJournal(db.securityEventDao),
    );
    await db.terminalDao.ensureSelf(fallbackName: 'Касса-1');

    container = ProviderContainer();
    container.read(appStateProvider.notifier).setTestUser(userId: 9);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    await GetIt.I.reset();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test(
    'ГЛАВНЫЙ ТЕСТ: setWalkUpEnabled пишет auth.settingsChanged c '
    'действующим userId',
    () async {
      final controller = container.read(
        authSettingsControllerProvider.notifier,
      );

      await controller.setWalkUpEnabled(true);
      await settle();

      final rows = await db.securityEventDao.findAll();
      final settingsRows = rows.where(
        (r) => r.eventType == SecurityEventType.authSettingsChanged,
      );
      expect(settingsRows, hasLength(1));
      expect(settingsRows.single.outcome, 'walkUp=true');
      expect(
        settingsRows.single.userId,
        9,
        reason: 'действующий — тот, кто вошёл на этой вкладке, известный '
            'через appStateProvider',
      );
    },
  );

  test(
    'ГЛАВНЫЙ ТЕСТ: setSessionIdleMinutes пишет auth.settingsChanged с '
    'новым значением в outcome',
    () async {
      final controller = container.read(
        authSettingsControllerProvider.notifier,
      );

      final ok = await controller.setSessionIdleMinutes(45);
      await settle();

      expect(ok, isTrue);
      final rows = await db.securityEventDao.findAll();
      final settingsRows = rows.where(
        (r) => r.eventType == SecurityEventType.authSettingsChanged,
      );
      expect(settingsRows, hasLength(1));
      expect(settingsRows.single.outcome, 'sessionIdleMinutes=45');
    },
  );

  test(
    'значение вне допустимых границ не пишет событие — ничего не '
    'применилось, писать нечего',
    () async {
      final controller = container.read(
        authSettingsControllerProvider.notifier,
      );

      final ok = await controller.setSessionIdleMinutes(0);
      await settle();

      expect(ok, isFalse);
      final rows = await db.securityEventDao.findAll();
      expect(
        rows.where((r) => r.eventType == SecurityEventType.authSettingsChanged),
        isEmpty,
      );
    },
  );
}
