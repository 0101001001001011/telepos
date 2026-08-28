import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/input_mode.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_field_tile.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_section.dart';

const _explanation = 'БИН печатается в каждом чеке и уходит в фискальный '
    'сервис. Ошибка здесь обнаружится только при первой сверке с КГД.';

final _touch = WizardMetrics.resolve(
  layout: LayoutType.mobile,
  input: InputMode.touch,
);

final _pointer = WizardMetrics.resolve(
  layout: LayoutType.desktop,
  input: InputMode.pointer,
);

Future<void> _pumpField(
  WidgetTester tester, {
  required WizardMetrics metrics,
  String? explanation,
  String? helper,
}) {
  final controller = TextEditingController();
  addTearDown(controller.dispose);

  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: SettingsSection(
            children: [
              SettingsFieldTile(
                label: 'БИН',
                controller: controller,
                helper: helper,
                explanation: explanation,
                onChanged: (_) {},
                metrics: metrics,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('поле без объяснения иконки не показывает', (tester) async {
    // Декоративных иконок в сгруппированном списке нет: иконка появляется
    // там, где у неё есть поведение. Иначе слева встаёт вертикальная полоса
    // шума, повторяющая подписи строк.
    await _pumpField(tester, metrics: _touch, helper: '12 цифр');
    expect(find.byIcon(Icons.help_outline), findsNothing);
  });

  testWidgets('под указателем иконка объясняет тултипом', (tester) async {
    await _pumpField(
      tester,
      metrics: _pointer,
      explanation: _explanation,
    );

    expect(find.byIcon(Icons.help_outline), findsOneWidget);
    final tooltip = tester.widget<Tooltip>(
      find.ancestor(
        of: find.byIcon(Icons.help_outline),
        matching: find.byType(Tooltip),
      ),
    );
    expect(tooltip.message, _explanation);
  });

  testWidgets('под указателем иконка не выглядит выключенной', (tester) async {
    // IconButton с onPressed: null красится в цвет «сюда нельзя». Наводить
    // сюда можно и нужно — иначе тултип есть, а поводов его искать нет.
    await _pumpField(tester, metrics: _pointer, explanation: _explanation);

    final context = tester.element(find.byIcon(Icons.help_outline));
    final icon = tester.widget<Icon>(find.byIcon(Icons.help_outline));
    expect(icon.color, Theme.of(context).colorScheme.onSurfaceVariant);
    expect(icon.size, isNot(0));
  });

  testWidgets('под пальцем тултипа нет — наведения на сенсоре не бывает', (
    tester,
  ) async {
    await _pumpField(tester, metrics: _touch, explanation: _explanation);

    expect(find.byIcon(Icons.help_outline), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byIcon(Icons.help_outline),
        matching: find.byType(Tooltip),
      ),
      findsNothing,
    );
  });

  testWidgets('под пальцем нажатие раскрывает текст, повторное — сворачивает', (
    tester,
  ) async {
    await _pumpField(tester, metrics: _touch, explanation: _explanation);

    expect(find.text(_explanation), findsNothing);

    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pumpAndSettle();
    expect(find.text(_explanation), findsOneWidget);

    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pumpAndSettle();
    expect(find.text(_explanation), findsNothing);
  });

  testWidgets('раскрытие идёт в потоке секции, а не всплывающим окном', (
    tester,
  ) async {
    // Модальное окно ради одной фразы прерывает заполнение формы, к которому
    // потом надо возвращаться. Текст обязан встать под полем той же строки.
    await _pumpField(tester, metrics: _touch, explanation: _explanation);

    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(
      find.descendant(
        of: find.byType(SettingsFieldTile),
        matching: find.text(_explanation),
      ),
      findsOneWidget,
    );
  });

  testWidgets('под указателем нажатие ничего не раскрывает', (tester) async {
    // Тултипа достаточно: он не занимает места и уходит вместе с курсором.
    // Раскрытие в дополнение к нему двигало бы форму под курсором.
    await _pumpField(tester, metrics: _pointer, explanation: _explanation);

    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(SettingsFieldTile),
        matching: find.text(_explanation),
      ),
      findsNothing,
    );
  });

  testWidgets('раскрытая подсказка не отменяет постоянную', (tester) async {
    // Три уровня объяснения независимы: «12 цифр» под полем остаётся, когда
    // раскрыто, зачем эти двенадцать цифр нужны.
    await _pumpField(
      tester,
      metrics: _touch,
      helper: '12 цифр',
      explanation: _explanation,
    );

    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pumpAndSettle();

    expect(find.text('12 цифр'), findsOneWidget);
    expect(find.text(_explanation), findsOneWidget);
  });

  test('иконка, открывающая пустоту, запрещена', () {
    // Пустое объяснение хуже отсутствующего: человек нажимает и не получает
    // ничего, после чего перестаёт нажимать вообще.
    expect(
      () => SettingsFieldTile(
        label: 'БИН',
        controller: TextEditingController(),
        explanation: '   ',
        onChanged: (_) {},
        metrics: _touch,
      ),
      throwsAssertionError,
    );
  });
}
