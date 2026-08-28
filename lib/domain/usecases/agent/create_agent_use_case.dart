abstract class CreateAgentUseCase {
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
  });

  Future<AgentInfo?> findByPhone(int phone, int type);
}

class CreateAgentResult {
  const CreateAgentResult._({
    required this.status,
    this.localId,
    this.existingAgent,
  });

  final CreateAgentStatus status;

  final int? localId;

  final AgentInfo? existingAgent;

  factory CreateAgentResult.created(int localId) =>
      CreateAgentResult._(status: CreateAgentStatus.created, localId: localId);

  factory CreateAgentResult.duplicatePhone(AgentInfo existing) =>
      CreateAgentResult._(
        status: CreateAgentStatus.duplicatePhone,
        existingAgent: existing,
      );

  factory CreateAgentResult.deletedExists(AgentInfo existing) =>
      CreateAgentResult._(
        status: CreateAgentStatus.deletedExists,
        existingAgent: existing,
      );
}

enum CreateAgentStatus { created, duplicatePhone, deletedExists }

class AgentInfo {
  const AgentInfo({
    required this.localId,
    this.serverId,
    required this.name,
    required this.phone,
    required this.type,
    this.bin,
    required this.isDeleted,
  });

  final int localId;
  final int? serverId;
  final String name;
  final int phone;
  final int type;
  final String? bin;
  final bool isDeleted;
}
