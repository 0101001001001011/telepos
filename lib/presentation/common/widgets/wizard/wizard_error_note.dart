import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_tokens.dart';

/// Сообщение об ошибке шага.
///
/// Без иконки-восклицания и без красной заливки во всю ширину: ошибка должна
/// объяснять, что пошло не так, а не пугать. Повторяется на всех одиннадцати
/// шагах, поэтому это примитив, а не копия в каждом файле.
class WizardErrorNote extends StatelessWidget {
  const WizardErrorNote({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.space16),
      child: Container(
        padding: const EdgeInsets.all(AppTokens.space12),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTokens.radiusControl),
        ),
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ),
    );
  }
}
