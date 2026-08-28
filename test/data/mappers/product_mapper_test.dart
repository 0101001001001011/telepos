import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/mappers/dto_mappers.dart';
import 'package:telepos/data/models/dto/dto.dart';

void main() {
  group('ProductDto', () {
    group('toJson / fromJson', () {
      test('should serialize product with all fields', () {
        final product = ProductDto(
          id: 1,
          name: 'Milk 1L',
          barcode: '4607025392408',
          categoryId: 5,
          price: '500.00',
          costPrice: '400.00',
          quantity: '10.000',
          unit: 'pcs',
          vatRate: '12.00',
          isActive: true,
          isMarked: false,
          createdAt: DateTime(2024, 3, 15, 10, 30),
          modifiedAt: DateTime(2024, 3, 20, 14, 45),
        );

        final json = product.toJson();

        expect(json['id'], equals(1));
        expect(json['name'], equals('Milk 1L'));
        expect(json['barcode'], equals('4607025392408'));
        expect(json['categoryId'], equals(5));
        expect(json['price'], equals('500.00'));
        expect(json['costPrice'], equals('400.00'));
        expect(json['quantity'], equals('10.000'));
        expect(json['unit'], equals('pcs'));
        expect(json['vatRate'], equals('12.00'));
        expect(json['isActive'], isTrue);
        expect(json['isMarked'], isFalse);
        expect(json['createdAt'], isNotNull);
        expect(json['modifiedAt'], isNotNull);
      });

      test('should deserialize product from json', () {
        final json = {
          'id': 1,
          'name': 'Bread',
          'barcode': '4607036278901',
          'categoryId': 2,
          'price': '150.00',
          'costPrice': '100.00',
          'quantity': '20.000',
          'unit': 'pcs',
          'vatRate': '12.00',
          'isActive': true,
          'isMarked': true,
          'createdAt': '2024-03-15T10:30:00.000',
          'modifiedAt': '2024-03-20T14:45:00.000',
        };

        final product = ProductDto.fromJson(json);

        expect(product.id, equals(1));
        expect(product.name, equals('Bread'));
        expect(product.barcode, equals('4607036278901'));
        expect(product.categoryId, equals(2));
        expect(product.price, equals('150.00'));
        expect(product.costPrice, equals('100.00'));
        expect(product.quantity, equals('20.000'));
        expect(product.unit, equals('pcs'));
        expect(product.vatRate, equals('12.00'));
        expect(product.isActive, isTrue);
        expect(product.isMarked, isTrue);
        expect(product.createdAt, isNotNull);
        expect(product.modifiedAt, isNotNull);
      });

      test('should handle null optional fields in json', () {
        final json = {'id': 1, 'name': 'Simple Product'};

        final product = ProductDto.fromJson(json);

        expect(product.id, equals(1));
        expect(product.name, equals('Simple Product'));
        expect(product.barcode, isNull);
        expect(product.categoryId, isNull);
        expect(product.price, isNull);
        expect(product.isActive, isTrue);
        expect(product.isMarked, isFalse);
      });

      test('should not include null fields in json output', () {
        const product = ProductDto(id: 1, name: 'Minimal Product');

        final json = product.toJson();

        expect(json.containsKey('barcode'), isFalse);
        expect(json.containsKey('categoryId'), isFalse);
        expect(json.containsKey('price'), isFalse);
        expect(json.containsKey('createdAt'), isFalse);
      });

      test('should handle roundtrip serialization', () {
        final original = ProductDto(
          id: 42,
          name: 'Roundtrip Product',
          barcode: '1234567890123',
          categoryId: 10,
          price: '999.99',
          costPrice: '750.50',
          quantity: '5.500',
          unit: 'kg',
          vatRate: '12.00',
          isActive: true,
          isMarked: true,
          createdAt: DateTime(2024, 1, 1),
          modifiedAt: DateTime(2024, 2, 1),
        );

        final json = original.toJson();
        final restored = ProductDto.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.name, equals(original.name));
        expect(restored.barcode, equals(original.barcode));
        expect(restored.categoryId, equals(original.categoryId));
        expect(restored.price, equals(original.price));
        expect(restored.costPrice, equals(original.costPrice));
        expect(restored.quantity, equals(original.quantity));
        expect(restored.unit, equals(original.unit));
        expect(restored.vatRate, equals(original.vatRate));
        expect(restored.isActive, equals(original.isActive));
        expect(restored.isMarked, equals(original.isMarked));
      });
    });

    group('toDbMap / fromDbMap', () {
      test('should convert product to database map', () {
        final product = ProductDto(
          id: 1,
          name: 'Database Product',
          barcode: '4607025392408',
          categoryId: 5,
          price: '500.00',
          costPrice: '400.00',
          quantity: '10.000',
          unit: 'pcs',
          vatRate: '12.00',
          isActive: true,
          isMarked: false,
          createdAt: DateTime(2024, 3, 15),
          modifiedAt: DateTime(2024, 3, 20),
        );

        final dbMap = product.toDbMap();

        expect(dbMap['id'], equals(1));
        expect(dbMap['name'], equals('Database Product'));
        expect(dbMap['barcode'], equals('4607025392408'));
        expect(dbMap['categoryId'], equals(5));
        expect(dbMap['price'], equals('500.00'));
        expect(dbMap['costPrice'], equals('400.00'));
        expect(dbMap['quantity'], equals('10.000'));
        expect(dbMap['unit'], equals('pcs'));
        expect(dbMap['vatRate'], equals('12.00'));
        expect(dbMap['isActive'], equals(1));
        expect(dbMap['isMarked'], equals(0));
        expect(dbMap['createdAt'], isNotNull);
        expect(dbMap['modifiedAt'], isNotNull);
      });

      test('should convert database map to product', () {
        final dbMap = {
          'id': 1,
          'name': 'From DB Product',
          'barcode': '4607036278901',
          'categoryId': 2,
          'price': '150.00',
          'costPrice': '100.00',
          'quantity': '20.000',
          'unit': 'pcs',
          'vatRate': '12.00',
          'isActive': 1,
          'isMarked': 0,
          'createdAt': '2024-03-15T10:30:00.000',
          'modifiedAt': '2024-03-20T14:45:00.000',
        };

        final product = ProductDtoMapper.fromDbMap(dbMap);

        expect(product.id, equals(1));
        expect(product.name, equals('From DB Product'));
        expect(product.barcode, equals('4607036278901'));
        expect(product.categoryId, equals(2));
        expect(product.price, equals('150.00'));
        expect(product.isActive, isTrue);
        expect(product.isMarked, isFalse);
      });

      test('should handle boolean conversion for isActive', () {
        final activeMap = {
          'id': 1,
          'name': 'Active Product',
          'isActive': 1,
          'isMarked': 0,
        };

        final inactiveMap = {
          'id': 2,
          'name': 'Inactive Product',
          'isActive': 0,
          'isMarked': 1,
        };

        final activeProduct = ProductDtoMapper.fromDbMap(activeMap);
        final inactiveProduct = ProductDtoMapper.fromDbMap(inactiveMap);

        expect(activeProduct.isActive, isTrue);
        expect(activeProduct.isMarked, isFalse);
        expect(inactiveProduct.isActive, isFalse);
        expect(inactiveProduct.isMarked, isTrue);
      });

      test('should handle null booleans as default values', () {
        final dbMap = {
          'id': 1,
          'name': 'Null Boolean Product',
          'isActive': null,
          'isMarked': null,
        };

        final product = ProductDtoMapper.fromDbMap(dbMap);

        expect(product.isActive, isFalse);
        expect(product.isMarked, isFalse);
      });
    });
  });

  group('ProductPriceDto', () {
    test('should serialize price with all fields', () {
      final price = ProductPriceDto(
        productId: 1,
        priceTypeId: 1,
        price: '500.00',
        minPrice: '450.00',
        modifiedAt: DateTime(2024, 3, 15),
      );

      final json = price.toJson();

      expect(json['productId'], equals(1));
      expect(json['priceTypeId'], equals(1));
      expect(json['price'], equals('500.00'));
      expect(json['minPrice'], equals('450.00'));
      expect(json['modifiedAt'], isNotNull);
    });

    test('should deserialize price from json', () {
      final json = {
        'productId': 1,
        'priceTypeId': 2,
        'price': '750.00',
        'minPrice': '700.00',
        'modifiedAt': '2024-03-15T10:30:00.000',
      };

      final price = ProductPriceDto.fromJson(json);

      expect(price.productId, equals(1));
      expect(price.priceTypeId, equals(2));
      expect(price.price, equals('750.00'));
      expect(price.minPrice, equals('700.00'));
    });

    test('should convert to database map', () {
      final price = ProductPriceDto(
        productId: 1,
        priceTypeId: 1,
        price: '500.00',
        minPrice: '450.00',
        modifiedAt: DateTime(2024, 3, 15),
      );

      final dbMap = price.toDbMap();

      expect(dbMap['productId'], equals(1));
      expect(dbMap['priceTypeId'], equals(1));
      expect(dbMap['price'], equals('500.00'));
      expect(dbMap['minPrice'], equals('450.00'));
    });

    test('should convert from database map', () {
      final dbMap = {
        'productId': 1,
        'priceTypeId': 1,
        'price': '500.00',
        'minPrice': '450.00',
        'modifiedAt': '2024-03-15T10:30:00.000',
      };

      final price = ProductPriceDtoMapper.fromDbMap(dbMap);

      expect(price.productId, equals(1));
      expect(price.priceTypeId, equals(1));
      expect(price.price, equals('500.00'));
      expect(price.minPrice, equals('450.00'));
    });
  });

  group('CategoryDto', () {
    test('should serialize category with all fields', () {
      const category = CategoryDto(
        id: 1,
        name: 'Dairy Products',
        parentId: null,
        sortOrder: 1,
        isActive: true,
      );

      final json = category.toJson();

      expect(json['id'], equals(1));
      expect(json['name'], equals('Dairy Products'));
      expect(json.containsKey('parentId'), isFalse);
      expect(json['sortOrder'], equals(1));
      expect(json['isActive'], isTrue);
    });

    test('should deserialize category from json', () {
      final json = {
        'id': 2,
        'name': 'Bakery',
        'parentId': 1,
        'sortOrder': 2,
        'isActive': true,
      };

      final category = CategoryDto.fromJson(json);

      expect(category.id, equals(2));
      expect(category.name, equals('Bakery'));
      expect(category.parentId, equals(1));
      expect(category.sortOrder, equals(2));
      expect(category.isActive, isTrue);
    });

    test('should handle hierarchical categories', () {
      const parent = CategoryDto(
        id: 1,
        name: 'Food',
        parentId: null,
        sortOrder: 0,
        isActive: true,
      );

      const child = CategoryDto(
        id: 2,
        name: 'Dairy',
        parentId: 1,
        sortOrder: 1,
        isActive: true,
      );

      expect(child.parentId, equals(parent.id));
    });

    test('should convert to database map', () {
      const category = CategoryDto(
        id: 1,
        name: 'Test Category',
        parentId: null,
        sortOrder: 1,
        isActive: true,
      );

      final dbMap = category.toDbMap();

      expect(dbMap['id'], equals(1));
      expect(dbMap['name'], equals('Test Category'));
      expect(dbMap['parentId'], isNull);
      expect(dbMap['sortOrder'], equals(1));
      expect(dbMap['isActive'], equals(1));
    });
  });

  group('ProductAliasDto', () {
    test('should serialize product alias', () {
      const alias = ProductAliasDto(
        id: 1,
        productId: 100,
        barcode: '4607025392408',
        coefficient: '1.0',
      );

      final json = alias.toJson();

      expect(json['id'], equals(1));
      expect(json['productId'], equals(100));
      expect(json['barcode'], equals('4607025392408'));
      expect(json['coefficient'], equals('1.0'));
    });

    test('should deserialize product alias from json', () {
      final json = {
        'id': 1,
        'productId': 100,
        'barcode': '4607025392408',
        'coefficient': '2.5',
      };

      final alias = ProductAliasDto.fromJson(json);

      expect(alias.id, equals(1));
      expect(alias.productId, equals(100));
      expect(alias.barcode, equals('4607025392408'));
      expect(alias.coefficient, equals('2.5'));
    });

    test('should handle null coefficient', () {
      final json = {'id': 1, 'productId': 100, 'barcode': '4607025392408'};

      final alias = ProductAliasDto.fromJson(json);

      expect(alias.coefficient, isNull);
    });
  });

  group('ProductPackageDto', () {
    test('should serialize product package', () {
      const package = ProductPackageDto(
        id: 1,
        productId: 100,
        name: 'Box of 12',
        coefficient: '12.0',
        barcode: '5901234123457',
      );

      final json = package.toJson();

      expect(json['id'], equals(1));
      expect(json['productId'], equals(100));
      expect(json['name'], equals('Box of 12'));
      expect(json['coefficient'], equals('12.0'));
      expect(json['barcode'], equals('5901234123457'));
    });

    test('should deserialize product package from json', () {
      final json = {
        'id': 1,
        'productId': 100,
        'name': 'Pack of 6',
        'coefficient': '6.0',
        'barcode': '5901234123458',
      };

      final package = ProductPackageDto.fromJson(json);

      expect(package.id, equals(1));
      expect(package.productId, equals(100));
      expect(package.name, equals('Pack of 6'));
      expect(package.coefficient, equals('6.0'));
      expect(package.barcode, equals('5901234123458'));
    });

    test('should handle null barcode', () {
      final json = {
        'id': 1,
        'productId': 100,
        'name': 'Bulk',
        'coefficient': '1.0',
      };

      final package = ProductPackageDto.fromJson(json);

      expect(package.barcode, isNull);
    });
  });

  group('CategoryRestrictionDto', () {
    test('should serialize category restriction', () {
      const restriction = CategoryRestrictionDto(
        categoryId: 1,
        userId: 10,
        canSell: true,
        canRefund: false,
        canDiscount: true,
      );

      final json = restriction.toJson();

      expect(json['categoryId'], equals(1));
      expect(json['userId'], equals(10));
      expect(json['canSell'], isTrue);
      expect(json['canRefund'], isFalse);
      expect(json['canDiscount'], isTrue);
    });

    test('should deserialize category restriction from json', () {
      final json = {
        'categoryId': 5,
        'userId': 2,
        'canSell': false,
        'canRefund': true,
        'canDiscount': false,
      };

      final restriction = CategoryRestrictionDto.fromJson(json);

      expect(restriction.categoryId, equals(5));
      expect(restriction.userId, equals(2));
      expect(restriction.canSell, isFalse);
      expect(restriction.canRefund, isTrue);
      expect(restriction.canDiscount, isFalse);
    });

    test('should use default values for missing permissions', () {
      final json = {'categoryId': 1, 'userId': 1};

      final restriction = CategoryRestrictionDto.fromJson(json);

      expect(restriction.canSell, isTrue);
      expect(restriction.canRefund, isTrue);
      expect(restriction.canDiscount, isTrue);
    });
  });
}
