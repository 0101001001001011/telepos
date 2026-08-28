import 'package:telepos/domain/entities/service/service_order_entity.dart';

abstract class ServiceOrderTransitionUseCase {
  Future<ServiceOrderEntity> progress(int orderId);

  Future<ServiceOrderEntity> cancel(int orderId);
}
