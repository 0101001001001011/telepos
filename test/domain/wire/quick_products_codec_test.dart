import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/repositories/scanner_rules_repository.dart';
import 'package:telepos/domain/sale/quick_product_catalog.dart';
import 'package:telepos/domain/wire/quick_products_codec.dart';
import 'package:telepos/domain/wire/sale_ops.dart';
import 'package:telepos/domain/wire/scanner_rules_codec.dart';
import 'package:telepos/domain/wire/till_ops.dart';

/// Кодеки задачи 45: быстрые товары и правила сканера.
void main() {
  group('быстрые товары', () {
    test('цена кнопки едет строкой, а не числом (I159)', () {
      final json = quickItemsToWireJson([
        QuickProductItem(
          ucode: 7,
          name: 'Кефир',
          price: Decimal.parse('499.995'),
        ),
      ]);
      final item = (json[quickItemsKey]! as List).single as Map;
      expect(item['price'], '499.995');
    });

    test('туда и обратно — те же категории и товары, кириллица цела', () {
      const categories = [
        QuickProductCategory(id: 1, name: 'Сүт өнімдері'),
        QuickProductCategory(id: 2, name: 'Нан'),
      ];
      final items = [
        QuickProductItem(
          ucode: 100,
          name: 'Ысык-Көл суу',
          price: Decimal.parse('1234567890123.123'),
        ),
        QuickProductItem(ucode: 200, name: 'Молоко', price: Decimal.zero),
      ];

      expect(
        SaleOps.quickCategories.decode(quickCategoriesToWireJson(categories)),
        categories,
      );
      expect(SaleOps.quickItems.decode(quickItemsToWireJson(items)), items);
    });

    test('корень — ключ со значением null, а не пропущенный ключ', () {
      final root = SaleOps.quickItems.encode(null);
      expect(root.containsKey(quickItemsCategoryKey), isTrue);
      expect(root[quickItemsCategoryKey], isNull);
      expect(SaleOps.quickItems.encode(5), {quickItemsCategoryKey: 5});
    });

    test('ответ без поля цены — отказ разбора, а не цена ноль', () {
      expect(
        () => SaleOps.quickItems.decode({
          quickItemsKey: [
            {'ucode': 1, 'name': 'Молоко'},
          ],
        }),
        throwsA(anything),
      );
    });
  });

  group('правила сканера', () {
    test('туда и обратно — заданные значения', () {
      final rules = ScannerRules(
        barcodeMinLength: 8,
        barcodeMaxLength: 13,
        scannerTimeoutMs: 40,
      );
      final back = TillOps.scannerRules.decode(scannerRulesToWireJson(rules));
      expect(back.barcodeMinLength, 8);
      expect(back.barcodeMaxLength, 13);
      expect(back.scannerTimeoutMs, 40);
    });

    test('незаданное едет null и обратно остаётся незаданным', () {
      final rules = ScannerRules(
        barcodeMinLength: null,
        barcodeMaxLength: null,
        scannerTimeoutMs: null,
      );
      final json = scannerRulesToWireJson(rules);
      expect(json, hasLength(3), reason: 'все три ключа на месте');
      final back = TillOps.scannerRules.decode(json);
      expect(back.barcodeMinLength, isNull);
      expect(
        back.effectiveBarcodeMinLength,
        rules.effectiveBarcodeMinLength,
        reason: 'умолчание берёт читатель, а не провод',
      );
    });

    test('пропущенный ключ — отказ разбора, а не молчаливое умолчание', () {
      expect(
        () => TillOps.scannerRules.decode({
          'barcodeMinLength': 8,
          'barcodeMaxLength': 13,
        }),
        throwsFormatException,
        reason:
            'касса, забывшая поле, и касса без настройки выглядели бы '
            'одинаково — и терминал молча читал бы коды по зашитым длинам',
      );
    });
  });
}
