abstract class DeferredSaleService {
  Future<void> deferSale({required int receiptNo});

  Future<dynamic> undeferSale({required int receiptNo});

  Future<List<dynamic>> getDeferredSales();

  Future<List<DeferredSaleProduct>> getProducts({
    required int receiptNo,
    required int posId,
  });
}

class DeferredSaleProduct {
  const DeferredSaleProduct({
    required this.ucode,
    required this.name,
    required this.quantity,
    required this.price,
  });

  final int ucode;

  final String name;

  final dynamic quantity;

  final dynamic price;
}
