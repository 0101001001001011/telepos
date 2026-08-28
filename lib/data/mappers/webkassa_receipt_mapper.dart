import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/fiscal/webkassa_service.dart';

class WebkassaReceiptMapper {
  WebkassaReceiptMapper._();

  static FiscalReceipt toEntity(WebkassaReceipt receipt) {
    return FiscalReceipt(
      operationId: receipt.operationId,
      receiptNo: receipt.receiptNo,
      fiscalNo: receipt.fiscalNo,
      wkReceiptNo: receipt.wkReceiptNo,
      wkTime: receipt.wkTime != null
          ? DateTime.fromMillisecondsSinceEpoch(receipt.wkTime! * 1000)
          : null,
      wkOfflineMode: receipt.wkOfflineMode ?? false,
      ticketUrl: receipt.ticketUrl,
      isSale: receipt.isSale ?? true,
    );
  }

  static WebkassaReceiptsCompanion toCompanion(FiscalReceipt entity) {
    return WebkassaReceiptsCompanion(
      operationId: Value(entity.operationId),
      receiptNo: Value(entity.receiptNo),
      fiscalNo: Value(entity.fiscalNo),
      wkReceiptNo: Value(entity.wkReceiptNo),
      wkTime: Value(
        entity.wkTime != null
            ? entity.wkTime!.millisecondsSinceEpoch ~/ 1000
            : null,
      ),
      wkOfflineMode: Value(entity.wkOfflineMode),
      ticketUrl: Value(entity.ticketUrl),
      isSale: Value(entity.isSale),
    );
  }

  static List<FiscalReceipt> toEntityList(List<WebkassaReceipt> receipts) {
    return receipts.map(toEntity).toList();
  }

  static FiscalReceipt fromFiscalizeResult({
    required int operationId,
    required int receiptNo,
    required FiscalizeResult result,
    required bool isSale,
  }) {
    return FiscalReceipt(
      operationId: operationId,
      receiptNo: receiptNo,
      fiscalNo: result.fiscalNo,
      wkReceiptNo: result.fiscalNo,
      wkTime: DateTime.now(),
      wkOfflineMode: result.offlineMode,
      ticketUrl: result.ticketUrl,
      isSale: isSale,
    );
  }
}
