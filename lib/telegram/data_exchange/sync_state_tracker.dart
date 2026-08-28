import 'package:shared_preferences/shared_preferences.dart';
import 'package:telepos/domain/entities/telegram/sync_packet.dart';

class SyncStateTracker {
  SyncStateTracker({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;

  static const String _keyPrefix = 'sync_last_timestamp_';

  static const String _statusPrefix = 'sync_status_';

  int getLastSync(ExchangeType type) {
    return _prefs.getInt('$_keyPrefix${type.name}') ?? 0;
  }

  DateTime? getLastSyncDateTime(ExchangeType type) {
    final timestamp = getLastSync(type);
    if (timestamp == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  }

  Future<void> setLastSync(ExchangeType type, int timestamp) async {
    await _prefs.setInt('$_keyPrefix${type.name}', timestamp);
  }

  Future<void> markSynced(ExchangeType type) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await setLastSync(type, timestamp);
  }

  Map<ExchangeType, int> getAllLastSync() {
    final result = <ExchangeType, int>{};
    for (final type in ExchangeType.values) {
      result[type] = getLastSync(type);
    }
    return result;
  }

  Future<void> reset(ExchangeType type) async {
    await _prefs.remove('$_keyPrefix${type.name}');
  }

  Future<void> resetAll() async {
    for (final type in ExchangeType.values) {
      await reset(type);
    }
  }

  Future<void> clearAll() async {
    await resetAll();
  }

  SyncStatus? getStatus(ExchangeType type) {
    final status = _prefs.getString('$_statusPrefix${type.name}');
    if (status == null) return null;

    return SyncStatus.values.firstWhere(
      (s) => s.name == status,
      orElse: () => SyncStatus.unknown,
    );
  }

  Future<void> setStatus(ExchangeType type, SyncStatus status) async {
    await _prefs.setString('$_statusPrefix${type.name}', status.name);
  }

  SyncStateSnapshot getSnapshot() {
    final timestamps = <ExchangeType, int>{};
    final statuses = <ExchangeType, SyncStatus>{};

    for (final type in ExchangeType.values) {
      timestamps[type] = getLastSync(type);
      statuses[type] = getStatus(type) ?? SyncStatus.unknown;
    }

    return SyncStateSnapshot(
      timestamps: timestamps,
      statuses: statuses,
      capturedAt: DateTime.now(),
    );
  }

  bool needsSync(
    ExchangeType type, {
    Duration maxAge = const Duration(minutes: 5),
  }) {
    final lastSync = getLastSyncDateTime(type);
    if (lastSync == null) return true;

    return DateTime.now().difference(lastSync) > maxAge;
  }

  List<ExchangeType> getTypesNeedingSync({
    Duration maxAge = const Duration(minutes: 5),
  }) {
    return ExchangeType.values
        .where((type) => needsSync(type, maxAge: maxAge))
        .toList();
  }
}

enum SyncStatus { unknown, inProgress, success, error, pending }

class SyncStateSnapshot {
  const SyncStateSnapshot({
    required this.timestamps,
    required this.statuses,
    required this.capturedAt,
  });

  final Map<ExchangeType, int> timestamps;

  final Map<ExchangeType, SyncStatus> statuses;

  final DateTime capturedAt;

  bool get allSynced => statuses.values.every((s) => s == SyncStatus.success);

  bool get hasErrors => statuses.values.any((s) => s == SyncStatus.error);

  int get errorCount =>
      statuses.values.where((s) => s == SyncStatus.error).length;

  DateTime? get latestSync {
    final maxTimestamp = timestamps.values.fold<int>(
      0,
      (a, b) => a > b ? a : b,
    );
    if (maxTimestamp == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(maxTimestamp * 1000);
  }

  DateTime? get oldestSync {
    final nonZero = timestamps.values.where((t) => t > 0).toList();
    if (nonZero.isEmpty) return null;
    final minTimestamp = nonZero.fold<int>(
      nonZero.first,
      (a, b) => a < b ? a : b,
    );
    return DateTime.fromMillisecondsSinceEpoch(minTimestamp * 1000);
  }

  @override
  String toString() {
    return 'SyncStateSnapshot('
        'latestSync: $latestSync, '
        'allSynced: $allSynced, '
        'errorCount: $errorCount)';
  }
}
