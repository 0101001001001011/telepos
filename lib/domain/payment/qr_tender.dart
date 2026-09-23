import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'package:telepos/domain/payment/payment_intent.dart';

/// Где сейчас оплата по QR — **глазами кассира**.
///
/// Выводится кассой из полей намерения (`status`, `abandonedAt`,
/// `createdAt`), а не хранится: хранимая фаза была бы второй правдой рядом
/// с первой. Разбор каждой — у членов.
enum QrTenderPhase {
  /// Код показан, покупатель платит, касса ждёт.
  waiting,

  /// Оплачено, пока касса ждала.
  paid,

  /// **Оплачено, хотя касса уже перестала ждать.** Отмена кассира и
  /// оплата покупателя разошлись на секунды; провайдер ответил на отмену
  /// «уже оплачено». Деньги списаны — и если чек ещё открыт, они идут в
  /// него, а не в разбор.
  paidAfterGiveUp,

  /// Кассир отменил, провайдер отмену подтвердил.
  cashierCancelled,

  /// Терпение кассы кончилось, провайдер отмену подтвердил.
  patienceSpent,

  /// **Касса перестала ждать, а провайдер отмену не подтвердил** — связи
  /// не было. Деньги ещё могут прийти, и объявлять оплату отменённой
  /// нельзя: кассир, принявший наличные поверх, взял бы с покупателя
  /// дважды.
  cancelUnconfirmed,

  /// Срок кода вышел — сказал провайдер.
  expired,

  /// Провайдер отказал (или покупатель отказался, или ответ не разобран).
  failed;

  /// Касса ещё ждёт ответа провайдера — чек закрывать нельзя.
  bool get blocksCompletion =>
      this == QrTenderPhase.waiting || this == QrTenderPhase.cancelUnconfirmed;

  /// Деньги на намерении есть.
  bool get holdsMoney =>
      this == QrTenderPhase.paid || this == QrTenderPhase.paidAfterGiveUp;

  static QrTenderPhase? byName(String? value) {
    for (final phase in values) {
      if (phase.name == value) return phase;
    }
    return null;
  }

  /// Фаза из полей намерения.
  ///
  /// Кассир или терпение — различается **отметкой времени**: сдалась
  /// касса не раньше `createdAt + patience` — значит, по терпению. Причину
  /// в таблицу не пишем: это была бы вторая колонка про одно решение, и
  /// первая же правка терпения развела бы их.
  static QrTenderPhase of(PaymentIntent intent, Duration patience) {
    final abandoned = intent.abandonedAt;
    switch (intent.status) {
      case QrIntentStatus.paid:
        return abandoned == null
            ? QrTenderPhase.paid
            : QrTenderPhase.paidAfterGiveUp;
      case QrIntentStatus.created:
      case QrIntentStatus.pending:
        return abandoned == null
            ? QrTenderPhase.waiting
            : QrTenderPhase.cancelUnconfirmed;
      case QrIntentStatus.cancelled:
        if (abandoned == null) return QrTenderPhase.failed;
        return abandoned.difference(intent.createdAt) >= patience
            ? QrTenderPhase.patienceSpent
            : QrTenderPhase.cashierCancelled;
      case QrIntentStatus.expired:
        return QrTenderPhase.expired;
      case QrIntentStatus.failed:
      case QrIntentStatus.reversed:
        return QrTenderPhase.failed;
    }
  }
}

/// Оплата по QR так, как её видит экран оплаты — **на обоих фронтах**.
///
/// # Чего здесь нет, и это главное
///
/// **Ни адреса провайдера, ни его ключа, ни его имени, ни ид намерения на
/// той стороне.** Всё это знает касса и только касса (докстринг
/// `QrProviderSettings`). Экрану хватает ключа намерения — им он
/// спрашивает, отменяет и закрывает чек, — и того, что показать человеку.
///
/// # Секунды, а не момент
///
/// [secondsLeft] посчитан **часами кассы** в момент ответа. Абсолютный
/// срок пришлось бы сравнивать с часами планшета, а они расходятся с
/// кассой на минуты чаще, чем кажется, — и кассир видел бы «осталось
/// −4 минуты» при живом ожидании.
@immutable
class QrTender {
  const QrTender({
    required this.intentKey,
    required this.phase,
    required this.amount,
    this.paidAmount,
    this.qrPayload,
    this.receiptNo,
    this.secondsLeft,
    this.settledReceiptNo,
    this.refusalCode,
  });

  /// Из строки намерения — одна функция на обе стороны сборки ответа.
  factory QrTender.of(
    PaymentIntent intent, {
    required Duration patience,
    required DateTime now,
    String? refusalCode,
  }) {
    final phase = QrTenderPhase.of(intent, patience);
    final left = intent.createdAt.add(patience).difference(now).inSeconds;
    return QrTender(
      intentKey: intent.intentKey,
      phase: phase,
      amount: intent.amount,
      paidAmount: intent.paidAmount,
      qrPayload: phase == QrTenderPhase.waiting ? intent.qrPayload : null,
      receiptNo: intent.receiptNo,
      secondsLeft: phase == QrTenderPhase.waiting
          ? (left < 0 ? 0 : left)
          : null,
      settledReceiptNo: intent.settledReceiptNo,
      refusalCode: refusalCode ?? intent.refusalCode,
    );
  }

  /// Ключ намерения — им экран опрашивает, отменяет и закрывает чек
  /// (`PaymentRequest.qrIntentKey`).
  final String intentKey;

  final QrTenderPhase phase;

  /// Сколько просили.
  final Decimal amount;

  /// Сколько провайдер подтвердил. Может быть меньше [amount].
  final Decimal? paidAmount;

  /// Что показать покупателю. Только пока касса ждёт: код отменённой
  /// оплаты на экране — приглашение заплатить по тому, что уже не примут.
  final String? qrPayload;

  final int? receiptNo;

  /// Сколько ещё касса согласна ждать. Только при [QrTenderPhase.waiting].
  final int? secondsLeft;

  /// Деньги уже легли в этот чек. Не `null` — второй раз зачесть нельзя.
  final int? settledReceiptNo;

  /// Последний отказ провайдера кодом (`qr_network`, `qr_rejected`, …).
  /// При [QrTenderPhase.waiting] — транзиентный: касса повторяет сама.
  final String? refusalCode;

  /// Деньги на строке.
  Decimal get money => paidAmount ?? amount;

  /// Подтверждено меньше, чем просили.
  bool get isPartial =>
      phase.holdsMoney && paidAmount != null && paidAmount! < amount;

  /// Эти деньги можно зачесть в открытый чек.
  bool get usable => phase.holdsMoney && settledReceiptNo == null;

  @override
  String toString() =>
      'QrTender($intentKey, ${phase.name}, $amount, paid=$paidAmount)';
}
