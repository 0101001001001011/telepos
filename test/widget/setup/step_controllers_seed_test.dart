import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';
import 'package:telepos/presentation/screens/setup/steps/organization_step.dart';
import 'package:telepos/presentation/screens/setup/steps/payment_terminal_step.dart';
import 'package:telepos/presentation/screens/setup/steps/pos_step.dart';

/// Разрез монолита переселил тридцать контроллеров из общего состояния мастера
/// в состояния отдельных шагов. Это меняет их время жизни: раньше контроллер
/// жил, пока открыт мастер, теперь — пока виден его шаг.
///
/// Отсюда риск, которого до разреза не было: уход на шаг назад и возврат
/// пересоздаёт контроллер, и без начального значения из черновика он вернулся
/// бы пустым. Человек при этом уже видел, что данные приняты.
Future<void> _pumpStep(WidgetTester tester, Widget step) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Scaffold шаг получает от InitialSetupScreen — сам он его не заводит.
        home: Scaffold(body: step),
      ),
    ),
  );
  await tester.pump();
}

/// Содержимое всех полей шага.
///
/// Проверять через `find.text` нельзя: подсказка поля (`hintText`) у половины
/// полей совпадает с образцовым значением, и совпадение с ней прошло бы за
/// проверку, ничего не проверив.
Set<String> _fieldValues(WidgetTester tester) {
  return tester
      .widgetList<TextField>(find.byType(TextField))
      .map((f) => f.controller?.text ?? '')
      .where((t) => t.isNotEmpty)
      .toSet();
}

void main() {
  testWidgets('шаг организации показывает уже набранное', (tester) async {
    const state = InitialSetupState(
      currentStep: InitialSetupStep.organizationSetup,
      organization: OrganizationInfo(
        companyName: 'ТОО Ромашка',
        taxId: '123456789012',
        legalAddress: 'Алматы, Абая 1',
        contactName: 'Асхат',
      ),
    );

    await _pumpStep(tester, const OrganizationStep(state: state));

    expect(
      _fieldValues(tester),
      containsAll(['ТОО Ромашка', '123456789012', 'Алматы, Абая 1', 'Асхат']),
    );
  });

  testWidgets('шаг кассы показывает уже набранное', (tester) async {
    const state = InitialSetupState(
      currentStep: InitialSetupStep.posSetup,
      posConfig: PosConfigInfo(cashBoxName: 'Касса у входа', posId: 'POS-7'),
    );

    await _pumpStep(tester, const PosStep(state: state));

    expect(_fieldValues(tester), containsAll(['Касса у входа', 'POS-7']));
  });

  testWidgets('пустой черновик даёт значения по умолчанию, а не пустоту', (
    tester,
  ) async {
    // POS-1 и порт 9999 были значениями по умолчанию в монолите. Разрез не
    // имеет права их потерять: это не украшение, а рабочая настройка.
    await _pumpStep(tester, const PosStep(state: InitialSetupState()));
    expect(_fieldValues(tester), contains('POS-1'));

    // Терминал по умолчанию выключен, и полей его тогда не видно вовсе —
    // порт проверяется на включённом.
    await _pumpStep(
      tester,
      const PaymentTerminalStep(
        state: InitialSetupState(
          paymentTerminalConfig: PaymentTerminalConfigInfo(kaspiEnabled: true),
        ),
      ),
    );
    expect(_fieldValues(tester), contains('9999'));
  });

  testWidgets('черновик перебивает значение по умолчанию', (tester) async {
    // Если бы контроллер пересоздавался с 'POS-1' поверх сохранённого POS-7,
    // возврат на шаг назад молча менял бы номер кассы.
    const state = InitialSetupState(posConfig: PosConfigInfo(posId: 'POS-7'));

    await _pumpStep(tester, const PosStep(state: state));

    expect(_fieldValues(tester), contains('POS-7'));
    expect(_fieldValues(tester), isNot(contains('POS-1')));
  });
}
