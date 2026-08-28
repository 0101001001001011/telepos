import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/web/wt_unavailable_screen.dart';

import '../helpers/test_app.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    required String reason,
    VoidCallback? onRetry,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        child: TestApp(
          themeMode: themeMode,
          child: WtUnavailableScreen(
            reason: reason,
            onRetry: onRetry ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('без сессии терминал показывает причину, а не пустоту', (
    tester,
  ) async {
    // 2026-08-04 белый экран нашёлся трижды подряд, и каждый раз причина
    // была в логе и не была на экране. Здесь она обязана быть на экране —
    // иначе искать будут не там, где сломалось.
    await pumpScreen(tester, reason: 'порт занят');
    await tester.pumpAndSettle();

    expect(find.textContaining('порт занят'), findsOneWidget);
  });

  testWidgets('на экране есть кнопка повтора, и она зовёт повтор', (
    tester,
  ) async {
    // Кнопка, которая рисуется и ничего не делает, — тот же тупик, только с
    // надеждой. Проверяется нажатие, а не наличие.
    var retried = 0;
    await pumpScreen(tester, reason: 'касса молчит', onRetry: () => retried++);
    await tester.pumpAndSettle();

    final button = find.byType(ElevatedButton);
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pump();

    expect(retried, 1);
  });

  testWidgets('экран называет, что запасного пути нет', (tester) async {
    // Решение заказчика: REST-запасного пути не существует. Экран, молчащий
    // об этом, оставляет оператора ждать, что «сейчас само переключится».
    await pumpScreen(tester, reason: 'нет WebTransport');
    await tester.pumpAndSettle();

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .join(' ');

    expect(texts, contains('WebTransport'));
    expect(texts.trim(), isNotEmpty);
  });

  testWidgets('в тёмной теме экран рисуется ролями, а не светлыми константами', (
    tester,
  ) async {
    // Проект уже ловил белое по белому: цвет, взятый мимо темы, остаётся
    // светлым в тёмной. Фон обязан прийти из темы.
    await pumpScreen(
      tester,
      reason: 'касса молчит',
      themeMode: ThemeMode.dark,
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final context = tester.element(find.byType(WtUnavailableScreen));

    expect(
      scaffold.backgroundColor,
      anyOf(isNull, equals(Theme.of(context).scaffoldBackgroundColor)),
      reason: 'фон берётся темой, а не константой экрана',
    );
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(
      Theme.of(context).scaffoldBackgroundColor,
      AppTheme.dark.scaffoldBackgroundColor,
    );
  });
}
