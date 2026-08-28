import 'dart:convert';
import 'dart:io';

import 'queue_storage.dart';
import 'queued_operation.dart';

class QueueStorageImpl implements QueueStorage {
  final String filePath;

  final Map<String, QueuedOperation> _cache = {};

  bool _initialized = false;

  DateTime? _lastSaveTime;
  static const _saveDebounce = Duration(milliseconds: 500);

  QueueStorageImpl({required this.filePath});

  factory QueueStorageImpl.defaultPath(String baseDir) {
    return QueueStorageImpl(filePath: '$baseDir/transport_queue.json');
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    final file = File(filePath);
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final operations = json['operations'] as List<dynamic>? ?? [];

        for (final opJson in operations) {
          final operation = QueuedOperation.fromJson(
            opJson as Map<String, dynamic>,
          );
          _cache[operation.id] = operation;
        }
      } catch (e) {
        _cache.clear();
      }
    }

    _initialized = true;
  }

  @override
  Future<void> add(QueuedOperation operation) async {
    _ensureInitialized();
    _cache[operation.id] = operation;
    await _save();
  }

  @override
  Future<void> addAll(List<QueuedOperation> operations) async {
    _ensureInitialized();
    for (final op in operations) {
      _cache[op.id] = op;
    }
    await _save();
  }

  @override
  Future<void> update(QueuedOperation operation) async {
    _ensureInitialized();
    _cache[operation.id] = operation;
    await _save();
  }

  @override
  Future<void> remove(String operationId) async {
    _ensureInitialized();
    _cache.remove(operationId);
    await _save();
  }

  @override
  Future<void> removeAll(List<String> operationIds) async {
    _ensureInitialized();
    for (final id in operationIds) {
      _cache.remove(id);
    }
    await _save();
  }

  @override
  Future<QueuedOperation?> get(String operationId) async {
    _ensureInitialized();
    return _cache[operationId];
  }

  @override
  Future<List<QueuedOperation>> getAll() async {
    _ensureInitialized();
    return _cache.values.toList();
  }

  @override
  Future<List<QueuedOperation>> getByStatus(
    QueuedOperationStatus status,
  ) async {
    _ensureInitialized();
    return _cache.values.where((op) => op.status == status).toList();
  }

  @override
  Future<List<QueuedOperation>> getPendingOperations() async {
    _ensureInitialized();
    final now = DateTime.now();

    return _cache.values
        .where(
          (op) =>
              (op.status == QueuedOperationStatus.pending ||
                  op.status == QueuedOperationStatus.retrying) &&
              (op.nextAttemptAt == null || op.nextAttemptAt!.isBefore(now)),
        )
        .toList()
      ..sort((a, b) {
        final priorityCompare = b.priority.compareTo(a.priority);
        if (priorityCompare != 0) return priorityCompare;
        return a.createdAt.compareTo(b.createdAt);
      });
  }

  @override
  Future<List<QueuedOperation>> getByGroup(String groupId) async {
    _ensureInitialized();
    return _cache.values.where((op) => op.groupId == groupId).toList();
  }

  @override
  Future<int> count() async {
    _ensureInitialized();
    return _cache.length;
  }

  @override
  Future<int> countByStatus(QueuedOperationStatus status) async {
    _ensureInitialized();
    return _cache.values.where((op) => op.status == status).length;
  }

  @override
  Future<int> clearCompleted({Duration age = const Duration(days: 7)}) async {
    _ensureInitialized();
    final cutoff = DateTime.now().subtract(age);
    int removed = 0;

    _cache.removeWhere((id, op) {
      if ((op.status == QueuedOperationStatus.completed ||
              op.status == QueuedOperationStatus.failed ||
              op.status == QueuedOperationStatus.cancelled) &&
          (op.lastAttemptAt?.isBefore(cutoff) ??
              op.createdAt.isBefore(cutoff))) {
        removed++;
        return true;
      }
      return false;
    });

    if (removed > 0) {
      await _save();
    }
    return removed;
  }

  @override
  Future<void> clearAll() async {
    _ensureInitialized();
    _cache.clear();
    await _save();
  }

  @override
  Future<void> dispose() async {
    await _forceSave();
    _cache.clear();
    _initialized = false;
  }

  Future<QueueStatistics> getStatistics() async {
    _ensureInitialized();

    int pending = 0;
    int inProgress = 0;
    int retrying = 0;
    int completed = 0;
    int failed = 0;
    int cancelled = 0;

    for (final op in _cache.values) {
      switch (op.status) {
        case QueuedOperationStatus.pending:
          pending++;
        case QueuedOperationStatus.inProgress:
          inProgress++;
        case QueuedOperationStatus.retrying:
          retrying++;
        case QueuedOperationStatus.completed:
          completed++;
        case QueuedOperationStatus.failed:
          failed++;
        case QueuedOperationStatus.cancelled:
          cancelled++;
      }
    }

    return QueueStatistics(
      total: _cache.length,
      pending: pending,
      inProgress: inProgress,
      retrying: retrying,
      completed: completed,
      failed: failed,
      cancelled: cancelled,
    );
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'QueueStorage not initialized. Call initialize() first.',
      );
    }
  }

  Future<void> _save() async {
    final now = DateTime.now();
    if (_lastSaveTime != null &&
        now.difference(_lastSaveTime!) < _saveDebounce) {
      return;
    }

    await _forceSave();
  }

  Future<void> _forceSave() async {
    _lastSaveTime = DateTime.now();

    final file = File(filePath);
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final json = {
      'version': 1,
      'savedAt': DateTime.now().toIso8601String(),
      'operations': _cache.values.map((op) => op.toJson()).toList(),
    };

    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
  }
}
