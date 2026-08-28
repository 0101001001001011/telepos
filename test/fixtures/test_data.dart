import 'package:decimal/decimal.dart';

class TestData {
  TestData._();

  static final testProduct1 = {
    'id': 1,
    'name': 'Молоко 1л',
    'barcode': '4607025392408',
    'price': Decimal.parse('500.00'),
    'quantity': Decimal.fromInt(10),
    'measureId': 1,
    'categoryId': 1,
  };

  static final testProduct2 = {
    'id': 2,
    'name': 'Хлеб белый',
    'barcode': '4607036278901',
    'price': Decimal.parse('150.00'),
    'quantity': Decimal.fromInt(20),
    'measureId': 1,
    'categoryId': 2,
  };

  static final weightProduct = {
    'id': 3,
    'name': 'Яблоки',
    'barcode': '2761234000003',
    'price': Decimal.parse('800.00'),
    'quantity': Decimal.parse('5.500'),
    'measureId': 2,
    'categoryId': 3,
    'isWeight': true,
  };

  static final testCategory1 = {
    'id': 1,
    'name': 'Молочные продукты',
    'sortOrder': 1,
  };

  static final testCategory2 = {
    'id': 2,
    'name': 'Хлебобулочные',
    'sortOrder': 2,
  };

  static final testAgent = {
    'id': 1,
    'name': 'Покупатель Тест',
    'phone': '+77001234567',
    'balance': Decimal.zero,
    'bonusBalance': Decimal.zero,
  };

  static final testUser = {
    'id': 1,
    'name': 'Кассир Тест',
    'login': 'cashier1',
    'role': 'CASHIER',
  };

  static final testAdmin = {
    'id': 2,
    'name': 'Администратор',
    'login': 'admin',
    'role': 'ADMIN',
  };

  static final testPosConfig = {
    'posId': 1,
    'posName': 'Касса 1',
    'storeId': 1,
    'storeName': 'Тестовый магазин',
    'priceTypeId': 1,
  };

  static final openShift = {
    'id': 1,
    'posId': 1,
    'userId': 1,
    'status': 'OPEN',
    'openedAt': DateTime(2024, 3, 15, 9, 0),
    'openingCash': Decimal.parse('10000.00'),
  };

  static final testSale = {
    'receiptNo': 1,
    'posId': 1,
    'shiftId': 1,
    'userId': 1,
    'totalAmount': Decimal.parse('650.00'),
    'paidAmount': Decimal.parse('1000.00'),
    'changeAmount': Decimal.parse('350.00'),
    'status': 'COMPLETED',
  };

  static final testSaleItem = {
    'productId': 1,
    'quantity': Decimal.one,
    'price': Decimal.parse('500.00'),
    'amount': Decimal.parse('500.00'),
  };

  static final cashPayment = {
    'accountId': 1,
    'type': 'CASH',
    'amount': Decimal.parse('1000.00'),
  };

  static final cardPayment = {
    'accountId': 2,
    'type': 'CARD',
    'amount': Decimal.parse('500.00'),
  };

  static final allProducts = [testProduct1, testProduct2, weightProduct];

  static final allCategories = [testCategory1, testCategory2];
}
