import 'package:decimal/decimal.dart';

import 'package:telepos/domain/entities/service/service_order_entity.dart';

abstract class CreateServiceOrderUseCase {
  Future<ServiceOrderEntity> create({
    required int userId,
    int? clientAgentId,
    String? clientName,
    String? clientPhone,
    String? clientNote,
    String? deviceDescription,
    String? serialNumber,
    String? complaint,
    int? estimatedCompletionTime,
    Decimal? estimatedAmount,
    Decimal? prepaymentAmount,
  });
}
