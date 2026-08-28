import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/agent/create_agent_use_case.dart';
import 'package:telepos/domain/usecases/agent/restore_agent_use_case.dart';

class RestoreAgentUseCaseImpl implements RestoreAgentUseCase {
  RestoreAgentUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<RestoreAgentResult> restore(int localId) async {
    final agent = await (_db.select(
      _db.agents,
    )..where((a) => a.localId.equals(localId))).getSingleOrNull();

    if (agent == null) {
      _logger.warning('RestoreAgent: agent localId=$localId not found');
      return RestoreAgentResult.notFound();
    }

    if (!agent.isDeleted) {
      _logger.warning('RestoreAgent: agent localId=$localId is not deleted');
      return RestoreAgentResult.notDeleted();
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await (_db.update(
      _db.agents,
    )..where((a) => a.localId.equals(localId))).write(
      AgentsCompanion(isDeleted: const Value(false), editTime: Value(now)),
    );

    _logger.info('RestoreAgent: restored localId=$localId');

    return RestoreAgentResult.restored(
      AgentInfo(
        localId: agent.localId,
        serverId: agent.serverId,
        name: agent.name ?? '',
        phone: agent.phone ?? 0,
        type: agent.type ?? 0,
        bin: agent.bin,
        isDeleted: false,
      ),
    );
  }

  @override
  Future<RestoreAgentResult> restoreByPhone(int phone, int type) async {
    final agent =
        await (_db.select(_db.agents)
              ..where((a) => a.phone.equals(phone))
              ..where((a) => a.type.equals(type))
              ..where((a) => a.isDeleted.equals(true))
              ..limit(1))
            .getSingleOrNull();

    if (agent == null) {
      _logger.warning(
        'RestoreAgent: deleted agent with phone=$phone, type=$type not found',
      );
      return RestoreAgentResult.notFound();
    }

    return restore(agent.localId);
  }
}
