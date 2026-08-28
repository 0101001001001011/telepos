class FiscalReceiptEntity {
  const FiscalReceiptEntity({
    this.operationId,
    this.receiptNo,
    this.fiscalNo,
    this.wkReceiptNo,
    this.wkTime,
    this.wkOfflineMode = false,
    this.ticketUrl,
    this.isSale = true,
  });

  final int? operationId;

  final int? receiptNo;

  final String? fiscalNo;

  final String? wkReceiptNo;

  final int? wkTime;

  final bool wkOfflineMode;

  final String? ticketUrl;

  final bool isSale;

  FiscalReceiptEntity copyWith({
    int? operationId,
    int? receiptNo,
    String? fiscalNo,
    String? wkReceiptNo,
    int? wkTime,
    bool? wkOfflineMode,
    String? ticketUrl,
    bool? isSale,
  }) {
    return FiscalReceiptEntity(
      operationId: operationId ?? this.operationId,
      receiptNo: receiptNo ?? this.receiptNo,
      fiscalNo: fiscalNo ?? this.fiscalNo,
      wkReceiptNo: wkReceiptNo ?? this.wkReceiptNo,
      wkTime: wkTime ?? this.wkTime,
      wkOfflineMode: wkOfflineMode ?? this.wkOfflineMode,
      ticketUrl: ticketUrl ?? this.ticketUrl,
      isSale: isSale ?? this.isSale,
    );
  }
}
