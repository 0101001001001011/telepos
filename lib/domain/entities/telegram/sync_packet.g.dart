// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_packet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SyncPacket _$SyncPacketFromJson(Map<String, dynamic> json) => _SyncPacket(
  packetId: json['packetId'] as String,
  exchangeType: $enumDecode(_$ExchangeTypeEnumMap, json['exchangeType']),
  sourceId: json['sourceId'] as String,
  targetId: json['targetId'] as String,
  sequenceNo: (json['sequenceNo'] as num).toInt(),
  payload: json['payload'] as String,
  payloadSize: (json['payloadSize'] as num).toInt(),
  checksum: json['checksum'] as String,
  status:
      $enumDecodeNullable(_$SyncPacketStatusEnumMap, json['status']) ??
      SyncPacketStatus.pending,
  createdAt: DateTime.parse(json['createdAt'] as String),
  sentAt: json['sentAt'] == null
      ? null
      : DateTime.parse(json['sentAt'] as String),
  deliveredAt: json['deliveredAt'] == null
      ? null
      : DateTime.parse(json['deliveredAt'] as String),
  acknowledgedAt: json['acknowledgedAt'] == null
      ? null
      : DateTime.parse(json['acknowledgedAt'] as String),
  retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
  maxRetries: (json['maxRetries'] as num?)?.toInt() ?? 5,
  isCompressed: json['isCompressed'] as bool? ?? false,
  isEncrypted: json['isEncrypted'] as bool? ?? false,
  errorMessage: json['errorMessage'] as String?,
);

Map<String, dynamic> _$SyncPacketToJson(_SyncPacket instance) =>
    <String, dynamic>{
      'packetId': instance.packetId,
      'exchangeType': _$ExchangeTypeEnumMap[instance.exchangeType]!,
      'sourceId': instance.sourceId,
      'targetId': instance.targetId,
      'sequenceNo': instance.sequenceNo,
      'payload': instance.payload,
      'payloadSize': instance.payloadSize,
      'checksum': instance.checksum,
      'status': _$SyncPacketStatusEnumMap[instance.status]!,
      'createdAt': instance.createdAt.toIso8601String(),
      'sentAt': instance.sentAt?.toIso8601String(),
      'deliveredAt': instance.deliveredAt?.toIso8601String(),
      'acknowledgedAt': instance.acknowledgedAt?.toIso8601String(),
      'retryCount': instance.retryCount,
      'maxRetries': instance.maxRetries,
      'isCompressed': instance.isCompressed,
      'isEncrypted': instance.isEncrypted,
      'errorMessage': instance.errorMessage,
    };

const _$ExchangeTypeEnumMap = {
  ExchangeType.product: 'product',
  ExchangeType.sale: 'sale',
  ExchangeType.refund: 'refund',
  ExchangeType.shift: 'shift',
  ExchangeType.agent: 'agent',
  ExchangeType.price: 'price',
  ExchangeType.supply: 'supply',
  ExchangeType.config: 'config',
  ExchangeType.fiscal: 'fiscal',
  ExchangeType.fullSync: 'fullSync',
  ExchangeType.heartbeat: 'heartbeat',
  ExchangeType.acknowledgment: 'acknowledgment',
};

const _$SyncPacketStatusEnumMap = {
  SyncPacketStatus.pending: 'pending',
  SyncPacketStatus.sending: 'sending',
  SyncPacketStatus.sent: 'sent',
  SyncPacketStatus.delivered: 'delivered',
  SyncPacketStatus.acknowledged: 'acknowledged',
  SyncPacketStatus.failed: 'failed',
  SyncPacketStatus.expired: 'expired',
};
