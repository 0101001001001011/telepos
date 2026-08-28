import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/agent_mapper.dart';
import 'package:telepos/domain/entities/agent/agent_entity.dart';
import 'package:telepos/domain/repositories/agent_repository.dart';

class AgentRepositoryImpl implements AgentRepository {
  AgentRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<AgentEntity?> findById(int localId) async {
    final agent = await _db.agentDao.findById(localId);
    return agent != null ? AgentMapper.fromDrift(agent) : null;
  }

  @override
  Future<AgentEntity?> findByPhone(int phone) async {
    final agent = await _db.agentDao.findByPhone(phone);
    return agent != null ? AgentMapper.fromDrift(agent) : null;
  }

  @override
  Future<List<AgentEntity>> search(String query) async {
    final results = <Agent>[];
    for (final type in [0, 1, 2]) {
      final agents = await _db.agentDao.findByNameOrPhonePart('%$query%', type);
      results.addAll(agents);
    }
    return AgentMapper.fromDriftList(results);
  }

  @override
  Future<List<AgentEntity>> findByType(int type) async {
    final agents = await _db.agentDao.findWithType(type);
    return AgentMapper.fromDriftList(agents);
  }

  @override
  Future<int> create(AgentEntity entity) async {
    final companion = AgentMapper.toDrift(entity);
    return _db.into(_db.agents).insert(companion);
  }

  @override
  Future<void> update(AgentEntity entity) async {
    if (entity.localId == null) return;
    final companion = AgentMapper.toDrift(entity);
    await (_db.update(
      _db.agents,
    )..where((a) => a.localId.equals(entity.localId!))).write(companion);
  }

  @override
  Future<void> softDelete(int localId) {
    return _db.agentDao.softDelete(localId).then((_) {});
  }
}
