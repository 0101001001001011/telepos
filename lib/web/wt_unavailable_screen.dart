import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/app_typography.dart';
import 'package:telepos/app/theme/input_mode.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_section.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_hero.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_scaffold.dart';

/// Экран, когда сессии к кассе нет.
///
/// # Почему он вообще существует
///
/// 2026-08-04 белый экран без единого слова нашёлся трижды за один день, и
/// каждый раз причина была в логе и не была на экране. Отказ обязан приходить
/// значением (И144), а значение обязано доезжать до глаз: `WtUnavailable`
/// несёт названную причину, и вот место, где её видно.
///
/// # Почему здесь нет запасного пути через REST
///
/// Решение заказчика 2026-08-04. Провод один — WebTransport, — и молчаливый
/// откат на HTTP означал бы работающий с виду терминал, который перестал
/// узнавать о событиях кассы. Такой терминал ищут не там, где он сломан.
/// Поэтому здесь ровно одно действие: повторить.
///
/// # Почему по образцу `UnreadableStep`
///
/// Тот экран отвечает на тот же род вопроса — «кассу не удалось спросить», —
/// и уже решён: иллюстрация с заголовком, пояснение, одна кнопка. Второй
/// облик для того же состояния означал бы, что оператор дважды учится одному.
class WtUnavailableScreen extends ConsumerWidget {
  const WtUnavailableScreen({
    required this.reason,
    required this.onRetry,
    super.key,
  });

  /// Названная причина из `WtUnavailable`. Пустой не бывает: «не получилось»
  /// без продолжения — тот же белый экран, только с рамкой.
  final String reason;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final metrics = WizardMetrics.resolve(
      layout: Breakpoints.of(context),
      input: ref.watch(inputModeProvider),
    );

    return WizardScaffold(
      // Мастера здесь нет: у состояния «нет связи» номера шага не бывает.
      // Ноль означает «вне нумерации» — рельс себя не рисует.
      totalSteps: 1,
      currentStep: 0,
      nextLabel: l10n.globalRetry,
      onNext: onRetry,
      hero: WizardHero(
        metrics: metrics,
        title: l10n.wtUnavailableTitle,
        illustration: Icon(
          Icons.cloud_off,
          size: AppTokens.iconSizeSuccess,
          color: theme.colorScheme.error,
        ),
      ),
      child: SettingsSection(
        footer: l10n.wtUnavailableBody,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTokens.space16),
            child: Text(
              l10n.wtUnavailableReason(reason),
              // Роль `body`, а не заголовок: причина — это подробность для
              // того, кто пойдёт её устранять, а не название состояния.
              style: AppTypography.body.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
