import 'download_operation.dart';

class ProductDownload extends DownloadOperation<Map<String, dynamic>> {
  @override
  String get name => 'ProductDownload';

  @override
  String get entityType => 'Product';

  @override
  Future<DownloadResult<Map<String, dynamic>>> execute({
    DateTime? since,
    int batchSize = 400,
  }) async {
    return DownloadResult.empty();
  }
}

class SaleDownload extends DownloadOperation<Map<String, dynamic>> {
  @override
  String get name => 'SaleDownload';

  @override
  String get entityType => 'Sale';

  @override
  Future<DownloadResult<Map<String, dynamic>>> execute({
    DateTime? since,
    int batchSize = 500,
  }) async {
    return DownloadResult.empty();
  }
}

class UserDownload extends DownloadOperation<Map<String, dynamic>> {
  @override
  String get name => 'UserDownload';

  @override
  String get entityType => 'User';

  @override
  Future<DownloadResult<Map<String, dynamic>>> execute({
    DateTime? since,
    int batchSize = 50,
  }) async {
    return DownloadResult.empty();
  }
}

class AgentDownload extends DownloadOperation<Map<String, dynamic>> {
  @override
  String get name => 'AgentDownload';

  @override
  String get entityType => 'Agent';

  @override
  Future<DownloadResult<Map<String, dynamic>>> execute({
    DateTime? since,
    int batchSize = 1000,
  }) async {
    return DownloadResult.empty();
  }
}

class AccountDownload extends DownloadOperation<Map<String, dynamic>> {
  @override
  String get name => 'AccountDownload';

  @override
  String get entityType => 'Account';

  @override
  Future<DownloadResult<Map<String, dynamic>>> execute({
    DateTime? since,
    int batchSize = 100,
  }) async {
    return DownloadResult.empty();
  }
}

class RefundDownload extends DownloadOperation<Map<String, dynamic>> {
  @override
  String get name => 'RefundDownload';

  @override
  String get entityType => 'Refund';

  @override
  Future<DownloadResult<Map<String, dynamic>>> execute({
    DateTime? since,
    int batchSize = 500,
  }) async {
    return DownloadResult.empty();
  }
}

class CategoryDownload extends DownloadOperation<Map<String, dynamic>> {
  @override
  String get name => 'CategoryDownload';

  @override
  String get entityType => 'Category';

  @override
  Future<DownloadResult<Map<String, dynamic>>> execute({
    DateTime? since,
    int batchSize = 100,
  }) async {
    return DownloadResult.empty();
  }
}

class CategoryRestrictionDownload
    extends DownloadOperation<Map<String, dynamic>> {
  @override
  String get name => 'CategoryRestrictionDownload';

  @override
  String get entityType => 'CategoryRestriction';

  @override
  Future<DownloadResult<Map<String, dynamic>>> execute({
    DateTime? since,
    int batchSize = 100,
  }) async {
    return DownloadResult.empty();
  }
}

class GlobalProductDownload extends DownloadOperation<Map<String, dynamic>> {
  @override
  String get name => 'GlobalProductDownload';

  @override
  String get entityType => 'GlobalProduct';

  @override
  Future<DownloadResult<Map<String, dynamic>>> execute({
    DateTime? since,
    int batchSize = 400,
  }) async {
    return DownloadResult.empty();
  }
}

class PackageProductDownload extends DownloadOperation<Map<String, dynamic>> {
  @override
  String get name => 'PackageProductDownload';

  @override
  String get entityType => 'PackageProduct';

  @override
  Future<DownloadResult<Map<String, dynamic>>> execute({
    DateTime? since,
    int batchSize = 500,
  }) async {
    return DownloadResult.empty();
  }
}

class ProductAliasDownload extends DownloadOperation<Map<String, dynamic>> {
  @override
  String get name => 'ProductAliasDownload';

  @override
  String get entityType => 'ProductAlias';

  @override
  Future<DownloadResult<Map<String, dynamic>>> execute({
    DateTime? since,
    int batchSize = 500,
  }) async {
    return DownloadResult.empty();
  }
}

class ProductPriceDownload extends DownloadOperation<Map<String, dynamic>> {
  @override
  String get name => 'ProductPriceDownload';

  @override
  String get entityType => 'ProductPrice';

  @override
  Future<DownloadResult<Map<String, dynamic>>> execute({
    DateTime? since,
    int batchSize = 600,
  }) async {
    return DownloadResult.empty();
  }
}

class QuickProductDownload extends DownloadOperation<Map<String, dynamic>> {
  @override
  String get name => 'QuickProductDownload';

  @override
  String get entityType => 'QuickProduct';

  @override
  Future<DownloadResult<Map<String, dynamic>>> execute({
    DateTime? since,
    int batchSize = 200,
  }) async {
    return DownloadResult.empty();
  }
}

class PosDownload extends DownloadOperation<Map<String, dynamic>> {
  @override
  String get name => 'PosDownload';

  @override
  String get entityType => 'Pos';

  @override
  Future<DownloadResult<Map<String, dynamic>>> execute({
    DateTime? since,
    int batchSize = 50,
  }) async {
    return DownloadResult.empty();
  }
}

class ThisPosDownload extends DownloadOperation<Map<String, dynamic>> {
  @override
  String get name => 'ThisPosDownload';

  @override
  String get entityType => 'ThisPos';

  @override
  Future<DownloadResult<Map<String, dynamic>>> execute({
    DateTime? since,
    int batchSize = 1,
  }) async {
    return DownloadResult.empty();
  }
}

class LastReportDownload extends DownloadOperation<Map<String, dynamic>> {
  @override
  String get name => 'LastReportDownload';

  @override
  String get entityType => 'LastReport';

  @override
  Future<DownloadResult<Map<String, dynamic>>> execute({
    DateTime? since,
    int batchSize = 1,
  }) async {
    return DownloadResult.empty();
  }
}

class DownloadRegistry {
  DownloadRegistry._();

  static final Map<String, DownloadOperation<Map<String, dynamic>>> operations =
      {
        'Product': ProductDownload(),
        'Sale': SaleDownload(),
        'User': UserDownload(),
        'Agent': AgentDownload(),
        'Account': AccountDownload(),
        'Refund': RefundDownload(),
        'Category': CategoryDownload(),
        'CategoryRestriction': CategoryRestrictionDownload(),
        'GlobalProduct': GlobalProductDownload(),
        'PackageProduct': PackageProductDownload(),
        'ProductAlias': ProductAliasDownload(),
        'ProductPrice': ProductPriceDownload(),
        'QuickProduct': QuickProductDownload(),
        'Pos': PosDownload(),
        'ThisPos': ThisPosDownload(),
        'LastReport': LastReportDownload(),
      };

  static DownloadOperation<Map<String, dynamic>>? get(String entityType) {
    return operations[entityType];
  }

  static List<String> get allNames => operations.keys.toList();

  static int get count => operations.length;
}
