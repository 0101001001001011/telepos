/// Контраст по WCAG 2.1 — общий, а не третья копия.
///
/// Жил в `test/theme/app_text_styles_test.dart` единственным экземпляром, и
/// это было верно ровно до второго потребителя: `login_screen_test.dart`
/// меряет контраст рамки поля кода привязки (порог 1.4.11 для границ
/// элементов — 3:1, не 4.5:1, который для текста). Копия рядом разошлась бы с
/// оригиналом молча — тем же приёмом, каким уже сведены подставные договоры
/// входа в `test/presentation/auth/support/fakes.dart`.
library;

import 'dart:math' as math;
import 'dart:ui';

/// Контраст по WCAG 2.1: (L1 + 0.05) / (L2 + 0.05).
double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

double _luminance(Color c) {
  double channel(double srgb) => srgb <= 0.03928
      ? srgb / 12.92
      : math.pow((srgb + 0.055) / 1.055, 2.4) as double;

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}
