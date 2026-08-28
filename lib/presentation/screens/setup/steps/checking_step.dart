import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/l10n/app_localizations.dart';

/// Касса спрашивает саму себя, настроена ли она.
///
/// Рельса здесь нет: у этого состояния нет номера шага, и «шаг 0 из 11» на
/// экране не значит ничего. Фон и поля — общие с остальными шагами, чтобы
/// переход от проверки к первому шагу не выглядел сменой приложения.
class CheckingStep extends ConsumerWidget {
  const CheckingStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppTokens.space24),
          Text(l10n.setupCheckingSettings, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}
