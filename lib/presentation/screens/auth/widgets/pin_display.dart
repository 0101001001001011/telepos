import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';

class PinDisplay extends StatelessWidget {
  const PinDisplay({
    required this.length,
    required this.enteredCount,
    this.hasError = false,
    this.maxLength = 4,
    super.key,
  });

  final int maxLength;

  final int enteredCount;

  final int length;

  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxLength, (index) {
        final isFilled = index < enteredCount;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? (hasError
                      ? Theme.of(context).colorScheme.error
                      : AppColors.primary)
                : Colors.transparent,
            border: Border.all(
              color: hasError
                  ? Theme.of(context).colorScheme.error
                  : (isFilled
                        ? AppColors.primary
                        : Theme.of(context).colorScheme.outline),
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}

class PinDisplayLarge extends StatelessWidget {
  const PinDisplayLarge({
    required this.enteredCount,
    this.maxLength = 4,
    this.errorMessage,
    super.key,
  });

  final int maxLength;

  final int enteredCount;

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final hasError = errorMessage != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppLocalizations.of(context)!.authEnterPin,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppTheme.spacing),

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLarge,
            vertical: AppTheme.spacing,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            border: Border.all(
              color: hasError
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.outline,
            ),
          ),
          child: PinDisplay(
            length: enteredCount,
            enteredCount: enteredCount,
            maxLength: maxLength,
            hasError: hasError,
          ),
        ),

        if (hasError) ...[
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            errorMessage!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
