// ignore_for_file: avoid_print
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/services/global_product_import_service.dart';

void main() {
  late AppDatabase db;
  late GlobalProductImportService importService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importService = GlobalProductImportService(
      db.globalProductDao,
      db.categoryDao,
      db.productInfoDao,
      db.productPriceDao,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('GlobalProductImportService Integration', () {
    test('needsImport returns true for empty database', () async {
      final needs = await importService.needsImport();
      expect(needs, isTrue);
    });

    test(
      'import loads products into database',
      () async {
        final file = File('docs/products/global_product.json');
        if (!file.existsSync()) {
          print('Skipping: JSON file not found');
          return;
        }

        final progressMessages = <String>[];

        final count = await importService.import(
          onProgress: (progress, message) {
            progressMessages.add('${(progress * 100).toInt()}% - $message');
            print(message);
          },
          fromFile: 'docs/products/global_product.json',
        );

        print('Imported: $count products');

        expect(count, greaterThan(100000));

        final needsAfter = await importService.needsImport();
        expect(needsAfter, isFalse);

        final dbCount = await db.globalProductDao.count();
        expect(dbCount, equals(count));

        final product = await db.globalProductDao.findByBarcode(
          '4602248003667',
        );
        expect(product, isNotNull);
        expect(product!.name, contains('Хлопья'));
        print('Found: ${product.name}');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test('reimport clears and reloads', () async {
      final file = File('docs/products/global_product.json');
      if (!file.existsSync()) {
        print('Skipping: JSON file not found');
        return;
      }

      await importService.import(fromFile: 'docs/products/global_product.json');

      final countBefore = await db.globalProductDao.count();

      final countAfter = await importService.reimport(
        onProgress: (p, m) => print(m),
        fromFile: 'docs/products/global_product.json',
      );

      expect(countAfter, equals(countBefore));
    }, timeout: const Timeout(Duration(minutes: 10)));

    test('searchByName finds products', () async {
      final file = File('docs/products/global_product.json');
      if (!file.existsSync()) {
        print('Skipping: JSON file not found');
        return;
      }

      await importService.import(fromFile: 'docs/products/global_product.json');

      final results = await db.globalProductDao.searchByName('молоко');
      print('Found ${results.length} products with "молоко"');

      expect(results, isNotEmpty);
      for (final p in results.take(5)) {
        print('  - ${p.name}');
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
