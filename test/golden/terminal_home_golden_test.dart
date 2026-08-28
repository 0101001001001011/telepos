@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/screens/terminal/terminal_home_screen.dart';

import '../helpers/mock_providers.dart';
import 'golden_test_helpers.dart';

/// Эталоны дома терминала — куда браузерная вкладка приходит после входа,
/// если у хоста нет своей базы (`HostCapabilities.ownsData == false`, задача
/// 12 плана `2026-08-20-browser-terminal-login.md`).
///
/// # Что переиспользовано
///
/// `MockAppStateNotifier` — из `test/helpers/mock_providers.dart`, уже
/// заведённая заглушка `AppStateNotifier`, чей `build()` не заводит два
/// `Timer.periodic` (часы, опрос свободного места), которые заводит настоящий
/// `AppStateNotifier.build()`. Экран этих таймеров не читает вовсе; без
/// подмены `testWidgets` находил бы их живыми к концу теста.
/// `test/presentation/terminal/terminal_home_screen_test.dart` решает ту же
/// задачу собственным `_TestAppStateNotifier`, но он приватен для того файла
/// (лишний, а не единственно верный: `MockAppStateNotifier` уже даёт то же
/// самое — фиксированное состояние без таймеров — через конструктор, без
/// отдельного класса на каждый файл).
///
/// # Что снято
///
/// Смена открыта и есть право `settings.hardware` — так на одном кадре видны
/// все три секции разом: «кто вошёл» со значком открытой смены, плитка
/// «Оборудование» и строка продажи с часами вместо стрелки (раздел 11
/// управляющего документа — право проверяется показом, продажа ещё не
/// собрана на этом маршруте). Без права плитка «Оборудование» не строится
/// вовсе — это уже проверено `terminal_home_screen_test.dart`, здесь не
/// дублируется.
Widget _terminalHomeUnderTest() {
  return ProviderScope(
    overrides: [
      appStateProvider.overrideWith(
        () => MockAppStateNotifier(
          const AppState(
            userId: 1,
            userName: 'Айгуль Сатпаева',
            userRole: 0,
            isShiftOpened: true,
            permissions: {PermissionKeys.settingsHardware},
          ),
        ),
      ),
    ],
    child: const TerminalHomeScreen(),
  );
}

void main() {
  for (final theme in const {
    'светлая': Brightness.light,
    'тёмная': Brightness.dark,
  }.entries) {
    testWidgets('дом терминала, телефон, ${theme.key}', (tester) async {
      await GoldenTestHelpers.matchGoldenMobile(
        tester,
        _terminalHomeUnderTest(),
        'terminal_home',
        brightness: theme.value,
      );
    });

    testWidgets('дом терминала, десктоп, ${theme.key}', (tester) async {
      await GoldenTestHelpers.matchGoldenDesktop(
        tester,
        _terminalHomeUnderTest(),
        'terminal_home',
        brightness: theme.value,
      );
    });
  }
}
