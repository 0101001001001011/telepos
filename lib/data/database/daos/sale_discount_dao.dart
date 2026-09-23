import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/discount_tables.dart';
import 'package:telepos/domain/discount/discount_origin.dart';

part 'sale_discount_dao.g.dart';

/// Происхождение скидок и аудит попыток — **и читатели к ним**.
///
/// Таблица без читателя в этом дереве уже трижды оказалась мёртвым кодом,
/// выглядящим живым (`ThisPosEntries`: `usersAllowedToRefund` и две
/// соседние — заведены, мигрированы и забыты; их единственное упоминание в
/// `lib/` сегодня — собственное объявление). Поэтому обе таблицы задачи 13
/// входят в дерево вместе с этим DAO, а не «под будущий отчёт».
@DriftAccessor(tables: [SaleDiscounts, DiscountAuditEntries])
class SaleDiscountDao extends DatabaseAccessor<AppDatabase>
    with _$SaleDiscountDaoMixin {
  SaleDiscountDao(super.db);

  Future<List<SaleDiscount>> findBySale(int receiptNo, int posId) => (select(
    saleDiscounts,
  )..where((d) => d.receiptNo.equals(receiptNo) & d.posId.equals(posId))).get();

  /// Сколько отдано по каждому происхождению за отрезок времени.
  ///
  /// **Тот самый вопрос, ради которого таблица и заведена**: «сколько мы
  /// отдали акциями за месяц». До неё ответить на него было нечем — в
  /// разности цен акция и уступка кассира выглядят одинаково.
  ///
  /// Перебирается в Dart, а не `GROUP BY`-ем: то же решение и по той же
  /// причине, что в `BonusEntryDao.balanceOf` — деньги в этом дереве
  /// приезжают через [DecimalConverter], и складывать их `SUM`-ом значило
  /// бы складывать `double`. Унаследованная оговорка `ReportDao` (все его
  /// методы — `customSelect` с `readsFrom: {}`, а `readDecimal` идёт через
  /// `double`) здесь намеренно не наследуется.
  Future<Map<int, Decimal>> givenByOrigin({
    required int fromTime,
    required int toTime,
  }) async {
    final rows = await (select(
      saleDiscounts,
    )..where((d) => d.time.isBetweenValues(fromTime, toTime))).get();
    final out = <int, Decimal>{};
    for (final r in rows) {
      out[r.origin] = (out[r.origin] ?? Decimal.zero) + r.amount;
    }
    return out;
  }

  /// Записать происхождение скидок строки. Пустой список — ничего.
  ///
  /// Зовётся **внутри транзакции продажи**: чек, не состоявшийся из-за
  /// нарушения ключа платежей, обязан не оставить за собой происхождение
  /// скидки, которой не было.
  Future<void> recordForLine({
    required int receiptNo,
    required int posId,
    required int saleProductId,
    required List<({int origin, int? sourceId, Decimal amount})> discounts,
    required int at,
  }) async {
    for (final d in discounts) {
      if (d.amount <= Decimal.zero) continue;
      await into(saleDiscounts).insert(
        SaleDiscountsCompanion.insert(
          receiptNo: receiptNo,
          posId: posId,
          saleProductId: saleProductId,
          origin: d.origin,
          sourceId: Value(d.sourceId),
          amount: d.amount,
          time: at,
        ),
      );
    }
  }

  // ── аудит ─────────────────────────────────────────────────────────────

  /// Записать попытку скидки — **прошедшую или отклонённую**.
  ///
  /// Отдельным оборотом от всего остального и **вне** транзакции корзины:
  /// команда, которой отказали, транзакции не открывает вовсе, а если бы
  /// открывала — откатила бы вместе с отказом и запись о нём. Аудит,
  /// исчезающий вместе с тем, что он записывает, аудитом не является.
  Future<void> recordAttempt({
    int? userId,
    int roleIndex = -1,
    int? receiptNo,
    int? posId,
    int? saleProductId,
    int? customerLocalId,
    required Decimal amount,
    required Decimal percent,
    required bool allowed,
    String? refusalCode,
    String? capSource,
    int? at,
  }) async {
    await into(discountAuditEntries).insert(
      DiscountAuditEntriesCompanion.insert(
        userId: Value(userId),
        roleIndex: Value(roleIndex),
        receiptNo: Value(receiptNo),
        posId: Value(posId),
        saleProductId: Value(saleProductId),
        customerLocalId: Value(customerLocalId),
        amount: amount,
        percent: percent,
        allowed: allowed,
        refusalCode: Value(refusalCode),
        capSource: Value(capSource),
        time: at ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ),
    );
  }

  /// Что этот человек делал со скидками. **Читатель аудита.**
  ///
  /// Отказы включены и не отделены флагом-доводом: «кассир девять раз
  /// пробовал дать сорок процентов» — единственный вопрос, ради которого
  /// отказы вообще пишутся, и выборка, умеющая их скрыть, скрывала бы их
  /// по умолчанию у каждого второго вызывающего.
  Future<List<DiscountAuditEntry>> auditFor({
    int? userId,
    int? receiptNo,
    int? posId,
  }) {
    final q = select(discountAuditEntries);
    if (userId != null) q.where((e) => e.userId.equals(userId));
    if (receiptNo != null) q.where((e) => e.receiptNo.equals(receiptNo));
    if (posId != null) q.where((e) => e.posId.equals(posId));
    q.orderBy([(e) => OrderingTerm.desc(e.time)]);
    return q.get();
  }

  /// Отказанные попытки за отрезок — то, что смотрит проверяющий.
  Future<List<DiscountAuditEntry>> refusalsBetween({
    required int fromTime,
    required int toTime,
  }) =>
      (select(discountAuditEntries)
            ..where(
              (e) =>
                  e.allowed.equals(false) &
                  e.time.isBetweenValues(fromTime, toTime),
            )
            ..orderBy([(e) => OrderingTerm.desc(e.time)]))
          .get();

  /// Происхождение словами — для экрана и отчёта.
  static String originName(int origin) => DiscountOrigin.nameOf(origin);
}
