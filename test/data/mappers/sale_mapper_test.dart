import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/mappers/dto_mappers.dart';
import 'package:telepos/data/models/dto/dto.dart';

void main() {
  group('SaleDto', () {
    group('toJson / fromJson', () {
      test('should serialize sale with all fields', () {
        final sale = SaleDto(
          receiptNo: 1,
          posId: 100,
          shiftId: 1,
          amount: '1500.50',
          discount: '100.00',
          cashAmount: '1000.00',
          cardAmount: '400.50',
          agentId: 5,
          userId: 1,
          items: const [
            SaleItemDto(
              productId: 1,
              productName: 'Milk',
              quantity: '2.000',
              price: '500.00',
              amount: '1000.00',
            ),
          ],
          payments: const [
            SalePaymentDto(type: 'CASH', amount: '1000.00', accountId: 1),
          ],
          fiscalNo: 'WK-2024-001',
          syncState: 'SYNCED',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          modifiedAt: DateTime(2024, 3, 15, 10, 35),
        );

        final json = sale.toJson();

        expect(json['receiptNo'], equals(1));
        expect(json['posId'], equals(100));
        expect(json['shiftId'], equals(1));
        expect(json['amount'], equals('1500.50'));
        expect(json['discount'], equals('100.00'));
        expect(json['cashAmount'], equals('1000.00'));
        expect(json['cardAmount'], equals('400.50'));
        expect(json['agentId'], equals(5));
        expect(json['userId'], equals(1));
        expect(json['items'], isA<List>());
        expect((json['items'] as List).length, equals(1));
        expect(json['payments'], isA<List>());
        expect((json['payments'] as List).length, equals(1));
        expect(json['fiscalNo'], equals('WK-2024-001'));
        expect(json['syncState'], equals('SYNCED'));
        expect(json['createdAt'], isNotNull);
        expect(json['modifiedAt'], isNotNull);
      });

      test('should deserialize sale from json', () {
        final json = {
          'receiptNo': 1,
          'posId': 100,
          'shiftId': 1,
          'amount': '1500.50',
          'discount': '100.00',
          'cashAmount': '1000.00',
          'cardAmount': '400.50',
          'agentId': 5,
          'userId': 1,
          'items': [
            {
              'productId': 1,
              'productName': 'Milk',
              'quantity': '2.000',
              'price': '500.00',
              'amount': '1000.00',
            },
          ],
          'payments': [
            {'type': 'CASH', 'amount': '1000.00', 'accountId': 1},
          ],
          'fiscalNo': 'WK-2024-001',
          'syncState': 'SYNCED',
          'createdAt': '2024-03-15T10:30:00.000',
          'modifiedAt': '2024-03-15T10:35:00.000',
        };

        final sale = SaleDto.fromJson(json);

        expect(sale.receiptNo, equals(1));
        expect(sale.posId, equals(100));
        expect(sale.shiftId, equals(1));
        expect(sale.amount, equals('1500.50'));
        expect(sale.discount, equals('100.00'));
        expect(sale.items.length, equals(1));
        expect(sale.payments.length, equals(1));
        expect(sale.fiscalNo, equals('WK-2024-001'));
        expect(sale.syncState, equals('SYNCED'));
      });

      test('should handle sale without optional fields', () {
        final json = {
          'receiptNo': 1,
          'posId': 100,
          'shiftId': 1,
          'amount': '1500.50',
        };

        final sale = SaleDto.fromJson(json);

        expect(sale.receiptNo, equals(1));
        expect(sale.posId, equals(100));
        expect(sale.amount, equals('1500.50'));
        expect(sale.discount, isNull);
        expect(sale.cashAmount, isNull);
        expect(sale.cardAmount, isNull);
        expect(sale.agentId, isNull);
        expect(sale.userId, isNull);
        expect(sale.items, isEmpty);
        expect(sale.payments, isEmpty);
        expect(sale.fiscalNo, isNull);
      });

      test('should handle roundtrip serialization', () {
        final original = SaleDto(
          receiptNo: 42,
          posId: 100,
          shiftId: 5,
          amount: '999.99',
          discount: '50.00',
          cashAmount: '500.00',
          cardAmount: '449.99',
          agentId: 10,
          userId: 2,
          items: const [
            SaleItemDto(
              productId: 1,
              productName: 'Product A',
              quantity: '1.000',
              price: '500.00',
              amount: '500.00',
            ),
            SaleItemDto(
              productId: 2,
              productName: 'Product B',
              quantity: '2.000',
              price: '249.995',
              amount: '499.99',
              discount: '50.00',
            ),
          ],
          payments: const [
            SalePaymentDto(type: 'CASH', amount: '500.00'),
            SalePaymentDto(type: 'CARD', amount: '449.99'),
          ],
          fiscalNo: 'FISCAL-123',
          syncState: 'PENDING_SYNC',
          createdAt: DateTime(2024, 1, 1, 12, 0),
          modifiedAt: DateTime(2024, 1, 1, 12, 5),
        );

        final json = original.toJson();
        final restored = SaleDto.fromJson(json);

        expect(restored.receiptNo, equals(original.receiptNo));
        expect(restored.posId, equals(original.posId));
        expect(restored.shiftId, equals(original.shiftId));
        expect(restored.amount, equals(original.amount));
        expect(restored.discount, equals(original.discount));
        expect(restored.items.length, equals(original.items.length));
        expect(restored.payments.length, equals(original.payments.length));
        expect(restored.fiscalNo, equals(original.fiscalNo));
        expect(restored.syncState, equals(original.syncState));
      });
    });

    group('toDbMap / fromDbMap', () {
      test('should convert sale to database map', () {
        final sale = SaleDto(
          receiptNo: 1,
          posId: 100,
          shiftId: 1,
          amount: '1500.50',
          discount: '100.00',
          cashAmount: '1000.00',
          cardAmount: '400.50',
          agentId: 5,
          userId: 1,
          fiscalNo: 'WK-2024-001',
          syncState: 'SYNCED',
          createdAt: DateTime(2024, 3, 15),
          modifiedAt: DateTime(2024, 3, 20),
        );

        final dbMap = sale.toDbMap();

        expect(dbMap['receiptNo'], equals(1));
        expect(dbMap['posId'], equals(100));
        expect(dbMap['shiftId'], equals(1));
        expect(dbMap['amount'], equals('1500.50'));
        expect(dbMap['discount'], equals('100.00'));
        expect(dbMap['cashAmount'], equals('1000.00'));
        expect(dbMap['cardAmount'], equals('400.50'));
        expect(dbMap['agentId'], equals(5));
        expect(dbMap['userId'], equals(1));
        expect(dbMap['fiscalNo'], equals('WK-2024-001'));
        expect(dbMap['syncState'], equals('SYNCED'));
      });

      test('should convert database map to sale', () {
        final dbMap = {
          'receiptNo': 1,
          'posId': 100,
          'shiftId': 1,
          'amount': '1500.50',
          'discount': '100.00',
          'cashAmount': '1000.00',
          'cardAmount': '400.50',
          'agentId': 5,
          'userId': 1,
          'fiscalNo': 'WK-2024-001',
          'syncState': 'SYNCED',
          'createdAt': '2024-03-15T10:30:00.000',
          'modifiedAt': '2024-03-20T14:45:00.000',
        };

        final sale = SaleDtoMapper.fromDbMap(dbMap);

        expect(sale.receiptNo, equals(1));
        expect(sale.posId, equals(100));
        expect(sale.shiftId, equals(1));
        expect(sale.amount, equals('1500.50'));
        expect(sale.discount, equals('100.00'));
        expect(sale.cashAmount, equals('1000.00'));
        expect(sale.cardAmount, equals('400.50'));
        expect(sale.agentId, equals(5));
        expect(sale.userId, equals(1));
        expect(sale.fiscalNo, equals('WK-2024-001'));
        expect(sale.syncState, equals('SYNCED'));
      });
    });
  });

  group('SaleItemDto', () {
    test('should serialize sale item with all fields', () {
      const item = SaleItemDto(
        productId: 1,
        productName: 'Milk 1L',
        quantity: '2.000',
        price: '500.00',
        amount: '1000.00',
        discount: '50.00',
        vatAmount: '120.00',
        barcode: '4607025392408',
        mark: 'MARK123456',
      );

      final json = item.toJson();

      expect(json['productId'], equals(1));
      expect(json['productName'], equals('Milk 1L'));
      expect(json['quantity'], equals('2.000'));
      expect(json['price'], equals('500.00'));
      expect(json['amount'], equals('1000.00'));
      expect(json['discount'], equals('50.00'));
      expect(json['vatAmount'], equals('120.00'));
      expect(json['barcode'], equals('4607025392408'));
      expect(json['mark'], equals('MARK123456'));
    });

    test('should deserialize sale item from json', () {
      final json = {
        'productId': 1,
        'productName': 'Milk 1L',
        'quantity': '2.000',
        'price': '500.00',
        'amount': '1000.00',
        'discount': '50.00',
        'vatAmount': '120.00',
        'barcode': '4607025392408',
        'mark': 'MARK123456',
      };

      final item = SaleItemDto.fromJson(json);

      expect(item.productId, equals(1));
      expect(item.productName, equals('Milk 1L'));
      expect(item.quantity, equals('2.000'));
      expect(item.price, equals('500.00'));
      expect(item.amount, equals('1000.00'));
      expect(item.discount, equals('50.00'));
      expect(item.vatAmount, equals('120.00'));
      expect(item.barcode, equals('4607025392408'));
      expect(item.mark, equals('MARK123456'));
    });

    test('should handle sale item without optional fields', () {
      final json = {
        'productId': 1,
        'productName': 'Simple Product',
        'quantity': '1.000',
        'price': '100.00',
        'amount': '100.00',
      };

      final item = SaleItemDto.fromJson(json);

      expect(item.productId, equals(1));
      expect(item.productName, equals('Simple Product'));
      expect(item.discount, isNull);
      expect(item.vatAmount, isNull);
      expect(item.barcode, isNull);
      expect(item.mark, isNull);
    });

    test('should convert sale item to database map with keys', () {
      const item = SaleItemDto(
        productId: 1,
        productName: 'Milk 1L',
        quantity: '2.000',
        price: '500.00',
        amount: '1000.00',
      );

      final dbMap = item.toDbMap(1, 100);

      expect(dbMap['receiptNo'], equals(1));
      expect(dbMap['posId'], equals(100));
      expect(dbMap['productId'], equals(1));
      expect(dbMap['productName'], equals('Milk 1L'));
      expect(dbMap['quantity'], equals('2.000'));
      expect(dbMap['price'], equals('500.00'));
      expect(dbMap['amount'], equals('1000.00'));
    });
  });

  group('SalePaymentDto', () {
    test('should serialize cash payment', () {
      const payment = SalePaymentDto(
        type: 'CASH',
        amount: '1000.00',
        accountId: 1,
        reference: 'REF-001',
      );

      final json = payment.toJson();

      expect(json['type'], equals('CASH'));
      expect(json['amount'], equals('1000.00'));
      expect(json['accountId'], equals(1));
      expect(json['reference'], equals('REF-001'));
    });

    test('should serialize card payment', () {
      const payment = SalePaymentDto(
        type: 'CARD',
        amount: '500.00',
        accountId: 2,
        reference: 'CARD-TXN-12345',
      );

      final json = payment.toJson();

      expect(json['type'], equals('CARD'));
      expect(json['amount'], equals('500.00'));
      expect(json['accountId'], equals(2));
      expect(json['reference'], equals('CARD-TXN-12345'));
    });

    test('should deserialize payment from json', () {
      final json = {
        'type': 'CASH',
        'amount': '750.00',
        'accountId': 1,
        'reference': 'CASH-REF',
      };

      final payment = SalePaymentDto.fromJson(json);

      expect(payment.type, equals('CASH'));
      expect(payment.amount, equals('750.00'));
      expect(payment.accountId, equals(1));
      expect(payment.reference, equals('CASH-REF'));
    });

    test('should handle payment without optional fields', () {
      final json = {'type': 'CASH', 'amount': '500.00'};

      final payment = SalePaymentDto.fromJson(json);

      expect(payment.type, equals('CASH'));
      expect(payment.amount, equals('500.00'));
      expect(payment.accountId, isNull);
      expect(payment.reference, isNull);
    });

    test('should convert payment to database map with keys', () {
      const payment = SalePaymentDto(
        type: 'CASH',
        amount: '1000.00',
        accountId: 1,
      );

      final dbMap = payment.toDbMap(1, 100);

      expect(dbMap['receiptNo'], equals(1));
      expect(dbMap['posId'], equals(100));
      expect(dbMap['type'], equals('CASH'));
      expect(dbMap['amount'], equals('1000.00'));
      expect(dbMap['accountId'], equals(1));
    });
  });

  group('RefundDto', () {
    test('should serialize refund with all fields', () {
      final refund = RefundDto(
        id: 1,
        posId: 100,
        shiftId: 1,
        amount: '500.00',
        originalReceiptNo: 1,
        originalPosId: 100,
        reason: 'Defective product',
        agentId: 5,
        userId: 1,
        items: const [
          RefundItemDto(
            productId: 1,
            productName: 'Milk 1L',
            quantity: '1.000',
            price: '500.00',
            amount: '500.00',
          ),
        ],
        fiscalNo: 'WK-REFUND-001',
        syncState: 'PENDING_SYNC',
        createdAt: DateTime(2024, 3, 16),
      );

      final json = refund.toJson();

      expect(json['id'], equals(1));
      expect(json['posId'], equals(100));
      expect(json['shiftId'], equals(1));
      expect(json['amount'], equals('500.00'));
      expect(json['originalReceiptNo'], equals(1));
      expect(json['originalPosId'], equals(100));
      expect(json['reason'], equals('Defective product'));
      expect(json['agentId'], equals(5));
      expect(json['userId'], equals(1));
      expect(json['items'], isA<List>());
      expect((json['items'] as List).length, equals(1));
      expect(json['fiscalNo'], equals('WK-REFUND-001'));
      expect(json['syncState'], equals('PENDING_SYNC'));
    });

    test('should deserialize refund from json', () {
      final json = {
        'id': 1,
        'posId': 100,
        'shiftId': 1,
        'amount': '500.00',
        'originalReceiptNo': 1,
        'originalPosId': 100,
        'reason': 'Defective product',
        'agentId': 5,
        'userId': 1,
        'items': [
          {
            'productId': 1,
            'productName': 'Milk 1L',
            'quantity': '1.000',
            'price': '500.00',
            'amount': '500.00',
          },
        ],
        'fiscalNo': 'WK-REFUND-001',
        'syncState': 'PENDING_SYNC',
        'createdAt': '2024-03-16T10:00:00.000',
      };

      final refund = RefundDto.fromJson(json);

      expect(refund.id, equals(1));
      expect(refund.posId, equals(100));
      expect(refund.shiftId, equals(1));
      expect(refund.amount, equals('500.00'));
      expect(refund.originalReceiptNo, equals(1));
      expect(refund.originalPosId, equals(100));
      expect(refund.reason, equals('Defective product'));
      expect(refund.items.length, equals(1));
      expect(refund.fiscalNo, equals('WK-REFUND-001'));
    });

    test('should handle refund without original receipt (blind refund)', () {
      final json = {
        'id': 1,
        'posId': 100,
        'shiftId': 1,
        'amount': '100.00',
        'reason': 'Customer request',
      };

      final refund = RefundDto.fromJson(json);

      expect(refund.originalReceiptNo, isNull);
      expect(refund.originalPosId, isNull);
      expect(refund.reason, equals('Customer request'));
    });

    test('should convert refund to database map', () {
      final refund = RefundDto(
        id: 1,
        posId: 100,
        shiftId: 1,
        amount: '500.00',
        originalReceiptNo: 1,
        originalPosId: 100,
        reason: 'Defective',
        agentId: 5,
        userId: 1,
        fiscalNo: 'FISCAL-001',
        syncState: 'SYNCED',
        createdAt: DateTime(2024, 3, 16),
      );

      final dbMap = refund.toDbMap();

      expect(dbMap['id'], equals(1));
      expect(dbMap['posId'], equals(100));
      expect(dbMap['shiftId'], equals(1));
      expect(dbMap['amount'], equals('500.00'));
      expect(dbMap['originalReceiptNo'], equals(1));
      expect(dbMap['originalPosId'], equals(100));
      expect(dbMap['reason'], equals('Defective'));
      expect(dbMap['agentId'], equals(5));
      expect(dbMap['userId'], equals(1));
      expect(dbMap['fiscalNo'], equals('FISCAL-001'));
      expect(dbMap['syncState'], equals('SYNCED'));
    });
  });

  group('RefundItemDto', () {
    test('should serialize refund item with all fields', () {
      const item = RefundItemDto(
        productId: 1,
        productName: 'Milk 1L',
        quantity: '1.000',
        price: '500.00',
        amount: '500.00',
        mark: 'MARK123456',
      );

      final json = item.toJson();

      expect(json['productId'], equals(1));
      expect(json['productName'], equals('Milk 1L'));
      expect(json['quantity'], equals('1.000'));
      expect(json['price'], equals('500.00'));
      expect(json['amount'], equals('500.00'));
      expect(json['mark'], equals('MARK123456'));
    });

    test('should deserialize refund item from json', () {
      final json = {
        'productId': 1,
        'productName': 'Milk 1L',
        'quantity': '1.000',
        'price': '500.00',
        'amount': '500.00',
        'mark': 'MARK123456',
      };

      final item = RefundItemDto.fromJson(json);

      expect(item.productId, equals(1));
      expect(item.productName, equals('Milk 1L'));
      expect(item.quantity, equals('1.000'));
      expect(item.price, equals('500.00'));
      expect(item.amount, equals('500.00'));
      expect(item.mark, equals('MARK123456'));
    });

    test('should handle refund item without mark', () {
      final json = {
        'productId': 1,
        'productName': 'Simple Product',
        'quantity': '1.000',
        'price': '100.00',
        'amount': '100.00',
      };

      final item = RefundItemDto.fromJson(json);

      expect(item.mark, isNull);
    });
  });

  group('ShiftDto', () {
    test('should serialize open shift', () {
      final shift = ShiftDto(
        id: 1,
        posId: 100,
        userId: 1,
        status: 'OPEN',
        openedAt: DateTime(2024, 3, 15, 9, 0),
        openingCash: '10000.00',
        syncState: 'SYNCED',
      );

      final json = shift.toJson();

      expect(json['id'], equals(1));
      expect(json['posId'], equals(100));
      expect(json['userId'], equals(1));
      expect(json['status'], equals('OPEN'));
      expect(json['openedAt'], isNotNull);
      expect(json['openingCash'], equals('10000.00'));
      expect(json['syncState'], equals('SYNCED'));
      expect(json.containsKey('closedAt'), isFalse);
      expect(json.containsKey('closingCash'), isFalse);
    });

    test('should serialize closed shift with totals', () {
      final shift = ShiftDto(
        id: 1,
        posId: 100,
        userId: 1,
        status: 'CLOSED',
        openedAt: DateTime(2024, 3, 15, 9, 0),
        closedAt: DateTime(2024, 3, 15, 21, 0),
        openingCash: '10000.00',
        closingCash: '25000.00',
        salesCount: 50,
        salesAmount: '75000.00',
        refundsCount: 2,
        refundsAmount: '1500.00',
        syncState: 'SYNCED',
      );

      final json = shift.toJson();

      expect(json['status'], equals('CLOSED'));
      expect(json['closedAt'], isNotNull);
      expect(json['closingCash'], equals('25000.00'));
      expect(json['salesCount'], equals(50));
      expect(json['salesAmount'], equals('75000.00'));
      expect(json['refundsCount'], equals(2));
      expect(json['refundsAmount'], equals('1500.00'));
    });

    test('should deserialize shift from json', () {
      final json = {
        'id': 1,
        'posId': 100,
        'userId': 1,
        'status': 'OPEN',
        'openedAt': '2024-03-15T09:00:00.000',
        'openingCash': '10000.00',
        'syncState': 'SYNCED',
      };

      final shift = ShiftDto.fromJson(json);

      expect(shift.id, equals(1));
      expect(shift.posId, equals(100));
      expect(shift.userId, equals(1));
      expect(shift.status, equals('OPEN'));
      expect(shift.openedAt, isNotNull);
      expect(shift.openingCash, equals('10000.00'));
      expect(shift.syncState, equals('SYNCED'));
    });

    test('should convert shift to database map', () {
      final shift = ShiftDto(
        id: 1,
        posId: 100,
        userId: 1,
        status: 'OPEN',
        openedAt: DateTime(2024, 3, 15, 9, 0),
        openingCash: '10000.00',
        salesCount: 10,
        salesAmount: '15000.00',
        refundsCount: 1,
        refundsAmount: '500.00',
        syncState: 'SYNCED',
      );

      final dbMap = shift.toDbMap();

      expect(dbMap['id'], equals(1));
      expect(dbMap['posId'], equals(100));
      expect(dbMap['userId'], equals(1));
      expect(dbMap['status'], equals('OPEN'));
      expect(dbMap['openingCash'], equals('10000.00'));
      expect(dbMap['salesCount'], equals(10));
      expect(dbMap['salesAmount'], equals('15000.00'));
      expect(dbMap['refundsCount'], equals(1));
      expect(dbMap['refundsAmount'], equals('500.00'));
      expect(dbMap['syncState'], equals('SYNCED'));
    });

    test('should convert database map to shift', () {
      final dbMap = {
        'id': 1,
        'posId': 100,
        'userId': 1,
        'status': 'CLOSED',
        'openedAt': '2024-03-15T09:00:00.000',
        'closedAt': '2024-03-15T21:00:00.000',
        'openingCash': '10000.00',
        'closingCash': '25000.00',
        'salesCount': 50,
        'salesAmount': '75000.00',
        'refundsCount': 2,
        'refundsAmount': '1500.00',
        'syncState': 'SYNCED',
      };

      final shift = ShiftDtoMapper.fromDbMap(dbMap);

      expect(shift.id, equals(1));
      expect(shift.posId, equals(100));
      expect(shift.userId, equals(1));
      expect(shift.status, equals('CLOSED'));
      expect(shift.openedAt, isNotNull);
      expect(shift.closedAt, isNotNull);
      expect(shift.openingCash, equals('10000.00'));
      expect(shift.closingCash, equals('25000.00'));
      expect(shift.salesCount, equals(50));
      expect(shift.salesAmount, equals('75000.00'));
      expect(shift.refundsCount, equals(2));
      expect(shift.refundsAmount, equals('1500.00'));
    });
  });

  group('AgentDto', () {
    test('should serialize agent with all fields', () {
      final agent = AgentDto(
        id: 1,
        name: 'Test Customer',
        phone: '+77001234567',
        email: 'customer@test.com',
        inn: '123456789012',
        address: '123 Test Street',
        balance: '5000.00',
        bonusBalance: '500.00',
        discountPercent: '5.00',
        priceTypeId: 2,
        isActive: true,
        isSupplier: false,
        createdAt: DateTime(2024, 1, 1),
        modifiedAt: DateTime(2024, 3, 15),
      );

      final json = agent.toJson();

      expect(json['id'], equals(1));
      expect(json['name'], equals('Test Customer'));
      expect(json['phone'], equals('+77001234567'));
      expect(json['email'], equals('customer@test.com'));
      expect(json['inn'], equals('123456789012'));
      expect(json['address'], equals('123 Test Street'));
      expect(json['balance'], equals('5000.00'));
      expect(json['bonusBalance'], equals('500.00'));
      expect(json['discountPercent'], equals('5.00'));
      expect(json['priceTypeId'], equals(2));
      expect(json['isActive'], isTrue);
      expect(json['isSupplier'], isFalse);
    });

    test('should serialize supplier agent', () {
      const agent = AgentDto(
        id: 2,
        name: 'Test Supplier',
        phone: '+77009876543',
        isActive: true,
        isSupplier: true,
      );

      final json = agent.toJson();

      expect(json['name'], equals('Test Supplier'));
      expect(json['isSupplier'], isTrue);
    });

    test('should deserialize agent from json', () {
      final json = {
        'id': 1,
        'name': 'Test Customer',
        'phone': '+77001234567',
        'email': 'customer@test.com',
        'balance': '5000.00',
        'bonusBalance': '500.00',
        'discountPercent': '5.00',
        'isActive': true,
        'isSupplier': false,
      };

      final agent = AgentDto.fromJson(json);

      expect(agent.id, equals(1));
      expect(agent.name, equals('Test Customer'));
      expect(agent.phone, equals('+77001234567'));
      expect(agent.email, equals('customer@test.com'));
      expect(agent.balance, equals('5000.00'));
      expect(agent.bonusBalance, equals('500.00'));
      expect(agent.isActive, isTrue);
      expect(agent.isSupplier, isFalse);
    });

    test('should convert agent to database map', () {
      final agent = AgentDto(
        id: 1,
        name: 'Test Customer',
        phone: '+77001234567',
        email: 'customer@test.com',
        balance: '5000.00',
        bonusBalance: '500.00',
        discountPercent: '5.00',
        priceTypeId: 2,
        isActive: true,
        isSupplier: false,
        createdAt: DateTime(2024, 1, 1),
        modifiedAt: DateTime(2024, 3, 15),
      );

      final dbMap = agent.toDbMap();

      expect(dbMap['id'], equals(1));
      expect(dbMap['name'], equals('Test Customer'));
      expect(dbMap['phone'], equals('+77001234567'));
      expect(dbMap['email'], equals('customer@test.com'));
      expect(dbMap['balance'], equals('5000.00'));
      expect(dbMap['bonusBalance'], equals('500.00'));
      expect(dbMap['discountPercent'], equals('5.00'));
      expect(dbMap['priceTypeId'], equals(2));
      expect(dbMap['isActive'], equals(1));
      expect(dbMap['isSupplier'], equals(0));
    });

    test('should convert database map to agent', () {
      final dbMap = {
        'id': 1,
        'name': 'Test Customer',
        'phone': '+77001234567',
        'email': 'customer@test.com',
        'balance': '5000.00',
        'bonusBalance': '500.00',
        'discountPercent': '5.00',
        'priceTypeId': 2,
        'isActive': 1,
        'isSupplier': 0,
        'createdAt': '2024-01-01T00:00:00.000',
        'modifiedAt': '2024-03-15T00:00:00.000',
      };

      final agent = AgentDtoMapper.fromDbMap(dbMap);

      expect(agent.id, equals(1));
      expect(agent.name, equals('Test Customer'));
      expect(agent.phone, equals('+77001234567'));
      expect(agent.email, equals('customer@test.com'));
      expect(agent.balance, equals('5000.00'));
      expect(agent.bonusBalance, equals('500.00'));
      expect(agent.discountPercent, equals('5.00'));
      expect(agent.priceTypeId, equals(2));
      expect(agent.isActive, isTrue);
      expect(agent.isSupplier, isFalse);
    });
  });

  group('UserDto', () {
    test('should serialize user', () {
      final user = UserDto(
        id: 1,
        name: 'Test Cashier',
        login: 'cashier1',
        phone: '+77001234567',
        role: 'CASHIER',
        isActive: true,
        modifiedAt: DateTime(2024, 3, 15),
      );

      final json = user.toJson();

      expect(json['id'], equals(1));
      expect(json['name'], equals('Test Cashier'));
      expect(json['login'], equals('cashier1'));
      expect(json['phone'], equals('+77001234567'));
      expect(json['role'], equals('CASHIER'));
      expect(json['isActive'], isTrue);
    });

    test('should deserialize user from json', () {
      final json = {
        'id': 1,
        'name': 'Test Cashier',
        'login': 'cashier1',
        'phone': '+77001234567',
        'role': 'CASHIER',
        'isActive': true,
        'modifiedAt': '2024-03-15T00:00:00.000',
      };

      final user = UserDto.fromJson(json);

      expect(user.id, equals(1));
      expect(user.name, equals('Test Cashier'));
      expect(user.login, equals('cashier1'));
      expect(user.phone, equals('+77001234567'));
      expect(user.role, equals('CASHIER'));
      expect(user.isActive, isTrue);
    });

    test('should handle user with permissions', () {
      final json = {
        'id': 1,
        'name': 'Admin',
        'role': 'ADMIN',
        'permissions': {
          'canSell': true,
          'canRefund': true,
          'canOpenShift': true,
          'canCloseShift': true,
          'canDiscount': true,
          'canEditPrice': true,
          'canCreateProduct': true,
          'canCreateAgent': true,
          'canViewReports': true,
          'canSupply': true,
          'canInvest': true,
          'canExpense': true,
          'maxDiscountPercent': '100.00',
        },
      };

      final user = UserDto.fromJson(json);

      expect(user.permissions, isNotNull);
      expect(user.permissions!.canSell, isTrue);
      expect(user.permissions!.canEditPrice, isTrue);
      expect(user.permissions!.maxDiscountPercent, equals('100.00'));
    });

    test('should convert user to database map', () {
      final user = UserDto(
        id: 1,
        name: 'Test Cashier',
        login: 'cashier1',
        phone: '+77001234567',
        role: 'CASHIER',
        isActive: true,
        modifiedAt: DateTime(2024, 3, 15),
      );

      final dbMap = user.toDbMap();

      expect(dbMap['id'], equals(1));
      expect(dbMap['name'], equals('Test Cashier'));
      expect(dbMap['login'], equals('cashier1'));
      expect(dbMap['phone'], equals('+77001234567'));
      expect(dbMap['role'], equals('CASHIER'));
      expect(dbMap['isActive'], equals(1));
    });

    test('should convert database map to user', () {
      final dbMap = {
        'id': 1,
        'name': 'Test Cashier',
        'login': 'cashier1',
        'phone': '+77001234567',
        'role': 'CASHIER',
        'isActive': 1,
        'modifiedAt': '2024-03-15T00:00:00.000',
      };

      final user = UserDtoMapper.fromDbMap(dbMap);

      expect(user.id, equals(1));
      expect(user.name, equals('Test Cashier'));
      expect(user.login, equals('cashier1'));
      expect(user.phone, equals('+77001234567'));
      expect(user.role, equals('CASHIER'));
      expect(user.isActive, isTrue);
    });
  });

  group('PosConfigDto', () {
    test('should serialize POS config', () {
      final config = PosConfigDto(
        posId: 1,
        posName: 'Cash Register 1',
        storeId: 10,
        storeName: 'Main Store',
        priceTypeId: 1,
        defaultUserId: 5,
        fiscalEnabled: true,
        fiscalProvider: 'WEBKASSA',
        modifiedAt: DateTime(2024, 3, 15),
      );

      final json = config.toJson();

      expect(json['posId'], equals(1));
      expect(json['posName'], equals('Cash Register 1'));
      expect(json['storeId'], equals(10));
      expect(json['storeName'], equals('Main Store'));
      expect(json['priceTypeId'], equals(1));
      expect(json['defaultUserId'], equals(5));
      expect(json['fiscalEnabled'], isTrue);
      expect(json['fiscalProvider'], equals('WEBKASSA'));
    });

    test('should deserialize POS config from json', () {
      final json = {
        'posId': 1,
        'posName': 'Cash Register 1',
        'storeId': 10,
        'storeName': 'Main Store',
        'fiscalEnabled': false,
      };

      final config = PosConfigDto.fromJson(json);

      expect(config.posId, equals(1));
      expect(config.posName, equals('Cash Register 1'));
      expect(config.storeId, equals(10));
      expect(config.storeName, equals('Main Store'));
      expect(config.fiscalEnabled, isFalse);
    });

    test('should convert POS config to database map', () {
      final config = PosConfigDto(
        posId: 1,
        posName: 'Cash Register 1',
        storeId: 10,
        storeName: 'Main Store',
        priceTypeId: 1,
        fiscalEnabled: true,
        fiscalProvider: 'WEBKASSA',
        modifiedAt: DateTime(2024, 3, 15),
      );

      final dbMap = config.toDbMap();

      expect(dbMap['posId'], equals(1));
      expect(dbMap['posName'], equals('Cash Register 1'));
      expect(dbMap['storeId'], equals(10));
      expect(dbMap['storeName'], equals('Main Store'));
      expect(dbMap['priceTypeId'], equals(1));
      expect(dbMap['fiscalEnabled'], equals(1));
      expect(dbMap['fiscalProvider'], equals('WEBKASSA'));
    });
  });

  group('FiscalReceiptDto', () {
    test('should serialize fiscal receipt', () {
      final receipt = FiscalReceiptDto(
        fiscalNo: 'WK-2024-001',
        fiscalSign: 'ABC123DEF456',
        ticketUrl: 'https://ofd.kz/check/12345',
        operationType: 'SALE',
        createdAt: DateTime(2024, 3, 15),
      );

      final json = receipt.toJson();

      expect(json['fiscalNo'], equals('WK-2024-001'));
      expect(json['fiscalSign'], equals('ABC123DEF456'));
      expect(json['ticketUrl'], equals('https://ofd.kz/check/12345'));
      expect(json['operationType'], equals('SALE'));
    });

    test('should deserialize fiscal receipt from json', () {
      final json = {
        'fiscalNo': 'WK-2024-001',
        'fiscalSign': 'ABC123DEF456',
        'ticketUrl': 'https://ofd.kz/check/12345',
        'operationType': 'SALE',
        'createdAt': '2024-03-15T10:30:00.000',
      };

      final receipt = FiscalReceiptDto.fromJson(json);

      expect(receipt.fiscalNo, equals('WK-2024-001'));
      expect(receipt.fiscalSign, equals('ABC123DEF456'));
      expect(receipt.ticketUrl, equals('https://ofd.kz/check/12345'));
      expect(receipt.operationType, equals('SALE'));
    });

    test('should convert fiscal receipt to database map', () {
      final receipt = FiscalReceiptDto(
        fiscalNo: 'WK-2024-001',
        fiscalSign: 'ABC123DEF456',
        ticketUrl: 'https://ofd.kz/check/12345',
        operationType: 'SALE',
        createdAt: DateTime(2024, 3, 15),
      );

      final dbMap = receipt.toDbMap();

      expect(dbMap['fiscalNo'], equals('WK-2024-001'));
      expect(dbMap['fiscalSign'], equals('ABC123DEF456'));
      expect(dbMap['ticketUrl'], equals('https://ofd.kz/check/12345'));
      expect(dbMap['operationType'], equals('SALE'));
    });
  });

  group('SyncStatusDto', () {
    test('should serialize sync status', () {
      final status = SyncStatusDto(
        lastSyncAt: DateTime(2024, 3, 15, 10, 30),
        pendingUploads: 5,
        isInProgress: true,
        currentStep: 'Uploading sales',
        progress: 0.75,
      );

      final json = status.toJson();

      expect(json['lastSyncAt'], isNotNull);
      expect(json['pendingUploads'], equals(5));
      expect(json['isInProgress'], isTrue);
      expect(json['currentStep'], equals('Uploading sales'));
      expect(json['progress'], equals(0.75));
    });

    test('should deserialize sync status from json', () {
      final json = {
        'lastSyncAt': '2024-03-15T10:30:00.000',
        'pendingUploads': 10,
        'isInProgress': false,
        'currentStep': 'Complete',
        'progress': 1.0,
      };

      final status = SyncStatusDto.fromJson(json);

      expect(status.lastSyncAt, isNotNull);
      expect(status.pendingUploads, equals(10));
      expect(status.isInProgress, isFalse);
      expect(status.currentStep, equals('Complete'));
      expect(status.progress, equals(1.0));
    });

    test('should handle default values', () {
      final json = <String, dynamic>{};

      final status = SyncStatusDto.fromJson(json);

      expect(status.lastSyncAt, isNull);
      expect(status.pendingUploads, equals(0));
      expect(status.isInProgress, isFalse);
      expect(status.currentStep, isNull);
      expect(status.progress, isNull);
    });
  });
}
