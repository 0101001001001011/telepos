abstract class ConfigSyncRepository {
  Future<Map<String, dynamic>?> getPosConfig(String posId);

  Future<void> saveConfig(Map<String, dynamic> config);
}
