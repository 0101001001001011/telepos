import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:telepos/domain/entities/telegram/sync_packet.dart';

part 'exchange_envelope.freezed.dart';
part 'exchange_envelope.g.dart';

@freezed
abstract class ExchangeEnvelope with _$ExchangeEnvelope {
  const factory ExchangeEnvelope({
    required String packetId,

    required String sourceId,

    required String targetId,

    required ExchangeType type,

    required int sequenceNo,

    @Default(1) int totalChunks,

    @Default(0) int chunkIndex,

    required DateTime timestamp,

    required String checksum,

    required String encryptedPayload,

    required String signature,

    @Default(1) int protocolVersion,

    @Default(0) int ttlSeconds,

    @Default(true) bool requiresAck,

    int? telegramMessageId,

    int? telegramChatId,
  }) = _ExchangeEnvelope;

  factory ExchangeEnvelope.fromJson(Map<String, dynamic> json) =>
      _$ExchangeEnvelopeFromJson(json);
}
