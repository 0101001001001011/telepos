import 'package:decimal/decimal.dart';

import 'package:telepos/domain/entities/service/service_mark_entity.dart';

abstract class AddServiceMarkUseCase {
  Future<ServiceMarkEntity> add({
    required int serviceOrderId,
    required String description,
    required int markType,
    required int userId,
    Decimal? cost,
    String? note,
    int? productUcode,
    int? approvalStatus,
    Decimal? quantity,
  });
}
