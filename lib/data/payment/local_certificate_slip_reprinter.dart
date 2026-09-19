import 'package:telepos/domain/payment/certificate_issuer.dart';
import 'package:telepos/domain/payment/certificate_slip_printer.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';

/// Повтор печати слипа на самой кассе — решение заказчика 2026-09-18.
///
/// # Почему два шага съехали из экрана сюда
///
/// До этой работы «найти бумажку и напечатать её слип» делал **экран**
/// (`CertificateIssueScreen._reprint`): он резолвил [CertificateIssuer], звал
/// `lookup`, потом резолвил [CertificateSlipPrinter] и звал `printIssued`.
/// Пока экран был один, это выглядело безобидно. С появлением планшета
/// повторить связку во вкладке значило бы либо дать ей печатать по своим
/// полям (слип с выдуманным номиналом — подделка), либо завести **вторую**
/// пару шагов, расходящуюся с первой при первой же правке.
///
/// Поэтому связка стала портом с двумя реализациями: эта — кассовая, вторая
/// — провод (`WtCertificateSlipReprinter`). Экран у обеих один.
///
/// # Порядок не случаен
///
/// Сначала `lookup` (он же проверяет ПИН и срок), и только потом печать:
/// слип бумажки, которой нет или чей ПИН не подошёл, печатать не для кого.
class LocalCertificateSlipReprinter implements CertificateSlipReprinter {
  const LocalCertificateSlipReprinter({
    required CertificateIssuer certificates,
    required CertificateSlipPrinter slips,
  }) : _certificates = certificates,
       _slips = slips;

  final CertificateIssuer _certificates;
  final CertificateSlipPrinter _slips;

  @override
  Future<GiftCertificate> reprint({
    required String number,
    String? pin,
    int? userId,
  }) async {
    final found = await _certificates.lookup(number: number, pin: pin);
    // **Отправляется, а не ожидается** — правило дерева «деньги не ждут
    // железа» действует и здесь. `await` тут стоит не ради ожидания печати:
    // `printIssued` сам не ждёт очереди и не бросает (докстринг порта), и
    // снять его значило бы только завести `unawaited` без выигрыша.
    await _slips.printIssued(certificate: found, userId: userId);
    return found;
  }
}
