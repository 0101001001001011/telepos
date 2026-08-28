import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/agent/agent_last_id_use_case.dart';

class AgentLastIdUseCaseImpl implements AgentLastIdUseCase {
  AgentLastIdUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<int> getNextId() async {
    final lastId = await getLastId();
    final nextId = (lastId ?? 0) + 1;

    _logger.debug('AgentLastId: next id=$nextId');

    return nextId;
  }

  @override
  Future<int?> getLastId() async {
    return _db.agentDao.findLastLocalId();
  }

  @override
  Future<int> count({int? type}) async {
    if (type != null) {
      final agents = await _db.agentDao.findWithType(type);
      return agents.length;
    }

    final result = await _db
        .customSelect(
          'SELECT COUNT(*) AS cnt FROM agents WHERE is_deleted = 0',
          readsFrom: {_db.agents},
        )
        .getSingle();

    return result.read<int>('cnt');
  }

  @override
  Future<int> countUnsynced() async {
    return _db.agentDao.countUnSyncedCustomers();
  }
}
