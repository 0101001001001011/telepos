import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';

void main() {
  PaymentState cashReady() => PaymentState(
    totalAmount: Decimal.parse('1000'),
    paymentType: PaymentType.cash,
    cashReceived: Decimal.parse('1000'),
  );

  test('валидная наличная оплата готова к завершению', () {
    expect(cashReady().canComplete, isTrue);
  });

  test('isProcessing=true ОБНУЛЯЕТ canComplete (ловушка premature-lock)', () {
    final s = cashReady().copyWith(isProcessing: true);
    expect(
      s.canComplete,
      isFalse,
      reason:
          'именно поэтому _handleComplete НЕ должен ставить '
          'setProcessing(true) до processPayment',
    );
  });

  test('карта: готова к завершению, но isProcessing так же её блокирует', () {
    final card = PaymentState(
      totalAmount: Decimal.parse('500'),
      paymentType: PaymentType.card,
    );
    expect(card.canComplete, isTrue);
    expect(card.copyWith(isProcessing: true).canComplete, isFalse);
  });

  test('недобор наличных не даёт завершить (без участия isProcessing)', () {
    final s = PaymentState(
      totalAmount: Decimal.parse('1000'),
      paymentType: PaymentType.cash,
      cashReceived: Decimal.parse('900'),
    );
    expect(s.canComplete, isFalse);
  });
}
