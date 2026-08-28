import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/input_mode.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_switch_tile.dart';

final _metrics = WizardMetrics.resolve(
  layout: LayoutType.mobile,
  input: InputMode.touch,
);

void main() {
  testWidgets('нажатие по тумблеру переключает ровно один раз', (tester) async {
    // Строка — сама по себе цель нажатия, и тумблер лежит внутри неё. Если
    // сработают оба обработчика, настройка вернётся в исходное положение, и
    // человек увидит, что нажатие ничего не сделало.
    var calls = 0;
    var value = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SettingsSwitchTile(
              title: 'Печатать чек',
              value: value,
              metrics: _metrics,
              onChanged: (v) {
                calls++;
                setState(() => value = v);
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(calls, 1, reason: 'обработчик вызван дважды — строкой и тумблером');
    expect(value, isTrue);
  });
}
