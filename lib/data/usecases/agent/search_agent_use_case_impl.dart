import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/agent/create_agent_use_case.dart';
import 'package:telepos/domain/usecases/agent/search_agent_use_case.dart';

class SearchAgentUseCaseImpl implements SearchAgentUseCase {
  SearchAgentUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<List<AgentInfo>> searchByName(
    String namePart,
    int type, {
    int limit = 100,
  }) async {
    final pattern = '%$namePart%';

    final agents = await _db.agentDao.findByNamePart(
      pattern,
      type,
      limit: limit,
    );

    _logger.debug(
      'SearchAgent: found ${agents.length} by name "$namePart", type=$type',
    );

    return agents.map(_toAgentInfo).toList();
  }

  @override
  Future<List<AgentInfo>> searchByPhone(
    String phonePart,
    int type, {
    int limit = 100,
  }) async {
    final pattern = '%$phonePart%';

    final agents = await _db.agentDao.findByPhonePart(pattern, type);

    _logger.debug(
      'SearchAgent: found ${agents.length} by phone "$phonePart", type=$type',
    );

    final limited = agents.take(limit).toList();
    return limited.map(_toAgentInfo).toList();
  }

  @override
  Future<List<AgentInfo>> searchByNameOrPhone(
    String query,
    int type, {
    int limit = 100,
  }) async {
    final pattern = '%$query%';

    final agents = await _db.agentDao.findByNameOrPhonePart(pattern, type);

    _logger.debug(
      'SearchAgent: found ${agents.length} by query "$query", type=$type',
    );

    final limited = agents.take(limit).toList();
    return limited.map(_toAgentInfo).toList();
  }

  @override
  Future<List<AgentInfo>> findAllByType(int type) async {
    final agents = await _db.agentDao.findWithType(type);

    _logger.debug('SearchAgent: found ${agents.length} agents of type=$type');

    return agents.map(_toAgentInfo).toList();
  }

  AgentInfo _toAgentInfo(Agent agent) => AgentInfo(
    localId: agent.localId,
    serverId: agent.serverId,
    name: agent.name ?? '',
    phone: agent.phone ?? 0,
    type: agent.type ?? 0,
    bin: agent.bin,
    isDeleted: agent.isDeleted,
  );
}
