import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _required = [
  'setupSectionOrganization',
  'setupSectionContact',
  'setupSectionAddress',
  'setupSectionCashBox',
  'setupSectionUsers',
  'setupSectionSecurity',
  'setupSectionScanner',
  'setupSectionScale',
  'setupSectionDisplay',
  'setupSectionTerminal',
  'setupSectionCashback',
];

const _locales = ['en', 'ru', 'kk', 'ky', 'uz'];

Map<String, dynamic> _arb(String locale) {
  return jsonDecode(File('assets/i18n/intl_$locale.arb').readAsStringSync())
      as Map<String, dynamic>;
}

void main() {
  for (final locale in _locales) {
    test('в $locale есть все заголовки секций и они не пустые', () {
      final map = _arb(locale);

      for (final key in _required) {
        expect(map.containsKey(key), isTrue, reason: '$locale: нет $key');
        expect(
          (map[key] as String).trim(),
          isNotEmpty,
          reason: '$locale: $key пустой',
        );
      }
    });
  }

  test('заголовок секции не остался непереведённым русским', () {
    // Пропущенный перевод обычно выглядит как копия русской строки, и
    // проверка «ключ есть, строка не пустая» его пропускает: строка есть.
    final ru = _arb('ru');
    for (final locale in ['en', 'uz']) {
      final map = _arb(locale);
      for (final key in _required) {
        expect(
          map[key],
          isNot(ru[key]),
          reason: '$locale: $key совпадает с русским — перевода нет',
        );
      }
    }
  });

  test('ключи удалённых шагов авторизации не вернулись', () {
    for (final locale in _locales) {
      final map = _arb(locale);
      final leftovers = map.keys.where(
        (k) =>
            RegExp(r'^setup(Auth|Register|Verify|Login|OrgSelect)').hasMatch(k),
      );
      expect(leftovers, isEmpty, reason: '$locale: $leftovers');
    }
  });
}
