abstract class LastSaleReceiptNoUseCase {
  Future<void> perform();
}

class LastSaleReceiptNoFailure implements Exception {
  const LastSaleReceiptNoFailure([this.message]);
  final String? message;

  @override
  String toString() => 'LastSaleReceiptNoFailure: ${message ?? 'unknown'}';
}
