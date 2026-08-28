import 'dart:async';
import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart';

class BackupInfo {
  final String id;
  final String filePath;
  final DateTime createdAt;
  final int sizeBytes;
  final String? description;

  BackupInfo({
    required this.id,
    required this.filePath,
    required this.createdAt,
    required this.sizeBytes,
    this.description,
  });

  String get fileName => filePath.split(Platform.pathSeparator).last;

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024)
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class AutoBackupService {
  final Talker _logger;
  final String _databasePath;
  final String _backupDirectory;
  final int _maxBackups;

  AutoBackupService({
    required String databasePath,
    required String backupDirectory,
    int maxBackups = 10,
    Talker? logger,
  }) : _databasePath = databasePath,
       _backupDirectory = backupDirectory,
       _maxBackups = maxBackups,
       _logger = logger ?? Talker();

  String get backupDirectory => _backupDirectory;

  int get maxBackups => _maxBackups;

  Future<void> _checkpointDb() async {
    try {
      if (GetIt.I.isRegistered<AppDatabase>()) {
        await GetIt.I<AppDatabase>().checkpointWal();
      }
    } catch (e) {
      _logger.warning('Backup: WAL checkpoint failed (non-critical): $e');
    }
  }

  Future<BackupInfo?> createBackup({String? description}) async {
    try {
      await _checkpointDb();

      final dbFile = File(_databasePath);
      if (!await dbFile.exists()) {
        _logger.error('Database file not found: $_databasePath');
        return null;
      }

      final backupDir = Directory(_backupDirectory);
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final timestamp = DateTime.now();
      final backupId = timestamp.millisecondsSinceEpoch.toString();
      final backupFileName = 'telepos_backup_${_formatTimestamp(timestamp)}.db';
      final backupPath =
          '$_backupDirectory${Platform.pathSeparator}$backupFileName';

      await dbFile.copy(backupPath);

      final backupFile = File(backupPath);
      final sizeBytes = await backupFile.length();

      final backupInfo = BackupInfo(
        id: backupId,
        filePath: backupPath,
        createdAt: timestamp,
        sizeBytes: sizeBytes,
        description: description,
      );

      _logger.info(
        'Backup created: $backupFileName (${backupInfo.formattedSize})',
      );

      await _cleanupOldBackups();

      return backupInfo;
    } catch (e, st) {
      _logger.error('Failed to create backup', e, st);
      return null;
    }
  }

  Future<List<BackupInfo>> listBackups() async {
    try {
      final backupDir = Directory(_backupDirectory);
      if (!await backupDir.exists()) {
        return [];
      }

      final backups = <BackupInfo>[];

      await for (final entity in backupDir.list()) {
        if (entity is File && entity.path.endsWith('.db')) {
          final stat = await entity.stat();
          backups.add(
            BackupInfo(
              id: stat.modified.millisecondsSinceEpoch.toString(),
              filePath: entity.path,
              createdAt: stat.modified,
              sizeBytes: stat.size,
            ),
          );
        }
      }

      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return backups;
    } catch (e, st) {
      _logger.error('Failed to list backups', e, st);
      return [];
    }
  }

  Future<bool> restoreBackup(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        _logger.error('Backup file not found: $backupPath');
        return false;
      }

      await createBackup(description: 'Pre-restore backup');

      await backupFile.copy(_databasePath);

      AppDatabase.deleteWalSidecars(_databasePath);

      _logger.info(
        'Database restored from: ${backupPath.split(Platform.pathSeparator).last}',
      );
      return true;
    } catch (e, st) {
      _logger.error('Failed to restore backup', e, st);
      return false;
    }
  }

  Future<bool> deleteBackup(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        await backupFile.delete();
        _logger.info(
          'Backup deleted: ${backupPath.split(Platform.pathSeparator).last}',
        );
        return true;
      }
      return false;
    } catch (e, st) {
      _logger.error('Failed to delete backup', e, st);
      return false;
    }
  }

  Future<void> _cleanupOldBackups() async {
    final backups = await listBackups();

    if (backups.length > _maxBackups) {
      final toDelete = backups.sublist(_maxBackups);

      for (final backup in toDelete) {
        await deleteBackup(backup.filePath);
        _logger.debug('Deleted old backup: ${backup.fileName}');
      }
    }
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.year}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}'
        '_'
        '${dt.hour.toString().padLeft(2, '0')}'
        '${dt.minute.toString().padLeft(2, '0')}'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  Future<void> dispose() async {}
}
