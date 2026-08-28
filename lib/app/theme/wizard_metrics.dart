import 'package:flutter/widgets.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/input_mode.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';

/// Раскладка шага мастера: что меняется от платформы к платформе.
///
/// Чистая функция от двух входов, поэтому проверяется во всех шести
/// сочетаниях без единого виджета.
@immutable
class WizardMetrics {
  const WizardMetrics({
    required this.rowHeight,
    required this.pageMargin,
    required this.columnMaxWidth,
    required this.heroHeight,
    required this.showHover,
    required this.showFocusRing,
    required this.actionsAlignedRight,
  });

  factory WizardMetrics.resolve({
    required LayoutType layout,
    required InputMode input,
  }) {
    final pointer = input == InputMode.pointer;
    return WizardMetrics(
      // Высота строки — от способа ввода, не от ширины.
      rowHeight: pointer
          ? AppTokens.rowHeightPointer
          : AppTokens.rowHeightTouch,
      pageMargin: switch (layout) {
        LayoutType.mobile => AppTokens.pageMarginMobile,
        LayoutType.tablet => AppTokens.pageMarginTablet,
        LayoutType.desktop => AppTokens.pageMarginDesktop,
      },
      // На телефоне колонка занимает всю ширину: ограничивать нечего.
      columnMaxWidth: switch (layout) {
        LayoutType.mobile => null,
        LayoutType.tablet => AppTokens.columnMaxWidthTablet,
        LayoutType.desktop => AppTokens.columnMaxWidthDesktop,
      },
      heroHeight: switch (layout) {
        LayoutType.mobile => AppTokens.heroHeightMobile,
        LayoutType.tablet => AppTokens.heroHeightTablet,
        LayoutType.desktop => AppTokens.heroHeightDesktop,
      },
      showHover: pointer,
      showFocusRing: pointer,
      // Кнопки к правому краю — только когда экран широкий И управляется
      // указателем. Планшет под пальцем оставляет кнопку во всю ширину.
      actionsAlignedRight: pointer && layout == LayoutType.desktop,
    );
  }

  /// Разрешает метрики по текущему контексту. Ширину берёт из [MediaQuery],
  /// режим ввода передаётся снаружи — он приходит из провайдера, а не из
  /// платформы напрямую, потому что мастер даёт его переопределить.
  factory WizardMetrics.of(BuildContext context, {required InputMode input}) {
    return WizardMetrics.resolve(layout: Breakpoints.of(context), input: input);
  }

  final double rowHeight;
  final double pageMargin;

  /// `null` означает «во всю доступную ширину».
  final double? columnMaxWidth;
  final double heroHeight;
  final bool showHover;
  final bool showFocusRing;
  final bool actionsAlignedRight;
}
