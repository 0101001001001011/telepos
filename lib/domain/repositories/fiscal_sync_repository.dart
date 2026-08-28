abstract class FiscalSyncRepository {
  Future<List<Map<String, dynamic>>> getUnsyncedFiscalDocs();

  Future<void> markFiscalDocsSynced(List<int> docIds);

  Future<void> saveFiscalStatus(Map<String, dynamic> status);
}
