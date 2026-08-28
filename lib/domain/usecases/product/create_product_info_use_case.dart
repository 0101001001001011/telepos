abstract class CreateProductInfoUseCase {
  Future<int> create({
    int? ucode,
    required int barcode,
    required String name,
    required int type,
    required int measure,
    int? categoryId,
    String? description,
    String? imagePath,
    int? vatRate,
    String? ntin,
    bool isMarkable = false,
    String? brand,
    String? manufacturer,
    String? countryOfOrigin,
  });

  Future<int> generateUcode();

  Future<int> generateBarcode();
}
