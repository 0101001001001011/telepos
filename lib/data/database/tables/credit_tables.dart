import 'package:drift/drift.dart';

/// Кредитный договор — задача 24, схема v45.
///
/// Зачем сущность вообще нужна и где проходит граница с банковским
/// модулем — в докстринге `lib/domain/payment/credit_contract.dart`. Здесь
/// только то, что относится к форме хранения.
///
/// # Удаления нет
///
/// `Payments.reference` ссылается на [number] навсегда, и по нему же
/// ищется погашение. Ошибочно заключённый договор — это
/// `CreditContractStatus.cancelled`, а не `DELETE`: товар по нему уже
/// отдан, и строка чека обязана объяснять, чем он оплачен, и через три
/// года.
///
/// # Два уникальных ключа, и они про разное
///
/// [number] — чтобы номер не повторился: по номеру ищут погашение, и два
/// договора под одним номером означают платёж, ушедший не туда.
///
/// `{receiptNo, posId}` — чтобы **на один чек не легло два договора**.
/// Это второй заслон; первый объясняет кассиру
/// (`credit_contract_duplicate`), второй не даёт беде случиться, когда
/// объяснять некому: между проверкой и вставкой есть окно, и закрывает
/// его только ключ.
@DataClassName('CreditContractRow')
class CreditContracts extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Номер, напечатанный на договоре. Выдаёт касса
  /// (`CreditContractNumber.of`), а не оператор руками.
  TextColumn get number => text().withLength(min: 1, max: 64)();

  /// Должник.
  IntColumn get agentLocalId => integer()();

  /// Счёт задолженности — **снимок на момент заключения**, а не ссылка на
  /// живое `Agents.mainAccountId`: счёт могут сменить, долг обязан
  /// остаться там, где записан.
  IntColumn get receivableAccountId => integer()();

  IntColumn get receiptNo => integer()();

  IntColumn get posId => integer()();

  /// Тело договора, **целыми тысячными**. Разбор масштаба — в докстринге
  /// `MoneyMillis`: разнесение платежа это условная запись внутри SQL, а
  /// вычитание `double` там теряет копейки молча.
  IntColumn get principalMillis => integer()();

  /// Надбавка целиком, целыми тысячными. У договоров, заключённых кассой,
  /// — ноль; разбор в докстринге `CreditContract`.
  IntColumn get feeTotalMillis => integer()();

  /// Первый взнос: сколько отдано деньгами на кассе. В график не входит.
  IntColumn get downPaymentMillis => integer()();

  IntColumn get termMonths => integer()();

  /// `InstallmentScheme` **стабильным кодом-строкой**, а не индексом
  /// члена.
  TextColumn get scheme => text().withLength(min: 1, max: 24)();

  /// `CreditContractStatus` стабильным кодом-строкой.
  TextColumn get status => text().withLength(min: 1, max: 16)();

  /// Секунды эпохи — тем же масштабом, что `payments.time`.
  IntColumn get signedAt => integer()();

  IntColumn get signedByUserId => integer().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {number},
    {receiptNo, posId},
  ];
}

/// Строка подписанного графика — задача 24, схема v45.
///
/// # Строки, а не формула
///
/// Аннуитет с округлением даёт остаток, который ложится в **последний**
/// платёж — так устроен любой подписанный договор. Пересчёт формулой на
/// каждом чтении рано или поздно даст другое число (сменилась версия,
/// сменилось правило округления), и оно **разойдётся с подписанным**.
/// Хранение строк — это хранение подписанного.
///
/// # Просрочки здесь НЕТ колонкой, и это решение
///
/// Просрочка вычисляется из [dueDate] и [paidMillis] на момент вопроса
/// (`CreditStanding.of`). Хранимую пришлось бы кем-то обновлять; фоновой
/// работы, переживающей выключение питания, в дереве нет, и на кассе,
/// простоявшей выключенной неделю, хранимое значение врало бы ровно
/// неделю — молча.
@DataClassName('CreditScheduleEntryRow')
class CreditScheduleEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get contractId => integer()();

  /// Номер в графике, **от нуля**. Погашение разносится FIFO по нему.
  IntColumn get seq => integer()();

  /// Срок платежа, секунды эпохи.
  IntColumn get dueDate => integer()();

  IntColumn get principalDueMillis => integer()();

  IntColumn get feeDueMillis => integer()();

  /// Сколько по строке внесено, целыми тысячными.
  ///
  /// Увеличивается **условной записью** `CreditDao.allocate`
  /// (`paid_millis + :x <= total_due_millis`) и только ею. Никакого
  /// `update(вычислено снаружи)`: между чтением и записью открывается
  /// ровно то окно, ради закрытия которого условная запись и заведена.
  IntColumn get paidMillis => integer().withDefault(const Constant(0))();

  /// Тело плюс надбавка — **хранится, а не складывается при чтении**.
  ///
  /// Условная запись сравнивает `paid_millis + :x` именно с этим числом,
  /// и складывать его в SQL из двух колонок значило бы повторить формулу
  /// в каждом запросе. Одна колонка — одно место, где можно ошибиться.
  IntColumn get totalDueMillis => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {contractId, seq},
  ];
}
