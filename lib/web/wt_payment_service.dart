import 'package:decimal/decimal.dart';

import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/payment/prepayment_intake.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/wire/pay_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';

/// Оплата чека — по проводу. Вторая реализация [PaymentService], задача 14.
///
/// # Что здесь есть и чего здесь нет
///
/// Здесь нет **ни одной** денежной арифметики, и это не экономия строк, а
/// суть задачи: сумму чека, потолок бонуса и сдачу считает касса
/// (докстринг [PaymentService]). Всё, что делает эта реализация, — кладёт
/// заявку в кадр и разбирает ответ. Считай она хоть что-нибудь сама, у
/// денег появился бы второй источник правды, живущий во вкладке браузера.
///
/// # Имя рабочего места в кадр не кладётся
///
/// [chargeCard] и [complete] получают `terminalId` доводом, и на провод он
/// **не уезжает**: касса берёт имя из сеанса и отвергает кадр, в котором
/// оно названо (`TillOperations._payTerminal`). Довод здесь остаётся
/// только потому, что он есть в контракте, — экран один и тот же на обеих
/// сборках, а на кассе имя приходит именно доводом.
///
/// # Отказы доезжают как есть
///
/// `WireRefusal` кассы становится кадром отказа с кодом
/// (`till_wire.dart`), а [WtDispatcher] переводит его обратно в
/// исключение с тем же кодом. Экран отличает причину по коду, а не по
/// подстроке в тексте — коды перечислены константами в
/// `payment_service.dart`.
class WtPaymentService implements PaymentService {
  const WtPaymentService(this._wire);

  final WtDispatcher _wire;

  @override
  Future<List<PaymentAccount>> accounts() => _wire.ask(PayOps.accounts, null);

  /// Тумблер кассы, а не догадка вкладки: у браузера базы нет, и
  /// придуманный им ответ был бы вторым источником правды о том, что
  /// касса разрешает.
  @override
  Future<bool> sellsInDebt() => _wire.ask(PayOps.sellsInDebt, null);

  @override
  Future<LoyaltyCustomer?> findLoyalty(String phone) =>
      _wire.ask(PayOps.loyalty, phone);

  @override
  Future<Decimal> reserveBonus(int customerId, Decimal amount) =>
      _wire.ask(PayOps.bonus, (customerId: customerId, amount: amount));

  /// Остаток аванса — ответ кассы. Вкладка его не считает и не хранит:
  /// сальдо живёт на счёте в базе кассы.
  @override
  Future<Decimal> prepaymentBalance(int customerId) =>
      _wire.ask(PayOps.prepayment, customerId);

  /// ПИН уезжает в кадр только тогда, когда кассир его набрал.
  @override
  Future<GiftCertificate> findCertificate(String number, {String? pin}) =>
      _wire.ask(PayOps.certificate, (number: number, pin: pin));

  /// Код QR заводит **касса**: у вкладки нет ни адреса провайдера, ни его
  /// ключа, и не будет — ответ несёт только то, что показать кассиру и
  /// покупателю. `terminalId` на провод не уезжает — из сеанса.
  @override
  Future<String?> qrUnavailableReason() => _wire.ask(PayOps.qrReadiness, null);

  @override
  Future<QrTender> startQr(
    int terminalId,
    Decimal amount,
    CartCommandMeta meta,
  ) => _wire.ask(PayOps.qrStart, (amount: amount, meta: meta));

  @override
  Future<QrTender> pollQr(int terminalId, String intentKey) =>
      _wire.ask(PayOps.qrPoll, intentKey);

  @override
  Future<QrTender> cancelQr(int terminalId, String intentKey) =>
      _wire.ask(PayOps.qrCancel, intentKey);

  @override
  Future<CardCharge> chargeCard(
    int terminalId,
    Decimal amount,
    CartCommandMeta meta,
  ) => _wire.ask(PayOps.card, (amount: amount, meta: meta));

  @override
  Future<SaleOutcome> complete(
    int terminalId,
    PaymentRequest request,
    CartCommandMeta meta,
  ) => _wire.ask(PayOps.complete, (request: request, meta: meta));

  /// `terminalId` на провод **не уезжает** — той же причиной, что у
  /// [chargeCard] и [complete]: касса берёт имя рабочего места из сеанса
  /// и отвергает кадр, в котором оно названо (`_payTerminal`).
  @override
  Future<List<CompletionTrouble>> hardwareTroubles(
    int terminalId,
    int receiptNo,
  ) => _wire.ask(PayOps.troubles, receiptNo);
}

/// Приём аванса покупателя — браузерная половина, требование заказчика
/// 2026-09-18.
///
/// # Почему отдельный класс, а не метод [WtPaymentService]
///
/// Потому что контракт другой. [PaymentService] — это **оплата чека**: у
/// каждого её метода есть чек, версия корзины и метка команды. Приём аванса
/// чека не имеет вовсе; кассир открывает его с дома терминала, когда
/// никакой продажи не идёт. Втиснув его в тот же контракт, пришлось бы
/// объяснять кассовой реализации (`LocalPaymentService`), почему у неё
/// появился метод, не касающийся ни одного чека, — и тащить в неё
/// `CustomerPaymentUseCase`.
///
/// Отсюда [PrepaymentIntakeService] — собственный контракт на одно
/// действие, у которого на кассе уже есть реализация: сам
/// `CustomerPaymentUseCase`.
///
/// # Арифметики здесь нет ни строки
///
/// Тот же довод, что у [WtPaymentService]: сколько денег легло на счёт
/// покупателя, считает касса, и она же решает, выписывать ли чек аванса.
/// Вкладка кладёт заявку в кадр и читает ответ. Отказ доезжает **кодом**
/// (`WtProtocolError.code`), и экран берёт фразу словарём — коды названы в
/// `prepayment_intake.dart`.
class WtPrepaymentIntakeService implements PrepaymentIntakeService {
  const WtPrepaymentIntakeService(this._wire);

  final WtDispatcher _wire;

  /// Отказ провода становится [WireRefusal] **с тем же кодом** — тем же
  /// приёмом, что у `WtRefundService._translate` и `WtCartService._named`.
  ///
  /// Иначе экран пришлось бы учить второму типу исключения: кассовая
  /// реализация того же контракта (`CustomerPaymentUseCaseImpl`) бросает
  /// `WireRefusal`, и договор обязан быть один на обе. Код при этом не
  /// теряется — фразу словарь находит по нему (`saleRefusalErrorKeyOf`).
  @override
  Future<PrepaymentIntakeOutcome> acceptPrepayment(
    PrepaymentIntakeRequest ask,
  ) async {
    try {
      return await _wire.ask(PayOps.prepaymentIntake, ask);
    } on WtProtocolError catch (error) {
      throw WireRefusal(error.code, error.detail);
    }
  }
}

/// Выдача аванса деньгами — по проводу. Вторая реализация
/// [PrepaymentRefundService], решение заказчика 2026-09-18.
///
/// # Зачем она понадобилась
///
/// [WtPrepaymentIntakeService] научила вкладку **вносить** деньги вперёд.
/// Отдать внесённое было нечем: `CustomerPaymentUseCase.refundPrepayment`
/// заведён на кассе целиком, экран под ним только кассовый, операции провода
/// не существовало. Кассир с планшетом мог взять аванс и не мог его вернуть.
///
/// # Почему отдельный класс, а не метод в [WtPrepaymentIntakeService]
///
/// Потому что контракты два ([PrepaymentIntakeService] и
/// [PrepaymentRefundService]), и разделены они не здесь, а в домене:
/// вкладка, умеющая только принимать, не должна объявлять метод выдачи
/// заглушкой. Разбор — в докстринге [PrepaymentRefundService].
///
/// # Арифметики здесь нет ни строки
///
/// Тот же довод, что у [WtPaymentService] и [WtPrepaymentIntakeService]:
/// хватает ли аванса, сколько осталось на счёте и выписывать ли документ
/// возврата, решает **касса** — условной записью внутри транзакции денег.
/// Вкладка кладёт заявку в кадр и читает ответ.
class WtPrepaymentRefundService implements PrepaymentRefundService {
  const WtPrepaymentRefundService(this._wire);

  final WtDispatcher _wire;

  /// Отказ провода становится [WireRefusal] **с тем же кодом** — тем же
  /// приёмом и по той же причине, что у [WtPrepaymentIntakeService]:
  /// кассовая реализация того же контракта бросает `WireRefusal`, и договор
  /// обязан быть один на обе.
  @override
  Future<PrepaymentRefundOutcome> payOutPrepayment(
    PrepaymentRefundRequest ask,
  ) async {
    try {
      return await _wire.ask(PayOps.prepaymentRefund, ask);
    } on WtProtocolError catch (error) {
      throw WireRefusal(error.code, error.detail);
    }
  }
}
