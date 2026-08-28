import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:telepos/domain/usecases/refund/refund_use_case.dart';

class MockRefundUseCase extends Mock implements RefundUseCase {}

class FakeRefundProductEntry extends Fake implements RefundProductEntry {}

void main() {
  setUpAll(() {
    registerFallbackValue(Decimal.zero);
    registerFallbackValue(FakeRefundProductEntry());
    registerFallbackValue(<RefundProductEntry>[]);
  });

  group('RefundUseCase', () {
    late MockRefundUseCase mockRefundUseCase;

    setUp(() {
      mockRefundUseCase = MockRefundUseCase();
    });

    group('perform', () {
      test('should complete refund successfully with receipt', () async {
        final products = [
          RefundProductEntry(
            ucode: 100,
            quantity: Decimal.one,
            price: Decimal.parse('500.00'),
            inSalePrice: Decimal.parse('500.00'),
            inSaleQuantity: Decimal.one,
          ),
        ];
        final expectedResult = RefundResult(
          refundLocalId: 1,
          amount: Decimal.parse('500.00'),
          productCount: 1,
          paymentCount: 1,
        );

        when(
          () => mockRefundUseCase.perform(
            refundLocalId: any(named: 'refundLocalId'),
            amount: any(named: 'amount'),
            userId: any(named: 'userId'),
            products: any(named: 'products'),
            cashbackAmount: any(named: 'cashbackAmount'),
            saleReceiptNo: any(named: 'saleReceiptNo'),
            salePosId: any(named: 'salePosId'),
            customerLocalId: any(named: 'customerLocalId'),
            customerServerId: any(named: 'customerServerId'),
          ),
        ).thenAnswer((_) async => expectedResult);

        final result = await mockRefundUseCase.perform(
          refundLocalId: 1,
          amount: Decimal.parse('500.00'),
          userId: 1,
          products: products,
          saleReceiptNo: 10,
          salePosId: 100,
        );

        expect(result.refundLocalId, 1);
        expect(result.amount, Decimal.parse('500.00'));
        expect(result.productCount, 1);
        expect(result.paymentCount, 1);
      });

      test('should complete refund without receipt', () async {
        final products = [
          RefundProductEntry(
            ucode: 100,
            quantity: Decimal.one,
            price: Decimal.parse('500.00'),
          ),
        ];
        final expectedResult = RefundResult(
          refundLocalId: 2,
          amount: Decimal.parse('500.00'),
          productCount: 1,
          paymentCount: 1,
        );

        when(
          () => mockRefundUseCase.perform(
            refundLocalId: any(named: 'refundLocalId'),
            amount: any(named: 'amount'),
            userId: any(named: 'userId'),
            products: any(named: 'products'),
          ),
        ).thenAnswer((_) async => expectedResult);

        final result = await mockRefundUseCase.perform(
          refundLocalId: 2,
          amount: Decimal.parse('500.00'),
          userId: 1,
          products: products,
        );

        expect(result.refundLocalId, 2);
        expect(result.productCount, 1);
      });

      test('should complete refund with cashback', () async {
        final products = [
          RefundProductEntry(
            ucode: 100,
            quantity: Decimal.one,
            price: Decimal.parse('500.00'),
            inSalePrice: Decimal.parse('500.00'),
            inSaleQuantity: Decimal.one,
          ),
        ];
        final expectedResult = RefundResult(
          refundLocalId: 3,
          amount: Decimal.parse('500.00'),
          productCount: 1,
          paymentCount: 2,
        );

        when(
          () => mockRefundUseCase.perform(
            refundLocalId: any(named: 'refundLocalId'),
            amount: any(named: 'amount'),
            cashbackAmount: any(named: 'cashbackAmount'),
            userId: any(named: 'userId'),
            products: any(named: 'products'),
            saleReceiptNo: any(named: 'saleReceiptNo'),
            salePosId: any(named: 'salePosId'),
          ),
        ).thenAnswer((_) async => expectedResult);

        final result = await mockRefundUseCase.perform(
          refundLocalId: 3,
          amount: Decimal.parse('500.00'),
          cashbackAmount: Decimal.parse('50.00'),
          userId: 1,
          products: products,
          saleReceiptNo: 10,
          salePosId: 100,
        );

        expect(result.paymentCount, 2);
      });

      test('should complete refund with customer information', () async {
        final products = [
          RefundProductEntry(
            ucode: 100,
            quantity: Decimal.one,
            price: Decimal.parse('500.00'),
          ),
        ];
        final expectedResult = RefundResult(
          refundLocalId: 4,
          amount: Decimal.parse('500.00'),
          productCount: 1,
          paymentCount: 1,
        );

        when(
          () => mockRefundUseCase.perform(
            refundLocalId: any(named: 'refundLocalId'),
            amount: any(named: 'amount'),
            userId: any(named: 'userId'),
            products: any(named: 'products'),
            customerLocalId: any(named: 'customerLocalId'),
            customerServerId: any(named: 'customerServerId'),
          ),
        ).thenAnswer((_) async => expectedResult);

        final result = await mockRefundUseCase.perform(
          refundLocalId: 4,
          amount: Decimal.parse('500.00'),
          userId: 1,
          products: products,
          customerLocalId: 10,
          customerServerId: 200,
        );

        expect(result.refundLocalId, 4);
      });

      test('should handle multiple products in refund', () async {
        final products = [
          RefundProductEntry(
            ucode: 100,
            quantity: Decimal.fromInt(2),
            price: Decimal.parse('500.00'),
            inSalePrice: Decimal.parse('500.00'),
            inSaleQuantity: Decimal.fromInt(5),
          ),
          RefundProductEntry(
            ucode: 200,
            quantity: Decimal.one,
            price: Decimal.parse('300.00'),
            inSalePrice: Decimal.parse('300.00'),
            inSaleQuantity: Decimal.fromInt(3),
          ),
        ];
        final expectedResult = RefundResult(
          refundLocalId: 5,
          amount: Decimal.parse('1300.00'),
          productCount: 2,
          paymentCount: 1,
        );

        when(
          () => mockRefundUseCase.perform(
            refundLocalId: any(named: 'refundLocalId'),
            amount: any(named: 'amount'),
            userId: any(named: 'userId'),
            products: any(named: 'products'),
            saleReceiptNo: any(named: 'saleReceiptNo'),
            salePosId: any(named: 'salePosId'),
          ),
        ).thenAnswer((_) async => expectedResult);

        final result = await mockRefundUseCase.perform(
          refundLocalId: 5,
          amount: Decimal.parse('1300.00'),
          userId: 1,
          products: products,
          saleReceiptNo: 10,
          salePosId: 100,
        );

        expect(result.productCount, 2);
        expect(result.amount, Decimal.parse('1300.00'));
      });

      test(
        'should handle partial refund (quantity less than original)',
        () async {
          final products = [
            RefundProductEntry(
              ucode: 100,
              quantity: Decimal.fromInt(2),
              price: Decimal.parse('500.00'),
              inSalePrice: Decimal.parse('500.00'),
              inSaleQuantity: Decimal.fromInt(5),
            ),
          ];
          final expectedResult = RefundResult(
            refundLocalId: 6,
            amount: Decimal.parse('1000.00'),
            productCount: 1,
            paymentCount: 1,
          );

          when(
            () => mockRefundUseCase.perform(
              refundLocalId: any(named: 'refundLocalId'),
              amount: any(named: 'amount'),
              userId: any(named: 'userId'),
              products: any(named: 'products'),
              saleReceiptNo: any(named: 'saleReceiptNo'),
              salePosId: any(named: 'salePosId'),
            ),
          ).thenAnswer((_) async => expectedResult);

          final result = await mockRefundUseCase.perform(
            refundLocalId: 6,
            amount: Decimal.parse('1000.00'),
            userId: 1,
            products: products,
            saleReceiptNo: 10,
            salePosId: 100,
          );

          expect(result.amount, Decimal.parse('1000.00'));
        },
      );

      test('should throw InvalidRefundException on validation error', () async {
        when(
          () => mockRefundUseCase.perform(
            refundLocalId: any(named: 'refundLocalId'),
            amount: any(named: 'amount'),
            userId: any(named: 'userId'),
            products: any(named: 'products'),
          ),
        ).thenThrow(const InvalidRefundException('Invalid refund'));

        expect(
          () => mockRefundUseCase.perform(
            refundLocalId: 7,
            amount: Decimal.parse('500.00'),
            userId: 1,
            products: [],
          ),
          throwsA(isA<InvalidRefundException>()),
        );
      });

      test(
        'should throw InvalidRefundException when quantity exceeds original',
        () async {
          when(
            () => mockRefundUseCase.perform(
              refundLocalId: any(named: 'refundLocalId'),
              amount: any(named: 'amount'),
              userId: any(named: 'userId'),
              products: any(named: 'products'),
              saleReceiptNo: any(named: 'saleReceiptNo'),
              salePosId: any(named: 'salePosId'),
            ),
          ).thenThrow(
            const InvalidRefundException('Quantity exceeds original sale'),
          );

          final products = [
            RefundProductEntry(
              ucode: 100,
              quantity: Decimal.fromInt(10),
              price: Decimal.parse('500.00'),
              inSalePrice: Decimal.parse('500.00'),
              inSaleQuantity: Decimal.fromInt(5),
            ),
          ];

          expect(
            () => mockRefundUseCase.perform(
              refundLocalId: 8,
              amount: Decimal.parse('5000.00'),
              userId: 1,
              products: products,
              saleReceiptNo: 10,
              salePosId: 100,
            ),
            throwsA(isA<InvalidRefundException>()),
          );
        },
      );

      test('should handle refund with price difference (discount)', () async {
        final products = [
          RefundProductEntry(
            ucode: 100,
            quantity: Decimal.one,
            price: Decimal.parse('450.00'),
            inSalePrice: Decimal.parse('450.00'),
            inSaleQuantity: Decimal.one,
            inSalePriceBefore: Decimal.parse('500.00'),
          ),
        ];
        final expectedResult = RefundResult(
          refundLocalId: 9,
          amount: Decimal.parse('450.00'),
          productCount: 1,
          paymentCount: 1,
        );

        when(
          () => mockRefundUseCase.perform(
            refundLocalId: any(named: 'refundLocalId'),
            amount: any(named: 'amount'),
            userId: any(named: 'userId'),
            products: any(named: 'products'),
            saleReceiptNo: any(named: 'saleReceiptNo'),
            salePosId: any(named: 'salePosId'),
          ),
        ).thenAnswer((_) async => expectedResult);

        final result = await mockRefundUseCase.perform(
          refundLocalId: 9,
          amount: Decimal.parse('450.00'),
          userId: 1,
          products: products,
          saleReceiptNo: 10,
          salePosId: 100,
        );

        expect(result.amount, Decimal.parse('450.00'));
      });

      test('should handle weight products with decimal quantity', () async {
        final products = [
          RefundProductEntry(
            ucode: 100,
            quantity: Decimal.parse('1.500'),
            price: Decimal.parse('800.00'),
            inSalePrice: Decimal.parse('800.00'),
            inSaleQuantity: Decimal.parse('2.500'),
          ),
        ];
        final expectedResult = RefundResult(
          refundLocalId: 10,
          amount: Decimal.parse('1200.00'),
          productCount: 1,
          paymentCount: 1,
        );

        when(
          () => mockRefundUseCase.perform(
            refundLocalId: any(named: 'refundLocalId'),
            amount: any(named: 'amount'),
            userId: any(named: 'userId'),
            products: any(named: 'products'),
            saleReceiptNo: any(named: 'saleReceiptNo'),
            salePosId: any(named: 'salePosId'),
          ),
        ).thenAnswer((_) async => expectedResult);

        final result = await mockRefundUseCase.perform(
          refundLocalId: 10,
          amount: Decimal.parse('1200.00'),
          userId: 1,
          products: products,
          saleReceiptNo: 10,
          salePosId: 100,
        );

        expect(result.amount, Decimal.parse('1200.00'));
      });
    });
  });

  group('RefundProductEntry', () {
    test('should create entry with required fields', () {
      final entry = RefundProductEntry(
        ucode: 100,
        quantity: Decimal.one,
        price: Decimal.parse('500.00'),
      );

      expect(entry.ucode, 100);
      expect(entry.quantity, Decimal.one);
      expect(entry.price, Decimal.parse('500.00'));
      expect(entry.inSalePrice, isNull);
      expect(entry.inSaleQuantity, isNull);
      expect(entry.inSalePriceBefore, isNull);
    });

    test('should create entry with all optional fields', () {
      final entry = RefundProductEntry(
        ucode: 100,
        quantity: Decimal.one,
        price: Decimal.parse('450.00'),
        inSalePrice: Decimal.parse('450.00'),
        inSaleQuantity: Decimal.fromInt(2),
        inSalePriceBefore: Decimal.parse('500.00'),
      );

      expect(entry.inSalePrice, Decimal.parse('450.00'));
      expect(entry.inSaleQuantity, Decimal.fromInt(2));
      expect(entry.inSalePriceBefore, Decimal.parse('500.00'));
    });

    test('should handle decimal quantity for weight products', () {
      final entry = RefundProductEntry(
        ucode: 100,
        quantity: Decimal.parse('2.567'),
        price: Decimal.parse('800.00'),
      );

      expect(entry.quantity.toString(), '2.567');
    });
  });

  group('RefundResult', () {
    test('should create result with all fields', () {
      final result = RefundResult(
        refundLocalId: 1,
        amount: Decimal.parse('500.00'),
        productCount: 2,
        paymentCount: 3,
      );

      expect(result.refundLocalId, 1);
      expect(result.amount, Decimal.parse('500.00'));
      expect(result.productCount, 2);
      expect(result.paymentCount, 3);
    });

    test('should handle zero amount', () {
      final result = RefundResult(
        refundLocalId: 1,
        amount: Decimal.zero,
        productCount: 0,
        paymentCount: 0,
      );

      expect(result.amount, Decimal.zero);
    });
  });

  group('InvalidRefundException', () {
    test('should create exception with message', () {
      const exception = InvalidRefundException('Test error');

      expect(exception.message, 'Test error');
      expect(exception.toString(), 'InvalidRefundException: Test error');
    });

    test('should be throwable and catchable', () {
      expect(
        () => throw const InvalidRefundException('Test'),
        throwsA(isA<InvalidRefundException>()),
      );
    });

    test('should implement Exception interface', () {
      const exception = InvalidRefundException('Test');

      expect(exception, isA<Exception>());
    });
  });
}
