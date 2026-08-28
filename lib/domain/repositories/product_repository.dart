abstract class ProductRepository {
  Future<ProductInfo?> findByBarcode(int barcode);

  Future<ProductInfo?> findByUcode(int ucode);

  Future<List<ProductInfo>> search(String query, {int limit = 20});

  Future<int> count();
}

class ProductInfo {
  const ProductInfo({
    required this.ucode,
    this.barcode,
    this.name,
    this.categoryId,
    this.categoryName,
    this.unitName,
    this.isWeightProduct = false,
  });

  final int ucode;
  final int? barcode;
  final String? name;
  final int? categoryId;
  final String? categoryName;
  final String? unitName;
  final bool isWeightProduct;
}
