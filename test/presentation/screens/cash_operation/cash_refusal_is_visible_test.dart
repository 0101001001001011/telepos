/// Отказ кассовой операции виден кассиру.
///
/// # Что измерено 2026-09-22
///
/// Экран кассовых операций при `result.success == false` делал ровно то же,
/// что при удаче: `_close(result)`. Кассир видел закрывшееся окно и был
/// уверен, что деньги внесены.
///
/// Отказ при этом существовал: `validateAmount` сравнивал сумму с потолком
/// и возвращал фразу — по-русски, собранную в слое данных. Показать её было
/// некому.
///
/// Сумма выше потолка исчезала молча. Это деньги, а не вёрстка.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/domain/sale/big_amount_limit.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/cash_operation/cash_operation_screen.dart';

void main() {
  late AppLocalizations ru;
  late AppLocalizations en;

  setUpAll(() {
    ru = lookupAppLocalizations(const Locale('ru'));
    en = lookupAppLocalizations(const Locale('en'));
  });

  test('отказ по нулевой сумме называется словами', () {
    final result = CashOperationResult.refused(CashAmountRefusal.notPositive);
    expect(result.success, isFalse);
    expect(cashRefusalText(ru, result), ru.cashRefusedNotPositive);
    expect(cashRefusalText(en, result), en.cashRefusedNotPositive);
    expect(cashRefusalText(en, result), isNot(contains('Сумма')));
  });

  test('отказ по потолку называет САМ потолок, и с валютой', () {
    // Без числа отказ бесполезен: кассир узнаёт, что нельзя, и не узнаёт,
    // на сколько нельзя.
    final result = CashOperationResult.refused(
      CashAmountRefusal.aboveCeiling,
      limit: r'2000 $',
    );
    final text = cashRefusalText(en, result);
    expect(text, contains('2000'));
    expect(text, contains(r'$'));
    expect(text, isNot(contains('₸')));
  });

  test('отказ без кода не теряется', () {
    // Сбой не про сумму — тоже отказ, и он обязан быть видимым, а не
    // молчаливым закрытием окна.
    final result = CashOperationResult.failed('disk full');
    expect(result.success, isFalse);
    expect(cashRefusalText(en, result), contains('disk full'));
  });

  test('удача отказом не считается', () {
    final ok = CashOperationResult.created(7);
    expect(ok.success, isTrue);
    expect(ok.refusal, isNull);
    expect(ok.operationId, 7);
  });

  test('потолок кассовой операции — тот же, что у чека', () {
    // Здесь жил ВТОРОЙ потолок, зашитый тем же миллионом, и ещё «миллиард»
    // при разрешении на крупные суммы. Два числа для одного правила
    // разошлись бы на первой же правке одного из них.
    expect(bigAmountLimitOf(null), kDefaultBigAmountLimit);
    expect(bigAmountLimitOf('2000'), Decimal.parse('2000'));
  });
}
