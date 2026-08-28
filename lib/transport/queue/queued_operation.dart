import 'dart:convert';

import '../interface/transport_interface_exports.dart';

enum QueuedOperationStatus {
  pending,

  inProgress,

  retrying,

  completed,

  failed,

  cancelled,
}

class QueuedOperation {
  final String id;

  final TransportOperation operation;

  final String payload;

  final TransportType preferredTransport;

  final QueuedOperationStatus status;

  final int attemptCount;

  final int maxAttempts;

  final DateTime createdAt;

  final DateTime? lastAttemptAt;

  final DateTime? nextAttemptAt;

  final String? lastError;

  final int priority;

  final String? groupId;

  final Map<String, dynamic> metadata;

  const QueuedOperation({
    required this.id,
    required this.operation,
    required this.payload,
    this.preferredTransport = TransportType.none,
    this.status = QueuedOperationStatus.pending,
    this.attemptCount = 0,
    this.maxAttempts = 5,
    required this.createdAt,
    this.lastAttemptAt,
    this.nextAttemptAt,
    this.lastError,
    this.priority = 0,
    this.groupId,
    this.metadata = const {},
  });

  factory QueuedOperation.create({
    required String id,
    required TransportOperation operation,
    required Map<String, dynamic> data,
    TransportType preferredTransport = TransportType.none,
    int maxAttempts = 5,
    int priority = 0,
    String? groupId,
    Map<String, dynamic> metadata = const {},
  }) {
    return QueuedOperation(
      id: id,
      operation: operation,
      payload: jsonEncode(data),
      preferredTransport: preferredTransport,
      status: QueuedOperationStatus.pending,
      attemptCount: 0,
      maxAttempts: maxAttempts,
      createdAt: DateTime.now(),
      nextAttemptAt: DateTime.now(),
      priority: priority,
      groupId: groupId,
      metadata: metadata,
    );
  }

  factory QueuedOperation.critical({
    required String id,
    required TransportOperation operation,
    required Map<String, dynamic> data,
    TransportType preferredTransport = TransportType.none,
    String? groupId,
  }) {
    return QueuedOperation.create(
      id: id,
      operation: operation,
      data: data,
      preferredTransport: preferredTransport,
      maxAttempts: 10,
      priority: 100,
      groupId: groupId,
      metadata: {'critical': true},
    );
  }

  Map<String, dynamic> get data {
    try {
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  bool get canExecuteNow {
    if (status != QueuedOperationStatus.pending &&
        status != QueuedOperationStatus.retrying) {
      return false;
    }

    if (nextAttemptAt == null) return true;
    return DateTime.now().isAfter(nextAttemptAt!);
  }

  bool get hasRemainingAttempts => attemptCount < maxAttempts;

  bool get isCritical => operation.isCritical || priority >= 100;

  Duration? get timeUntilNextAttempt {
    if (nextAttemptAt == null) return null;
    final remaining = nextAttemptAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  DateTime _calculateNextAttempt(int attempt) {
    final delaySeconds = (1 << attempt).clamp(1, 600);
    return DateTime.now().add(Duration(seconds: delaySeconds));
  }

  QueuedOperation markInProgress() {
    return copyWith(
      status: QueuedOperationStatus.inProgress,
      lastAttemptAt: DateTime.now(),
    );
  }

  QueuedOperation markCompleted() {
    return copyWith(
      status: QueuedOperationStatus.completed,
      lastAttemptAt: DateTime.now(),
    );
  }

  QueuedOperation markForRetry(String error) {
    final newAttempt = attemptCount + 1;

    if (newAttempt >= maxAttempts) {
      return markFailed(error);
    }

    return copyWith(
      status: QueuedOperationStatus.retrying,
      attemptCount: newAttempt,
      lastAttemptAt: DateTime.now(),
      nextAttemptAt: _calculateNextAttempt(newAttempt),
      lastError: error,
    );
  }

  QueuedOperation markFailed(String error) {
    return copyWith(
      status: QueuedOperationStatus.failed,
      lastAttemptAt: DateTime.now(),
      lastError: error,
    );
  }

  QueuedOperation markCancelled() {
    return copyWith(
      status: QueuedOperationStatus.cancelled,
      lastAttemptAt: DateTime.now(),
    );
  }

  QueuedOperation reset() {
    return copyWith(
      status: QueuedOperationStatus.pending,
      attemptCount: 0,
      lastAttemptAt: null,
      nextAttemptAt: DateTime.now(),
      lastError: null,
    );
  }

  QueuedOperation copyWith({
    String? id,
    TransportOperation? operation,
    String? payload,
    TransportType? preferredTransport,
    QueuedOperationStatus? status,
    int? attemptCount,
    int? maxAttempts,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    DateTime? nextAttemptAt,
    String? lastError,
    int? priority,
    String? groupId,
    Map<String, dynamic>? metadata,
  }) {
    return QueuedOperation(
      id: id ?? this.id,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      preferredTransport: preferredTransport ?? this.preferredTransport,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
      priority: priority ?? this.priority,
      groupId: groupId ?? this.groupId,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'operation': operation.name,
    'payload': payload,
    'preferredTransport': preferredTransport.name,
    'status': status.name,
    'attemptCount': attemptCount,
    'maxAttempts': maxAttempts,
    'createdAt': createdAt.toIso8601String(),
    if (lastAttemptAt != null)
      'lastAttemptAt': lastAttemptAt!.toIso8601String(),
    if (nextAttemptAt != null)
      'nextAttemptAt': nextAttemptAt!.toIso8601String(),
    if (lastError != null) 'lastError': lastError,
    'priority': priority,
    if (groupId != null) 'groupId': groupId,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  factory QueuedOperation.fromJson(Map<String, dynamic> json) {
    return QueuedOperation(
      id: json['id'] as String,
      operation: TransportOperation.values.byName(json['operation'] as String),
      payload: json['payload'] as String,
      preferredTransport: json['preferredTransport'] != null
          ? TransportType.values.byName(json['preferredTransport'] as String)
          : TransportType.none,
      status: QueuedOperationStatus.values.byName(json['status'] as String),
      attemptCount: json['attemptCount'] as int? ?? 0,
      maxAttempts: json['maxAttempts'] as int? ?? 5,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastAttemptAt: json['lastAttemptAt'] != null
          ? DateTime.parse(json['lastAttemptAt'] as String)
          : null,
      nextAttemptAt: json['nextAttemptAt'] != null
          ? DateTime.parse(json['nextAttemptAt'] as String)
          : null,
      lastError: json['lastError'] as String?,
      priority: json['priority'] as int? ?? 0,
      groupId: json['groupId'] as String?,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
    );
  }

  @override
  String toString() =>
      'QueuedOperation($id, $operation, status=$status, attempts=$attemptCount/$maxAttempts)';
}
