import 'upload_operation.dart';

class SaleUpload extends UploadOperation<Map<String, dynamic>> {
  @override
  String get name => 'SaleUpload';

  @override
  String get entityType => 'Sale';

  @override
  Future<UploadResult> execute({
    required List<Map<String, dynamic>> items,
    int batchSize = 500,
  }) async {
    return UploadResult.nothingToUpload();
  }
}

class RefundUpload extends UploadOperation<Map<String, dynamic>> {
  @override
  String get name => 'RefundUpload';

  @override
  String get entityType => 'Refund';

  @override
  Future<UploadResult> execute({
    required List<Map<String, dynamic>> items,
    int batchSize = 500,
  }) async {
    return UploadResult.nothingToUpload();
  }
}

class PaymentUpload extends UploadOperation<Map<String, dynamic>> {
  @override
  String get name => 'PaymentUpload';

  @override
  String get entityType => 'Payment';

  @override
  Future<UploadResult> execute({
    required List<Map<String, dynamic>> items,
    int batchSize = 500,
  }) async {
    return UploadResult.nothingToUpload();
  }
}

class ProductUpload extends UploadOperation<Map<String, dynamic>> {
  @override
  String get name => 'ProductUpload';

  @override
  String get entityType => 'Product';

  @override
  Future<UploadResult> execute({
    required List<Map<String, dynamic>> items,
    int batchSize = 100,
  }) async {
    return UploadResult.nothingToUpload();
  }
}

class ProductPriceUpload extends UploadOperation<Map<String, dynamic>> {
  @override
  String get name => 'ProductPriceUpload';

  @override
  String get entityType => 'ProductPrice';

  @override
  Future<UploadResult> execute({
    required List<Map<String, dynamic>> items,
    int batchSize = 200,
  }) async {
    return UploadResult.nothingToUpload();
  }
}

class CreatedAgentUpload extends UploadOperation<Map<String, dynamic>> {
  @override
  String get name => 'CreatedAgentUpload';

  @override
  String get entityType => 'CreatedAgent';

  @override
  Future<UploadResult> execute({
    required List<Map<String, dynamic>> items,
    int batchSize = 100,
  }) async {
    return UploadResult.nothingToUpload();
  }
}

class ChangedAgentUpload extends UploadOperation<Map<String, dynamic>> {
  @override
  String get name => 'ChangedAgentUpload';

  @override
  String get entityType => 'ChangedAgent';

  @override
  Future<UploadResult> execute({
    required List<Map<String, dynamic>> items,
    int batchSize = 100,
  }) async {
    return UploadResult.nothingToUpload();
  }
}

class CancelledProductUpload extends UploadOperation<Map<String, dynamic>> {
  @override
  String get name => 'CancelledProductUpload';

  @override
  String get entityType => 'CancelledProduct';

  @override
  Future<UploadResult> execute({
    required List<Map<String, dynamic>> items,
    int batchSize = 100,
  }) async {
    return UploadResult.nothingToUpload();
  }
}

class ShiftUpload extends UploadOperation<Map<String, dynamic>> {
  @override
  String get name => 'ShiftUpload';

  @override
  String get entityType => 'Shift';

  @override
  Future<UploadResult> execute({
    required List<Map<String, dynamic>> items,
    int batchSize = 50,
  }) async {
    return UploadResult.nothingToUpload();
  }
}

class SupplyUpload extends UploadOperation<Map<String, dynamic>> {
  @override
  String get name => 'SupplyUpload';

  @override
  String get entityType => 'Supply';

  @override
  Future<UploadResult> execute({
    required List<Map<String, dynamic>> items,
    int batchSize = 50,
  }) async {
    return UploadResult.nothingToUpload();
  }
}

class UploadRegistry {
  UploadRegistry._();

  static final Map<String, UploadOperation<Map<String, dynamic>>> operations = {
    'Sale': SaleUpload(),
    'Refund': RefundUpload(),
    'Payment': PaymentUpload(),
    'Product': ProductUpload(),
    'ProductPrice': ProductPriceUpload(),
    'CreatedAgent': CreatedAgentUpload(),
    'ChangedAgent': ChangedAgentUpload(),
    'CancelledProduct': CancelledProductUpload(),
    'Shift': ShiftUpload(),
    'Supply': SupplyUpload(),
  };

  static UploadOperation<Map<String, dynamic>>? get(String entityType) {
    return operations[entityType];
  }

  static List<String> get allNames => operations.keys.toList();

  static int get count => operations.length;
}
