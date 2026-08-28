import 'package:telepos/core/constants/enums/service_order_status.dart';
import 'package:telepos/domain/entities/service/service_order_entity.dart';

abstract class FindServiceOrdersUseCase {
  Future<List<ServiceOrderEntity>> findByStatus(ServiceOrderStatus status);

  Future<List<ServiceOrderEntity>> findActive();

  Future<ServiceOrderEntity?> findByOrderNumber(String orderNumber);

  Future<List<ServiceOrderEntity>> search(String query);
}
