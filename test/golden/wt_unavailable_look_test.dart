@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/web/wt_unavailable_screen.dart';

import '../helpers/test_app.dart';

/// Снимок экрана «нет связи с кассой» на той ширине, на которой заказчик
/// увидел смещение влево (2026-08-06, окно 900 точек).
///
/// Отдельный файл, а не проверка внутри `test/web/`: там проверяют поведение —
/// что причина названа и кнопка есть, — а здесь смотрят на раскладку, и
/// поведенческая проверка её не видит.
void main() {
  for (final size in const {
    'w900': Size(900, 995),
    'w1440': Size(1440, 900),
  }.entries) {
    testWidgets('нет связи — ${size.key}', (tester) async {
      tester.view.physicalSize = size.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: TestApp(
            themeMode: ThemeMode.dark,
            child: WtUnavailableScreen(
              reason: 'сессия не поднялась: WebTransportError: '
                  'Opening handshake failed.',
              onRetry: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/wt_unavailable_${size.key}.png'),
      );
    });
  }
}
