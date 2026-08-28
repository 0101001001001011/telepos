import '../models/dto/dto.dart';

extension ProductDtoMapper on ProductDto {
  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'categoryId': categoryId,
      'price': price,
      'costPrice': costPrice,
      'quantity': quantity,
      'unit': unit,
      'vatRate': vatRate,
      'isActive': isActive ? 1 : 0,
      'isMarked': isMarked ? 1 : 0,
      'createdAt': createdAt?.toIso8601String(),
      'modifiedAt': modifiedAt?.toIso8601String(),
    };
  }

  static ProductDto fromDbMap(Map<String, dynamic> map) {
    return ProductDto(
      id: map['id'] as int,
      name: map['name'] as String,
      barcode: map['barcode'] as String?,
      categoryId: map['categoryId'] as int?,
      price: map['price'] as String?,
      costPrice: map['costPrice'] as String?,
      quantity: map['quantity'] as String?,
      unit: map['unit'] as String?,
      vatRate: map['vatRate'] as String?,
      isActive: (map['isActive'] as int?) == 1,
      isMarked: (map['isMarked'] as int?) == 1,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
      modifiedAt: map['modifiedAt'] != null
          ? DateTime.parse(map['modifiedAt'] as String)
          : null,
    );
  }
}

extension CategoryDtoMapper on CategoryDto {
  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'name': name,
      'parentId': parentId,
      'sortOrder': sortOrder,
      'isActive': isActive ? 1 : 0,
    };
  }
}

extension SaleDtoMapper on SaleDto {
  Map<String, dynamic> toDbMap() {
    return {
      'receiptNo': receiptNo,
      'posId': posId,
      'shiftId': shiftId,
      'amount': amount,
      'discount': discount,
      'cashAmount': cashAmount,
      'cardAmount': cardAmount,
      'agentId': agentId,
      'userId': userId,
      'fiscalNo': fiscalNo,
      'syncState': syncState,
      'createdAt': createdAt?.toIso8601String(),
      'modifiedAt': modifiedAt?.toIso8601String(),
    };
  }

  static SaleDto fromDbMap(Map<String, dynamic> map) {
    return SaleDto(
      receiptNo: map['receiptNo'] as int,
      posId: map['posId'] as int,
      shiftId: map['shiftId'] as int,
      amount: map['amount'] as String,
      discount: map['discount'] as String?,
      cashAmount: map['cashAmount'] as String?,
      cardAmount: map['cardAmount'] as String?,
      agentId: map['agentId'] as int?,
      userId: map['userId'] as int?,
      fiscalNo: map['fiscalNo'] as String?,
      syncState: map['syncState'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
      modifiedAt: map['modifiedAt'] != null
          ? DateTime.parse(map['modifiedAt'] as String)
          : null,
    );
  }
}

extension SaleItemDtoMapper on SaleItemDto {
  Map<String, dynamic> toDbMap(int receiptNo, int posId) {
    return {
      'receiptNo': receiptNo,
      'posId': posId,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
      'amount': amount,
      'discount': discount,
      'vatAmount': vatAmount,
      'barcode': barcode,
      'mark': mark,
    };
  }
}

extension RefundDtoMapper on RefundDto {
  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'posId': posId,
      'shiftId': shiftId,
      'amount': amount,
      'originalReceiptNo': originalReceiptNo,
      'originalPosId': originalPosId,
      'reason': reason,
      'agentId': agentId,
      'userId': userId,
      'fiscalNo': fiscalNo,
      'syncState': syncState,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

extension AgentDtoMapper on AgentDto {
  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'inn': inn,
      'address': address,
      'balance': balance,
      'bonusBalance': bonusBalance,
      'discountPercent': discountPercent,
      'priceTypeId': priceTypeId,
      'isActive': isActive ? 1 : 0,
      'isSupplier': isSupplier ? 1 : 0,
      'createdAt': createdAt?.toIso8601String(),
      'modifiedAt': modifiedAt?.toIso8601String(),
    };
  }

  static AgentDto fromDbMap(Map<String, dynamic> map) {
    return AgentDto(
      id: map['id'] as int,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      inn: map['inn'] as String?,
      address: map['address'] as String?,
      balance: map['balance'] as String?,
      bonusBalance: map['bonusBalance'] as String?,
      discountPercent: map['discountPercent'] as String?,
      priceTypeId: map['priceTypeId'] as int?,
      isActive: (map['isActive'] as int?) == 1,
      isSupplier: (map['isSupplier'] as int?) == 1,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
      modifiedAt: map['modifiedAt'] != null
          ? DateTime.parse(map['modifiedAt'] as String)
          : null,
    );
  }
}

extension ShiftDtoMapper on ShiftDto {
  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'posId': posId,
      'userId': userId,
      'status': status,
      'openedAt': openedAt?.toIso8601String(),
      'closedAt': closedAt?.toIso8601String(),
      'openingCash': openingCash,
      'closingCash': closingCash,
      'salesCount': salesCount,
      'salesAmount': salesAmount,
      'refundsCount': refundsCount,
      'refundsAmount': refundsAmount,
      'syncState': syncState,
    };
  }

  static ShiftDto fromDbMap(Map<String, dynamic> map) {
    return ShiftDto(
      id: map['id'] as int,
      posId: map['posId'] as int,
      userId: map['userId'] as int,
      status: map['status'] as String,
      openedAt: map['openedAt'] != null
          ? DateTime.parse(map['openedAt'] as String)
          : null,
      closedAt: map['closedAt'] != null
          ? DateTime.parse(map['closedAt'] as String)
          : null,
      openingCash: map['openingCash'] as String?,
      closingCash: map['closingCash'] as String?,
      salesCount: map['salesCount'] as int?,
      salesAmount: map['salesAmount'] as String?,
      refundsCount: map['refundsCount'] as int?,
      refundsAmount: map['refundsAmount'] as String?,
      syncState: map['syncState'] as String?,
    );
  }
}

extension SupplyDtoMapper on SupplyDto {
  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'posId': posId,
      'supplierId': supplierId,
      'amount': amount,
      'invoiceNo': invoiceNo,
      'status': status,
      'userId': userId,
      'syncState': syncState,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

extension UserDtoMapper on UserDto {
  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'name': name,
      'login': login,
      'phone': phone,
      'role': role,
      'isActive': isActive ? 1 : 0,
      'modifiedAt': modifiedAt?.toIso8601String(),
    };
  }

  static UserDto fromDbMap(Map<String, dynamic> map) {
    return UserDto(
      id: map['id'] as int,
      name: map['name'] as String,
      login: map['login'] as String?,
      phone: map['phone'] as String?,
      role: map['role'] as String?,
      isActive: (map['isActive'] as int?) == 1,
      modifiedAt: map['modifiedAt'] != null
          ? DateTime.parse(map['modifiedAt'] as String)
          : null,
    );
  }
}

extension PosConfigDtoMapper on PosConfigDto {
  Map<String, dynamic> toDbMap() {
    return {
      'posId': posId,
      'posName': posName,
      'storeId': storeId,
      'storeName': storeName,
      'priceTypeId': priceTypeId,
      'defaultUserId': defaultUserId,
      'fiscalEnabled': fiscalEnabled ? 1 : 0,
      'fiscalProvider': fiscalProvider,
      'modifiedAt': modifiedAt?.toIso8601String(),
    };
  }
}

extension FiscalReceiptDtoMapper on FiscalReceiptDto {
  Map<String, dynamic> toDbMap() {
    return {
      'fiscalNo': fiscalNo,
      'fiscalSign': fiscalSign,
      'ticketUrl': ticketUrl,
      'operationType': operationType,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

extension SalePaymentDtoMapper on SalePaymentDto {
  Map<String, dynamic> toDbMap(int receiptNo, int posId) {
    return {
      'receiptNo': receiptNo,
      'posId': posId,
      'type': type,
      'amount': amount,
      'accountId': accountId,
      'reference': reference,
    };
  }
}

extension ProductPriceDtoMapper on ProductPriceDto {
  Map<String, dynamic> toDbMap() {
    return {
      'productId': productId,
      'priceTypeId': priceTypeId,
      'price': price,
      'minPrice': minPrice,
      'modifiedAt': modifiedAt?.toIso8601String(),
    };
  }

  static ProductPriceDto fromDbMap(Map<String, dynamic> map) {
    return ProductPriceDto(
      productId: map['productId'] as int,
      priceTypeId: map['priceTypeId'] as int,
      price: map['price'] as String,
      minPrice: map['minPrice'] as String?,
      modifiedAt: map['modifiedAt'] != null
          ? DateTime.parse(map['modifiedAt'] as String)
          : null,
    );
  }
}
