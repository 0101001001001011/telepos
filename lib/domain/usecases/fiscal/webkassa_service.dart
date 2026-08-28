import 'package:decimal/decimal.dart';

abstract class WebKassaService {
  Future<FiscalizeResult> fiscalizeSale({
    required int saleId,
    required Decimal amount,
    required Decimal cashAmount,
    required Decimal cardAmount,
    List<FiscalItemData>? items,
    String? customerBin,
  });

  Future<FiscalizeResult> fiscalizeRefund({
    required int refundId,
    required String originalFiscalNo,
    required Decimal amount,
    List<FiscalItemData>? items,
  });

  Future<WebKassaStatus> getStatus();

  Future<WebKassaConfig?> getConfig();

  Future<bool> isAvailable();

  Future<int> getOfflineReceiptCount();

  Future<OfflineSyncResult> syncOfflineReceipts();
}

class OfflineSyncResult {
  const OfflineSyncResult({
    required this.totalCount,
    required this.syncedCount,
    required this.failedCount,
    this.errors = const [],
  });

  final int totalCount;

  final int syncedCount;

  final int failedCount;

  final List<String> errors;

  bool get isFullySync => totalCount > 0 && failedCount == 0;

  bool get hasErrors => failedCount > 0;

  factory OfflineSyncResult.empty() =>
      const OfflineSyncResult(totalCount: 0, syncedCount: 0, failedCount: 0);

  @override
  String toString() =>
      'OfflineSyncResult(total: $totalCount, synced: $syncedCount, failed: $failedCount)';
}

class FiscalizeResult {
  const FiscalizeResult({
    required this.success,
    this.fiscalNo,
    this.ticketUrl,
    this.offlineMode = false,
    this.errorMessage,
    this.errorCode,
  });

  final bool success;

  final String? fiscalNo;

  final String? ticketUrl;

  final bool offlineMode;

  final String? errorMessage;

  final int? errorCode;

  factory FiscalizeResult.success({
    required String fiscalNo,
    String? ticketUrl,
    bool offlineMode = false,
  }) => FiscalizeResult(
    success: true,
    fiscalNo: fiscalNo,
    ticketUrl: ticketUrl,
    offlineMode: offlineMode,
  );

  factory FiscalizeResult.failed(String message, {int? errorCode}) =>
      FiscalizeResult(
        success: false,
        errorMessage: message,
        errorCode: errorCode,
      );

  factory FiscalizeResult.notConfigured() => const FiscalizeResult(
    success: false,
    errorMessage: 'WebKassa не настроен',
    errorCode: -1,
  );
}

class WebKassaStatus {
  const WebKassaStatus({
    required this.isConfigured,
    required this.isActive,
    required this.isOnline,
    this.lastErrorTime,
    this.lastError,
  });

  final bool isConfigured;

  final bool isActive;

  final bool isOnline;

  final DateTime? lastErrorTime;

  final String? lastError;

  bool get canFiscalize => isConfigured && isActive;
}

class WebKassaConfig {
  const WebKassaConfig({
    required this.posId,
    this.posFactoryNo,
    this.taxDeptRegNo,
    this.ofdId,
    this.taxpayerName,
    this.iinBin,
    this.address,
    this.ofdName,
    this.ofdHost,
    required this.isActive,
    required this.isTaxpayer,
    this.vatSerialNo,
    this.vatNo,
  });

  final int posId;

  final String? posFactoryNo;

  final String? taxDeptRegNo;

  final String? ofdId;

  final String? taxpayerName;

  final String? iinBin;

  final String? address;

  final String? ofdName;

  final String? ofdHost;

  final bool isActive;

  final bool isTaxpayer;

  final String? vatSerialNo;

  final String? vatNo;

  String? get fullOfdUrl {
    if (ofdHost == null || ofdHost!.isEmpty) return null;
    return ofdHost!.startsWith('http') ? ofdHost : 'https://$ofdHost';
  }
}

class FiscalItemData {
  const FiscalItemData({
    required this.name,
    required this.quantity,
    required this.price,
    required this.amount,
    this.barcode,
    this.markCode,
  });

  final String name;

  final Decimal quantity;

  final Decimal price;

  final Decimal amount;

  final String? barcode;

  final String? markCode;
}

class FiscalReceipt {
  const FiscalReceipt({
    required this.operationId,
    this.receiptNo,
    this.fiscalNo,
    this.wkReceiptNo,
    this.wkTime,
    this.wkOfflineMode = false,
    this.ticketUrl,
    required this.isSale,
  });

  final int operationId;

  final int? receiptNo;

  final String? fiscalNo;

  final String? wkReceiptNo;

  final DateTime? wkTime;

  final bool wkOfflineMode;

  final String? ticketUrl;

  final bool isSale;

  bool get hasTicketUrl => ticketUrl != null && ticketUrl!.isNotEmpty;
}
