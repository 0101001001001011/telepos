abstract class AccountVisibleToPosUseCase {
  Future<List<dynamic>> getVisibleAccounts();

  Future<List<dynamic>> getVisibleByType(int type);

  Future<List<dynamic>> getVisibleBankAccounts();

  Future<List<dynamic>> getVisibleCustomAccounts();
}
