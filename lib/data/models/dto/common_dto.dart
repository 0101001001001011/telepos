library;

class SupplyDto {
  const SupplyDto({
    required this.id,
    required this.posId,
    required this.supplierId,
    required this.amount,
    this.invoiceNo,
    this.status,
    this.userId,
    this.items = const [],
    this.syncState,
    this.createdAt,
  });

  final int id;
  final int posId;
  final int supplierId;
  final String amount;
  final String? invoiceNo;
  final String? status;
  final int? userId;
  final List<SupplyItemDto> items;
  final String? syncState;
  final DateTime? createdAt;

  factory SupplyDto.fromJson(Map<String, dynamic> json) {
    return SupplyDto(
      id: json['id'] as int,
      posId: json['posId'] as int,
      supplierId: json['supplierId'] as int,
      amount: json['amount'] as String,
      invoiceNo: json['invoiceNo'] as String?,
      status: json['status'] as String?,
      userId: json['userId'] as int?,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => SupplyItemDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
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
      'supplierId': supplierId,
      'amount': amount,
      if (invoiceNo != null) 'invoiceNo': invoiceNo,
      if (status != null) 'status': status,
      if (userId != null) 'userId': userId,
      'items': items.map((e) => e.toJson()).toList(),
      if (syncState != null) 'syncState': syncState,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}

class SupplyItemDto {
  const SupplyItemDto({
    required this.productId,
    required this.quantity,
    required this.price,
    required this.amount,
  });

  final int productId;
  final String quantity;
  final String price;
  final String amount;

  factory SupplyItemDto.fromJson(Map<String, dynamic> json) {
    return SupplyItemDto(
      productId: json['productId'] as int,
      quantity: json['quantity'] as String,
      price: json['price'] as String,
      amount: json['amount'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'quantity': quantity,
      'price': price,
      'amount': amount,
    };
  }
}

class UserDto {
  const UserDto({
    required this.id,
    required this.name,
    this.login,
    this.phone,
    this.role,
    this.permissions,
    this.isActive = true,
    this.modifiedAt,
  });

  final int id;
  final String name;
  final String? login;
  final String? phone;
  final String? role;
  final PermissionDto? permissions;
  final bool isActive;
  final DateTime? modifiedAt;

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      id: json['id'] as int,
      name: json['name'] as String,
      login: json['login'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String?,
      permissions: json['permissions'] != null
          ? PermissionDto.fromJson(json['permissions'] as Map<String, dynamic>)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      modifiedAt: json['modifiedAt'] != null
          ? DateTime.parse(json['modifiedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (login != null) 'login': login,
      if (phone != null) 'phone': phone,
      if (role != null) 'role': role,
      if (permissions != null) 'permissions': permissions!.toJson(),
      'isActive': isActive,
      if (modifiedAt != null) 'modifiedAt': modifiedAt!.toIso8601String(),
    };
  }
}

class PermissionDto {
  const PermissionDto({
    this.canSell = true,
    this.canRefund = true,
    this.canOpenShift = true,
    this.canCloseShift = true,
    this.canDiscount = true,
    this.canEditPrice = false,
    this.canCreateProduct = false,
    this.canCreateAgent = false,
    this.canViewReports = false,
    this.canSupply = false,
    this.canInvest = false,
    this.canExpense = false,
    this.maxDiscountPercent,
  });

  final bool canSell;
  final bool canRefund;
  final bool canOpenShift;
  final bool canCloseShift;
  final bool canDiscount;
  final bool canEditPrice;
  final bool canCreateProduct;
  final bool canCreateAgent;
  final bool canViewReports;
  final bool canSupply;
  final bool canInvest;
  final bool canExpense;
  final String? maxDiscountPercent;

  factory PermissionDto.fromJson(Map<String, dynamic> json) {
    return PermissionDto(
      canSell: json['canSell'] as bool? ?? true,
      canRefund: json['canRefund'] as bool? ?? true,
      canOpenShift: json['canOpenShift'] as bool? ?? true,
      canCloseShift: json['canCloseShift'] as bool? ?? true,
      canDiscount: json['canDiscount'] as bool? ?? true,
      canEditPrice: json['canEditPrice'] as bool? ?? false,
      canCreateProduct: json['canCreateProduct'] as bool? ?? false,
      canCreateAgent: json['canCreateAgent'] as bool? ?? false,
      canViewReports: json['canViewReports'] as bool? ?? false,
      canSupply: json['canSupply'] as bool? ?? false,
      canInvest: json['canInvest'] as bool? ?? false,
      canExpense: json['canExpense'] as bool? ?? false,
      maxDiscountPercent: json['maxDiscountPercent'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'canSell': canSell,
      'canRefund': canRefund,
      'canOpenShift': canOpenShift,
      'canCloseShift': canCloseShift,
      'canDiscount': canDiscount,
      'canEditPrice': canEditPrice,
      'canCreateProduct': canCreateProduct,
      'canCreateAgent': canCreateAgent,
      'canViewReports': canViewReports,
      'canSupply': canSupply,
      'canInvest': canInvest,
      'canExpense': canExpense,
      if (maxDiscountPercent != null) 'maxDiscountPercent': maxDiscountPercent,
    };
  }
}

class PosConfigDto {
  const PosConfigDto({
    required this.posId,
    required this.posName,
    this.storeId,
    this.storeName,
    this.priceTypeId,
    this.defaultUserId,
    this.fiscalEnabled = false,
    this.fiscalProvider,
    this.modifiedAt,
  });

  final int posId;
  final String posName;
  final int? storeId;
  final String? storeName;
  final int? priceTypeId;
  final int? defaultUserId;
  final bool fiscalEnabled;
  final String? fiscalProvider;
  final DateTime? modifiedAt;

  factory PosConfigDto.fromJson(Map<String, dynamic> json) {
    return PosConfigDto(
      posId: json['posId'] as int,
      posName: json['posName'] as String,
      storeId: json['storeId'] as int?,
      storeName: json['storeName'] as String?,
      priceTypeId: json['priceTypeId'] as int?,
      defaultUserId: json['defaultUserId'] as int?,
      fiscalEnabled: json['fiscalEnabled'] as bool? ?? false,
      fiscalProvider: json['fiscalProvider'] as String?,
      modifiedAt: json['modifiedAt'] != null
          ? DateTime.parse(json['modifiedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'posId': posId,
      'posName': posName,
      if (storeId != null) 'storeId': storeId,
      if (storeName != null) 'storeName': storeName,
      if (priceTypeId != null) 'priceTypeId': priceTypeId,
      if (defaultUserId != null) 'defaultUserId': defaultUserId,
      'fiscalEnabled': fiscalEnabled,
      if (fiscalProvider != null) 'fiscalProvider': fiscalProvider,
      if (modifiedAt != null) 'modifiedAt': modifiedAt!.toIso8601String(),
    };
  }
}

class PosSettingsDto {
  const PosSettingsDto({
    required this.posId,
    this.printerEnabled = false,
    this.printerAddress,
    this.displayEnabled = false,
    this.displayPort,
    this.scannerEnabled = false,
    this.autoSync = true,
    this.syncIntervalMinutes = 5,
  });

  final int posId;
  final bool printerEnabled;
  final String? printerAddress;
  final bool displayEnabled;
  final String? displayPort;
  final bool scannerEnabled;
  final bool autoSync;
  final int syncIntervalMinutes;

  factory PosSettingsDto.fromJson(Map<String, dynamic> json) {
    return PosSettingsDto(
      posId: json['posId'] as int,
      printerEnabled: json['printerEnabled'] as bool? ?? false,
      printerAddress: json['printerAddress'] as String?,
      displayEnabled: json['displayEnabled'] as bool? ?? false,
      displayPort: json['displayPort'] as String?,
      scannerEnabled: json['scannerEnabled'] as bool? ?? false,
      autoSync: json['autoSync'] as bool? ?? true,
      syncIntervalMinutes: json['syncIntervalMinutes'] as int? ?? 5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'posId': posId,
      'printerEnabled': printerEnabled,
      if (printerAddress != null) 'printerAddress': printerAddress,
      'displayEnabled': displayEnabled,
      if (displayPort != null) 'displayPort': displayPort,
      'scannerEnabled': scannerEnabled,
      'autoSync': autoSync,
      'syncIntervalMinutes': syncIntervalMinutes,
    };
  }
}

class PriceTypeDto {
  const PriceTypeDto({
    required this.id,
    required this.name,
    this.isDefault = false,
    this.sortOrder,
  });

  final int id;
  final String name;
  final bool isDefault;
  final int? sortOrder;

  factory PriceTypeDto.fromJson(Map<String, dynamic> json) {
    return PriceTypeDto(
      id: json['id'] as int,
      name: json['name'] as String,
      isDefault: json['isDefault'] as bool? ?? false,
      sortOrder: json['sortOrder'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isDefault': isDefault,
      if (sortOrder != null) 'sortOrder': sortOrder,
    };
  }
}

class AccountDto {
  const AccountDto({
    required this.id,
    required this.name,
    required this.type,
    this.isDefault = false,
    this.isActive = true,
  });

  final int id;
  final String name;
  final String type;
  final bool isDefault;
  final bool isActive;

  factory AccountDto.fromJson(Map<String, dynamic> json) {
    return AccountDto(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] as String,
      isDefault: json['isDefault'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'isDefault': isDefault,
      'isActive': isActive,
    };
  }
}

class FiscalReceiptDto {
  const FiscalReceiptDto({
    required this.fiscalNo,
    this.fiscalSign,
    this.ticketUrl,
    this.operationType,
    this.createdAt,
  });

  final String fiscalNo;
  final String? fiscalSign;
  final String? ticketUrl;
  final String? operationType;
  final DateTime? createdAt;

  factory FiscalReceiptDto.fromJson(Map<String, dynamic> json) {
    return FiscalReceiptDto(
      fiscalNo: json['fiscalNo'] as String,
      fiscalSign: json['fiscalSign'] as String?,
      ticketUrl: json['ticketUrl'] as String?,
      operationType: json['operationType'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fiscalNo': fiscalNo,
      if (fiscalSign != null) 'fiscalSign': fiscalSign,
      if (ticketUrl != null) 'ticketUrl': ticketUrl,
      if (operationType != null) 'operationType': operationType,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}

class OfdStatusDto {
  const OfdStatusDto({
    required this.isConfigured,
    required this.isConnected,
    this.lastCheckAt,
    this.errorMessage,
  });

  final bool isConfigured;
  final bool isConnected;
  final DateTime? lastCheckAt;
  final String? errorMessage;

  factory OfdStatusDto.fromJson(Map<String, dynamic> json) {
    return OfdStatusDto(
      isConfigured: json['isConfigured'] as bool,
      isConnected: json['isConnected'] as bool,
      lastCheckAt: json['lastCheckAt'] != null
          ? DateTime.parse(json['lastCheckAt'] as String)
          : null,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isConfigured': isConfigured,
      'isConnected': isConnected,
      if (lastCheckAt != null) 'lastCheckAt': lastCheckAt!.toIso8601String(),
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }
}

class SyncStatusDto {
  const SyncStatusDto({
    this.lastSyncAt,
    this.pendingUploads = 0,
    this.isInProgress = false,
    this.currentStep,
    this.progress,
  });

  final DateTime? lastSyncAt;
  final int pendingUploads;
  final bool isInProgress;
  final String? currentStep;
  final double? progress;

  factory SyncStatusDto.fromJson(Map<String, dynamic> json) {
    return SyncStatusDto(
      lastSyncAt: json['lastSyncAt'] != null
          ? DateTime.parse(json['lastSyncAt'] as String)
          : null,
      pendingUploads: json['pendingUploads'] as int? ?? 0,
      isInProgress: json['isInProgress'] as bool? ?? false,
      currentStep: json['currentStep'] as String?,
      progress: (json['progress'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (lastSyncAt != null) 'lastSyncAt': lastSyncAt!.toIso8601String(),
      'pendingUploads': pendingUploads,
      'isInProgress': isInProgress,
      if (currentStep != null) 'currentStep': currentStep,
      if (progress != null) 'progress': progress,
    };
  }
}

class SyncPacketDto {
  const SyncPacketDto({
    required this.type,
    required this.data,
    this.timestamp,
    this.checksum,
  });

  final String type;
  final Map<String, dynamic> data;
  final DateTime? timestamp;
  final String? checksum;

  factory SyncPacketDto.fromJson(Map<String, dynamic> json) {
    return SyncPacketDto(
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
      checksum: json['checksum'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': data,
      if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
      if (checksum != null) 'checksum': checksum,
    };
  }
}
