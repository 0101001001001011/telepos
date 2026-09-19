import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/report_dao.dart';

/// Отчёты не считают выручкой чек, который ещё не продан — задача 34.
///
/// Восемнадцать выборок `ReportDao` фильтровали `state <> 3`, то есть
/// исключали только отложенный чек. Чек **в работе** (`state = 0`) и он же,
/// занятый под оплату (`state = 2`, `LocalPaymentService._stateClaimedForPayment`),
/// входили в выручку. Довод «спасает нулевое время» опровергнут: ресторанный
/// стол пишет `state = 0` вместе с настоящим временем и суммой.
///
/// Посев — одна продажа в каждом из четырёх состояний, с одним и тем же
/// временем, товаром и кассиром, и суммами, различимыми в любой сумме
/// подмножества: 500 (продан), 1000 (в работе), 300 (занят под оплату),
/// 700 (отложен). Правильный ответ везде — **500 и одна продажа**; любое
/// лишнее состояние даёт число, по которому видно, какое именно.
void main() {
  late AppDatabase db;
  late ReportDao reports;

  const t = 1000000;
  const from = t - 10;
  const to = t + 10;
  const ucode = 77;

  Future<void> seedSale(int receiptNo, int state, int amount) async {
    await db.customStatement(
      'INSERT INTO sales (receipt_no, pos_id, user_id, amount, time, state, '
      'customer_local_id, order_type) VALUES (?, 1, 1, ?, ?, ?, 5, 1)',
      [receiptNo, amount, t, state],
    );
    await db.customStatement(
      'INSERT INTO sale_products (receipt_no, pos_id, ucode, quantity, price, '
      'price_before) VALUES (?, 1, ?, 1, ?, ?)',
      [receiptNo, ucode, amount, amount],
    );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    reports = db.reportDao;
    await db.customStatement(
      "INSERT INTO users (id, name) VALUES (1, 'Айгуль')",
    );
    // `type = 6` — блюдо: иначе `getDishPopularity` отсекла бы строку своим
    // условием, и проба сравнивала бы пустоту с пустотой.
    await db.customStatement(
      'INSERT INTO product_infos (ucode, barcode, name, type, measure, '
      "quantity, vat_rate) VALUES (?, 4600000000077, 'Молоко', 6, 0, 100, 12)",
      [ucode],
    );
    await seedSale(1, 1, 500); // продан
    await seedSale(2, 0, 1000); // в работе — открытый стол ресторана
    await seedSale(3, 2, 300); // занят под оплату
    await seedSale(4, 3, 700); // отложен
  });

  tearDown(() => db.close());

  Decimal money(QueryRow row, String column) => row.readDecimal(column);

  test('предпосылка: все четыре чека легли в базу', () async {
    final count = await db
        .customSelect('SELECT COUNT(*) AS c FROM sales')
        .getSingle();
    expect(count.read<int>('c'), 4);
  });

  test('итог выручки и число продаж — только проданный чек', () async {
    final row = await reports.getTotalRevenue(from, to);
    expect(money(row, 'total_revenue'), Decimal.fromInt(500));
    expect(row.read<int>('sale_count'), 1);
  });

  test('доход за период — только проданный чек', () async {
    final row = await reports.getIncomeForPeriod(from, to);
    expect(money(row, 'sales_income'), Decimal.fromInt(500));
    expect(row.read<int>('sale_count'), 1);
  });

  test('выручка по дням и по часам', () async {
    final byDay = await reports.getRevenueByDay(from, to);
    expect(money(byDay.single, 'revenue'), Decimal.fromInt(500));
    expect(byDay.single.read<int>('cnt'), 1);

    final byHour = await reports.getHourlyDistribution(from, to);
    expect(money(byHour.single, 'revenue'), Decimal.fromInt(500));
    expect(byHour.single.read<int>('cnt'), 1);
  });

  test('кассир, покупатель, тип заказа', () async {
    final cashier = await reports.getCashierPerformance(from, to);
    expect(money(cashier.single, 'revenue'), Decimal.fromInt(500));
    expect(cashier.single.read<int>('sale_count'), 1);

    final customers = await reports.getTopCustomers(from, to, 10);
    expect(money(customers.single, 'revenue'), Decimal.fromInt(500));
    expect(customers.single.read<int>('sale_count'), 1);

    final orderTypes = await reports.getRestaurantOrderTypes(from, to);
    expect(money(orderTypes.single, 'total_revenue'), Decimal.fromInt(500));
    expect(orderTypes.single.read<int>('order_count'), 1);
  });

  test('товарные выборки по строкам чека', () async {
    final top = await reports.getTopProducts(from, to, 10);
    expect(money(top.single, 'revenue'), Decimal.fromInt(500));

    final categories = await reports.getCategoryPerformance(from, to);
    expect(money(categories.single, 'revenue'), Decimal.fromInt(500));

    final vat = await reports.getVatByRate(from, to);
    expect(money(vat.single, 'gross'), Decimal.fromInt(500));

    final daily = await reports.getDailyProductSales(from, to, ucode);
    expect(money(daily.single, 'qty_sold'), Decimal.one);

    final depletion = await reports.getStockDepletion(from, to);
    expect(money(depletion.single, 'total_sold'), Decimal.one);

    final extended = await reports.getStockDepletionExtended(from, to);
    expect(money(extended.single, 'total_sold'), Decimal.one);
  });

  test('прибыль, себестоимость и блюда', () async {
    final profit = await reports.getProductProfit(from, to);
    expect(money(profit.single, 'revenue'), Decimal.fromInt(500));

    final cogs = await reports.getProfitCogs(from, to);
    expect(money(cogs.single, 'revenue'), Decimal.fromInt(500));

    final dishes = await reports.getDishPopularity(from, to);
    expect(money(dishes.single, 'revenue'), Decimal.fromInt(500));
  });

  test('ни одна выборка продаж в ReportDao не фильтрует одним «не отложен»', () {
    // Пробы выше держат восемнадцать мест поимённо; этот сторож держит
    // девятнадцатое — выборку, которую допишут завтра тем же копированием.
    final source = File(
      'lib/data/database/daos/report_dao.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('state <> 3')));
  });
}
