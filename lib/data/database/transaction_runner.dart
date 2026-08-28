import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';

class TransactionRunner {
  TransactionRunner(this._db);

  final AppDatabase _db;

  Future<T> run<T>(Future<T> Function(AppDatabase txn) action) {
    return _db.transaction(() => action(_db));
  }

  Future<void> runVoid(Future<void> Function(AppDatabase txn) action) {
    return _db.transaction(() => action(_db));
  }

  Future<void> runBatch(void Function(Batch batch) action) {
    return _db.batch(action);
  }
}
