import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Строки про разрешения рабочего места переведены во всех пяти словарях.
///
/// Заведён по образцу `refund_keys_test.dart` и по той же измеренной
/// причине: ключ, добавленный только в русский, набор не красит — строка
/// **есть**, она просто русская. Для кассира на казахском это ровно то же,
/// что отсутствующий ключ, и заметить это можно только глазами.
///
/// Здесь цена ошибки выше обычной: эти две строки — единственное, чем экран
/// объясняет кассиру, почему кнопка погашена. Непереведённая строка вернула
/// бы задачу в исходное состояние («кнопка не работает, и непонятно
/// почему») для четырёх языков из пяти.
///
/// Предел тот же, что у соседа: сторож ловит «не тронуто», а не качество
/// перевода. Проверять качество нечем, и притворяться, что можно, было бы
/// хуже отсутствия сторожа.
const _keys = [
  // Причина, которую кассир видит по нажатию на погашенную кнопку.
  'paymentTypeNotAllowedHere',
  // Постоянная подпись под рядом кнопок: что рабочее место принимает.
  'paymentTypesLimitedHere',
  // Три причины, по которым погашена кнопка «В долг» (задача 16). Их
  // именно три, а не одна: тумблер меняется в настройках кассы, право —
  // у администратора, а молчание кассы не лечится ни тем, ни другим.
  // Непереведённая строка здесь стоит дороже обычной — она единственное,
  // что отличает три разных действия кассира друг от друга.
  'paymentDebtNotSoldHere',
  'paymentDebtNotPermitted',
  'paymentDebtPolicyUnknown',
];

const _locales = ['en', 'ru', 'kk', 'ky', 'uz'];

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(File('assets/i18n/intl_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('разбор словарей что-то нашёл', () {
    // Без этого проверки ниже зелены на пустых картах.
    for (final locale in _locales) {
      expect(
        _arb(locale).length,
        greaterThan(1000),
        reason: 'словарь $locale разобран не был',
      );
    }
  });

  for (final locale in _locales) {
    test('в $locale есть строки про виды оплаты места и они не пустые', () {
      final map = _arb(locale);
      for (final key in _keys) {
        expect(map.containsKey(key), isTrue, reason: '$locale: нет $key');
        expect(
          (map[key] as String).trim(),
          isNotEmpty,
          reason: '$locale: $key пуст',
        );
      }
    });
  }

  for (final locale in _locales.where((l) => l != 'ru')) {
    test('в $locale строки не остались копией русской', () {
      final ru = _arb('ru');
      final map = _arb(locale);
      for (final key in _keys) {
        expect(
          map[key],
          isNot(equals(ru[key])),
          reason: '$locale: $key — копия русской строки',
        );
      }
    });
  }

  test('подстановки на месте во всех словарях', () {
    // Потерянная подстановка — не косметика: без `{type}` кассир прочитает
    // «не разрешена этому рабочему месту» и не узнает, что именно.
    const required = {
      'paymentTypeNotAllowedHere': '{type}',
      'paymentTypesLimitedHere': '{types}',
    };
    for (final locale in _locales) {
      final map = _arb(locale);
      required.forEach((key, placeholder) {
        expect(
          map[key] as String,
          contains(placeholder),
          reason: '$locale: в $key потеряна подстановка $placeholder',
        );
      });
    }
  });
}
