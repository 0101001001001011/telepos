import 'package:drift/drift.dart';

/// Справочник видов оплаты — задача 14, схема v41.
///
/// # Что было вместо него
///
/// **Ничего.** У таблицы `Payments` не было колонки вида оплаты вообще:
/// вид выводился из рода счёта-получателя, и таких мест было **десять**
/// (разбор — `PaymentKindDerivation`). Следствий три, и каждое измерено:
///
/// 1. **Бонус не доезжал до оператора** осмысленным словом: строка на
///    бонусном счёте выглядела «оплатой», и объявить её платежом значило
///    завысить базу налога.
/// 2. **Сертификату и предоплате некуда лечь** — рода счёта под них нет,
///    а другого способа сказать «это сертификат» у строки не было.
/// 3. **У долга не было строки оплаты вовсе**: он выводился разностью
///    «сумма чека минус сумма платежей». Замер — продажа в долг на 1000 с
///    300 наличными оставляла в `Payments` **одну** строку на 300
///    (`test/data/sale/local_payment_service_debt_toggle_test.dart`).
///
/// Инвариант «Σ строк оплаты == сумма чека» был нарушен трижды. Эта
/// таблица закрывает третье, а первые два делает выразимыми.
///
/// # Почему ид присваиваются руками
///
/// `Payments.kindId` уезжает в выгрузку вместе с чеком, а чеки
/// синхронизируются между кассами сети. Автоинкремент дал бы двум кассам
/// **разный ид под одним смыслом**. Системные — 1–9
/// (`SystemPaymentKindIds`), пользовательские — со 100.
///
/// # Удаления вида нет
///
/// `Payments.kindId` ссылается на строку справочника навсегда: чек
/// трёхлетней давности обязан читаться. [isActive] `= false` убирает вид
/// из селектора и оставляет его в истории. Метода `delete` нет ни у DAO,
/// ни у контракта.
/// Имя строки — `PaymentKindEntry`, а не `PaymentKind`: последнее занято
/// доменной моделью (`lib/domain/payment/payment_kind.dart`), и два класса
/// под одним именем в одном ввозе — гарантированная путаница у читателя,
/// который не смотрит на импорты.
@DataClassName('PaymentKindEntry')
class PaymentKinds extends Table {
  /// Ид, присвоенный руками, — **не автоинкремент**. Разбор выше.
  IntColumn get id => integer()();

  /// Короткое имя на проводе и в настройках: `cash`, `card`, `debt`…
  TextColumn get code => text().withLength(min: 1, max: 64)();

  TextColumn get name => text().withLength(min: 1, max: 128)();

  /// `PaymentSettlement` числом: 0 — тендер, 1 — зачёт, 2 —
  /// обязательство.
  ///
  /// **Три значения, а не два.** Нехватка третьего и есть причина, по
  /// которой долг жил разностью.
  IntColumn get settlement => integer()();

  /// `FiscalTreatment` **стабильным кодом-строкой**, а не индексом члена.
  ///
  /// Индекс меняется от перестановки в объявлении, а на диске лежат чеки
  /// трёхлетней давности.
  TextColumn get fiscalTreatment => text().withLength(min: 1, max: 32)();

  /// Род счёта-получателя (`AccountType`) — правило, а не строка.
  ///
  /// Счёт кассы у каждой кассы свой; хранить его ид в справочнике,
  /// который синхронизируется между кассами, значило бы разослать чужой
  /// номер счёта.
  IntColumn get payeeAccountType => integer().nullable()();

  /// Конкретный счёт-получатель, если оператор назвал именно его. Только
  /// у пользовательских видов и только на своей кассе.
  IntColumn get payeeAccountId => integer().nullable()();

  BoolColumn get requiresAcquiring =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get requiresCounterparty =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get requiresProvider =>
      boolean().withDefault(const Constant(false))();

  /// Вид участвует в сдаче. У сертификата — `false`: сдача с сертификата
  /// превращает его в способ обналичить.
  BoolColumn get givesChange => boolean().withDefault(const Constant(false))();

  BoolColumn get refundAllowed => boolean().withDefault(const Constant(true))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();

  /// Вид показывается в селекторе оплаты. `agent_settlement` — нет.
  BoolColumn get isSelectable => boolean().withDefault(const Constant(true))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {code},
  ];
}
