/// Правка Б-3 закрытия долга безопасности (2026-08-22).
///
/// `_UserEditDialogState._loadPermissions` читает `getAllowedKeys` для
/// СУЩЕСТВУЮЩЕГО пользователя, не разбирая роль — у владельца строк в
/// `user_permissions` нет никогда (`LocalAuthRepository._issue` обходит
/// таблицу целиком, докстринг `PermissionKeys.roleDefaults`), значит
/// `_permissions`, загруженные для реального владельца, — пустая таблица
/// (всё `false`), а не снимок настоящих прав. Переключатели рисуются
/// `isOwner ? true : (_permissions[key] ?? true)` — включёнными, пока роль
/// не сменили. Понизь роль на кассира — `isOwner` становится `false`, и все
/// переключатели читают уже выключенный `_permissions[key]`: «Сохранить»
/// пишет запрещающие строки на весь словарь, человек без единого права.
///
/// Этот тест воспроизводит ровно этот путь через настоящий виджет (диалог
/// приватный — `_UserEditDialog`, не экспортирован, поэтому взаимодействие
/// идёт через публичный `UserManagementScreen`, как обычный пользователь):
/// открывает владельца, меняет роль на кассира, сохраняет и читает права из
/// базы напрямую.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/constants/enums/user_role.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/user_management_screen.dart';

void main() {
  late AppDatabase db;
  const ownerId = 1;

  setUp(() async {
    GetIt.I.allowReassignment = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    GetIt.I.registerSingleton<AppDatabase>(db);

    await db.userDao.insertUser(
      UsersCompanion.insert(
        id: const Value(ownerId),
        name: const Value('Владелец Аскар'),
        role: const Value(0), // UserRole.owner
        status: const Value('active'),
        editTime: const Value(1000),
        passwordEnc: const Value('irrelevant-hash'),
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

  testWidgets(
    'понижение владельца до кассира в диалоге редактирования подставляет '
    'умолчания новой роли, а не пустой набор',
    (tester) async {
      await pumpScreen(tester);

      // Открыть диалог редактирования единственного пользователя (владельца).
      await tester.tap(find.text('Владелец Аскар'));
      await tester.pumpAndSettle();

      // `_loadPermissions` — `addPostFrameCallback` внутри `initState`, ждём
      // отдельным кадром: диалог уже на экране, но вкладка прав ещё
      // «loading» один кадр.
      await tester.pump();
      await tester.pumpAndSettle();

      final dialogFinder = find.byType(Dialog);
      expect(
        dialogFinder,
        findsOneWidget,
        reason: 'диалог редактирования обязан открыться',
      );

      // Дропдаун роли — единственный виджет своего типа на экране (список
      // пользователей позади диалога ролей не выбирает), можно найти по
      // типу без уточнения диалогом.
      final roleDropdown = find.byType(DropdownButtonFormField<int>);
      expect(roleDropdown, findsOneWidget);

      await tester.tap(roleDropdown);
      await tester.pumpAndSettle();

      // «Кассир» в этот момент есть только в открывшемся меню — фон
      // (карточка пользователя) до сохранения всё ещё показывает бейдж
      // «Владелец», не «Кассир».
      final cashierOption = find.text('Кассир');
      expect(cashierOption, findsOneWidget);
      await tester.tap(cashierOption);
      await tester.pumpAndSettle();

      // Сохранить.
      final saveButton = find.widgetWithText(ElevatedButton, 'Сохранить');
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      final allowed = await db.userPermissionDao.getAllowedKeys(ownerId);
      final expectedDefaults =
          PermissionKeys.roleDefaults[UserRole.cashier]!;

      expect(
        allowed,
        expectedDefaults,
        reason:
            'понижение обязано подставить умолчания новой роли (кассира) — '
            'до правки Б-3 здесь получался бы пустой набор (все '
            'переключатели гасли вместе с owner-снимком без строк), и '
            '"Сохранить" писал бы запрет на каждый из 34 ключей',
      );
      expect(
        allowed,
        isNotEmpty,
        reason:
            'умолчания кассира не пусты (nav.sale, nav.shift, история и '
            'т.д.) — пустой набор здесь прямо доказывал бы старую дыру',
      );
    },
  );
}
