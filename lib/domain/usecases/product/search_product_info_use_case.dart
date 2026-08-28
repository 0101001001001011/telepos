abstract class SearchProductInfoUseCase {
  Future<List<ProductSearchResult>> search({
    required String query,
    int limit = 50,
  });

  Future<List<ProductSearchResult>> searchByName({
    required String namePart,
    int limit = 50,
  });

  Future<List<ProductSearchResult>> searchByBarcode({
    required String barcodePart,
    int limit = 50,
  });
}

class ProductSearchResult {
  const ProductSearchResult({
    required this.ucode,
    required this.barcode,
    required this.name,
    required this.type,
    required this.measure,
    this.categoryId,
    this.isDeleted = false,
  });

  final int ucode;
  final int barcode;
  final String name;
  final int type;
  final int measure;
  final int? categoryId;
  final bool isDeleted;
}
