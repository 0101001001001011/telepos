import 'dart:async';
import 'dart:math';

import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/messaging/message_service.dart';
import 'package:telepos/domain/entities/telegram/exchange_envelope.dart';
import 'package:telepos/domain/entities/telegram/sync_packet.dart';

class ChunkTransferService {
  final MessageService _messageService;
  final TdLibLogger _logger;

  static const maxChunkSize = 3500;

  ChunkTransferService({
    required MessageService messageService,
    required TdLibLogger logger,
  }) : _messageService = messageService,
       _logger = logger;

  List<String> splitIntoChunks(String data) {
    if (data.length <= maxChunkSize) {
      return [data];
    }

    final chunks = <String>[];
    for (var i = 0; i < data.length; i += maxChunkSize) {
      chunks.add(data.substring(i, min(i + maxChunkSize, data.length)));
    }

    _logger.logSync(
      'Data split into ${chunks.length} chunks '
      '(total: ${data.length} chars)',
    );

    return chunks;
  }

  Future<List<ExchangeEnvelope>> sendChunked({
    required int chatId,
    required String packetId,
    required String sourceId,
    required String targetId,
    required ExchangeType type,
    required String encryptedPayload,
    required String checksum,
    required String signature,
    required int sequenceNo,
  }) async {
    final chunks = splitIntoChunks(encryptedPayload);
    final envelopes = <ExchangeEnvelope>[];

    for (var i = 0; i < chunks.length; i++) {
      final envelope = ExchangeEnvelope(
        packetId: packetId,
        sourceId: sourceId,
        targetId: targetId,
        type: type,
        sequenceNo: sequenceNo,
        totalChunks: chunks.length,
        chunkIndex: i,
        timestamp: DateTime.now(),
        checksum: checksum,
        encryptedPayload: chunks[i],
        signature: signature,
      );

      final messageText = '__TELEPOS_DATA__:${_serializeEnvelope(envelope)}';
      await _messageService.sendSilent(chatId, messageText);

      envelopes.add(envelope);

      _logger.logSync(
        'Chunk ${i + 1}/${chunks.length} sent',
        packetId: packetId,
      );

      if (i < chunks.length - 1) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    return envelopes;
  }

  String? assembleChunks(List<ExchangeEnvelope> chunks) {
    if (chunks.isEmpty) return null;

    final totalChunks = chunks.first.totalChunks;
    if (chunks.length != totalChunks) {
      _logger.logError(
        'assembleChunks',
        'Incomplete: ${chunks.length}/$totalChunks chunks',
      );
      return null;
    }

    chunks.sort((a, b) => a.chunkIndex.compareTo(b.chunkIndex));

    for (var i = 0; i < totalChunks; i++) {
      if (chunks[i].chunkIndex != i) {
        _logger.logError('assembleChunks', 'Missing chunk index: $i');
        return null;
      }
    }

    final assembled = chunks.map((c) => c.encryptedPayload).join();
    _logger.logSync(
      'Assembled $totalChunks chunks (${assembled.length} chars)',
      packetId: chunks.first.packetId,
    );

    return assembled;
  }

  bool isComplete(List<ExchangeEnvelope> receivedChunks) {
    if (receivedChunks.isEmpty) return false;
    return receivedChunks.length == receivedChunks.first.totalChunks;
  }

  List<int> getMissingChunkIndices(List<ExchangeEnvelope> chunks) {
    if (chunks.isEmpty) return [];

    final totalChunks = chunks.first.totalChunks;
    final received = chunks.map((c) => c.chunkIndex).toSet();
    final missing = <int>[];

    for (var i = 0; i < totalChunks; i++) {
      if (!received.contains(i)) {
        missing.add(i);
      }
    }

    return missing;
  }

  String _serializeEnvelope(ExchangeEnvelope envelope) {
    return [
      envelope.packetId,
      envelope.sourceId,
      envelope.targetId,
      envelope.type.name,
      envelope.sequenceNo.toString(),
      envelope.totalChunks.toString(),
      envelope.chunkIndex.toString(),
      envelope.timestamp.millisecondsSinceEpoch.toString(),
      envelope.checksum,
      envelope.encryptedPayload,
      envelope.signature,
    ].join('::');
  }

  static ExchangeEnvelope? parseEnvelope(String messageText) {
    if (!messageText.startsWith('__TELEPOS_DATA__:')) return null;

    final data = messageText.substring('__TELEPOS_DATA__:'.length);
    final parts = data.split('::');
    if (parts.length < 11) return null;

    try {
      return ExchangeEnvelope(
        packetId: parts[0],
        sourceId: parts[1],
        targetId: parts[2],
        type: ExchangeType.values.firstWhere((t) => t.name == parts[3]),
        sequenceNo: int.parse(parts[4]),
        totalChunks: int.parse(parts[5]),
        chunkIndex: int.parse(parts[6]),
        timestamp: DateTime.fromMillisecondsSinceEpoch(int.parse(parts[7])),
        checksum: parts[8],
        encryptedPayload: parts[9],
        signature: parts[10],
      );
    } catch (_) {
      return null;
    }
  }
}
