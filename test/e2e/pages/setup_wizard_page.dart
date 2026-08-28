library;

import '../../support/settings_finders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/presentation/screens/auth/login_screen.dart';
import 'package:telepos/presentation/screens/setup/initial_setup_screen.dart';

class SetupWizardPage {
  SetupWizardPage(this.t);
  final WidgetTester t;

  /// Основная кнопка шага, какой бы ни была её подпись.
  ///
  /// Искать «Далее» по тексту больше нельзя: на шаге фискализации кнопка
  /// называется «Пропустить (настроить позже)». Это не обходной путь, а
  /// смысл перемены — вместо двух кнопок-синонимов рядом одна, и она честно
  /// говорит, что сделает.
  Finder get _next => find.byType(ElevatedButton);
  Finder get _done => find.widgetWithText(ElevatedButton, 'Готово');

  void expectOnWizard() =>
      expect(find.byType(InitialSetupScreen), findsOneWidget);

  /// Waits until the till has finished asking itself whether it is configured.
  ///
  /// The wizard used to open on an account screen, so this waited for that
  /// widget. There is no account screen any more — the first thing a till
  /// shows is the country, and the only thing worth waiting for is the
  /// checking spinner going away.
  Future<void> waitForFirstStep() async {
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 250));
      final stillChecking = find
          .byType(CircularProgressIndicator)
          .evaluate()
          .isNotEmpty;
      if (!stillChecking && find.text('Казахстан').evaluate().isNotEmpty) {
        return;
      }
    }
    await t.pumpAndSettle(const Duration(seconds: 1));
  }

  /// The wizard must never ask for an account: there is no server to check one
  /// against, and asking would be a dead end.
  void expectNoAccountQuestions() {
    for (final forbidden in [
      'Создать аккаунт',
      'У меня есть аккаунт',
      'Настроить офлайн (без аккаунта)',
    ]) {
      expect(
        find.text(forbidden),
        findsNothing,
        reason: 'Wizard must not ask about accounts: found "$forbidden"',
      );
    }
  }

  /// С 2026-08-04 название шага живёт в ШАПКЕ мастера и подписью группы, а не
  /// центрированным заголовком внутри шага: плакат убран целиком. Поэтому сюда
  /// передаётся короткое имя шага («Касса», «Пользователи»), а не бывший
  /// заголовок («Настройка кассы», «Создание пользователей»).
  void expectStepTitle(String ruTitle) => expect(
    find.text(ruTitle),
    findsWidgets,
    reason: 'Expected to be on step with title "$ruTitle"',
  );

  void expectReachedLogin() {
    expect(
      find.byType(LoginScreen),
      findsOneWidget,
      reason: 'Wizard should hand off to the login screen on completion',
    );
    expect(
      find.byType(InitialSetupScreen),
      findsNothing,
      reason: 'The setup wizard should no longer be mounted',
    );
  }

  Future<void> selectCountryAndNext(String countryName) async {
    final card = find.text(countryName);
    expect(card, findsWidgets, reason: 'Country "$countryName" must be listed');
    await t.ensureVisible(card.first);
    await t.pumpAndSettle();
    await t.tap(card.first);
    await t.pumpAndSettle();
    await tapNext();
  }

  Future<void> fillOrganizationAndNext({
    required String companyName,
    required String taxId,
  }) async {
    final nameField = settingsField('Название организации');
    expect(nameField, findsOneWidget);
    await t.enterText(nameField, companyName);
    await t.pump();

    final taxField = settingsField('БИН/ИИН');
    expect(
      taxField,
      findsOneWidget,
      reason: 'Tax-id field should carry the country tax label',
    );
    await t.enterText(taxField, taxId);
    await t.pump();

    await tapNext();
  }

  Future<void> tapNext() async {
    expect(_next, findsWidgets, reason: 'A "Далее" button must be present');
    await t.ensureVisible(_next.first);
    await t.pumpAndSettle();
    await t.tap(_next.first);
    await t.pumpAndSettle();
  }

  Future<void> tapDone() async {
    expect(
      _done,
      findsOneWidget,
      reason: 'Summary must offer a "Готово" button',
    );
    await t.ensureVisible(_done);
    await t.pumpAndSettle();
    await t.tap(_done);
    await t.pumpAndSettle(const Duration(seconds: 5));
  }
}
