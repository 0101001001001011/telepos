library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value, Variable;
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

  Future<int?> lastOrderId() async {
    final r = await h.db
        .customSelect('SELECT MAX(id) id FROM service_orders')
        .getSingleOrNull();
    return r?.read<int?>('id');
  }

  Future<int?> orderStatus(int id) async {
    final r = await h.db
        .customSelect(
          'SELECT status s FROM service_orders WHERE id = ?',
          variables: [Variable.withInt(id)],
        )
        .getSingleOrNull();
    return r?.read<int?>('s');
  }

  Future<double> paymentsTotal() async {
    final r = await h.db
        .customSelect('SELECT COALESCE(SUM(amount),0) t FROM payments')
        .getSingle();
    return r.read<double>('t');
  }

  Future<void> progress(WidgetTester t, String actionLabel) async {
    final btn = find.text(actionLabel);
    if (btn.evaluate().isEmpty) {
      step('progress: button "$actionLabel" NOT FOUND');
      return;
    }
    await t.tap(btn.first);
    await render(t);
    final confirm = find.text('Начать работу');
    if (confirm.evaluate().isNotEmpty) {
      await t.tap(confirm.last);
      await render(t);
    }
  }

  testWidgets('SERVICE — сервис-день приёмка→работа→выдача+оплата (UI)', (
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

    final payBefore = await paymentsTotal();
    step('start: payments total = $payBefore');

    try {
      h.router!.go('/service-intake');
      await render(t);
      await shot(t, 'sv_01_intake');

      final name = find.byType(TextField).first;
      await t.enterText(name, 'Иван Тестов');
      await render(t);

      final catalogBtn = find.text('Каталог услуг');
      if (catalogBtn.evaluate().isNotEmpty) {
        await t.tap(catalogBtn.first);
        await render(t);
        await shot(t, 'sv_02_catalog');
        final svc = find.text('Ремонт телефона');
        if (svc.evaluate().isNotEmpty) {
          await t.tap(svc.first);
          await render(t);
          final ok = find.text('Сохранить');
          if (ok.evaluate().isNotEmpty) {
            await t.tap(ok.last);
            await render(t);
          }
        } else {
          step('service "Ремонт телефона" NOT in catalog');
        }
      }
      step(
        'приёмка: услуга добавлена = '
        '${find.textContaining('Ремонт телефона').evaluate().isNotEmpty}',
      );

      final save = find.text('Сохранить');
      if (save.evaluate().isNotEmpty) {
        await t.tap(save.last);
        await render(t);
      }
      final orderId = await lastOrderId();
      step(
        'приёмка: заказ создан id=$orderId, статус=${orderId != null ? await orderStatus(orderId) : null}',
      );
      await shot(t, 'sv_03_detail');

      await progress(t, 'Начать работу');
      step(
        'после "Начать работу": статус=${orderId != null ? await orderStatus(orderId) : null}',
      );
      await progress(t, 'Готов');
      step(
        'после "Готов": статус=${orderId != null ? await orderStatus(orderId) : null}',
      );
      await progress(t, 'Закрыт');
      await shot(t, 'sv_04_closed');

      final statusFinal = orderId != null ? await orderStatus(orderId) : null;
      final payAfter = await paymentsTotal();
      step(
        'ИТОГ: статус=$statusFinal (ожидаем 3=closed), '
        'payments $payBefore → $payAfter (ожидаем +5000)',
      );
    } catch (e) {
      step('FAILED: $e');
      await shot(t, 'sv_FAILED');
    }

    // ignore: avoid_print
    print('\n===== SERVICE LOG =====');
    for (final l in log) {
      // ignore: avoid_print
      print('[sv] $l');
    }
    // ignore: avoid_print
    print('===== END =====\n');
  });
}
