import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/agent/create_agent_use_case.dart';

class CreateAgentUseCaseImpl implements CreateAgentUseCase {
  CreateAgentUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  static const int _stateInProgress = 0;

  @override
  Future<CreateAgentResult> create({
    required String name,
    required int phone,
    required int type,
    String? bin,
    String? legalName,
    String? legalType,
    String? legalAddress,
    String? actualAddress,
    String? note,
  }) async {
    final existingByPhone = await findByPhone(phone, type);

    if (existingByPhone != null) {
      if (existingByPhone.isDeleted) {
        _logger.info(
          'CreateAgent: found deleted agent with phone=$phone, suggesting restore',
        );
        return CreateAgentResult.deletedExists(existingByPhone);
      } else {
        _logger.warning('CreateAgent: duplicate phone=$phone for type=$type');
        return CreateAgentResult.duplicatePhone(existingByPhone);
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final localId = await _db
        .into(_db.agents)
        .insert(
          AgentsCompanion.insert(
            name: Value(name),
            phone: Value(phone),
            type: Value(type),
            bin: Value(bin),
            legalName: Value(legalName),
            legalType: Value(legalType),
            legalAddress: Value(legalAddress),
            actualAddress: Value(actualAddress),
            note: Value(note),
            state: Value(_stateInProgress),
            editTime: Value(now),
            isDeleted: const Value(false),
          ),
        );

    _logger.info(
      'CreateAgent: created localId=$localId, name=$name, phone=$phone',
    );

    return CreateAgentResult.created(localId);
  }

  @override
  Future<AgentInfo?> findByPhone(int phone, int type) async {
    final agent = await _db.agentDao.findByPhoneAndType(phone, type);

    if (agent == null) return null;

    return AgentInfo(
      localId: agent.localId,
      serverId: agent.serverId,
      name: agent.name ?? '',
      phone: agent.phone ?? 0,
      type: agent.type ?? type,
      bin: agent.bin,
      isDeleted: agent.isDeleted,
    );
  }
}
