import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// У всех пяти словарей один и тот же набор ключей — задача 38.
///
/// Гейт `flutter gen-l10n` (и `flutter build web`, который его зовёт) говорит
/// о недостающем ключе **предупреждением, а не отказом**: ключ, которого нет в
/// `intl_kk.arb`, молча берётся из шаблона, и казахский кассир читает
/// русскую строку. Так 57 ключей отсутствовали в kk/ky/uz и не менялись
/// между слияниями — долг, который никто не видел, потому что сборка зелёная.
///
/// Метаданные (`@key`, `@@locale`) не сравниваются: у нешаблонных словарей
/// они необязательны.
void main() {
  const locales = ['ru', 'en', 'kk', 'ky', 'uz'];

  Set<String> keysOf(String locale) {
    final json =
        jsonDecode(File('assets/i18n/intl_$locale.arb').readAsStringSync())
            as Map<String, dynamic>;
    return json.keys.where((k) => !k.startsWith('@')).toSet();
  }

  test('каждый словарь несёт ровно ключи шаблона', () {
    final template = keysOf('ru');
    expect(template, isNotEmpty, reason: 'предпосылка: шаблон прочитан');

    final gaps = <String, List<String>>{};
    for (final locale in locales.skip(1)) {
      final keys = keysOf(locale);
      final missing = template.difference(keys).toList()..sort();
      final extra = keys.difference(template).toList()..sort();
      if (missing.isNotEmpty) gaps['$locale: нет'] = missing;
      if (extra.isNotEmpty) gaps['$locale: лишние'] = extra;
    }

    expect(
      gaps,
      isEmpty,
      reason:
          'недостающий ключ сборка заменяет русской строкой шаблона молча; '
          'лишний — строка, которую никто не покажет',
    );
  });
}
