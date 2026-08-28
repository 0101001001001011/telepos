import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';

class TdLibSession {
  final String sessionId;
  final String phoneNumber;
  final int userId;
  final String databasePath;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final bool isActive;

  TdLibSession({
    required this.sessionId,
    required this.phoneNumber,
    required this.userId,
    required this.databasePath,
    required this.createdAt,
    required this.lastActiveAt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'phoneNumber': phoneNumber,
    'userId': userId,
    'databasePath': databasePath,
    'createdAt': createdAt.toIso8601String(),
    'lastActiveAt': lastActiveAt.toIso8601String(),
    'isActive': isActive,
  };

  factory TdLibSession.fromJson(Map<String, dynamic> json) => TdLibSession(
    sessionId: json['sessionId'] as String,
    phoneNumber: json['phoneNumber'] as String,
    userId: json['userId'] as int,
    databasePath: json['databasePath'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    lastActiveAt: DateTime.parse(json['lastActiveAt'] as String),
    isActive: json['isActive'] as bool? ?? true,
  );
}

class TdLibSessionManager {
  final TdLibClient _client; // ignore: unused_field
  final TdLibLogger _logger;
  final String _sessionsDir;

  TdLibSession? _currentSession;

  TdLibSessionManager({
    required TdLibClient client,
    required TdLibLogger logger,
    required String sessionsDir,
  }) : _client = client,
       _logger = logger,
       _sessionsDir = sessionsDir;

  TdLibSession? get currentSession => _currentSession;

  bool get hasActiveSession => _currentSession != null;

  Future<void> persistSession(TdLibSession session) async {
    _currentSession = session;

    final dir = Directory(_sessionsDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final file = File('${dir.path}/${session.sessionId}.json');
    await file.writeAsString(jsonEncode(session.toJson()));

    _logger.logConnection('Session persisted: ${session.sessionId}');
  }

  Future<TdLibSession?> restoreSession() async {
    final dir = Directory(_sessionsDir);
    if (!dir.existsSync()) return null;

    try {
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();

      if (files.isEmpty) return null;

      TdLibSession? latest;
      for (final file in files) {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final session = TdLibSession.fromJson(json);
        if (session.isActive) {
          if (latest == null ||
              session.lastActiveAt.isAfter(latest.lastActiveAt)) {
            latest = session;
          }
        }
      }

      if (latest != null) {
        _currentSession = latest;
        _logger.logConnection('Session restored: ${latest.sessionId}');
      }

      return latest;
    } catch (e, st) {
      _logger.logError('restoreSession', e, st);
      return null;
    }
  }

  Future<void> updateLastActive() async {
    if (_currentSession == null) return;

    _currentSession = TdLibSession(
      sessionId: _currentSession!.sessionId,
      phoneNumber: _currentSession!.phoneNumber,
      userId: _currentSession!.userId,
      databasePath: _currentSession!.databasePath,
      createdAt: _currentSession!.createdAt,
      lastActiveAt: DateTime.now(),
      isActive: true,
    );

    await persistSession(_currentSession!);
  }

  Future<void> deactivateSession() async {
    if (_currentSession == null) return;

    _currentSession = TdLibSession(
      sessionId: _currentSession!.sessionId,
      phoneNumber: _currentSession!.phoneNumber,
      userId: _currentSession!.userId,
      databasePath: _currentSession!.databasePath,
      createdAt: _currentSession!.createdAt,
      lastActiveAt: DateTime.now(),
      isActive: false,
    );

    await persistSession(_currentSession!);
    _currentSession = null;
    _logger.logConnection('Session deactivated');
  }

  Future<void> clearAllSessions() async {
    final dir = Directory(_sessionsDir);
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
    _currentSession = null;
    _logger.logConnection('All sessions cleared');
  }

  Future<List<TdLibSession>> listSessions() async {
    final dir = Directory(_sessionsDir);
    if (!dir.existsSync()) return [];

    final sessions = <TdLibSession>[];
    for (final file in dir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      try {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        sessions.add(TdLibSession.fromJson(json));
      } catch (_) {}
    }

    sessions.sort((a, b) => b.lastActiveAt.compareTo(a.lastActiveAt));
    return sessions;
  }
}
