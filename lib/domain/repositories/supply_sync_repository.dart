abstract class SupplySyncRepository {
  Future<List<Map<String, dynamic>>> getUnsyncedSupplies();

  Future<void> markSuppliesSynced(List<int> supplyIds);
}
