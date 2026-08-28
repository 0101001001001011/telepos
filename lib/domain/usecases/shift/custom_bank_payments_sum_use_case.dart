import 'package:telepos/domain/entities/shift/shift_receipt.dart';

abstract class CustomBankPaymentsSumUseCase {
  Future<List<PaymentSumEntry>> getPaymentSums({
    required int userId,
    required int openTime,
    required int closeTime,
  });
}
