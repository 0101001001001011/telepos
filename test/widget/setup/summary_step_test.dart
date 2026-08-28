import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_tile.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_progress_rail.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';
import 'package:telepos/presentation/screens/setup/steps/checking_step.dart';
import 'package:telepos/presentation/screens/setup/steps/complete_step.dart';
import 'package:telepos/presentation/screens/setup/steps/summary_step.dart';
import 'package:telepos/presentation/screens/setup/steps/unreadable_step.dart';

class _StubNotifier extends InitialSetupNotifier {
  _StubNotifier(this._state);

  final InitialSetupState _state;

  @override
  InitialSetupState build() => _state;
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  InitialSetupState? stub,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (stub != null)
          initialSetupControllerProvider.overrideWith(
            () => _StubNotifier(stub),
          ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
  // Экран проверки крутит бесконечный индикатор: pumpAndSettle на нём не
  // сойдётся никогда, и это не поломка теста, а суть экрана.
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

const _filled = InitialSetupState(
  currentStep: InitialSetupStep.summary,
  organization: OrganizationInfo(
    companyName: 'ТОО Ромашка',
    taxId: '123456789012',
  ),
);

void main() {
  testWidgets('итог показывает введённое строками «название — значение»', (
    tester,
  ) async {
    await _pump(tester, const SummaryStep(state: _filled));

    expect(find.byType(SettingsTile), findsWidgets);
    expect(find.text('ТОО Ромашка'), findsOneWidget);
    expect(find.text('123456789012'), findsOneWidget);
  });

  testWidgets('на итоге рельс заполнен целиком', (tester) async {
    await _pump(
      tester,
      const SummaryStep(
        state: InitialSetupState(currentStep: InitialSetupStep.summary),
      ),
    );

    final rail = tester.widget<WizardProgressRail>(
      find.byType(WizardProgressRail),
    );
    expect(rail.currentStep, rail.totalSteps);
  });

  testWidgets('строка итога ведёт назад к своему шагу', (tester) async {
    // Ради этого «название — значение» и заводилось. Раньше исправить
    // замеченное на итоге можно было только одиннадцатью нажатиями «Назад».
    late ProviderContainer container;
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialSetupControllerProvider.overrideWith(
            () => _StubNotifier(_filled),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('ru'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const SummaryStep(state: _filled),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ТОО Ромашка'));
    await tester.pumpAndSettle();

    expect(
      container.read(initialSetupControllerProvider).currentStep,
      InitialSetupStep.organizationSetup,
    );
  });

  testWidgets('прыжок на состояние вне нумерации отклоняется', (tester) async {
    // `unreadable` существует, чтобы неотвеченный вопрос «настроена ли касса»
    // не был принят за «не настроена». Вход в него откуда бы то ни было свёл
    // бы его смысл на нет.
    final container = ProviderContainer(
      overrides: [
        initialSetupControllerProvider.overrideWith(
          () => _StubNotifier(_filled),
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(initialSetupControllerProvider.notifier)
        .goToStep(InitialSetupStep.unreadable);

    expect(
      container.read(initialSetupControllerProvider).currentStep,
      InitialSetupStep.summary,
    );
  });

  testWidgets('экран проверки не показывает рельса', (tester) async {
    await _pump(tester, const CheckingStep(), settle: false);
    expect(find.byType(WizardProgressRail), findsNothing);
  });

  testWidgets('нечитаемое состояние рельса не показывает и в мастер не ведёт', (
    tester,
  ) async {
    await _pump(
      tester,
      const UnreadableStep(),
      stub: const InitialSetupState(currentStep: InitialSetupStep.unreadable),
    );

    expect(find.byType(WizardProgressRail), findsOneWidget);
    final rail = tester.widget<WizardProgressRail>(
      find.byType(WizardProgressRail),
    );
    expect(rail.currentStep, 0, reason: 'вне нумерации — рельс пуст');

    // Единственное действие — повтор. Кнопки «Далее» здесь быть не должно.
    expect(find.widgetWithText(ElevatedButton, 'Повторить'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Далее'), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('на «готово» рельс заполнен целиком и зелёного круга нет', (
    tester,
  ) async {
    await _pump(
      tester,
      const CompleteStep(),
      stub: const InitialSetupState(currentStep: InitialSetupStep.complete),
    );

    final rail = tester.widget<WizardProgressRail>(
      find.byType(WizardProgressRail),
    );
    expect(rail.currentStep, rail.totalSteps);
    expect(find.byType(Card), findsNothing);
  });
}
