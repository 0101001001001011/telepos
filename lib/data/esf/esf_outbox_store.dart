import 'package:telepos/domain/esf/esf_models.dart';

class EsfOutboxEntry {
  EsfOutboxEntry({
    required this.invoice,
    EsfStatus? status,
    this.attempts = 0,
    this.lastError,
    DateTime? createdAt,
  }) : status = status ?? EsfStatus.queued,
       createdAt = createdAt ?? invoice.issueDate;

  EsfInvoice invoice;

  EsfStatus status;

  int attempts;

  String? lastError;

  final DateTime createdAt;

  String get idempotencyKey => invoice.idempotencyKey;

  Map<String, dynamic> toJson() => {
    'invoice': invoice.toJson(),
    'status': status.name,
    'attempts': attempts,
    if (lastError != null) 'lastError': lastError,
    'createdAt': createdAt.toIso8601String(),
  };

  factory EsfOutboxEntry.fromJson(Map<String, dynamic> json) => EsfOutboxEntry(
    invoice: EsfInvoice.fromJson(
      (json['invoice'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    status: EsfStatus.values.byName(json['status'] as String? ?? 'queued'),
    attempts: json['attempts'] as int? ?? 0,
    lastError: json['lastError'] as String?,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
  );
}

abstract interface class EsfOutboxStore {
  Future<void> enqueue(EsfOutboxEntry entry);

  Future<void> update(EsfOutboxEntry entry);

  Future<List<EsfOutboxEntry>> all();

  Future<List<EsfOutboxEntry>> pending();

  Future<EsfOutboxEntry?> find(String idempotencyKey);

  Future<void> remove(String idempotencyKey);

  Future<int> pendingCount();
}

class InMemoryEsfOutboxStore implements EsfOutboxStore {
  final Map<String, EsfOutboxEntry> _entries = {};

  @override
  Future<void> enqueue(EsfOutboxEntry entry) async {
    _entries.putIfAbsent(entry.idempotencyKey, () => entry);
  }

  @override
  Future<void> update(EsfOutboxEntry entry) async {
    _entries[entry.idempotencyKey] = entry;
  }

  @override
  Future<List<EsfOutboxEntry>> all() async {
    final list = _entries.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Future<List<EsfOutboxEntry>> pending() async {
    final list =
        _entries.values.where((e) => e.status == EsfStatus.queued).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Future<EsfOutboxEntry?> find(String idempotencyKey) async =>
      _entries[idempotencyKey];

  @override
  Future<void> remove(String idempotencyKey) async {
    _entries.remove(idempotencyKey);
  }

  @override
  Future<int> pendingCount() async => (await pending()).length;
}
