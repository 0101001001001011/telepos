import 'package:telepos/domain/entities/cash_operation/cash_operation_entity.dart';

abstract class CashOperationRepository {
  Future<List<CashOperationEntity>> findByShift(int shiftOpenTime);

  Future<int> insert(CashOperationEntity entity);
}
