/// Рассрочка на проводе — **поля доезжают, и право спрашивается**.
///
/// # Зачем отдельный сторож
///
/// Потому что образец, лежащий рядом, копировать было нельзя: задача 22
/// завела `PaymentRequest.qrIntentKey`, кассовая раскладка его читает — а
/// в кодек провода он **не попал ни одной строкой**.
///
/// Проба ниже утверждает обратное для рассрочки: то, что положил
/// кодировщик, разбор возвращает обратно тем же значением. Проверено
/// диверсией — снятая строка `installmentTermMonths` в кодировщике красит
/// первый же случай.
///
/// # Чем это кончилось, и почему сторож остался частным
///
/// `qrIntentKey` внесён в обе половины кодека 2026-09-08. Но сам этот
/// сторож дыру найти **не мог и не может**: он назван по своим двум
/// полям, а частный сторож молчит ровно о том поле, которого в нём не
/// назвали. Общий завёлся отдельно —
/// `pay_ops_request_roundtrip_test.dart`: он не держит списка полей, а
/// читает объявления класса из исходника и требует ключ в кадре на
/// каждое. Измерено диверсией: снятая строка `qrIntentKey` в кодировщике
/// красит общий сторож и **оставляет этот зелёным целиком**.
///
/// Этот оставлен потому, что проверяет сверх круговой поездки то, чего
/// общий не знает: право по телу кадра и порядок членов `PaymentType`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/domain/payment/installment_scheduler.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/wire/pay_ops.dart';

void main() {
  group('срок и схема доезжают до кассы', () {
    test('туда и обратно тем же значением', () {
      final request = PaymentRequest(
        type: PaymentType.installment,
        customerId: 5,
        installmentTermMonths: 12,
        installmentScheme: InstallmentScheme.differentiated.code,
      );

      final json = paymentRequestToWireJson(request);
      expect(json['installmentTermMonths'], 12);
      expect(json['installmentScheme'], 'differentiated');

      final back = paymentRequestFromWireJson(json);
      expect(back.type, PaymentType.installment);
      expect(back.installmentTermMonths, 12);
      expect(back.installmentScheme, 'differentiated');
    });

    test('без рассрочки ключей в кадре нет вовсе', () {
      // Два лишних `null` в самом частом кадре провода ничего не значат, и
      // разбор читает их отсутствие как «рассрочки нет».
      final json = paymentRequestToWireJson(
        PaymentRequest(type: PaymentType.cash),
      );
      expect(json.containsKey('installmentTermMonths'), isFalse);
      expect(json.containsKey('installmentScheme'), isFalse);

      final back = paymentRequestFromWireJson(json);
      expect(back.installmentTermMonths, isNull);
      expect(back.installmentScheme, isNull);
    });

    test('нечисловой срок читается как «не назван», а не роняет разбор', () {
      // `TypeError` из кодека уехал бы на провод именем типа вместо
      // названной причины (I144). `null` доедет до кассы и получит
      // `credit_term_invalid`.
      final back = paymentRequestFromWireJson(<String, Object?>{
        'type': 'installment',
        'installmentTermMonths': '12',
        'installmentScheme': 'equalInstalments',
      });
      expect(back.installmentTermMonths, isNull);
      expect(back.type, PaymentType.installment);
    });

    test('каждая схема переживает провод', () {
      for (final scheme in InstallmentScheme.values) {
        final json = paymentRequestToWireJson(
          PaymentRequest(
            type: PaymentType.installment,
            installmentTermMonths: 3,
            installmentScheme: scheme.code,
          ),
        );
        expect(
          InstallmentScheme.byCode(
            paymentRequestFromWireJson(json).installmentScheme,
          ),
          scheme,
        );
      }
    });
  });

  group('право спрашивается по телу кадра', () {
    test('рассрочка требует op.sellDebt — то же право, что долг', () {
      expect(payExtraPermissions(<String, Object?>{'type': 'installment'}), {
        PermissionKeys.opSellDebt,
      });
      expect(payExtraPermissions(<String, Object?>{'type': 'debt'}), {
        PermissionKeys.opSellDebt,
      });
    });

    test('КОНТРОЛЬНЫЙ МАРКЕР: наличные права сверх navSale не требуют', () {
      // Без него зелёные утверждения выше означали бы «функция всегда
      // возвращает opSellDebt», а не «возвращает его на кредитных видах».
      expect(payExtraPermissions(<String, Object?>{'type': 'cash'}), isEmpty);
      expect(payExtraPermissions(<String, Object?>{'type': 'card'}), isEmpty);
      expect(payExtraPermissions(<String, Object?>{'type': 'mixed'}), isEmpty);
    });
  });

  test('имя вида на проводе разбирается обратно в член перечисления', () {
    // `PaymentType.installment` дописан **в конец** `values`: порядок
    // уезжает на диск (`Terminals.allowedPaymentTypes`), и вставка в
    // середину переназначила бы уже разрешённые рабочим местам виды.
    expect(PaymentType.values.last, PaymentType.installment);
    for (final type in PaymentType.values) {
      expect(PaymentType.byWireName(type.name), type);
    }
  });
}
