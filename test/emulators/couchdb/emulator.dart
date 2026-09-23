/// Эмулятор CouchDB — ровно столько, сколько трогает касса.
///
/// # Зачем он и почему именно сервер
///
/// Спека `2026-07-29-sync-correctness-design.md` требует проверять
/// синхронизацию **столкновением двух касс на одном документе**. Столкнуть их
/// было не на чем: из пяти файлов проб, упоминающих couch, ни один не
/// поднимает сервер, и четыре находки о сломанной синхронизации три месяца
/// подтверждались только чтением кода.
///
/// Подменять `CouchDbClient` в контейнере нельзя по правилу дерева:
/// эмулируется **зависимость, а не адаптер**, и точка подстановки — самая
/// дальняя. Подделка клиента мерила бы наше представление о CouchDB; здесь
/// касса говорит по HTTP с тем, что отвечает как CouchDB.
///
/// # Главное свойство: он УМЕЕТ ОТКАЗЫВАТЬ
///
/// Эмулятор, принимающий всё подряд, зеленил бы шаги 1–3 спеки не глядя —
/// они ровно про отказы. Поэтому ревизии здесь настоящие: отправка документа
/// без `_rev` поверх существующего даёт `409 conflict` **по этому документу**,
/// а остальные в том же пакете принимаются. Именно так ведёт себя
/// `_bulk_docs`, и именно на этом стоит продукт.
///
/// # Чего здесь нет намеренно
///
/// * **Дерева ревизий.** Хранится текущая ревизия и счётчик; проигравшая
///   ветка не сохраняется. Продукт её не читает ни в одном месте, а дерево
///   потребовало бы воспроизвести правило выбора победителя — то самое,
///   которое спека велит записать словами, а не отдавать CouchDB.
/// * **`_revs_diff` и протокола репликации** — названы вне области спеки.
/// * **Проверки пароля.** Заголовок `Authorization` принимается любой: предмет
///   проб — синхронизация, а не доступ.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Один документ так, как его помнит эмулятор.
class _Doc {
  _Doc({required this.body, required this.rev, required this.seq});

  Map<String, Object?> body;
  String rev;
  int seq;
  bool deleted = false;
}

/// Сервер, отвечающий как CouchDB на то, что спрашивает касса.
class CouchDbEmulator {
  CouchDbEmulator({this.dbName = 'telepos'});

  final String dbName;
  HttpServer? _server;
  final Map<String, _Doc> _docs = {};
  int _seq = 0;

  /// Зовётся **перед** обработкой `_bulk_docs`.
  ///
  /// Единственный способ устроить настоящую гонку: касса спрашивает ревизии
  /// `_all_docs`, а соседняя записывает своё до того, как наш пакет доехал.
  /// Подсунуть устаревшую ревизию снаружи нельзя — движок обновляет её сам
  /// прямо перед отправкой, и это правильно. Значит вмешиваться надо здесь,
  /// внутри окна, которого снаружи не видно.
  Future<void> Function()? onBeforeBulkDocs;

  /// Зовётся **перед** записью одиночного документа, с его идентификатором.
  ///
  /// Тем же доводом, что [onBeforeBulkDocs], но для занятия отложенного
  /// чека: оно идёт через `PUT`, и гонка двух касс живёт в окне между
  /// чтением документа и записью нашей отметки.
  Future<void> Function(String id)? onBeforePutDocument;

  /// Адрес, который отдают `CouchDbClient`. IPv4 намеренно: `localhost` на
  /// Windows это `::1`, и он прячет класс отказов, которым болеет сеть.
  String get baseUrl => 'http://127.0.0.1:${_server!.port}';

  int get port => _server!.port;

  /// Сколько документов эмулятор принял — величина для утверждений проб.
  int get documentCount => _docs.values.where((d) => !d.deleted).length;

  /// Тело документа по идентификатору, либо `null`.
  Map<String, Object?>? document(String id) {
    final d = _docs[id];
    return d == null || d.deleted ? null : {...d.body, '_rev': d.rev};
  }

  /// Положить документ мимо HTTP — так проба готовит состояние «этот
  /// документ уже есть», не делая вид, что его отправила касса.
  String seed(String id, Map<String, Object?> body) {
    _seq++;
    final rev = '1-${_hash('$id$_seq')}';
    _docs[id] = _Doc(body: {...body, '_id': id}, rev: rev, seq: _seq);
    return rev;
  }

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(_serve());
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _serve() async {
    final server = _server;
    if (server == null) return;
    await for (final req in server) {
      try {
        await _handle(req);
      } on Object catch (e) {
        req.response.statusCode = HttpStatus.internalServerError;
        req.response.write(jsonEncode({'error': 'emulator', 'reason': '$e'}));
        await req.response.close();
      }
    }
  }

  Future<void> _handle(HttpRequest req) async {
    final path = req.uri.path;
    final method = req.method;

    if (path == '/_up') return _json(req, {'status': 'ok'});

    if (path == '/$dbName' && method == 'GET') {
      return _json(req, {
        'db_name': dbName,
        'doc_count': documentCount,
        'update_seq': _seq,
      });
    }

    if (path == '/$dbName/_bulk_docs' && method == 'POST') {
      return _bulkDocs(req);
    }

    if (path == '/$dbName/_all_docs') return _allDocs(req);

    if (path == '/$dbName/_changes' && method == 'GET') return _changes(req);

    // Одиночный документ: `/db/<id>`.
    final prefix = '/$dbName/';
    if (path.startsWith(prefix)) {
      final id = Uri.decodeComponent(path.substring(prefix.length));
      if (id.startsWith('_')) {
        return _error(req, HttpStatus.notFound, 'not_found', 'no such handler');
      }
      if (method == 'GET') return _getDoc(req, id);
      if (method == 'PUT') return _putDoc(req, id);
      if (method == 'DELETE') return _deleteDoc(req, id);
    }

    return _error(req, HttpStatus.notFound, 'not_found', 'missing');
  }

  // ── отправка пакетом ──────────────────────────────────────────────────

  /// `_bulk_docs` — то место, где продукт и ломается.
  ///
  /// Ответ CouchDB — список **по документу**, и отказ одного не отменяет
  /// приёма остальных. Продукт считает только `ok == true` и выбрасывает
  /// `{id, error}` — находка 2 спеки; здесь она воспроизводима.
  Future<void> _bulkDocs(HttpRequest req) async {
    final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map;
    // Окно гонки: тело прочитано, но ещё не применено — ровно здесь соседняя
    // касса успевает записать своё.
    final hook = onBeforeBulkDocs;
    if (hook != null) await hook();
    final docs = (body['docs'] as List).cast<Map<String, Object?>>();
    final out = <Map<String, Object?>>[];

    for (final doc in docs) {
      final id = doc['_id'] as String?;
      if (id == null || id.isEmpty) {
        out.add({
          'error': 'bad_request',
          'reason': 'document must have an _id',
        });
        continue;
      }
      final sent = doc['_rev'] as String?;
      final existing = _docs[id];

      if (existing != null && !existing.deleted && sent != existing.rev) {
        // Ровно тот отказ, из-за которого у продукта вторая отправка
        // документа не проходит НИКОГДА: ревизию он не шлёт вовсе.
        out.add({
          'id': id,
          'error': 'conflict',
          'reason': 'Document update conflict.',
        });
        continue;
      }

      _seq++;
      final gen = existing == null ? 1 : int.parse(existing.rev.split('-')[0]) + 1;
      final rev = '$gen-${_hash('$id$_seq')}';
      _docs[id] = _Doc(
        body: {...doc}..remove('_rev'),
        rev: rev,
        seq: _seq,
      );
      out.add({'ok': true, 'id': id, 'rev': rev});
    }

    return _jsonList(req, out);
  }

  // ── чтение ────────────────────────────────────────────────────────────

  Future<void> _allDocs(HttpRequest req) async {
    final includeDocs = req.uri.queryParameters['include_docs'] != 'false';
    List<String> keys;
    if (req.method == 'POST') {
      final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map;
      keys = (body['keys'] as List).cast<String>();
    } else {
      keys = _docs.keys.toList()..sort();
    }

    final rows = <Map<String, Object?>>[];
    for (final key in keys) {
      final d = _docs[key];
      if (d == null || d.deleted) {
        // CouchDB отвечает строкой с `error`, а не пропуском: спрашивающий
        // обязан отличить «нет такого» от «не спрашивали».
        rows.add({'key': key, 'error': 'not_found'});
        continue;
      }
      rows.add({
        'id': key,
        'key': key,
        'value': {'rev': d.rev},
        if (includeDocs) 'doc': {...d.body, '_id': key, '_rev': d.rev},
      });
    }

    return _json(req, {
      'total_rows': _docs.length,
      'offset': 0,
      'rows': rows,
    });
  }

  Future<void> _changes(HttpRequest req) async {
    final q = req.uri.queryParameters;
    final since = int.tryParse(q['since'] ?? '0') ?? 0;
    final limit = int.tryParse(q['limit'] ?? '500') ?? 500;
    final includeDocs = q['include_docs'] != 'false';

    final all = _docs.entries.where((e) => e.value.seq > since).toList()
      ..sort((a, b) => a.value.seq.compareTo(b.value.seq));
    final page = all.take(limit).toList();

    return _json(req, {
      'results': [
        for (final e in page)
          {
            'id': e.key,
            'seq': e.value.seq,
            'changes': [
              {'rev': e.value.rev},
            ],
            if (e.value.deleted) 'deleted': true,
            if (includeDocs && !e.value.deleted)
              'doc': {...e.value.body, '_id': e.key, '_rev': e.value.rev},
          },
      ],
      'last_seq': page.isEmpty ? since : page.last.value.seq,
      'pending': all.length - page.length,
    });
  }

  Future<void> _getDoc(HttpRequest req, String id) async {
    final d = _docs[id];
    if (d == null || d.deleted) {
      return _error(req, HttpStatus.notFound, 'not_found', 'missing');
    }
    return _json(req, {...d.body, '_id': id, '_rev': d.rev});
  }

  Future<void> _putDoc(HttpRequest req, String id) async {
    final doc = jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, Object?>;
    // Окно гонки: тело прочитано, но ещё не применено.
    final hook = onBeforePutDocument;
    if (hook != null) await hook(id);
    final sent = doc['_rev'] as String?;
    final existing = _docs[id];
    if (existing != null && !existing.deleted && sent != existing.rev) {
      return _error(
        req,
        HttpStatus.conflict,
        'conflict',
        'Document update conflict.',
      );
    }
    _seq++;
    final gen = existing == null ? 1 : int.parse(existing.rev.split('-')[0]) + 1;
    final rev = '$gen-${_hash('$id$_seq')}';
    _docs[id] = _Doc(body: {...doc}..remove('_rev'), rev: rev, seq: _seq);
    req.response.statusCode = HttpStatus.created;
    return _json(req, {'ok': true, 'id': id, 'rev': rev}, alreadyCoded: true);
  }

  Future<void> _deleteDoc(HttpRequest req, String id) async {
    final rev = req.uri.queryParameters['rev'];
    final d = _docs[id];
    if (d == null || d.deleted) {
      return _error(req, HttpStatus.notFound, 'not_found', 'missing');
    }
    if (rev != d.rev) {
      return _error(
        req,
        HttpStatus.conflict,
        'conflict',
        'Document update conflict.',
      );
    }
    _seq++;
    d.deleted = true;
    d.seq = _seq;
    return _json(req, {'ok': true, 'id': id, 'rev': d.rev});
  }

  // ── мелочь ────────────────────────────────────────────────────────────

  static String _hash(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  Future<void> _json(
    HttpRequest req,
    Map<String, Object?> body, {
    bool alreadyCoded = false,
  }) async {
    if (!alreadyCoded) req.response.statusCode = HttpStatus.ok;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(body));
    await req.response.close();
  }

  Future<void> _jsonList(HttpRequest req, List<Object?> body) async {
    req.response.statusCode = HttpStatus.ok;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(body));
    await req.response.close();
  }

  Future<void> _error(
    HttpRequest req,
    int code,
    String error,
    String reason,
  ) async {
    req.response.statusCode = code;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode({'error': error, 'reason': reason}));
    await req.response.close();
  }
}
