import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:telepos/domain/repositories/telegram_repository.dart';
import 'package:telepos/domain/entities/telegram/auth_state.dart';
import 'package:telepos/telegram/auth/telegram_auth_service.dart';
import 'package:telepos/telegram/channels/channel_registry.dart';
import 'package:telepos/telegram/data_exchange/telegram_sync_engine.dart';
import 'package:telepos/telegram/encryption/encryption_key_store.dart';
import 'package:telepos/telegram/internal_chat/staff_chat_service.dart';
import 'package:telepos/telegram/messaging/realtime_updates.dart';
import 'package:telepos/domain/entities/telegram/exchange_envelope.dart';
import 'package:telepos/domain/entities/telegram/notification_payload.dart';
import 'package:telepos/domain/entities/telegram/sync_packet.dart';
import 'package:telepos/domain/entities/telegram/telegram_message.dart';
import 'package:telepos/telegram/notifications/notification_service.dart';

class TelegramRepositoryImpl implements TelegramRepository {
  final TelegramAuthService _authService;
  final TelegramSyncEngine _syncEngine;
  final NotificationService _notificationService;
  final StaffChatService _staffChatService;
  final RealtimeUpdates _realtimeUpdates; // ignore: unused_field
  final ChannelRegistry? _channelRegistry;
  final EncryptionKeyStore? _keyStore;

  TelegramRepositoryImpl({
    required TelegramAuthService authService,
    required TelegramSyncEngine syncEngine,
    required NotificationService notificationService,
    required StaffChatService staffChatService,
    required RealtimeUpdates realtimeUpdates,
    ChannelRegistry? channelRegistry,
    EncryptionKeyStore? keyStore,
  }) : _authService = authService,
       _syncEngine = syncEngine,
       _notificationService = notificationService,
       _staffChatService = staffChatService,
       _realtimeUpdates = realtimeUpdates,
       _channelRegistry = channelRegistry,
       _keyStore = keyStore;

  @override
  Future<Either<TelegramFailure, TelegramAuthState>> authenticate(
    String phone,
  ) async {
    try {
      await _authService.startPhoneAuth(phone);
      return Right(_authService.currentState);
    } catch (e) {
      return Left(TelegramFailure(message: e.toString(), originalError: e));
    }
  }

  @override
  Future<Either<TelegramFailure, TelegramAuthState>> authenticateQr() async {
    try {
      await _authService.startQrAuth();
      return Right(_authService.currentState);
    } catch (e) {
      return Left(TelegramFailure(message: e.toString(), originalError: e));
    }
  }

  @override
  Future<Either<TelegramFailure, TelegramAuthState>> confirmCode(
    String code,
  ) async {
    try {
      await _authService.submitCode(code);
      return Right(_authService.currentState);
    } catch (e) {
      return Left(TelegramFailure(message: e.toString(), originalError: e));
    }
  }

  @override
  Future<Either<TelegramFailure, TelegramAuthState>> confirmPassword(
    String password,
  ) async {
    try {
      await _authService.submitPassword(password);
      return Right(_authService.currentState);
    } catch (e) {
      return Left(TelegramFailure(message: e.toString(), originalError: e));
    }
  }

  @override
  Future<Either<TelegramFailure, void>> submitIdentityDocuments(
    List<String> documentPaths,
  ) async {
    try {
      await _authService.submitIdentityDocuments(
        documentPaths: documentPaths,
        documentTypes: [],
      );
      return const Right(null);
    } catch (e) {
      return Left(TelegramFailure(message: e.toString(), originalError: e));
    }
  }

  @override
  Stream<TelegramAuthState> get authState => _authService.stateStream;

  @override
  bool get isAuthorized => _authService.isAuthorized;

  @override
  Future<Either<TelegramFailure, void>> logOut() async {
    try {
      await _authService.logOut();
      return const Right(null);
    } catch (e) {
      return Left(TelegramFailure(message: e.toString(), originalError: e));
    }
  }

  @override
  Future<Either<TelegramFailure, void>> sendDataPacket(
    ExchangeEnvelope envelope,
  ) async {
    try {
      await _syncEngine.sendPacket(
        sourceId: envelope.sourceId,
        targetId: envelope.targetId,
        type: envelope.type,
        data: {'encryptedPayload': envelope.encryptedPayload},
        sessionId: envelope.sourceId,
      );
      return const Right(null);
    } catch (e) {
      return Left(TelegramFailure(message: e.toString(), originalError: e));
    }
  }

  @override
  Stream<ExchangeEnvelope> receiveDataPackets() {
    return const Stream.empty();
  }

  @override
  Future<Either<TelegramFailure, void>> syncData(ExchangeType type) async {
    try {
      await _syncEngine.syncType(type);
      return const Right(null);
    } catch (e) {
      return Left(TelegramFailure(message: e.toString(), originalError: e));
    }
  }

  @override
  Future<Either<TelegramFailure, void>> syncAll() async {
    try {
      await _syncEngine.syncAll();
      return const Right(null);
    } catch (e) {
      return Left(TelegramFailure(message: e.toString(), originalError: e));
    }
  }

  @override
  Future<Either<TelegramFailure, void>> sendNotification(
    NotificationPayload payload,
  ) async {
    try {
      await _notificationService.send(payload);
      return const Right(null);
    } catch (e) {
      return Left(TelegramFailure(message: e.toString(), originalError: e));
    }
  }

  @override
  Future<Either<TelegramFailure, void>> sendCriticalNotification(
    NotificationPayload payload,
  ) async {
    try {
      await _notificationService.sendCritical(payload);
      return const Right(null);
    } catch (e) {
      return Left(TelegramFailure(message: e.toString(), originalError: e));
    }
  }

  @override
  Stream<TelegramMessage> getStaffMessages() {
    return _staffChatService.messages;
  }

  @override
  Future<Either<TelegramFailure, TelegramMessage>> sendStaffMessage(
    String text,
  ) async {
    try {
      final msg = await _staffChatService.sendMessage(text);
      return Right(msg);
    } catch (e) {
      return Left(TelegramFailure(message: e.toString(), originalError: e));
    }
  }

  @override
  Future<Either<TelegramFailure, List<TelegramMessage>>> getStaffChatHistory({
    int limit = 50,
  }) async {
    try {
      final messages = await _staffChatService.getHistory(limit: limit);
      return Right(messages);
    } catch (e) {
      return Left(TelegramFailure(message: e.toString(), originalError: e));
    }
  }

  @override
  Future<Either<TelegramFailure, String>> createChannel({
    required String title,
    required String description,
  }) async {
    try {
      return Right('channel_created:$title');
    } catch (e) {
      return Left(TelegramFailure(message: e.toString(), originalError: e));
    }
  }

  @override
  bool get isConnected => _authService.isAuthorized;

  @override
  Stream<bool> get connectionState => _authService.stateStream.map(
    (state) => state is TelegramAuthStateAuthorized,
  );

  @override
  Future<bool> isConfigured() async {
    if (!_authService.isAuthorized) {
      return false;
    }

    final registry = _channelRegistry;
    if (registry != null) {
      await registry.restore();
      if (!registry.isComplete) {
        return false;
      }
    }

    final keyStore = _keyStore;
    if (keyStore != null) {
      final hasKeys = await keyStore.hasKeys();
      if (!hasKeys) {
        return false;
      }
    }

    return true;
  }
}
