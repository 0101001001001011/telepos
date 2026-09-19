import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/core/utils/decimal_util.dart';
import 'package:telepos/data/database/app_database.dart';

part 'report_dao.g.dart';

extension ReportRowDecimal on QueryRow {
  Decimal readDecimal(String column) {
    final value = read<double?>(column);
    if (value == null) return Decimal.zero;
    return DecimalUtil.fromDouble(value);
  }

  Decimal? readDecimalOrNull(String column) {
    final value = read<double?>(column);
    if (value == null) return null;
    return DecimalUtil.fromDouble(value);
  }
}

/// Отчётные выборки.
///
/// # Какой чек — выручка
///
/// Выручкой считается только **проданный** чек: состояние не `0` (в работе),
/// не `2` (тот же чек в работе, занятый под оплату на время записи денег,
/// `LocalPaymentService._stateClaimedForPayment`) и не `3` (отложен). Тем же
/// правилом живёт `SaleDao.amountOfShift`.
///
/// До задачи 34 все восемнадцать мест исключали одно состояние `3`, и открытый
/// стол ресторана — `state = 0` с настоящим временем и суммой — входил в
/// выручку отчётов. `NULL` в состоянии исключается, как исключался и
/// прежним фильтром: `NULL NOT IN (…)` в SQL не истина.
///
/// Проба — `test/data/database/report_dao_in_progress_test.dart`.
@DriftAccessor(tables: [])
class ReportDao extends DatabaseAccessor<AppDatabase> with _$ReportDaoMixin {
  ReportDao(super.db);

  Future<QueryRow> getTotalRevenue(int startTs, int endTs) async {
    final rows = await customSelect(
      'SELECT '
      '(SELECT COALESCE(SUM(amount), 0) FROM sales '
      '   WHERE time BETWEEN ?1 AND ?2 AND state NOT IN (0, 2, 3)) - '
      '(SELECT COALESCE(SUM(amount), 0) FROM refunds '
      '   WHERE time BETWEEN ?1 AND ?2 AND (state IS NULL OR state <> 0)) '
      'AS total_revenue, '
      '(SELECT COUNT(*) FROM sales '
      '   WHERE time BETWEEN ?1 AND ?2 AND state NOT IN (0, 2, 3)) AS sale_count',
      variables: [Variable.withInt(startTs), Variable.withInt(endTs)],
      readsFrom: {},
    ).get();
    return rows.first;
  }

  Future<List<QueryRow>> getRevenueByDay(int startTs, int endTs) {
    return customSelect(
      'SELECT day_bucket, '
      'SUM(amount) AS revenue, '
      'SUM(is_sale) AS cnt '
      'FROM ('
      '  SELECT (time / 86400) AS day_bucket, amount AS amount, 1 AS is_sale '
      '  FROM sales WHERE time BETWEEN ?1 AND ?2 AND state NOT IN (0, 2, 3) '
      '  UNION ALL '
      '  SELECT (time / 86400) AS day_bucket, -amount AS amount, 0 AS is_sale '
      '  FROM refunds WHERE time BETWEEN ?1 AND ?2 AND (state IS NULL OR state <> 0) '
      ') '
      'GROUP BY day_bucket '
      'ORDER BY day_bucket',
      variables: [Variable.withInt(startTs), Variable.withInt(endTs)],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getTopProducts(int startTs, int endTs, int limit) {
    return customSelect(
      'SELECT sp.ucode, pi.name, '
      'SUM(sp.quantity * sp.price) AS revenue, '
      'SUM(sp.quantity) AS qty_sold '
      'FROM sale_products sp '
      'JOIN sales s ON s.receipt_no = sp.receipt_no AND s.pos_id = sp.pos_id '
      'JOIN product_infos pi ON pi.ucode = sp.ucode '
      'WHERE s.time BETWEEN ? AND ? AND s.state NOT IN (0, 2, 3) '
      'GROUP BY sp.ucode '
      'ORDER BY revenue DESC '
      'LIMIT ?',
      variables: [
        Variable.withInt(startTs),
        Variable.withInt(endTs),
        Variable.withInt(limit),
      ],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getPaymentMethods(int startTs, int endTs) {
    return customSelect(
      'SELECT p.payee_account_id, a.name AS account_name, '
      'a.type AS account_type, '
      'SUM(p.amount) AS total '
      'FROM payments p '
      'JOIN accounts a ON a.id = p.payee_account_id '
      'WHERE p.time BETWEEN ? AND ? '
      'GROUP BY p.payee_account_id '
      'ORDER BY total DESC',
      variables: [Variable.withInt(startTs), Variable.withInt(endTs)],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getHourlyDistribution(int startTs, int endTs) {
    return customSelect(
      'SELECT hour_of_day, '
      'SUM(is_sale) AS cnt, '
      'SUM(amount) AS revenue '
      'FROM ('
      '  SELECT ((time % 86400) / 3600) AS hour_of_day, amount AS amount, 1 AS is_sale '
      '  FROM sales WHERE time BETWEEN ?1 AND ?2 AND state NOT IN (0, 2, 3) '
      '  UNION ALL '
      '  SELECT ((time % 86400) / 3600) AS hour_of_day, -amount AS amount, 0 AS is_sale '
      '  FROM refunds WHERE time BETWEEN ?1 AND ?2 AND (state IS NULL OR state <> 0) '
      ') '
      'GROUP BY hour_of_day '
      'ORDER BY hour_of_day',
      variables: [Variable.withInt(startTs), Variable.withInt(endTs)],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getCashierPerformance(int startTs, int endTs) {
    return customSelect(
      'SELECT t.user_id, u.name, '
      'SUM(t.is_sale) AS sale_count, '
      'SUM(t.amount) AS revenue '
      'FROM ('
      '  SELECT user_id, amount AS amount, 1 AS is_sale '
      '  FROM sales WHERE time BETWEEN ?1 AND ?2 AND state NOT IN (0, 2, 3) '
      '  UNION ALL '
      '  SELECT user_id, -amount AS amount, 0 AS is_sale '
      '  FROM refunds WHERE time BETWEEN ?1 AND ?2 AND (state IS NULL OR state <> 0) '
      ') t '
      'JOIN users u ON u.id = t.user_id '
      'GROUP BY t.user_id '
      'ORDER BY revenue DESC',
      variables: [Variable.withInt(startTs), Variable.withInt(endTs)],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getCategoryPerformance(int startTs, int endTs) {
    return customSelect(
      'SELECT sp.category_id, c.name, '
      'SUM(sp.quantity * sp.price) AS revenue, '
      'SUM(sp.quantity) AS qty '
      'FROM sale_products sp '
      'JOIN sales s ON s.receipt_no = sp.receipt_no AND s.pos_id = sp.pos_id '
      'LEFT JOIN categories c ON c.id = sp.category_id '
      'WHERE s.time BETWEEN ? AND ? AND s.state NOT IN (0, 2, 3) '
      'GROUP BY sp.category_id '
      'ORDER BY revenue DESC',
      variables: [Variable.withInt(startTs), Variable.withInt(endTs)],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getLowStockItems(double threshold) {
    return customSelect(
      'SELECT pi.ucode, pi.name, pi.quantity AS stock, '
      'pp.selling_price '
      'FROM product_infos pi '
      'LEFT JOIN product_prices pp ON pp.ucode = pi.ucode '
      'WHERE pi.is_deleted = 0 '
      'AND pi.quantity IS NOT NULL '
      'AND pi.quantity < ? '
      'ORDER BY pi.quantity ASC '
      'LIMIT 50',
      variables: [Variable.withReal(threshold)],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getCashFlow(int startTs, int endTs) {
    return customSelect(
      'SELECT (doc_time / 86400) AS day_bucket, '
      'type, '
      'SUM(amount) AS total '
      'FROM cash_operations '
      'WHERE doc_time BETWEEN ? AND ? '
      'GROUP BY day_bucket, type '
      'ORDER BY day_bucket',
      variables: [Variable.withInt(startTs), Variable.withInt(endTs)],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getRefundTrend(int startTs, int endTs) {
    return customSelect(
      'SELECT (time / 86400) AS day_bucket, '
      'COUNT(*) AS refund_count, '
      'SUM(amount) AS refund_total '
      'FROM refunds '
      'WHERE time BETWEEN ? AND ? '
      'GROUP BY day_bucket '
      'ORDER BY day_bucket',
      variables: [Variable.withInt(startTs), Variable.withInt(endTs)],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getTopCustomers(int startTs, int endTs, int limit) {
    return customSelect(
      'SELECT s.customer_local_id, ag.name, '
      'SUM(s.amount) AS revenue, '
      'COUNT(*) AS sale_count '
      'FROM sales s '
      'LEFT JOIN agents ag ON ag.local_id = s.customer_local_id '
      'WHERE s.time BETWEEN ? AND ? AND s.state NOT IN (0, 2, 3) '
      'AND s.customer_local_id IS NOT NULL '
      'GROUP BY s.customer_local_id '
      'ORDER BY revenue DESC '
      'LIMIT ?',
      variables: [
        Variable.withInt(startTs),
        Variable.withInt(endTs),
        Variable.withInt(limit),
      ],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getSupplierVolume(int startTs, int endTs) {
    return customSelect(
      'SELECT su.supplier_id, ag.name, '
      'COUNT(*) AS supply_count '
      'FROM supplies su '
      'LEFT JOIN agents ag ON ag.local_id = su.supplier_id '
      'WHERE su.edit_time BETWEEN ? AND ? '
      'GROUP BY su.supplier_id '
      'ORDER BY supply_count DESC',
      variables: [Variable.withInt(startTs), Variable.withInt(endTs)],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getStockDepletion(int startTs, int endTs) {
    return customSelect(
      'SELECT sp.ucode, pi.name, '
      'pi.quantity AS stock, '
      'SUM(sp.quantity) AS total_sold, '
      '(CAST(? AS REAL) - CAST(? AS REAL)) / 86400.0 AS days_in_range '
      'FROM sale_products sp '
      'JOIN sales s ON s.receipt_no = sp.receipt_no AND s.pos_id = sp.pos_id '
      'JOIN product_infos pi ON pi.ucode = sp.ucode '
      'WHERE s.time BETWEEN ? AND ? AND s.state NOT IN (0, 2, 3) '
      'AND pi.quantity IS NOT NULL '
      'GROUP BY sp.ucode '
      'HAVING total_sold > 0 '
      'ORDER BY (pi.quantity / (total_sold / MAX(1, days_in_range))) ASC '
      'LIMIT 50',
      variables: [
        Variable.withInt(endTs),
        Variable.withInt(startTs),
        Variable.withInt(startTs),
        Variable.withInt(endTs),
      ],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getDailyProductSales(
    int startTs,
    int endTs,
    int ucode,
  ) {
    return customSelect(
      'SELECT (s.time / 86400) AS day_bucket, '
      'SUM(sp.quantity) AS qty_sold '
      'FROM sale_products sp '
      'JOIN sales s ON s.receipt_no = sp.receipt_no AND s.pos_id = sp.pos_id '
      'WHERE sp.ucode = ? '
      'AND s.time BETWEEN ? AND ? AND s.state NOT IN (0, 2, 3) '
      'GROUP BY day_bucket '
      'ORDER BY day_bucket',
      variables: [
        Variable.withInt(ucode),
        Variable.withInt(startTs),
        Variable.withInt(endTs),
      ],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getStockDepletionExtended(int startTs, int endTs) {
    return customSelect(
      'SELECT sp.ucode, pi.name, '
      'pi.quantity AS stock, '
      'SUM(sp.quantity) AS total_sold, '
      '(CAST(? AS REAL) - CAST(? AS REAL)) / 86400.0 AS days_in_range, '
      'pp.wholesale_price AS last_purchase_price '
      'FROM sale_products sp '
      'JOIN sales s ON s.receipt_no = sp.receipt_no AND s.pos_id = sp.pos_id '
      'JOIN product_infos pi ON pi.ucode = sp.ucode '
      'LEFT JOIN product_prices pp ON pp.ucode = sp.ucode '
      'WHERE s.time BETWEEN ? AND ? AND s.state NOT IN (0, 2, 3) '
      'AND pi.quantity IS NOT NULL '
      'GROUP BY sp.ucode '
      'HAVING total_sold > 0 '
      'ORDER BY (pi.quantity / (total_sold / MAX(1, days_in_range))) ASC '
      'LIMIT 50',
      variables: [
        Variable.withInt(endTs),
        Variable.withInt(startTs),
        Variable.withInt(startTs),
        Variable.withInt(endTs),
      ],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getLastSupplierForProducts() {
    return customSelect(
      'SELECT spr.ucode, ag.name AS supplier_name '
      'FROM supply_products spr '
      'JOIN supplies su ON su.id = spr.supply_id '
      'LEFT JOIN agents ag ON ag.local_id = su.supplier_id '
      'WHERE su.supplier_id IS NOT NULL '
      'AND spr.id IN ('
      '  SELECT MAX(spr2.id) FROM supply_products spr2 '
      '  JOIN supplies su2 ON su2.id = spr2.supply_id '
      '  GROUP BY spr2.ucode'
      ')',
      variables: [],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getProductProfit(int startTs, int endTs) {
    return customSelect(
      'SELECT t.ucode, pi.name, '
      'SUM(t.qty) AS qty_sold, '
      'SUM(t.revenue) AS revenue, '
      'COALESCE(pp.wholesale_price, 0) AS cost_price, '
      'SUM(t.revenue) - SUM(t.qty) * COALESCE(pp.wholesale_price, 0) AS profit, '
      'CASE WHEN SUM(t.revenue) > 0 '
      '  THEN (SUM(t.revenue) - SUM(t.qty) * COALESCE(pp.wholesale_price, 0)) / SUM(t.revenue) * 100 '
      '  ELSE 0 END AS margin_pct '
      'FROM ('
      '  SELECT sp.ucode AS ucode, sp.quantity AS qty, sp.quantity * sp.price AS revenue '
      '  FROM sale_products sp '
      '  JOIN sales s ON s.receipt_no = sp.receipt_no AND s.pos_id = sp.pos_id '
      '  WHERE s.time BETWEEN ?1 AND ?2 AND s.state NOT IN (0, 2, 3) '
      '  UNION ALL '
      '  SELECT rp.ucode AS ucode, -rp.quantity AS qty, -(rp.quantity * rp.price) AS revenue '
      '  FROM refund_products rp '
      '  JOIN refunds r ON r.local_id = rp.refund_local_id '
      '  WHERE r.time BETWEEN ?1 AND ?2 AND (r.state IS NULL OR r.state <> 0) '
      ') t '
      'JOIN product_infos pi ON pi.ucode = t.ucode '
      'LEFT JOIN product_prices pp ON pp.ucode = t.ucode '
      'GROUP BY t.ucode ORDER BY profit DESC LIMIT 50',
      variables: [Variable.withInt(startTs), Variable.withInt(endTs)],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getSupplierPriceHistory(int startTs, int endTs) {
    return customSelect(
      'SELECT spr.ucode, pi.name, su.supplier_id, ag.name AS supplier_name, '
      'su.edit_time, spr.price AS unit_price, spr.quantity '
      'FROM supply_products spr '
      'JOIN supplies su ON su.id = spr.supply_id '
      'LEFT JOIN product_infos pi ON pi.ucode = spr.ucode '
      'LEFT JOIN agents ag ON ag.local_id = su.supplier_id '
      'WHERE su.edit_time BETWEEN ? AND ? '
      'ORDER BY spr.ucode, su.edit_time',
      variables: [Variable.withInt(startTs), Variable.withInt(endTs)],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getRestaurantOrderTypes(int startTs, int endTs) {
    return customSelect(
      'SELECT COALESCE(s.order_type, 0) AS order_type, '
      'COUNT(*) AS order_count, '
      'SUM(s.amount) AS total_revenue, '
      'AVG(s.amount) AS avg_check '
      'FROM sales s '
      'WHERE s.time BETWEEN ? AND ? AND s.state NOT IN (0, 2, 3) '
      'AND s.order_type IS NOT NULL '
      'GROUP BY s.order_type ORDER BY total_revenue DESC',
      variables: [Variable.withInt(startTs), Variable.withInt(endTs)],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getTableTurnover(int startTs, int endTs) {
    return customSelect(
      'SELECT rt.id, rt.name, rt.zone, rt.capacity, '
      'COUNT(ro.id) AS seating_count, '
      'SUM(COALESCE(s.amount, 0)) AS total_revenue, '
      'AVG(COALESCE(s.amount, 0)) AS avg_check, '
      'SUM(COALESCE(ro.tips, 0)) AS total_tips '
      'FROM restaurant_tables rt '
      'LEFT JOIN restaurant_orders ro ON ro.table_id = rt.id AND ro.open_time BETWEEN ? AND ? '
      'LEFT JOIN sales s ON s.receipt_no = ro.receipt_no AND s.pos_id = ro.pos_id '
      'WHERE rt.is_active = 1 '
      'GROUP BY rt.id ORDER BY seating_count DESC',
      variables: [Variable.withInt(startTs), Variable.withInt(endTs)],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getDishPopularity(int startTs, int endTs) {
    return customSelect(
      'SELECT t.ucode, pi.name, '
      'SUM(t.qty) AS qty_sold, '
      'SUM(t.revenue) AS revenue, '
      'COALESCE(pp.wholesale_price, 0) AS cost_price, '
      'CASE WHEN SUM(t.qty) > 0 THEN COALESCE(pp.wholesale_price, 0) / (SUM(t.revenue) / SUM(t.qty)) * 100 ELSE 0 END AS food_cost_pct '
      'FROM ('
      '  SELECT sp.ucode AS ucode, sp.quantity AS qty, sp.quantity * sp.price AS revenue '
      '  FROM sale_products sp '
      '  JOIN sales s ON s.receipt_no = sp.receipt_no AND s.pos_id = sp.pos_id '
      '  WHERE s.time BETWEEN ?1 AND ?2 AND s.state NOT IN (0, 2, 3) '
      '  UNION ALL '
      '  SELECT rp.ucode AS ucode, -rp.quantity AS qty, -(rp.quantity * rp.price) AS revenue '
      '  FROM refund_products rp '
      '  JOIN refunds r ON r.local_id = rp.refund_local_id '
      '  WHERE r.time BETWEEN ?1 AND ?2 AND (r.state IS NULL OR r.state <> 0) '
      ') t '
      'JOIN product_infos pi ON pi.ucode = t.ucode '
      'LEFT JOIN product_prices pp ON pp.ucode = t.ucode '
      'WHERE pi.type = 6 '
      'GROUP BY t.ucode ORDER BY qty_sold DESC',
      variables: [Variable.withInt(startTs), Variable.withInt(endTs)],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getTipsAnalysis(int startTs, int endTs) {
    return customSelect(
      'SELECT ro.waiter_id, COALESCE(u.name, \'Без официанта\') AS waiter_name, '
      'COUNT(*) AS order_count, '
      'SUM(COALESCE(s.amount, 0)) AS revenue, '
      'SUM(COALESCE(ro.tips, 0)) AS total_tips, '
      'CASE WHEN SUM(s.amount) > 0 THEN SUM(COALESCE(ro.tips, 0)) / SUM(s.amount) * 100 ELSE 0 END AS tip_percent '
      'FROM restaurant_orders ro '
      'LEFT JOIN sales s ON s.receipt_no = ro.receipt_no AND s.pos_id = ro.pos_id '
      'LEFT JOIN users u ON u.id = ro.waiter_id '
      'WHERE ro.open_time BETWEEN ? AND ? '
      'GROUP BY ro.waiter_id ORDER BY total_tips DESC',
      variables: [Variable.withInt(startTs), Variable.withInt(endTs)],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getVatByRate(int startTs, int endTs) {
    return customSelect(
      'SELECT COALESCE(pi.vat_rate, -1) AS vat_rate, '
      'SUM(sp.quantity * sp.price) AS gross '
      'FROM sale_products sp '
      'JOIN sales s ON s.receipt_no = sp.receipt_no AND s.pos_id = sp.pos_id '
      'JOIN product_infos pi ON pi.ucode = sp.ucode '
      'WHERE s.time BETWEEN ? AND ? AND s.state NOT IN (0, 2, 3) '
      'GROUP BY COALESCE(pi.vat_rate, -1) '
      'ORDER BY vat_rate',
      variables: [Variable.withInt(startTs), Variable.withInt(endTs)],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getAgentBalances() {
    return customSelect(
      'SELECT ag.local_id, ag.name, ag.type AS agent_type, '
      'a.id AS account_id, a.value AS balance '
      'FROM agents ag '
      'JOIN accounts a ON a.id = ag.main_account_id '
      'WHERE ag.is_deleted = 0 '
      'ORDER BY a.value DESC',
      variables: [],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getCashCollection(int startTs, int endTs) {
    return customSelect(
      'SELECT co.id, co.amount, co.account_id, a.name AS account_name, '
      'co.user_id, u.name AS user_name, co.note, co.doc_time '
      'FROM cash_operations co '
      'LEFT JOIN accounts a ON a.id = co.account_id '
      'LEFT JOIN users u ON u.id = co.user_id '
      'WHERE co.type = 2 AND co.doc_time BETWEEN ? AND ? '
      'ORDER BY co.doc_time DESC',
      variables: [Variable.withInt(startTs), Variable.withInt(endTs)],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getProfitCogs(int startTs, int endTs) {
    return customSelect(
      'SELECT t.ucode, pi.name, '
      'SUM(t.qty) AS qty_sold, '
      'SUM(t.revenue) AS revenue, '
      'COALESCE(pp.wholesale_price, 0) AS unit_cost '
      'FROM ('
      '  SELECT sp.ucode AS ucode, sp.quantity AS qty, sp.quantity * sp.price AS revenue '
      '  FROM sale_products sp '
      '  JOIN sales s ON s.receipt_no = sp.receipt_no AND s.pos_id = sp.pos_id '
      '  WHERE s.time BETWEEN ?1 AND ?2 AND s.state NOT IN (0, 2, 3) '
      '  UNION ALL '
      '  SELECT rp.ucode AS ucode, -rp.quantity AS qty, -(rp.quantity * rp.price) AS revenue '
      '  FROM refund_products rp '
      '  JOIN refunds r ON r.local_id = rp.refund_local_id '
      '  WHERE r.time BETWEEN ?1 AND ?2 AND (r.state IS NULL OR r.state <> 0) '
      ') t '
      'JOIN product_infos pi ON pi.ucode = t.ucode '
      'LEFT JOIN product_prices pp ON pp.ucode = t.ucode '
      'GROUP BY t.ucode '
      'ORDER BY revenue DESC',
      variables: [Variable.withInt(startTs), Variable.withInt(endTs)],
      readsFrom: {},
    ).get();
  }

  Future<List<QueryRow>> getWriteoffByReason(int startTs, int endTs) {
    return customSelect(
      'SELECT COALESCE(reason, -1) AS reason, '
      'COUNT(*) AS doc_count, '
      'SUM(COALESCE(amount, 0)) AS total '
      'FROM writeoffs '
      'WHERE doc_time BETWEEN ? AND ? '
      'GROUP BY COALESCE(reason, -1) '
      'ORDER BY total DESC',
      variables: [Variable.withInt(startTs), Variable.withInt(endTs)],
      readsFrom: {},
    ).get();
  }

  Future<QueryRow> getIncomeForPeriod(int startTs, int endTs) async {
    final rows = await customSelect(
      'SELECT '
      '(SELECT COALESCE(SUM(amount), 0) FROM sales '
      '   WHERE time BETWEEN ?1 AND ?2 AND state NOT IN (0, 2, 3)) AS sales_income, '
      '(SELECT COUNT(*) FROM sales '
      '   WHERE time BETWEEN ?1 AND ?2 AND state NOT IN (0, 2, 3)) AS sale_count, '
      '(SELECT COALESCE(SUM(amount), 0) FROM refunds '
      '   WHERE time BETWEEN ?1 AND ?2) AS refund_total, '
      '(SELECT COUNT(*) FROM refunds '
      '   WHERE time BETWEEN ?1 AND ?2) AS refund_count',
      variables: [Variable.withInt(startTs), Variable.withInt(endTs)],
      readsFrom: {},
    ).get();
    return rows.first;
  }

  Future<List<QueryRow>> getCashBookMovements(int startTs, int endTs) {
    return customSelect(
      'SELECT * FROM ('
      '  SELECT p.time AS ts, '
      '         CASE WHEN p.amount >= 0 THEN 1 ELSE -1 END AS direction, '
      '         CASE WHEN p.receipt_no IS NOT NULL THEN 0 ELSE 4 END AS kind, '
      '         ABS(p.amount) AS amount, '
      '         a.name AS account_name, '
      '         CAST(COALESCE(p.receipt_no, p.refund_local_id) AS TEXT) AS ref '
      '  FROM payments p '
      '  JOIN accounts a ON a.id = p.payee_account_id '
      '  WHERE p.time BETWEEN ?1 AND ?2 '
      '    AND (p.receipt_no IS NOT NULL OR p.refund_local_id IS NOT NULL) '
      '    AND a.type IN (0, 2) '
      '  UNION ALL '
      '  SELECT co.doc_time AS ts, '
      '         CASE WHEN co.type = 0 THEN 1 ELSE -1 END AS direction, '
      '         (co.type + 1) AS kind, '
      '         co.amount AS amount, '
      '         a.name AS account_name, '
      '         COALESCE(co.note, \'\') AS ref '
      '  FROM cash_operations co '
      '  LEFT JOIN accounts a ON a.id = co.account_id '
      '  WHERE co.doc_time BETWEEN ?1 AND ?2 '
      ') '
      'ORDER BY ts ASC, kind ASC',
      variables: [Variable.withInt(startTs), Variable.withInt(endTs)],
      readsFrom: {},
    ).get();
  }
}
