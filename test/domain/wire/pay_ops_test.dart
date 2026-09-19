/// Кодек пяти денежных операций оплаты — задача 14.
///
/// Проверяется не «поля переложились», а два свойства, ради которых кодек
/// вообще написан здесь, а не в `till_operations.dart`:
///
/// 1. **Деньги едут строкой, никогда числом** (I159). Сторож
///    `test/architecture/money_over_wire_test.dart` проверяет **форму
///    записи** — что под денежным ключом стоит буквальный вызов
///    `wireMoney`; здесь проверяется **результат**: в кадре лежит
///    `String`, а обратно приходит тот же `Decimal` до последнего разряда.
/// 2. **Разбирает и собирает одна и та же пара.** Второй читатель формы
///    — это расхождение, которое обнаруживается в браузере, а не в
///    прогоне.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/wire/cart_codec.dart';
import 'package:telepos/domain/wire/pay_ops.dart';

void main() {
  Decimal d(String v) => Decimal.parse(v);

  group('деньги — строкой', () {
    test('каждое денежное поле заявки уезжает строкой', () {
      final json = paymentRequestToWireJson(
        PaymentRequest(
          type: PaymentType.mixed,
          cashReceived: d('5000'),
          cardAmount: d('400.125'),
          bonusUsed: d('120'),
          claimedChange: d('9999'),
        ),
      );

      for (final key in const [
        'cashReceived',
        'cardAmount',
        'bonusUsed',
        'claimedChange',
      ]) {
        expect(json[key], isA<String>(), reason: key);
      }
    });

    test('каждое денежное поле итога уезжает строкой', () {
      final json = saleOutcomeToWireJson(
        SaleOutcome(
          receiptNo: 9,
          posId: 1,
          amount: d('1990'),
          change: d('3010'),
          paid: d('1990'),
          debt: Decimal.zero,
        ),
      );

      for (final key in const ['amount', 'change', 'paid', 'debt']) {
        expect(json[key], isA<String>(), reason: key);
      }
    });

    test('разряды не теряются на проводе', () {
      // P18,S3 — и один разряд сверх него: дверь `wireMoney` ничего не
      // округляет, и это проверено у неё самой (`wire_money_test.dart`).
      // Здесь то же свойство проверяется через настоящую пару кодека:
      // потеря разряда на деньгах — это недостача, а не мелочь.
      final request = PaymentRequest(
        type: PaymentType.cash,
        cashReceived: d('123456789012345.6789'),
      );

      final back = paymentRequestFromWireJson(
        paymentRequestToWireJson(request),
      );

      expect(back.cashReceived, d('123456789012345.6789'));
    });
  });

  group('пара разбирает то, что сама пишет', () {
    test('заявка возвращается той же', () {
      final request = PaymentRequest(
        type: PaymentType.debt,
        cashReceived: d('300'),
        cardAmount: d('0'),
        bonusUsed: d('12.5'),
        prepaymentUsed: d('600.125'),
        prepaymentReference: 'АВ-7',
        claimedChange: d('0'),
        accountId: 12,
        customerId: 5,
        customerBin: '900101300123',
        approvalCode: '123456',
        cardMask: '**** 4242',
        transactionId: 'tx-1',
      );

      final back = paymentRequestFromWireJson(
        paymentRequestToWireJson(request),
      );

      expect(back.type, PaymentType.debt);
      expect(back.cashReceived, d('300'));
      expect(back.bonusUsed, d('12.5'));
      // Зачёт аванса — задача 23. Поле, потерянное на проводе, дало бы
      // чек, который на кассе разложен иначе, чем на экране: кассир
      // видит зачёт, касса берёт всю сумму наличными.
      expect(back.prepaymentUsed, d('600.125'));
      expect(back.prepaymentReference, 'АВ-7');
      expect(back.claimedChange, d('0'));
      expect(back.accountId, 12);
      expect(back.customerId, 5);
      expect(back.customerBin, '900101300123');
      expect(back.approvalCode, '123456');
      expect(back.cardMask, '**** 4242');
      expect(back.transactionId, 'tx-1');
    });

    test('несчитанная сдача остаётся несчитанной, а не нулём', () {
      // Ноль — это сумма («сдачи нет»), `null` — «терминал её не считал».
      // Свести их в одно значило бы заставить кассу писать в журнал
      // расхождение там, где никто ничего не утверждал.
      final back = paymentRequestFromWireJson(
        paymentRequestToWireJson(PaymentRequest(type: PaymentType.cash)),
      );

      expect(back.claimedChange, isNull);
    });

    test('итог возвращается тем же', () {
      final outcome = SaleOutcome(
        receiptNo: 9,
        posId: 1,
        amount: d('1990'),
        change: d('3010'),
        paid: d('1990'),
        debt: d('0'),
        repeat: true,
      );

      final back = saleOutcomeFromWireJson(saleOutcomeToWireJson(outcome));

      expect(back.receiptNo, 9);
      expect(back.posId, 1);
      expect(back.amount, d('1990'));
      expect(back.change, d('3010'));
      expect(back.paid, d('1990'));
      expect(back.debt, d('0'));
      expect(back.repeat, isTrue);
    });

    test('счета и клиент лояльности возвращаются теми же', () {
      final accounts = accountsFromWireJson(
        accountsToWireJson(const [
          PaymentAccount(id: 11, name: 'Касса', isDefault: true),
          PaymentAccount(id: 12, name: 'Банк'),
        ]),
      );
      expect(accounts, hasLength(2));
      expect(accounts.first.isDefault, isTrue);
      expect(accounts.last.isDefault, isFalse);

      final customer = loyaltyFromWireJson(
        loyaltyToWireJson(
          LoyaltyCustomer(
            id: 5,
            phone: '77015550000',
            name: 'Айгуль',
            bonusBalance: d('340.5'),
          ),
        ),
      );
      expect(customer!.id, 5);
      expect(customer.bonusBalance, d('340.5'));
    });

    test('«клиента нет» — это ответ, а не пустой клиент', () {
      expect(loyaltyFromWireJson(loyaltyToWireJson(null)), isNull);
    });

    test('метка команды переживает круг', () {
      const meta = CartCommandMeta(key: 'k9', baseVersion: 3, receiptNo: 9);
      expect(
        cartCommandMetaFromWireJson(cartCommandMetaToWireJson(meta)),
        meta,
      );

      const cold = CartCommandMeta(key: 'k1', baseVersion: 0, receiptNo: null);
      expect(
        cartCommandMetaFromWireJson(cartCommandMetaToWireJson(cold)).receiptNo,
        isNull,
      );
    });
  });

  group('чужой ответ не выдаётся за одобрение', () {
    test('незнакомое слово исхода читается как отказ', () {
      // Три исхода, и только один из них двигает деньги. Незнакомое слово
      // значит «мы не знаем, провелась ли карта»; считать это одобрением —
      // худший из трёх выборов, `notConfigured` увёл бы кассира на ручной
      // путь, будто устройства нет.
      final charge = cardChargeFromWireJson(const {'outcome': 'ошибка'});
      expect(charge.outcome, CardChargeOutcome.declined);
    });

    test('ответ эквайринга возвращается тем же', () {
      final back = cardChargeFromWireJson(
        cardChargeToWireJson(
          CardCharge(
            outcome: CardChargeOutcome.approved,
            amount: d('1000'),
            approvalCode: '123456',
            cardMask: '**** 4242',
            transactionId: 'tx-1',
          ),
        ),
      );

      expect(back.outcome, CardChargeOutcome.approved);
      expect(back.amount, d('1000'));
      expect(back.approvalCode, '123456');
    });
  });

  group('чего в заявке больше нет', () {
    test('признак фискализации по проводу не едет — I6', () {
      // Приходил полем заявки и перебивал умолчание кассы без права и без
      // следа: браузер решал, уедет ли чек к фискальному оператору.
      // Вопрос теперь задаётся кассе (`SaleCheckoutService
      // .selectiveOfdDefault`), а поля нет вовсе — забыть его проверить
      // некому.
      final json = paymentRequestToWireJson(
        PaymentRequest(type: PaymentType.cash),
      );
      expect(json.keys, isNot(contains('selectiveOfd')));
    });

    test('отмены прежней оплаты в заявке нет — решение круга правки 1', () {
      // Отмена уже проведённой оплаты убрана целиком: у неё не было ни
      // одного производителя в `lib/`, она приносила дыру в проверке прав
      // и не возвращала ни склад WMS, ни серийники, ни ингредиенты.
      final json = paymentRequestToWireJson(
        PaymentRequest(type: PaymentType.cash),
      );
      expect(json.keys, isNot(contains('cancelPrevious')));
    });
  });

  group('вид оплаты по имени, а не по номеру', () {
    test('каждое имя узнаётся, чужое — нет', () {
      // По имени, а не по индексу: новый вид оплаты не в конец
      // перечисления не должен молча превратить чужие кадры в долг. То же
      // правило, что у `Terminals.pointMode` и `DeviceBinding.deviceClass`.
      for (final type in PaymentType.values) {
        expect(PaymentType.byWireName(type.name), type);
      }
      expect(PaymentType.byWireName('долг'), isNull);
      expect(PaymentType.byWireName(null), isNull);
      expect(PaymentType.byWireName('3'), isNull);
    });
  });
}
