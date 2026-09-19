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
import 'package:telepos/domain/shift/shift_status.dart';

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
/// Смена открыта, права — `settings.hardware` и `nav.sale`: так на одном
/// кадре видны все три секции разом — «кто вошёл» со значком открытой смены,
/// плитка «Оборудование» и **плитка «Продажа» со стрелкой**.
///
/// **`nav.sale` в фикстуре — задача 13, и он обязателен.** До неё продажа
/// стояла на доме терминала строкой с часами и подписью «под браузер пока
/// не собирается»: нажать было нельзя, права она не спрашивала, и на эталон
/// попадала всегда. Задача 13 сделала её настоящей плиткой и спрятала за
/// `nav.sale` — фикстура с одним лишь `settings.hardware` перестала её
/// показывать, и первая пересъёмка эталонов **потеряла продажу целиком**
/// (29542 → 19595 байт при тех же размерах кадра), а этот докстринг
/// продолжал обещать «строку продажи с часами». Поймано разбором, не
/// набором: эталон сравнивается сам с собой, и исчезнувшая секция — такой
/// же «зелёный», как и сохранившаяся.
///
/// Без права плитка «Оборудование» не строится вовсе — это уже проверено
/// `terminal_home_screen_test.dart`, здесь не дублируется.
Widget _terminalHomeUnderTest() {
  return ProviderScope(
    overrides: [
      appStateProvider.overrideWith(
        () => MockAppStateNotifier(
          const AppState(
            userId: 1,
            userName: 'Айгуль Сатпаева',
            userRole: 0,
            shift: ShiftStatus.open,
            permissions: {
              PermissionKeys.settingsHardware,
              PermissionKeys.navSale,
            },
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
