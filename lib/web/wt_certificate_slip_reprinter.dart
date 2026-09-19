import 'package:telepos/domain/payment/certificate_slip_printer.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/wire/pay_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';

/// Повтор печати слипа — по проводу. Вторая реализация
/// [CertificateSlipReprinter], решение заказчика 2026-09-18.
///
/// # Печатает **касса**, и это не уступка, а устройство
///
/// Принтер стоит у кассы; у вкладки его нет и быть не может. Так же устроена
/// продажа: чек печатает касса по команде терминала, а не браузер. Разница
/// только в том, что печать чека прицеплена к оплате, а слип просят
/// отдельно.
///
/// # Кадр несёт номер и ПИН, и больше ничего
///
/// Ни полей сертификата, ни кассира. Поля нашла бы вкладка — и напечатала бы
/// обязательство магазина на выдуманную сумму; кассира касса знает из
/// сеанса. Разбор — в докстринге [CertificateSlipReprinter].
///
/// `userId` довода здесь принимается и **не кладётся в кадр** по тому же
/// правилу, по которому его не кладёт `WtCertificateIssuer.issue`: значение,
/// названное вкладкой, значением сеанса не является.
///
/// # Отказ доезжает кодом и становится `WireRefusal`
///
/// Тем же приёмом, что у соседей (`WtCertificateIssuer`,
/// `WtPrepaymentIntakeService`): кассовая реализация того же контракта
/// бросает [WireRefusal], и договор обязан быть один на обе — экран у них
/// общий.
class WtCertificateSlipReprinter implements CertificateSlipReprinter {
  const WtCertificateSlipReprinter(this._wire);

  final WtDispatcher _wire;

  @override
  Future<GiftCertificate> reprint({
    required String number,
    String? pin,
    int? userId,
  }) async {
    try {
      return await _wire.ask(PayOps.certificateSlip, (
        number: number,
        pin: pin,
      ));
    } on WtProtocolError catch (error) {
      throw WireRefusal(error.code, error.detail);
    }
  }
}
