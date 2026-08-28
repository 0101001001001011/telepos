library;

import 'package:decimal/decimal.dart';

enum FiscalPaymentKind { cash, card, credit, mobile, tare }

enum FiscalTaxMode { none, vat }

enum FiscalOperationKind { sale, saleReturn, purchase, purchaseReturn }

enum FiscalErrorCode {
  ok,
  badCredentials,
  tokenExpired,
  cashboxNotFound,
  cashboxBlocked,
  offlineLimitExceeded,
  offlineNotSupported,
  duplicate,
  validation,
  notEnoughMoney,
  shiftError,
  unsupported,
  notConfigured,
  network,
  unknown,
}

class FiscalTax {
  const FiscalTax({
    required this.mode,
    required this.ratePercent,
    required this.amount,
  });

  final FiscalTaxMode mode;

  final Decimal ratePercent;

  final Decimal amount;

  factory FiscalTax.none() => FiscalTax(
    mode: FiscalTaxMode.none,
    ratePercent: Decimal.zero,
    amount: Decimal.zero,
  );

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'ratePercent': ratePercent.toString(),
    'amount': amount.toString(),
  };

  factory FiscalTax.fromJson(Map<String, dynamic> json) => FiscalTax(
    mode: FiscalTaxMode.values.byName(json['mode'] as String? ?? 'none'),
    ratePercent: Decimal.parse((json['ratePercent'] ?? '0').toString()),
    amount: Decimal.parse((json['amount'] ?? '0').toString()),
  );
}

class FiscalPosition {
  const FiscalPosition({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.tax,
    this.discount = _zeroPlaceholder,
    this.markup = _zeroPlaceholder,
    this.unitCode,
    this.barcode,
    this.ntin,
    this.sectionCode,
    this.markCodes = const [],
    this.warehouseProductId,
    this.virtualWarehouse = false,
  });

  static const Decimal? _zeroPlaceholder = null;

  final String name;

  final Decimal quantity;

  final Decimal unitPrice;

  final Decimal lineTotal;

  final FiscalTax tax;

  final Decimal? discount;

  final Decimal? markup;

  final int? unitCode;

  final String? barcode;

  final String? ntin;

  final String? sectionCode;

  final List<String> markCodes;

  final String? warehouseProductId;

  final bool virtualWarehouse;

  Decimal get discountOr => discount ?? Decimal.zero;

  Decimal get markupOr => markup ?? Decimal.zero;

  bool get isMarked => markCodes.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity.toString(),
    'unitPrice': unitPrice.toString(),
    'lineTotal': lineTotal.toString(),
    'tax': tax.toJson(),
    'discount': discountOr.toString(),
    'markup': markupOr.toString(),
    if (unitCode != null) 'unitCode': unitCode,
    if (barcode != null) 'barcode': barcode,
    if (ntin != null) 'ntin': ntin,
    if (sectionCode != null) 'sectionCode': sectionCode,
    if (markCodes.isNotEmpty) 'markCodes': markCodes,
    if (warehouseProductId != null) 'warehouseProductId': warehouseProductId,
    'virtualWarehouse': virtualWarehouse,
  };

  factory FiscalPosition.fromJson(Map<String, dynamic> json) => FiscalPosition(
    name: json['name'] as String? ?? '',
    quantity: Decimal.parse((json['quantity'] ?? '0').toString()),
    unitPrice: Decimal.parse((json['unitPrice'] ?? '0').toString()),
    lineTotal: Decimal.parse((json['lineTotal'] ?? '0').toString()),
    tax: FiscalTax.fromJson(
      (json['tax'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    discount: Decimal.parse((json['discount'] ?? '0').toString()),
    markup: Decimal.parse((json['markup'] ?? '0').toString()),
    unitCode: json['unitCode'] as int?,
    barcode: json['barcode'] as String?,
    ntin: json['ntin'] as String?,
    sectionCode: json['sectionCode'] as String?,
    markCodes:
        (json['markCodes'] as List?)?.map((e) => e.toString()).toList() ??
        const [],
    warehouseProductId: json['warehouseProductId'] as String?,
    virtualWarehouse: json['virtualWarehouse'] as bool? ?? false,
  );
}

class FiscalPayment {
  const FiscalPayment({required this.kind, required this.amount});

  final FiscalPaymentKind kind;

  final Decimal amount;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'amount': amount.toString(),
  };

  factory FiscalPayment.fromJson(Map<String, dynamic> json) => FiscalPayment(
    kind: FiscalPaymentKind.values.byName(json['kind'] as String? ?? 'cash'),
    amount: Decimal.parse((json['amount'] ?? '0').toString()),
  );
}

class FiscalCustomer {
  const FiscalCustomer({this.binIin, this.email, this.phone});

  final String? binIin;
  final String? email;
  final String? phone;

  Map<String, dynamic> toJson() => {
    if (binIin != null) 'binIin': binIin,
    if (email != null) 'email': email,
    if (phone != null) 'phone': phone,
  };

  factory FiscalCustomer.fromJson(Map<String, dynamic> json) => FiscalCustomer(
    binIin: json['binIin'] as String?,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
  );
}

class FiscalSaleRequest {
  const FiscalSaleRequest({
    required this.idempotencyKey,
    required this.localOperationId,
    required this.positions,
    required this.payments,
    required this.totalDiscount,
    required this.totalMarkup,
    required this.occurredAt,
    this.kind = FiscalOperationKind.sale,
    this.customer,
    this.offlineAllowed = true,
  });

  final String idempotencyKey;

  final int localOperationId;

  final List<FiscalPosition> positions;
  final List<FiscalPayment> payments;

  final Decimal totalDiscount;

  final Decimal totalMarkup;

  final DateTime occurredAt;

  final FiscalOperationKind kind;

  final FiscalCustomer? customer;

  final bool offlineAllowed;

  Map<String, dynamic> toJson() => {
    'idempotencyKey': idempotencyKey,
    'localOperationId': localOperationId,
    'positions': positions.map((p) => p.toJson()).toList(),
    'payments': payments.map((p) => p.toJson()).toList(),
    'totalDiscount': totalDiscount.toString(),
    'totalMarkup': totalMarkup.toString(),
    'occurredAt': occurredAt.toIso8601String(),
    'kind': kind.name,
    if (customer != null) 'customer': customer!.toJson(),
    'offlineAllowed': offlineAllowed,
  };

  factory FiscalSaleRequest.fromJson(
    Map<String, dynamic> json,
  ) => FiscalSaleRequest(
    idempotencyKey: json['idempotencyKey'] as String? ?? '',
    localOperationId: json['localOperationId'] as int? ?? 0,
    positions: (json['positions'] as List? ?? [])
        .map((e) => FiscalPosition.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    payments: (json['payments'] as List? ?? [])
        .map((e) => FiscalPayment.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    totalDiscount: Decimal.parse((json['totalDiscount'] ?? '0').toString()),
    totalMarkup: Decimal.parse((json['totalMarkup'] ?? '0').toString()),
    occurredAt:
        DateTime.tryParse(json['occurredAt'] as String? ?? '') ??
        DateTime.now(),
    kind: FiscalOperationKind.values.byName(json['kind'] as String? ?? 'sale'),
    customer: json['customer'] == null
        ? null
        : FiscalCustomer.fromJson(
            (json['customer'] as Map).cast<String, dynamic>(),
          ),
    offlineAllowed: json['offlineAllowed'] as bool? ?? true,
  );
}

class FiscalRefundBasis {
  const FiscalRefundBasis({
    required this.originalFiscalSign,
    required this.originalDateTime,
    required this.originalRegistrationNumber,
    required this.originalTotal,
    this.originalWasOffline = false,
  });

  final String originalFiscalSign;
  final DateTime originalDateTime;

  final String originalRegistrationNumber;
  final Decimal originalTotal;
  final bool originalWasOffline;

  Map<String, dynamic> toJson() => {
    'originalFiscalSign': originalFiscalSign,
    'originalDateTime': originalDateTime.toIso8601String(),
    'originalRegistrationNumber': originalRegistrationNumber,
    'originalTotal': originalTotal.toString(),
    'originalWasOffline': originalWasOffline,
  };

  factory FiscalRefundBasis.fromJson(Map<String, dynamic> json) =>
      FiscalRefundBasis(
        originalFiscalSign: json['originalFiscalSign'] as String? ?? '',
        originalDateTime:
            DateTime.tryParse(json['originalDateTime'] as String? ?? '') ??
            DateTime.now(),
        originalRegistrationNumber:
            json['originalRegistrationNumber'] as String? ?? '',
        originalTotal: Decimal.parse((json['originalTotal'] ?? '0').toString()),
        originalWasOffline: json['originalWasOffline'] as bool? ?? false,
      );
}

class FiscalRefundRequest {
  const FiscalRefundRequest({required this.sale, required this.basis});

  final FiscalSaleRequest sale;
  final FiscalRefundBasis basis;

  Map<String, dynamic> toJson() => {
    'sale': sale.toJson(),
    'basis': basis.toJson(),
  };

  factory FiscalRefundRequest.fromJson(Map<String, dynamic> json) =>
      FiscalRefundRequest(
        sale: FiscalSaleRequest.fromJson(
          (json['sale'] as Map).cast<String, dynamic>(),
        ),
        basis: FiscalRefundBasis.fromJson(
          (json['basis'] as Map).cast<String, dynamic>(),
        ),
      );
}

class FiscalMoneyRequest {
  const FiscalMoneyRequest({
    required this.idempotencyKey,
    required this.amount,
    required this.occurredAt,
    this.comment,
  });

  final String idempotencyKey;

  final Decimal amount;
  final DateTime occurredAt;
  final String? comment;

  Map<String, dynamic> toJson() => {
    'idempotencyKey': idempotencyKey,
    'amount': amount.toString(),
    'occurredAt': occurredAt.toIso8601String(),
    if (comment != null) 'comment': comment,
  };

  factory FiscalMoneyRequest.fromJson(Map<String, dynamic> json) =>
      FiscalMoneyRequest(
        idempotencyKey: json['idempotencyKey'] as String? ?? '',
        amount: Decimal.parse((json['amount'] ?? '0').toString()),
        occurredAt:
            DateTime.tryParse(json['occurredAt'] as String? ?? '') ??
            DateTime.now(),
        comment: json['comment'] as String?,
      );
}

class FiscalShiftRequest {
  const FiscalShiftRequest({this.idempotencyKey});

  final String? idempotencyKey;
}

class FiscalCorrectionRequest {
  const FiscalCorrectionRequest({
    required this.idempotencyKey,
    required this.positions,
    required this.payments,
    this.basis,
    this.comment,
  });

  final String idempotencyKey;
  final List<FiscalPosition> positions;
  final List<FiscalPayment> payments;
  final FiscalRefundBasis? basis;
  final String? comment;
}

class FiscalResult {
  const FiscalResult({
    required this.success,
    this.fiscalSign,
    this.registrationNumber,
    this.ticketUrl,
    this.shiftNumber,
    this.documentNumber,
    this.fiscalizedAt,
    this.offlineMode = false,
    this.queued = false,
    this.errorMessage,
    this.errorCode = FiscalErrorCode.ok,
    this.rawErrorCode,
  });

  final bool success;

  final String? fiscalSign;

  final String? registrationNumber;

  final String? ticketUrl;

  final int? shiftNumber;

  final int? documentNumber;

  final DateTime? fiscalizedAt;

  final bool offlineMode;

  final bool queued;

  final String? errorMessage;

  final FiscalErrorCode errorCode;

  final int? rawErrorCode;

  bool get hasFiscalSign => fiscalSign != null && fiscalSign!.isNotEmpty;

  factory FiscalResult.ok({
    required String fiscalSign,
    String? registrationNumber,
    String? ticketUrl,
    int? shiftNumber,
    int? documentNumber,
    DateTime? fiscalizedAt,
    bool offlineMode = false,
  }) => FiscalResult(
    success: true,
    fiscalSign: fiscalSign,
    registrationNumber: registrationNumber,
    ticketUrl: ticketUrl,
    shiftNumber: shiftNumber,
    documentNumber: documentNumber,
    fiscalizedAt: fiscalizedAt,
    offlineMode: offlineMode,
  );

  factory FiscalResult.queued() =>
      const FiscalResult(success: true, queued: true, offlineMode: true);

  factory FiscalResult.failure(
    String message, {
    FiscalErrorCode code = FiscalErrorCode.unknown,
    int? rawErrorCode,
  }) => FiscalResult(
    success: false,
    errorMessage: message,
    errorCode: code,
    rawErrorCode: rawErrorCode,
  );

  factory FiscalResult.notConfigured() => const FiscalResult(
    success: false,
    errorMessage: 'Фискализация не настроена',
    errorCode: FiscalErrorCode.notConfigured,
  );

  factory FiscalResult.unsupported(String op) => FiscalResult(
    success: false,
    errorMessage: 'Операция не поддерживается оператором: $op',
    errorCode: FiscalErrorCode.unsupported,
  );
}

class FiscalReportOperationSummary {
  const FiscalReportOperationSummary({
    required this.count,
    required this.total,
    required this.vat,
  });

  final int count;
  final Decimal total;
  final Decimal vat;
}

class FiscalReportResult {
  const FiscalReportResult({
    required this.result,
    this.shiftNumber,
    this.documentCount = 0,
    this.cashIn,
    this.cashOut,
    this.cashInDrawer,
    this.controlSum,
    this.sell,
    this.saleReturn,
    this.startedAt,
    this.closedAt,
  });

  final FiscalResult result;
  final int? shiftNumber;
  final int documentCount;
  final Decimal? cashIn;
  final Decimal? cashOut;
  final Decimal? cashInDrawer;
  final String? controlSum;
  final FiscalReportOperationSummary? sell;
  final FiscalReportOperationSummary? saleReturn;
  final DateTime? startedAt;
  final DateTime? closedAt;

  bool get success => result.success;

  factory FiscalReportResult.failure(
    String message, {
    FiscalErrorCode code = FiscalErrorCode.unknown,
  }) => FiscalReportResult(result: FiscalResult.failure(message, code: code));
}

class FiscalAuthResult {
  const FiscalAuthResult({
    required this.success,
    this.token,
    this.expiresAt,
    this.error,
    this.errorCode = FiscalErrorCode.ok,
  });

  final bool success;
  final String? token;
  final DateTime? expiresAt;
  final String? error;
  final FiscalErrorCode errorCode;

  factory FiscalAuthResult.ok({String? token, DateTime? expiresAt}) =>
      FiscalAuthResult(success: true, token: token, expiresAt: expiresAt);

  factory FiscalAuthResult.failure(
    String error, {
    FiscalErrorCode code = FiscalErrorCode.unknown,
  }) => FiscalAuthResult(success: false, error: error, errorCode: code);
}

class FiscalStatus {
  const FiscalStatus({
    required this.configured,
    required this.active,
    required this.online,
    this.lastError,
    this.lastErrorAt,
  });

  final bool configured;
  final bool active;
  final bool online;
  final String? lastError;
  final DateTime? lastErrorAt;

  bool get canFiscalize => configured && active;

  factory FiscalStatus.notConfigured() =>
      const FiscalStatus(configured: false, active: false, online: false);
}

class FiscalUnsupported implements Exception {
  const FiscalUnsupported(this.op);

  final String op;

  @override
  String toString() => 'FiscalUnsupported: $op';
}
