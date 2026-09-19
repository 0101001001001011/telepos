/// Кодек оплаты по QR и фаза глазами кассира.
///
/// Кодек проверяется **перечнем ключей**, а не круговой поездкой одних
/// лишь известных полей: круговая поездка зелена и у кадра, в который
/// кто-то положил адрес провайдера рядом, — известные поля переложились, а
/// лишнее просто не проверяли.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/payment/payment_intent.dart';
import 'package:telepos/domain/payment/qr_tender.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/wire/pay_ops.dart';

void main() {
  Decimal d(String v) => Decimal.parse(v);

  group('кадр ответа', () {
    const allowed = {
      'intentKey',
      'phase',
      'amount',
      'paidAmount',
      'qrPayload',
      'receiptNo',
      'secondsLeft',
      'settledReceiptNo',
      'refusalCode',
    };

    test('все поля едут и возвращаются, и ни одного сверх перечня', () {
      final tender = QrTender(
        intentKey: 'qr-1-7-9-1000-a1',
        phase: QrTenderPhase.paid,
        amount: d('1000.005'),
        paidAmount: d('999.995'),
        qrPayload: 'https://pay/q',
        receiptNo: 9,
        secondsLeft: 12,
        settledReceiptNo: 9,
        refusalCode: 'qr_network',
      );
      final json = qrTenderToWireJson(tender);

      expect(json.keys.toSet().difference(allowed), isEmpty);
      expect(json['amount'], '1000.005', reason: 'деньги строкой (I159)');

      final back = qrTenderFromWireJson(json);
      expect(back.intentKey, tender.intentKey);
      expect(back.phase, QrTenderPhase.paid);
      expect(back.amount, d('1000.005'));
      expect(back.paidAmount, d('999.995'));
      expect(back.qrPayload, 'https://pay/q');
      expect(back.receiptNo, 9);
      expect(back.secondsLeft, 12);
      expect(back.settledReceiptNo, 9);
      expect(back.refusalCode, 'qr_network');
      expect(back.usable, isFalse, reason: 'деньги уже в чеке 9');
    });

    test('незнакомая фаза — «не знаем», а не «ждём» и не «отказ»', () {
      final back = qrTenderFromWireJson({
        'intentKey': 'k',
        'phase': 'teleported',
        'amount': '10',
      });
      expect(back.phase, QrTenderPhase.cancelUnconfirmed);
      expect(back.phase.blocksCompletion, isTrue);
    });
  });

  group('кадр запроса', () {
    test('qrStart: сумма строкой и метка попытки, рабочего места нет', () {
      final body = PayOps.qrStart.encode((
        amount: d('1000.5'),
        meta: const CartCommandMeta(key: 'a1', baseVersion: 3, receiptNo: 9),
      ));
      expect(body['amount'], '1000.5');
      expect(body['key'], 'a1');
      expect(body['receiptNo'], 9);
      expect(body.keys.where((k) => k.toLowerCase().contains('terminal')),
          isEmpty);
    });

    test('qrPoll и qrCancel — только ключ; не-строка разбирается пустой', () {
      expect(PayOps.qrPoll.encode('k1'), {'intentKey': 'k1'});
      expect(PayOps.qrCancel.encode('k1'), {'intentKey': 'k1'});
      expect(qrIntentKeyFromWireJson({'intentKey': 42}), '');
    });
  });

  group('фаза из полей намерения', () {
    final created = DateTime(2026, 9, 13, 12);
    const patience = Duration(minutes: 3);

    PaymentIntent intent(
      QrIntentStatus status, {
      DateTime? abandonedAt,
    }) => PaymentIntent(
      id: 1,
      intentKey: 'k',
      providerCode: 'p',
      amount: d('100'),
      status: status,
      createdAt: created,
      abandonedAt: abandonedAt,
    );

    test('ожидание и неподтверждённая отмена различаются отметкой', () {
      expect(
        QrTenderPhase.of(intent(QrIntentStatus.pending), patience),
        QrTenderPhase.waiting,
      );
      expect(
        QrTenderPhase.of(
          intent(QrIntentStatus.pending, abandonedAt: created),
          patience,
        ),
        QrTenderPhase.cancelUnconfirmed,
      );
    });

    test('кассир или терпение — по времени отметки, граница включительно', () {
      expect(
        QrTenderPhase.of(
          intent(
            QrIntentStatus.cancelled,
            abandonedAt: created.add(const Duration(seconds: 179)),
          ),
          patience,
        ),
        QrTenderPhase.cashierCancelled,
      );
      expect(
        QrTenderPhase.of(
          intent(QrIntentStatus.cancelled, abandonedAt: created.add(patience)),
          patience,
        ),
        QrTenderPhase.patienceSpent,
      );
    });

    test('оплата после сдачи и отмена провайдером без нашего решения', () {
      expect(
        QrTenderPhase.of(
          intent(QrIntentStatus.paid, abandonedAt: created),
          patience,
        ),
        QrTenderPhase.paidAfterGiveUp,
      );
      expect(
        QrTenderPhase.of(intent(QrIntentStatus.cancelled), patience),
        QrTenderPhase.failed,
      );
    });

    test('код показывается только в ожидании, секунды не уходят в минус', () {
      final waiting = QrTender.of(
        intent(QrIntentStatus.pending).copyWith(qrPayload: 'https://pay/q'),
        patience: patience,
        now: created.add(const Duration(minutes: 5)),
      );
      expect(waiting.qrPayload, 'https://pay/q');
      expect(waiting.secondsLeft, 0);

      final paid = QrTender.of(
        intent(QrIntentStatus.paid).copyWith(qrPayload: 'https://pay/q'),
        patience: patience,
        now: created,
      );
      expect(paid.qrPayload, isNull);
      expect(paid.secondsLeft, isNull);
    });
  });
}
