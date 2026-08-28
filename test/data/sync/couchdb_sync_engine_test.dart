import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telepos/data/sync/couchdb_sync_engine.dart';

void main() {
  group('CouchDbSyncEngine', () {
    late CouchDbSyncEngine engine;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      engine = CouchDbSyncEngine(prefs: prefs);
    });

    test('isConfigured is false initially', () {
      expect(engine.isConfigured, false);
    });

    test('isSyncing is false initially', () {
      expect(engine.isSyncing, false);
    });

    test('client is null before initialize', () {
      expect(engine.client, isNull);
    });

    test('tryRestore returns false without stored credentials', () async {
      expect(await engine.tryRestore(), false);
    });

    test('tryRestore returns false with partial credentials', () async {
      SharedPreferences.setMockInitialValues({
        'couchdb_url': 'http://localhost:5984',
      });
      final prefs = await SharedPreferences.getInstance();
      final e = CouchDbSyncEngine(prefs: prefs);
      expect(await e.tryRestore(), false);
    });

    test('markSyncStarted/Complete cycle', () async {
      final statuses = <SyncConnectionStatus>[];
      engine.statusStream.listen(statuses.add);

      engine.markSyncStarted();
      expect(engine.isSyncing, true);

      engine.markSyncComplete();
      expect(engine.isSyncing, false);

      await Future<void>.delayed(Duration.zero);
      expect(statuses, contains(SyncConnectionStatus.syncing));
      expect(statuses, contains(SyncConnectionStatus.connected));
    });

    test('markSyncFailed sets error status', () async {
      final statuses = <SyncConnectionStatus>[];
      engine.statusStream.listen(statuses.add);

      engine.markSyncStarted();
      engine.markSyncFailed();

      await Future<void>.delayed(Duration.zero);
      expect(statuses, contains(SyncConnectionStatus.error));
      expect(engine.isSyncing, false);
    });

    test('pushDocuments returns 0 when not configured', () async {
      final result = await engine.pushDocuments([
        {'_id': 'test:1', 'type': 'test', 'value': 42},
      ]);
      expect(result, 0);
    });

    test('pullChanges returns empty when not configured', () async {
      final result = await engine.pullChanges();
      expect(result.count, 0);
      expect(result.changes, isEmpty);
    });

    test('dispose completes without error', () {
      engine.dispose();
    });
  });

  group('SyncConnectionStatus', () {
    test('has all expected values', () {
      expect(SyncConnectionStatus.values.length, 5);
      expect(SyncConnectionStatus.disconnected.name, 'disconnected');
      expect(SyncConnectionStatus.connecting.name, 'connecting');
      expect(SyncConnectionStatus.connected.name, 'connected');
      expect(SyncConnectionStatus.syncing.name, 'syncing');
      expect(SyncConnectionStatus.error.name, 'error');
    });
  });

  group('SyncResult', () {
    test('success result', () {
      const r = SyncResult(success: true, pushed: 5, pulled: 10);
      expect(r.success, true);
      expect(r.pushed, 5);
      expect(r.pulled, 10);
      expect(r.error, isNull);
    });

    test('failure result', () {
      const r = SyncResult(success: false, error: 'Connection lost');
      expect(r.success, false);
      expect(r.error, 'Connection lost');
    });
  });

  group('PullResult', () {
    test('empty result', () {
      const r = PullResult(changes: {}, lastSeq: '0', count: 0);
      expect(r.count, 0);
      expect(r.changes, isEmpty);
    });

    test('with changes', () {
      const r = PullResult(
        changes: {
          'product': [
            {'_id': 'product:1'},
          ],
          'sale': [
            {'_id': 'sale:1:1'},
            {'_id': 'sale:2:1'},
          ],
        },
        lastSeq: '100-abc',
        count: 3,
      );
      expect(r.count, 3);
      expect(r.changes['product'], hasLength(1));
      expect(r.changes['sale'], hasLength(2));
    });
  });
}
