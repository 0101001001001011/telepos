library;

enum MarkCisStatus {
  emitted,

  applied,

  inCirculation,

  retired,

  aggregated,

  reserved,

  blocked,

  unknown,
}

enum IsMptDocType {
  acceptance,

  withdrawal,

  aggregation,

  disaggregation,

  transfer,

  remarking,
}

enum IsMptErrorCode {
  ok,

  notConfigured,

  authFailed,

  network,

  rejected,

  unsupported,

  unknown,
}

class MarkCode {
  const MarkCode({
    required this.code,
    this.gtin,
    this.serial,
    this.cisStatus = MarkCisStatus.unknown,
  });

  final String code;

  final String? gtin;

  final String? serial;

  final MarkCisStatus cisStatus;

  Map<String, dynamic> toJson() => {
    'code': code,
    if (gtin != null) 'gtin': gtin,
    if (serial != null) 'serial': serial,
    'cisStatus': cisStatus.name,
  };

  factory MarkCode.fromJson(Map<String, dynamic> json) => MarkCode(
    code: json['code'] as String? ?? '',
    gtin: json['gtin'] as String?,
    serial: json['serial'] as String?,
    cisStatus: MarkCisStatus.values.byName(
      json['cisStatus'] as String? ?? 'unknown',
    ),
  );
}

class MarkVerification {
  const MarkVerification({
    required this.code,
    required this.status,
    this.valid = false,
    this.ownerBin,
    this.productGroup,
    this.message,
  });

  final String code;
  final MarkCisStatus status;

  final bool valid;

  final String? ownerBin;

  final String? productGroup;
  final String? message;

  bool get isInCirculation => status == MarkCisStatus.inCirculation;

  Map<String, dynamic> toJson() => {
    'code': code,
    'status': status.name,
    'valid': valid,
    if (ownerBin != null) 'ownerBin': ownerBin,
    if (productGroup != null) 'productGroup': productGroup,
    if (message != null) 'message': message,
  };

  factory MarkVerification.fromJson(Map<String, dynamic> json) =>
      MarkVerification(
        code: json['code'] as String? ?? '',
        status: MarkCisStatus.values.byName(
          json['status'] as String? ?? 'unknown',
        ),
        valid: json['valid'] as bool? ?? false,
        ownerBin: json['ownerBin'] as String?,
        productGroup: json['productGroup'] as String?,
        message: json['message'] as String?,
      );
}

class IsMptDocRequest {
  const IsMptDocRequest({
    required this.idempotencyKey,
    required this.type,
    required this.codes,
    this.productGroup,
    this.parentCode,
    this.counterpartyBin,
    this.localRef,
    this.occurredAt,
  });

  final String idempotencyKey;
  final IsMptDocType type;

  final List<String> codes;

  final String? productGroup;

  final String? parentCode;

  final String? counterpartyBin;

  final int? localRef;

  final DateTime? occurredAt;

  Map<String, dynamic> toJson() => {
    'idempotencyKey': idempotencyKey,
    'type': type.name,
    'codes': codes,
    if (productGroup != null) 'productGroup': productGroup,
    if (parentCode != null) 'parentCode': parentCode,
    if (counterpartyBin != null) 'counterpartyBin': counterpartyBin,
    if (localRef != null) 'localRef': localRef,
    if (occurredAt != null) 'occurredAt': occurredAt!.toIso8601String(),
  };

  factory IsMptDocRequest.fromJson(
    Map<String, dynamic> json,
  ) => IsMptDocRequest(
    idempotencyKey: json['idempotencyKey'] as String? ?? '',
    type: IsMptDocType.values.byName(json['type'] as String? ?? 'acceptance'),
    codes:
        (json['codes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    productGroup: json['productGroup'] as String?,
    parentCode: json['parentCode'] as String?,
    counterpartyBin: json['counterpartyBin'] as String?,
    localRef: json['localRef'] as int?,
    occurredAt: json['occurredAt'] == null
        ? null
        : DateTime.tryParse(json['occurredAt'] as String),
  );
}

class IsMptResult {
  const IsMptResult({
    required this.success,
    this.documentId,
    this.queued = false,
    this.errorMessage,
    this.errorCode = IsMptErrorCode.ok,
  });

  final bool success;

  final String? documentId;

  final bool queued;

  final String? errorMessage;
  final IsMptErrorCode errorCode;

  factory IsMptResult.ok({String? documentId}) =>
      IsMptResult(success: true, documentId: documentId);

  factory IsMptResult.queued() =>
      const IsMptResult(success: true, queued: true);

  factory IsMptResult.failure(
    String message, {
    IsMptErrorCode code = IsMptErrorCode.unknown,
  }) => IsMptResult(success: false, errorMessage: message, errorCode: code);

  factory IsMptResult.unsupported(String op) => IsMptResult(
    success: false,
    errorMessage: 'Операция ИС МПТ не поддерживается провайдером: $op',
    errorCode: IsMptErrorCode.unsupported,
  );

  factory IsMptResult.notConfigured() => const IsMptResult(
    success: false,
    errorMessage: 'ИС МПТ не настроена (нужны ЭЦП и доступ к ЛК ismet.kz)',
    errorCode: IsMptErrorCode.notConfigured,
  );
}

class IsMptVerifyResult {
  const IsMptVerifyResult({
    required this.success,
    this.verifications = const [],
    this.queued = false,
    this.errorMessage,
    this.errorCode = IsMptErrorCode.ok,
  });

  final bool success;
  final List<MarkVerification> verifications;

  final bool queued;
  final String? errorMessage;
  final IsMptErrorCode errorCode;

  factory IsMptVerifyResult.ok(List<MarkVerification> v) =>
      IsMptVerifyResult(success: true, verifications: v);

  factory IsMptVerifyResult.failure(
    String message, {
    IsMptErrorCode code = IsMptErrorCode.unknown,
  }) =>
      IsMptVerifyResult(success: false, errorMessage: message, errorCode: code);

  factory IsMptVerifyResult.unsupported() => const IsMptVerifyResult(
    success: false,
    errorMessage: 'Проверка статуса КМ недоступна (ИС МПТ не настроена)',
    errorCode: IsMptErrorCode.unsupported,
  );
}

class IsMptStatus {
  const IsMptStatus({
    required this.configured,
    required this.online,
    this.lastError,
  });

  final bool configured;
  final bool online;
  final String? lastError;

  factory IsMptStatus.notConfigured() =>
      const IsMptStatus(configured: false, online: false);
}
