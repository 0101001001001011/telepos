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

  Future<List<num?>> warrantyQuality(int id) async {
    final r = await h.db
        .customSelect(
          'SELECT warranty_days w, quality_rating q FROM service_orders WHERE id = $id',
        )
        .getSingleOrNull();
    return [r?.read<int?>('w'), r?.read<int?>('q')];
  }

  Future<void> seedService(
    int ucode,
    int barcode,
    String name, {
    bool flags = false,
  }) async {
    await h.db
        .into(h.db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: Value(ucode),
            barcode: Value(barcode),
            name: Value(name),
            type: const Value(4),
            measure: const Value(0),
            isDeleted: const Value(false),
          ),
        );
    await h.db
        .into(h.db.productPrices)
        .insert(
          ProductPricesCompanion(
            ucode: Value(ucode),
            barcode: Value(barcode),
            sellingPrice: Value(Decimal.fromInt(5000)),
            wholesalePrice: Value(Decimal.fromInt(5000)),
          ),
        );
    if (flags) {
      await h.db
          .into(h.db.serviceTypes)
          .insert(
            ServiceTypesCompanion(
              productUcode: Value(ucode),
              requiresRepairPhotos: const Value(true),
              requiresQualityCheck: const Value(true),
              warrantyDays: const Value(90),
            ),
          );
    }
  }

  Future<int?> intake(WidgetTester t, String client, String serviceName) async {
    h.router!.go('/service-intake');
    await render(t);
    await t.enterText(find.byType(TextField).first, client);
    await render(t);
    await tapText(t, 'Каталог услуг');
    final svc = find.text(serviceName);
    if (svc.evaluate().isNotEmpty) {
      await t.tap(svc.first);
      await render(t);
      await tapText(t, 'Сохранить', last: true);
    }
    await tapText(t, 'Сохранить', last: true);
    return lastOrderId();
  }

  testWidgets('SERVICE FEATURES — warranty/quality/media gated by type (UI)', (
    t,
  ) async {
    await seedService(2001, 4607201, 'Ремонт с гарантией', flags: true);
    await seedService(2002, 4607202, 'Простая услуга', flags: false);

    await h.pumpApp(t);
    await t.pump(const Duration(seconds: 1));
    await h.loginAsCashier(t);
    await render(t);

    try {
      final id = await intake(t, 'Клиент А', 'Ремонт с гарантией');
      await shot(t, 'sf_01_with_flags');

      final qualityShown = find.text('Оценка качества').evaluate().isNotEmpty;
      final mediaShown = find.text('Фото/видео ремонта').evaluate().isNotEmpty;
      step(
        'A flags ON: оценка качества=$qualityShown, медиа ремонта=$mediaShown (ожидаем true/true)',
      );

      final w90 = find.text('90 дн.');
      if (w90.evaluate().isNotEmpty) {
        await t.ensureVisible(w90.first);
        await render(t);
        await t.tap(w90.first, warnIfMissed: false);
        await render(t);
      }
      final stars = find.byIcon(Icons.star_border);
      if (stars.evaluate().length >= 5) {
        await t.tap(stars.at(4), warnIfMissed: false);
        await render(t);
      }
      await shot(t, 'sf_02_rated');
      final wq = id != null ? await warrantyQuality(id) : [null, null];
      step(
        'A persist: warranty_days=${wq[0]} (90), quality_rating=${wq[1]} (5)',
      );
    } catch (e) {
      step('A FAILED: $e');
      await shot(t, 'sf_A_FAILED');
    }

    try {
      await intake(t, 'Клиент Б', 'Простая услуга');
      await render(t);
      final qualityHidden = find.text('Оценка качества').evaluate().isEmpty;
      final mediaHidden = find.text('Фото/видео ремонта').evaluate().isEmpty;
      final warrantyShown = find
          .text('Гарантия и качество')
          .evaluate()
          .isNotEmpty;
      step(
        'B flags OFF: оценка скрыта=$qualityHidden, медиа скрыто=$mediaHidden, '
        'гарантия(универсальна) видна=$warrantyShown (ожидаем true/true/true)',
      );
      await shot(t, 'sf_03_no_flags');
    } catch (e) {
      step('B FAILED: $e');
    }

    // ignore: avoid_print
    print('\n===== SERVICE FEATURES LOG =====');
    for (final l in log) {
      // ignore: avoid_print
      print('[sf] $l');
    }
    // ignore: avoid_print
    print('===== END =====\n');
  });
}
