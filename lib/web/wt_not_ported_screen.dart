import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/input_mode.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_section.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_hero.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_scaffold.dart';

/// Маршрут, до которого браузерный терминал ещё не дотягивается.
///
/// # Зачем он есть
///
/// Браузерная таблица маршрутов растёт по одному экрану: маршрут переезжает в
/// неё тогда, когда договоры этого экрана получают реализацию поверх провода.
/// Пока экран не переехал, переход на него по-прежнему написан в общем коде —
/// `initial_setup_screen.dart` зовёт `/network-settings` кнопкой Wi-Fi на
/// каждом шаге мастера, — и без этого экрана такой переход даёт
/// `GoException: no routes for location`. Исключение маршрутизатора и белый
/// экран для кассира одно и то же: он не знает, что делать. Отказ обязан
/// приходить значением (И144), и вот его облик.
///
/// # Почему один экран на две роли
///
/// Он же стоит `errorBuilder`-ом браузерной таблицы. Это не «на всякий
/// случай»: перечень переходов ведётся руками, и забытый в нём переход — это
/// ровно тот дефект, который стоил заказчику пройденного до конца мастера.
/// Сторож (`test/architecture/browser_routes_test.dart`) не даёт списку
/// разойтись с кодом, а `errorBuilder` отвечает за то, чего сторож не
/// предвидел: между «названный экран» и «исключение» выбор очевиден.
///
/// # Почему не «ошибка»
///
/// Это не поломка, а граница: касса умеет это делать, браузерный терминал —
/// пока нет. Слово «ошибка» отправило бы оператора чинить исправное.
class WtNotPortedScreen extends ConsumerWidget {
  const WtNotPortedScreen({required this.location, super.key});

  /// Куда просились. Показывается дословно: без него экран говорит «что-то
  /// недоступно», а это ровно столько же сведений, сколько в белом поле.
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final metrics = WizardMetrics.resolve(
      layout: Breakpoints.of(context),
      input: ref.watch(inputModeProvider),
    );

    return WizardScaffold(
      totalSteps: 1,
      currentStep: 0,
      nextLabel: l10n.globalBack,
      // Возврат, а не «повторить»: повторять нечего — маршрута нет и через
      // секунду не появится. `pop` работает после `push` (так открывается
      // кнопка Wi-Fi мастера); из `errorBuilder` стека может не быть вовсе,
      // и тогда единственное осмысленное место — состояние терминала.
      onNext: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.login);
        }
      },
      hero: WizardHero(
        metrics: metrics,
        title: l10n.wtNotPortedTitle,
        illustration: Icon(
          Icons.pending_outlined,
          size: AppTokens.iconSizeSuccess,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      child: SettingsSection(
        footer: l10n.wtNotPortedBody,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTokens.space16),
            child: Text(
              l10n.wtNotPortedLocation(location),
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
