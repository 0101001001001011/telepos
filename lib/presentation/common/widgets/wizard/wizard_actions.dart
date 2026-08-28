import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';

/// «Далее» и «Назад».
///
/// Под пальцем кнопка занимает всю ширину колонки и стоит там, куда дотянется
/// большой палец. Под указателем на широком экране кнопки прижаты к правому
/// краю колонки — так устроены настольные диалоги, и растянутая на 640
/// пикселей кнопка на них выглядит чужой.
class WizardActions extends StatelessWidget {
  const WizardActions({
    required this.metrics,
    required this.nextLabel,
    required this.backLabel,
    this.onNext,
    this.onBack,
    this.nextEnabled = true,
    this.busy = false,
    super.key,
  });

  final WizardMetrics metrics;
  final String nextLabel;
  final String backLabel;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final bool nextEnabled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    // Занятость гасит кнопку, а не только показывает спиннер: иначе второе
    // нажатие во время записи в базу заводит вторую запись.
    final next = ElevatedButton(
      onPressed: (nextEnabled && !busy) ? onNext : null,
      child: busy
          ? const SizedBox(
              width: AppTokens.space20,
              height: AppTokens.space20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(nextLabel),
    );

    final back = onBack == null
        ? null
        : TextButton(onPressed: busy ? null : onBack, child: Text(backLabel));

    if (metrics.actionsAlignedRight) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (back != null) ...[back, const SizedBox(width: AppTokens.space8)],
          next,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        next,
        if (back != null) ...[const SizedBox(height: AppTokens.space4), back],
      ],
    );
  }
}
