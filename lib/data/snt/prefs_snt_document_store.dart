import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/domain/snt/snt_models.dart';
import 'package:telepos/domain/snt/snt_store.dart';

class PrefsSntDocumentStore implements SntDocumentStore {
  PrefsSntDocumentStore(this._prefs);

  final SharedPreferences _prefs;

  static const String prefsKey = 'snt_documents_v1';

  Map<String, SntDocument> _read() {
    final raw = _prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      final out = <String, SntDocument>{};
      for (final e in decoded) {
        if (e is Map) {
          final doc = SntDocument.fromJson(e.cast<String, dynamic>());
          out[doc.idempotencyKey] = doc;
        }
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> _write(Map<String, SntDocument> docs) async {
    final list = docs.values.map((d) => d.toJson()).toList();
    await _prefs.setString(prefsKey, jsonEncode(list));
  }

  @override
  Future<void> save(SntDocument doc) async {
    final docs = _read();
    docs[doc.idempotencyKey] = doc;
    await _write(docs);
  }

  @override
  Future<SntDocument?> findByKey(String idempotencyKey) async =>
      _read()[idempotencyKey];

  @override
  Future<List<SntDocument>> list({
    SntDirection? direction,
    SntStatus? status,
  }) async {
    final list = _read().values.where((d) {
      if (direction != null && d.direction != direction) return false;
      if (status != null && d.status != status) return false;
      return true;
    }).toList()..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return list;
  }

  @override
  Future<List<SntDocument>> outbox() => list(status: SntStatus.queued);

  @override
  Future<void> remove(String idempotencyKey) async {
    final docs = _read();
    if (docs.remove(idempotencyKey) != null) {
      await _write(docs);
    }
  }
}
