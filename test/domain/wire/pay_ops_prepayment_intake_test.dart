/// Кодек `pay.prepaymentIntake` — требование заказчика 2026-09-18.
///
/// # Что здесь меряется
///
/// Не «поля переложились туда и обратно» — этого мало. Кодек провода
/// ломается тремя способами, и каждый уже случался в этом дереве:
///
/// 1. **поле не доехало вовсе.** `qrIntentKey` (задача 22) был написан,
///    прочитан кассой и не внесён в кодек ни одной половиной: оплата
///    телефоном с браузера не доезжала, а покраснеть было нечему;
/// 2. **разбор уронил `TypeError`** — и на провод уехало имя типа вместо
///    названной причины (I144);
/// 3. **умолчание соврало**. Вид оплаты, подставленный наличными, отправил
///    бы оператору чек аванса наличными на взнос картой — ровно тот дефект,
///    ради снятия которого вид приёма вообще хранится (v47).
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/payment/prepayment_intake.dart';
import 'package:telepos/domain/wire/pay_ops.dart';

void main() {
  Decimal d(String v) => Decimal.parse(v);

  group('заявка', () {
    test('доезжает до кассы теми же величинами', () {
      final body = PayOps.prepaymentIntake.encode(
        PrepaymentIntakeRequest(
          key: 'sess-1:0',
          customerId: 5,
          amount: d('1500.500'),
          tenderKindId: SystemPaymentKindIds.card,
          note: 'Аванс покупателя (Айгуль)',
        ),
      );

      // Деньги — строкой и через единственную дверь (I159).
      expect(body['amount'], isA<String>());

      final parsed = prepaymentIntakeFromWireJson(body);
      expect(parsed.customerId, 5);
      expect(parsed.amount, d('1500.5'));
      expect(parsed.tenderKindId, SystemPaymentKindIds.card);
      expect(parsed.note, 'Аванс покупателя (Айгуль)');
      // Ключ повтора — четвёртый способ сломать кодек, и он же самый
      // дорогой: кадр без ключа касса примет, а повтор опознать будет
      // нечем. До 2026-09-18 поля не было вовсе, и деньги принимались
      // дважды.
      expect(parsed.key, 'sess-1:0');
    });

    test('примечания нет — ключа в кадре нет вовсе', () {
      final body = PayOps.prepaymentIntake.encode(
        PrepaymentIntakeRequest(
          key: 'sess-1:1',
          customerId: 5,
          amount: d('1000'),
          tenderKindId: SystemPaymentKindIds.cash,
        ),
      );

      expect(body.containsKey('note'), isFalse);
      expect(prepaymentIntakeFromWireJson(body).note, isNull);
    });

    test('пустое примечание читается как «не писали»', () {
      // Пустая строка в поле, которое человек потом читает в журнале, —
      // мусор, неотличимый от намеренной пустоты.
      expect(
        prepaymentIntakeFromWireJson(const {
          'customerId': 5,
          'amount': '1000',
          'tenderKindId': 1,
          'note': '   ',
        }).note,
        isNull,
      );
    });

    test('мусор в кадре не роняет разбор, а доезжает до названного отказа', () {
      // Кадр, собранный мимо экрана. `TypeError` отсюда уехал бы на провод
      // именем типа вместо причины (I144); честный ответ даёт касса.
      final parsed = prepaymentIntakeFromWireJson(const {
        'customerId': 'пять',
        'amount': 'много',
        'tenderKindId': {'вид': 'карта'},
      });

      expect(parsed.customerId, 0, reason: 'такого покупателя нет');
      expect(parsed.amount, Decimal.zero, reason: 'ноль не положителен');
      expect(
        parsed.tenderKindId,
        0,
        reason: 'вида 0 в справочнике нет и быть не может',
      );
    });

    test('вид оплаты НЕ подставляется наличными', () {
      // Слом, который выглядел бы безобидным: касса приняла бы взнос и
      // отправила бы оператору чек наличными на взнос картой.
      expect(
        prepaymentIntakeFromWireJson(const {
          'customerId': 5,
          'amount': '1000',
        }).tenderKindId,
        isNot(SystemPaymentKindIds.cash),
      );
    });

    test('пустое тело не роняет разбор', () {
      final parsed = prepaymentIntakeFromWireJson(const {});
      expect(parsed.customerId, 0);
      expect(parsed.amount, Decimal.zero);
      expect(parsed.tenderKindId, 0);
      expect(parsed.note, isNull);
      expect(parsed.key, isEmpty, reason: 'ключ не выдумывается разбором');
    });

    test('ключ повтора едет всегда, а не «когда есть»', () {
      // Слом первого рода из докстринга файла: поле, написанное и
      // прочитанное, но не внесённое в кодировщик. Выглядит работающим на
      // кассе, где ключ до провода не доезжает вовсе, — и не защищает
      // ничего в браузере, ради которого всё и делается.
      final body = PayOps.prepaymentIntake.encode(
        PrepaymentIntakeRequest(
          key: 'sess-9:3',
          customerId: 5,
          amount: d('1000'),
          tenderKindId: SystemPaymentKindIds.cash,
        ),
      );

      expect(body['key'], 'sess-9:3');
    });

    test('ключа в кадре нет — разбор НЕ выдумывает его', () {
      // Самый опасный из мыслимых сломов этого кодека, и потому у него
      // своя проба. Ключ, выданный разбором (метка времени, случайное
      // число, хэш тела), у каждого кадра получился бы свой: повторы
      // перестали бы опознаваться **все до одного**, а таблица
      // `prepayment_intakes` заполнялась бы и создавала видимость защиты.
      //
      // Пустая строка означает «ключа не было», и касса отказывает
      // названной причиной до первой записи.
      for (final body in const <Map<String, Object?>>[
        {'customerId': 5, 'amount': '1000', 'tenderKindId': 1},
        {'customerId': 5, 'amount': '1000', 'tenderKindId': 1, 'key': '   '},
        {'customerId': 5, 'amount': '1000', 'tenderKindId': 1, 'key': 17},
      ]) {
        expect(
          prepaymentIntakeFromWireJson(body).key,
          isEmpty,
          reason: 'кадр $body не имеет ключа, и выдумывать его нечем',
        );
      }
    });
  });

  group('исход', () {
    test('сальдо и фискальный признак переживают провод', () {
      final frame = prepaymentIntakeOutcomeToWireJson(
        PrepaymentIntakeOutcome(
          operationId: 42,
          balance: d('700.250'),
          fiscalSign: 'ФП-7',
        ),
      );

      expect(frame['balance'], isA<String>());
      final parsed = prepaymentIntakeOutcomeFromWireJson(frame);
      expect(parsed.operationId, 42);
      expect(parsed.balance, d('700.25'));
      expect(parsed.fiscalSign, 'ФП-7');
      expect(parsed.fiscalError, isNull);
    });

    test('чека не было — ключей фискализации в кадре нет', () {
      final frame = prepaymentIntakeOutcomeToWireJson(
        PrepaymentIntakeOutcome(operationId: 1, balance: d('100')),
      );

      expect(frame.containsKey('fiscalSign'), isFalse);
      expect(frame.containsKey('fiscalError'), isFalse);
    });

    test('отказ оператора едет словом и денег не отменяет', () {
      final parsed = prepaymentIntakeOutcomeFromWireJson(
        prepaymentIntakeOutcomeToWireJson(
          PrepaymentIntakeOutcome(
            operationId: 1,
            balance: d('100'),
            fiscalError: 'network',
          ),
        ),
      );

      expect(parsed.fiscalError, 'network');
      expect(parsed.balance, d('100'), reason: 'деньги приняты');
    });

    test('усечённый ответ не роняет вкладку', () {
      final parsed = prepaymentIntakeOutcomeFromWireJson(const {});
      expect(parsed.operationId, 0);
      expect(parsed.balance, Decimal.zero);
    });
  });

  test('операция объявлена вопросом и состоит в каталоге', () {
    expect(PayOps.all, contains(PayOps.prepaymentIntake));
    expect(PayOps.prepaymentIntake.name, 'pay.prepaymentIntake');
  });
}
