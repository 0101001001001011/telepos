import 'package:decimal/decimal.dart';

abstract class OnRefundCustomerUseCase {
  Future<void> perform({
    required Decimal refundAmount,
    required Decimal cashbackAmount,
    required List<Decimal> paymentAmounts,
    required int customerLocalId,
  });
}

class AgentNotFound implements Exception {
  const AgentNotFound([this.message]);
  final String? message;

  @override
  String toString() => 'AgentNotFound: ${message ?? 'unknown'}';
}
