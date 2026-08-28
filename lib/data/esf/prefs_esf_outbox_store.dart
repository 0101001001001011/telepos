import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/data/esf/esf_outbox_store.dart';

class PrefsEsfOutboxStore implements EsfOutboxStore {
  PrefsEsfOutboxStore(this._prefs);

  final SharedPreferences _prefs;

  static const String prefsKey = 'esf_outbox_v1';

  Map<String, EsfOutboxEntry> _read() {
    final raw = _prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      final out = <String, EsfOutboxEntry>{};
      for (final e in decoded) {
        if (e is Map) {
          final entry = EsfOutboxEntry.fromJson(e.cast<String, dynamic>());
          out[entry.idempotencyKey] = entry;
        }
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> _write(Map<String, EsfOutboxEntry> entries) async {
    final list = entries.values.map((e) => e.toJson()).toList();
    await _prefs.setString(prefsKey, jsonEncode(list));
  }

  @override
  Future<void> enqueue(EsfOutboxEntry entry) async {
    final entries = _read();
    if (entries.containsKey(entry.idempotencyKey)) return;
    entries[entry.idempotencyKey] = entry;
    await _write(entries);
  }

  @override
  Future<void> update(EsfOutboxEntry entry) async {
    final entries = _read();
    entries[entry.idempotencyKey] = entry;
    await _write(entries);
  }

  @override
  Future<List<EsfOutboxEntry>> all() async {
    final list = _read().values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Future<List<EsfOutboxEntry>> pending() async =>
      (await all()).where((e) => e.status.name == 'queued').toList();

  @override
  Future<EsfOutboxEntry?> find(String idempotencyKey) async =>
      _read()[idempotencyKey];

  @override
  Future<void> remove(String idempotencyKey) async {
    final entries = _read();
    if (entries.remove(idempotencyKey) != null) {
      await _write(entries);
    }
  }

  @override
  Future<int> pendingCount() async => (await pending()).length;
}
