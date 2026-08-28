import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/input_mode.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';
import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_choice_tile.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_section.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_error_note.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_hero.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_scaffold.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';

/// Первый шаг мастера: страна.
///
/// Было: залитый цветом круг 100 px с иконкой, страны — карточками с
/// двухпиксельной рамкой и заливкой. Стало: шапка без круга и один
/// сгруппированный список, где выбранное отмечено галочкой.
class CountryStep extends ConsumerWidget {
  const CountryStep({required this.state, super.key});

  final InitialSetupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final metrics = WizardMetrics.resolve(
      layout: Breakpoints.of(context),
      input: ref.watch(inputModeProvider),
    );
    // Контроллер читается внутри обработчиков, а не при построении. Чтение
    // `.notifier` в build() создаёт контроллер немедленно — со своими
    // таймерами и обращениями к графу зависимостей, — и шаг перестаёт
    // рисоваться сам по себе. А рисоваться сам по себе он обязан: на этом
    // держатся и голдены, и возможность посмотреть один экран, не поднимая
    // кассу целиком.
    InitialSetupNotifier controller() =>
        ref.read(initialSetupControllerProvider.notifier);

    return WizardScaffold(
      totalSteps: state.totalSteps,
      currentStep: state.stepNumber,
      nextEnabled: state.selectedCountry != null,
      busy: state.isLoading,
      onNext: () => controller().confirmCountrySelection(),
      // Первый шаг — один из двух, где приветствие с иллюстрацией уместно, как
      // в первом запуске Telegram. Заголовок под ней — роль `title` (20);
      // крупнее в приложении нет ничего, кроме сумм.
      //
      // Самой иллюстрации пока нет: задача 19 её ещё не сгенерировала, а
      // Image.asset на отсутствующий файл рисует ящик ошибки.
      hero: WizardHero(
        metrics: metrics,
        title: l10n.setupWelcomeTitle,
        subtitle: l10n.setupCountryDescription,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSection(
            header: l10n.setupStepCountry,
            children: [
              for (final country in CountryCode.values)
                SettingsChoiceTile(
                  metrics: metrics,
                  leading: Text(
                    _flag(country),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  title: country.countryName,
                  subtitle:
                      '${country.currencyName} (${country.currencyShort})',
                  // Ставка НДС из подзаголовка убрана намеренно: её
                  // спрашивают следующим шагом, и показывать ответ до того,
                  // как задан вопрос, незачем.
                  detail: l10n.setupPriceExample(country.formatMoney(1234.56)),
                  selected: state.selectedCountry == country,
                  onTap: () => controller().selectCountry(country),
                ),
            ],
          ),
          if (state.hasError)
            WizardErrorNote(
              message: ErrorLocalizer.localize(context, state.error!),
            ),
        ],
      ),
    );
  }

  String _flag(CountryCode country) => switch (country) {
    CountryCode.kzt => '🇰🇿',
    CountryCode.rub => '🇷🇺',
    CountryCode.kgs => '🇰🇬',
    CountryCode.uzs => '🇺🇿',
    CountryCode.usd => '🇺🇸',
    CountryCode.tmt => '🇹🇲',
  };
}
