import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:telepos/core/logging/app_logger.dart';
import 'package:telepos/core/logging/file_log_observer.dart';

class LogFileInfo {
  const LogFileInfo({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.modified,
  });

  final String name;
  final String path;
  final int sizeBytes;
  final DateTime modified;
}

class LogJournalService {
  LogJournalService({String? logDirectory})
    : _logDir = logDirectory ?? AppLogger.logDir;

  final String? _logDir;

  String? get logDirectory => _logDir;

  bool _isLog(String name) =>
      name.startsWith(FileLogObserver.filePrefix) &&
      name.endsWith(FileLogObserver.fileSuffix);

  List<LogFileInfo> listLogs() {
    final dir = _logDir;
    if (dir == null) return const [];
    final d = Directory(dir);
    if (!d.existsSync()) return const [];
    final files = <LogFileInfo>[];
    for (final e in d.listSync()) {
      if (e is! File) continue;
      final name = p.basename(e.path);
      if (!_isLog(name)) continue;
      final stat = e.statSync();
      files.add(
        LogFileInfo(
          name: name,
          path: e.path,
          sizeBytes: stat.size,
          modified: stat.modified,
        ),
      );
    }
    files.sort((a, b) => b.name.compareTo(a.name));
    return files;
  }

  int totalSizeBytes() =>
      listLogs().fold<int>(0, (sum, f) => sum + f.sizeBytes);

  Future<int> exportTo(String targetDir) async {
    final logs = listLogs();
    if (logs.isEmpty) return 0;
    final target = Directory(targetDir);
    if (!target.existsSync()) target.createSync(recursive: true);
    var copied = 0;
    for (final f in logs) {
      try {
        await File(f.path).copy(p.join(targetDir, f.name));
        copied++;
      } catch (_) {}
    }
    return copied;
  }

  Future<int> deleteOlderThan(Duration maxAge) async {
    final cutoff = DateTime.now().subtract(maxAge);
    var deleted = 0;
    final today = _todayName();
    for (final f in listLogs()) {
      if (f.name == today) continue;
      if (f.modified.isBefore(cutoff)) {
        try {
          await File(f.path).delete();
          deleted++;
        } catch (_) {}
      }
    }
    return deleted;
  }

  Future<int> deleteAllExceptToday() async {
    var deleted = 0;
    final today = _todayName();
    for (final f in listLogs()) {
      if (f.name == today) continue;
      try {
        await File(f.path).delete();
        deleted++;
      } catch (_) {}
    }
    return deleted;
  }

  String _todayName() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${FileLogObserver.filePrefix}${now.year}-$m-$d${FileLogObserver.fileSuffix}';
  }
}
