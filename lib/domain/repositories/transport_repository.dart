import 'dart:async';

import 'package:dartz/dartz.dart';

abstract class TransportRepository {
  Future<Either<TransportFailure, void>> uploadSales(
    List<Map<String, dynamic>> sales,
  );

  Future<Either<TransportFailure, void>> uploadRefunds(
    List<Map<String, dynamic>> refunds,
  );

  Future<Either<TransportFailure, void>> uploadShifts(
    List<Map<String, dynamic>> shifts,
  );

  Future<Either<TransportFailure, void>> uploadCashOperations(
    List<Map<String, dynamic>> operations,
  );

  Future<Either<TransportFailure, void>> uploadSupplies(
    List<Map<String, dynamic>> supplies,
  );

  Future<Either<TransportFailure, List<Map<String, dynamic>>>>
  downloadProducts({DateTime? since});

  Future<Either<TransportFailure, List<Map<String, dynamic>>>> downloadPrices({
    DateTime? since,
  });

  Future<Either<TransportFailure, List<Map<String, dynamic>>>>
  downloadCategories({DateTime? since});

  Future<Either<TransportFailure, List<Map<String, dynamic>>>> downloadAgents({
    DateTime? since,
  });

  Future<Either<TransportFailure, Map<String, dynamic>>> downloadConfig();

  Future<Either<TransportFailure, List<Map<String, dynamic>>>> downloadUsers();

  Future<Either<TransportFailure, List<Map<String, dynamic>>>> downloadStock();

  Future<Either<TransportFailure, String>> uploadBackup({
    required String filePath,
    required Map<String, dynamic> metadata,
  });

  Future<Either<TransportFailure, List<Map<String, dynamic>>>> listBackups();

  Future<Either<TransportFailure, String>> downloadBackup(String backupId);

  Future<Either<TransportFailure, void>> sendNotification({
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  });

  Future<Either<TransportFailure, void>> sendReport({
    required String type,
    required Map<String, dynamic> data,
    String? filePath,
  });

  Future<Either<TransportFailure, void>> subscribeToUpdates(
    List<String> channels,
  );

  Future<Either<TransportFailure, void>> unsubscribeFromUpdates();

  Stream<TransportUpdate> get updatesStream;

  Stream<RemoteCommand> get commandsStream;

  TransportConnectionStatus get connectionStatus;

  Stream<TransportConnectionStatus> get connectionStatusStream;

  bool get isConnected;

  TransportModeInfo get currentMode;

  Future<int> get queuedOperationsCount;

  Future<int> get failedOperationsCount;

  Future<void> processQueue();

  Future<void> retryFailedOperations();

  Future<void> initialize();

  Future<void> dispose();
}

class TransportFailure {
  final String message;
  final String? code;
  final bool isRetryable;
  final Object? originalError;

  const TransportFailure({
    required this.message,
    this.code,
    this.isRetryable = true,
    this.originalError,
  });

  factory TransportFailure.noConnection() => const TransportFailure(
    message: 'No network connection',
    code: 'NO_CONNECTION',
    isRetryable: true,
  );

  factory TransportFailure.timeout() => const TransportFailure(
    message: 'Request timeout',
    code: 'TIMEOUT',
    isRetryable: true,
  );

  factory TransportFailure.serverError(String message) => TransportFailure(
    message: message,
    code: 'SERVER_ERROR',
    isRetryable: true,
  );

  factory TransportFailure.unauthorized() => const TransportFailure(
    message: 'Unauthorized',
    code: 'UNAUTHORIZED',
    isRetryable: false,
  );

  factory TransportFailure.queued() => const TransportFailure(
    message: 'Operation queued for later execution',
    code: 'QUEUED',
    isRetryable: false,
  );

  @override
  String toString() => 'TransportFailure($code): $message';
}

class TransportConnectionStatus {
  final bool isConnected;
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final String? error;

  const TransportConnectionStatus({
    required this.isConnected,
    this.isSyncing = false,
    this.lastSyncTime,
    this.error,
  });

  factory TransportConnectionStatus.connected() =>
      const TransportConnectionStatus(isConnected: true);

  factory TransportConnectionStatus.disconnected() =>
      const TransportConnectionStatus(isConnected: false);

  factory TransportConnectionStatus.syncing() =>
      const TransportConnectionStatus(isConnected: true, isSyncing: true);

  TransportConnectionStatus copyWith({
    bool? isConnected,
    bool? isSyncing,
    DateTime? lastSyncTime,
    String? error,
  }) {
    return TransportConnectionStatus(
      isConnected: isConnected ?? this.isConnected,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      error: error,
    );
  }
}

class TransportModeInfo {
  final String name;
  final bool hasTelegram;
  final bool hasRest;
  final String? primaryTransport;

  const TransportModeInfo({
    required this.name,
    required this.hasTelegram,
    required this.hasRest,
    this.primaryTransport,
  });

  factory TransportModeInfo.restOnly() => const TransportModeInfo(
    name: 'REST API',
    hasTelegram: false,
    hasRest: true,
    primaryTransport: 'rest',
  );

  factory TransportModeInfo.telegramOnly() => const TransportModeInfo(
    name: 'Telegram',
    hasTelegram: true,
    hasRest: false,
    primaryTransport: 'telegram',
  );

  factory TransportModeInfo.hybrid() => const TransportModeInfo(
    name: 'Hybrid',
    hasTelegram: true,
    hasRest: true,
    primaryTransport: 'telegram',
  );
}

class TransportUpdate {
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const TransportUpdate({
    required this.type,
    required this.data,
    required this.timestamp,
  });
}

class RemoteCommand {
  final String commandId;
  final String type;
  final Map<String, dynamic> params;

  const RemoteCommand({
    required this.commandId,
    required this.type,
    required this.params,
  });
}
