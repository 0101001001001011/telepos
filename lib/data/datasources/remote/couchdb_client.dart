import 'dart:convert';

import 'package:dio/dio.dart';

class CouchDbClient {
  CouchDbClient({
    required String url,
    required String dbName,
    required String username,
    required String password,
    Dio? dio,
  }) : _dbName = dbName,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: url,
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
               headers: {
                 'Content-Type': 'application/json',
                 'Accept': 'application/json',
                 'Authorization':
                     'Basic ${base64Encode(utf8.encode('$username:$password'))}',
               },
             ),
           );

  final String _dbName;
  final Dio _dio;

  Future<bool> ping() async {
    try {
      final resp = await _dio.get('/_up');
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getDocument(String docId) async {
    try {
      final resp = await _dio.get('/$_dbName/$docId');
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<String?> putDocument(String docId, Map<String, dynamic> body) async {
    try {
      final resp = await _dio.put('/$_dbName/$docId', data: body);
      final data = resp.data as Map<String, dynamic>;
      return data['rev'] as String?;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final current = await getDocument(docId);
        if (current != null) {
          body['_rev'] = current['_rev'];
          final resp = await _dio.put('/$_dbName/$docId', data: body);
          final data = resp.data as Map<String, dynamic>;
          return data['rev'] as String?;
        }
      }
      rethrow;
    }
  }

  Future<bool> deleteDocument(String docId, String rev) async {
    try {
      await _dio.delete('/$_dbName/$docId', queryParameters: {'rev': rev});
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return true;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> bulkDocs(
    List<Map<String, dynamic>> docs,
  ) async {
    final resp = await _dio.post('/$_dbName/_bulk_docs', data: {'docs': docs});
    return (resp.data as List).whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> allDocs({
    List<String>? keys,
    bool includeDocs = true,
  }) async {
    final queryParams = <String, dynamic>{'include_docs': includeDocs};

    Response resp;
    if (keys != null && keys.isNotEmpty) {
      resp = await _dio.post(
        '/$_dbName/_all_docs',
        data: {'keys': keys},
        queryParameters: queryParams,
      );
    } else {
      resp = await _dio.get(
        '/$_dbName/_all_docs',
        queryParameters: queryParams,
      );
    }

    final data = resp.data as Map<String, dynamic>;
    final rows = data['rows'] as List? ?? [];
    return rows
        .where((r) => r['doc'] != null)
        .map((r) => r['doc'] as Map<String, dynamic>)
        .toList();
  }

  Future<CouchDbChangesResult> getChanges({
    String? since,
    int limit = 500,
    bool includeDocs = true,
  }) async {
    final queryParams = <String, dynamic>{
      'include_docs': includeDocs,
      'limit': limit,
      'feed': 'normal',
    };
    if (since != null) {
      queryParams['since'] = since;
    }

    final resp = await _dio.get(
      '/$_dbName/_changes',
      queryParameters: queryParams,
    );
    final data = resp.data as Map<String, dynamic>;

    final results = (data['results'] as List? ?? [])
        .map(
          (r) => CouchDbChange(
            id: r['id'] as String,
            seq: r['seq'].toString(),
            deleted: r['deleted'] as bool? ?? false,
            doc: r['doc'] as Map<String, dynamic>?,
          ),
        )
        .toList();

    return CouchDbChangesResult(
      results: results,
      lastSeq: data['last_seq'].toString(),
      pending: data['pending'] as int? ?? 0,
    );
  }

  Future<List<Map<String, dynamic>>> viewQuery({
    required String designDoc,
    required String viewName,
    dynamic key,
    dynamic startKey,
    dynamic endKey,
    bool includeDocs = true,
    int? limit,
    bool descending = false,
  }) async {
    final queryParams = <String, dynamic>{
      'include_docs': includeDocs,
      if (descending) 'descending': true,
      if (limit != null) 'limit': limit,
    };
    if (key != null) {
      queryParams['key'] = jsonEncode(key);
    }
    if (startKey != null) {
      queryParams['startkey'] = jsonEncode(startKey);
    }
    if (endKey != null) {
      queryParams['endkey'] = jsonEncode(endKey);
    }

    final resp = await _dio.get(
      '/$_dbName/_design/$designDoc/_view/$viewName',
      queryParameters: queryParams,
    );
    final data = resp.data as Map<String, dynamic>;
    final rows = data['rows'] as List? ?? [];

    if (includeDocs) {
      return rows
          .where((r) => r['doc'] != null)
          .map((r) => r['doc'] as Map<String, dynamic>)
          .toList();
    }
    return rows.map((r) => r as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> getDatabaseInfo() async {
    final resp = await _dio.get('/$_dbName');
    return resp.data as Map<String, dynamic>;
  }
}

class CouchDbChange {
  const CouchDbChange({
    required this.id,
    required this.seq,
    this.deleted = false,
    this.doc,
  });

  final String id;
  final String seq;
  final bool deleted;
  final Map<String, dynamic>? doc;
}

class CouchDbChangesResult {
  const CouchDbChangesResult({
    required this.results,
    required this.lastSeq,
    this.pending = 0,
  });

  final List<CouchDbChange> results;
  final String lastSeq;
  final int pending;
}
