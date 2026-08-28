import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:telepos/domain/entities/telegram/auth_state.dart';
import 'package:telepos/domain/entities/telegram/exchange_envelope.dart';
import 'package:telepos/domain/entities/telegram/notification_payload.dart';
import 'package:telepos/domain/entities/telegram/sync_packet.dart';
import 'package:telepos/domain/entities/telegram/telegram_message.dart';

abstract class TelegramRepository {
  Future<Either<TelegramFailure, TelegramAuthState>> authenticate(String phone);

  Future<Either<TelegramFailure, TelegramAuthState>> authenticateQr();

  Future<Either<TelegramFailure, TelegramAuthState>> confirmCode(String code);

  Future<Either<TelegramFailure, TelegramAuthState>> confirmPassword(
    String password,
  );

  Future<Either<TelegramFailure, void>> submitIdentityDocuments(
    List<String> documentPaths,
  );

  Stream<TelegramAuthState> get authState;

  bool get isAuthorized;

  Future<Either<TelegramFailure, void>> logOut();

  Future<Either<TelegramFailure, void>> sendDataPacket(
    ExchangeEnvelope envelope,
  );

  Stream<ExchangeEnvelope> receiveDataPackets();

  Future<Either<TelegramFailure, void>> syncData(ExchangeType type);

  Future<Either<TelegramFailure, void>> syncAll();

  Future<Either<TelegramFailure, void>> sendNotification(
    NotificationPayload payload,
  );

  Future<Either<TelegramFailure, void>> sendCriticalNotification(
    NotificationPayload payload,
  );

  Stream<TelegramMessage> getStaffMessages();

  Future<Either<TelegramFailure, TelegramMessage>> sendStaffMessage(
    String text,
  );

  Future<Either<TelegramFailure, List<TelegramMessage>>> getStaffChatHistory({
    int limit = 50,
  });

  Future<Either<TelegramFailure, String>> createChannel({
    required String title,
    required String description,
  });

  bool get isConnected;

  Stream<bool> get connectionState;

  Future<bool> isConfigured();
}

class TelegramFailure {
  final String message;
  final int? code;
  final Object? originalError;

  TelegramFailure({required this.message, this.code, this.originalError});

  @override
  String toString() => 'TelegramFailure($code): $message';
}
