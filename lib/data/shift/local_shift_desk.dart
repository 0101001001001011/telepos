import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';

import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/shift/shift_age_rule.dart';
import 'package:telepos/data/database/watch_source.dart';
import 'package:telepos/data/services/shift_service_impl.dart';
import 'package:telepos/domain/services/shift_service.dart';
import 'package:telepos/domain/shift/shift_desk.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

/// Смена на самой кассе — та половина порта, у которой есть база.
///
/// # Один бухгалтер, два вызывающих
///
/// До 2026-09-18 закрытие смены жило **целиком в контроллере экрана**
/// (`ShiftNotifier.closeShift`): уборка начатых чеков, выбор суммы
/// («насчитали» против «системный итог»), запись расхождения излишком или
/// недостачей и только потом `ShiftService.onCloseShift`. Всё это — поверх
/// `GetIt.I<AppDatabase>()` прямо из презентационного слоя.
///
/// Написать рядом вторую такую же процедуру для провода было бы худшим из
/// возможного: касса закрывала бы смену одним способом, планшет — другим, и
/// расходились бы они не в цвете кнопки, а **в деньгах** — расхождение,
/// записанное одним путём и не записанное другим, не ловится ни
/// инвентаризацией, ни отчётом смены.
///
/// Поэтому процедура переехала сюда целиком, а `ShiftNotifier.closeShift`
/// стал её вызывающим — вторым, наравне с обработчиком провода. Экран кассы
/// от этого не изменился ни на копейку: те же запросы, тот же порядок, та же
/// арифметика.
///
/// # Что считает касса, а что приносит вкладка
///
/// Вкладка приносит **одно число — пересчитанные деньги**, и разбор, почему
/// только его, — в докстринге [ShiftDeskRepository]. Всё остальное считается
/// здесь, над собственным журналом кассы.
///
/// # Секунды, не миллисекунды
///
/// `Shifts.openTime` — секунды. Каждое чтение здесь идёт в секундах и
/// сравнивается с секундами; ни одного `* 1000` в расчётах нет, они бывают
/// только на показе.
class LocalShiftDesk implements ShiftDeskRepository {
  LocalShiftDesk({
    required AppDatabase db,
    this.actorUserId,
    ShiftService? shifts,
    Talker? logger,
    ShiftAgeRule? age,
  }) : _db = db,
       _logger = logger,
       // Служба смены собирается здесь, когда её не дали, — тем же приёмом и
       // по тому же доводу, что `LocalPaymentService` собирает выпуск
       // сертификатов и стойку QR: у неё нет ни одного состояния, зависящего
       // от вызывающего (всё в базе), а требовать её доводом значило бы
       // тащить новый обязательный довод через `TillOperations`, `ApiServer`
       // и стенд живой проверки ради объекта без памяти.
       //
       // Кассовое DI довод **даёт** — там `ShiftService` уже синглтон, и
       // второго заводить незачем.
       _shifts = shifts ?? ShiftServiceImpl(db: db, logger: logger ?? Talker()),
       _age = age ?? ShiftAgeRule(db: db);

  /// Кто действует — **доводом постройки, а не доводом вызова**.
  ///
  /// Обработчик провода строит эту стойку на каждый запрос и кладёт сюда
  /// `AuthSession.userId` — то есть того, чьим сеансом заявка пришла.
  /// Приди кассир доводом метода, он пришёл бы из тела кадра, и любой
  /// вошедший открывал бы смену на чужое имя: именем смены подписан
  /// Z-отчёт и вся её выручка (И162, тот же приём, каким оплата берёт
  /// рабочее место из сеанса, а не из тела).
  ///
  /// `null` — действующего нет (петля, голый процесс). Тогда открытие
  /// отказывает названной причиной, а не открывает смену на кассира `0`.
  final int? actorUserId;

  final AppDatabase _db;
  final ShiftService _shifts;
  final Talker? _logger;

  /// Правило возраста — **то же самое**, которым касса запирает продажу.
  ///
  /// Не своя проверка «сутки прошли»: значок на доме терминала обязан
  /// говорить то же, что скажет продажа, а два счёта возраста разошлись бы
  /// на первой же правке предела.
  final ShiftAgeRule _age;

  @override
  Stream<ShiftDeskView> watch() => watchTables(_db, [
    // Смена — очевидно. Продажи и оплаты — потому что от них зависят
    // наличная выручка и число незаконченных чеков; кассовые операции и
    // счета — потому что от них зависят «должно быть» и «есть по журналу».
    // Сигнал приходит по таблице, а не по строке (докстринг `watchTables`):
    // кадр может уйти и тогда, когда по существу ничего не изменилось, —
    // значение в нём всегда верное, и это дешевле списка того, что кого
    // касается.
    _db.shifts,
    _db.sales,
    _db.payments,
    _db.cashOperations,
    _db.accounts,
  ], read);

  /// Состояние смены — то же чтение, которым отвечает подписка.
  Future<ShiftDeskView> read() async {
    final shift = await _db.shiftDao.findOpenedShift();
    if (shift == null || !shift.isOpened) return ShiftDeskView.closed;

    final cash = await _cashTotals(shift.openTime);
    final sales = await _salesTotals(shift.openTime);
    final openingCash = shift.openingCash ?? Decimal.zero;
    final unfiscalized = await _unfiscalized();

    return ShiftDeskView(
      open: true,
      // Возраст считает правило кассы, не этот файл (см. [_age]).
      overAge: await _age.isOverAge(),
      openedAtSeconds: shift.openTime,
      cashierName: await _cashierName(),
      openingCash: openingCash,
      systemTotal: await _systemTotal(),
      // Та же формула, что у `ShiftState.expectedCash`: начало + наличная
      // выручка − наличные возвраты − (изъятия + дивиденды).
      expectedCash:
          openingCash +
          sales.cashSales -
          sales.cashRefunds -
          (cash.expense + cash.dividend),
      unfinishedSales: await _unfinishedSales(),
      unfiscalizedCount: unfiscalized.count,
      unfiscalizedReceipts: unfiscalized.receiptNumbers,
    );
  }

  @override
  Future<void> close({Decimal? counted}) async {
    final shift = await _db.shiftDao.findOpenedShift();
    if (shift == null || !shift.isOpened) {
      // Названный отказ, а не молчаливый успех: `onCloseShift` без открытой
      // смены пишет предупреждение в журнал и возвращается — по проводу это
      // прочлось бы как «закрыл». Разбор — в докстринге [shiftNotOpenCode].
      throw const WireRefusal(
        shiftNotOpenCode,
        'на этой кассе нет открытой смены',
      );
    }

    // Числа снимаются **до уборки**, и это не мелочь порядка: уборка сносит
    // начатые чеки вместе с их строками и оплатами, то есть меняет ровно ту
    // наличную выручку, из которой считается «должно быть». Экран кассы
    // считал расхождение по числам, снятым до уборки (`state` был загружен
    // раньше, `_persistReconciliation` читал его), — здесь тот же порядок,
    // иначе закрытие с планшета писало бы другую недостачу, чем закрытие с
    // кассы.
    final before = await read();

    await _cleanUpUnfinishedSales();

    // «Насчитали» против «системного итога» — **то же правило**, каким жил
    // кассовый экран (`hasCounted ? enteredTotal : systemTotal`). `null`
    // означает «никто не считал», а не ноль: ноль в ящике — законный
    // результат пересчёта (докстринг [ShiftDeskRepository.close]).
    final cashInPos = counted ?? before.systemTotal;

    await _persistReconciliation(shift, counted, before.expectedCash);

    await _shifts.onCloseShift(cashInPos);
    _logger?.info(
      'ShiftDesk: closed shift=${shift.id} cashInPos=$cashInPos '
      'counted=${counted ?? 'не считали'}',
    );
  }

  @override
  Future<void> open({Decimal? openingCash}) async {
    final user = actorUserId;
    if (user == null) {
      throw const WireRefusal(
        shiftActorUnknownCode,
        'смену открывает кассир, а этой заявке кассира назвать нечем',
      );
    }
    final existing = await _db.shiftDao.findOpenedShift();
    if (existing != null && existing.isOpened) {
      throw const WireRefusal(
        shiftAlreadyOpenCode,
        'на этой кассе уже открыта смена',
      );
    }
    await _shifts.onOpenShift(user, openingCash: openingCash);
    _logger?.info('ShiftDesk: opened shift for user=$user');
  }

  /// Незаконченные чеки смены прибираются **до** закрытия — тем же запросом
  /// и в том же порядке, что делал `ShiftNotifier.closeShift`.
  ///
  /// Строки и оплаты сносятся раньше самого чека: обратный порядок оставил
  /// бы строки без чека — те самые сироты, которые потом не находятся ничем.
  Future<void> _cleanUpUnfinishedSales() async {
    final inProgress = await _db.saleDao.findByState(0);
    for (final sale in inProgress) {
      await _db.saleProductDao.deleteBySale(sale.receiptNo, sale.posId);
      await _db.paymentDao.deleteBySale(sale.receiptNo, sale.posId);
      await (_db.delete(_db.sales)..where(
            (s) =>
                s.receiptNo.equals(sale.receiptNo) & s.posId.equals(sale.posId),
          ))
          .go();
      _logger?.info(
        'ShiftDesk: cleaned up IN_PROGRESS sale receipt=${sale.receiptNo}',
      );
    }
  }

  /// Излишек или недостача — кассовой операцией, как и на экране кассы.
  ///
  /// **Не пишется вовсе, когда никто не считал** ([counted] `null`):
  /// расхождение — это разница между пересчитанным и ожидаемым, и без
  /// пересчёта сравнивать не с чем. Записать здесь ноль значило бы утверждать
  /// «сошлось», а не «не проверяли».
  ///
  /// Отказ записи расхождения **не отменяет закрытия смены**, и это не
  /// небрежность: кассир не должен оставаться с открытой сменой из-за того,
  /// что не нашёлся счёт кассы. Беда уходит в журнал — тем же приёмом, что
  /// и в `ShiftNotifier._persistReconciliation`, откуда эта процедура и
  /// переехала.
  Future<void> _persistReconciliation(
    Shift shift,
    Decimal? counted,
    Decimal expected,
  ) async {
    if (counted == null) return;
    try {
      final reconciliation = counted - expected;
      if (reconciliation == Decimal.zero) return;

      final isOverage = reconciliation > Decimal.zero;
      final accountId = await _posAccountId();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _db.cashOperationDao.insert(
        CashOperationsCompanion.insert(
          amount: reconciliation,
          // 0 — внесение, 1 — изъятие: `CashOperationType.index`, тот же
          // порядок, каким их читает `_loadCashOperations` экрана смены.
          type: isOverage ? 0 : 1,
          accountId: Value(accountId),
          userId: Value(shift.userId),
          note: Value(isOverage ? 'Излишек смены' : 'Недостача смены'),
          docTime: Value(now),
          state: const Value(1),
        ),
      );
      _logger?.info(
        'ShiftDesk: reconciliation shift=${shift.id} amount=$reconciliation '
        '(${isOverage ? 'излишек' : 'недостача'})',
      );
    } catch (e, st) {
      _logger?.error('ShiftDesk: reconciliation failed: $e', e, st);
    }
  }

  /// Счёт кассы: у `thisPos`, а при пустой ссылке — первый счёт типа
  /// [AccountType.pos].
  ///
  /// Запасной путь не украшение: `thisPos.accountId` в этом дереве бывает
  /// пустым, и это записанное правило проекта, а не гипотеза.
  Future<int?> _posAccountId() async {
    final thisPos = await _db.thisPosDao.get();
    final linked = thisPos?.accountId;
    if (linked != null) return linked;
    final accounts = await _db.accountDao.findByType(AccountType.pos);
    return accounts.isEmpty ? null : accounts.first.id;
  }

  /// Сколько в ящике по журналу кассы — остаток её счёта.
  Future<Decimal> _systemTotal() async {
    try {
      final id = await _posAccountId();
      if (id == null) return Decimal.zero;
      return (await _db.accountDao.findById(id))?.value ?? Decimal.zero;
    } catch (e) {
      _logger?.error('ShiftDesk: systemTotal failed: $e');
      return Decimal.zero;
    }
  }

  Future<String?> _cashierName() async {
    try {
      final row = await _db.shiftDao.findCurrentUser();
      return row?.data['name'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Изъятия и дивиденды смены. Внесения здесь не считаются: в «должно
  /// быть» они уже вошли выручкой, и вычитать их не из чего.
  Future<({Decimal expense, Decimal dividend})> _cashTotals(
    int shiftOpenTime,
  ) async {
    var expense = Decimal.zero;
    var dividend = Decimal.zero;
    try {
      final rows = await _db
          .customSelect(
            'SELECT type, COALESCE(SUM(amount), 0) as total '
            'FROM cash_operations WHERE doc_time >= ? GROUP BY type',
            variables: [Variable.withInt(shiftOpenTime)],
            readsFrom: {_db.cashOperations},
          )
          .get();
      for (final row in rows) {
        final total = Decimal.parse(
          row.read<double>('total').toStringAsFixed(3),
        );
        // 0 — внесение (в «должно быть» оно уже вошло выручкой), 1 —
        // изъятие, **всё остальное** — дивиденд. Именно `default`, а не
        // `case 2`: экран кассы читает типы тем же правилом
        // (`_loadCashOperations`: `0 => investment, 1 => expense, _ =>
        // dividend`), и тип 3, появись он завтра, у экрана вычитался бы, а
        // здесь — молча нет.
        switch (row.read<int>('type')) {
          case 0:
            break;
          case 1:
            expense += total;
          default:
            dividend += total;
        }
      }
    } catch (e) {
      _logger?.error('ShiftDesk: cashTotals failed: $e');
    }
    return (expense: expense, dividend: dividend);
  }

  /// Наличная выручка и наличные возвраты смены — **теми же двумя
  /// запросами**, что у экрана смены (`ShiftNotifier._loadSalesTotals`).
  ///
  /// # Два запроса, а не один с разбором знака
  ///
  /// Первая редакция этого метода брала один запрос
  /// (`receipt_no IS NOT NULL`) и делила суммы по знаку: положительные —
  /// выручка, отрицательные — возвраты. Это **молча теряло все возвраты**:
  /// строка оплаты возврата ссылается на `refund_local_id`, а не на
  /// `receipt_no`, и в выборку не попадала вовсе. «Должно быть» выходило
  /// завышенным ровно на сумму наличных возвратов смены, и на столько же
  /// врало расхождение — то есть закрытие смены писало бы недостачу там,
  /// где всё сошлось.
  ///
  /// Найдено сличением с экраном кассы при переносе процедуры, а не
  /// прогоном: набор был зелен — в его смене возвратов не было. Сторож
  /// заведён тем же кругом: «наличный возврат уменьшает „должно быть“».
  Future<({Decimal cashSales, Decimal cashRefunds})> _salesTotals(
    int shiftOpenTime,
  ) async {
    var cashSales = Decimal.zero;
    var cashRefunds = Decimal.zero;
    try {
      final sales = await _db
          .customSelect(
            'SELECT COALESCE(SUM(p.amount), 0) as total '
            'FROM payments p JOIN accounts a ON a.id = p.payee_account_id '
            'WHERE p.time >= ? AND p.receipt_no IS NOT NULL '
            'AND a.type IN (0, 2)',
            variables: [Variable.withInt(shiftOpenTime)],
            readsFrom: {_db.payments, _db.accounts},
          )
          .getSingle();
      cashSales = Decimal.parse(sales.read<double>('total').toStringAsFixed(2));

      // Возврат ссылается на `refund_local_id`, а не на `receipt_no`, и
      // сумма берётся со знаком минус в самом запросе — ровно как на
      // экране кассы.
      final refunds = await _db
          .customSelect(
            'SELECT COALESCE(SUM(-p.amount), 0) as total '
            'FROM payments p JOIN accounts a ON a.id = p.payee_account_id '
            'WHERE p.refund_local_id IS NOT NULL AND p.time >= ? '
            'AND a.type IN (0, 2)',
            variables: [Variable.withInt(shiftOpenTime)],
            readsFrom: {_db.payments, _db.accounts},
          )
          .getSingle();
      cashRefunds = Decimal.parse(
        refunds.read<double>('total').toStringAsFixed(2),
      );
    } catch (e) {
      _logger?.error('ShiftDesk: salesTotals failed: $e');
    }
    return (cashSales: cashSales, cashRefunds: cashRefunds);
  }

  /// Начатые и отложенные чеки — тем же счётом, что у экрана смены.
  Future<int> _unfinishedSales() async {
    try {
      final started = await _db
          .customSelect(
            'SELECT COUNT(*) as cnt FROM sales s '
            'WHERE s.state = 0 AND (s.amount > 0.001 OR EXISTS '
            '(SELECT 1 FROM sale_products sp '
            'WHERE sp.receipt_no = s.receipt_no AND sp.pos_id = s.pos_id))',
            readsFrom: {_db.sales, _db.saleProducts},
          )
          .getSingle();
      final deferred = await _db.saleDao.countWithState(3);
      return started.read<int>('cnt') + deferred;
    } catch (e) {
      _logger?.error('ShiftDesk: unfinishedSales failed: $e');
      return 0;
    }
  }

  /// Чеки без фискального документа — спрашивается у той же службы, что
  /// отвечает кассовому экрану.
  Future<UnfiscalizedAtClose> _unfiscalized() async {
    try {
      return await _shifts.unfiscalizedAtClose();
    } catch (e) {
      _logger?.error('ShiftDesk: unfiscalized failed: $e');
      return UnfiscalizedAtClose.empty;
    }
  }
}
