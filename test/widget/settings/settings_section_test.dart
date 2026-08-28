import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/input_mode.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_choice_tile.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_field_tile.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_section.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_switch_tile.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_tile.dart';

final _metrics = WizardMetrics.resolve(
  layout: LayoutType.mobile,
  input: InputMode.touch,
);

final _pointerMetrics = WizardMetrics.resolve(
  layout: LayoutType.desktop,
  input: InputMode.pointer,
);

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  testWidgets('между тремя строками ровно два разделителя', (tester) async {
    await _pump(
      tester,
      SettingsSection(
        header: 'Организация',
        children: [
          SettingsTile(title: 'Название', value: 'ТОО', metrics: _metrics),
          SettingsTile(title: 'БИН', value: '1234', metrics: _metrics),
          SettingsTile(title: 'Телефон', value: '+7', metrics: _metrics),
        ],
      ),
    );

    expect(find.byType(Divider), findsNWidgets(2));
  });

  testWidgets('после последней строки разделителя нет', (tester) async {
    await _pump(
      tester,
      SettingsSection(
        children: [SettingsTile(title: 'Одна', metrics: _metrics)],
      ),
    );

    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('секция скруглена и не отбрасывает тень', (tester) async {
    await _pump(
      tester,
      SettingsSection(
        children: [SettingsTile(title: 'Строка', metrics: _metrics)],
      ),
    );

    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(SettingsSection),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.elevation, 0);
    expect(material.borderRadius, BorderRadius.circular(AppTokens.radiusSection));
  });

  testWidgets('разделитель толщиной в один физический пиксель', (tester) async {
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(
      tester,
      SettingsSection(
        children: [
          SettingsTile(title: 'Раз', metrics: _metrics),
          SettingsTile(title: 'Два', metrics: _metrics),
        ],
      ),
    );

    final divider = tester.widget<Divider>(find.byType(Divider));
    expect(divider.thickness, 0.5);
    expect(divider.indent, AppTokens.space16);
  });

  testWidgets('подпись секции набрана вторичным цветом', (tester) async {
    await _pump(
      tester,
      SettingsSection(
        header: 'ОРГАНИЗАЦИЯ',
        children: [SettingsTile(title: 'Строка', metrics: _metrics)],
      ),
    );

    final context = tester.element(find.text('ОРГАНИЗАЦИЯ'));
    final header = tester.widget<Text>(find.text('ОРГАНИЗАЦИЯ'));
    expect(header.style?.color, Theme.of(context).colorScheme.onSurfaceVariant);
  });

  testWidgets('строка соблюдает высоту из метрик', (tester) async {
    await _pump(
      tester,
      SettingsSection(
        children: [SettingsTile(title: 'Строка', metrics: _metrics)],
      ),
    );

    final size = tester.getSize(find.byType(SettingsTile));
    expect(size.height, greaterThanOrEqualTo(AppTokens.rowHeightTouch));
  });

  testWidgets('под указателем строка ниже, чем под пальцем', (tester) async {
    // Плотность — единственное, что меняется от способа ввода. Если строка
    // под курсором окажется такой же высокой, метрики не доехали до виджета.
    await _pump(
      tester,
      Column(
        children: [
          SettingsSection(
            children: [SettingsTile(title: 'Палец', metrics: _metrics)],
          ),
          SettingsSection(
            children: [
              SettingsTile(title: 'Курсор', metrics: _pointerMetrics),
            ],
          ),
        ],
      ),
    );

    final touch = tester.getSize(find.widgetWithText(SettingsTile, 'Палец'));
    final pointer = tester.getSize(find.widgetWithText(SettingsTile, 'Курсор'));
    expect(pointer.height, lessThan(touch.height));
    expect(pointer.height, greaterThanOrEqualTo(AppTokens.rowHeightPointer));
  });

  testWidgets('переключатель сообщает о нажатии', (tester) async {
    var value = false;
    await _pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => SettingsSection(
          children: [
            SettingsSwitchTile(
              title: 'Печатать чек',
              value: value,
              onChanged: (v) => setState(() => value = v),
              metrics: _metrics,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(value, isTrue);
  });

  testWidgets('нажатие по строке переключателя равносильно нажатию тумблера', (
    tester,
  ) async {
    // Цель нажатия — вся строка, а не сам тумблер шириной 40 px: под пальцем
    // промах по тумблеру означает, что настройка не переключилась молча.
    var value = false;
    await _pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => SettingsSection(
          children: [
            SettingsSwitchTile(
              title: 'Печатать чек',
              value: value,
              onChanged: (v) => setState(() => value = v),
              metrics: _metrics,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Печатать чек'));
    await tester.pumpAndSettle();
    expect(value, isTrue);
  });

  testWidgets('выбор строки не сдвигает текст остальных', (tester) async {
    // Место под галочку занято всегда. Иначе выбор одного варианта отбирает
    // ширину у текста всех строк, и список «дёргается» при каждом нажатии.
    // Заголовок намеренно длинный: он переносится и занимает всю доступную
    // ширину колонки, поэтому измеряется именно колонка, а не глифы (у
    // выбранной строки вес 500, и её глифы шире по определению).
    const long = 'Казахстан, Республика Казахстан — очень длинное название '
        'страны, которое обязательно перенесётся на вторую строку';

    Widget build({required bool selected}) => SettingsSection(
      children: [
        SettingsChoiceTile(
          title: long,
          selected: selected,
          onTap: () {},
          metrics: _metrics,
        ),
      ],
    );

    await _pump(tester, build(selected: false));
    final unselected = tester.getRect(find.text(long));

    await _pump(tester, build(selected: true));
    final selected = tester.getRect(find.text(long));

    expect(selected.left, unselected.left);
    expect(selected.width, unselected.width);
  });

  testWidgets('поле ввода сообщает о наборе и показывает ошибку', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? seen;

    await _pump(
      tester,
      SettingsSection(
        children: [
          SettingsFieldTile(
            label: 'БИН',
            controller: controller,
            helper: '12 цифр',
            errorText: 'Нужно 12 цифр',
            onChanged: (v) => seen = v,
            metrics: _metrics,
          ),
        ],
      ),
    );

    await tester.enterText(find.byType(TextField), '123');
    expect(seen, '123');

    // Когда есть ошибка, подсказка уступает ей место: две строки под полем
    // соревнуются за внимание, и человек читает ту, что не про ошибку.
    expect(find.text('Нужно 12 цифр'), findsOneWidget);
    expect(find.text('12 цифр'), findsNothing);
  });

  testWidgets('поле без ошибки показывает постоянную подсказку', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await _pump(
      tester,
      SettingsSection(
        children: [
          SettingsFieldTile(
            label: 'БИН',
            controller: controller,
            helper: '12 цифр',
            onChanged: (_) {},
            metrics: _metrics,
          ),
        ],
      ),
    );

    expect(find.text('12 цифр'), findsOneWidget);
  });
}
