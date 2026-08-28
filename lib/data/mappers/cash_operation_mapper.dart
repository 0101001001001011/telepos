import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/cash_operation/cash_operation_entity.dart';

class CashOperationMapper {
  CashOperationMapper._();

  static CashOperationEntity fromDrift(CashOperation operation) {
    return CashOperationEntity(
      id: operation.id,
      storeId: operation.storeId,
      amount: operation.amount,
      accountId: operation.accountId,
      type: operation.type,
      userId: operation.userId,
      note: operation.note,
      docTime: operation.docTime,
      state: operation.state,
    );
  }

  static CashOperationsCompanion toDrift(CashOperationEntity entity) {
    return CashOperationsCompanion(
      id: entity.id != null ? Value(entity.id!) : const Value.absent(),
      storeId: Value(entity.storeId),
      amount: Value(entity.amount),
      accountId: Value(entity.accountId),
      type: Value(entity.type),
      userId: Value(entity.userId),
      note: Value(entity.note),
      docTime: Value(entity.docTime),
      state: Value(entity.state),
    );
  }

  static List<CashOperationEntity> fromDriftList(
    List<CashOperation> operations,
  ) {
    return operations.map(fromDrift).toList();
  }
}
