library;

class SaleDto {
  const SaleDto({
    required this.receiptNo,
    required this.posId,
    required this.shiftId,
    required this.amount,
    this.discount,
    this.cashAmount,
    this.cardAmount,
    this.agentId,
    this.userId,
    this.items = const [],
    this.payments = const [],
    this.fiscalNo,
    this.syncState,
    this.createdAt,
    this.modifiedAt,
  });

  final int receiptNo;
  final int posId;
  final int shiftId;
  final String amount;
  final String? discount;
  final String? cashAmount;
  final String? cardAmount;
  final int? agentId;
  final int? userId;
  final List<SaleItemDto> items;
  final List<SalePaymentDto> payments;
  final String? fiscalNo;
  final String? syncState;
  final DateTime? createdAt;
  final DateTime? modifiedAt;

  factory SaleDto.fromJson(Map<String, dynamic> json) {
    return SaleDto(
      receiptNo: json['receiptNo'] as int,
      posId: json['posId'] as int,
      shiftId: json['shiftId'] as int,
      amount: json['amount'] as String,
      discount: json['discount'] as String?,
      cashAmount: json['cashAmount'] as String?,
      cardAmount: json['cardAmount'] as String?,
      agentId: json['agentId'] as int?,
      userId: json['userId'] as int?,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => SaleItemDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      payments:
          (json['payments'] as List<dynamic>?)
              ?.map((e) => SalePaymentDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      fiscalNo: json['fiscalNo'] as String?,
      syncState: json['syncState'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      modifiedAt: json['modifiedAt'] != null
          ? DateTime.parse(json['modifiedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'receiptNo': receiptNo,
      'posId': posId,
      'shiftId': shiftId,
      'amount': amount,
      if (discount != null) 'discount': discount,
      if (cashAmount != null) 'cashAmount': cashAmount,
      if (cardAmount != null) 'cardAmount': cardAmount,
      if (agentId != null) 'agentId': agentId,
      if (userId != null) 'userId': userId,
      'items': items.map((e) => e.toJson()).toList(),
      'payments': payments.map((e) => e.toJson()).toList(),
      if (fiscalNo != null) 'fiscalNo': fiscalNo,
      if (syncState != null) 'syncState': syncState,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (modifiedAt != null) 'modifiedAt': modifiedAt!.toIso8601String(),
    };
  }
}

class SaleItemDto {
  const SaleItemDto({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.amount,
    this.discount,
    this.vatAmount,
    this.barcode,
    this.mark,
  });

  final int productId;
  final String productName;
  final String quantity;
  final String price;
  final String amount;
  final String? discount;
  final String? vatAmount;
  final String? barcode;
  final String? mark;

  factory SaleItemDto.fromJson(Map<String, dynamic> json) {
    return SaleItemDto(
      productId: json['productId'] as int,
      productName: json['productName'] as String,
      quantity: json['quantity'] as String,
      price: json['price'] as String,
      amount: json['amount'] as String,
      discount: json['discount'] as String?,
      vatAmount: json['vatAmount'] as String?,
      barcode: json['barcode'] as String?,
      mark: json['mark'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
      'amount': amount,
      if (discount != null) 'discount': discount,
      if (vatAmount != null) 'vatAmount': vatAmount,
      if (barcode != null) 'barcode': barcode,
      if (mark != null) 'mark': mark,
    };
  }
}

class SalePaymentDto {
  const SalePaymentDto({
    required this.type,
    required this.amount,
    this.accountId,
    this.reference,
  });

  final String type;
  final String amount;
  final int? accountId;
  final String? reference;

  factory SalePaymentDto.fromJson(Map<String, dynamic> json) {
    return SalePaymentDto(
      type: json['type'] as String,
      amount: json['amount'] as String,
      accountId: json['accountId'] as int?,
      reference: json['reference'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'amount': amount,
      if (accountId != null) 'accountId': accountId,
      if (reference != null) 'reference': reference,
    };
  }
}

class RefundDto {
  const RefundDto({
    required this.id,
    required this.posId,
    required this.shiftId,
    required this.amount,
    this.originalReceiptNo,
    this.originalPosId,
    this.reason,
    this.agentId,
    this.userId,
    this.items = const [],
    this.fiscalNo,
    this.syncState,
    this.createdAt,
  });

  final int id;
  final int posId;
  final int shiftId;
  final String amount;
  final int? originalReceiptNo;
  final int? originalPosId;
  final String? reason;
  final int? agentId;
  final int? userId;
  final List<RefundItemDto> items;
  final String? fiscalNo;
  final String? syncState;
  final DateTime? createdAt;

  factory RefundDto.fromJson(Map<String, dynamic> json) {
    return RefundDto(
      id: json['id'] as int,
      posId: json['posId'] as int,
      shiftId: json['shiftId'] as int,
      amount: json['amount'] as String,
      originalReceiptNo: json['originalReceiptNo'] as int?,
      originalPosId: json['originalPosId'] as int?,
      reason: json['reason'] as String?,
      agentId: json['agentId'] as int?,
      userId: json['userId'] as int?,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => RefundItemDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      fiscalNo: json['fiscalNo'] as String?,
      syncState: json['syncState'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'posId': posId,
      'shiftId': shiftId,
      'amount': amount,
      if (originalReceiptNo != null) 'originalReceiptNo': originalReceiptNo,
      if (originalPosId != null) 'originalPosId': originalPosId,
      if (reason != null) 'reason': reason,
      if (agentId != null) 'agentId': agentId,
      if (userId != null) 'userId': userId,
      'items': items.map((e) => e.toJson()).toList(),
      if (fiscalNo != null) 'fiscalNo': fiscalNo,
      if (syncState != null) 'syncState': syncState,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}

class RefundItemDto {
  const RefundItemDto({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.amount,
    this.mark,
  });

  final int productId;
  final String productName;
  final String quantity;
  final String price;
  final String amount;
  final String? mark;

  factory RefundItemDto.fromJson(Map<String, dynamic> json) {
    return RefundItemDto(
      productId: json['productId'] as int,
      productName: json['productName'] as String,
      quantity: json['quantity'] as String,
      price: json['price'] as String,
      amount: json['amount'] as String,
      mark: json['mark'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
      'amount': amount,
      if (mark != null) 'mark': mark,
    };
  }
}
