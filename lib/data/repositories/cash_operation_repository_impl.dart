import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/cash_operation_mapper.dart';
import 'package:telepos/domain/entities/cash_operation/cash_operation_entity.dart';
import 'package:telepos/domain/repositories/cash_operation_repository.dart';

class CashOperationRepositoryImpl implements CashOperationRepository {
  CashOperationRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<List<CashOperationEntity>> findByShift(int shiftOpenTime) async {
    final operations = await _db.cashOperationDao.findByTimeRange(
      shiftOpenTime,
    );
    return CashOperationMapper.fromDriftList(operations);
  }

  @override
  Future<int> insert(CashOperationEntity entity) async {
    final companion = CashOperationMapper.toDrift(entity);
    return _db.into(_db.cashOperations).insert(companion);
  }
}
