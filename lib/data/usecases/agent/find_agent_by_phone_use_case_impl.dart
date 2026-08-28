import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/agent/create_agent_use_case.dart';
import 'package:telepos/domain/usecases/agent/find_agent_by_phone_use_case.dart';

class FindAgentByPhoneUseCaseImpl implements FindAgentByPhoneUseCase {
  FindAgentByPhoneUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<AgentInfo?> find(int phone) async {
    final agent = await _db.agentDao.findByPhone(phone);

    if (agent == null) {
      _logger.debug('FindAgentByPhone: phone=$phone not found');
      return null;
    }

    _logger.debug(
      'FindAgentByPhone: found localId=${agent.localId} for phone=$phone',
    );

    return _toAgentInfo(agent);
  }

  @override
  Future<AgentInfo?> findByType(int phone, int type) async {
    final agent = await _db.agentDao.findByPhoneAndType(phone, type);

    if (agent == null) {
      _logger.debug('FindAgentByPhone: phone=$phone, type=$type not found');
      return null;
    }

    return _toAgentInfo(agent);
  }

  @override
  Future<AgentInfo?> findByServerId(int serverId) async {
    final agent = await _db.agentDao.findByServerId(serverId);

    if (agent == null) {
      _logger.debug('FindAgentByPhone: serverId=$serverId not found');
      return null;
    }

    return _toAgentInfo(agent);
  }

  @override
  Future<AgentInfo?> findByLocalId(int localId) async {
    final agent = await (_db.select(
      _db.agents,
    )..where((a) => a.localId.equals(localId))).getSingleOrNull();

    if (agent == null) {
      _logger.debug('FindAgentByPhone: localId=$localId not found');
      return null;
    }

    return _toAgentInfo(agent);
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
