import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/measure.dart';
import 'package:telepos/core/constants/enums/product_type.dart';
import 'package:telepos/data/database/app_database.dart' as db;
import 'package:telepos/domain/repositories/product_repository.dart';

void main() {
  ProductInfo toProductInfo(db.ProductInfo row) {
    final measure = row.measure >= 0 && row.measure < Measure.values.length
        ? Measure.values[row.measure]
        : Measure.piece;
    final productType = row.type >= 0 && row.type < ProductType.values.length
        ? ProductType.values[row.type]
        : ProductType.normal;

    return ProductInfo(
      ucode: row.ucode,
      barcode: row.barcode,
      name: row.name,
      categoryId: row.categoryId,
      unitName: measure.unit,
      isWeightProduct: productType == ProductType.weight,
    );
  }

  group('ProductRepositoryImpl._toProductInfo mapping', () {
    test('normal product with piece measure', () {
      final row = db.ProductInfo(
        ucode: 1001,
        barcode: 4607001,
        name: 'Молоко 1л',
        categoryId: 5,
        type: ProductType.normal.index,
        measure: Measure.piece.index,
        isDeleted: false,
        isMarkable: false,
      );

      final info = toProductInfo(row);

      expect(info.ucode, 1001);
      expect(info.barcode, 4607001);
      expect(info.name, 'Молоко 1л');
      expect(info.categoryId, 5);
      expect(info.unitName, 'шт');
      expect(info.isWeightProduct, false);
    });

    test('weight product with kg measure', () {
      final row = db.ProductInfo(
        ucode: 2001,
        barcode: 2000001,
        name: 'Яблоки Голден',
        type: ProductType.weight.index,
        measure: Measure.kg.index,
        isDeleted: false,
        isMarkable: false,
      );

      final info = toProductInfo(row);

      expect(info.unitName, 'кг');
      expect(info.isWeightProduct, true);
    });

    test('product with liter measure', () {
      final row = db.ProductInfo(
        ucode: 3001,
        barcode: 3000001,
        name: 'Масло подсолнечное',
        type: ProductType.normal.index,
        measure: Measure.liter.index,
        isDeleted: false,
        isMarkable: false,
      );

      final info = toProductInfo(row);

      expect(info.unitName, 'литр');
      expect(info.isWeightProduct, false);
    });

    test('product with meter measure', () {
      final row = db.ProductInfo(
        ucode: 4001,
        barcode: 4000001,
        name: 'Ткань хлопок',
        type: ProductType.normal.index,
        measure: Measure.meter.index,
        isDeleted: false,
        isMarkable: false,
      );

      final info = toProductInfo(row);

      expect(info.unitName, 'метр');
      expect(info.isWeightProduct, false);
    });

    test('all measure enum values produce correct unitName', () {
      for (final m in Measure.values) {
        final row = db.ProductInfo(
          ucode: 100 + m.index,
          barcode: 100 + m.index,
          name: 'Test ${m.name}',
          type: 0,
          measure: m.index,
          isDeleted: false,
          isMarkable: false,
        );

        final info = toProductInfo(row);
        expect(info.unitName, m.unit);
      }
    });

    test('all product types: only weight is flagged', () {
      for (final pt in ProductType.values) {
        final row = db.ProductInfo(
          ucode: 200 + pt.index,
          barcode: 200 + pt.index,
          name: 'Test ${pt.name}',
          type: pt.index,
          measure: 0,
          isDeleted: false,
          isMarkable: false,
        );

        final info = toProductInfo(row);
        expect(
          info.isWeightProduct,
          pt == ProductType.weight,
          reason:
              '${pt.name} should ${pt == ProductType.weight ? "" : "not "}be weight',
        );
      }
    });

    test('invalid measure index defaults to piece', () {
      final row = db.ProductInfo(
        ucode: 5001,
        barcode: 5000001,
        name: 'Invalid measure',
        type: 0,
        measure: 99,
        isDeleted: false,
        isMarkable: false,
      );

      final info = toProductInfo(row);

      expect(info.unitName, 'шт');
      expect(info.isWeightProduct, false);
    });

    test('negative measure index defaults to piece', () {
      final row = db.ProductInfo(
        ucode: 5002,
        barcode: 5000002,
        name: 'Negative measure',
        type: 0,
        measure: -1,
        isDeleted: false,
        isMarkable: false,
      );

      final info = toProductInfo(row);

      expect(info.unitName, 'шт');
    });

    test('invalid type index defaults to normal (not weight)', () {
      final row = db.ProductInfo(
        ucode: 6001,
        barcode: 6000001,
        name: 'Invalid type',
        type: 99,
        measure: 0,
        isDeleted: false,
        isMarkable: false,
      );

      final info = toProductInfo(row);

      expect(info.isWeightProduct, false);
    });

    test('categoryName is null (Categories table has no name column)', () {
      final row = db.ProductInfo(
        ucode: 7001,
        barcode: 7000001,
        name: 'Test',
        categoryId: 10,
        type: 0,
        measure: 0,
        isDeleted: false,
        isMarkable: false,
      );

      final info = toProductInfo(row);

      expect(info.categoryId, 10);
      expect(info.categoryName, isNull);
    });
  });
}
