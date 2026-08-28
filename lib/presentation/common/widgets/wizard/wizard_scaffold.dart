import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/input_mode.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_actions.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_progress_rail.dart';

/// Каркас шага мастера.
///
/// Берёт на себя рельс, ширину колонки, поля страницы, прокрутку, липкую
/// панель действий над экранной клавиатурой и клавиатурные сокращения. Шаг
/// после этого содержит только секции — и это единственный способ добиться,
/// чтобы одиннадцать экранов выглядели одинаково.
class WizardScaffold extends ConsumerWidget {
  const WizardScaffold({
    required this.totalSteps,
    required this.currentStep,
    required this.child,
    this.hero,
    this.onNext,
    this.onBack,
    this.nextLabel,
    this.nextEnabled = true,
    this.busy = false,
    this.trailingHeaderActions = const [],
    super.key,
  });

  static const columnKey = ValueKey('wizard-column');

  final int totalSteps;
  final int currentStep;
  final Widget child;

  /// Иллюстрация с заголовком — только у первого шага и у завершения.
  ///
  /// У шагов, где заполняют поля, этого блока нет вовсе, и `null` здесь —
  /// норма, а не упущение. Название шага уже стоит в шапке мастера
  /// (`InitialSetupScreen`); третий его повтор крупным кеглем по центру и был
  /// тем «плакатом», из-за которого экран не походил на Telegram.
  final Widget? hero;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final String? nextLabel;
  final bool nextEnabled;
  final bool busy;
  final List<Widget> trailingHeaderActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final layout = Breakpoints.of(context);
    final input = ref.watch(inputModeProvider);
    final metrics = WizardMetrics.resolve(layout: layout, input: input);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            metrics.pageMargin,
            AppTokens.space12,
            metrics.pageMargin,
            AppTokens.space16,
          ),
          child: Row(
            children: [
              // Под пальцем возврат живёт в шапке: две кнопки внизу
              // конкурируют за большой палец, и «Назад» нажимается по ошибке.
              // Под указателем он уезжает в панель действий — там его ждут.
              if (onBack != null && !metrics.actionsAlignedRight)
                IconButton(
                  onPressed: busy ? null : onBack,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: l10n.globalBack,
                ),
              Expanded(
                child: WizardProgressRail(
                  totalSteps: totalSteps,
                  currentStep: currentStep,
                ),
              ),
              ...trailingHeaderActions,
            ],
          ),
        ),
        // Форма прижата к ВЕРХУ, иллюстрация центрируется. Правило одно, и оно
        // выводится из [hero], а не задаётся каждым экраном отдельно.
        //
        // Раньше центрировалось всё: `ConstrainedBox(minHeight: maxHeight)`
        // плюс `MainAxisAlignment.center`. Короткий шаг раздвигался на всю
        // высоту, и его единственная секция вставала посреди экрана.
        // Оправдание было такое — иначе между содержимым и панелью действий
        // зияет пустота.
        //
        // Оправдание неверно, и это видно на любом экране настроек Telegram:
        // группы начинаются сразу под шапкой, а пустота внизу — нормальное
        // состояние короткого списка. Центрирование же ставило первую строку
        // каждого шага на разную высоту в зависимости от того, сколько строк
        // ниже, и глаз заново искал начало на каждом следующем шаге.
        //
        // Экраны с иллюстрацией — другое дело: там картинка с подписью и есть
        // всё содержимое, и прижатая к верху она выглядит не композицией, а
        // обрезком. Так же устроен первый запуск Telegram.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final column = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: hero != null
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  if (hero != null) ...[
                    hero!,
                    const SizedBox(height: AppTokens.space32),
                  ],
                  child,
                  const SizedBox(height: AppTokens.space24),
                ],
              );

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: metrics.pageMargin),
                child: hero == null
                    ? column
                    // Минимальная высота нужна только центрированию: без неё
                    // Column сжимается по содержимому, и центрировать
                    // становится нечего.
                    : ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: column,
                      ),
              );
            },
          ),
        ),
        // Панель действий поднимается над экранной клавиатурой сама: содержимое
        // выше неё лежит в Expanded, а Scaffold по умолчанию ужимается под
        // viewInsets.
        Padding(
          padding: EdgeInsets.fromLTRB(
            metrics.pageMargin,
            AppTokens.space12,
            metrics.pageMargin,
            AppTokens.space16,
          ),
          child: WizardActions(
            metrics: metrics,
            nextLabel: nextLabel ?? l10n.globalNext,
            backLabel: l10n.globalBack,
            onNext: onNext,
            onBack: metrics.actionsAlignedRight ? onBack : null,
            nextEnabled: nextEnabled,
            busy: busy,
          ),
        ),
      ],
    );

    final column = Center(
      child: ConstrainedBox(
        key: columnKey,
        constraints: BoxConstraints(
          maxWidth: metrics.columnMaxWidth ?? double.infinity,
        ),
        child: body,
      ),
    );

    // Клавиатурные сокращения — только под указателем. На телефоне Enter в
    // поле ввода означает «следующее поле», а не «следующий шаг».
    if (!metrics.showFocusRing) {
      return Scaffold(body: SafeArea(child: column));
    }

    return Scaffold(
      body: SafeArea(
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): _NextIntent(),
            SingleActivator(LogicalKeyboardKey.numpadEnter): _NextIntent(),
            SingleActivator(LogicalKeyboardKey.escape): _BackIntent(),
          },
          child: Actions(
            actions: {
              _NextIntent: CallbackAction<_NextIntent>(
                onInvoke: (_) {
                  if (nextEnabled && !busy) onNext?.call();
                  return null;
                },
              ),
              _BackIntent: CallbackAction<_BackIntent>(
                onInvoke: (_) {
                  if (!busy) onBack?.call();
                  return null;
                },
              ),
            },
            child: Focus(autofocus: true, child: column),
          ),
        ),
      ),
    );
  }
}

class _NextIntent extends Intent {
  const _NextIntent();
}

class _BackIntent extends Intent {
  const _BackIntent();
}
