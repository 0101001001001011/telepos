abstract class RefundSyncRepository {
  Future<List<Map<String, dynamic>>> getUnsyncedRefunds();

  Future<void> markRefundsSynced(List<int> refundIds);
}
