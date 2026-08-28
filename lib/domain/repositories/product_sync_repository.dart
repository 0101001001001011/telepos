abstract class ProductSyncRepository {
  Future<List<Map<String, dynamic>>> getModifiedSince(DateTime? since);

  Future<void> saveProducts(List<Map<String, dynamic>> products);

  Future<void> updateProduct(Map<String, dynamic> product);
}
