library;

class AgentDto {
  const AgentDto({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.inn,
    this.address,
    this.balance,
    this.bonusBalance,
    this.discountPercent,
    this.priceTypeId,
    this.isActive = true,
    this.isSupplier = false,
    this.createdAt,
    this.modifiedAt,
  });

  final int id;
  final String name;
  final String? phone;
  final String? email;
  final String? inn;
  final String? address;
  final String? balance;
  final String? bonusBalance;
  final String? discountPercent;
  final int? priceTypeId;
  final bool isActive;
  final bool isSupplier;
  final DateTime? createdAt;
  final DateTime? modifiedAt;

  factory AgentDto.fromJson(Map<String, dynamic> json) {
    return AgentDto(
      id: json['id'] as int,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      inn: json['inn'] as String?,
      address: json['address'] as String?,
      balance: json['balance'] as String?,
      bonusBalance: json['bonusBalance'] as String?,
      discountPercent: json['discountPercent'] as String?,
      priceTypeId: json['priceTypeId'] as int?,
      isActive: json['isActive'] as bool? ?? true,
      isSupplier: json['isSupplier'] as bool? ?? false,
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
      'id': id,
      'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (inn != null) 'inn': inn,
      if (address != null) 'address': address,
      if (balance != null) 'balance': balance,
      if (bonusBalance != null) 'bonusBalance': bonusBalance,
      if (discountPercent != null) 'discountPercent': discountPercent,
      if (priceTypeId != null) 'priceTypeId': priceTypeId,
      'isActive': isActive,
      'isSupplier': isSupplier,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (modifiedAt != null) 'modifiedAt': modifiedAt!.toIso8601String(),
    };
  }
}

class AgentBalanceDto {
  const AgentBalanceDto({
    required this.agentId,
    required this.balance,
    required this.bonusBalance,
    this.creditLimit,
    this.lastTransactionAt,
  });

  final int agentId;
  final String balance;
  final String bonusBalance;
  final String? creditLimit;
  final DateTime? lastTransactionAt;

  factory AgentBalanceDto.fromJson(Map<String, dynamic> json) {
    return AgentBalanceDto(
      agentId: json['agentId'] as int,
      balance: json['balance'] as String,
      bonusBalance: json['bonusBalance'] as String,
      creditLimit: json['creditLimit'] as String?,
      lastTransactionAt: json['lastTransactionAt'] != null
          ? DateTime.parse(json['lastTransactionAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'agentId': agentId,
      'balance': balance,
      'bonusBalance': bonusBalance,
      if (creditLimit != null) 'creditLimit': creditLimit,
      if (lastTransactionAt != null)
        'lastTransactionAt': lastTransactionAt!.toIso8601String(),
    };
  }
}

class AgentBonusDto {
  const AgentBonusDto({
    required this.id,
    required this.agentId,
    required this.amount,
    required this.type,
    this.saleReceiptNo,
    this.salePosId,
    this.description,
    this.createdAt,
  });

  final int id;
  final int agentId;
  final String amount;
  final String type;
  final int? saleReceiptNo;
  final int? salePosId;
  final String? description;
  final DateTime? createdAt;

  factory AgentBonusDto.fromJson(Map<String, dynamic> json) {
    return AgentBonusDto(
      id: json['id'] as int,
      agentId: json['agentId'] as int,
      amount: json['amount'] as String,
      type: json['type'] as String,
      saleReceiptNo: json['saleReceiptNo'] as int?,
      salePosId: json['salePosId'] as int?,
      description: json['description'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'agentId': agentId,
      'amount': amount,
      'type': type,
      if (saleReceiptNo != null) 'saleReceiptNo': saleReceiptNo,
      if (salePosId != null) 'salePosId': salePosId,
      if (description != null) 'description': description,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}
