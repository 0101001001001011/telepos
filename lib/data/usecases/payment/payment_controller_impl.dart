import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';
import 'package:telepos/domain/usecases/payment/payment_controller.dart';

class PaymentControllerImpl implements PaymentController {
  PaymentControllerImpl({required Talker logger}) : _logger = logger;

  final Talker _logger;

  @override
  PaymentState createSession({
    required Decimal saleAmount,
    bool isDebtAllowed = false,
    bool hasBonusPayment = false,
  }) {
    _logger.info(
      'PaymentController: createSession amount=$saleAmount, '
      'debtAllowed=$isDebtAllowed, bonus=$hasBonusPayment',
    );

    return PaymentState(
      saleAmount: saleAmount,
      isDebtAllowed: isDebtAllowed,
      hasBonusPayment: hasBonusPayment,
    );
  }

  @override
  PaymentResult addPayment({
    required PaymentState state,
    required int accountId,
    required Decimal amount,
    required bool isCashless,
  }) {
    if (amount <= Decimal.zero) {
      _logger.warning('PaymentController: invalid amount $amount');
      return PaymentResult.failure(PaymentError.invalidAmount);
    }

    if (isCashless) {
      final newCashlessTotal = state.cashlessReceived + amount;
      if (newCashlessTotal > state.saleAmount) {
        _logger.warning(
          'PaymentController: cashless overpayment '
          'newTotal=$newCashlessTotal > saleAmount=${state.saleAmount}',
        );
        return PaymentResult.failure(PaymentError.cashlessOverpayment);
      }
    }

    final newPayment = PaymentEntry(
      accountId: accountId,
      amount: amount,
      isCashless: isCashless,
      time: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    final newState = state.copyWith(payments: [...state.payments, newPayment]);

    _logger.info(
      'PaymentController: addPayment account=$accountId, amount=$amount, '
      'cashless=$isCashless, totalReceived=${newState.received}',
    );

    return PaymentResult.success(newState);
  }

  @override
  PaymentState removePayment({
    required PaymentState state,
    required int index,
  }) {
    if (index < 0 || index >= state.payments.length) {
      _logger.warning('PaymentController: invalid payment index $index');
      return state;
    }

    final newPayments = List<PaymentEntry>.from(state.payments)
      ..removeAt(index);

    _logger.info(
      'PaymentController: removePayment index=$index, '
      'remaining=${state.payments.length - 1}',
    );

    return state.copyWith(payments: newPayments);
  }

  @override
  PaymentState clearPayments(PaymentState state) {
    _logger.info('PaymentController: clearPayments');
    return state.copyWith(payments: const []);
  }

  @override
  PaymentValidation validate(PaymentState state) {
    if (state.payments.isEmpty) {
      _logger.warning('PaymentController: no payments');
      return const PaymentValidation(
        isValid: false,
        error: PaymentValidationError.noPayments,
      );
    }

    final isDebt = state.remaining > Decimal.zero;
    if (isDebt && !state.isDebtAllowed) {
      _logger.warning(
        'PaymentController: insufficient funds, remaining=${state.remaining}',
      );
      return const PaymentValidation(
        isValid: false,
        error: PaymentValidationError.insufficientFunds,
      );
    }

    if (isDebt && state.hasBonusPayment) {
      _logger.warning('PaymentController: bonus with debt not allowed');
      return const PaymentValidation(
        isValid: false,
        error: PaymentValidationError.bonusWithDebt,
      );
    }

    _logger.info('PaymentController: validate OK, isDebt=$isDebt');

    return PaymentValidation(isValid: true, isDebt: isDebt);
  }

  @override
  Decimal calculateChange(PaymentState state, Decimal cashAmount) {
    final cashNeeded = state.saleAmount - state.cashlessReceived;

    if (cashAmount > cashNeeded && cashNeeded >= Decimal.zero) {
      final change = cashAmount - cashNeeded;
      _logger.info('PaymentController: calculateChange = $change');
      return change;
    }

    return Decimal.zero;
  }

  @override
  PaymentType getPaymentType(PaymentState state) {
    if (state.payments.isEmpty) {
      return PaymentType.none;
    }

    final hasCash = state.cashReceived > Decimal.zero;
    final hasCashless = state.cashlessReceived > Decimal.zero;

    if (hasCash && hasCashless) {
      return PaymentType.mixed;
    } else if (hasCashless) {
      return PaymentType.cashless;
    } else {
      return PaymentType.cash;
    }
  }
}
