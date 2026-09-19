import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/sale_tables.dart';

part 'sale_dao.g.dart';

@DriftAccessor(tables: [Sales, SaleWithdrawals])
class SaleDao extends DatabaseAccessor<AppDatabase> with _$SaleDaoMixin {
  SaleDao(super.db);

  Future<Sale?> findByKey(int receiptNo, int posId) =>
      (select(sales)..where(
            (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId),
          ))
          .getSingleOrNull();

  Future<Sale?> findBySaleId(int saleId) =>
      (select(sales)..where((s) => s.saleId.equals(saleId))).getSingleOrNull();

  Future<int?> findLastReceiptNo() {
    final expr = sales.receiptNo.max();
    return (selectOnly(
      sales,
    )..addColumns([expr])).map((row) => row.read(expr)).getSingleOrNull();
  }

  /// Чек в работе **этого** рабочего места **на этой кассе**.
  ///
  /// Оба довода обязательны намеренно.
  ///
  /// **`terminalId`** — задача 3: до v37 метод означал «единственный чек
  /// кассы», рабочее место было одно, и `state = 0` определяло чек
  /// однозначно. С браузерным терминалом одной кассой пользуется больше
  /// одного места, и молчаливое умолчание вернуло бы чужой чек,
  /// продолженный как свой.
  ///
  /// **`posId`** — круг правки 3 задачи 7, и это была **не** та же
  /// ошибка, а её вторая половина. Первичный ключ `Sales` составной,
  /// `{receiptNo, posId}`; выборка без кассы отбирает по двум третям
  /// признака владения. Проба разбора: строка `posId = 2, receiptNo = 1,
  /// state = 0, terminalId = 7` — и рабочее место седьмого терминала
  /// **показало чек соседней кассы своим и записало в него строку**.
  /// Строки чужой кассы попадают в базу штатно: обмен и слияние
  /// (`merge_tables_use_case_impl`, `couchdb_sync_coordinator`) тянут
  /// чеки других касс сети, а `findLastForeign` прямо на них рассчитан.
  ///
  /// Порядок в конце — не украшение и не замена предикату: круг правки 2
  /// добавил `orderBy`, чтобы выбор из нескольких строк был воспроизводим,
  /// и это **не сделало его верным** — воспроизводимо возвращалась чужая
  /// касса. Сужает выборку предикат, порядок только убирает произвол
  /// внутри уже верной.
  Future<Sale?> findInProgress({
    required int posId,
    required int terminalId,
  }) async {
    return (select(sales)
          ..where(
            (s) =>
                s.state.equals(0) &
                s.posId.equals(posId) &
                s.terminalId.equals(terminalId),
          )
          ..orderBy([(s) => OrderingTerm.asc(s.receiptNo)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Чек, к которому уже применена команда с ключом [key].
  ///
  /// Задача 7, защита от повтора (I160) для команд, **уводящих чек из
  /// работы**: после `defer` у рабочего места чека в работе нет, и
  /// [findInProgress] повтор той же команды опознать уже не может —
  /// повтор получил бы «нет корзины» вместо того же ответа. Ключ
  /// порождается терминалом и обязан быть уникальным (uuid, не счётчик):
  /// поиск идёт по всей кассе, а не по одному рабочему месту, потому что
  /// у отложенного чека владельца нет по определению (правило смысла
  /// `Sales.terminalId`).
  Future<Sale?> findByCommandKey(int posId, String key) =>
      (select(sales)
            ..where((s) => s.posId.equals(posId) & s.lastCommandKey.equals(key))
            // Тот же довод, что у [findInProgress]: ключ обязан быть
            // уникальным, но `limit(1)` без порядка означает «доверимся»,
            // а не «проверим». Порядок делает ответ повторяемым, даже
            // если уникальность когда-нибудь нарушится.
            ..orderBy([(s) => OrderingTerm.asc(s.receiptNo)])
            ..limit(1))
          .getSingleOrNull();

  /// Меняет состояние чека и снимает владельца, если новое состояние —
  /// не «в работе».
  ///
  /// Правило смысла (задача 2, уточнено по итогам разбора задачи 3):
  /// владельца имеет **только** чек в работе (`state = 0`). Переход в
  /// любое другое состояние снимает владельца — отложенный чек
  /// (`state = 3`) уходит в общий пул на тех же основаниях, что
  /// отправленный или синхронизированный: он больше не принадлежит
  /// тому, кто его набирал. До этой правки колонку у отправленных и
  /// синхронизированных чеков никто не трогал — `data_exchange_service`
  /// и `merge_tables_use_case_impl` звали этот метод напрямую, и каждая
  /// новая продажа, дойдя до отправленного состояния, несла бы
  /// устаревшего владельца навсегда (у колонки сегодня нет читателя вне
  /// `findInProgress`, что и делало эту ложь в данных незаметной).
  ///
  /// Переход **в** `state = 0`, наоборот, владельца не снимает и не
  /// проставляет — его выставляет тот, кто поднимает чек (`undeferSale`,
  /// вставка новой продажи), отдельной записью: этому методу неоткуда
  /// узнать, чьих рук это подъём.
  Future<int> updateState(int receiptNo, int posId, int state) =>
      (update(sales)..where(
            (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId),
          ))
          .write(
            SalesCompanion(
              state: Value(state),
              terminalId: state == 0 ? const Value.absent() : const Value(null),
            ),
          );

  Future<List<Sale>> findByState(int state) =>
      (select(sales)..where((s) => s.state.equals(state))).get();

  Future<List<Sale>> findRecentCompleted({int limit = 30}) =>
      (select(sales)
            ..where(
              (s) => s.state.isNotIn([0, 3]) & s.time.isBiggerThanValue(0),
            )
            ..orderBy([(s) => OrderingTerm.desc(s.time)])
            ..limit(limit))
          .get();

  Future<List<QueryRow>> findToUpload(
    int state, {
    int limit = 100,
  }) => customSelect(
    'SELECT DISTINCT s.* FROM sales s '
    'LEFT JOIN sale_products sp ON s.pos_id = sp.pos_id AND s.receipt_no = sp.receipt_no '
    'LEFT JOIN product_info_editions pe ON sp.ucode = pe.ucode '
    'LEFT JOIN product_price_editions ppe ON ppe.ucode = sp.ucode '
    'WHERE s.state = ? '
    'AND (s.customer_local_id IS NULL OR s.customer_server_id IS NOT NULL) '
    'GROUP BY s.receipt_no, s.pos_id '
    'HAVING COUNT(pe.ucode) = 0 AND COUNT(ppe.ucode) = 0 '
    'LIMIT ?',
    variables: [Variable.withInt(state), Variable.withInt(limit)],
    readsFrom: {sales},
  ).get();

  Future<int> countWithState(int state) {
    final expr = sales.receiptNo.count();
    return (selectOnly(sales)
          ..addColumns([expr])
          ..where(sales.state.equals(state)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> countBetweenDate(int startDate, int endDate) {
    final expr = sales.receiptNo.count();
    return (selectOnly(sales)
          ..addColumns([expr])
          ..where(
            sales.time.isBiggerThanValue(startDate) &
                sales.time.isSmallerThanValue(endDate) &
                sales.state.equals(3).not(),
          ))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<Sale?> findFirstSaleAfter(int timestamp) =>
      (select(sales)
            ..where(
              (s) =>
                  s.time.isBiggerThanValue(timestamp) & s.state.equals(3).not(),
            )
            ..orderBy([(s) => OrderingTerm.asc(s.time)])
            ..limit(1))
          .getSingleOrNull();

  Future<List<Sale>> findSalesToDelete(int threeMonthEarly) =>
      (select(sales)..where(
            (s) =>
                s.time.isSmallerThanValue(threeMonthEarly) &
                s.state.equals(4) &
                s.customerLocalId.isNull() &
                s.customerServerId.isNull(),
          ))
          .get();

  /// Сумма продаж клиента (он же агент — `SaleUseCaseImpl.perform` кладёт
  /// `agentLocalId` именно в `customerLocalId`), на которой считается его
  /// баланс (`agent_balance_service_impl.dart:59`).
  ///
  /// **Фильтр по состоянию заведён кругом правки 1 задачи 7, и вот
  /// почему.** До задачи 7 выборка не смотрела ни на состояние, ни на
  /// время — и это сходило с рук, потому что у чека **в работе** оба
  /// слагаемых были пусты: агент проставлялся только при завершении
  /// продажи, а сумма стояла нулём до неё же. Задача 7 положила в этот
  /// путь оба: `CartService.setAgent` пишет клиента чеку в работе, а
  /// каждая команда корзины пишет его непустую сумму. Проба разбора: чек
  /// в работе на 1000 давал баланс агента 1000 — **долг агента рос на
  /// каждый скан ненабранного чека**.
  ///
  /// Незавершённый чек деньгами не является: `state = 0` (в работе) и
  /// `state = 3` (отложен) исключаются — тем же выражением, которым уже
  /// пользуется [findRecentCompleted].
  Future<double?> sumAmountByCustomerLocalId(int customerLocalId) {
    final expr = sales.amount.sum();
    return (selectOnly(sales)
          ..addColumns([expr])
          ..where(
            sales.customerLocalId.equals(customerLocalId) &
                sales.state.isNotIn([0, 3]),
          ))
        .map((row) => row.read(expr))
        .getSingleOrNull();
  }

  Future<int?> findMaxSyncedSaleId() {
    final expr = sales.saleId.max();
    return (selectOnly(sales)
          ..addColumns([expr])
          ..where(sales.state.equals(4)))
        .map((row) => row.read(expr))
        .getSingleOrNull();
  }

  Future<List<Sale>> findWithNoCustomerLocId(List<int> serverIds) =>
      (select(sales)..where(
            (s) =>
                s.customerServerId.isIn(serverIds) & s.customerLocalId.isNull(),
          ))
          .get();

  Future<List<QueryRow>> findLastForeign() => customSelect(
    'SELECT * FROM sales WHERE pos_id NOT IN (SELECT id FROM this_pos_entries) ORDER BY time DESC LIMIT 1',
    readsFrom: {sales},
  ).get();

  /// Тот же приём, что `updateState`: чек больше не в работе — владельца
  /// нет. Отдельный метод от `updateState` (используется `CouchDB`-
  /// синхронизацией, `couchdb_sync_coordinator.dart`), но правило смысла
  /// одно и то же, и запись владельца дублируется здесь по той же
  /// причине — общего метода-точки для всех переходов состояния у
  /// таблицы исторически нет.
  Future<int> markSyncedByKey(
    int receiptNo,
    int posId, {
    int syncedState = 4,
  }) =>
      (update(sales)..where(
            (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId),
          ))
          .write(
            SalesCompanion(
              state: Value(syncedState),
              terminalId: syncedState == 0
                  ? const Value.absent()
                  : const Value(null),
            ),
          );

  /// Тот же приём, что `updateState` — см. там докстрингом.
  Future<int> setState(int state, int posId, List<int> receiptNos) =>
      (update(
            sales,
          )..where((s) => s.receiptNo.isIn(receiptNos) & s.posId.equals(posId)))
          .write(
            SalesCompanion(
              state: Value(state),
              terminalId: state == 0 ? const Value.absent() : const Value(null),
            ),
          );

  Future<int> setAgentServerIdByLocalId(int localId, int serverId) =>
      (update(sales)..where((s) => s.customerLocalId.equals(localId))).write(
        SalesCompanion(customerServerId: Value(serverId)),
      );

  /// Выручка смены — сумма продаж кассира за отрезок времени
  /// (`assemble_shift_receipt_use_case_impl.dart:64`, отчёт по смене).
  ///
  /// **Фильтр по состоянию — тот же круг правки и та же причина, что у
  /// [sumAmountByCustomerLocalId].** Отбор шёл по времени, и от суммы
  /// незавершённого чека выборку спасало только то, что `Sales.time` у
  /// него равен нулю (его выставляет завершение продажи), а ноль не
  /// попадает в отрезок смены. То есть денежный итог держался на
  /// побочном свойстве другой колонки, а не на условии, которое кто-то
  /// написал; задача 7 сделала вторую половину этой связки —
  /// непустую сумму у чека в работе — обычным делом.
  ///
  /// Условие названо явно: чек в работе (0) и отложенный (3) выручкой
  /// смены не являются, сколько бы времени у них ни стояло.
  Future<double?> amountOfShift(int userId, int fromTime, int toTime) {
    final expr = sales.amount.sum();
    return (selectOnly(sales)
          ..addColumns([expr])
          ..where(
            sales.userId.equals(userId) &
                sales.time.isBetweenValues(fromTime, toTime) &
                sales.state.isNotIn([0, 3]),
          ))
        .map((row) => row.read(expr))
        .getSingleOrNull();
  }

  Future<List<Sale>> findByPosIdAndBetweenDate(
    int posId,
    int startDate,
    int endDate, {
    int limit = 100,
  }) =>
      (select(sales)
            ..where(
              (s) =>
                  s.posId.equals(posId) &
                  s.time.isBiggerThanValue(startDate) &
                  s.time.isSmallerThanValue(endDate) &
                  s.state.equals(3).not(),
            )
            ..orderBy([(s) => OrderingTerm.desc(s.time)])
            ..limit(limit))
          .get();

  Future<int> setSaleId(int receiptNo, int posId, int saleId) =>
      (update(sales)..where(
            (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId),
          ))
          .write(SalesCompanion(saleId: Value(saleId)));

  Future<int> setIsWholesale(int receiptNo, int posId, bool isWholesale) =>
      (update(sales)..where(
            (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId),
          ))
          .write(SalesCompanion(isWholesale: Value(isWholesale)));

  Future<int> setAmount(int receiptNo, int posId, Decimal amount) =>
      (update(sales)..where(
            (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId),
          ))
          .write(SalesCompanion(amount: Value(amount)));

  Future<SaleWithdrawal?> findWithdrawalByReceiptNo(int receiptNo) => (select(
    saleWithdrawals,
  )..where((sw) => sw.receiptNo.equals(receiptNo))).getSingleOrNull();

  Future<SaleWithdrawal?> findWithdrawalBySale(int receiptNo, int posId) =>
      (select(saleWithdrawals)..where(
            (sw) => sw.receiptNo.equals(receiptNo) & sw.posId.equals(posId),
          ))
          .getSingleOrNull();

  Future<List<Sale>> findOldSyncedSales(int cutoffTimestamp) =>
      (select(sales)..where(
            (s) =>
                s.time.isSmallerThanValue(cutoffTimestamp) & s.state.equals(4),
          ))
          .get();

  Future<int> deleteSale(int receiptNo, int posId) => (delete(
    sales,
  )..where((s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId))).go();

  Future<int> deleteSales(List<({int receiptNo, int posId})> keys) async {
    int deleted = 0;
    for (final key in keys) {
      deleted += await deleteSale(key.receiptNo, key.posId);
    }
    return deleted;
  }
}
