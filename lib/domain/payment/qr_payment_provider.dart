import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'package:telepos/domain/payment/payment_intent.dart';

/// Разговор с провайдером QR/СБП — **чистый Dart, ни Flutter, ни drift,
/// ни базы**.
///
/// # Отказ приходит значением (I144)
///
/// Ни один метод не бросает наружу. Провайдер живёт за сетью, и сеть
/// отказывает **обычно**, а не исключительно: обрыв на середине опроса —
/// не ошибка программы, а нормальный вторник. Исключение здесь означало
/// бы, что каждый вызывающий обязан помнить про `try`, а забывший его
/// уронит кассу посреди чека.
///
/// Поэтому у всех четырёх методов один вид ответа: [QrProviderReply], у
/// которого либо есть состояние, либо есть названная причина.
///
/// # Чего этот контракт НЕ делает
///
/// * **Не пишет в базу.** Строку намерения ведёт `QrPaymentCoordinator`;
///   провайдер — это разговор, а не память.
/// * **Не ждёт.** Терпение кассы — решение кассы, и оно у координатора.
///   Провайдер отвечает то, что знает **сейчас**.
/// * **Не решает про деньги.** Сумма, подтверждённая провайдером, едет в
///   [QrIntentState.paidAmount] как есть; правду о чеке выводит касса.
abstract interface class QrPaymentProvider {
  /// Короткое имя провайдера — уезжает в `Payments.providerCode`.
  String get code;

  /// Создать намерение на [amount].
  ///
  /// [intentKey] — **наш** ключ идемпотентности, придуманный кассой
  /// раньше первого обращения. Повтор с тем же ключом обязан вернуть **то
  /// же самое намерение**, а не завести второе: иначе повтор, вызванный
  /// обрывом ответа, взял бы у покупателя деньги дважды.
  Future<QrProviderReply<QrIntentCreation>> create({
    required String intentKey,
    required Decimal amount,
    String? orderNo,
  });

  /// Спросить, что стало с намерением.
  Future<QrProviderReply<QrIntentState>> poll(String providerIntentId);

  /// Отменить намерение.
  ///
  /// Ответ `paid` здесь — **не ошибка вызова, а самый важный из исходов**:
  /// покупатель успел заплатить между «кассир нажал отмену» и «провайдер
  /// услышал». Деньги списаны, отменять нечего, и молчать об этом нельзя.
  Future<QrProviderReply<QrIntentState>> cancel(String providerIntentId);

  /// Вернуть подтверждённую оплату.
  ///
  /// **Может быть не поддержан вовсе** — тогда [QrProviderReply.refusal]
  /// с кодом [qrReverseUnsupportedCode], а не исключение и не молчание.
  /// Молчание здесь худшее из трёх: кассир решил бы, что вернул.
  ///
  /// [refundKey] — ключ возврата кассы (задача 26): повтор с тем же ключом
  /// обязан вернуть прежний ответ, а не вернуть деньги второй раз. `null` —
  /// разовая отмена оплаты, у которой повтора нет.
  Future<QrProviderReply<QrIntentState>> reverse(
    String providerIntentId,
    Decimal amount, {
    String? refundKey,
  });
}

/// Ответ провайдера: либо значение, либо названная причина. Никогда оба и
/// никогда ни одного.
@immutable
class QrProviderReply<T> {
  const QrProviderReply.ok(T this.value) : refusal = null;

  const QrProviderReply.refused(QrRefusal this.refusal) : value = null;

  final T? value;
  final QrRefusal? refusal;

  bool get isOk => refusal == null;

  @override
  String toString() => isOk ? 'QrProviderReply.ok($value)' : '$refusal';
}

/// Причина отказа — **код и слова**, без текста исключения (I144).
@immutable
class QrRefusal {
  const QrRefusal(this.code, this.message);

  final String code;
  final String message;

  /// Стоит ли пробовать ещё раз.
  ///
  /// Не «повторить прямо сейчас», а «этот отказ лечится временем».
  /// Разбирается координатором: транзиентный отказ на опросе не переводит
  /// намерение в `failed`, потому что деньги могли уже уйти.
  bool get isTransient =>
      code == qrNetworkCode ||
      code == qrTimeoutCode ||
      code == qrProviderBusyCode;

  @override
  bool operator ==(Object other) =>
      other is QrRefusal && other.code == code && other.message == message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => 'QrRefusal($code, $message)';
}

/// Связи с провайдером нет.
///
/// **Транзиентный**, и это решение денежное, а не вкусовое: касса, не
/// дозвонившаяся до провайдера, не знает, оплачено или нет. Объявить
/// такое намерение отказанным значило бы закрыть чек другим способом при
/// живых деньгах на той стороне.
const qrNetworkCode = 'qr_network';

/// Провайдер не ответил за отведённое время.
const qrTimeoutCode = 'qr_timeout';

/// Провайдер ответил «занят, спросите позже».
const qrProviderBusyCode = 'qr_provider_busy';

/// Провайдер ответил тем, чего мы не понимаем.
///
/// **Не транзиентный**: повтор даст тот же непонятный ответ. Лечится
/// человеком, а не временем.
const qrMalformedCode = 'qr_malformed_reply';

/// Такого намерения у провайдера нет.
const qrUnknownIntentCode = 'qr_unknown_intent';

/// Провайдер не умеет возвращать деньги по этому каналу.
///
/// План, шаг 5: `reverse` может быть неподдержан — тогда **отказ
/// значением**, а не исключение и не молчание.
const qrReverseUnsupportedCode = 'qr_reverse_unsupported';

/// Провайдер отверг сам запрос: сумма, срок, учётные данные.
const qrRejectedCode = 'qr_rejected';

/// Провайдер QR не настроен на этой кассе.
const qrNotConfiguredCode = 'qr_not_configured';

/// Все коды отказа — **перечислены, чтобы сторож мог пройти по списку**.
///
/// Ветка разбора, до которой не доходит ни одна проба, зелена впустую;
/// список существует затем, чтобы «сколько кодов» и «сколько пройдено»
/// были двумя числами, а не одним ощущением.
const List<String> kQrRefusalCodes = <String>[
  qrNetworkCode,
  qrTimeoutCode,
  qrProviderBusyCode,
  qrMalformedCode,
  qrUnknownIntentCode,
  qrReverseUnsupportedCode,
  qrRejectedCode,
  qrNotConfiguredCode,
];

/// Что провайдер ответил на создание намерения.
@immutable
class QrIntentCreation {
  const QrIntentCreation({
    required this.providerIntentId,
    required this.status,
    this.qrPayload,
    this.expiresAt,
    this.alreadyExisted = false,
  });

  final String providerIntentId;
  final QrIntentStatus status;

  /// Код, который показывают покупателю.
  final String? qrPayload;
  final DateTime? expiresAt;

  /// Провайдер узнал наш [QrPaymentProvider.create] ключ и вернул прежнее
  /// намерение вместо нового.
  ///
  /// Существует ради пробы идемпотентности: без этого флага «повтор не
  /// создал второго» доказывается только косвенно — числом строк на той
  /// стороне, которого у продукта нет.
  final bool alreadyExisted;

  @override
  String toString() =>
      'QrIntentCreation($providerIntentId, ${status.code}, '
      'existed=$alreadyExisted)';
}

/// Что провайдер знает о намерении сейчас.
@immutable
class QrIntentState {
  const QrIntentState({
    required this.providerIntentId,
    required this.status,
    this.paidAmount,
    this.confirmedAt,
    this.message,
  });

  final String providerIntentId;
  final QrIntentStatus status;

  /// Сколько подтверждено. `null` — провайдер не назвал; тогда считается
  /// запрошенная (`PaymentIntent.money`).
  final Decimal? paidAmount;
  final DateTime? confirmedAt;

  /// Слова провайдера при отказном исходе.
  final String? message;

  @override
  String toString() =>
      'QrIntentState($providerIntentId, ${status.code}, $paidAmount)';
}
