import 'package:telepos/domain/usecases/agent/create_agent_use_case.dart';

abstract class RestoreAgentUseCase {
  Future<RestoreAgentResult> restore(int localId);

  Future<RestoreAgentResult> restoreByPhone(int phone, int type);
}

class RestoreAgentResult {
  const RestoreAgentResult._({required this.status, this.agent});

  final RestoreAgentStatus status;

  final AgentInfo? agent;

  factory RestoreAgentResult.restored(AgentInfo agent) =>
      RestoreAgentResult._(status: RestoreAgentStatus.restored, agent: agent);

  factory RestoreAgentResult.notFound() =>
      const RestoreAgentResult._(status: RestoreAgentStatus.notFound);

  factory RestoreAgentResult.notDeleted() =>
      const RestoreAgentResult._(status: RestoreAgentStatus.notDeleted);
}

enum RestoreAgentStatus { restored, notFound, notDeleted }
