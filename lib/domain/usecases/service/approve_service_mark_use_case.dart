import 'package:telepos/domain/entities/service/service_mark_entity.dart';

abstract class ApproveServiceMarkUseCase {
  Future<ServiceMarkEntity> approve({
    required int markId,
    required int approverUserId,
  });

  Future<ServiceMarkEntity> reject({
    required int markId,
    required int approverUserId,
  });
}
