import 'package:decimal/decimal.dart';

import 'package:telepos/domain/entities/service/service_mark_entity.dart';

class ServiceOrderReceiptData {
  const ServiceOrderReceiptData({
    required this.orderNumber,
    required this.clientName,
    this.deviceDescription,
    this.complaint,
    required this.intakeTime,
    this.estimatedCompletionTime,
    this.estimatedAmount,
    this.marks = const [],
  });

  final String orderNumber;
  final String clientName;
  final String? deviceDescription;
  final String? complaint;
  final int intakeTime;
  final int? estimatedCompletionTime;
  final Decimal? estimatedAmount;
  final List<ServiceMarkEntity> marks;
}

abstract class ServiceOrderReceiptUseCase {
  Future<ServiceOrderReceiptData> generateIntakeReceipt(int orderId);

  Future<ServiceOrderReceiptData> generateCompletionReceipt(int orderId);
}
