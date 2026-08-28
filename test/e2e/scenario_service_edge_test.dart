library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/data/database/app_database.dart';

import 'support/harness.dart';

void main() {
  final h = E2eHarness();
  setUpAll(() => h.setUp());
  tearDownAll(() => h.tearDown());

  final log = <String>[];
  void step(String s) => log.add(s);

  Future<void> render(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    await t.pump(const Duration(milliseconds: 500));
  }

  Future<void> shot(WidgetTester t, String name) async {
    try {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('scenario/$name.png'),
      );
    } catch (e) {
      step('SHOT_FAIL $name: $e');
    }
  }

  Future<void> tapText(WidgetTester t, String text, {bool last = false}) async {
    final f = find.text(text);
    if (f.evaluate().isEmpty) return;
    await t.tap(last ? f.last : f.first);
    await render(t);
  }

  Future<int?> lastOrderId() async {
    final r = await h.db
        .customSelect('SELECT MAX(id) id FROM service_orders')
        .getSingleOrNull();
    return r?.read<int?>('id');
  }

  Future<int?> orderStatus(int id) async {
    final r = await h.db
        .customSelect('SELECT status s FROM service_orders WHERE id = $id')
        .getSingleOrNull();
    return r?.read<int?>('s');
  }

  Future<num?> scalar(String sql) async {
    final r = await h.db.customSelect(sql).getSingleOrNull();
    return r?.data.values.first as num?;
  }

  Future<void> intake(
    WidgetTester t, {
    required String client,
    String? prepayment,
  }) async {
    h.router!.go('/service-intake');
    await render(t);
    await t.enterText(find.byType(TextField).first, client);
    await render(t);
    final catalog = find.text('Каталог услуг');
    if (catalog.evaluate().isNotEmpty) {
      await t.tap(catalog.first);
      await render(t);
      final svc = find.text('Ремонт телефона');
      if (svc.evaluate().isNotEmpty) {
        await t.tap(svc.first);
        await render(t);
        await tapText(t, 'Сохранить', last: true);
      }
    }
    if (prepayment != null) {
      final pre = find.text('Предоплата');
      if (pre.evaluate().isNotEmpty) {
        await t.tap(pre.first);
        await render(t);
        final field = find.byWidgetPredicate(
          (w) =>
              w is TextField && w.decoration?.labelText == 'Сумма предоплаты',
        );
        if (field.evaluate().isNotEmpty) {
          await t.enterText(field.first, prepayment);
          await render(t);
          await tapText(t, 'Сохранить', last: true);
        }
      }
    }
    await tapText(t, 'Сохранить', last: true);
  }

  Future<void> progress(WidgetTester t, String actionLabel) async {
    final btn = find.text(actionLabel);
    if (btn.evaluate().isEmpty) return;
    await t.tap(btn.first);
    await render(t);
    final confirm = find.text('Начать работу');
    if (confirm.evaluate().isNotEmpty) {
      await t.tap(confirm.last);
      await render(t);
    }
  }

  testWidgets('SERVICE EDGE — prepayment covers total / cancel no-revenue', (
    t,
  ) async {
    await h.db
        .into(h.db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: const Value(2001),
            barcode: const Value(4607201),
            name: const Value('Ремонт телефона'),
            type: const Value(4),
            measure: const Value(0),
            isDeleted: const Value(false),
          ),
        );
    await h.db
        .into(h.db.productPrices)
        .insert(
          ProductPricesCompanion(
            ucode: const Value(2001),
            barcode: const Value(4607201),
            sellingPrice: Value(Decimal.fromInt(5000)),
            wholesalePrice: Value(Decimal.fromInt(5000)),
          ),
        );

    await h.pumpApp(t);
    await t.pump(const Duration(seconds: 1));
    await h.loginAsCashier(t);
    await render(t);

    try {
      await intake(t, client: 'Полная Предоплата', prepayment: '5000');
      final id = await lastOrderId();
      await progress(t, 'Начать работу');
      await progress(t, 'Готов');
      await progress(t, 'Закрыт');
      final st = id != null ? await orderStatus(id) : null;
      final fin = await scalar(
        'SELECT final_amount FROM service_orders WHERE id = $id',
      );
      final salesFromClose = await scalar(
        'SELECT COALESCE(SUM(amount),0) FROM sales '
        'WHERE state IS NOT NULL AND state <> 0 AND state <> 3',
      );
      step(
        'A prepay=total: статус=$st (3=closed), итог=$fin (5000), '
        'доп.продажа на закрытии=$salesFromClose (ожидаем 0 — предоплата покрыла)',
      );
    } catch (e) {
      step('A FAILED: $e');
      await shot(t, 'se_A_FAILED');
    }

    try {
      await intake(t, client: 'Отмена Предоплата', prepayment: '2000');
      final id = await lastOrderId();
      final cancel = find.text('Отменить');
      if (cancel.evaluate().isNotEmpty) {
        await t.tap(cancel.first);
        await render(t);
        final confirm = find.text('Отменить');
        if (confirm.evaluate().isNotEmpty) {
          await t.tap(confirm.last);
          await render(t);
        }
      }
      final st = id != null ? await orderStatus(id) : null;
      final salesTotal = await scalar(
        'SELECT COALESCE(SUM(amount),0) FROM sales '
        'WHERE state IS NOT NULL AND state <> 0 AND state <> 3',
      );
      step(
        'B cancel: статус=$st (ожидаем 4=cancelled), '
        'выручка-продажи=$salesTotal (ожидаем 0 — отмена ≠ выручка)',
      );
    } catch (e) {
      step('B FAILED: $e');
      await shot(t, 'se_B_FAILED');
    }

    // ignore: avoid_print
    print('\n===== SERVICE EDGE LOG =====');
    for (final l in log) {
      // ignore: avoid_print
      print('[se] $l');
    }
    // ignore: avoid_print
    print('===== END =====\n');
  });
}
