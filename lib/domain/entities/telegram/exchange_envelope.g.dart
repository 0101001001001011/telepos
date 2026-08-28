// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exchange_envelope.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ExchangeEnvelope _$ExchangeEnvelopeFromJson(Map<String, dynamic> json) =>
    _ExchangeEnvelope(
      packetId: json['packetId'] as String,
      sourceId: json['sourceId'] as String,
      targetId: json['targetId'] as String,
      type: $enumDecode(_$ExchangeTypeEnumMap, json['type']),
      sequenceNo: (json['sequenceNo'] as num).toInt(),
      totalChunks: (json['totalChunks'] as num?)?.toInt() ?? 1,
      chunkIndex: (json['chunkIndex'] as num?)?.toInt() ?? 0,
      timestamp: DateTime.parse(json['timestamp'] as String),
      checksum: json['checksum'] as String,
      encryptedPayload: json['encryptedPayload'] as String,
      signature: json['signature'] as String,
      protocolVersion: (json['protocolVersion'] as num?)?.toInt() ?? 1,
      ttlSeconds: (json['ttlSeconds'] as num?)?.toInt() ?? 0,
      requiresAck: json['requiresAck'] as bool? ?? true,
      telegramMessageId: (json['telegramMessageId'] as num?)?.toInt(),
      telegramChatId: (json['telegramChatId'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ExchangeEnvelopeToJson(_ExchangeEnvelope instance) =>
    <String, dynamic>{
      'packetId': instance.packetId,
      'sourceId': instance.sourceId,
      'targetId': instance.targetId,
      'type': _$ExchangeTypeEnumMap[instance.type]!,
      'sequenceNo': instance.sequenceNo,
      'totalChunks': instance.totalChunks,
      'chunkIndex': instance.chunkIndex,
      'timestamp': instance.timestamp.toIso8601String(),
      'checksum': instance.checksum,
      'encryptedPayload': instance.encryptedPayload,
      'signature': instance.signature,
      'protocolVersion': instance.protocolVersion,
      'ttlSeconds': instance.ttlSeconds,
      'requiresAck': instance.requiresAck,
      'telegramMessageId': instance.telegramMessageId,
      'telegramChatId': instance.telegramChatId,
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
