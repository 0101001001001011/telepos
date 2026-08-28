import 'dart:io';

import 'package:path_provider/path_provider.dart';

class DirectoryUtil {
  DirectoryUtil._();

  static Directory? _appDocuments;
  static Directory? _appSupport;
  static Directory? _appCache;
  static Directory? _appTemp;

  static Future<void> initialize() async {
    _appDocuments = await getApplicationDocumentsDirectory();
    _appSupport = await getApplicationSupportDirectory();
    _appCache = await getApplicationCacheDirectory();
    _appTemp = await getTemporaryDirectory();

    await _ensureDirectories();
  }

  static Future<void> _ensureDirectories() async {
    final dirs = [
      databaseDir,
      logsDir,
      backupsDir,
      exportsDir,
      importsDir,
      tempDir,
    ];

    for (final dir in dirs) {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }
  }

  static Directory get documentsDir {
    if (_appDocuments == null) {
      throw StateError('DirectoryUtil not initialized');
    }
    return _appDocuments!;
  }

  static Directory get supportDir {
    if (_appSupport == null) {
      throw StateError('DirectoryUtil not initialized');
    }
    return _appSupport!;
  }

  static Directory get cacheDir {
    if (_appCache == null) {
      throw StateError('DirectoryUtil not initialized');
    }
    return _appCache!;
  }

  static Directory get systemTempDir {
    if (_appTemp == null) {
      throw StateError('DirectoryUtil not initialized');
    }
    return _appTemp!;
  }

  static Directory get databaseDir => Directory('${supportDir.path}/database');

  static Directory get logsDir => Directory('${supportDir.path}/logs');

  static Directory get backupsDir => Directory('${documentsDir.path}/backups');

  static Directory get exportsDir => Directory('${documentsDir.path}/exports');

  static Directory get importsDir => Directory('${documentsDir.path}/imports');

  static Directory get tempDir => Directory('${cacheDir.path}/temp');

  static String get mainDatabasePath => '${databaseDir.path}/telepos.db';

  static String get backupDatabasePath =>
      '${backupsDir.path}/telepos_backup.db';

  static String get todayLogPath {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return '${logsDir.path}/telepos_$date.log';
  }

  static Future<int> getDirectorySize(Directory dir) async {
    int totalSize = 0;
    if (await dir.exists()) {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    }
    return totalSize;
  }

  static Future<void> clearDirectory(Directory dir) async {
    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        await entity.delete(recursive: true);
      }
    }
  }

  static Future<void> clearCache() async {
    await clearDirectory(cacheDir);
    await clearDirectory(tempDir);
  }

  static Future<int> clearOldLogs({int olderThanDays = 7}) async {
    int deletedCount = 0;
    final cutoff = DateTime.now().subtract(Duration(days: olderThanDays));

    if (await logsDir.exists()) {
      await for (final entity in logsDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entity.delete();
            deletedCount++;
          }
        }
      }
    }

    return deletedCount;
  }

  static Future<StorageInfo> getStorageInfo() async {
    return StorageInfo(
      databaseSize: await getDirectorySize(databaseDir),
      logsSize: await getDirectorySize(logsDir),
      cacheSize: await getDirectorySize(cacheDir),
      backupsSize: await getDirectorySize(backupsDir),
    );
  }
}

class StorageInfo {
  const StorageInfo({
    required this.databaseSize,
    required this.logsSize,
    required this.cacheSize,
    required this.backupsSize,
  });

  final int databaseSize;

  final int logsSize;

  final int cacheSize;

  final int backupsSize;

  int get totalSize => databaseSize + logsSize + cacheSize + backupsSize;

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  String toString() =>
      '''
StorageInfo:
  Database: ${formatSize(databaseSize)}
  Logs: ${formatSize(logsSize)}
  Cache: ${formatSize(cacheSize)}
  Backups: ${formatSize(backupsSize)}
  Total: ${formatSize(totalSize)}
''';
}
