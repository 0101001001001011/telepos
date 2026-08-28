library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/telepos_icons.dart';

class CatalogPage {
  CatalogPage(this.t);
  final WidgetTester t;

  static const title = 'Каталог товаров';
  static const addProductBtn = 'Добавить товар';
  static const categoriesBtn = 'Категории';
  static const searchHint = 'Название или штрихкод';
  static const noProducts = 'Нет товаров';
  static const save = 'Сохранить';
  static const cancel = 'Отмена';
  static const delete = 'Удалить';

  static const nameLabel = 'Название';
  static const priceLabel = 'Цена продажи';
  static const nameRequired = 'Введите название';
  static const priceRequired = 'Введите цену';
  static const priceInvalid = 'Цена должна быть больше 0';

  static const productCreated = 'Товар создан';
  static const productUpdated = 'Товар обновлён';
  static const productDeleted = 'Товар удалён';
  static const productRestored = 'Товар восстановлен';

  static const manageCategories = 'Управление категориями';
  static const addCategory = 'Добавить категорию';
  static const categoryName = 'Название категории';

  Future<void> settle([int frames = 12]) async {
    for (int i = 0; i < frames; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
  }

  Finder buttonByText(String text, {Finder? within}) {
    final label = within == null
        ? find.text(text)
        : find.descendant(of: within, matching: find.text(text));
    return find.ancestor(
      of: label,
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
  }

  bool get isEmptyState => find.text(noProducts).evaluate().isNotEmpty;

  Finder get searchField =>
      find.widgetWithText(TextField, searchHint).hitTestable();

  Future<void> search(String query) async {
    final field = find.widgetWithText(TextField, searchHint);
    expect(field, findsWidgets, reason: 'search field must be present');
    await t.enterText(field.first, query);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await settle();
  }

  Future<void> clearSearch() async {
    final clearBtn = find.descendant(
      of: find.byType(TextField),
      matching: find.byIcon(TeleposIcons.close),
    );
    if (clearBtn.evaluate().isNotEmpty) {
      await t.tap(clearBtn.first);
      await settle();
    }
  }

  Future<void> openCreate() async {
    final btn = buttonByText(addProductBtn);
    expect(btn, findsWidgets, reason: '"$addProductBtn" header button missing');
    await t.tap(btn.first);
    await settle();
    expect(
      find.byType(AlertDialog),
      findsOneWidget,
      reason: 'create dialog must open',
    );
  }

  Future<void> enterName(String name) async {
    final f = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextFormField, nameLabel),
    );
    expect(f, findsOneWidget, reason: 'name field must be present in form');
    await t.enterText(f, name);
    await t.pump();
  }

  Future<void> enterPrice(String price) async {
    final f = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextFormField, priceLabel),
    );
    expect(f, findsOneWidget, reason: 'price field must be present in form');
    await t.enterText(f, price);
    await t.pump();
  }

  Future<void> submitForm() async {
    final btn = buttonByText(save, within: find.byType(AlertDialog));
    expect(btn, findsWidgets, reason: 'form Save button must exist');
    await t.tap(btn.first);
    await settle();
  }

  Future<void> cancelForm() async {
    final btn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextButton, cancel),
    );
    await t.tap(btn.first);
    await settle();
  }

  Future<void> createProduct({
    required String name,
    required String price,
  }) async {
    await openCreate();
    await enterName(name);
    await enterPrice(price);
    await submitForm();
  }

  bool productVisible(String name) => find.text(name).evaluate().isNotEmpty;

  Future<void> openEdit(String name) async {
    final cell = find.text(name);
    expect(cell, findsWidgets, reason: 'product "$name" must be in the table');
    await t.tap(cell.first);
    await settle();
    expect(
      find.byType(AlertDialog),
      findsOneWidget,
      reason: 'edit dialog must open on name tap',
    );
  }

  Future<void> deleteProduct(String name) async {
    final delBtn = find.widgetWithIcon(IconButton, TeleposIcons.delete);
    expect(
      delBtn,
      findsWidgets,
      reason: 'a delete action must be present for active products',
    );
    await t.tap(delBtn.first);
    await settle();
    final confirm = buttonByText(delete, within: find.byType(AlertDialog));
    expect(confirm, findsWidgets, reason: 'delete must ask for confirmation');
    await t.tap(confirm.first);
    await settle();
  }

  Future<void> restoreProduct(String name) async {
    final btn = find.widgetWithIcon(IconButton, Icons.restore);
    expect(
      btn,
      findsWidgets,
      reason: 'a restore action must be present for deleted products',
    );
    await t.tap(btn.first);
    await settle();
  }

  Future<bool> toggleShowDeleted() async {
    final chip = find.byWidgetPredicate(
      (w) =>
          (w is FilterChip &&
              w.label is Text &&
              ((w.label as Text).data?.toLowerCase().contains('удал') ??
                  false)) ||
          (w is CheckboxListTile &&
              w.title is Text &&
              ((w.title as Text).data?.toLowerCase().contains('удал') ??
                  false)),
    );
    if (chip.evaluate().isEmpty) return false;
    await t.ensureVisible(chip.first);
    await t.pump();
    await t.tap(chip.first, warnIfMissed: false);
    await settle();
    return true;
  }

  Future<void> openCategoryEditor() async {
    final btn = buttonByText(categoriesBtn);
    expect(btn, findsWidgets, reason: '"$categoriesBtn" header button missing');
    await t.tap(btn.first);
    await settle();
    expect(
      find.text(manageCategories),
      findsOneWidget,
      reason: 'category editor must open',
    );
  }

  Future<void> addCategoryInEditor(String name) async {
    final addBtn = buttonByText(addCategory);
    expect(addBtn, findsWidgets, reason: 'add-category button missing');
    await t.tap(addBtn.first);
    await settle();

    final nameField = find.widgetWithText(TextField, categoryName);
    expect(nameField, findsWidgets, reason: 'category name field missing');
    await t.enterText(nameField.first, name);
    await t.pump();

    final saveBtn = buttonByText(save);
    expect(saveBtn, findsWidgets, reason: 'category save button missing');
    await t.tap(saveBtn.last);
    await settle();
  }

  Future<void> closeCategoryEditor() async {
    final close = find.descendant(
      of: find.byType(Dialog),
      matching: find.byIcon(TeleposIcons.close),
    );
    if (close.evaluate().isNotEmpty) {
      await t.tap(close.first);
      await settle();
    }
  }
}
