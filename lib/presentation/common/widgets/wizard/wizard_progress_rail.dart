import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/l10n/app_localizations.dart';

/// Прогресс мастера сегментами, как индикатор историй в Telegram.
///
/// Заменяет [LinearProgressIndicator]. Дело не только во внешнем виде:
/// непрерывная полоса утверждает, что настройка измеряется процентами, а она
/// измеряется шагами — их одиннадцать, и человек проходит их по одному.
class WizardProgressRail extends StatelessWidget {
  const WizardProgressRail({
    required this.totalSteps,
    required this.currentStep,
    super.key,
  });

  final int totalSteps;

  /// Единица-ориентированный номер. Ноль означает «шаг вне нумерации»
  /// (проверка состояния, нечитаемое состояние) — рельс тогда не рисуется.
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    if (currentStep <= 0 || totalSteps <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppTokens.railHeight / 2);

    // Цвет сегмента программе чтения с экрана недоступен, поэтому номер шага
    // проговаривается словами. Строка берётся из локализации, а не из кода:
    // мастер проходят на пяти языках.
    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      label: l10n.setupStepProgress(currentStep, totalSteps),
      child: Row(
        children: [
          for (var index = 0; index < totalSteps; index++) ...[
            // Зазор — отдельным элементом строки, а не отступом внутри
            // сегмента. Отступ внутри Expanded съедает ширину у сегмента, и
            // последний, у которого отступа нет, оказывается шире остальных.
            if (index != 0) const SizedBox(width: AppTokens.railGap),
            Expanded(
              child: AnimatedContainer(
                duration: AppTokens.durationFast,
                curve: Curves.easeOut,
                height: AppTokens.railHeight,
                decoration: BoxDecoration(
                  color: index < currentStep
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                  borderRadius: radius,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
