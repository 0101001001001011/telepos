abstract class FindByAliasUseCase {
  Future<int?> find(String alias);

  Future<List<int>> findByPart(String aliasPart);
}
