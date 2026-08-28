abstract class SaleSyncRepository {
  Future<List<Map<String, dynamic>>> getUnsyncedSales();

  Future<void> markSalesSynced(List<int> saleIds);

  Future<void> updateFiscalData(List<Map<String, dynamic>> fiscalData);
}
