import 'package:meta/meta.dart';

import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';

/// Чем строка оплаты рассчитывается — **три значения, а не два**.
///
/// Ровно нехватка третьего значения и есть причина, по которой продажа в
/// долг сегодня живёт разностью, а не строкой: долг не приносит живых
/// денег ([tender]) и не гасит ничего накопленного ([offset]) — он
/// **заменяет** деньги обязательством, и назвать его любым из двух
/// остальных значило бы соврать в отчёте смены.
///
/// Значения лежат на диске (`payment_kinds.settlement`) числами: индекс
/// члена меняться не должен, новые члены дописываются **в конец**.
enum PaymentSettlement {
  /// Живые деньги: наличные, карта, QR. Двигают счёт кассы или банка,
  /// участвуют в сдаче (если вид её даёт) и попадают в выручку смены.
  tender,

  /// Зачёт накопленного или ранее внесённого: бонус, сертификат,
  /// предоплата. Денег в кассу не приносят — уменьшают чужое
  /// обязательство.
  offset,

  /// Обязательство вместо денег: долг, рассрочка. Ни живых денег, ни
  /// зачёта; счёт покупателя уходит в минус на эту сумму.
  ///
  /// **Ни одна строка этого рода не выходит из денежного ящика при
  /// возврате** — см. `RefundUseCaseImpl._createReversalPayments`.
  deferred;

  /// Разбор числа с диска. Незнакомое число — не «наличные по
  /// умолчанию», а `null`: справочник, приехавший от кассы более новой
  /// сборки, обязан читаться как «не знаю», а не как выдуманное значение.
  static PaymentSettlement? byIndex(int? value) =>
      value != null && value >= 0 && value < values.length
      ? values[value]
      : null;

  /// Имя на проводе и в настройках. Совпадает с [name].
  static PaymentSettlement? byCode(String? value) {
    for (final v in values) {
      if (v.name == value) return v;
    }
    return null;
  }

  /// Обязательство вместо денег.
  ///
  /// Существует затем, чтобы читатель, у которого на руках только род
  /// расчёта (без всего [PaymentKind]), спрашивал **тем же словом**, что
  /// и остальные: `settlement == PaymentSettlement.deferred`, написанное
  /// в трёх местах, разъезжается ровно так же, как разъехались десять
  /// мест вывода вида из рода счёта.
  bool get isDeferredValue => this == PaymentSettlement.deferred;
}

/// Как вид оплаты называется в фискальном документе — **страновое
/// решение, и потому оно в справочнике, а не в коде**.
///
/// # Почему шестой член, которого нет в [FiscalPaymentKind]
///
/// [notAPayment] — не вид оплаты оператора, а утверждение «эта строка в
/// фискальный документ платежом не идёт вовсе». Такой ответ нужен
/// **бонусу**: он списывается со счёта покупателя, счёт кассы не
/// двигается, и объявить его платежом значит **завысить базу налога**.
/// Бонус фискально — скидка, и он уже входит слагаемым в формулу скидки
/// позиции (`FiscalPositionBuilder`, `extraDiscount`, задачи 6 и 7). Ещё
/// одно поле под ту же величину развело бы два ответа на один вопрос.
///
/// # Почему не переиспользован сам [FiscalPaymentKind]
///
/// Потому что он **исчерпывающий и без `default`** там, где им
/// пользуются (`WebkassaProvider._paymentKindCode`): добавление члена
/// ломает сборку, и это ровно тот сторож, который здесь нужен. Свой
/// шестой член в нём означал бы «оператор знает про не-платёж» — он не
/// знает. Разделение читается так: [FiscalTreatment] отвечает «что
/// сказать оператору», [toFiscalKind] переводит ответ на язык оператора и
/// возвращает `null` там, где сказать нечего.
enum FiscalTreatment {
  cash,
  card,
  credit,
  mobile,
  tare,

  /// Строка в фискальный документ платежом не идёт. Сегодня это бонус.
  notAPayment,

  /// **Зачёт денег, уже прошедших через кассу раньше**: гашение
  /// сертификата, зачёт аванса. Решение заказчика 2026-09-14.
  ///
  /// # Чем отличается от [notAPayment]
  ///
  /// Оба не платёж, но спрашивают разное. Бонус — накопленное магазином, и
  /// ответ у него один: скидка позиции. Зачёт — деньги покупателя, внесённые
  /// раньше, и **как закрыть разницу позиций и оплаты** выбирает оператор
  /// настройкой `OffsetFiscalLayout`: скидкой позиций (практика 1С:Розница
  /// КЗ) или чеком только на доплату. Слить члены значило бы отнять у
  /// зачёта этот выбор.
  ///
  /// # Почему не `cash`
  ///
  /// Разбор `docs/internal/research/2026-09-14-certificate-prepayment-
  /// fiscal-kz.md`: КГД — «оплата сертификатом не является денежным
  /// расчётом». Чек 8350 (сертификаты 6500 + аванс 700 + наличные 1150)
  /// уезжал оператору `cashAmount 8350` при 1150 в ящике: Z-отчёт оператора
  /// врал на 7200, а 6500 из них прошли выручкой ККМ второй раз.
  offsetNotFiscal;

  /// Стабильный код на диске и на проводе — **строка, а не индекс
  /// члена**.
  ///
  /// Тот же довод, что у `Sales.fiscalState` в спеке: индекс члена
  /// меняется от перестановки в объявлении, а на диске лежат чеки
  /// трёхлетней давности.
  String get code => name;

  static FiscalTreatment? byCode(String? value) {
    for (final v in values) {
      if (v.name == value) return v;
    }
    return null;
  }

  /// Безналичные деньги **с точки зрения оператора** — задача 22.
  ///
  /// # Почему это одно выражение, а не список на месте вопроса
  ///
  /// Выборочная фискализация «только безналичные чеки» (`ofdSyncType ==
  /// 2`) спрашивала `fiscalTreatment != card`, и до задачи 22 это было
  /// верно **по построению**: единственным безналичным видом была карта.
  /// QR/СБП — второй, и с ним чек, оплаченный телефоном, переставал
  /// уезжать оператору вовсе: молча, без отказа, с исходом
  /// `notRequired`.
  ///
  /// Список «карта или мобильный», повторённый у каждого читателя, дал бы
  /// ту же беду под другим именем при первом же забытом повторе — ровно
  /// как разъехались десять мест вывода вида из рода счёта. Здесь один
  /// ответ, и сторож проходит по **всем** членам перечисления
  /// (`ofd_policy_cashless_kinds_test.dart`).
  ///
  /// # Почему `credit` и `tare` — не безнал
  ///
  /// [credit] — обязательство вместо денег: покупатель не заплатил ничем,
  /// ни наличными, ни безналично. [tare] — возврат залога за тару, и
  /// деньгами оператора он не считается. [notAPayment] — не платёж вовсе.
  ///
  /// `switch` **исчерпывающий и без `default`**: новый член сломает
  /// сборку здесь, и это хорошо.
  bool get isCashless => switch (this) {
    FiscalTreatment.cash => false,
    FiscalTreatment.card => true,
    FiscalTreatment.credit => false,
    FiscalTreatment.mobile => true,
    FiscalTreatment.tare => false,
    FiscalTreatment.notAPayment => false,
    // Зачёт — деньги, прошедшие раньше; сегодняшнего расчёта нет вовсе.
    FiscalTreatment.offsetNotFiscal => false,
  };

  /// **Наличные деньги сегодняшнего расчёта** — те, ради которых
  /// выборочная фискализация вообще заведена.
  ///
  /// Не отрицание [isCashless]: «не безналичные» — это ещё и долг, и
  /// бонус, и зачёт, а наличными из них не является ни один. Отдельный
  /// вопрос нужен потому, что в составе чека у наличной строки роль
  /// особая: она одна **уводит** чек от оператора (разбор — у
  /// [receiptIsCashless]).
  ///
  /// `switch` **исчерпывающий и без `default`**: новый член сломает
  /// сборку здесь, и это хорошо.
  bool get isCash => switch (this) {
    FiscalTreatment.cash => true,
    FiscalTreatment.card => false,
    FiscalTreatment.credit => false,
    FiscalTreatment.mobile => false,
    FiscalTreatment.tare => false,
    FiscalTreatment.notAPayment => false,
    FiscalTreatment.offsetNotFiscal => false,
  };

  /// Уезжает ли оператору **чек такого состава** при выборочной
  /// фискализации «только безналичные» (`ThisPos.ofdSyncType == 2`).
  ///
  /// # Почему вопрос про чек, а не про строку — ревизия 2026-09-19
  ///
  /// До этого выражения вопрос задавался каждой строке по отдельности:
  /// «все ли строки безналичны?». Пока безналичным видом была одна карта,
  /// разницы не было. Сегодня у чека есть строки, которые **деньгами
  /// сегодняшнего расчёта не являются вовсе**, и каждая из них уводила
  /// чек мимо оператора:
  ///
  /// * [offsetNotFiscal] — гашение сертификата и зачёт аванса (решение
  ///   заказчика 2026-09-14: не фискальная оплата);
  /// * [notAPayment] — бонус;
  /// * [credit] — долг и рассрочка.
  ///
  /// Измерено: чек «карта 4000 + сертификат 1000» на кассе с
  /// `ofdSyncType == 2` не уезжал оператору **вовсе** — деньги картой
  /// взяты, фискального документа нет, отказа и полосы кассир не видит.
  /// Это та же беда, что задача 22 закрыла для QR, вернувшаяся под другим
  /// именем: ответ был про вид, а вопрос — про чек.
  ///
  /// # Правило
  ///
  /// Уезжает чек, в котором **есть безналичная строка и нет наличной**.
  /// Вето принадлежит только наличным, и по делу: выборочность «только
  /// безнал» ради того и включается, чтобы наличный чек остался вне
  /// оператора. Строка, не являющаяся сегодняшними деньгами, ни ведёт к
  /// оператору, ни уводит от него — она молчит.
  ///
  /// # Чего это правило НЕ решает
  ///
  /// Оно не говорит, **что** уедет в конверте: раскладка зачёта, скидка
  /// бонусом и исключение проданных сертификатов считаются отдельно
  /// (`LocalPaymentService._fiscalize`, `OffsetFiscalLayout`), и сторож
  /// равенства позиций и оплат — `fiscal_envelope_balance_test`. Оно
  /// также ничего не знает о строках, вид которых определить не удалось:
  /// такая строка до сюда не доезжает (`isOfdSale` её пропускает), и
  /// молчание о ней — осознанный предел, названный там же.
  static bool receiptIsCashless(Iterable<FiscalTreatment> lines) {
    var cashless = false;
    for (final line in lines) {
      if (line.isCash) return false;
      if (line.isCashless) cashless = true;
    }
    return cashless;
  }

  /// Что сказать фискальному оператору. `null` — не говорить ничего.
  ///
  /// `switch` **исчерпывающий и без `default`**: новый член сломает
  /// сборку здесь, и это хорошо — компилятор сторожит.
  FiscalPaymentKind? toFiscalKind() => switch (this) {
    FiscalTreatment.cash => FiscalPaymentKind.cash,
    FiscalTreatment.card => FiscalPaymentKind.card,
    FiscalTreatment.credit => FiscalPaymentKind.credit,
    FiscalTreatment.mobile => FiscalPaymentKind.mobile,
    FiscalTreatment.tare => FiscalPaymentKind.tare,
    FiscalTreatment.notAPayment => null,
    FiscalTreatment.offsetNotFiscal => null,
  };
}

/// Системные ид видов оплаты — **присвоены руками, 1–9**.
///
/// # Почему не автоинкремент
///
/// `Payments.kindId` уезжает в выгрузку вместе с чеком, а чеки
/// синхронизируются между кассами сети. Автоинкремент дал бы двум кассам
/// **разный ид под одним смыслом**: чек, приехавший с соседней кассы,
/// читался бы как оплаченный сертификатом там, где на самом деле была
/// карта. Ид вида — часть смысла чека, а не его локальная деталь.
///
/// Пользовательские виды начинаются со **100** — промежуток 10–99
/// оставлен под системные, которых ещё нет.
abstract final class SystemPaymentKindIds {
  static const int cash = 1;
  static const int card = 2;
  static const int bonus = 3;
  static const int debt = 4;
  static const int certificate = 5;
  static const int qr = 6;
  static const int prepayment = 7;
  static const int installment = 8;

  /// Расчёт с контрагентом — **не тендер продажи**.
  ///
  /// Строки оплаты, лежащие на счёте рода [AccountType.agentMain], читает
  /// погашение долга контрагентом, а не касса продажи. Классифицировать
  /// их «наличными» было бы порчей: они пришли бы в выручку смены. Вид
  /// скрыт от селектора ([PaymentKind.isSelectable] = `false`) — выбрать
  /// его кассиру нельзя, он существует ради **чтения истории**.
  static const int agentSettlement = 9;

  /// С какого числа начинаются виды, заведённые оператором.
  static const int firstUserId = 100;

  static const List<int> all = <int>[
    cash,
    card,
    bonus,
    debt,
    certificate,
    qr,
    prepayment,
    installment,
    agentSettlement,
  ];
}

/// Вид оплаты как настраиваемая сущность.
///
/// Чистый Dart: ни Flutter, ни drift. Строка `payment_kinds` в базе, член
/// каталога [PaymentKindCatalog] в домене.
///
/// # Чего здесь нет и почему
///
/// **`mixed` в справочнике нет.** Смешанная оплата перестаёт быть видом и
/// становится тем, чем всегда была, — **двумя строками**. Вид отвечает на
/// вопрос «чем заплатили», и ответ «двумя разными вещами» — не ответ.
///
/// **Удаления вида нет и не будет.** `Payments.kindId` ссылается на
/// строку справочника навсегда: чек трёхлетней давности обязан читаться.
/// [isActive] `= false` убирает вид из селектора и оставляет его в
/// истории.
@immutable
class PaymentKind {
  const PaymentKind({
    required this.id,
    required this.code,
    required this.name,
    required this.settlement,
    required this.fiscalTreatment,
    this.payeeAccountType,
    this.payeeAccountId,
    this.requiresAcquiring = false,
    this.requiresCounterparty = false,
    this.requiresProvider = false,
    this.givesChange = false,
    this.refundAllowed = true,
    this.isActive = true,
    this.isSystem = false,
    this.isSelectable = true,
    this.sortOrder = 0,
  });

  /// Ид, присвоенный руками. Системные — 1–9
  /// ([SystemPaymentKindIds]), пользовательские — от
  /// [SystemPaymentKindIds.firstUserId].
  final int id;

  /// Короткое имя на проводе и в настройках: `cash`, `card`, `debt`…
  final String code;

  /// Как вид называется кассиру.
  final String name;

  /// Тендер, зачёт или обязательство.
  final PaymentSettlement settlement;

  /// Как вид называется **в фискальном документе**.
  final FiscalTreatment fiscalTreatment;

  /// Род счёта-получателя ([AccountType]) — правило, а не конкретная
  /// строка.
  ///
  /// Счёт кассы у каждой кассы свой; хранить его ид в справочнике,
  /// который синхронизируется между кассами, значило бы разослать чужой
  /// номер счёта. Род — общий.
  final int? payeeAccountType;

  /// Конкретный счёт-получатель, если оператор назвал именно его.
  ///
  /// Заполняется только у **пользовательских** видов и только на той
  /// кассе, где заведён: в выгрузку не едет.
  final int? payeeAccountId;

  /// Вид требует проведения через эквайринг.
  final bool requiresAcquiring;

  /// Вид требует названного контрагента: долг, рассрочка.
  final bool requiresCounterparty;

  /// Вид требует названного провайдера (`Payments.providerCode`): QR/СБП.
  final bool requiresProvider;

  /// Вид участвует в сдаче.
  ///
  /// У сертификата — **`false`, и это не мелочь**: сдача с сертификата
  /// превращает его в способ обналичить.
  final bool givesChange;

  /// На этот вид разрешён возврат.
  final bool refundAllowed;

  /// Вид доступен к выбору. Выключенный остаётся в истории.
  final bool isActive;

  /// Системный вид: ид и код менять нельзя.
  final bool isSystem;

  /// Вид показывается в селекторе оплаты.
  ///
  /// [SystemPaymentKindIds.agentSettlement] — единственный сегодня, у
  /// кого здесь `false`.
  final bool isSelectable;

  final int sortOrder;

  /// Строка этого вида приносит в кассу живые деньги.
  bool get isTender => settlement == PaymentSettlement.tender;

  /// Строка этого вида — обязательство, а не деньги.
  ///
  /// Читается двумя денежными местами: завершением продажи (такая строка
  /// не двигает счёт-получатель обычным движением, а уводит в минус счёт
  /// покупателя) и возвратом (такая строка **не выходит из ящика**).
  bool get isDeferred => settlement == PaymentSettlement.deferred;

  PaymentKind copyWith({
    String? code,
    String? name,
    PaymentSettlement? settlement,
    FiscalTreatment? fiscalTreatment,
    int? payeeAccountType,
    bool clearPayeeAccountType = false,
    int? payeeAccountId,
    bool clearPayeeAccountId = false,
    bool? requiresAcquiring,
    bool? requiresCounterparty,
    bool? requiresProvider,
    bool? givesChange,
    bool? refundAllowed,
    bool? isActive,
    bool? isSystem,
    bool? isSelectable,
    int? sortOrder,
  }) => PaymentKind(
    id: id,
    code: code ?? this.code,
    name: name ?? this.name,
    settlement: settlement ?? this.settlement,
    fiscalTreatment: fiscalTreatment ?? this.fiscalTreatment,
    payeeAccountType: clearPayeeAccountType
        ? null
        : (payeeAccountType ?? this.payeeAccountType),
    payeeAccountId: clearPayeeAccountId
        ? null
        : (payeeAccountId ?? this.payeeAccountId),
    requiresAcquiring: requiresAcquiring ?? this.requiresAcquiring,
    requiresCounterparty: requiresCounterparty ?? this.requiresCounterparty,
    requiresProvider: requiresProvider ?? this.requiresProvider,
    givesChange: givesChange ?? this.givesChange,
    refundAllowed: refundAllowed ?? this.refundAllowed,
    isActive: isActive ?? this.isActive,
    isSystem: isSystem ?? this.isSystem,
    isSelectable: isSelectable ?? this.isSelectable,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  @override
  bool operator ==(Object other) =>
      other is PaymentKind &&
      other.id == id &&
      other.code == code &&
      other.name == name &&
      other.settlement == settlement &&
      other.fiscalTreatment == fiscalTreatment &&
      other.payeeAccountType == payeeAccountType &&
      other.payeeAccountId == payeeAccountId &&
      other.requiresAcquiring == requiresAcquiring &&
      other.requiresCounterparty == requiresCounterparty &&
      other.requiresProvider == requiresProvider &&
      other.givesChange == givesChange &&
      other.refundAllowed == refundAllowed &&
      other.isActive == isActive &&
      other.isSystem == isSystem &&
      other.isSelectable == isSelectable;

  @override
  int get hashCode => Object.hash(
    id,
    code,
    name,
    settlement,
    fiscalTreatment,
    payeeAccountType,
    payeeAccountId,
    requiresAcquiring,
    requiresCounterparty,
    requiresProvider,
    givesChange,
    refundAllowed,
    Object.hash(isActive, isSystem, isSelectable),
  );

  @override
  String toString() => 'PaymentKind($id, $code, ${settlement.name})';
}

/// Девять системных видов — **посев справочника и единственное место, где
/// они объявлены**.
///
/// Читается миграцией v41 (посев) и пробами. Продукт читает **базу**, а не
/// этот список: справочник настраиваемый, и вид, выключенный оператором,
/// обязан быть выключенным и для продукта.
abstract final class SystemPaymentKinds {
  /// Виды 5–8 (`certificate`, `qr`, `prepayment`, `installment`)
  /// заводятся **выключенными** и на существующих кассах, и на новых:
  /// включить вид за оператора значит записать решение, которого он не
  /// принимал.
  ///
  /// **Фискальная трактовка у выключенных — начальная, а не
  /// окончательная.** Набор оператора беден (пять членов
  /// [FiscalPaymentKind]), отдельного «сертификата» или «аванса» в нём
  /// нет, и правильный ответ зависит от страны и от договора с
  /// оператором. Здесь стоит ближайшее по смыслу; оператор подтверждает
  /// его тем же движением, которым включает вид.
  static const List<PaymentKind> all = <PaymentKind>[
    PaymentKind(
      id: SystemPaymentKindIds.cash,
      code: 'cash',
      name: 'Наличные',
      settlement: PaymentSettlement.tender,
      fiscalTreatment: FiscalTreatment.cash,
      payeeAccountType: AccountType.pos,
      givesChange: true,
      isSystem: true,
      sortOrder: 10,
    ),
    PaymentKind(
      id: SystemPaymentKindIds.card,
      code: 'card',
      name: 'Карта',
      settlement: PaymentSettlement.tender,
      fiscalTreatment: FiscalTreatment.card,
      payeeAccountType: AccountType.customBank,
      requiresAcquiring: true,
      isSystem: true,
      sortOrder: 20,
    ),
    PaymentKind(
      id: SystemPaymentKindIds.bonus,
      code: 'bonus',
      name: 'Бонус',
      settlement: PaymentSettlement.offset,
      // **Скидка, а не платёж.** Разбор — [FiscalTreatment.notAPayment].
      fiscalTreatment: FiscalTreatment.notAPayment,
      payeeAccountType: AccountType.cashback,
      isSystem: true,
      sortOrder: 30,
    ),
    PaymentKind(
      id: SystemPaymentKindIds.debt,
      code: 'debt',
      name: 'В долг',
      settlement: PaymentSettlement.deferred,
      fiscalTreatment: FiscalTreatment.credit,
      payeeAccountType: AccountType.agentMain,
      requiresCounterparty: true,
      isSystem: true,
      sortOrder: 40,
    ),
    PaymentKind(
      id: SystemPaymentKindIds.certificate,
      code: 'certificate',
      name: 'Сертификат',
      settlement: PaymentSettlement.offset,
      // **Начальная трактовка, а не окончательная — и код её нигде не
      // повторяет.** Отдельного «сертификата» у оператора нет (пять членов
      // [FiscalPaymentKind]), и правильный ответ зависит от страны и
      // договора. Здесь стоит ближайшее по смыслу; оператор подтверждает
      // его тем же движением, которым включает вид. Гашение читает
      // **строку справочника** (`FiscalPositionBuilder` через
      // `PaymentKind.fiscalTreatment`), а не эту константу, — поэтому
      // смена трактовки настройкой меняет то, что уезжает оператору, и не
      // требует ни правки кода, ни миграции.
      //
      // **С v47 — `offsetNotFiscal`, и это решение заказчика 2026-09-14**, а
      // не ближайшее по смыслу: гашение сертификата — не денежный расчёт
      // (КГД 2020, 2021), и `cash` врал оператору о деньгах в ящике. Даже
      // перенастроенный оператором в платёж, этот вид оплатой не уедет —
      // сторож `FiscalOffsetSettings.effectiveTreatment`.
      fiscalTreatment: FiscalTreatment.offsetNotFiscal,
      // Счёт-получатель — **обязательство кассы**, а не выручка: деньги за
      // сертификат пришли раньше и уже посчитаны выручкой той смены.
      // Положить их в выручку второй раз, при гашении, значит удвоить
      // выручку. Род появился в задаче 21 ([AccountType.certificateLiability]);
      // на кассах, прошедших v41 с пустым полем, его проставляет миграция
      // v42 — `_pointCertificateKindAtLiabilityAccount`.
      payeeAccountType: AccountType.certificateLiability,
      // **`false`, и это не мелочь**: сдача с сертификата превращает его в
      // способ обналичить. Разбор решения «остаток остаётся на
      // сертификате, а не выдаётся деньгами» — в докстринге
      // `LocalCertificateIssuer`.
      givesChange: false,
      isActive: false,
      isSystem: true,
      sortOrder: 50,
    ),
    PaymentKind(
      id: SystemPaymentKindIds.qr,
      code: 'qr',
      name: 'QR / СБП',
      settlement: PaymentSettlement.tender,
      fiscalTreatment: FiscalTreatment.mobile,
      payeeAccountType: AccountType.customBank,
      requiresProvider: true,
      isActive: false,
      isSystem: true,
      sortOrder: 60,
    ),
    PaymentKind(
      id: SystemPaymentKindIds.prepayment,
      code: 'prepayment',
      name: 'Предоплата',
      settlement: PaymentSettlement.offset,
      // **`cash` — посчитанный ответ, а не «ближайшее по смыслу»**
      // (задача 23). Приём аванса и зачёт аванса — разные документы, и
      // выручку признаёт второй: приём кладёт деньги на расчётный счёт
      // покупателя и выручки не создаёт, значит на чеке отгрузки те же
      // деньги признаются впервые, и назвать их надо тем, чем платили.
      //
      // Повторить решение бонуса нельзя: [FiscalTreatment.notAPayment]
      // уводит сумму в скидку позиции, а товар по авансу продан за
      // полную цену — скидка занизила бы базу налога.
      //
      // Цена названа: аванс, принятый картой, уедет наличными. Приём
      // аванса сегодня не хранит, чем платили; это долг приёма.
      //
      // **С v47 довод выше снят решением заказчика 2026-09-14.** Приём аванса
      // даёт свой фискальный чек (настройка, по умолчанию вкл) с фактическим
      // типом оплаты и хранит, чем принят (`cash_operations.kind_id`). Значит
      // выручку по ККМ признал уже приём, и зачёт наличными — двойная выручка.
      // Посев — `offsetNotFiscal`; перенастроенный оператором в `cash`, зачёт
      // при фискализованном приёме оплатой всё равно не уедет — сторож
      // `FiscalOffsetSettings.effectiveTreatment`.
      fiscalTreatment: FiscalTreatment.offsetNotFiscal,
      // **Счёт-получатель — расчётный счёт покупателя**, тот же самый,
      // который уходит в минус при продаже в долг. Плюс — покупатель
      // внёс вперёд, минус — покупатель должен, и остаток аванса это
      // кредитовое сальдо, а не второй остаток рядом.
      //
      // Названо здесь, а не оставлено пустым, как у сертификата, по
      // измеренной причине: правило 4 (`kind_account_missing`)
      // отказывает **включить** зачёт без счёта, а значит вид без этого
      // поля из продукта включить нельзя вовсе.
      payeeAccountType: AccountType.agentMain,
      // Аванс всегда чей-то: зачёт без покупателя — зачёт с
      // неизвестного счёта.
      requiresCounterparty: true,
      isActive: false,
      isSystem: true,
      sortOrder: 70,
    ),
    PaymentKind(
      id: SystemPaymentKindIds.installment,
      code: 'installment',
      name: 'Рассрочка',
      settlement: PaymentSettlement.deferred,
      fiscalTreatment: FiscalTreatment.credit,
      payeeAccountType: AccountType.agentMain,
      requiresCounterparty: true,
      isActive: false,
      isSystem: true,
      sortOrder: 80,
    ),
    PaymentKind(
      id: SystemPaymentKindIds.agentSettlement,
      code: 'agent_settlement',
      name: 'Расчёт с контрагентом',
      settlement: PaymentSettlement.offset,
      fiscalTreatment: FiscalTreatment.notAPayment,
      payeeAccountType: AccountType.agentMain,
      isSelectable: false,
      isSystem: true,
      sortOrder: 900,
    ),
  ];

  static PaymentKind byId(int id) =>
      all.firstWhere((k) => k.id == id, orElse: () => throw ArgumentError(id));
}
