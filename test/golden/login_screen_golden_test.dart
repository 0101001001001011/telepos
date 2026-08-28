@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/domain/auth/auth_attempt.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/auth/auth_user.dart';
import 'package:telepos/presentation/screens/auth/login_screen.dart';

import 'golden_test_helpers.dart';

/// Эталоны экрана входа, переведённого на доменный контракт `AuthRepository`
/// (задача 11 плана `2026-08-20-browser-terminal-login.md`).
///
/// # Почему не `real_screens_golden_test.dart`
///
/// Тот файл поднимает экран через `configureDependencies()` целиком — там
/// `AuthRepository` резолвится в `LocalAuthRepository`, который читает
/// настоящую `AppDatabase`. Здесь `AuthRepository` подделан ровно так, как это
/// уже делает `test/presentation/auth/login_controller_test.dart::_FakeAuth`:
/// касса отвечает списком кассиров сама, без базы. Это тест самого экрана —
/// его слоя представления, — а не провода до кассы; провод проверен задачами
/// 8-10.
///
/// # Что снято
///
/// Ни один кассир не выбран: список кассиров виден целиком, PIN-клавиатура
/// пуста. Выбор конкретного кассира и заполненный PIN не добавляют новой
/// ветки разметки (`_buildContent` не смотрит на то, кто выбран, только на
/// то, выбран ли хоть кто-то и есть ли у него пароль) — состояние «никто не
/// выбран» уже показывает список, клавиатуру и подпись входа одним кадром.
class _FakeAuthRepository implements AuthRepository {
  @override
  Stream<List<AuthUser>> watchUsers() => Stream.value(const [
    AuthUser(id: 1, name: 'Айгуль Сатпаева', role: 'Кассир', hasPin: true),
    AuthUser(id: 2, name: 'Ерлан Жумабаев', role: 'Администратор', hasPin: true),
    AuthUser(id: 3, name: 'Динара Ахметова', role: 'Кассир', hasPin: true),
  ]);

  @override
  Future<AuthOutcome> login(AuthAttempt attempt) async =>
      const AuthRejection(AuthRejectionReason.wrongPin);

  @override
  Future<void> logout(String token) async {}

  @override
  Stream<AuthSession?> watchSession(String token) => const Stream.empty();
}

Future<Widget> _loginUnderTest() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return ProviderScope(
    // `LanguageSwitcher`, отрисованный прямо в `build()` экрана, читает
    // `sharedPreferencesProvider` не лениво — без переопределения сборка
    // виджета бросает `UnimplementedError` ещё до первого кадра. Тот же
    // приём, что и в `real_screens_golden_test.dart`.
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const LoginScreen(),
  );
}

void main() {
  setUp(() async {
    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<AuthRepository>(_FakeAuthRepository());
  });

  tearDown(() => GetIt.instance.reset());

  for (final theme in const {
    'светлая': Brightness.light,
    'тёмная': Brightness.dark,
  }.entries) {
    testWidgets('вход, телефон, ${theme.key}', (tester) async {
      await GoldenTestHelpers.matchGoldenMobile(
        tester,
        await _loginUnderTest(),
        'login',
        brightness: theme.value,
      );
    });

    testWidgets('вход, десктоп, ${theme.key}', (tester) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        tester,
        await _loginUnderTest(),
        'login',
        brightness: theme.value,
      );
    });
  }
}
