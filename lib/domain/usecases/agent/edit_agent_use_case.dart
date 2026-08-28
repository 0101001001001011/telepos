abstract class EditAgentUseCase {
  Future<bool> edit({
    required int localId,
    String? name,
    int? phone,
    String? bin,
    String? legalName,
    String? legalType,
    String? legalAddress,
    String? actualAddress,
    String? note,
  });

  Future<bool> updateType(int localId, int type);

  Future<bool> delete(int localId);
}
