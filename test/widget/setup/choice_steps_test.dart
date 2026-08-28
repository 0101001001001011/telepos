import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/core/constants/enums/operating_mode.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_choice_tile.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_section.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_progress_rail.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';
import 'package:telepos/presentation/screens/setup/steps/country_step.dart';
import 'package:telepos/presentation/screens/setup/steps/operating_mode_step.dart';
import 'package:telepos/presentation/screens/setup/steps/vat_step.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('страны показаны одним сгруппированным списком', (tester) async {
    await _pump(
      tester,
      const CountryStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.countrySelection,
        ),
      ),
    );

    expect(find.byType(SettingsSection), findsOneWidget);
    expect(
      find.byType(SettingsChoiceTile),
      findsNWidgets(CountryCode.values.length),
    );
  });

  testWidgets('выбранная страна отмечена галочкой ровно один раз', (
    tester,
  ) async {
    await _pump(
      tester,
      const CountryStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.countrySelection,
          selectedCountry: CountryCode.kzt,
        ),
      ),
    );

    final selected = tester
        .widgetList<SettingsChoiceTile>(find.byType(SettingsChoiceTile))
        .where((t) => t.selected);
    expect(selected.length, 1);
    expect(find.byIcon(TeleposIcons.check), findsOneWidget);
  });

  testWidgets('карточек с рамкой и тенью не осталось ни на одном из трёх', (
    tester,
  ) async {
    // Card появлялся на каждом шаге и был главным источником материального
    // вида. Проверяются все три экрана: убрать его на одном и оставить на
    // двух — значит не убрать.
    for (final step in <Widget>[
      const CountryStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.countrySelection,
        ),
      ),
      const VatStep(
        state: InitialSetupState(currentStep: InitialSetupStep.vatSelection),
      ),
      const OperatingModeStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.operatingModeSelection,
        ),
      ),
    ]) {
      await _pump(tester, step);
      expect(find.byType(Card), findsNothing, reason: '${step.runtimeType}');
    }
  });

  testWidgets('материальной полосы прогресса не осталось ни на одном', (
    tester,
  ) async {
    // Ради этого весь этап и делался: заказчик запускает приложение и должен
    // увидеть рельс, а не LinearProgressIndicator.
    for (final step in <Widget>[
      const CountryStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.countrySelection,
        ),
      ),
      const VatStep(
        state: InitialSetupState(currentStep: InitialSetupStep.vatSelection),
      ),
      const OperatingModeStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.operatingModeSelection,
        ),
      ),
    ]) {
      await _pump(tester, step);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(WizardProgressRail), findsOneWidget);
    }
  });

  testWidgets('рельс показывает первый шаг из одиннадцати', (tester) async {
    await _pump(
      tester,
      const CountryStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.countrySelection,
        ),
      ),
    );

    final rail = tester.widget<WizardProgressRail>(
      find.byType(WizardProgressRail),
    );
    expect(rail.currentStep, 1);
    expect(rail.totalSteps, 11);
  });

  testWidgets('пока страна не выбрана, дальше не пускает', (tester) async {
    // selectedCountry по умолчанию равна kzt, а не null, поэтому «не
    // выбрано» приходится задавать явно. Без этого проверка прошла бы на
    // состоянии, в котором страна как раз выбрана, и ничего бы не значила.
    await _pump(
      tester,
      const CountryStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.countrySelection,
          selectedCountry: null,
        ),
      ),
    );

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('со страной по умолчанию дальше пускает', (tester) async {
    await _pump(
      tester,
      const CountryStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.countrySelection,
        ),
      ),
    );

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('НДС: ровно один из двух вариантов отмечен всегда', (
    tester,
  ) async {
    // Третьего состояния у флага нет, поэтому «ничего не выбрано» на этом
    // шаге означало бы, что экран врёт о состоянии черновика.
    for (final payer in [true, false]) {
      await _pump(
        tester,
        VatStep(
          state: InitialSetupState(
            currentStep: InitialSetupStep.vatSelection,
            organization: OrganizationInfo(isVatPayer: payer),
          ),
        ),
      );

      final tiles = tester
          .widgetList<SettingsChoiceTile>(find.byType(SettingsChoiceTile))
          .toList();
      expect(tiles.length, 2);
      expect(tiles.where((t) => t.selected).length, 1, reason: 'payer=$payer');
    }
  });

  testWidgets('НДС: ставка страны показана в строке плательщика', (
    tester,
  ) async {
    await _pump(
      tester,
      const VatStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.vatSelection,
          selectedCountry: CountryCode.kzt,
        ),
      ),
    );

    expect(find.textContaining('${CountryCode.kzt.vatRate}'), findsWidgets);
  });

  testWidgets('режим работы: три варианта, отмечен текущий', (tester) async {
    await _pump(
      tester,
      const OperatingModeStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.operatingModeSelection,
          operatingMode: OperatingMode.restaurant,
        ),
      ),
    );

    final tiles = tester
        .widgetList<SettingsChoiceTile>(find.byType(SettingsChoiceTile))
        .toList();
    expect(tiles.length, 3);
    expect(tiles.where((t) => t.selected).length, 1);
    expect(tiles[1].selected, isTrue, reason: 'выбран ресторан');
  });

  testWidgets('иллюстраций нет, пока их не сгенерировали', (tester) async {
    // Задача 19 (иллюстрации) не сделана, каталога assets/images/setup нет.
    // Image.asset на отсутствующий файл рисует красный ящик в отладке и
    // пустоту в релизе — ссылаться на него до генерации нельзя.
    await _pump(
      tester,
      const CountryStep(
        state: InitialSetupState(
          currentStep: InitialSetupStep.countrySelection,
        ),
      ),
    );

    expect(find.byType(Image), findsNothing);
  });
}
