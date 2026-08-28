import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_field_tile.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_section.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_progress_rail.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';
import 'package:telepos/presentation/screens/setup/steps/organization_step.dart';
import 'package:telepos/presentation/screens/setup/steps/pos_step.dart';

/// Подменяет контроллер мастера неподвижным состоянием.
///
/// Настоящий заводит таймер начальной проверки, как только его создадут, —
/// а создаёт его первое же изменение поля. Проверяем ввод, а не запуск кассы.
class _StubNotifier extends InitialSetupNotifier {
  _StubNotifier(this._state);

  final InitialSetupState _state;

  @override
  InitialSetupState build() => _state;
}

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  Size size, {
  InitialSetupState? stub,
}) async {
  tester.view.physicalSize = size;
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
  await tester.pumpAndSettle();
}

const _org = InitialSetupState(currentStep: InitialSetupStep.organizationSetup);
const _pos = InitialSetupState(currentStep: InitialSetupStep.posSetup);

void main() {
  testWidgets('поля организации разложены по трём секциям', (tester) async {
    await _pump(
      tester,
      const OrganizationStep(state: _org),
      const Size(800, 1600),
    );
    expect(find.byType(SettingsSection), findsNWidgets(3));
  });

  testWidgets('касса разложена по двум секциям', (tester) async {
    await _pump(tester, const PosStep(state: _pos), const Size(800, 1600));
    expect(find.byType(SettingsSection), findsNWidgets(2));
  });

  testWidgets('рамок вокруг полей нет', (tester) async {
    await _pump(
      tester,
      const OrganizationStep(state: _org),
      const Size(800, 1600),
    );

    expect(find.byType(TextField), findsWidgets);
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      final border = field.decoration?.border;
      expect(
        border,
        anyOf(isNull, equals(InputBorder.none)),
        reason: 'секция уже задаёт границу, вторая рамка внутри неё лишняя',
      );
    }
  });

  testWidgets('декоративных иконок в полях не осталось', (tester) async {
    // prefixIcon в каждой строке создавал вертикальную полосу шума слева и
    // повторял то, что уже сказано подписью строки.
    await _pump(
      tester,
      const OrganizationStep(state: _org),
      const Size(800, 1600),
    );

    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.decoration?.prefixIcon, isNull);
    }
  });

  testWidgets('на широком экране поля не растягиваются во всю ширину', (
    tester,
  ) async {
    await _pump(
      tester,
      const OrganizationStep(state: _org),
      const Size(1600, 1200),
    );

    final section = tester.getSize(find.byType(SettingsSection).first);
    expect(
      section.width,
      lessThanOrEqualTo(AppTokens.columnMaxWidthDesktop),
      reason: 'колонка на десктопе ограничена 640',
    );
  });

  testWidgets('на телефоне секция занимает ширину за вычетом полей', (
    tester,
  ) async {
    // Другая половина привязки к платформе: ограничение 640 не должно
    // превратиться в «640 везде», иначе на телефоне 400 останется поле в
    // 120 px с каждой стороны.
    await _pump(
      tester,
      const OrganizationStep(state: _org),
      const Size(400, 1600),
    );

    final section = tester.getSize(find.byType(SettingsSection).first);
    expect(section.width, 400 - AppTokens.pageMarginMobile * 2);
  });

  testWidgets('материальной полосы прогресса нет ни на одной из форм', (
    tester,
  ) async {
    for (final step in <Widget>[
      const OrganizationStep(state: _org),
      const PosStep(state: _pos),
    ]) {
      await _pump(tester, step, const Size(800, 1600));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(WizardProgressRail), findsOneWidget);
      expect(find.byType(Card), findsNothing);
    }
  });

  testWidgets('налоговый номер принимает только цифры и не длиннее нормы', (
    tester,
  ) async {
    // БИН уходит в фискальный сервис. Буква, проскочившая в поле, всплывёт
    // только при первой сверке с КГД — то есть после того, как чеки уже
    // напечатаны.
    await _pump(
      tester,
      const OrganizationStep(state: _org),
      const Size(800, 1600),
      stub: _org,
    );

    // Искать по типу клавиатуры нельзя: телефон тоже цифровой. Берём поле
    // той строки, у которой подпись — налоговый номер.
    final taxField = find.descendant(
      of: find.ancestor(
        of: find.text('БИН/ИИН'),
        matching: find.byType(SettingsFieldTile),
      ),
      matching: find.byType(TextField),
    );
    expect(taxField, findsOneWidget);

    await tester.enterText(taxField, 'AB12345678901234567890');
    await tester.pump();

    final controller = tester.widget<TextField>(taxField).controller!;
    expect(controller.text, '123456789012');
  });
}
