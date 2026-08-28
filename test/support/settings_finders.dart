import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_field_tile.dart';

/// Поле ввода строки настроек, найденное по её подписи.
///
/// `find.widgetWithText(TextField, 'Название организации')` больше не работает
/// и работать не должно: подпись переехала из `InputDecoration.labelText`
/// внутрь строки секции и стала отдельным виджетом рядом с полем. Это и есть
/// та перемена, ради которой всё делалось — рамка и плавающая подпись Material
/// исчезли, — поэтому искать надо от подписи к её строке, а от строки к полю.
Finder settingsField(String label) {
  return find.descendant(
    of: find.ancestor(
      of: find.text(label),
      matching: find.byType(SettingsFieldTile),
    ),
    matching: find.byType(TextField),
  );
}
