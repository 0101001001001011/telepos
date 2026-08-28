import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_packet.freezed.dart';
part 'sync_packet.g.dart';

enum ExchangeType {
  product,
  sale,
  refund,
  shift,
  agent,
  price,
  supply,
  config,
  fiscal,
  fullSync,
  heartbeat,
  acknowledgment,
}

enum SyncPacketStatus {
  pending,
  sending,
  sent,
  delivered,
  acknowledged,
  failed,
  expired,
}

@freezed
abstract class SyncPacket with _$SyncPacket {
  const factory SyncPacket({
    required String packetId,

    required ExchangeType exchangeType,

    required String sourceId,

    required String targetId,

    required int sequenceNo,

    required String payload,

    required int payloadSize,

    required String checksum,

    @Default(SyncPacketStatus.pending) SyncPacketStatus status,

    required DateTime createdAt,

    DateTime? sentAt,

    DateTime? deliveredAt,

    DateTime? acknowledgedAt,

    @Default(0) int retryCount,

    @Default(5) int maxRetries,

    @Default(false) bool isCompressed,

    @Default(false) bool isEncrypted,

    String? errorMessage,
  }) = _SyncPacket;

  factory SyncPacket.fromJson(Map<String, dynamic> json) =>
      _$SyncPacketFromJson(json);
}
