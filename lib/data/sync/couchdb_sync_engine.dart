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

  /// Отправить пакет и **назвать поимённо**, что легло, а что нет.
  ///
  /// # Почему не число
  ///
  /// До 2026-09-19 метод возвращал `int` и считал только `r['ok'] == true`, а
  /// строки `{id, error: 'conflict'}` выбрасывал. Из этого следовали сразу
  /// две беды, и обе молчаливые: отказ не попадал никуда выше `debug`, а
  /// звавший не мог отметить синхронизированными те документы, которые
  /// доехали, — он видел только «сколько-то из скольких-то».
  ///
  /// Число отвечает на вопрос «много ли», а очереди нужен ответ на вопрос
  /// «какие именно». Без него отметка возможна лишь на весь пакет целиком, и
  /// один вечный отказ держит в очереди всё остальное навсегда (находка 4
  /// спеки `2026-07-29-sync-correctness-design.md`).
  ///
  /// # Отказ обязан быть слышен
  ///
  /// Каждый отклонённый документ пишется уровнем `warning` с идентификатором
  /// и причиной. `debug` здесь не годится: в рабочей кассе его не читают, и
  /// именно поэтому пропажа половины обмена три месяца выглядела как
  /// «Sync done».
  ///
  /// # Чего этот метод НЕ делает
  ///
  /// Не решает, что делать с отказом: повторить, бросить или показать
  /// кассиру. Это знание звавшего — у справочника и у чека оно разное.
  Future<CouchDbPushResult> pushDocuments(
    List<Map<String, dynamic>> docs,
  ) async {
    if (_client == null || docs.isEmpty) return const CouchDbPushResult.empty();

    try {
      final results = await _client!.bulkDocs(await _withRevisions(docs));
      final confirmed = <String, String>{};
      final rejected = <CouchDbPushRejection>[];

      for (var i = 0; i < results.length; i++) {
        final r = results[i];
        final id = r['id'] as String? ?? _idAt(docs, i);
        if (r['ok'] == true) {
          confirmed[id] = r['rev'] as String? ?? '';
          continue;
        }
        final rejection = CouchDbPushRejection(
          id: id,
          error: r['error'] as String? ?? 'unknown',
          reason: r['reason'] as String? ?? '',
        );
        rejected.add(rejection);
        talker.warning(
          '[CouchDB Push] Отклонён ${rejection.id}: '
          '${rejection.error} — ${rejection.reason}',
        );
      }

      talker.debug(
        '[CouchDB Push] ${confirmed.length}/${docs.length} принято, '
        '${rejected.length} отклонено',
      );
      return CouchDbPushResult(confirmed: confirmed, rejected: rejected);
    } catch (e) {
      // Сорвавшаяся отправка — не отказ по документу: неизвестно, что из
      // пакета легло. Пустой исход означает «ничего не отмечать», и это
      // единственный честный ответ.
      talker.error('[CouchDB Push] Пакет не отправлен: $e');
      return const CouchDbPushResult.empty();
    }
  }

  /// Приложить `_rev` тем документам, которые на сервере уже есть.
  ///
  /// # Почему без этого не работало НИЧЕГО, кроме первой отправки
  ///
  /// CouchDB отвергает обновление существующего документа без его ревизии.
  /// Касса ревизию не слала вовсе (`grep "rev:"` по координатору давал ноль),
  /// поэтому первая отправка любого документа проходила, а **каждая
  /// следующая — никогда**. Справочник, изменённый на соседней кассе,
  /// обновиться не мог по построению.
  ///
  /// # Откуда берутся ревизии
  ///
  /// Одним вопросом `_all_docs` по ключам пакета — клиент это уже умел.
  /// Спрашивать по документу значило бы N запросов на пакет в 500 штук.
  ///
  /// # Чего это НЕ решает
  ///
  /// Гонку: между вопросом о ревизии и отправкой соседняя касса может
  /// записать свою. Тогда придёт `conflict`, документ останется в очереди и
  /// уедет следующим кругом — это разрешимый отказ
  /// ([CouchDbPushRejection.mayResolveOnRetry]), а не потеря.
  ///
  /// Отказ самого `_all_docs` не отменяет отправку: пакет уходит как был,
  /// новые документы лягут, существующие получат `conflict` и повторятся.
  /// Это хуже, чем с ревизиями, но лучше, чем не отправить ничего.
  Future<List<Map<String, dynamic>>> _withRevisions(
    List<Map<String, dynamic>> docs,
  ) async {
    final ids = <String>[
      for (final d in docs)
        if (d['_id'] is String) d['_id'] as String,
    ];
    if (ids.isEmpty) return docs;

    Map<String, String> revs;
    try {
      final existing = await _client!.allDocs(keys: ids);
      revs = {
        for (final d in existing)
          if (d['_id'] is String && d['_rev'] is String)
            d['_id'] as String: d['_rev'] as String,
      };
    } on Object catch (e) {
      talker.warning(
        '[CouchDB Push] Ревизии не спрошены ($e); '
        'пакет уходит без них — существующие вернутся конфликтом',
      );
      return docs;
    }

    if (revs.isEmpty) return docs;
    return [
      for (final d in docs)
        if (d['_id'] is String && revs.containsKey(d['_id']))
          {...d, '_rev': revs[d['_id']]!}
        else
          d,
    ];
  }

  /// Идентификатор документа по месту в пакете — на случай ответа без `id`.
  ///
  /// CouchDB кладёт `id` в каждую строку, но отказ `bad_request` на документе
  /// без `_id` его не несёт: назвать нечего. Тогда в журнал уходит место в
  /// пакете, а не пустая строка, — иначе разбор упирается в «отклонён ».
  static String _idAt(List<Map<String, dynamic>> docs, int i) {
    if (i >= docs.length) return '<вне пакета #$i>';
    return docs[i]['_id'] as String? ?? '<без _id, место $i>';
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

/// Исход отправки пакета: что легло и что отклонено — поимённо.
class CouchDbPushResult {
  const CouchDbPushResult({required this.confirmed, required this.rejected});

  const CouchDbPushResult.empty() : confirmed = const {}, rejected = const [];

  /// Идентификатор документа → его новая ревизия.
  final Map<String, String> confirmed;

  /// Отклонённые, каждый со своей причиной.
  final List<CouchDbPushRejection> rejected;

  /// Легло ли хоть что-нибудь.
  bool get anyConfirmed => confirmed.isNotEmpty;

  /// Сколько легло — для журнала и счётчиков экрана.
  int get confirmedCount => confirmed.length;

  /// Доехал ли конкретный документ.
  ///
  /// Этим и отмечают очередь **по документу**: спрашивать по месту в пакете
  /// нельзя, CouchDB отвечает строками в своём порядке.
  bool landed(String docId) => confirmed.containsKey(docId);
}

/// Один отклонённый документ.
class CouchDbPushRejection {
  const CouchDbPushRejection({
    required this.id,
    required this.error,
    required this.reason,
  });

  final String id;

  /// Слово CouchDB: `conflict`, `bad_request`, `forbidden`…
  final String error;

  /// Пояснение CouchDB как есть, без приглаживания.
  final String reason;

  /// Разрешится ли отказ сам собой при следующей попытке.
  ///
  /// `conflict` — **разрешится**: шаг 2 спеки приложит ревизию, и документ
  /// доедет. Остальное (`bad_request`, `forbidden`) не разрешится никогда, и
  /// держать такой документ в очереди значит копить её без предела.
  bool get mayResolveOnRetry => error == 'conflict';

  @override
  String toString() => '$id: $error — $reason';
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
