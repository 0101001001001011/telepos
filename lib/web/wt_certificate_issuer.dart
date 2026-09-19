import 'package:decimal/decimal.dart';

import 'package:telepos/domain/discount/discount_policy.dart';
import 'package:telepos/domain/payment/certificate_issuer.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/wire/pay_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';

/// Выпуск подарочного сертификата — по проводу. Вторая реализация
/// [CertificateIssuer], дыра 1 ревизии 2026-09-19.
///
/// # Зачем она понадобилась именно сейчас
///
/// Операция `pay.certificateIssue` существует с задачи 21: со своим правом,
/// своим кодеком, своим обработчиком и своими пробами. Вызывать её было
/// **нечему** — ни одной реализации [CertificateIssuer] в браузерной точке
/// входа не привязано, и экрана, который бы её спросил, не существовало ни
/// на одной из двух сборок. То есть дыра «написано, охраняется правом,
/// покрыто пробами, недостижимо кассиру» жила на проводе в чистом виде, и
/// закрыть её на кассе значило закрыть половину.
///
/// # Арифметики здесь нет ни строки
///
/// Тот же довод, что у `WtPaymentService`: обязательство кассы, счёт под
/// него, уникальность номера и хэш ПИНа — всё это делает касса. Вкладка
/// кладёт заявку в кадр и читает ответ.
///
/// # Отказ доезжает кодом и становится `WireRefusal`
///
/// Тем же приёмом, что у `WtPrepaymentIntakeService` и `WtRefundService`:
/// кассовая реализация того же контракта бросает [WireRefusal], и договор
/// обязан быть один на обе — иначе экран пришлось бы учить второму типу
/// исключения, а он один на обе сборки.
class WtCertificateIssuer implements CertificateIssuer {
  const WtCertificateIssuer(this._wire);

  final WtDispatcher _wire;

  @override
  Future<GiftCertificate> issue({
    required DiscountAuthority by,
    required String number,
    required Decimal nominal,
    String? pin,
    int? expiresAt,
    int? receiptNo,
    int? posId,
    int? userId,
  }) async {
    // [by] в кадр **не кладётся и здесь не читается** — ревизия второго
    // фронта 2026-09-19. Довод обязателен по контракту, чтобы забыть право
    // было нельзя по сборке, но решает его не вкладка: права, названные
    // вкладкой, правами не являются (то же правило, что у `posId`/`userId`
    // ниже и у имени рабочего места в докстринге `CartService`). Право
    // читают дважды на стороне кассы: сторож провода до обработчика и сам
    // `LocalCertificateIssuer.issue` из сеанса. Проверять его ещё и тут
    // значило бы завести третью правду, расходящуюся молча: вкладка со
    // старым набором прав показывала бы «не разрешено» там, где касса уже
    // разрешила.
    //
    // `posId` и `userId` в кадр **не кладутся**, и это не забывчивость:
    // обязательство берёт на себя касса, номер кассы — её собственный, а
    // кассира она знает из сеанса. Значения, названные вкладкой, значениями
    // сеанса не являются — то же правило, по которому кадр не смеет
    // называть рабочее место (докстринг `CartService`). Обработчик кассы их
    // и не читает: `TillOperations` строит вызов из четырёх полей заявки.
    try {
      return await _wire.ask(
        PayOps.certificateIssue,
        CertificateIssueAsk(
          number: number,
          nominal: nominal,
          pin: pin,
          expiresAt: expiresAt,
          receiptNo: receiptNo,
        ),
      );
    } on WtProtocolError catch (error) {
      throw WireRefusal(error.code, error.detail);
    }
  }

  @override
  Future<GiftCertificate> lookup({required String number, String? pin}) async {
    // Та же операция, какой предъявление сертификата спрашивает остаток
    // (`pay.certificate`), а не своя вторая: вопрос один и тот же — «что
    // касса знает о бумажке, которую ей подали». Своя операция рядом
    // означала бы второй ответ на него, и замок перебора
    // (`CertificateThrottle`) сторожил бы только один из двух.
    try {
      return await _wire.ask(PayOps.certificate, (number: number, pin: pin));
    } on WtProtocolError catch (error) {
      throw WireRefusal(error.code, error.detail);
    }
  }

  /// Отзыв бумажки **по проводу не ездит** — своей операции у него нет.
  ///
  /// Названо отказом, а не молчаливым успехом и не `UnimplementedError`:
  /// «отозвал» на месте «не отзывал» — это ровно тот подлог, которым
  /// занимался бы экран, показавший успех. Что вызывающего у [cancel] в
  /// дереве сегодня нет ни одного — не довод написать здесь заглушку:
  /// первый же появившийся получил бы тишину.
  ///
  /// Код — **существующий** `certificates_unavailable`, тот же, которым
  /// отвечает касса, собранная без узла сертификатов
  /// (`TillOperations._requireCertificates`). Новый код здесь был бы
  /// новым словом на ту же беду — «этой сборке нечем», — и потребовал бы
  /// пяти словарных строк ради метода, у которого нет вызывающих. Фраза
  /// существующего кода («эта касса не выпускает подарочные сертификаты по
  /// проводу») правдива и здесь: отзыва по проводу нет.
  ///
  /// [certificateUnknownCode] на этом месте солгал бы: «такого сертификата
  /// нет» отправит кассира искать опечатку в номере, которого никто не
  /// читал.
  @override
  Future<void> cancel(String number) async {
    throw const WireRefusal(
      'certificates_unavailable',
      'отозвать сертификат можно только на самой кассе: операции отзыва по '
          'проводу нет',
    );
  }
}
