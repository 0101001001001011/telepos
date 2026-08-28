import 'dart:async';

import 'transport_result.dart';
import 'transport_status.dart';

abstract class TransportInterface {
  String get name;

  Future<bool> isAvailable();

  Stream<TransportStatus> get statusStream;

  TransportStatus get currentStatus;

  Future<TransportResult<void>> uploadSales(List<Map<String, dynamic>> sales);

  Future<TransportResult<void>> uploadRefunds(
    List<Map<String, dynamic>> refunds,
  );

  Future<TransportResult<void>> uploadShifts(List<Map<String, dynamic>> shifts);

  Future<TransportResult<void>> uploadCashOperations(
    List<Map<String, dynamic>> operations,
  );

  Future<TransportResult<List<Map<String, dynamic>>>> downloadProducts({
    DateTime? since,
  });

  Future<TransportResult<List<Map<String, dynamic>>>> downloadPrices({
    DateTime? since,
  });

  Future<TransportResult<List<Map<String, dynamic>>>> downloadCategories({
    DateTime? since,
  });

  Future<TransportResult<List<Map<String, dynamic>>>> downloadAgents({
    DateTime? since,
  });

  Future<TransportResult<Map<String, dynamic>>> downloadConfig();

  Future<TransportResult<List<Map<String, dynamic>>>> downloadUsers();

  Future<TransportResult<String>> uploadBackup({
    required String filePath,
    required Map<String, dynamic> metadata,
  });

  Future<TransportResult<List<Map<String, dynamic>>>> listBackups();

  Future<TransportResult<String>> downloadBackup(String backupId);

  Future<TransportResult<void>> deleteBackup(String backupId);

  Future<TransportResult<void>> sendNotification({
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  });

  Future<TransportResult<void>> sendReport({
    required String type,
    required Map<String, dynamic> data,
    String? filePath,
  });

  Stream<TransportUpdate> get updates;

  Future<void> subscribeToUpdates(List<String> types);

  Future<void> unsubscribeFromUpdates();

  Future<void> initialize();

  Future<void> dispose();
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
