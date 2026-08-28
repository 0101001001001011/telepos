import 'package:decimal/decimal.dart';

class AgentEntity {
  const AgentEntity({
    this.localId,
    this.serverId,
    this.type,
    this.storeId,
    this.name,
    this.phone,
    this.bin,
    this.legalType,
    this.legalAddress,
    this.actualAddress,
    this.note,
    this.legalName,
    this.isDeleted = false,
    this.editTime,
    this.serverEditTime,
    this.mainAccountId,
    this.cashbackAccountId,
    this.state,
    this.supportsOnlineOrder = false,
    this.onlineOrderApiUrl,
    this.onlineOrderApiKey,
    this.orderEmail,
    this.minOrderAmount,
    this.deliveryDays,
  });

  final int? localId;

  final int? serverId;

  final int? type;

  final int? storeId;

  final String? name;

  final int? phone;

  final String? bin;

  final String? legalType;

  final String? legalAddress;

  final String? actualAddress;

  final String? note;

  final String? legalName;

  final bool isDeleted;

  final int? editTime;

  final int? serverEditTime;

  final int? mainAccountId;

  final int? cashbackAccountId;

  final int? state;

  final bool supportsOnlineOrder;

  final String? onlineOrderApiUrl;

  final String? onlineOrderApiKey;

  final String? orderEmail;

  final Decimal? minOrderAmount;

  final int? deliveryDays;

  bool get isSupplier => type == 0;

  bool get isCustomer => type == 1;

  bool get isOwner => type == 2;

  String get displayName => name ?? 'Agent #${localId ?? serverId ?? 0}';

  AgentEntity copyWith({
    int? localId,
    int? serverId,
    int? type,
    int? storeId,
    String? name,
    int? phone,
    String? bin,
    String? legalType,
    String? legalAddress,
    String? actualAddress,
    String? note,
    String? legalName,
    bool? isDeleted,
    int? editTime,
    int? serverEditTime,
    int? mainAccountId,
    int? cashbackAccountId,
    int? state,
    bool? supportsOnlineOrder,
    String? onlineOrderApiUrl,
    String? onlineOrderApiKey,
    String? orderEmail,
    Decimal? minOrderAmount,
    int? deliveryDays,
  }) {
    return AgentEntity(
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      type: type ?? this.type,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      bin: bin ?? this.bin,
      legalType: legalType ?? this.legalType,
      legalAddress: legalAddress ?? this.legalAddress,
      actualAddress: actualAddress ?? this.actualAddress,
      note: note ?? this.note,
      legalName: legalName ?? this.legalName,
      isDeleted: isDeleted ?? this.isDeleted,
      editTime: editTime ?? this.editTime,
      serverEditTime: serverEditTime ?? this.serverEditTime,
      mainAccountId: mainAccountId ?? this.mainAccountId,
      cashbackAccountId: cashbackAccountId ?? this.cashbackAccountId,
      state: state ?? this.state,
      supportsOnlineOrder: supportsOnlineOrder ?? this.supportsOnlineOrder,
      onlineOrderApiUrl: onlineOrderApiUrl ?? this.onlineOrderApiUrl,
      onlineOrderApiKey: onlineOrderApiKey ?? this.onlineOrderApiKey,
      orderEmail: orderEmail ?? this.orderEmail,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      deliveryDays: deliveryDays ?? this.deliveryDays,
    );
  }
}
