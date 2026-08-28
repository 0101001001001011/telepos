@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/presentation/screens/auth/widgets/pin_keypad.dart';
import 'package:telepos/presentation/screens/cash_operation/widgets/numpad_widget.dart';

import 'golden_test_helpers.dart';

/// Эталоны цифровых клавиатур — единственных двух виджетов приложения, которые
/// красили **фон** константой светлой темы.
///
/// Заведены потому, что снимать было нечем. Проверено 2026-08-04: из 126
/// эталонов ни один не покрывает `PinKeypad` и `NumpadWidget` — 44 сняты с
/// `_Mock`-виджетов, крашеных материальной палитрой напрямую, а единственный
/// «настоящий» экран (`real_login`) снимается только в светлой теме. Правку,
/// смысл которой в тёмной теме, такой набор пропустил бы целиком: он и пропустил
/// — все 126 прошли, не заметив ни снятой тени, ни смены заливки.
///
/// Снимается в **обеих** темах: эталон только светлой оставил бы тёмную ровно в
/// том состоянии, из-за которого эта работа и делается — ненаблюдаемом.
void main() {
  Widget wrap(Widget child) => Scaffold(
    body: Center(child: SingleChildScrollView(child: child)),
  );

  final cases = <String, Widget>{
    'keypad_pin': wrap(PinKeypad(onKeyPressed: (_) {})),
    'keypad_pin_compact': wrap(PinKeypadCompact(onKeyPressed: (_) {})),
    'keypad_numpad': wrap(
      NumpadWidget(
        onDigit: (_) {},
        onDecimal: () {},
        onBackspace: () {},
        onClear: () {},
        // Быстрые суммы включены намеренно: это единственное место, где жила
        // заготовленная светлая подложка `primaryLighter`.
        quickAmounts: const [500, 1000, 5000],
      ),
    ),
  };

  for (final entry in cases.entries) {
    for (final brightness in Brightness.values) {
      testWidgets('${entry.key} — ${brightness.name}', (tester) async {
        await GoldenTestHelpers.matchGoldenMobile(
          tester,
          entry.value,
          entry.key,
          brightness: brightness,
        );
      });
    }
  }
}
