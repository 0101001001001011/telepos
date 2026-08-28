import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/app_typography.dart';
import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_section.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_hero.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';
import 'package:telepos/presentation/screens/setup/steps/business_rules_step.dart';
import 'package:telepos/presentation/screens/setup/steps/complete_step.dart';
import 'package:telepos/presentation/screens/setup/steps/country_step.dart';
import 'package:telepos/presentation/screens/setup/steps/employees_step.dart';
import 'package:telepos/presentation/screens/setup/steps/equipment_step.dart';
import 'package:telepos/presentation/screens/setup/steps/fiscal_step.dart';
import 'package:telepos/presentation/screens/setup/steps/operating_mode_step.dart';
import 'package:telepos/presentation/screens/setup/steps/organization_step.dart';
import 'package:telepos/presentation/screens/setup/steps/payment_terminal_step.dart';
import 'package:telepos/presentation/screens/setup/steps/pos_step.dart';
import 'package:telepos/presentation/screens/setup/steps/summary_step.dart';
import 'package:telepos/presentation/screens/setup/steps/vat_step.dart';

/// Композиция шага: плаката нет, группы подписаны, содержимое сверху.
///
/// Заказчик посмотрел собранный веб 2026-08-04 и сказал: «шрифт конечно
/// верный, а вот на телеграм не похоже». Разобралось это на две измеримые
/// вещи, и обе проверяются здесь, а не на глаз по эталону: эталон покажет
/// разницу, но не назовёт правило, а правило — именно то, что возвращается
/// первым же экраном, которому «нужен заголовок покрупнее».
///
/// Гоняется в ОБЕИХ темах. Композиция от темы не зависит, но до 2026-08-04
/// тёмная не проверялась вообще ничем, и «прогнать оба раза» стоит одного
/// цикла, а стоимость обратного уже измерена.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required Brightness brightness,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Черновик заполнен: пустой мастер прячет половину строк, и проверка
/// композиции прошла бы на экране из одной секции.
InitialSetupState _at(InitialSetupStep step) => InitialSetupState(
  currentStep: step,
  selectedCountry: CountryCode.kzt,
  organization: const OrganizationInfo(
    companyName: 'ТОО «Ромашка»',
    taxId: '123456789012',
    isVatPayer: true,
  ),
  posConfig: const PosConfigInfo(cashBoxName: 'Касса у входа'),
  fiscalConfig: const FiscalConfigInfo(
    enabled: true,
    fiscalType: FiscalType.webkassa,
  ),
  equipmentConfig: const EquipmentConfigInfo(printerEnabled: true),
  paymentTerminalConfig: const PaymentTerminalConfigInfo(kaspiEnabled: true),
  firstUser: const EmployeeInfo(name: 'Асхат', pin: '4321'),
);

/// Шаги, на которых ЗАПОЛНЯЮТ ПОЛЯ или выбирают из списка.
///
/// `country` и `complete` в список не входят: это два экрана-исключения, где
/// иллюстрация с заголовком уместна, как в первом запуске Telegram.
Map<String, Widget> _formSteps() => {
  'organization': OrganizationStep(
    state: _at(InitialSetupStep.organizationSetup),
  ),
  'vat': VatStep(state: _at(InitialSetupStep.vatSelection)),
  'mode': OperatingModeStep(
    state: _at(InitialSetupStep.operatingModeSelection),
  ),
  'employees': EmployeesStep(state: _at(InitialSetupStep.employeeSetup)),
  'pos': PosStep(state: _at(InitialSetupStep.posSetup)),
  'fiscal': FiscalStep(state: _at(InitialSetupStep.fiscalSetup)),
  'equipment': EquipmentStep(state: _at(InitialSetupStep.equipmentSetup)),
  'terminal': PaymentTerminalStep(
    state: _at(InitialSetupStep.paymentTerminalSetup),
  ),
  'rules': BusinessRulesStep(state: _at(InitialSetupStep.businessRulesSetup)),
  'summary': SummaryStep(state: _at(InitialSetupStep.summary)),
};

void main() {
  for (final theme in const {
    'светлая': Brightness.light,
    'тёмная': Brightness.dark,
  }.entries) {
    group('Композиция шага, ${theme.key} тема', () {
      testWidgets('ни на одном шаге с полями нет плаката', (tester) async {
        // Плакат — это центрированный заголовок 28-м кеглем с центрированным
        // подзаголовком под ним, стоявший наверху всех одиннадцати шагов. В
        // настройках Telegram заголовков по центру не бывает вовсе.
        //
        // Проверяются ВСЕ шаги сразу: убрать плакат на одном и оставить на
        // девяти — значит не убрать.
        for (final entry in _formSteps().entries) {
          await _pump(tester, entry.value, brightness: theme.value);
          expect(
            find.byType(WizardHero),
            findsNothing,
            reason: 'шаг ${entry.key} снова начинается с плаката',
          );
        }
      });

      testWidgets('каждый шаг с полями начинается подписью группы', (
        tester,
      ) async {
        // Иначе «плаката нет» превратилось бы в «названия нет»: экран, где
        // первая строка формы висит без объяснения, чем она является, хуже
        // плаката, а не лучше.
        for (final entry in _formSteps().entries) {
          await _pump(tester, entry.value, brightness: theme.value);
          final sections = tester
              .widgetList<SettingsSection>(find.byType(SettingsSection))
              .toList();
          expect(sections, isNotEmpty, reason: 'шаг ${entry.key} без секций');
          expect(
            sections.first.header,
            isNotNull,
            reason: 'шаг ${entry.key} начинается секцией без подписи',
          );
        }
      });

      testWidgets('подпись группы набрана ролью sectionHeader и слева', (
        tester,
      ) async {
        await _pump(
          tester,
          OrganizationStep(state: _at(InitialSetupStep.organizationSetup)),
          brightness: theme.value,
        );

        final header = tester.widget<Text>(find.text('Организация'));
        expect(header.style?.fontSize, AppTypography.sectionHeader.fontSize);
        expect(
          header.style?.fontWeight,
          AppTypography.sectionHeader.fontWeight,
        );

        final context = tester.element(find.text('Организация'));
        expect(
          header.style?.color,
          Theme.of(context).colorScheme.onSurfaceVariant,
        );
        // Слева, а не по центру: `textAlign` не задан вовсе, а колонка
        // растянута — значит выравнивание достаётся от направления письма.
        expect(header.textAlign, isNot(TextAlign.center));
      });

      testWidgets('заголовок экрана-исключения не крупнее title', (
        tester,
      ) async {
        // Исключений два — первый шаг и завершение. Там иллюстрация уместна,
        // но кегль под ней ровно 20: роли крупнее в приложении нет, и
        // `test/theme/app_typography_test.dart` следит, чтобы не появилась.
        for (final entry in <String, Widget>{
          'country': CountryStep(state: _at(InitialSetupStep.countrySelection)),
          'complete': const CompleteStep(),
        }.entries) {
          await _pump(tester, entry.value, brightness: theme.value);
          expect(
            find.byType(WizardHero),
            findsOneWidget,
            reason: 'у ${entry.key} пропала иллюстрация с заголовком',
          );

          final hero = tester.widget<WizardHero>(find.byType(WizardHero));
          final title = tester.widget<Text>(find.text(hero.title));
          expect(
            title.style?.fontSize,
            AppTypography.title.fontSize,
            reason: '${entry.key}: заголовок набран не ролью title',
          );
        }
      });
    });
  }
}
