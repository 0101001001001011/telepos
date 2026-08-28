import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

QueryExecutor createDatabaseConnection() {
  return LazyDatabase(() async {
    final appDir = await getApplicationSupportDirectory();
    final dbDir = Directory('${appDir.path}${Platform.pathSeparator}db');
    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }
    final dbFile = File('${dbDir.path}${Platform.pathSeparator}store.db');

    if (dbFile.existsSync()) {
      try {
        for (final suffix in const ['', '-wal', '-shm']) {
          final src = File('${dbFile.path}$suffix');
          final dst = File('${dbFile.path}$suffix.bak');
          if (src.existsSync()) {
            src.copySync(dst.path);
          } else if (dst.existsSync()) {
            dst.deleteSync();
          }
        }
        debugPrint('[DB] Pre-launch backup: ${dbFile.path}.bak (+wal/shm)');
      } catch (e) {
        debugPrint('[DB] Backup failed (non-critical): $e');
      }
    }

    return NativeDatabase.createInBackground(dbFile, logStatements: kDebugMode);
  });
}
