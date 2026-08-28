import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

QueryExecutor createDatabaseConnection() {
  return DatabaseConnection.delayed(
    Future(() async {
      final db = await WasmDatabase.open(
        databaseName: 'telepos_store',
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse('drift_worker.js'),
      );
      if (db.missingFeatures.isNotEmpty) {
        // ignore: avoid_print
        print('[DB/Web] Missing features: ${db.missingFeatures}');
      }
      return db.resolvedExecutor;
    }),
  );
}
