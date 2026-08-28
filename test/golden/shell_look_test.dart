@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/app/theme/app_theme.dart';

import '../e2e/support/harness.dart';

/// Эталоны **оболочки**, снятые в обеих темах на всех её ветках.
///
/// Ни один из 87 прежних эталонов оболочку не показывал: `screens_golden` и
/// `product_doc_golden` снимают макеты, а `real_screens_golden` — вход, то
/// есть экран **вне** `ShellRoute`. Шапку, левую колонку и нижнюю панель не
/// проверял никто, и переодеть их можно было бы, ничего не сломав в наборе, —
/// в том числе переодеть неверно.
///
/// Оболочка поднимается через настоящий граф зависимостей, настоящий роутер и
/// настоящий вход: права приходят от вошедшего кассира, и список назначений в
/// колонке — тот же, что увидит кассир. Собрать `AdaptiveScaffold` руками с
/// выдуманным набором прав было бы дешевле и доказывало бы только раскладку
/// выдуманного набора.
///
/// Четыре размера — это четыре разные ветки оболочки, а не четыре ширины
/// одной:
///
/// * `mobile` — шапка со шторкой и нижняя панель;
/// * `tablet_portrait` — шапка с меню дополнительных и нижняя панель;
/// * `tablet_landscape` — шапка, левая колонка, волосок;
/// * `desktop` — то же плюс полоса состояния снизу.
void main() {
  late E2eHarness harness;

  setUp(() async {
    harness = E2eHarness();
    await harness.setUp();
  });

  tearDown(() async {
    await harness.tearDown();
  });

  const sizes = <String, Size>{
    'mobile': Size(400, 800),
    'tablet_portrait': Size(700, 1000),
    'tablet_landscape': Size(1000, 700),
    'desktop': Size(1440, 900),
  };

  final themes = <String, ThemeData>{
    'light': AppTheme.light,
    'dark': AppTheme.dark,
  };

  for (final theme in themes.entries) {
    for (final size in sizes.entries) {
      testWidgets('оболочка — ${size.key}, ${theme.key}', (tester) async {
        // Вход проходится на широкой поверхности, и только потом окно
        // сужается до нужной ветки.
        //
        // Измерено, а не предположено: та же последовательность входа при
        // 400x800 и 700x1000 оставляет маршрут на `/login`, а при 1600x1000
        // доводит до `/shift`. Экран входа на узком разворачивает другую
        // раскладку (`_MobileLoginLayout` вместо `_DesktopLoginLayout`), и
        // сквозной вход по ней не проходит. Предмет этой проверки —
        // оболочка; чинить экран входа отсюда значило бы подменить предмет,
        // а обойти сужением — честно: маршрут проверяется явно, и оболочка
        // снимается настоящая.
        // Часы в шапке заморожены. Без этого эталон снимается со временем
        // съёмки, и назавтра тот же экран расходится с ним на 90 точек —
        // проверка начинает падать от хода часов, а не от правки кода.
        await harness.pumpApp(tester, theme: theme.value, frozenTime: '12:00');
        await harness.loginAsCashier(tester);

        // Проверка до снимка, а не вместо него: эталон покажет, ЧТО на
        // экране, но не заметит, если экран окажется не тем.
        expect(
          harness.router!.routerDelegate.currentConfiguration.uri.path,
          '/shift',
          reason: 'Снимается оболочка, а значит маршрут внутри ShellRoute',
        );

        tester.view.physicalSize = size.value;
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/shell_${size.key}_${theme.key}.png'),
        );

        // Отпускает дерево до конца тела теста — иначе таймер, который
        // заводит отмена подписки `LoginNotifier` на `watchUsers()`, всплывает
        // только на автоматическом сбросе между тестами и обваливает прогон
        // с «A Timer is still pending». Причина и приём — в
        // `E2eHarness.releaseScreen`.
        await harness.releaseScreen(tester);
      });
    }
  }
}
