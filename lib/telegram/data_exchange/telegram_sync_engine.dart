import 'dart:async';

import 'package:telepos/telegram/channels/channel_registry.dart';
import 'package:telepos/telegram/channels/channel_types.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/data_exchange/chunk_transfer_service.dart';
import 'package:telepos/telegram/data_exchange/conflict_resolver.dart';
import 'package:telepos/telegram/data_exchange/data_packer.dart';
import 'package:telepos/telegram/data_exchange/data_unpacker.dart';
import 'package:telepos/telegram/data_exchange/sync_protocol.dart';
import 'package:telepos/telegram/data_exchange/sync_state_tracker.dart';
import 'package:telepos/telegram/encryption/data_encryption_service.dart';
import 'package:telepos/telegram/messaging/message_service.dart';
import 'package:telepos/telegram/messaging/realtime_updates.dart';
import 'package:telepos/domain/entities/telegram/exchange_envelope.dart';
import 'package:telepos/domain/entities/telegram/sync_packet.dart';

enum SyncEngineState { idle, syncing, paused, error }

class SyncConfig {
  final Duration syncInterval;

  final String posId;

  final String serverId;

  final Set<ExchangeType> enabledTypes;

  final bool autoSyncEnabled;

  const SyncConfig({
    this.syncInterval = const Duration(minutes: 5),
    required this.posId,
    required this.serverId,
    this.enabledTypes = const {
      ExchangeType.product,
      ExchangeType.sale,
      ExchangeType.refund,
      ExchangeType.shift,
      ExchangeType.agent,
      ExchangeType.price,
      ExchangeType.supply,
      ExchangeType.config,
      ExchangeType.fiscal,
    },
    this.autoSyncEnabled = true,
  });

  SyncConfig copyWith({
    Duration? syncInterval,
    String? posId,
    String? serverId,
    Set<ExchangeType>? enabledTypes,
    bool? autoSyncEnabled,
  }) {
    return SyncConfig(
      syncInterval: syncInterval ?? this.syncInterval,
      posId: posId ?? this.posId,
      serverId: serverId ?? this.serverId,
      enabledTypes: enabledTypes ?? this.enabledTypes,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
    );
  }
}

class SyncState {
  final SyncEngineState engineState;
  final DateTime? lastSyncTime;
  final ExchangeType? currentType;
  final int pendingPackets;
  final int processedPackets;
  final String? lastError;

  const SyncState({
    this.engineState = SyncEngineState.idle,
    this.lastSyncTime,
    this.currentType,
    this.pendingPackets = 0,
    this.processedPackets = 0,
    this.lastError,
  });

  SyncState copyWith({
    SyncEngineState? engineState,
    DateTime? lastSyncTime,
    ExchangeType? currentType,
    int? pendingPackets,
    int? processedPackets,
    String? lastError,
  }) {
    return SyncState(
      engineState: engineState ?? this.engineState,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      currentType: currentType ?? this.currentType,
      pendingPackets: pendingPackets ?? this.pendingPackets,
      processedPackets: processedPackets ?? this.processedPackets,
      lastError: lastError ?? this.lastError,
    );
  }

  bool get isIdle => engineState == SyncEngineState.idle;
  bool get isSyncing => engineState == SyncEngineState.syncing;
  bool get isPaused => engineState == SyncEngineState.paused;
  bool get hasError => engineState == SyncEngineState.error;
}

typedef ExchangeHandler = Future<void> Function(Map<String, dynamic> data);

typedef SyncHandler = Future<void> Function(String sessionId, int lastSync);

class TelegramSyncEngine {
  final MessageService _messageService; // ignore: unused_field
  final DataPacker _packer;
  final DataUnpacker _unpacker;
  final ChunkTransferService _chunkTransfer;
  final ConflictResolver _conflictResolver; // ignore: unused_field
  final DataEncryptionService _encryption;
  final ChannelRegistry _channelRegistry;
  final RealtimeUpdates _realtimeUpdates;
  final TdLibLogger _logger;

  SyncEngineState _state = SyncEngineState.idle;
  final Map<String, SyncSession> _activeSessions = {};
  final Map<String, List<ExchangeEnvelope>> _receivedChunks = {};

  Timer? _periodicSyncTimer;
  StreamSubscription? _messageSubscription;

  SyncConfig _config;

  SyncState _syncState = const SyncState();

  final Map<ExchangeType, ExchangeHandler> _handlers = {};

  final Map<ExchangeType, SyncHandler> _downloadHandlers = {};

  final Map<ExchangeType, SyncHandler> _uploadHandlers = {};

  SyncStateTracker? _stateTracker;

  TelegramSyncEngine({
    required MessageService messageService,
    required DataPacker packer,
    required DataUnpacker unpacker,
    required ChunkTransferService chunkTransfer,
    required ConflictResolver conflictResolver,
    required DataEncryptionService encryption,
    required ChannelRegistry channelRegistry,
    required RealtimeUpdates realtimeUpdates,
    required TdLibLogger logger,
    SyncStateTracker? stateTracker,
    SyncConfig? config,
  }) : _messageService = messageService,
       _packer = packer,
       _unpacker = unpacker,
       _chunkTransfer = chunkTransfer,
       _conflictResolver = conflictResolver,
       _encryption = encryption,
       _channelRegistry = channelRegistry,
       _realtimeUpdates = realtimeUpdates,
       _logger = logger,
       _stateTracker = stateTracker,
       _config =
           config ??
           const SyncConfig(posId: 'default-pos', serverId: 'default-server');

  void setStateTracker(SyncStateTracker tracker) {
    _stateTracker = tracker;
    _logger.logSync('SyncStateTracker set');
  }

  SyncStateTracker? get stateTracker => _stateTracker;

  int getLastSyncTimestamp(ExchangeType type) {
    return _stateTracker?.getLastSync(type) ?? 0;
  }

  Future<void> markSynced(ExchangeType type) async {
    await _stateTracker?.markSynced(type);
    await _stateTracker?.setStatus(type, SyncStatus.success);
  }

  SyncEngineState get state => _state;

  SyncConfig get config => _config;

  SyncState get syncState => _syncState;

  Map<String, SyncSession> get activeSessions =>
      Map.unmodifiable(_activeSessions);

  void updateConfig(SyncConfig newConfig) {
    _config = newConfig;
    _logger.logSync('Config updated: posId=${newConfig.posId}');

    if (_periodicSyncTimer != null && newConfig.autoSyncEnabled) {
      _periodicSyncTimer?.cancel();
      _periodicSyncTimer = Timer.periodic(
        newConfig.syncInterval,
        (_) => syncAll(),
      );
    }
  }

  void registerHandler(ExchangeType type, ExchangeHandler handler) {
    _handlers[type] = handler;
    _logger.logSync('Handler registered for ${type.name}');
  }

  void registerDownloadHandler(ExchangeType type, SyncHandler handler) {
    _downloadHandlers[type] = handler;
    _logger.logSync('Download handler registered for ${type.name}');
  }

  void registerUploadHandler(ExchangeType type, SyncHandler handler) {
    _uploadHandlers[type] = handler;
    _logger.logSync('Upload handler registered for ${type.name}');
  }

  void start() {
    _logger.logSync('Sync engine starting');

    _messageSubscription = _realtimeUpdates.systemMessages.listen(
      _handleIncomingData,
    );

    if (_config.autoSyncEnabled) {
      _periodicSyncTimer = Timer.periodic(
        _config.syncInterval,
        (_) => syncAll(),
      );
    }

    _state = SyncEngineState.idle;
    _syncState = const SyncState();
    _logger.logSync('Sync engine started');
  }

  Future<void> stop() async {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    _state = SyncEngineState.idle;
    _syncState = const SyncState();
    _logger.logSync('Sync engine stopped');
  }

  Future<void> sendPacket({
    required String sourceId,
    required String targetId,
    required ExchangeType type,
    required dynamic data,
    required String sessionId,
  }) async {
    _state = SyncEngineState.syncing;
    _syncState = _syncState.copyWith(
      engineState: SyncEngineState.syncing,
      currentType: type,
    );
    _logger.logSync('Sending packet: type=${type.name}');

    try {
      final packed = await _packer.pack(data, sessionId);

      final signature = await _encryption.signData(packed.payload, sourceId);

      final chatId = _channelRegistry.getChatId(
        SystemChannelType.posDataExchange,
      );
      if (chatId == null) {
        throw StateError('Data exchange channel not found');
      }

      final session = _activeSessions.putIfAbsent(
        sessionId,
        () => SyncSession(
          sessionId: sessionId,
          peerId: targetId,
          startedAt: DateTime.now(),
          state: SyncSessionState.active,
        ),
      );
      session.lastSequenceNo++;

      final packetId = '${sourceId}_${DateTime.now().millisecondsSinceEpoch}';

      await _chunkTransfer.sendChunked(
        chatId: chatId,
        packetId: packetId,
        sourceId: sourceId,
        targetId: targetId,
        type: type,
        encryptedPayload: packed.payload,
        checksum: packed.checksum,
        signature: signature,
        sequenceNo: session.lastSequenceNo,
      );

      session.totalPackets++;
      session.deliveredPackets++;

      _syncState = _syncState.copyWith(
        processedPackets: _syncState.processedPackets + 1,
      );

      _logger.logSync(
        'Packet sent: ${type.name} '
        '(${packed.originalSize} → ${packed.packedSize} bytes)',
        packetId: packetId,
      );
    } catch (e, st) {
      _state = SyncEngineState.error;
      _syncState = _syncState.copyWith(
        engineState: SyncEngineState.error,
        lastError: e.toString(),
      );
      _logger.logError('sendPacket', e, st);
      rethrow;
    } finally {
      if (_state == SyncEngineState.syncing) {
        _state = SyncEngineState.idle;
        _syncState = _syncState.copyWith(engineState: SyncEngineState.idle);
      }
    }
  }

  Future<void> syncAll() async {
    if (_state == SyncEngineState.syncing) {
      _logger.logSync('Sync already in progress, skipping');
      return;
    }

    _state = SyncEngineState.syncing;
    _syncState = _syncState.copyWith(
      engineState: SyncEngineState.syncing,
      pendingPackets: _config.enabledTypes.length * 2,
    );
    _logger.logSync('Full sync started');

    final sessionId = 'sync_${DateTime.now().millisecondsSinceEpoch}';

    try {
      for (final type in _config.enabledTypes) {
        if (_state == SyncEngineState.paused) {
          _logger.logSync('Sync paused, stopping iteration');
          break;
        }

        _syncState = _syncState.copyWith(currentType: type);

        final lastSync = getLastSyncTimestamp(type);

        await _stateTracker?.setStatus(type, SyncStatus.inProgress);

        try {
          final downloadHandler = _downloadHandlers[type];
          if (downloadHandler != null) {
            _logger.logSync('Download ${type.name} (lastSync=$lastSync)');
            await downloadHandler(sessionId, lastSync);
          }

          final uploadHandler = _uploadHandlers[type];
          if (uploadHandler != null) {
            _logger.logSync('Upload ${type.name} (lastSync=$lastSync)');
            await uploadHandler(sessionId, lastSync);
          }

          await markSynced(type);
        } catch (e) {
          _logger.logError('syncAll:${type.name}', e);
          await _stateTracker?.setStatus(type, SyncStatus.error);
        }
      }

      _syncState = _syncState.copyWith(
        lastSyncTime: DateTime.now(),
        pendingPackets: 0,
        currentType: null,
      );
      _logger.logSync('Full sync completed');
    } catch (e, st) {
      _state = SyncEngineState.error;
      _syncState = _syncState.copyWith(
        engineState: SyncEngineState.error,
        lastError: e.toString(),
      );
      _logger.logError('syncAll', e, st);
    } finally {
      if (_state == SyncEngineState.syncing) {
        _state = SyncEngineState.idle;
        _syncState = _syncState.copyWith(engineState: SyncEngineState.idle);
      }
    }
  }

  Future<void> syncType(ExchangeType type) async {
    if (!_config.enabledTypes.contains(type)) {
      _logger.logSync('Type ${type.name} is disabled, skipping');
      return;
    }

    final lastSync = getLastSyncTimestamp(type);

    _logger.logSync('Syncing type: ${type.name} (lastSync=$lastSync)');
    _syncState = _syncState.copyWith(
      engineState: SyncEngineState.syncing,
      currentType: type,
    );

    final sessionId =
        'sync_${type.name}_${DateTime.now().millisecondsSinceEpoch}';

    await _stateTracker?.setStatus(type, SyncStatus.inProgress);

    try {
      final downloadHandler = _downloadHandlers[type];
      if (downloadHandler != null) {
        await downloadHandler(sessionId, lastSync);
      }

      final uploadHandler = _uploadHandlers[type];
      if (uploadHandler != null) {
        await uploadHandler(sessionId, lastSync);
      }

      await markSynced(type);

      _syncState = _syncState.copyWith(
        lastSyncTime: DateTime.now(),
        currentType: null,
      );
    } catch (e, st) {
      await _stateTracker?.setStatus(type, SyncStatus.error);
      _syncState = _syncState.copyWith(
        engineState: SyncEngineState.error,
        lastError: e.toString(),
      );
      _logger.logError('syncType:${type.name}', e, st);
      rethrow;
    } finally {
      if (_syncState.engineState == SyncEngineState.syncing) {
        _syncState = _syncState.copyWith(engineState: SyncEngineState.idle);
      }
    }
  }

  Future<void> forceSyncType(ExchangeType type) async {
    await _stateTracker?.reset(type);
    await syncType(type);
  }

  Future<void> forceSyncAll() async {
    await _stateTracker?.resetAll();
    await syncAll();
  }

  void pause() {
    _state = SyncEngineState.paused;
    _syncState = _syncState.copyWith(engineState: SyncEngineState.paused);
    _logger.logSync('Sync paused');
  }

  void resume() {
    _state = SyncEngineState.idle;
    _syncState = _syncState.copyWith(engineState: SyncEngineState.idle);
    _logger.logSync('Sync resumed');
  }

  void _handleIncomingData(dynamic message) {
    try {
      final text = message.text as String? ?? '';
      final envelope = ChunkTransferService.parseEnvelope(text);
      if (envelope == null) return;

      _syncState = _syncState.copyWith(
        pendingPackets: _syncState.pendingPackets + 1,
      );

      _logger.logSync(
        'Received chunk ${envelope.chunkIndex + 1}/${envelope.totalChunks}',
        packetId: envelope.packetId,
      );

      _receivedChunks.putIfAbsent(envelope.packetId, () => []).add(envelope);

      final chunks = _receivedChunks[envelope.packetId]!;
      if (_chunkTransfer.isComplete(chunks)) {
        _processCompletePacket(envelope.packetId, chunks);
      }
    } catch (e, st) {
      _logger.logError('_handleIncomingData', e, st);
    }
  }

  Future<void> _processCompletePacket(
    String packetId,
    List<ExchangeEnvelope> chunks,
  ) async {
    _logger.logSync('Processing complete packet', packetId: packetId);

    try {
      final payload = _chunkTransfer.assembleChunks(chunks);
      if (payload == null) return;

      final isValid = await _encryption.verifySignature(
        payload,
        chunks.first.signature,
        chunks.first.sourceId,
      );

      if (!isValid) {
        _logger.logError('_processCompletePacket', 'Invalid signature');
        return;
      }

      final unpacked = await _unpacker.unpack(
        payload,
        sessionId: chunks.first.sourceId,
        checksum: chunks.first.checksum,
      );

      if (!unpacked.isChecksumValid) {
        _logger.logError('_processCompletePacket', 'Checksum mismatch');
        return;
      }

      final type = chunks.first.type;
      final handler = _handlers[type];

      if (handler != null) {
        final data = unpacked.data;
        if (data is Map<String, dynamic>) {
          await handler(data);
          _logger.logSync(
            'Handler executed for type=${type.name}',
            packetId: packetId,
          );
        } else {
          _logger.logWarning(
            'Unexpected data type: ${data.runtimeType}, expected Map',
          );
        }
      } else {
        _logger.logWarning('No handler registered for type=${type.name}');
      }

      _syncState = _syncState.copyWith(
        processedPackets: _syncState.processedPackets + 1,
        pendingPackets: _syncState.pendingPackets - 1,
      );

      _logger.logSync(
        'Packet processed: type=${type.name}',
        packetId: packetId,
      );

      _receivedChunks.remove(packetId);
    } catch (e, st) {
      _logger.logError('_processCompletePacket', e, st);
    }
  }

  Future<void> dispose() async {
    await stop();
    _handlers.clear();
    _downloadHandlers.clear();
    _uploadHandlers.clear();
  }
}
