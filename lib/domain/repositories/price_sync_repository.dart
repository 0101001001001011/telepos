abstract class PriceSyncRepository {
  Future<void> savePrices(List<Map<String, dynamic>> prices);

  Future<List<Map<String, dynamic>>> getModifiedPrices(DateTime? since);
}
