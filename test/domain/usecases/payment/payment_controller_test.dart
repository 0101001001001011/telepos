import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:telepos/domain/usecases/payment/payment_controller.dart';

class MockPaymentController extends Mock implements PaymentController {}

class FakePaymentState extends Fake implements PaymentState {}

void main() {
  setUpAll(() {
    registerFallbackValue(Decimal.zero);
    registerFallbackValue(FakePaymentState());
  });

  group('PaymentController', () {
    late MockPaymentController mockController;

    setUp(() {
      mockController = MockPaymentController();
    });

    group('createSession', () {
      test('should create session with sale amount', () {
        final expectedState = PaymentState(saleAmount: Decimal.parse('500.00'));

        when(
          () => mockController.createSession(
            saleAmount: any(named: 'saleAmount'),
            isDebtAllowed: any(named: 'isDebtAllowed'),
            hasBonusPayment: any(named: 'hasBonusPayment'),
          ),
        ).thenReturn(expectedState);

        final result = mockController.createSession(
          saleAmount: Decimal.parse('500.00'),
        );

        expect(result.saleAmount, Decimal.parse('500.00'));
        expect(result.isDebtAllowed, false);
        expect(result.hasBonusPayment, false);
        expect(result.payments, isEmpty);
      });

      test('should create session with debt allowed', () {
        final expectedState = PaymentState(
          saleAmount: Decimal.parse('500.00'),
          isDebtAllowed: true,
        );

        when(
          () => mockController.createSession(
            saleAmount: any(named: 'saleAmount'),
            isDebtAllowed: true,
            hasBonusPayment: any(named: 'hasBonusPayment'),
          ),
        ).thenReturn(expectedState);

        final result = mockController.createSession(
          saleAmount: Decimal.parse('500.00'),
          isDebtAllowed: true,
        );

        expect(result.isDebtAllowed, true);
      });

      test('should create session with bonus payment', () {
        final expectedState = PaymentState(
          saleAmount: Decimal.parse('500.00'),
          hasBonusPayment: true,
        );

        when(
          () => mockController.createSession(
            saleAmount: any(named: 'saleAmount'),
            isDebtAllowed: any(named: 'isDebtAllowed'),
            hasBonusPayment: true,
          ),
        ).thenReturn(expectedState);

        final result = mockController.createSession(
          saleAmount: Decimal.parse('500.00'),
          hasBonusPayment: true,
        );

        expect(result.hasBonusPayment, true);
      });
    });

    group('addPayment', () {
      test('should add cash payment successfully', () {
        final initialState = PaymentState(saleAmount: Decimal.parse('500.00'));
        final expectedState = PaymentState(
          saleAmount: Decimal.parse('500.00'),
          payments: [
            PaymentEntry(
              accountId: 1,
              amount: Decimal.parse('500.00'),
              isCashless: false,
            ),
          ],
        );

        when(
          () => mockController.addPayment(
            state: any(named: 'state'),
            accountId: any(named: 'accountId'),
            amount: any(named: 'amount'),
            isCashless: false,
          ),
        ).thenReturn(PaymentResult.success(expectedState));

        final result = mockController.addPayment(
          state: initialState,
          accountId: 1,
          amount: Decimal.parse('500.00'),
          isCashless: false,
        );

        expect(result.isSuccess, true);
        expect(result.state!.payments.length, 1);
        expect(result.state!.payments.first.isCashless, false);
      });

      test('should add cashless payment successfully', () {
        final initialState = PaymentState(saleAmount: Decimal.parse('500.00'));
        final expectedState = PaymentState(
          saleAmount: Decimal.parse('500.00'),
          payments: [
            PaymentEntry(
              accountId: 2,
              amount: Decimal.parse('500.00'),
              isCashless: true,
            ),
          ],
        );

        when(
          () => mockController.addPayment(
            state: any(named: 'state'),
            accountId: any(named: 'accountId'),
            amount: any(named: 'amount'),
            isCashless: true,
          ),
        ).thenReturn(PaymentResult.success(expectedState));

        final result = mockController.addPayment(
          state: initialState,
          accountId: 2,
          amount: Decimal.parse('500.00'),
          isCashless: true,
        );

        expect(result.isSuccess, true);
        expect(result.state!.payments.first.isCashless, true);
      });

      test('should fail with invalid amount', () {
        final initialState = PaymentState(saleAmount: Decimal.parse('500.00'));

        when(
          () => mockController.addPayment(
            state: any(named: 'state'),
            accountId: any(named: 'accountId'),
            amount: any(named: 'amount'),
            isCashless: any(named: 'isCashless'),
          ),
        ).thenReturn(PaymentResult.failure(PaymentError.invalidAmount));

        final result = mockController.addPayment(
          state: initialState,
          accountId: 1,
          amount: Decimal.zero,
          isCashless: false,
        );

        expect(result.isSuccess, false);
        expect(result.error, PaymentError.invalidAmount);
      });

      test('should fail with cashless overpayment', () {
        final initialState = PaymentState(saleAmount: Decimal.parse('500.00'));

        when(
          () => mockController.addPayment(
            state: any(named: 'state'),
            accountId: any(named: 'accountId'),
            amount: any(named: 'amount'),
            isCashless: true,
          ),
        ).thenReturn(PaymentResult.failure(PaymentError.cashlessOverpayment));

        final result = mockController.addPayment(
          state: initialState,
          accountId: 2,
          amount: Decimal.parse('600.00'),
          isCashless: true,
        );

        expect(result.isSuccess, false);
        expect(result.error, PaymentError.cashlessOverpayment);
      });

      test('should fail with bonus and debt combination', () {
        final initialState = PaymentState(
          saleAmount: Decimal.parse('500.00'),
          isDebtAllowed: true,
          hasBonusPayment: true,
        );

        when(
          () => mockController.addPayment(
            state: any(named: 'state'),
            accountId: any(named: 'accountId'),
            amount: any(named: 'amount'),
            isCashless: any(named: 'isCashless'),
          ),
        ).thenReturn(PaymentResult.failure(PaymentError.bonusWithDebt));

        final result = mockController.addPayment(
          state: initialState,
          accountId: 1,
          amount: Decimal.parse('300.00'),
          isCashless: false,
        );

        expect(result.isSuccess, false);
        expect(result.error, PaymentError.bonusWithDebt);
      });
    });

    group('removePayment', () {
      test('should remove payment by index', () {
        final initialState = PaymentState(
          saleAmount: Decimal.parse('500.00'),
          payments: [
            PaymentEntry(
              accountId: 1,
              amount: Decimal.parse('300.00'),
              isCashless: false,
            ),
            PaymentEntry(
              accountId: 2,
              amount: Decimal.parse('200.00'),
              isCashless: true,
            ),
          ],
        );
        final expectedState = PaymentState(
          saleAmount: Decimal.parse('500.00'),
          payments: [
            PaymentEntry(
              accountId: 2,
              amount: Decimal.parse('200.00'),
              isCashless: true,
            ),
          ],
        );

        when(
          () => mockController.removePayment(
            state: any(named: 'state'),
            index: 0,
          ),
        ).thenReturn(expectedState);

        final result = mockController.removePayment(
          state: initialState,
          index: 0,
        );

        expect(result.payments.length, 1);
        expect(result.payments.first.accountId, 2);
      });
    });

    group('clearPayments', () {
      test('should clear all payments', () {
        final initialState = PaymentState(
          saleAmount: Decimal.parse('500.00'),
          payments: [
            PaymentEntry(
              accountId: 1,
              amount: Decimal.parse('300.00'),
              isCashless: false,
            ),
            PaymentEntry(
              accountId: 2,
              amount: Decimal.parse('200.00'),
              isCashless: true,
            ),
          ],
        );
        final expectedState = PaymentState(saleAmount: Decimal.parse('500.00'));

        when(
          () => mockController.clearPayments(any()),
        ).thenReturn(expectedState);

        final result = mockController.clearPayments(initialState);

        expect(result.payments, isEmpty);
      });
    });

    group('validate', () {
      test('should validate successfully when fully paid', () {
        final state = PaymentState(
          saleAmount: Decimal.parse('500.00'),
          payments: [
            PaymentEntry(
              accountId: 1,
              amount: Decimal.parse('500.00'),
              isCashless: false,
            ),
          ],
        );

        when(
          () => mockController.validate(any()),
        ).thenReturn(const PaymentValidation(isValid: true));

        final result = mockController.validate(state);

        expect(result.isValid, true);
        expect(result.error, isNull);
        expect(result.isDebt, false);
      });

      test('should fail validation with no payments', () {
        final state = PaymentState(saleAmount: Decimal.parse('500.00'));

        when(() => mockController.validate(any())).thenReturn(
          const PaymentValidation(
            isValid: false,
            error: PaymentValidationError.noPayments,
          ),
        );

        final result = mockController.validate(state);

        expect(result.isValid, false);
        expect(result.error, PaymentValidationError.noPayments);
      });

      test('should fail validation with insufficient funds', () {
        final state = PaymentState(
          saleAmount: Decimal.parse('500.00'),
          payments: [
            PaymentEntry(
              accountId: 1,
              amount: Decimal.parse('300.00'),
              isCashless: false,
            ),
          ],
        );

        when(() => mockController.validate(any())).thenReturn(
          const PaymentValidation(
            isValid: false,
            error: PaymentValidationError.insufficientFunds,
          ),
        );

        final result = mockController.validate(state);

        expect(result.isValid, false);
        expect(result.error, PaymentValidationError.insufficientFunds);
      });

      test('should validate as debt when allowed', () {
        final state = PaymentState(
          saleAmount: Decimal.parse('500.00'),
          isDebtAllowed: true,
          payments: [
            PaymentEntry(
              accountId: 1,
              amount: Decimal.parse('300.00'),
              isCashless: false,
            ),
          ],
        );

        when(
          () => mockController.validate(any()),
        ).thenReturn(const PaymentValidation(isValid: true, isDebt: true));

        final result = mockController.validate(state);

        expect(result.isValid, true);
        expect(result.isDebt, true);
      });
    });

    group('calculateChange', () {
      test('should calculate change correctly', () {
        final state = PaymentState(
          saleAmount: Decimal.parse('500.00'),
          payments: [
            PaymentEntry(
              accountId: 1,
              amount: Decimal.parse('1000.00'),
              isCashless: false,
            ),
          ],
        );

        when(
          () => mockController.calculateChange(any(), any()),
        ).thenReturn(Decimal.parse('500.00'));

        final result = mockController.calculateChange(
          state,
          Decimal.parse('1000.00'),
        );

        expect(result, Decimal.parse('500.00'));
      });

      test('should return zero when no overpayment', () {
        final state = PaymentState(
          saleAmount: Decimal.parse('500.00'),
          payments: [
            PaymentEntry(
              accountId: 1,
              amount: Decimal.parse('500.00'),
              isCashless: false,
            ),
          ],
        );

        when(
          () => mockController.calculateChange(any(), any()),
        ).thenReturn(Decimal.zero);

        final result = mockController.calculateChange(
          state,
          Decimal.parse('500.00'),
        );

        expect(result, Decimal.zero);
      });
    });

    group('getPaymentType', () {
      test('should return cash type when only cash payments', () {
        final state = PaymentState(
          saleAmount: Decimal.parse('500.00'),
          payments: [
            PaymentEntry(
              accountId: 1,
              amount: Decimal.parse('500.00'),
              isCashless: false,
            ),
          ],
        );

        when(
          () => mockController.getPaymentType(any()),
        ).thenReturn(PaymentType.cash);

        final result = mockController.getPaymentType(state);

        expect(result, PaymentType.cash);
      });

      test('should return cashless type when only cashless payments', () {
        final state = PaymentState(
          saleAmount: Decimal.parse('500.00'),
          payments: [
            PaymentEntry(
              accountId: 2,
              amount: Decimal.parse('500.00'),
              isCashless: true,
            ),
          ],
        );

        when(
          () => mockController.getPaymentType(any()),
        ).thenReturn(PaymentType.cashless);

        final result = mockController.getPaymentType(state);

        expect(result, PaymentType.cashless);
      });

      test('should return mixed type when both cash and cashless payments', () {
        final state = PaymentState(
          saleAmount: Decimal.parse('500.00'),
          payments: [
            PaymentEntry(
              accountId: 1,
              amount: Decimal.parse('300.00'),
              isCashless: false,
            ),
            PaymentEntry(
              accountId: 2,
              amount: Decimal.parse('200.00'),
              isCashless: true,
            ),
          ],
        );

        when(
          () => mockController.getPaymentType(any()),
        ).thenReturn(PaymentType.mixed);

        final result = mockController.getPaymentType(state);

        expect(result, PaymentType.mixed);
      });

      test('should return none when no payments', () {
        final state = PaymentState(saleAmount: Decimal.parse('500.00'));

        when(
          () => mockController.getPaymentType(any()),
        ).thenReturn(PaymentType.none);

        final result = mockController.getPaymentType(state);

        expect(result, PaymentType.none);
      });
    });
  });

  group('PaymentState', () {
    test('should calculate received correctly', () {
      final state = PaymentState(
        saleAmount: Decimal.parse('500.00'),
        payments: [
          PaymentEntry(
            accountId: 1,
            amount: Decimal.parse('300.00'),
            isCashless: false,
          ),
          PaymentEntry(
            accountId: 2,
            amount: Decimal.parse('200.00'),
            isCashless: true,
          ),
        ],
      );

      expect(state.received, Decimal.parse('500.00'));
    });

    test('should calculate cashReceived correctly', () {
      final state = PaymentState(
        saleAmount: Decimal.parse('500.00'),
        payments: [
          PaymentEntry(
            accountId: 1,
            amount: Decimal.parse('300.00'),
            isCashless: false,
          ),
          PaymentEntry(
            accountId: 2,
            amount: Decimal.parse('200.00'),
            isCashless: true,
          ),
        ],
      );

      expect(state.cashReceived, Decimal.parse('300.00'));
    });

    test('should calculate cashlessReceived correctly', () {
      final state = PaymentState(
        saleAmount: Decimal.parse('500.00'),
        payments: [
          PaymentEntry(
            accountId: 1,
            amount: Decimal.parse('300.00'),
            isCashless: false,
          ),
          PaymentEntry(
            accountId: 2,
            amount: Decimal.parse('200.00'),
            isCashless: true,
          ),
        ],
      );

      expect(state.cashlessReceived, Decimal.parse('200.00'));
    });

    test('should calculate remaining correctly when underpaid', () {
      final state = PaymentState(
        saleAmount: Decimal.parse('500.00'),
        payments: [
          PaymentEntry(
            accountId: 1,
            amount: Decimal.parse('300.00'),
            isCashless: false,
          ),
        ],
      );

      expect(state.remaining, Decimal.parse('200.00'));
    });

    test('should return zero remaining when fully paid', () {
      final state = PaymentState(
        saleAmount: Decimal.parse('500.00'),
        payments: [
          PaymentEntry(
            accountId: 1,
            amount: Decimal.parse('500.00'),
            isCashless: false,
          ),
        ],
      );

      expect(state.remaining, Decimal.zero);
    });

    test('should return zero remaining when overpaid', () {
      final state = PaymentState(
        saleAmount: Decimal.parse('500.00'),
        payments: [
          PaymentEntry(
            accountId: 1,
            amount: Decimal.parse('1000.00'),
            isCashless: false,
          ),
        ],
      );

      expect(state.remaining, Decimal.zero);
    });

    test('should calculate debt when allowed and underpaid', () {
      final state = PaymentState(
        saleAmount: Decimal.parse('500.00'),
        isDebtAllowed: true,
        payments: [
          PaymentEntry(
            accountId: 1,
            amount: Decimal.parse('300.00'),
            isCashless: false,
          ),
        ],
      );

      expect(state.debt, Decimal.parse('200.00'));
    });

    test('should return zero debt when not allowed', () {
      final state = PaymentState(
        saleAmount: Decimal.parse('500.00'),
        isDebtAllowed: false,
        payments: [
          PaymentEntry(
            accountId: 1,
            amount: Decimal.parse('300.00'),
            isCashless: false,
          ),
        ],
      );

      expect(state.debt, Decimal.zero);
    });

    test('should detect overpayment', () {
      final state = PaymentState(
        saleAmount: Decimal.parse('500.00'),
        payments: [
          PaymentEntry(
            accountId: 1,
            amount: Decimal.parse('1000.00'),
            isCashless: false,
          ),
        ],
      );

      expect(state.hasOverpayment, true);
    });

    test('should calculate overpayment from cash only', () {
      final state = PaymentState(
        saleAmount: Decimal.parse('500.00'),
        payments: [
          PaymentEntry(
            accountId: 1,
            amount: Decimal.parse('800.00'),
            isCashless: false,
          ),
        ],
      );

      expect(state.overpayment, Decimal.parse('300.00'));
    });

    test('should use copyWith correctly', () {
      final original = PaymentState(saleAmount: Decimal.parse('500.00'));

      final modified = original.copyWith(
        saleAmount: Decimal.parse('600.00'),
        isDebtAllowed: true,
      );

      expect(modified.saleAmount, Decimal.parse('600.00'));
      expect(modified.isDebtAllowed, true);
      expect(modified.hasBonusPayment, false);
    });
  });

  group('PaymentEntry', () {
    test('should create entry with required fields', () {
      final entry = PaymentEntry(
        accountId: 1,
        amount: Decimal.parse('500.00'),
        isCashless: false,
      );

      expect(entry.accountId, 1);
      expect(entry.amount, Decimal.parse('500.00'));
      expect(entry.isCashless, false);
      expect(entry.time, isNull);
    });

    test('should create entry with timestamp', () {
      final entry = PaymentEntry(
        accountId: 1,
        amount: Decimal.parse('500.00'),
        isCashless: true,
        time: 1234567890,
      );

      expect(entry.time, 1234567890);
    });
  });

  group('PaymentResult', () {
    test('should create success result', () {
      final result = PaymentResult.success(
        PaymentState(saleAmount: Decimal.parse('500.00')),
      );

      expect(result.isSuccess, true);
      expect(result.state, isNotNull);
      expect(result.error, isNull);
    });

    test('should create failure result', () {
      final result = PaymentResult.failure(PaymentError.invalidAmount);

      expect(result.isSuccess, false);
      expect(result.state, isNull);
      expect(result.error, PaymentError.invalidAmount);
    });
  });

  group('PaymentValidation', () {
    test('should create valid validation', () {
      const validation = PaymentValidation(isValid: true);

      expect(validation.isValid, true);
      expect(validation.error, isNull);
      expect(validation.isDebt, false);
    });

    test('should create invalid validation with error', () {
      const validation = PaymentValidation(
        isValid: false,
        error: PaymentValidationError.noPayments,
      );

      expect(validation.isValid, false);
      expect(validation.error, PaymentValidationError.noPayments);
    });

    test('should create debt validation', () {
      const validation = PaymentValidation(isValid: true, isDebt: true);

      expect(validation.isDebt, true);
    });
  });
}
