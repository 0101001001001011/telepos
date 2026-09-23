/// Потолок суммы чека — настройка кассы, а не число в коде.
///
/// # Что измерено 2026-09-22
///
/// `LocalSaleCheckoutService` сравнивал итог чека с `Decimal.parse('1000000')`,
/// зашитым в коде, а отказ говорил «превышает 1 млн ₸» — на кассе любой
/// страны. Миллион тенге — около двух тысяч долларов; на американской кассе
/// тот же миллион оказывался в пятьсот раз выше, то есть защиты не было
/// вовсе, а текст отказа при этом называл чужую валюту.
///
/// Нашлось сторожем словаря (`dictionary_has_no_currency_test`): он ищет
/// знаки валют в текстах, а нашёл зашитое бизнес-правило.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/sale/big_amount_limit.dart';

void main() {
  test('не задано — прежнее зашитое число', () {
    // Касса, работавшая вчера, обязана работать сегодня так же: обновление
    // не имеет права начать отказывать на других суммах молча.
    expect(bigAmountLimitOf(null), kDefaultBigAmountLimit);
    expect(bigAmountLimitOf(''), kDefaultBigAmountLimit);
    expect(bigAmountLimitOf('   '), kDefaultBigAmountLimit);
    expect(kDefaultBigAmountLimit, Decimal.parse('1000000'));
  });

  test('задано — берётся настройка', () {
    expect(bigAmountLimitOf('2000'), Decimal.parse('2000'));
    expect(bigAmountLimitOf(' 1500.50 '), Decimal.parse('1500.50'));
  });

  test('опечатка в настройке не снимает защиту', () {
    // Соблазнительный вариант — «не разобрали, значит предела нет» — снял бы
    // защиту молча: владелец, опечатавшийся в поле, узнал бы об этом по
    // чеку на миллион, а не по отказу.
    expect(bigAmountLimitOf('очень много'), kDefaultBigAmountLimit);
    expect(bigAmountLimitOf('1 000 000'), kDefaultBigAmountLimit);
  });

  test('ноль — это ноль, а не «не задано»', () {
    // Нулевой потолок означает «спрашивать разрешения всегда», и это
    // законная настройка. Свести её к умолчанию значило бы тихо не
    // выполнить прямое указание владельца.
    expect(bigAmountLimitOf('0'), Decimal.zero);
  });
}
