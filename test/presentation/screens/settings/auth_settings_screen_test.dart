/// Задача 18, закрытие И31: `ThisPosDao.saveAuthSettings` существовала в
/// схеме и в тесте, но ни одна строка `lib/` её не звала — настройки
/// walk-up и срока сеанса менять было нечем. Эти тесты проверяют не
/// отрисовку, а то, что щелчок и ввод доходят до самой базы, которую читают
/// `local_auth_repository.dart` (walk-up) и `service_locator.dart` (срок
/// сеанса при подъёме) — и, отдельно, что смена срока доходит ещё и до уже
/// поднятого `SessionRegistry`, живьём, без перезапуска.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/auth_settings_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    GetIt.I.allowReassignment = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    GetIt.I.registerSingleton<AppDatabase>(db);
    // Строка ThisPos обязана существовать, иначе `saveAuthSettings`
    // (`UPDATE ... WHERE rId = true`) молча обновит ноль строк — та же
    // ловушка тихого отказа, которую бриф просит не оставлять.
    await db.thisPosDao.upsert(const ThisPosEntriesCompanion());
  });

  tearDown(() async {
    await db.close();
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
          home: const AuthSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('открывается на настоящих умолчаниях из базы, не выдуманных', (
    tester,
  ) async {
    await pumpScreen(tester);

    final switchTile = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('auth-settings-walk-up')),
    );
    expect(
      switchTile.value,
      isFalse,
      reason: 'ThisPos.walkUpEnabled по умолчанию выключен',
    );

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('auth-settings-session-minutes')),
    );
    expect(field.controller!.text, '30');
  });

  testWidgets('щелчок по walk-up доходит до базы, которую читает вход', (
    tester,
  ) async {
    await pumpScreen(tester);

    // До щелчка: именно то значение, которое `local_auth_repository.dart`
    // читает в `_matchAll`.
    expect((await db.thisPosDao.authSettings()).walkUpEnabled, isFalse);

    await tester.tap(find.byKey(const ValueKey('auth-settings-walk-up')));
    await tester.pumpAndSettle();

    expect(
      (await db.thisPosDao.authSettings()).walkUpEnabled,
      isTrue,
      reason:
          'щелчок не доехал до базы — на кассе это осталось бы настройкой, '
          'которую нечем изменить, тем же дефектом, что и до этой задачи',
    );

    // Экран отражает то, что действительно записано, а не то, что нажали.
    final switchTile = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('auth-settings-walk-up')),
    );
    expect(switchTile.value, isTrue);
  });

  testWidgets(
    'сохранённый срок сеанса читается обратно тем же экраном (сохранение и '
    'чтение)',
    (tester) async {
      await pumpScreen(tester);

      await tester.enterText(
        find.byKey(const ValueKey('auth-settings-session-minutes')),
        '45',
      );
      await tester.tap(find.byKey(const ValueKey('auth-settings-session-save')));
      await tester.pumpAndSettle();

      expect((await db.thisPosDao.authSettings()).sessionIdleMinutes, 45);

      // Перечитать экраном заново — то самое «сохранение и чтение обратно»
      // из брифа задачи, а не просто чтение из базы мимо экрана.
      await pumpScreen(tester);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('auth-settings-session-minutes')),
      );
      expect(field.controller!.text, '45');
    },
  );

  testWidgets(
    'неверный ввод (0, отрицательное, не число) не пишется в базу',
    (tester) async {
      await pumpScreen(tester);

      for (final bad in ['0', '-5', 'abc', '']) {
        await tester.enterText(
          find.byKey(const ValueKey('auth-settings-session-minutes')),
          bad,
        );
        await tester.tap(
          find.byKey(const ValueKey('auth-settings-session-save')),
        );
        await tester.pumpAndSettle();

        expect(
          (await db.thisPosDao.authSettings()).sessionIdleMinutes,
          30,
          reason: 'ввод "$bad" не должен был дойти до базы',
        );
      }
    },
  );

  testWidgets(
    'смена срока действует немедленно на уже поднятый SessionRegistry — '
    'без перезапуска кассы',
    (tester) async {
      final registry = SessionRegistry(idleTimeout: const Duration(minutes: 30));
      GetIt.I.registerSingleton<SessionRegistry>(registry);

      await pumpScreen(tester);

      await tester.enterText(
        find.byKey(const ValueKey('auth-settings-session-minutes')),
        '5',
      );
      await tester.tap(
        find.byKey(const ValueKey('auth-settings-session-save')),
      );
      await tester.pumpAndSettle();

      expect(
        registry.idleTimeout,
        const Duration(minutes: 5),
        reason:
            'настройка, применяемая только после перезапуска, хуже '
            'отсутствующей — она должна подействовать на живой процесс сразу',
      );
    },
  );
}
