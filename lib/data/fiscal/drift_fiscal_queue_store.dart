import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:telepos/data/database/app_database.dart' as db;
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';

class DriftFiscalQueueStore implements FiscalQueueStore {
  DriftFiscalQueueStore(this._db);

  final db.AppDatabase _db;

  db.$FiscalQueueEntriesTable get _t => _db.fiscalQueueEntries;

  @override
  Future<void> enqueue(FiscalQueueEntry entry) async {
    await _db
        .into(_t)
        .insert(_toCompanion(entry), mode: InsertMode.insertOrIgnore);
  }

  @override
  Future<List<FiscalQueueEntry>> pending() async {
    final rows =
        await (_db.select(_t)
              ..where((r) => r.status.equals(FiscalQueueStatus.pending.index))
              ..orderBy([(r) => OrderingTerm.asc(r.occurredAt)]))
            .get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<FiscalQueueEntry>> failed() async {
    final rows =
        await (_db.select(_t)
              ..where((r) => r.status.equals(FiscalQueueStatus.failed.index))
              ..orderBy([(r) => OrderingTerm.asc(r.occurredAt)]))
            .get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> update(FiscalQueueEntry entry) async {
    await (_db.update(
      _t,
    )..where((r) => r.idempotencyKey.equals(entry.idempotencyKey))).write(
      db.FiscalQueueEntriesCompanion(
        opType: Value(entry.opType.index),
        payload: Value(jsonEncode(entry.payload)),
        occurredAt: Value(entry.occurredAt.millisecondsSinceEpoch),
        status: Value(entry.status.index),
        attempts: Value(entry.attempts),
        lastError: Value(entry.lastError),
      ),
    );
  }

  @override
  Future<void> remove(String idempotencyKey) async {
    await (_db.delete(
      _t,
    )..where((r) => r.idempotencyKey.equals(idempotencyKey))).go();
  }

  @override
  Future<int> pendingCount() async {
    final count = _t.idempotencyKey.count();
    final q = _db.selectOnly(_t)
      ..addColumns([count])
      ..where(_t.status.equals(FiscalQueueStatus.pending.index));
    final row = await q.getSingle();
    return row.read(count) ?? 0;
  }

  /// Счёт **не** делается запросом `count(*)`: списанные строки остаются в
  /// таблице (тихой чистки у этой очереди нет), а отметка о списании живёт
  /// внутри JSON-payload, и SQL про неё ничего не знает. Считать столбцом
  /// значило бы назвать закрытию смены число, в котором уже разобранные
  /// чеки считаются заново.
  @override
  Future<int> failedCount() async =>
      (await failed()).where((e) => e.writeOff == null).length;

  db.FiscalQueueEntriesCompanion _toCompanion(FiscalQueueEntry e) =>
      db.FiscalQueueEntriesCompanion.insert(
        idempotencyKey: e.idempotencyKey,
        opType: e.opType.index,
        payload: jsonEncode(e.payload),
        occurredAt: e.occurredAt.millisecondsSinceEpoch,
        status: Value(e.status.index),
        attempts: Value(e.attempts),
        lastError: Value(e.lastError),
      );

  FiscalQueueEntry _fromRow(db.FiscalQueueEntry row) => FiscalQueueEntry(
    idempotencyKey: row.idempotencyKey,
    opType: _opFromIndex(row.opType),
    payload: _decodePayload(row.payload),
    occurredAt: DateTime.fromMillisecondsSinceEpoch(row.occurredAt),
    status: _statusFromIndex(row.status),
    attempts: row.attempts,
    lastError: row.lastError,
  );

  static Map<String, dynamic> _decodePayload(String raw) {
    if (raw.isEmpty) return const {};
    final decoded = jsonDecode(raw);
    return decoded is Map ? decoded.cast<String, dynamic>() : const {};
  }

  static FiscalQueueOp _opFromIndex(int i) =>
      (i >= 0 && i < FiscalQueueOp.values.length)
      ? FiscalQueueOp.values[i]
      : FiscalQueueOp.sale;

  static FiscalQueueStatus _statusFromIndex(int i) =>
      (i >= 0 && i < FiscalQueueStatus.values.length)
      ? FiscalQueueStatus.values[i]
      : FiscalQueueStatus.pending;
}
