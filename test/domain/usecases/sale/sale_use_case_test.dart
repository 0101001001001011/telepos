import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/sale/receipt_line.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';

class MockSaleUseCase extends Mock implements SaleUseCase {}

class FakePaymentEntry extends Fake implements PaymentEntry {}

class FakeCustomFieldEntry extends Fake implements CustomFieldEntry {}

class FakeWithdrawalEntry extends Fake implements WithdrawalEntry {}

void main() {
  setUpAll(() {
    registerFallbackValue(Decimal.zero);
    registerFallbackValue(FakePaymentEntry());
    registerFallbackValue(FakeCustomFieldEntry());
    registerFallbackValue(FakeWithdrawalEntry());
    registerFallbackValue(<PaymentEntry>[]);
    registerFallbackValue(<CustomFieldEntry>[]);
    registerFallbackValue(<ReceiptLine>[]);
  });

  group('SaleUseCase', () {
    late MockSaleUseCase mockSaleUseCase;

    setUp(() {
      mockSaleUseCase = MockSaleUseCase();
    });

    group('perform', () {
      test('should complete sale successfully with valid parameters', () async {
        final payments = [
          PaymentEntry(kindId: SystemPaymentKindIds.cash, payeeAccountId: 1, amount: Decimal.parse('1000.00')),
        ];

        when(
          () => mockSaleUseCase.perform(
            receiptNo: any(named: 'receiptNo'),
            posId: any(named: 'posId'),
            amount: any(named: 'amount'),
            lines: any(named: 'lines'),
            payments: any(named: 'payments'),
            change: any(named: 'change'),
            selectiveOfd: any(named: 'selectiveOfd'),
            customerBin: any(named: 'customerBin'),
            agentLocalId: any(named: 'agentLocalId'),
            agentServerId: any(named: 'agentServerId'),
            customFields: any(named: 'customFields'),
            withdrawal: any(named: 'withdrawal'),
          ),
        ).thenAnswer((_) async {});

        await expectLater(
          mockSaleUseCase.perform(
            receiptNo: 1,
            posId: 100,
            amount: Decimal.parse('500.00'),
            lines: const [],
            payments: payments,
            change: Decimal.parse('500.00'),
            selectiveOfd: false,
          ),
          completes,
        );

        verify(
          () => mockSaleUseCase.perform(
            receiptNo: 1,
            posId: 100,
            amount: Decimal.parse('500.00'),
            lines: const [],
            payments: payments,
            change: Decimal.parse('500.00'),
            selectiveOfd: false,
          ),
        ).called(1);
      });

      test('should complete sale with zero change', () async {
        final payments = [
          PaymentEntry(kindId: SystemPaymentKindIds.cash, payeeAccountId: 1, amount: Decimal.parse('500.00')),
        ];

        when(
          () => mockSaleUseCase.perform(
            receiptNo: any(named: 'receiptNo'),
            posId: any(named: 'posId'),
            amount: any(named: 'amount'),
            lines: any(named: 'lines'),
            payments: any(named: 'payments'),
            change: any(named: 'change'),
            selectiveOfd: any(named: 'selectiveOfd'),
          ),
        ).thenAnswer((_) async {});

        await expectLater(
          mockSaleUseCase.perform(
            receiptNo: 2,
            posId: 100,
            amount: Decimal.parse('500.00'),
            lines: const [],
            payments: payments,
            change: Decimal.zero,
            selectiveOfd: false,
          ),
          completes,
        );
      });

      test('should complete sale with agent information', () async {
        final payments = [
          PaymentEntry(kindId: SystemPaymentKindIds.cash, 
            payeeAccountId: 1,
            amount: Decimal.parse('1000.00'),
            customerLocalId: 5,
          ),
        ];

        when(
          () => mockSaleUseCase.perform(
            receiptNo: any(named: 'receiptNo'),
            posId: any(named: 'posId'),
            amount: any(named: 'amount'),
            lines: any(named: 'lines'),
            payments: any(named: 'payments'),
            change: any(named: 'change'),
            selectiveOfd: any(named: 'selectiveOfd'),
            agentLocalId: any(named: 'agentLocalId'),
            agentServerId: any(named: 'agentServerId'),
          ),
        ).thenAnswer((_) async {});

        await expectLater(
          mockSaleUseCase.perform(
            receiptNo: 3,
            posId: 100,
            amount: Decimal.parse('500.00'),
            lines: const [],
            payments: payments,
            change: Decimal.parse('500.00'),
            selectiveOfd: true,
            agentLocalId: 10,
            agentServerId: 200,
          ),
          completes,
        );
      });

      test('should complete sale with custom fields', () async {
        final payments = [
          PaymentEntry(kindId: SystemPaymentKindIds.cash, payeeAccountId: 1, amount: Decimal.parse('500.00')),
        ];
        final customFields = [
          const CustomFieldEntry(customFieldId: 1, customFieldItemId: 10),
          const CustomFieldEntry(customFieldId: 2, customFieldItemId: 20),
        ];

        when(
          () => mockSaleUseCase.perform(
            receiptNo: any(named: 'receiptNo'),
            posId: any(named: 'posId'),
            amount: any(named: 'amount'),
            lines: any(named: 'lines'),
            payments: any(named: 'payments'),
            change: any(named: 'change'),
            selectiveOfd: any(named: 'selectiveOfd'),
            customFields: any(named: 'customFields'),
          ),
        ).thenAnswer((_) async {});

        await expectLater(
          mockSaleUseCase.perform(
            receiptNo: 4,
            posId: 100,
            amount: Decimal.parse('500.00'),
            lines: const [],
            payments: payments,
            change: Decimal.zero,
            selectiveOfd: false,
            customFields: customFields,
          ),
          completes,
        );
      });

      test('should complete sale with withdrawal', () async {
        final payments = [
          PaymentEntry(kindId: SystemPaymentKindIds.cash, payeeAccountId: 1, amount: Decimal.parse('400.00')),
        ];
        final withdrawal = WithdrawalEntry(
          agentAccountId: 5,
          amount: Decimal.parse('100.00'),
        );

        when(
          () => mockSaleUseCase.perform(
            receiptNo: any(named: 'receiptNo'),
            posId: any(named: 'posId'),
            amount: any(named: 'amount'),
            lines: any(named: 'lines'),
            payments: any(named: 'payments'),
            change: any(named: 'change'),
            selectiveOfd: any(named: 'selectiveOfd'),
            withdrawal: any(named: 'withdrawal'),
          ),
        ).thenAnswer((_) async {});

        await expectLater(
          mockSaleUseCase.perform(
            receiptNo: 5,
            posId: 100,
            amount: Decimal.parse('500.00'),
            lines: const [],
            payments: payments,
            change: Decimal.zero,
            selectiveOfd: false,
            withdrawal: withdrawal,
          ),
          completes,
        );
      });

      test('should complete sale with customer BIN', () async {
        final payments = [
          PaymentEntry(kindId: SystemPaymentKindIds.cash, payeeAccountId: 1, amount: Decimal.parse('500.00')),
        ];

        when(
          () => mockSaleUseCase.perform(
            receiptNo: any(named: 'receiptNo'),
            posId: any(named: 'posId'),
            amount: any(named: 'amount'),
            lines: any(named: 'lines'),
            payments: any(named: 'payments'),
            change: any(named: 'change'),
            selectiveOfd: any(named: 'selectiveOfd'),
            customerBin: any(named: 'customerBin'),
          ),
        ).thenAnswer((_) async {});

        await expectLater(
          mockSaleUseCase.perform(
            receiptNo: 6,
            posId: 100,
            amount: Decimal.parse('500.00'),
            lines: const [],
            payments: payments,
            change: Decimal.zero,
            selectiveOfd: true,
            customerBin: '123456789012',
          ),
          completes,
        );
      });

      test('should handle multiple payments', () async {
        final payments = [
          PaymentEntry(kindId: SystemPaymentKindIds.cash, payeeAccountId: 1, amount: Decimal.parse('300.00')),
          PaymentEntry(kindId: SystemPaymentKindIds.cash, payeeAccountId: 2, amount: Decimal.parse('200.00')),
        ];

        when(
          () => mockSaleUseCase.perform(
            receiptNo: any(named: 'receiptNo'),
            posId: any(named: 'posId'),
            amount: any(named: 'amount'),
            lines: any(named: 'lines'),
            payments: any(named: 'payments'),
            change: any(named: 'change'),
            selectiveOfd: any(named: 'selectiveOfd'),
          ),
        ).thenAnswer((_) async {});

        await expectLater(
          mockSaleUseCase.perform(
            receiptNo: 7,
            posId: 100,
            amount: Decimal.parse('500.00'),
            lines: const [],
            payments: payments,
            change: Decimal.zero,
            selectiveOfd: false,
          ),
          completes,
        );
      });

      test('should throw exception on database error', () async {
        when(
          () => mockSaleUseCase.perform(
            receiptNo: any(named: 'receiptNo'),
            posId: any(named: 'posId'),
            amount: any(named: 'amount'),
            lines: any(named: 'lines'),
            payments: any(named: 'payments'),
            change: any(named: 'change'),
            selectiveOfd: any(named: 'selectiveOfd'),
          ),
        ).thenThrow(Exception('Database error'));

        expect(
          () => mockSaleUseCase.perform(
            receiptNo: 8,
            posId: 100,
            amount: Decimal.parse('500.00'),
            lines: const [],
            payments: [],
            change: Decimal.zero,
            selectiveOfd: false,
          ),
          throwsException,
        );
      });

      test('should handle large amounts (near limit)', () async {
        final largeAmount = Decimal.parse('999999.999');
        final payments = [
          PaymentEntry(kindId: SystemPaymentKindIds.cash, payeeAccountId: 1, amount: Decimal.parse('1000000.00')),
        ];

        when(
          () => mockSaleUseCase.perform(
            receiptNo: any(named: 'receiptNo'),
            posId: any(named: 'posId'),
            amount: any(named: 'amount'),
            lines: any(named: 'lines'),
            payments: any(named: 'payments'),
            change: any(named: 'change'),
            selectiveOfd: any(named: 'selectiveOfd'),
          ),
        ).thenAnswer((_) async {});

        await expectLater(
          mockSaleUseCase.perform(
            receiptNo: 9,
            posId: 100,
            amount: largeAmount,
            lines: const [],
            payments: payments,
            change: Decimal.parse('0.001'),
            selectiveOfd: true,
          ),
          completes,
        );
      });

      test('should handle sale with OFD enabled', () async {
        final payments = [
          PaymentEntry(kindId: SystemPaymentKindIds.cash, payeeAccountId: 1, amount: Decimal.parse('500.00')),
        ];

        when(
          () => mockSaleUseCase.perform(
            receiptNo: any(named: 'receiptNo'),
            posId: any(named: 'posId'),
            amount: any(named: 'amount'),
            lines: any(named: 'lines'),
            payments: any(named: 'payments'),
            change: any(named: 'change'),
            selectiveOfd: true,
          ),
        ).thenAnswer((_) async {});

        await expectLater(
          mockSaleUseCase.perform(
            receiptNo: 10,
            posId: 100,
            amount: Decimal.parse('500.00'),
            lines: const [],
            payments: payments,
            change: Decimal.zero,
            selectiveOfd: true,
          ),
          completes,
        );
      });
    });
  });

  group('PaymentEntry', () {
    test('should create payment entry with required fields', () {
      final entry = PaymentEntry(kindId: SystemPaymentKindIds.cash, 
        payeeAccountId: 1,
        amount: Decimal.parse('100.00'),
      );

      expect(entry.payeeAccountId, 1);
      expect(entry.amount, Decimal.parse('100.00'));
      expect(entry.customerLocalId, isNull);
    });

    test('should create payment entry with customer local id', () {
      final entry = PaymentEntry(kindId: SystemPaymentKindIds.cash, 
        payeeAccountId: 1,
        amount: Decimal.parse('100.00'),
        customerLocalId: 5,
      );

      expect(entry.customerLocalId, 5);
    });

    test('should handle zero amount', () {
      final entry = PaymentEntry(kindId: SystemPaymentKindIds.cash, payeeAccountId: 1, amount: Decimal.zero);

      expect(entry.amount, Decimal.zero);
    });

    test('should handle decimal precision (P18,S3)', () {
      final entry = PaymentEntry(kindId: SystemPaymentKindIds.cash, 
        payeeAccountId: 1,
        amount: Decimal.parse('123456.789'),
      );

      expect(entry.amount.toString(), '123456.789');
    });
  });

  group('CustomFieldEntry', () {
    test('should create custom field entry', () {
      const entry = CustomFieldEntry(customFieldId: 1, customFieldItemId: 10);

      expect(entry.customFieldId, 1);
      expect(entry.customFieldItemId, 10);
    });
  });

  group('WithdrawalEntry', () {
    test('should create withdrawal entry', () {
      final entry = WithdrawalEntry(
        agentAccountId: 5,
        amount: Decimal.parse('50.00'),
      );

      expect(entry.agentAccountId, 5);
      expect(entry.amount, Decimal.parse('50.00'));
    });

    test('should handle zero withdrawal amount', () {
      final entry = WithdrawalEntry(agentAccountId: 5, amount: Decimal.zero);

      expect(entry.amount, Decimal.zero);
    });
  });
}
