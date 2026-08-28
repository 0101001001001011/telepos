import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:telepos/data/datasources/remote/couchdb_client.dart';
import 'package:telepos/data/sync/couchdb_document_mapper.dart';
import 'package:telepos/core/logging/app_talker.dart';

enum SyncConnectionStatus {
  disconnected,
  connecting,
  connected,
  syncing,
  error,
}

class CouchDbSyncEngine {
  CouchDbSyncEngine({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;

  CouchDbClient? _client;
  Timer? _syncTimer;
  bool _isSyncing = false;
  final _statusController = StreamController<SyncConnectionStatus>.broadcast();

  static const _keyLastSeq = 'couchdb_last_seq';

  Stream<SyncConnectionStatus> get statusStream => _statusController.stream;

  bool get isConfigured => _client != null;

  bool get isSyncing => _isSyncing;

  CouchDbClient? get client => _client;

  Future<void> initialize({
    required String url,
    required String dbName,
    required String username,
    required String password,
  }) async {
    talker.info('[CouchDB Sync] Initializing: $url/$dbName');

    await _prefs.setString('couchdb_url', url);
    await _prefs.setString('couchdb_db_name', dbName);
    await _prefs.setString('couchdb_user', username);
    await _prefs.setString('couchdb_pass', password);

    _client = CouchDbClient(
      url: url,
      dbName: dbName,
      username: username,
      password: password,
    );

    _statusController.add(SyncConnectionStatus.connecting);

    try {
      final reachable = await _client!.ping();
      if (reachable) {
        _statusController.add(SyncConnectionStatus.connected);
        talker.info('[CouchDB Sync] Connected');
      } else {
        _statusController.add(SyncConnectionStatus.disconnected);
        talker.warning('[CouchDB Sync] Server unreachable, will retry later');
      }
    } catch (e) {
      _statusController.add(SyncConnectionStatus.disconnected);
      talker.warning('[CouchDB Sync] Ping failed: $e');
    }
  }

  Future<bool> tryRestore() async {
    final url = _prefs.getString('couchdb_url');
    final dbName = _prefs.getString('couchdb_db_name');
    final user = _prefs.getString('couchdb_user');
    final pass = _prefs.getString('couchdb_pass');

    if (url == null || dbName == null || user == null || pass == null) {
      return false;
    }

    await initialize(url: url, dbName: dbName, username: user, password: pass);
    return isConfigured;
  }

  void startPeriodicSync({
    required Future<void> Function() onSync,
    Duration interval = const Duration(minutes: 5),
  }) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) => onSync());
    talker.info(
      '[CouchDB Sync] Periodic sync started (every ${interval.inMinutes}min)',
    );
  }

  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  void dispose() {
    stopPeriodicSync();
    _statusController.close();
  }

  Future<int> pushDocuments(List<Map<String, dynamic>> docs) async {
    if (_client == null || docs.isEmpty) return 0;

    try {
      final results = await _client!.bulkDocs(docs);
      int count = 0;
      for (final r in results) {
        if (r['ok'] == true) count++;
      }
      talker.debug('[CouchDB Push] $count/${docs.length} documents');
      return count;
    } catch (e) {
      talker.error('[CouchDB Push] Failed: $e');
      return 0;
    }
  }

  Future<PullResult> pullChanges({int limit = 1000}) async {
    if (_client == null) {
      return const PullResult(changes: {}, lastSeq: '', count: 0);
    }

    final lastSeq = _prefs.getString(_keyLastSeq);

    try {
      final result = await _client!.getChanges(
        since: lastSeq,
        limit: limit,
        includeDocs: true,
      );

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final change in result.results) {
        if (change.deleted || change.doc == null) continue;

        final doc = change.doc!;
        final type = CouchDbDocumentMapper.typeFromDocId(
          doc['_id'] as String? ?? '',
        );
        if (type == null) continue;

        final docType = doc['type'] as String? ?? type;
        grouped.putIfAbsent(docType, () => []).add(doc);
      }

      await _prefs.setString(_keyLastSeq, result.lastSeq);

      final totalCount = grouped.values.fold<int>(
        0,
        (sum, list) => sum + list.length,
      );
      talker.debug(
        '[CouchDB Pull] $totalCount changes (${grouped.keys.join(', ')})',
      );

      return PullResult(
        changes: grouped,
        lastSeq: result.lastSeq,
        count: totalCount,
      );
    } catch (e) {
      talker.error('[CouchDB Pull] Failed: $e');
      return const PullResult(changes: {}, lastSeq: '', count: 0);
    }
  }

  Future<List<Map<String, dynamic>>> queryView({
    required String viewName,
    dynamic key,
    dynamic startKey,
    dynamic endKey,
    int? limit,
    bool descending = false,
  }) async {
    if (_client == null) return [];

    try {
      return await _client!.viewQuery(
        designDoc: 'pos',
        viewName: viewName,
        key: key,
        startKey: startKey,
        endKey: endKey,
        limit: limit,
        descending: descending,
      );
    } catch (e) {
      talker.error('[CouchDB View] $viewName failed: $e');
      return [];
    }
  }

  void markSyncStarted() {
    _isSyncing = true;
    _statusController.add(SyncConnectionStatus.syncing);
  }

  void markSyncComplete() {
    _isSyncing = false;
    _statusController.add(SyncConnectionStatus.connected);
  }

  void markSyncFailed() {
    _isSyncing = false;
    _statusController.add(SyncConnectionStatus.error);
  }
}

class PullResult {
  const PullResult({
    required this.changes,
    required this.lastSeq,
    required this.count,
  });

  final Map<String, List<Map<String, dynamic>>> changes;

  final String lastSeq;

  final int count;
}

class SyncResult {
  const SyncResult({
    required this.success,
    this.pushed = 0,
    this.pulled = 0,
    this.error,
  });

  final bool success;
  final int pushed;
  final int pulled;
  final String? error;
}
