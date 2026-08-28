library;

import 'package:decimal/decimal.dart';

enum SntDirection { inbound, outbound }

enum SntOperationType {
  supply,

  movement,

  ownerTransfer,

  supplierReturn,

  importEaeu,

  exportEaeu,
}

enum SntStatus {
  draft,

  queued,

  registered,

  delivered,

  confirmed,

  rejected,

  revoked,

  annulled,

  failed,
}

extension SntStatusX on SntStatus {
  bool get isConfirmed => this == SntStatus.confirmed;

  bool get isTerminal =>
      this == SntStatus.rejected ||
      this == SntStatus.revoked ||
      this == SntStatus.annulled ||
      this == SntStatus.failed;
}

enum SntErrorCode {
  ok,

  notConfigured,

  unsupported,

  authFailed,

  validation,

  network,

  duplicate,

  unknown,
}

class SntParty {
  const SntParty({
    required this.bin,
    this.name,
    this.warehouseCode,
    this.warehouseName,
  });

  final String bin;

  final String? name;

  final String? warehouseCode;
  final String? warehouseName;

  Map<String, dynamic> toJson() => {
    'bin': bin,
    if (name != null) 'name': name,
    if (warehouseCode != null) 'warehouseCode': warehouseCode,
    if (warehouseName != null) 'warehouseName': warehouseName,
  };

  factory SntParty.fromJson(Map<String, dynamic> json) => SntParty(
    bin: json['bin'] as String? ?? '',
    name: json['name'] as String?,
    warehouseCode: json['warehouseCode'] as String?,
    warehouseName: json['warehouseName'] as String?,
  );
}

class SntLine {
  const SntLine({
    required this.productCode,
    required this.name,
    required this.quantity,
    required this.unitCode,
    this.price,
    this.amount,
    this.vat,
    this.ntin,
    this.gtin,
    this.tnved,
    this.isTraceable = false,
    this.markCodes = const [],
    this.originCountry,
  });

  final int productCode;

  final String name;

  final Decimal quantity;

  final int unitCode;

  final Decimal? price;

  final Decimal? amount;

  final Decimal? vat;

  final String? ntin;

  final String? gtin;

  final String? tnved;

  final bool isTraceable;

  final List<String> markCodes;

  final String? originCountry;

  Map<String, dynamic> toJson() => {
    'productCode': productCode,
    'name': name,
    'quantity': quantity.toString(),
    'unitCode': unitCode,
    if (price != null) 'price': price!.toString(),
    if (amount != null) 'amount': amount!.toString(),
    if (vat != null) 'vat': vat!.toString(),
    if (ntin != null) 'ntin': ntin,
    if (gtin != null) 'gtin': gtin,
    if (tnved != null) 'tnved': tnved,
    'isTraceable': isTraceable,
    if (markCodes.isNotEmpty) 'markCodes': markCodes,
    if (originCountry != null) 'originCountry': originCountry,
  };

  factory SntLine.fromJson(Map<String, dynamic> json) => SntLine(
    productCode: json['productCode'] as int? ?? 0,
    name: json['name'] as String? ?? '',
    quantity: Decimal.parse((json['quantity'] ?? '0').toString()),
    unitCode: json['unitCode'] as int? ?? 796,
    price: json['price'] == null
        ? null
        : Decimal.parse(json['price'].toString()),
    amount: json['amount'] == null
        ? null
        : Decimal.parse(json['amount'].toString()),
    vat: json['vat'] == null ? null : Decimal.parse(json['vat'].toString()),
    ntin: json['ntin'] as String?,
    gtin: json['gtin'] as String?,
    tnved: json['tnved'] as String?,
    isTraceable: json['isTraceable'] as bool? ?? false,
    markCodes:
        (json['markCodes'] as List?)?.map((e) => e.toString()).toList() ??
        const [],
    originCountry: json['originCountry'] as String?,
  );
}

class SntDocument {
  SntDocument({
    required this.idempotencyKey,
    required this.direction,
    required this.operationType,
    required this.sender,
    required this.recipient,
    required this.lines,
    required this.occurredAt,
    this.registrationNumber,
    this.localSourceType,
    this.localSourceId,
    this.status = SntStatus.draft,
    this.withTransport = true,
    this.comment,
    this.lastError,
  });

  final String idempotencyKey;

  final SntDirection direction;
  final SntOperationType operationType;

  final SntParty sender;

  final SntParty recipient;

  final List<SntLine> lines;

  final DateTime occurredAt;

  String? registrationNumber;

  final String? localSourceType;
  final int? localSourceId;

  SntStatus status;

  final bool withTransport;

  final String? comment;
  String? lastError;

  bool get hasTraceableGoods => lines.any((l) => l.isTraceable);

  DateTime get actionDeadline => withTransport
      ? occurredAt.add(const Duration(days: 28))
      : occurredAt.add(const Duration(days: 10));

  SntDocument copyWith({
    String? registrationNumber,
    SntStatus? status,
    String? lastError,
  }) {
    return SntDocument(
      idempotencyKey: idempotencyKey,
      direction: direction,
      operationType: operationType,
      sender: sender,
      recipient: recipient,
      lines: lines,
      occurredAt: occurredAt,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      localSourceType: localSourceType,
      localSourceId: localSourceId,
      status: status ?? this.status,
      withTransport: withTransport,
      comment: comment,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() => {
    'idempotencyKey': idempotencyKey,
    'direction': direction.name,
    'operationType': operationType.name,
    'sender': sender.toJson(),
    'recipient': recipient.toJson(),
    'lines': lines.map((l) => l.toJson()).toList(),
    'occurredAt': occurredAt.toIso8601String(),
    if (registrationNumber != null) 'registrationNumber': registrationNumber,
    if (localSourceType != null) 'localSourceType': localSourceType,
    if (localSourceId != null) 'localSourceId': localSourceId,
    'status': status.name,
    'withTransport': withTransport,
    if (comment != null) 'comment': comment,
    if (lastError != null) 'lastError': lastError,
  };

  factory SntDocument.fromJson(Map<String, dynamic> json) => SntDocument(
    idempotencyKey: json['idempotencyKey'] as String? ?? '',
    direction: SntDirection.values.byName(
      json['direction'] as String? ?? 'inbound',
    ),
    operationType: SntOperationType.values.byName(
      json['operationType'] as String? ?? 'supply',
    ),
    sender: SntParty.fromJson(
      (json['sender'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    recipient: SntParty.fromJson(
      (json['recipient'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    lines: (json['lines'] as List? ?? [])
        .map((e) => SntLine.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    occurredAt:
        DateTime.tryParse(json['occurredAt'] as String? ?? '') ??
        DateTime.now(),
    registrationNumber: json['registrationNumber'] as String?,
    localSourceType: json['localSourceType'] as String?,
    localSourceId: json['localSourceId'] as int?,
    status: SntStatus.values.byName(json['status'] as String? ?? 'draft'),
    withTransport: json['withTransport'] as bool? ?? true,
    comment: json['comment'] as String?,
    lastError: json['lastError'] as String?,
  );
}

class SntResult {
  const SntResult({
    required this.success,
    this.status,
    this.registrationNumber,
    this.queued = false,
    this.errorMessage,
    this.errorCode = SntErrorCode.ok,
  });

  final bool success;

  final SntStatus? status;

  final String? registrationNumber;

  final bool queued;

  final String? errorMessage;
  final SntErrorCode errorCode;

  factory SntResult.ok({SntStatus? status, String? registrationNumber}) =>
      SntResult(
        success: true,
        status: status,
        registrationNumber: registrationNumber,
      );

  factory SntResult.queued() =>
      const SntResult(success: true, queued: true, status: SntStatus.queued);

  factory SntResult.unsupported(String op) => SntResult(
    success: false,
    errorMessage:
        'Операция СНТ недоступна (требуется ЭЦП/учётная запись ИС ЭСФ): $op',
    errorCode: SntErrorCode.unsupported,
  );

  factory SntResult.notConfigured() => const SntResult(
    success: false,
    errorMessage: 'СНТ / Виртуальный склад не настроены',
    errorCode: SntErrorCode.notConfigured,
  );

  factory SntResult.failure(
    String message, {
    SntErrorCode code = SntErrorCode.unknown,
  }) => SntResult(success: false, errorMessage: message, errorCode: code);
}

class VirtualWarehouseBalance {
  const VirtualWarehouseBalance({
    required this.productCode,
    required this.name,
    required this.quantity,
    this.unitCode = 796,
    this.warehouseCode,
    this.originCountry,
  });

  final int productCode;
  final String name;

  final Decimal quantity;
  final int unitCode;
  final String? warehouseCode;

  final String? originCountry;

  VirtualWarehouseBalance copyWith({Decimal? quantity}) =>
      VirtualWarehouseBalance(
        productCode: productCode,
        name: name,
        quantity: quantity ?? this.quantity,
        unitCode: unitCode,
        warehouseCode: warehouseCode,
        originCountry: originCountry,
      );

  Map<String, dynamic> toJson() => {
    'productCode': productCode,
    'name': name,
    'quantity': quantity.toString(),
    'unitCode': unitCode,
    if (warehouseCode != null) 'warehouseCode': warehouseCode,
    if (originCountry != null) 'originCountry': originCountry,
  };

  factory VirtualWarehouseBalance.fromJson(Map<String, dynamic> json) =>
      VirtualWarehouseBalance(
        productCode: json['productCode'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        quantity: Decimal.parse((json['quantity'] ?? '0').toString()),
        unitCode: json['unitCode'] as int? ?? 796,
        warehouseCode: json['warehouseCode'] as String?,
        originCountry: json['originCountry'] as String?,
      );
}
