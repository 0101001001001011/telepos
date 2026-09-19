import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

/// Намерение оплаты по QR/СБП — **единственный вид оплаты в дереве, у
/// которого между вопросом и ответом проходит время**.
///
/// # Почему намерению нужна своя сущность, а наличным — нет
///
/// Наличные, карта и бонус отвечают кассе **внутри вызова**: к моменту,
/// когда `LocalPaymentService.complete` собирает строки оплаты, про них
/// уже всё известно. QR так не умеет. Касса **создаёт намерение**,
/// показывает код, и подтверждение приходит **снаружи и потом** — от
/// банка покупателя, через провайдера, по своему расписанию. Между этими
/// двумя мгновениями касса может быть перезагружена, вкладка закрыта, а
/// кассир — уйти на другой чек.
///
/// Отсюда состояния, которых у наличных нет, и отсюда же **таблица, а не
/// поле экрана**: память экрана умирает вместе с экраном, а деньги
/// покупателя — нет.
///
/// # Шесть состояний и почему их не пять
///
/// Пятое и шестое ([abandonedAt], [settledAt]) — **не состояния, а
/// отметки времени рядом с состоянием**, и это осознанно. Соблазн завести
/// седьмой член перечисления `paidAfterGiveUp` («оплачено после того, как
/// касса сдалась») велик и неправ: провайдер про нашу сдачу не знает и
/// знать не может, он отвечает `paid`. Класть в одно поле ответ чужой
/// системы и своё решение значит потерять возможность отличить «он
/// сказал» от «мы решили» — а именно эта разница и разбирается человеком
/// на экране беды.
///
/// Отсюда определения, которые читаются **утверждением о полях**, а не
/// сравнением со статусом:
///
/// * **Деньги без чека** — [isOrphanMoney]: `paid`, но `settledAt` пуст.
///   Ровно тот класс беды, ради которого намерение видно на экране
///   разбора.
/// * **Оплачено после сдачи** — [isPaidAfterGiveUp]: `paid`, `abandonedAt`
///   заполнен. Деньги у покупателя списаны, а чек закрыт другим способом
///   или не закрыт вовсе.
///
/// # Значения на диске — строки, а не индексы членов
///
/// Тот же довод, что у `FiscalTreatment.code` и `Sales.fiscalState`:
/// индекс члена меняется от перестановки в объявлении, а на диске лежат
/// намерения, пережившие перезагрузку и обновление сборки.
enum QrIntentStatus {
  /// Строка заведена кассой, провайдер ещё не отвечал.
  ///
  /// Живёт доли секунды в счастливом случае и **сколько угодно** в
  /// несчастном: обрыв связи ровно на создании оставляет намерение
  /// именно здесь, и это не «ничего не произошло» — деньги, может быть,
  /// уже ждут покупателя на той стороне. Разбирается [reconcile] по
  /// [intentKey], а не забывается.
  created,

  /// Провайдер принял намерение и вернул код. Покупатель платит.
  pending,

  /// Провайдер подтвердил оплату.
  paid,

  /// Срок намерения вышел — сказал **провайдер**, а не наш таймер.
  ///
  /// Наше терпение кончается отдельно и не переводит намерение сюда:
  /// касса, устав ждать, ставит [abandonedAt], а состояние оставляет
  /// таким, какое есть. Иначе мы объявили бы просроченным то, что через
  /// секунду станет `paid`, — и потеряли бы деньги на ровном месте.
  expired,

  /// Намерение отменено — кассиром через кассу или провайдером.
  cancelled,

  /// Провайдер ответил отказом (или ответил тем, чего мы не понимаем).
  failed,

  /// Оплата возвращена покупателю.
  reversed;

  /// Стабильный код на диске и на проводе.
  String get code => name;

  static QrIntentStatus? byCode(String? value) {
    for (final v in values) {
      if (v.name == value) return v;
    }
    return null;
  }

  /// Состояние, из которого само по себе больше ничего не выйдет.
  ///
  /// `paid` **терминально по-провайдерски и не терминально по-нашему**:
  /// деньги пришли, но чек ещё может быть не закрыт. Опрашивать
  /// провайдера дальше незачем, разбирать — есть что.
  bool get isTerminal => switch (this) {
    QrIntentStatus.created => false,
    QrIntentStatus.pending => false,
    QrIntentStatus.paid => true,
    QrIntentStatus.expired => true,
    QrIntentStatus.cancelled => true,
    QrIntentStatus.failed => true,
    QrIntentStatus.reversed => true,
  };

  /// Деньги на этой строке есть.
  bool get holdsMoney => this == QrIntentStatus.paid;
}

/// Намерение оплаты как строка базы и как доменная величина.
@immutable
class PaymentIntent {
  const PaymentIntent({
    required this.id,
    required this.intentKey,
    required this.providerCode,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.providerIntentId,
    this.posId,
    this.receiptNo,
    this.terminalId,
    this.qrPayload,
    this.paidAmount,
    this.expiresAt,
    this.confirmedAt,
    this.abandonedAt,
    this.settledAt,
    this.settledReceiptNo,
    this.reversedAmount,
    this.reversedAt,
    this.refusalCode,
    this.refusalMessage,
    this.confirmations = 0,
  });

  final int id;

  /// Ключ идемпотентности — **наш, а не провайдера**, и придуман раньше
  /// первого обращения.
  ///
  /// Это и есть весь механизм «повтор не создаёт второго намерения»:
  /// строка с этим ключом одна по уникальному ключу таблицы, и повторный
  /// вызов находит её, а не заводит вторую. Ключ провайдера
  /// ([providerIntentId]) для этого не годится — он приходит **ответом**,
  /// то есть позже той секунды, в которую и случается двойное создание.
  final String intentKey;

  /// Какой провайдер. Едет в `Payments.providerCode` при расчёте.
  final String providerCode;

  /// Сколько просили.
  final Decimal amount;

  /// Сколько провайдер подтвердил. Может быть **меньше** [amount] —
  /// «оплачено частично» бывает, и молчать про это нельзя.
  final Decimal? paidAmount;

  final QrIntentStatus status;

  final String? providerIntentId;

  /// Код, который показывают покупателю.
  final String? qrPayload;

  final int? posId;
  final int? receiptNo;
  final int? terminalId;

  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? confirmedAt;

  /// Когда **касса перестала ждать** — терпение кончилось или кассир нажал
  /// «Отмена».
  ///
  /// Не то же самое, что [QrIntentStatus.cancelled]: там сказал
  /// провайдер, здесь решили мы. Подтверждение, пришедшее после этой
  /// отметки, — деньги у покупателя списаны, а чек закрыт другим
  /// способом.
  final DateTime? abandonedAt;

  /// Когда деньги легли в чек строкой `Payments`.
  ///
  /// Пусто при `paid` — **деньги без чека**, и они обязаны быть видны.
  final DateTime? settledAt;

  final int? settledReceiptNo;

  /// Сколько по этому намерению **вернули покупателю** — v51.
  ///
  /// `null` — не возвращали **или не знаем**: у возвратов, прошедших до
  /// v51, записи не осталось, и переноса нет (разбор — в ветви
  /// `from < 51`). Ноль здесь означал бы «вернули нисколько», то есть
  /// утверждение, которого никто не делал.
  final Decimal? reversedAmount;

  /// Когда провайдер подтвердил возврат.
  final DateTime? reversedAt;

  final String? refusalCode;
  final String? refusalMessage;

  /// Сколько раз провайдер подтверждал это намерение.
  ///
  /// Больше одного — не беда сама по себе (переотправка вебхука обычна),
  /// но **второе подтверждение не берёт денег второй раз**, и число здесь
  /// существует, чтобы это было видно, а не выведено из молчания.
  final int confirmations;

  /// Деньги пришли, чека нет. Экран разбора показывает ровно это.
  bool get isOrphanMoney => status.holdsMoney && settledAt == null;

  /// Подтверждение пришло после того, как касса сдалась.
  bool get isPaidAfterGiveUp => status.holdsMoney && abandonedAt != null;

  /// Провайдер подтвердил меньше, чем просили.
  bool get isPartial =>
      status.holdsMoney && paidAmount != null && paidAmount! < amount;

  /// Сколько денег на этой строке на самом деле.
  ///
  /// `paidAmount ?? amount` — и `??`, а не `amount`: провайдер, не
  /// назвавший сумму, подтвердил запрошенную; провайдер, назвавший
  /// меньшую, подтвердил меньшую. Подставлять запрошенную поверх
  /// названной значило бы дописать покупателю денег, которых он не
  /// платил.
  Decimal get money => paidAmount ?? amount;

  /// Деньги, **оставшиеся** на намерении: подтверждённое минус вернувшееся.
  ///
  /// Заведено вместе с [reversedAmount] (v51) и отвечает на вопрос, который
  /// до неё задать было нечем: «сколько из этих денег ещё у кассы». До v51
  /// [money] отвечал за оба вопроса сразу и после возврата врал.
  ///
  /// # Чего это НЕ доказывает
  ///
  /// Что возвратов не было, когда здесь [money]. У возвратов до v51
  /// [reversedAmount] пуст, и остаток посчитается полным.
  Decimal get moneyLeft {
    final back = reversedAmount;
    if (back == null) return money;
    final left = money - back;
    return left > Decimal.zero ? left : Decimal.zero;
  }

  PaymentIntent copyWith({
    String? providerIntentId,
    QrIntentStatus? status,
    String? qrPayload,
    Decimal? paidAmount,
    DateTime? expiresAt,
    DateTime? confirmedAt,
    DateTime? abandonedAt,
    DateTime? settledAt,
    int? settledReceiptNo,
    Decimal? reversedAmount,
    DateTime? reversedAt,
    String? refusalCode,
    String? refusalMessage,
    int? confirmations,
  }) => PaymentIntent(
    id: id,
    intentKey: intentKey,
    providerCode: providerCode,
    amount: amount,
    status: status ?? this.status,
    createdAt: createdAt,
    providerIntentId: providerIntentId ?? this.providerIntentId,
    posId: posId,
    receiptNo: receiptNo,
    terminalId: terminalId,
    qrPayload: qrPayload ?? this.qrPayload,
    paidAmount: paidAmount ?? this.paidAmount,
    expiresAt: expiresAt ?? this.expiresAt,
    confirmedAt: confirmedAt ?? this.confirmedAt,
    abandonedAt: abandonedAt ?? this.abandonedAt,
    settledAt: settledAt ?? this.settledAt,
    settledReceiptNo: settledReceiptNo ?? this.settledReceiptNo,
    reversedAmount: reversedAmount ?? this.reversedAmount,
    reversedAt: reversedAt ?? this.reversedAt,
    refusalCode: refusalCode ?? this.refusalCode,
    refusalMessage: refusalMessage ?? this.refusalMessage,
    confirmations: confirmations ?? this.confirmations,
  );

  @override
  String toString() =>
      'PaymentIntent($id, $intentKey, ${status.code}, $amount)';
}
