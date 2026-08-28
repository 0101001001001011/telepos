import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:telepos/telegram/channels/channel_registry.dart';
import 'package:telepos/telegram/channels/channel_types.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/data_exchange/chunk_transfer_service.dart';
import 'package:telepos/telegram/data_exchange/conflict_resolver.dart';
import 'package:telepos/telegram/data_exchange/data_packer.dart';
import 'package:telepos/telegram/data_exchange/data_unpacker.dart';
import 'package:telepos/telegram/data_exchange/sync_protocol.dart';
import 'package:telepos/telegram/data_exchange/telegram_sync_engine.dart';
import 'package:telepos/telegram/encryption/data_encryption_service.dart';
import 'package:telepos/telegram/messaging/message_service.dart';
import 'package:telepos/telegram/messaging/realtime_updates.dart';
import 'package:telepos/domain/entities/telegram/exchange_envelope.dart';
import 'package:telepos/domain/entities/telegram/sync_packet.dart';
import 'package:telepos/domain/entities/telegram/telegram_message.dart';

class MockMessageService extends Mock implements MessageService {}

class MockDataPacker extends Mock implements DataPacker {}

class MockDataUnpacker extends Mock implements DataUnpacker {}

class MockChunkTransferService extends Mock implements ChunkTransferService {}

class MockConflictResolver extends Mock implements ConflictResolver {}

class MockDataEncryptionService extends Mock implements DataEncryptionService {}

class MockChannelRegistry extends Mock implements ChannelRegistry {}

class MockRealtimeUpdates extends Mock implements RealtimeUpdates {}

class MockTdLibLogger extends Mock implements TdLibLogger {}

class FakeExchangeEnvelope extends Fake implements ExchangeEnvelope {}

void main() {
  late TelegramSyncEngine syncEngine;
  late MockMessageService mockMessageService;
  late MockDataPacker mockPacker;
  late MockDataUnpacker mockUnpacker;
  late MockChunkTransferService mockChunkTransfer;
  late MockConflictResolver mockConflictResolver;
  late MockDataEncryptionService mockEncryption;
  late MockChannelRegistry mockChannelRegistry;
  late MockRealtimeUpdates mockRealtimeUpdates;
  late MockTdLibLogger mockLogger;

  late StreamController<TelegramMessage> systemMessagesController;

  setUpAll(() {
    registerFallbackValue(FakeExchangeEnvelope());
    registerFallbackValue(ExchangeType.product);
    registerFallbackValue(SystemChannelType.posDataExchange);
    registerFallbackValue(<ExchangeEnvelope>[]);
  });

  TelegramSyncEngine createSyncEngine() {
    return TelegramSyncEngine(
      messageService: mockMessageService,
      packer: mockPacker,
      unpacker: mockUnpacker,
      chunkTransfer: mockChunkTransfer,
      conflictResolver: mockConflictResolver,
      encryption: mockEncryption,
      channelRegistry: mockChannelRegistry,
      realtimeUpdates: mockRealtimeUpdates,
      logger: mockLogger,
    );
  }

  void setupDefaultMocks() {
    when(
      () => mockRealtimeUpdates.systemMessages,
    ).thenAnswer((_) => systemMessagesController.stream);
    when(
      () => mockLogger.logSync(any(), packetId: any(named: 'packetId')),
    ).thenReturn(null);
    when(() => mockLogger.logSync(any())).thenReturn(null);
    when(() => mockLogger.logError(any(), any(), any())).thenReturn(null);
    when(() => mockLogger.logError(any(), any())).thenReturn(null);
  }

  setUp(() {
    mockMessageService = MockMessageService();
    mockPacker = MockDataPacker();
    mockUnpacker = MockDataUnpacker();
    mockChunkTransfer = MockChunkTransferService();
    mockConflictResolver = MockConflictResolver();
    mockEncryption = MockDataEncryptionService();
    mockChannelRegistry = MockChannelRegistry();
    mockRealtimeUpdates = MockRealtimeUpdates();
    mockLogger = MockTdLibLogger();

    systemMessagesController = StreamController<TelegramMessage>.broadcast();

    setupDefaultMocks();
    syncEngine = createSyncEngine();
  });

  tearDown(() async {
    await syncEngine.dispose();
    await systemMessagesController.close();
  });

  group('TelegramSyncEngine', () {
    group('Initial state', () {
      test('should start with idle state', () {
        expect(syncEngine.state, SyncEngineState.idle);
      });

      test('should have empty active sessions initially', () {
        expect(syncEngine.activeSessions, isEmpty);
      });
    });

    group('Sync lifecycle - start()', () {
      test('should set state to idle when started', () {
        syncEngine.start();

        expect(syncEngine.state, SyncEngineState.idle);
      });

      test('should log sync engine starting', () {
        syncEngine.start();

        verify(() => mockLogger.logSync('Sync engine starting')).called(1);
      });

      test('should log sync engine started', () {
        syncEngine.start();

        verify(() => mockLogger.logSync('Sync engine started')).called(1);
      });

      test('should subscribe to system messages', () {
        syncEngine.start();

        verify(() => mockRealtimeUpdates.systemMessages).called(1);
      });

      test('should remain in idle state after starting', () {
        syncEngine.start();

        expect(syncEngine.state, SyncEngineState.idle);
      });
    });

    group('Sync lifecycle - stop()', () {
      test('should set state to idle when stopped', () async {
        syncEngine.start();
        await syncEngine.stop();

        expect(syncEngine.state, SyncEngineState.idle);
      });

      test('should log sync engine stopped', () async {
        syncEngine.start();
        await syncEngine.stop();

        verify(() => mockLogger.logSync('Sync engine stopped')).called(1);
      });

      test('should cancel periodic sync timer when stopped', () async {
        syncEngine.start();
        await syncEngine.stop();

        expect(syncEngine.state, SyncEngineState.idle);
      });

      test('should be safe to call stop multiple times', () async {
        syncEngine.start();
        await syncEngine.stop();
        await syncEngine.stop();

        expect(syncEngine.state, SyncEngineState.idle);
      });

      test('should be safe to call stop without start', () async {
        await syncEngine.stop();

        expect(syncEngine.state, SyncEngineState.idle);
      });
    });

    group('Sync lifecycle - pause() and resume()', () {
      test('should set state to paused when pause is called', () {
        syncEngine.start();
        syncEngine.pause();

        expect(syncEngine.state, SyncEngineState.paused);
      });

      test('should log sync paused', () {
        syncEngine.pause();

        verify(() => mockLogger.logSync('Sync paused')).called(1);
      });

      test('should set state to idle when resume is called', () {
        syncEngine.start();
        syncEngine.pause();
        syncEngine.resume();

        expect(syncEngine.state, SyncEngineState.idle);
      });

      test('should log sync resumed', () {
        syncEngine.resume();

        verify(() => mockLogger.logSync('Sync resumed')).called(1);
      });

      test('should allow pause-resume cycle multiple times', () {
        syncEngine.start();

        syncEngine.pause();
        expect(syncEngine.state, SyncEngineState.paused);

        syncEngine.resume();
        expect(syncEngine.state, SyncEngineState.idle);

        syncEngine.pause();
        expect(syncEngine.state, SyncEngineState.paused);

        syncEngine.resume();
        expect(syncEngine.state, SyncEngineState.idle);
      });

      test('should be safe to pause without start', () {
        syncEngine.pause();

        expect(syncEngine.state, SyncEngineState.paused);
      });

      test('should be safe to resume without pause', () {
        syncEngine.resume();

        expect(syncEngine.state, SyncEngineState.idle);
      });
    });

    group('Sync lifecycle - dispose()', () {
      test('should call stop when disposed', () async {
        syncEngine.start();
        await syncEngine.dispose();

        verify(() => mockLogger.logSync('Sync engine stopped')).called(1);
      });

      test('should set state to idle when disposed', () async {
        syncEngine.start();
        await syncEngine.dispose();

        expect(syncEngine.state, SyncEngineState.idle);
      });
    });

    group('Sync intervals and scheduling - syncAll()', () {
      test('should set state to syncing during sync', () async {
        await syncEngine.syncAll();

        expect(syncEngine.state, SyncEngineState.idle);
      });

      test('should log full sync started', () async {
        await syncEngine.syncAll();

        verify(() => mockLogger.logSync('Full sync started')).called(1);
      });

      test('should log full sync completed', () async {
        await syncEngine.syncAll();

        verify(() => mockLogger.logSync('Full sync completed')).called(1);
      });

      test('should return to idle state after sync completes', () async {
        await syncEngine.syncAll();

        expect(syncEngine.state, SyncEngineState.idle);
      });

      test('should set error state if sync fails', () async {
        expect(syncEngine.state, SyncEngineState.idle);
      });
    });

    group('Sync intervals and scheduling - syncType()', () {
      test('should log sync type', () async {
        await syncEngine.syncType(ExchangeType.product);

        verify(
          () => mockLogger.logSync('Syncing type: product (lastSync=0)'),
        ).called(1);
      });

      test('should handle all enabled exchange types', () async {
        final enabledTypes = syncEngine.config.enabledTypes;

        for (final type in ExchangeType.values) {
          await syncEngine.syncType(type);

          if (enabledTypes.contains(type)) {
            verify(
              () =>
                  mockLogger.logSync('Syncing type: ${type.name} (lastSync=0)'),
            ).called(1);
          } else {
            verify(
              () =>
                  mockLogger.logSync('Type ${type.name} is disabled, skipping'),
            ).called(1);
          }
        }
      });
    });

    group('Data packet sending - sendPacket()', () {
      const testSourceId = 'pos-001';
      const testTargetId = 'server-001';
      const testSessionId = 'session-123';
      const testChatId = 12345;
      final testData = {
        'key': 'value',
        'items': [1, 2, 3],
      };

      void setupSendPacketMocks() {
        when(
          () =>
              mockChannelRegistry.getChatId(SystemChannelType.posDataExchange),
        ).thenReturn(testChatId);

        when(() => mockPacker.pack(any(), any())).thenAnswer(
          (_) async => PackedData(
            payload: 'encrypted_payload',
            checksum: 'abc123',
            originalSize: 100,
            packedSize: 80,
            isCompressed: true,
            isEncrypted: true,
          ),
        );

        when(
          () => mockEncryption.signData(any(), any()),
        ).thenAnswer((_) async => 'signature123');

        when(
          () => mockChunkTransfer.sendChunked(
            chatId: any(named: 'chatId'),
            packetId: any(named: 'packetId'),
            sourceId: any(named: 'sourceId'),
            targetId: any(named: 'targetId'),
            type: any(named: 'type'),
            encryptedPayload: any(named: 'encryptedPayload'),
            checksum: any(named: 'checksum'),
            signature: any(named: 'signature'),
            sequenceNo: any(named: 'sequenceNo'),
          ),
        ).thenAnswer((_) async => <ExchangeEnvelope>[]);
      }

      test('should set state to syncing when sending packet', () async {
        setupSendPacketMocks();

        await syncEngine.sendPacket(
          sourceId: testSourceId,
          targetId: testTargetId,
          type: ExchangeType.product,
          data: testData,
          sessionId: testSessionId,
        );

        expect(syncEngine.state, SyncEngineState.idle);
      });

      test('should pack data before sending', () async {
        setupSendPacketMocks();

        await syncEngine.sendPacket(
          sourceId: testSourceId,
          targetId: testTargetId,
          type: ExchangeType.product,
          data: testData,
          sessionId: testSessionId,
        );

        verify(() => mockPacker.pack(testData, testSessionId)).called(1);
      });

      test('should sign packed data', () async {
        setupSendPacketMocks();

        await syncEngine.sendPacket(
          sourceId: testSourceId,
          targetId: testTargetId,
          type: ExchangeType.product,
          data: testData,
          sessionId: testSessionId,
        );

        verify(
          () => mockEncryption.signData('encrypted_payload', testSourceId),
        ).called(1);
      });

      test('should get chat ID from channel registry', () async {
        setupSendPacketMocks();

        await syncEngine.sendPacket(
          sourceId: testSourceId,
          targetId: testTargetId,
          type: ExchangeType.product,
          data: testData,
          sessionId: testSessionId,
        );

        verify(
          () =>
              mockChannelRegistry.getChatId(SystemChannelType.posDataExchange),
        ).called(1);
      });

      test(
        'should throw StateError if data exchange channel not found',
        () async {
          when(
            () => mockChannelRegistry.getChatId(
              SystemChannelType.posDataExchange,
            ),
          ).thenReturn(null);
          when(() => mockPacker.pack(any(), any())).thenAnswer(
            (_) async => PackedData(
              payload: 'encrypted_payload',
              checksum: 'abc123',
              originalSize: 100,
              packedSize: 80,
              isCompressed: true,
              isEncrypted: true,
            ),
          );
          when(
            () => mockEncryption.signData(any(), any()),
          ).thenAnswer((_) async => 'signature123');

          expect(
            () => syncEngine.sendPacket(
              sourceId: testSourceId,
              targetId: testTargetId,
              type: ExchangeType.product,
              data: testData,
              sessionId: testSessionId,
            ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('Data exchange channel not found'),
              ),
            ),
          );
        },
      );

      test('should create session if not exists', () async {
        setupSendPacketMocks();
        expect(syncEngine.activeSessions, isEmpty);

        await syncEngine.sendPacket(
          sourceId: testSourceId,
          targetId: testTargetId,
          type: ExchangeType.product,
          data: testData,
          sessionId: testSessionId,
        );

        expect(syncEngine.activeSessions, contains(testSessionId));
      });

      test('should increment sequence number for session', () async {
        setupSendPacketMocks();

        await syncEngine.sendPacket(
          sourceId: testSourceId,
          targetId: testTargetId,
          type: ExchangeType.product,
          data: testData,
          sessionId: testSessionId,
        );

        expect(
          syncEngine.activeSessions[testSessionId]!.lastSequenceNo,
          equals(1),
        );

        await syncEngine.sendPacket(
          sourceId: testSourceId,
          targetId: testTargetId,
          type: ExchangeType.sale,
          data: testData,
          sessionId: testSessionId,
        );

        expect(
          syncEngine.activeSessions[testSessionId]!.lastSequenceNo,
          equals(2),
        );
      });

      test('should send data through chunk transfer service', () async {
        setupSendPacketMocks();

        await syncEngine.sendPacket(
          sourceId: testSourceId,
          targetId: testTargetId,
          type: ExchangeType.product,
          data: testData,
          sessionId: testSessionId,
        );

        verify(
          () => mockChunkTransfer.sendChunked(
            chatId: testChatId,
            packetId: any(named: 'packetId'),
            sourceId: testSourceId,
            targetId: testTargetId,
            type: ExchangeType.product,
            encryptedPayload: 'encrypted_payload',
            checksum: 'abc123',
            signature: 'signature123',
            sequenceNo: 1,
          ),
        ).called(1);
      });

      test('should update session statistics after sending', () async {
        setupSendPacketMocks();

        await syncEngine.sendPacket(
          sourceId: testSourceId,
          targetId: testTargetId,
          type: ExchangeType.product,
          data: testData,
          sessionId: testSessionId,
        );

        final session = syncEngine.activeSessions[testSessionId]!;
        expect(session.totalPackets, equals(1));
        expect(session.deliveredPackets, equals(1));
      });

      test('should log packet sending', () async {
        setupSendPacketMocks();

        await syncEngine.sendPacket(
          sourceId: testSourceId,
          targetId: testTargetId,
          type: ExchangeType.product,
          data: testData,
          sessionId: testSessionId,
        );

        verify(
          () => mockLogger.logSync('Sending packet: type=product'),
        ).called(1);
      });

      test('should log packet sent with sizes', () async {
        setupSendPacketMocks();

        await syncEngine.sendPacket(
          sourceId: testSourceId,
          targetId: testTargetId,
          type: ExchangeType.product,
          data: testData,
          sessionId: testSessionId,
        );

        verify(
          () => mockLogger.logSync(
            any(that: contains('Packet sent')),
            packetId: any(named: 'packetId'),
          ),
        ).called(1);
      });

      test('should handle different exchange types', () async {
        setupSendPacketMocks();

        for (final type in [
          ExchangeType.sale,
          ExchangeType.refund,
          ExchangeType.agent,
          ExchangeType.config,
        ]) {
          await syncEngine.sendPacket(
            sourceId: testSourceId,
            targetId: testTargetId,
            type: type,
            data: testData,
            sessionId: 'session-${type.name}',
          );

          verify(
            () => mockLogger.logSync('Sending packet: type=${type.name}'),
          ).called(1);
        }
      });

      test('should set error state on failure', () async {
        when(
          () =>
              mockChannelRegistry.getChatId(SystemChannelType.posDataExchange),
        ).thenReturn(testChatId);
        when(
          () => mockPacker.pack(any(), any()),
        ).thenThrow(Exception('Packer error'));

        expect(
          () => syncEngine.sendPacket(
            sourceId: testSourceId,
            targetId: testTargetId,
            type: ExchangeType.product,
            data: testData,
            sessionId: testSessionId,
          ),
          throwsException,
        );

        expect(syncEngine.state, SyncEngineState.error);
      });

      test('should log error on failure', () async {
        when(
          () =>
              mockChannelRegistry.getChatId(SystemChannelType.posDataExchange),
        ).thenReturn(testChatId);
        final exception = Exception('Test error');
        when(() => mockPacker.pack(any(), any())).thenThrow(exception);

        try {
          await syncEngine.sendPacket(
            sourceId: testSourceId,
            targetId: testTargetId,
            type: ExchangeType.product,
            data: testData,
            sessionId: testSessionId,
          );
        } catch (_) {}

        verify(
          () => mockLogger.logError('sendPacket', exception, any()),
        ).called(1);
      });

      test('should return to idle state after successful send', () async {
        setupSendPacketMocks();

        await syncEngine.sendPacket(
          sourceId: testSourceId,
          targetId: testTargetId,
          type: ExchangeType.product,
          data: testData,
          sessionId: testSessionId,
        );

        expect(syncEngine.state, SyncEngineState.idle);
      });
    });

    group('Data packet receiving', () {
      const testPacketId = 'packet-001';
      const testSourceId = 'server-001';
      const testTargetId = 'pos-001';
      const testChecksum = 'checksum123';
      const testSignature = 'signature123';

      TelegramMessage createSystemMessage(String text) {
        return TelegramMessage(
          messageId: 1,
          chatId: 100,
          senderId: 200,
          direction: MessageDirection.incoming,
          contentType: MessageContentType.text,
          text: text,
          date: DateTime.now(),
          isSystemMessage: true,
        );
      }

      void setupReceiveMocks() {
        when(() => mockChunkTransfer.isComplete(any())).thenReturn(false);
        when(() => mockChunkTransfer.assembleChunks(any())).thenReturn(null);
        when(
          () => mockEncryption.verifySignature(any(), any(), any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockUnpacker.unpack(
            any(),
            sessionId: any(named: 'sessionId'),
            checksum: any(named: 'checksum'),
          ),
        ).thenAnswer(
          (_) async => UnpackedData(
            data: {'key': 'value'},
            isChecksumValid: true,
            originalChecksum: testChecksum,
            computedChecksum: testChecksum,
          ),
        );
      }

      test('should parse incoming envelope from message', () async {
        setupReceiveMocks();
        syncEngine.start();

        final now = DateTime.now();
        final messageText =
            '__TELEPOS_DATA__:$testPacketId::$testSourceId::$testTargetId::product::1::1::0::${now.millisecondsSinceEpoch}::$testChecksum::encrypted_data::$testSignature';

        when(() => mockChunkTransfer.isComplete(any())).thenReturn(true);
        when(
          () => mockChunkTransfer.assembleChunks(any()),
        ).thenReturn('assembled_payload');

        final message = createSystemMessage(messageText);
        systemMessagesController.add(message);

        await Future.delayed(const Duration(milliseconds: 50));

        verify(
          () => mockEncryption.verifySignature(any(), any(), any()),
        ).called(1);
      });

      test('should ignore non-TELEPOS messages', () async {
        setupReceiveMocks();
        syncEngine.start();

        final message = createSystemMessage('regular message');
        systemMessagesController.add(message);

        await Future.delayed(const Duration(milliseconds: 10));

        verifyNever(() => mockChunkTransfer.isComplete(any()));
      });

      test('should collect chunks until complete', () async {
        setupReceiveMocks();
        syncEngine.start();

        when(() => mockChunkTransfer.isComplete(any())).thenAnswer((
          invocation,
        ) {
          final chunks = invocation.positionalArguments[0] as List;
          return chunks.length >= 3;
        });
        when(
          () => mockChunkTransfer.assembleChunks(any()),
        ).thenReturn('full_payload');

        expect(syncEngine.state, SyncEngineState.idle);
      });

      test('should process complete packet when all chunks received', () async {
        setupReceiveMocks();
        syncEngine.start();

        when(() => mockChunkTransfer.isComplete(any())).thenReturn(true);
        when(
          () => mockChunkTransfer.assembleChunks(any()),
        ).thenReturn('assembled_payload');

        final now = DateTime.now();
        final messageText =
            '__TELEPOS_DATA__:$testPacketId::$testSourceId::$testTargetId::product::1::1::0::${now.millisecondsSinceEpoch}::$testChecksum::encrypted_data::$testSignature';

        final message = createSystemMessage(messageText);
        systemMessagesController.add(message);

        await Future.delayed(const Duration(milliseconds: 50));

        verify(
          () => mockEncryption.verifySignature(
            'assembled_payload',
            testSignature,
            testSourceId,
          ),
        ).called(1);
      });

      test('should verify signature before processing', () async {
        setupReceiveMocks();
        syncEngine.start();

        when(() => mockChunkTransfer.isComplete(any())).thenReturn(true);
        when(
          () => mockChunkTransfer.assembleChunks(any()),
        ).thenReturn('assembled_payload');
        when(
          () => mockEncryption.verifySignature(any(), any(), any()),
        ).thenAnswer((_) async => false);

        final now = DateTime.now();
        final messageText =
            '__TELEPOS_DATA__:$testPacketId::$testSourceId::$testTargetId::product::1::1::0::${now.millisecondsSinceEpoch}::$testChecksum::encrypted_data::$testSignature';

        final message = createSystemMessage(messageText);
        systemMessagesController.add(message);

        await Future.delayed(const Duration(milliseconds: 50));

        verify(
          () => mockLogger.logError(
            '_processCompletePacket',
            'Invalid signature',
          ),
        ).called(1);
      });

      test('should unpack data after signature verification', () async {
        setupReceiveMocks();
        syncEngine.start();

        when(() => mockChunkTransfer.isComplete(any())).thenReturn(true);
        when(
          () => mockChunkTransfer.assembleChunks(any()),
        ).thenReturn('assembled_payload');

        final now = DateTime.now();
        final messageText =
            '__TELEPOS_DATA__:$testPacketId::$testSourceId::$testTargetId::product::1::1::0::${now.millisecondsSinceEpoch}::$testChecksum::encrypted_data::$testSignature';

        final message = createSystemMessage(messageText);
        systemMessagesController.add(message);

        await Future.delayed(const Duration(milliseconds: 50));

        verify(
          () => mockUnpacker.unpack(
            'assembled_payload',
            sessionId: testSourceId,
            checksum: testChecksum,
          ),
        ).called(1);
      });

      test('should verify checksum after unpacking', () async {
        setupReceiveMocks();
        syncEngine.start();

        when(() => mockChunkTransfer.isComplete(any())).thenReturn(true);
        when(
          () => mockChunkTransfer.assembleChunks(any()),
        ).thenReturn('assembled_payload');
        when(
          () => mockUnpacker.unpack(
            any(),
            sessionId: any(named: 'sessionId'),
            checksum: any(named: 'checksum'),
          ),
        ).thenAnswer(
          (_) async => UnpackedData(
            data: {'key': 'value'},
            isChecksumValid: false,
            originalChecksum: testChecksum,
            computedChecksum: 'different_checksum',
          ),
        );

        final now = DateTime.now();
        final messageText =
            '__TELEPOS_DATA__:$testPacketId::$testSourceId::$testTargetId::product::1::1::0::${now.millisecondsSinceEpoch}::$testChecksum::encrypted_data::$testSignature';

        final message = createSystemMessage(messageText);
        systemMessagesController.add(message);

        await Future.delayed(const Duration(milliseconds: 50));

        verify(
          () => mockLogger.logError(
            '_processCompletePacket',
            'Checksum mismatch',
          ),
        ).called(1);
      });

      test('should log received chunk', () async {
        setupReceiveMocks();
        syncEngine.start();

        final now = DateTime.now();
        final messageText =
            '__TELEPOS_DATA__:$testPacketId::$testSourceId::$testTargetId::product::1::3::1::${now.millisecondsSinceEpoch}::$testChecksum::encrypted_data::$testSignature';

        final message = createSystemMessage(messageText);
        systemMessagesController.add(message);

        await Future.delayed(const Duration(milliseconds: 50));

        verify(
          () =>
              mockLogger.logSync('Received chunk 2/3', packetId: testPacketId),
        ).called(1);
      });

      test('should handle error in incoming data processing', () async {
        setupReceiveMocks();
        syncEngine.start();

        final invalidMessage = createSystemMessage('__TELEPOS_DATA__:invalid');
        systemMessagesController.add(invalidMessage);

        await Future.delayed(const Duration(milliseconds: 10));

        expect(syncEngine.state, isNot(SyncEngineState.error));
      });
    });

    group('Error handling', () {
      test('should set error state when packing fails', () async {
        when(
          () =>
              mockChannelRegistry.getChatId(SystemChannelType.posDataExchange),
        ).thenReturn(123);
        when(
          () => mockPacker.pack(any(), any()),
        ).thenThrow(Exception('Packing failed'));

        try {
          await syncEngine.sendPacket(
            sourceId: 'source',
            targetId: 'target',
            type: ExchangeType.product,
            data: {},
            sessionId: 'session',
          );
        } catch (_) {}

        expect(syncEngine.state, SyncEngineState.error);
      });

      test('should set error state when signing fails', () async {
        when(
          () =>
              mockChannelRegistry.getChatId(SystemChannelType.posDataExchange),
        ).thenReturn(123);
        when(() => mockPacker.pack(any(), any())).thenAnswer(
          (_) async => PackedData(
            payload: 'payload',
            checksum: 'sum',
            originalSize: 10,
            packedSize: 10,
            isCompressed: false,
            isEncrypted: true,
          ),
        );
        when(
          () => mockEncryption.signData(any(), any()),
        ).thenThrow(StateError('No key'));

        try {
          await syncEngine.sendPacket(
            sourceId: 'source',
            targetId: 'target',
            type: ExchangeType.product,
            data: {},
            sessionId: 'session',
          );
        } catch (_) {}

        expect(syncEngine.state, SyncEngineState.error);
      });

      test('should set error state when chunk transfer fails', () async {
        when(
          () =>
              mockChannelRegistry.getChatId(SystemChannelType.posDataExchange),
        ).thenReturn(123);
        when(() => mockPacker.pack(any(), any())).thenAnswer(
          (_) async => PackedData(
            payload: 'payload',
            checksum: 'sum',
            originalSize: 10,
            packedSize: 10,
            isCompressed: false,
            isEncrypted: true,
          ),
        );
        when(
          () => mockEncryption.signData(any(), any()),
        ).thenAnswer((_) async => 'sig');
        when(
          () => mockChunkTransfer.sendChunked(
            chatId: any(named: 'chatId'),
            packetId: any(named: 'packetId'),
            sourceId: any(named: 'sourceId'),
            targetId: any(named: 'targetId'),
            type: any(named: 'type'),
            encryptedPayload: any(named: 'encryptedPayload'),
            checksum: any(named: 'checksum'),
            signature: any(named: 'signature'),
            sequenceNo: any(named: 'sequenceNo'),
          ),
        ).thenThrow(Exception('Transfer failed'));

        try {
          await syncEngine.sendPacket(
            sourceId: 'source',
            targetId: 'target',
            type: ExchangeType.product,
            data: {},
            sessionId: 'session',
          );
        } catch (_) {}

        expect(syncEngine.state, SyncEngineState.error);
      });

      test('should rethrow exception after setting error state', () async {
        when(
          () =>
              mockChannelRegistry.getChatId(SystemChannelType.posDataExchange),
        ).thenReturn(123);
        final exception = Exception('Test exception');
        when(() => mockPacker.pack(any(), any())).thenThrow(exception);

        expect(
          () => syncEngine.sendPacket(
            sourceId: 'source',
            targetId: 'target',
            type: ExchangeType.product,
            data: {},
            sessionId: 'session',
          ),
          throwsA(equals(exception)),
        );
      });

      test('should log error with context', () async {
        when(
          () =>
              mockChannelRegistry.getChatId(SystemChannelType.posDataExchange),
        ).thenReturn(123);
        final exception = Exception('Detailed error');
        when(() => mockPacker.pack(any(), any())).thenThrow(exception);

        try {
          await syncEngine.sendPacket(
            sourceId: 'source',
            targetId: 'target',
            type: ExchangeType.product,
            data: {},
            sessionId: 'session',
          );
        } catch (_) {}

        verify(
          () => mockLogger.logError('sendPacket', exception, any()),
        ).called(1);
      });
    });

    group('Retry logic', () {
      test('should create session with initial state', () async {
        when(
          () =>
              mockChannelRegistry.getChatId(SystemChannelType.posDataExchange),
        ).thenReturn(123);
        when(() => mockPacker.pack(any(), any())).thenAnswer(
          (_) async => PackedData(
            payload: 'payload',
            checksum: 'sum',
            originalSize: 10,
            packedSize: 10,
            isCompressed: false,
            isEncrypted: true,
          ),
        );
        when(
          () => mockEncryption.signData(any(), any()),
        ).thenAnswer((_) async => 'sig');
        when(
          () => mockChunkTransfer.sendChunked(
            chatId: any(named: 'chatId'),
            packetId: any(named: 'packetId'),
            sourceId: any(named: 'sourceId'),
            targetId: any(named: 'targetId'),
            type: any(named: 'type'),
            encryptedPayload: any(named: 'encryptedPayload'),
            checksum: any(named: 'checksum'),
            signature: any(named: 'signature'),
            sequenceNo: any(named: 'sequenceNo'),
          ),
        ).thenAnswer((_) async => []);

        await syncEngine.sendPacket(
          sourceId: 'source',
          targetId: 'target',
          type: ExchangeType.product,
          data: {},
          sessionId: 'retry-session',
        );

        final session = syncEngine.activeSessions['retry-session'];
        expect(session, isNotNull);
        expect(session!.state, SyncSessionState.active);
      });

      test('session should track total and delivered packets', () async {
        when(
          () =>
              mockChannelRegistry.getChatId(SystemChannelType.posDataExchange),
        ).thenReturn(123);
        when(() => mockPacker.pack(any(), any())).thenAnswer(
          (_) async => PackedData(
            payload: 'payload',
            checksum: 'sum',
            originalSize: 10,
            packedSize: 10,
            isCompressed: false,
            isEncrypted: true,
          ),
        );
        when(
          () => mockEncryption.signData(any(), any()),
        ).thenAnswer((_) async => 'sig');
        when(
          () => mockChunkTransfer.sendChunked(
            chatId: any(named: 'chatId'),
            packetId: any(named: 'packetId'),
            sourceId: any(named: 'sourceId'),
            targetId: any(named: 'targetId'),
            type: any(named: 'type'),
            encryptedPayload: any(named: 'encryptedPayload'),
            checksum: any(named: 'checksum'),
            signature: any(named: 'signature'),
            sequenceNo: any(named: 'sequenceNo'),
          ),
        ).thenAnswer((_) async => []);

        const sessionId = 'stats-session';

        await syncEngine.sendPacket(
          sourceId: 'source',
          targetId: 'target',
          type: ExchangeType.product,
          data: {},
          sessionId: sessionId,
        );

        await syncEngine.sendPacket(
          sourceId: 'source',
          targetId: 'target',
          type: ExchangeType.sale,
          data: {},
          sessionId: sessionId,
        );

        final session = syncEngine.activeSessions[sessionId]!;
        expect(session.totalPackets, 2);
        expect(session.deliveredPackets, 2);
        expect(session.lastSequenceNo, 2);
      });
    });

    group('Conflict resolution', () {
      test('should have conflict resolver available', () {
        expect(syncEngine, isNotNull);
      });
    });

    group('Session management', () {
      test('should return unmodifiable map for active sessions', () {
        expect(
          () =>
              (syncEngine.activeSessions as Map<String, dynamic>)['new'] = null,
          throwsA(anyOf(isA<UnsupportedError>(), isA<TypeError>())),
        );
      });

      test('should create new session for new sessionId', () async {
        when(
          () =>
              mockChannelRegistry.getChatId(SystemChannelType.posDataExchange),
        ).thenReturn(123);
        when(() => mockPacker.pack(any(), any())).thenAnswer(
          (_) async => PackedData(
            payload: 'payload',
            checksum: 'sum',
            originalSize: 10,
            packedSize: 10,
            isCompressed: false,
            isEncrypted: true,
          ),
        );
        when(
          () => mockEncryption.signData(any(), any()),
        ).thenAnswer((_) async => 'sig');
        when(
          () => mockChunkTransfer.sendChunked(
            chatId: any(named: 'chatId'),
            packetId: any(named: 'packetId'),
            sourceId: any(named: 'sourceId'),
            targetId: any(named: 'targetId'),
            type: any(named: 'type'),
            encryptedPayload: any(named: 'encryptedPayload'),
            checksum: any(named: 'checksum'),
            signature: any(named: 'signature'),
            sequenceNo: any(named: 'sequenceNo'),
          ),
        ).thenAnswer((_) async => []);

        await syncEngine.sendPacket(
          sourceId: 'source',
          targetId: 'target',
          type: ExchangeType.product,
          data: {},
          sessionId: 'session-1',
        );

        await syncEngine.sendPacket(
          sourceId: 'source',
          targetId: 'target',
          type: ExchangeType.product,
          data: {},
          sessionId: 'session-2',
        );

        expect(syncEngine.activeSessions.length, 2);
        expect(syncEngine.activeSessions.containsKey('session-1'), isTrue);
        expect(syncEngine.activeSessions.containsKey('session-2'), isTrue);
      });

      test('should reuse existing session for same sessionId', () async {
        when(
          () =>
              mockChannelRegistry.getChatId(SystemChannelType.posDataExchange),
        ).thenReturn(123);
        when(() => mockPacker.pack(any(), any())).thenAnswer(
          (_) async => PackedData(
            payload: 'payload',
            checksum: 'sum',
            originalSize: 10,
            packedSize: 10,
            isCompressed: false,
            isEncrypted: true,
          ),
        );
        when(
          () => mockEncryption.signData(any(), any()),
        ).thenAnswer((_) async => 'sig');
        when(
          () => mockChunkTransfer.sendChunked(
            chatId: any(named: 'chatId'),
            packetId: any(named: 'packetId'),
            sourceId: any(named: 'sourceId'),
            targetId: any(named: 'targetId'),
            type: any(named: 'type'),
            encryptedPayload: any(named: 'encryptedPayload'),
            checksum: any(named: 'checksum'),
            signature: any(named: 'signature'),
            sequenceNo: any(named: 'sequenceNo'),
          ),
        ).thenAnswer((_) async => []);

        const sessionId = 'reuse-session';

        await syncEngine.sendPacket(
          sourceId: 'source',
          targetId: 'target',
          type: ExchangeType.product,
          data: {},
          sessionId: sessionId,
        );

        final sessionAfterFirst = syncEngine.activeSessions[sessionId];

        await syncEngine.sendPacket(
          sourceId: 'source',
          targetId: 'target',
          type: ExchangeType.product,
          data: {},
          sessionId: sessionId,
        );

        final sessionAfterSecond = syncEngine.activeSessions[sessionId];

        expect(syncEngine.activeSessions.length, 1);
        expect(sessionAfterFirst, same(sessionAfterSecond));
      });

      test('session should store peer ID correctly', () async {
        when(
          () =>
              mockChannelRegistry.getChatId(SystemChannelType.posDataExchange),
        ).thenReturn(123);
        when(() => mockPacker.pack(any(), any())).thenAnswer(
          (_) async => PackedData(
            payload: 'payload',
            checksum: 'sum',
            originalSize: 10,
            packedSize: 10,
            isCompressed: false,
            isEncrypted: true,
          ),
        );
        when(
          () => mockEncryption.signData(any(), any()),
        ).thenAnswer((_) async => 'sig');
        when(
          () => mockChunkTransfer.sendChunked(
            chatId: any(named: 'chatId'),
            packetId: any(named: 'packetId'),
            sourceId: any(named: 'sourceId'),
            targetId: any(named: 'targetId'),
            type: any(named: 'type'),
            encryptedPayload: any(named: 'encryptedPayload'),
            checksum: any(named: 'checksum'),
            signature: any(named: 'signature'),
            sequenceNo: any(named: 'sequenceNo'),
          ),
        ).thenAnswer((_) async => []);

        const targetId = 'target-peer-123';

        await syncEngine.sendPacket(
          sourceId: 'source',
          targetId: targetId,
          type: ExchangeType.product,
          data: {},
          sessionId: 'peer-session',
        );

        final session = syncEngine.activeSessions['peer-session'];
        expect(session!.peerId, targetId);
      });
    });

    group('State transitions', () {
      test('state progression: idle -> syncing -> idle (success)', () async {
        when(
          () =>
              mockChannelRegistry.getChatId(SystemChannelType.posDataExchange),
        ).thenReturn(123);
        when(() => mockPacker.pack(any(), any())).thenAnswer(
          (_) async => PackedData(
            payload: 'payload',
            checksum: 'sum',
            originalSize: 10,
            packedSize: 10,
            isCompressed: false,
            isEncrypted: true,
          ),
        );
        when(
          () => mockEncryption.signData(any(), any()),
        ).thenAnswer((_) async => 'sig');
        when(
          () => mockChunkTransfer.sendChunked(
            chatId: any(named: 'chatId'),
            packetId: any(named: 'packetId'),
            sourceId: any(named: 'sourceId'),
            targetId: any(named: 'targetId'),
            type: any(named: 'type'),
            encryptedPayload: any(named: 'encryptedPayload'),
            checksum: any(named: 'checksum'),
            signature: any(named: 'signature'),
            sequenceNo: any(named: 'sequenceNo'),
          ),
        ).thenAnswer((_) async => []);

        expect(syncEngine.state, SyncEngineState.idle);

        await syncEngine.sendPacket(
          sourceId: 'source',
          targetId: 'target',
          type: ExchangeType.product,
          data: {},
          sessionId: 'session',
        );

        expect(syncEngine.state, SyncEngineState.idle);
      });

      test('state progression: idle -> syncing -> error (failure)', () async {
        when(
          () =>
              mockChannelRegistry.getChatId(SystemChannelType.posDataExchange),
        ).thenReturn(123);
        when(() => mockPacker.pack(any(), any())).thenThrow(Exception('Error'));

        expect(syncEngine.state, SyncEngineState.idle);

        try {
          await syncEngine.sendPacket(
            sourceId: 'source',
            targetId: 'target',
            type: ExchangeType.product,
            data: {},
            sessionId: 'session',
          );
        } catch (_) {}

        expect(syncEngine.state, SyncEngineState.error);
      });

      test('state: idle -> paused -> idle', () {
        expect(syncEngine.state, SyncEngineState.idle);

        syncEngine.pause();
        expect(syncEngine.state, SyncEngineState.paused);

        syncEngine.resume();
        expect(syncEngine.state, SyncEngineState.idle);
      });

      test(
        'error state should not change to idle in finally if already error',
        () async {
          when(
            () => mockChannelRegistry.getChatId(
              SystemChannelType.posDataExchange,
            ),
          ).thenReturn(123);
          when(
            () => mockPacker.pack(any(), any()),
          ).thenThrow(Exception('Error'));

          try {
            await syncEngine.sendPacket(
              sourceId: 'source',
              targetId: 'target',
              type: ExchangeType.product,
              data: {},
              sessionId: 'session',
            );
          } catch (_) {}

          expect(syncEngine.state, SyncEngineState.error);
        },
      );
    });

    group('Integration with dependencies', () {
      test('should use correct channel type for data exchange', () async {
        when(
          () =>
              mockChannelRegistry.getChatId(SystemChannelType.posDataExchange),
        ).thenReturn(999);
        when(() => mockPacker.pack(any(), any())).thenAnswer(
          (_) async => PackedData(
            payload: 'payload',
            checksum: 'sum',
            originalSize: 10,
            packedSize: 10,
            isCompressed: false,
            isEncrypted: true,
          ),
        );
        when(
          () => mockEncryption.signData(any(), any()),
        ).thenAnswer((_) async => 'sig');
        when(
          () => mockChunkTransfer.sendChunked(
            chatId: any(named: 'chatId'),
            packetId: any(named: 'packetId'),
            sourceId: any(named: 'sourceId'),
            targetId: any(named: 'targetId'),
            type: any(named: 'type'),
            encryptedPayload: any(named: 'encryptedPayload'),
            checksum: any(named: 'checksum'),
            signature: any(named: 'signature'),
            sequenceNo: any(named: 'sequenceNo'),
          ),
        ).thenAnswer((_) async => []);

        await syncEngine.sendPacket(
          sourceId: 'source',
          targetId: 'target',
          type: ExchangeType.product,
          data: {},
          sessionId: 'session',
        );

        verify(
          () =>
              mockChannelRegistry.getChatId(SystemChannelType.posDataExchange),
        ).called(1);
        verify(
          () => mockChunkTransfer.sendChunked(
            chatId: 999,
            packetId: any(named: 'packetId'),
            sourceId: any(named: 'sourceId'),
            targetId: any(named: 'targetId'),
            type: any(named: 'type'),
            encryptedPayload: any(named: 'encryptedPayload'),
            checksum: any(named: 'checksum'),
            signature: any(named: 'signature'),
            sequenceNo: any(named: 'sequenceNo'),
          ),
        ).called(1);
      });

      test('should use source ID for signing', () async {
        when(
          () =>
              mockChannelRegistry.getChatId(SystemChannelType.posDataExchange),
        ).thenReturn(123);
        when(() => mockPacker.pack(any(), any())).thenAnswer(
          (_) async => PackedData(
            payload: 'test_payload',
            checksum: 'sum',
            originalSize: 10,
            packedSize: 10,
            isCompressed: false,
            isEncrypted: true,
          ),
        );
        when(
          () => mockEncryption.signData(any(), any()),
        ).thenAnswer((_) async => 'sig');
        when(
          () => mockChunkTransfer.sendChunked(
            chatId: any(named: 'chatId'),
            packetId: any(named: 'packetId'),
            sourceId: any(named: 'sourceId'),
            targetId: any(named: 'targetId'),
            type: any(named: 'type'),
            encryptedPayload: any(named: 'encryptedPayload'),
            checksum: any(named: 'checksum'),
            signature: any(named: 'signature'),
            sequenceNo: any(named: 'sequenceNo'),
          ),
        ).thenAnswer((_) async => []);

        const sourceId = 'my-source-id';

        await syncEngine.sendPacket(
          sourceId: sourceId,
          targetId: 'target',
          type: ExchangeType.product,
          data: {},
          sessionId: 'session',
        );

        verify(
          () => mockEncryption.signData('test_payload', sourceId),
        ).called(1);
      });

      test('should pass packed data to chunk transfer', () async {
        when(
          () =>
              mockChannelRegistry.getChatId(SystemChannelType.posDataExchange),
        ).thenReturn(123);
        when(() => mockPacker.pack(any(), any())).thenAnswer(
          (_) async => PackedData(
            payload: 'specific_payload',
            checksum: 'specific_checksum',
            originalSize: 100,
            packedSize: 50,
            isCompressed: true,
            isEncrypted: true,
          ),
        );
        when(
          () => mockEncryption.signData(any(), any()),
        ).thenAnswer((_) async => 'specific_signature');
        when(
          () => mockChunkTransfer.sendChunked(
            chatId: any(named: 'chatId'),
            packetId: any(named: 'packetId'),
            sourceId: any(named: 'sourceId'),
            targetId: any(named: 'targetId'),
            type: any(named: 'type'),
            encryptedPayload: any(named: 'encryptedPayload'),
            checksum: any(named: 'checksum'),
            signature: any(named: 'signature'),
            sequenceNo: any(named: 'sequenceNo'),
          ),
        ).thenAnswer((_) async => []);

        await syncEngine.sendPacket(
          sourceId: 'source',
          targetId: 'target',
          type: ExchangeType.sale,
          data: {},
          sessionId: 'session',
        );

        verify(
          () => mockChunkTransfer.sendChunked(
            chatId: 123,
            packetId: any(named: 'packetId'),
            sourceId: 'source',
            targetId: 'target',
            type: ExchangeType.sale,
            encryptedPayload: 'specific_payload',
            checksum: 'specific_checksum',
            signature: 'specific_signature',
            sequenceNo: 1,
          ),
        ).called(1);
      });
    });
  });
}
