import 'package:telepos/domain/entities/service/service_order_entity.dart';

abstract class UpdateServiceOrderUseCase {
  Future<void> update(ServiceOrderEntity order);
}
