library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class InventoryPage {
  InventoryPage(this.t);
  final WidgetTester t;

  static const startLabel = 'Начать';
  static const finishLabel = 'Завершить';
  static const scanHint = 'Сканируйте штрихкод';
  static const pressStartHint = 'Нажмите "Начать" для инвентаризации';
  static const scanProductsHint = 'Сканируйте товары для подсчёта';
  static const completedSnack = 'Инвентаризация завершена';

  static const fullCountLabel = 'Полная инвентаризация';

  Finder get scanField => find.byType(TextField);
  Finder get startButton => find.widgetWithText(TextButton, startLabel);
  Finder get finishButton => find.widgetWithText(TextButton, finishLabel);

  Finder get fullCountToggle => find.byType(SwitchListTile);

  Future<void> enableFullCount() async {
    expect(
      fullCountToggle,
      findsOneWidget,
      reason: 'inactive inventory must offer a full/partial mode toggle',
    );
    await t.tap(fullCountToggle);
    await t.pumpAndSettle();
  }

  bool get isInactiveEmptyState =>
      find.text(pressStartHint).evaluate().isNotEmpty;

  bool get isActive => find.text(scanHint).evaluate().isNotEmpty;

  Future<void> start() async {
    expect(
      startButton,
      findsOneWidget,
      reason: 'inactive inventory must offer a "Начать" action',
    );
    await t.tap(startButton);
    await t.pumpAndSettle();
  }

  Future<void> scan(String barcode) async {
    expect(
      scanField,
      findsWidgets,
      reason: 'active inventory must show a scan field',
    );
    await t.enterText(scanField.first, barcode);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
  }

  Future<void> complete() async {
    await t.tap(finishButton);
    await t.pumpAndSettle();
    final dialogConfirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(ElevatedButton, finishLabel),
    );
    expect(
      dialogConfirm,
      findsOneWidget,
      reason: 'completing must ask for confirmation',
    );
    await t.tap(dialogConfirm);
    await t.pumpAndSettle();
  }

  void expectProductVisible(String name) =>
      expect(find.text(name), findsOneWidget);

  void expectDifference(String diff) => expect(
    find.text(diff),
    findsWidgets,
    reason: 'difference $diff should render',
  );
}
