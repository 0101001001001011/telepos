library;

import 'package:decimal/decimal.dart';

enum EsfDocumentType { basic, corrected, additional }

enum EsfDirection { outgoing, incoming }

enum EsfPartyType { legalEntity, individualEntrepreneur, individual }

enum EsfTaxMode { none, vat }

enum EsfStatus { draft, queued, submitted, delivered, rejected, revoked, error }

enum EsfErrorCode {
  ok,

  notConfigured,

  accountRequired,

  validation,

  signature,

  network,

  rejected,

  unsupported,

  unknown,
}

class EsfParty {
  const EsfParty({
    required this.binIin,
    required this.name,
    this.type = EsfPartyType.legalEntity,
    this.vatSeries,
    this.vatNumber,
    this.address,
  });

  final String binIin;

  final String name;

  final EsfPartyType type;

  final String? vatSeries;

  final String? vatNumber;

  final String? address;

  bool get hasValidBinIin =>
      binIin.length == 12 && int.tryParse(binIin) != null;

  bool get isVatPayer =>
      (vatSeries != null && vatSeries!.isNotEmpty) ||
      (vatNumber != null && vatNumber!.isNotEmpty);

  Map<String, dynamic> toJson() => {
    'binIin': binIin,
    'name': name,
    'type': type.name,
    if (vatSeries != null) 'vatSeries': vatSeries,
    if (vatNumber != null) 'vatNumber': vatNumber,
    if (address != null) 'address': address,
  };

  factory EsfParty.fromJson(Map<String, dynamic> json) => EsfParty(
    binIin: json['binIin'] as String? ?? '',
    name: json['name'] as String? ?? '',
    type: EsfPartyType.values.byName(json['type'] as String? ?? 'legalEntity'),
    vatSeries: json['vatSeries'] as String?,
    vatNumber: json['vatNumber'] as String?,
    address: json['address'] as String?,
  );
}

class EsfTax {
  const EsfTax({
    required this.mode,
    required this.ratePercent,
    required this.amount,
  });

  final EsfTaxMode mode;

  final Decimal ratePercent;

  final Decimal amount;

  factory EsfTax.none() => EsfTax(
    mode: EsfTaxMode.none,
    ratePercent: Decimal.zero,
    amount: Decimal.zero,
  );

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'ratePercent': ratePercent.toString(),
    'amount': amount.toString(),
  };

  factory EsfTax.fromJson(Map<String, dynamic> json) => EsfTax(
    mode: EsfTaxMode.values.byName(json['mode'] as String? ?? 'none'),
    ratePercent: Decimal.parse((json['ratePercent'] ?? '0').toString()),
    amount: Decimal.parse((json['amount'] ?? '0').toString()),
  );
}

class EsfLine {
  const EsfLine({
    required this.lineNumber,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.tax,
    this.discount = _zeroPlaceholder,
    this.unitCode,
    this.ntin,
    this.tnved,
    this.warehouseProductId,
    this.virtualWarehouse = false,
  });

  static const Decimal? _zeroPlaceholder = null;

  final int lineNumber;

  final String name;

  final Decimal quantity;
  final Decimal unitPrice;

  final Decimal lineTotal;

  final EsfTax tax;

  final Decimal? discount;

  final int? unitCode;

  final String? ntin;

  final String? tnved;

  final String? warehouseProductId;

  final bool virtualWarehouse;

  Decimal get discountOr => discount ?? Decimal.zero;

  Decimal get totalWithVat => lineTotal + tax.amount;

  Map<String, dynamic> toJson() => {
    'lineNumber': lineNumber,
    'name': name,
    'quantity': quantity.toString(),
    'unitPrice': unitPrice.toString(),
    'lineTotal': lineTotal.toString(),
    'tax': tax.toJson(),
    'discount': discountOr.toString(),
    if (unitCode != null) 'unitCode': unitCode,
    if (ntin != null) 'ntin': ntin,
    if (tnved != null) 'tnved': tnved,
    if (warehouseProductId != null) 'warehouseProductId': warehouseProductId,
    'virtualWarehouse': virtualWarehouse,
  };

  factory EsfLine.fromJson(Map<String, dynamic> json) => EsfLine(
    lineNumber: json['lineNumber'] as int? ?? 0,
    name: json['name'] as String? ?? '',
    quantity: Decimal.parse((json['quantity'] ?? '0').toString()),
    unitPrice: Decimal.parse((json['unitPrice'] ?? '0').toString()),
    lineTotal: Decimal.parse((json['lineTotal'] ?? '0').toString()),
    tax: EsfTax.fromJson(
      (json['tax'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    discount: Decimal.parse((json['discount'] ?? '0').toString()),
    unitCode: json['unitCode'] as int?,
    ntin: json['ntin'] as String?,
    tnved: json['tnved'] as String?,
    warehouseProductId: json['warehouseProductId'] as String?,
    virtualWarehouse: json['virtualWarehouse'] as bool? ?? false,
  );
}

class EsfVatBucket {
  const EsfVatBucket({
    required this.ratePercent,
    required this.taxableAmount,
    required this.vatAmount,
  });

  final Decimal ratePercent;

  final Decimal taxableAmount;

  final Decimal vatAmount;

  Map<String, dynamic> toJson() => {
    'ratePercent': ratePercent.toString(),
    'taxableAmount': taxableAmount.toString(),
    'vatAmount': vatAmount.toString(),
  };

  factory EsfVatBucket.fromJson(Map<String, dynamic> json) => EsfVatBucket(
    ratePercent: Decimal.parse((json['ratePercent'] ?? '0').toString()),
    taxableAmount: Decimal.parse((json['taxableAmount'] ?? '0').toString()),
    vatAmount: Decimal.parse((json['vatAmount'] ?? '0').toString()),
  );
}

class EsfInvoice {
  const EsfInvoice({
    required this.idempotencyKey,
    required this.accountingNumber,
    required this.direction,
    required this.documentType,
    required this.supplier,
    required this.buyer,
    required this.lines,
    required this.vatBuckets,
    required this.turnoverDate,
    required this.issueDate,
    this.currency = 'KZT',
    this.exchangeRate,
    this.registrationNumber,
    this.sourceSaleReceiptNo,
    this.sourceSalePosId,
    this.sourceSupplyId,
    this.contractNumber,
    this.deliveryConditions,
  });

  final String idempotencyKey;

  final String accountingNumber;

  final EsfDirection direction;

  final EsfDocumentType documentType;

  final EsfParty supplier;

  final EsfParty buyer;

  final List<EsfLine> lines;

  final List<EsfVatBucket> vatBuckets;

  final DateTime turnoverDate;

  final DateTime issueDate;

  final String currency;

  final Decimal? exchangeRate;

  final String? registrationNumber;

  final int? sourceSaleReceiptNo;
  final int? sourceSalePosId;

  final int? sourceSupplyId;

  final String? contractNumber;
  final String? deliveryConditions;

  Decimal get totalTaxable =>
      vatBuckets.fold(Decimal.zero, (s, b) => s + b.taxableAmount);

  Decimal get totalVat =>
      vatBuckets.fold(Decimal.zero, (s, b) => s + b.vatAmount);

  Decimal get totalWithVat => totalTaxable + totalVat;

  bool get isRegistered =>
      registrationNumber != null && registrationNumber!.isNotEmpty;

  EsfInvoice copyWith({
    String? registrationNumber,
    EsfDocumentType? documentType,
  }) => EsfInvoice(
    idempotencyKey: idempotencyKey,
    accountingNumber: accountingNumber,
    direction: direction,
    documentType: documentType ?? this.documentType,
    supplier: supplier,
    buyer: buyer,
    lines: lines,
    vatBuckets: vatBuckets,
    turnoverDate: turnoverDate,
    issueDate: issueDate,
    currency: currency,
    exchangeRate: exchangeRate,
    registrationNumber: registrationNumber ?? this.registrationNumber,
    sourceSaleReceiptNo: sourceSaleReceiptNo,
    sourceSalePosId: sourceSalePosId,
    sourceSupplyId: sourceSupplyId,
    contractNumber: contractNumber,
    deliveryConditions: deliveryConditions,
  );

  Map<String, dynamic> toJson() => {
    'idempotencyKey': idempotencyKey,
    'accountingNumber': accountingNumber,
    'direction': direction.name,
    'documentType': documentType.name,
    'supplier': supplier.toJson(),
    'buyer': buyer.toJson(),
    'lines': lines.map((l) => l.toJson()).toList(),
    'vatBuckets': vatBuckets.map((b) => b.toJson()).toList(),
    'turnoverDate': turnoverDate.toIso8601String(),
    'issueDate': issueDate.toIso8601String(),
    'currency': currency,
    if (exchangeRate != null) 'exchangeRate': exchangeRate.toString(),
    if (registrationNumber != null) 'registrationNumber': registrationNumber,
    if (sourceSaleReceiptNo != null) 'sourceSaleReceiptNo': sourceSaleReceiptNo,
    if (sourceSalePosId != null) 'sourceSalePosId': sourceSalePosId,
    if (sourceSupplyId != null) 'sourceSupplyId': sourceSupplyId,
    if (contractNumber != null) 'contractNumber': contractNumber,
    if (deliveryConditions != null) 'deliveryConditions': deliveryConditions,
  };

  factory EsfInvoice.fromJson(Map<String, dynamic> json) => EsfInvoice(
    idempotencyKey: json['idempotencyKey'] as String? ?? '',
    accountingNumber: json['accountingNumber'] as String? ?? '',
    direction: EsfDirection.values.byName(
      json['direction'] as String? ?? 'outgoing',
    ),
    documentType: EsfDocumentType.values.byName(
      json['documentType'] as String? ?? 'basic',
    ),
    supplier: EsfParty.fromJson(
      (json['supplier'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    buyer: EsfParty.fromJson(
      (json['buyer'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    lines: (json['lines'] as List? ?? [])
        .map((e) => EsfLine.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    vatBuckets: (json['vatBuckets'] as List? ?? [])
        .map((e) => EsfVatBucket.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    turnoverDate:
        DateTime.tryParse(json['turnoverDate'] as String? ?? '') ??
        DateTime.now(),
    issueDate:
        DateTime.tryParse(json['issueDate'] as String? ?? '') ?? DateTime.now(),
    currency: json['currency'] as String? ?? 'KZT',
    exchangeRate: json['exchangeRate'] == null
        ? null
        : Decimal.parse(json['exchangeRate'].toString()),
    registrationNumber: json['registrationNumber'] as String?,
    sourceSaleReceiptNo: json['sourceSaleReceiptNo'] as int?,
    sourceSalePosId: json['sourceSalePosId'] as int?,
    sourceSupplyId: json['sourceSupplyId'] as int?,
    contractNumber: json['contractNumber'] as String?,
    deliveryConditions: json['deliveryConditions'] as String?,
  );
}

class EsfResult {
  const EsfResult({
    required this.success,
    this.status = EsfStatus.draft,
    this.registrationNumber,
    this.queued = false,
    this.errorMessage,
    this.errorCode = EsfErrorCode.ok,
  });

  final bool success;

  final EsfStatus status;

  final String? registrationNumber;

  final bool queued;

  final String? errorMessage;
  final EsfErrorCode errorCode;

  factory EsfResult.queued() =>
      const EsfResult(success: true, status: EsfStatus.queued, queued: true);

  factory EsfResult.delivered(String registrationNumber) => EsfResult(
    success: true,
    status: EsfStatus.delivered,
    registrationNumber: registrationNumber,
  );

  factory EsfResult.notConfigured() => const EsfResult(
    success: false,
    status: EsfStatus.error,
    errorMessage: 'ЭСФ не настроена',
    errorCode: EsfErrorCode.notConfigured,
  );

  factory EsfResult.accountRequired() => const EsfResult(
    success: false,
    status: EsfStatus.error,
    errorMessage:
        'Для выписки ЭСФ требуется ЭЦП НУЦ РК и профиль ИС ЭСФ (account-gated)',
    errorCode: EsfErrorCode.accountRequired,
  );

  factory EsfResult.unsupported(String op) => EsfResult(
    success: false,
    status: EsfStatus.error,
    errorMessage: 'Операция ЭСФ не поддерживается: $op',
    errorCode: EsfErrorCode.unsupported,
  );

  factory EsfResult.failure(
    String message, {
    EsfErrorCode code = EsfErrorCode.unknown,
  }) => EsfResult(
    success: false,
    status: EsfStatus.error,
    errorMessage: message,
    errorCode: code,
  );
}

class EsfProviderStatus {
  const EsfProviderStatus({
    required this.configured,
    required this.canSubmit,
    this.reason,
  });

  final bool configured;

  final bool canSubmit;

  final String? reason;

  factory EsfProviderStatus.notConfigured() => const EsfProviderStatus(
    configured: false,
    canSubmit: false,
    reason: 'ЭСФ не настроена',
  );
}
