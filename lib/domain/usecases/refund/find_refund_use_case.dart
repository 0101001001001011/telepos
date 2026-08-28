abstract class FindRefundUseCase {
  Future<dynamic> findByLocalId({required int localId});

  Future<dynamic> findBySale({
    required int saleReceiptNo,
    required int salePosId,
  });

  Future<dynamic> findByServerId({required int serverId});
}
