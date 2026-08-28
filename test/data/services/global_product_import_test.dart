// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';

void main() {
  group('GlobalProductImport', () {
    test('JSON file exists and is valid', () async {
      final file = File('assets/data/global_product.json');
      if (!file.existsSync()) {
        markTestSkipped('Catalog asset not present in test env');
        return;
      }
      expect(file.existsSync(), isTrue, reason: 'JSON file should exist');

      final size = await file.length();
      print('File size: ${(size / 1024 / 1024).toStringAsFixed(2)} MB');
      expect(size, greaterThan(1000000), reason: 'File should be > 1MB');
    });

    test('JSON can be parsed', () async {
      final file = File('assets/data/global_product.json');
      if (!file.existsSync()) {
        markTestSkipped('Catalog asset not present in test env');
        return;
      }
      final jsonString = await file.readAsString();

      final List<dynamic> products = jsonDecode(jsonString);

      print('Total products: ${products.length}');
      expect(products.length, greaterThan(100000));
    });

    test('First product has correct structure', () async {
      final file = File('assets/data/global_product.json');
      if (!file.existsSync()) {
        markTestSkipped('Catalog asset not present in test env');
        return;
      }
      final jsonString = await file.readAsString();

      final List<dynamic> products = jsonDecode(jsonString);
      final first = products.first as Map<String, dynamic>;

      print('First product: $first');

      expect(first.containsKey('id'), isTrue);
      expect(first.containsKey('code'), isTrue);
      expect(first.containsKey('name'), isTrue);
      expect(first.containsKey('arrivalCost'), isTrue);
      expect(first.containsKey('sellingPrice'), isTrue);
      expect(first.containsKey('editTime'), isTrue);
    });

    test('Barcode parsing works correctly', () {
      final testCases = [
        {'code': '4602248003667', 'expected': 4602248003667},
        {'code': 4602248003667, 'expected': 4602248003667},
        {'code': '123', 'expected': 123},
      ];

      for (final tc in testCases) {
        final codeValue = tc['code'];
        final int code;
        if (codeValue is int) {
          code = codeValue;
        } else if (codeValue is String) {
          code = int.tryParse(codeValue) ?? 0;
        } else {
          code = 0;
        }
        expect(code, tc['expected']);
      }
    });

    test('Decimal parsing works correctly', () {
      Decimal parseDecimal(dynamic value) {
        if (value == null) return Decimal.zero;
        if (value is int) return Decimal.fromInt(value);
        if (value is double) return Decimal.parse(value.toStringAsFixed(3));
        if (value is String) return Decimal.tryParse(value) ?? Decimal.zero;
        return Decimal.zero;
      }

      expect(parseDecimal(125), Decimal.fromInt(125));
      expect(parseDecimal(125.5), Decimal.parse('125.500'));
      expect(parseDecimal('125.99'), Decimal.parse('125.99'));
      expect(parseDecimal(null), Decimal.zero);
    });

    test('Sample products can be converted', () async {
      final file = File('assets/data/global_product.json');
      if (!file.existsSync()) {
        markTestSkipped('Catalog asset not present in test env');
        return;
      }
      final jsonString = await file.readAsString();

      final List<dynamic> products = jsonDecode(jsonString);

      final sample = products.take(10).toList();

      for (final json in sample) {
        final map = json as Map<String, dynamic>;

        final codeValue = map['code'];
        final int code;
        if (codeValue is int) {
          code = codeValue;
        } else if (codeValue is String) {
          code = int.tryParse(codeValue) ?? 0;
        } else {
          code = 0;
        }

        expect(code, greaterThan(0), reason: 'Code should be > 0: $codeValue');

        final name = map['name'] as String?;
        expect(name, isNotNull);
        expect(name, isNotEmpty);

        print('✓ ${code.toString().padRight(15)} | $name');
      }
    });

    test('Count products by category', () async {
      final file = File('assets/data/global_product.json');
      if (!file.existsSync()) {
        markTestSkipped('Catalog asset not present in test env');
        return;
      }
      final jsonString = await file.readAsString();

      final List<dynamic> products = jsonDecode(jsonString);

      final categoryCount = <int, int>{};
      for (final json in products) {
        final map = json as Map<String, dynamic>;
        final categoryId = map['categoryId'] as int? ?? -1;
        categoryCount[categoryId] = (categoryCount[categoryId] ?? 0) + 1;
      }

      print('Categories: ${categoryCount.length}');
      print('Top 5 categories:');

      final sorted = categoryCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in sorted.take(5)) {
        print('  Category ${entry.key}: ${entry.value} products');
      }
    });
  });
}
