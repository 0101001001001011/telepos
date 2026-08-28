library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/datasources/remote/couchdb_client.dart';
import 'package:telepos/data/sync/couchdb_document_mapper.dart';
import 'package:telepos/data/sync/couchdb_sync_coordinator.dart';
import 'package:telepos/data/sync/couchdb_sync_engine.dart';
import 'package:telepos/core/logging/app_talker.dart' as app_log;

Decimal d(String v) => Decimal.parse(v);

class _FakeClient extends CouchDbClient {
  _FakeClient()
    : super(url: 'http://x', dbName: 'db', username: 'u', password: 'p');
  @override
  Future<bool> ping() async => true;
}

class _FakeEngine extends CouchDbSyncEngine {
  _FakeEngine(SharedPreferences prefs) : super(prefs: prefs);

  final List<Map<String, dynamic>> pushed = [];
  final _client = _FakeClient();

  double confirmRatio = 1.0;

  @override
  bool get isConfigured => true;

  @override
  CouchDbClient? get client => _client;

  @override
  Future<bool> tryRestore() async => true;

  @override
  Future<int> pushDocuments(List<Map<String, dynamic>> docs) async {
    pushed.addAll(docs);
    if (confirmRatio >= 1.0) return docs.length;
    return (docs.length * confirmRatio).floor();
  }

  @override
  Future<PullResult> pullChanges({int limit = 1000}) async =>
      const PullResult(changes: {}, lastSeq: '', count: 0);

  @override
  void markSyncStarted() {}
  @override
  void markSyncComplete() {}
  @override
  void markSyncFailed() {}
}

void main() {
  late AppDatabase db;
  var talkerReady = false;

  setUp(() {
    if (!talkerReady) {
      app_log.installLogger(Talker());
      talkerReady = true;
    }
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  const ts = 1700000000;

  Future<int> seedWriteoff() async {
    final id = await db.writeoffDao.insertWriteoff(
      WriteoffsCompanion(
        userId: const drift.Value(1),
        docTime: const drift.Value(ts),
        reason: const drift.Value(1),
        comment: const drift.Value('просрочка'),
        amount: drift.Value(d('900')),
        state: const drift.Value(1),
      ),
    );
    await db.writeoffProductDao.insertProduct(
      WriteoffProductsCompanion(
        writeoffId: drift.Value(id),
        ucode: const drift.Value(1001),
        quantity: drift.Value(d('2')),
        price: drift.Value(d('450')),
        amount: drift.Value(d('900')),
      ),
    );
    return id;
  }

  Future<int> seedMovement() async {
    final id = await db.movementDao.insertMovement(
      MovementsCompanion(
        userId: const drift.Value(1),
        editTime: const drift.Value(ts),
        amount: drift.Value(d('1500')),
        comment: const drift.Value('на склад-2'),
        fromLocation: const drift.Value('Касса-1'),
        toLocation: const drift.Value('Склад-2'),
        state: const drift.Value(1),
        status: const drift.Value(1),
      ),
    );
    await db.movementProductDao.insertProduct(
      MovementProductsCompanion(
        movementId: drift.Value(id),
        ucode: const drift.Value(1002),
        quantity: drift.Value(d('10')),
        price: drift.Value(d('150')),
        amount: drift.Value(d('1500')),
      ),
    );
    return id;
  }

  Future<int> seedInventory() async {
    final id = await db.inventoryDao.insertInventory(
      InventoriesCompanion(
        userId: const drift.Value(1),
        startTime: const drift.Value(ts),
        endTime: const drift.Value(ts + 60),
        status: const drift.Value(1),
        comment: const drift.Value('ночная'),
        discrepancyCount: const drift.Value(1),
        isFullCount: const drift.Value(true),
        state: const drift.Value(1),
      ),
    );
    await db.inventoryProductDao.insertProduct(
      InventoryProductsCompanion(
        inventoryId: drift.Value(id),
        ucode: const drift.Value(1003),
        expectedQty: drift.Value(d('100')),
        actualQty: drift.Value(d('97')),
        difference: drift.Value(d('-3')),
        price: drift.Value(d('280')),
      ),
    );
    return id;
  }

  Future<int> seedSupplierReturn() async {
    final id = await db.supplierReturnDao.insertReturn(
      SupplierReturnsCompanion(
        userId: const drift.Value(1),
        supplierId: const drift.Value(7),
        editTime: const drift.Value(ts),
        amount: drift.Value(d('2670')),
        accountId: const drift.Value(3),
        comment: const drift.Value('брак'),
        supplyId: const drift.Value(42),
        state: const drift.Value(1),
        status: const drift.Value(1),
      ),
    );
    await db.supplierReturnProductDao.insertProduct(
      SupplierReturnProductsCompanion(
        supplierReturnId: drift.Value(id),
        ucode: const drift.Value(1004),
        quantity: drift.Value(d('3')),
        price: drift.Value(d('890')),
        amount: drift.Value(d('2670')),
      ),
    );
    return id;
  }

  test('mappers build correct type, _id and key fields with line items', () {
    final wDoc = CouchDbDocumentMapper.writeoffToDoc(
      writeoff: {
        'id': 5,
        'user_id': 1,
        'doc_time': ts,
        'reason': 1,
        'comment': 'просрочка',
        'amount': d('900'),
        'state': 1,
      },
      products: const [
        {'ucode': 1001, 'quantity': '2', 'price': '450', 'amount': '900'},
      ],
    );
    expect(wDoc['type'], 'writeoff');
    expect(wDoc['_id'], 'writeoff:5');
    expect(wDoc['writeoff_id'], 5);
    expect(wDoc['reason'], 1);
    expect(wDoc['amount'], '900');
    expect(wDoc['amount'], isA<String>());
    expect((wDoc['products'] as List), hasLength(1));
    expect(
      CouchDbDocumentMapper.typeFromDocId(wDoc['_id'] as String),
      'writeoff',
    );

    final mDoc = CouchDbDocumentMapper.movementToDoc(
      movement: {
        'id': 8,
        'user_id': 1,
        'edit_time': ts,
        'amount': d('1500'),
        'comment': 'c',
        'from_location': 'Касса-1',
        'to_location': 'Склад-2',
        'state': 1,
        'status': 1,
      },
      products: const [
        {'ucode': 1002, 'quantity': '10', 'price': '150', 'amount': '1500'},
      ],
    );
    expect(mDoc['type'], 'movement');
    expect(mDoc['_id'], 'movement:8');
    expect(mDoc['from_location'], 'Касса-1');
    expect(mDoc['to_location'], 'Склад-2');
    expect(mDoc['amount'], '1500');
    expect((mDoc['products'] as List), hasLength(1));

    final iDoc = CouchDbDocumentMapper.inventoryToDoc(
      inventory: {
        'id': 11,
        'user_id': 1,
        'start_time': ts,
        'end_time': ts + 60,
        'status': 1,
        'comment': 'ночная',
        'discrepancy_count': 1,
        'is_full_count': true,
        'state': 1,
      },
      products: const [
        {
          'ucode': 1003,
          'expected_qty': '100',
          'actual_qty': '97',
          'difference': '-3',
          'price': '280',
        },
      ],
    );
    expect(iDoc['type'], 'inventory');
    expect(iDoc['_id'], 'inventory:11');
    expect(iDoc['discrepancy_count'], 1);
    expect(iDoc['is_full_count'], true);
    expect((iDoc['products'] as List).first['difference'], '-3');

    final sDoc = CouchDbDocumentMapper.supplierReturnToDoc(
      supplierReturn: {
        'id': 14,
        'user_id': 1,
        'supplier_id': 7,
        'edit_time': ts,
        'amount': d('2670'),
        'account_id': 3,
        'comment': 'брак',
        'supply_id': 42,
        'state': 1,
        'status': 1,
      },
      products: const [
        {'ucode': 1004, 'quantity': '3', 'price': '890', 'amount': '2670'},
      ],
    );
    expect(sDoc['type'], 'supplier_return');
    expect(sDoc['_id'], 'supplier_return:14');
    expect(sDoc['supplier_id'], 7);
    expect(sDoc['supply_id'], 42);
    expect(sDoc['amount'], '2670');
    expect((sDoc['products'] as List), hasLength(1));

    expect(CouchDbDocumentMapper.docToWriteoff(wDoc)['id'], 5);
    expect(CouchDbDocumentMapper.docToMovement(mDoc)['to_location'], 'Склад-2');
    expect(CouchDbDocumentMapper.docToInventory(iDoc)['discrepancy_count'], 1);
    expect(CouchDbDocumentMapper.docToSupplierReturn(sDoc)['supply_id'], 42);
  });

  test('coordinator pushes writeoff/movement/inventory/supplier_return and '
      'marks them SYNCED on full confirmation', () async {
    await seedWriteoff();
    await seedMovement();
    await seedInventory();
    await seedSupplierReturn();

    expect(await db.writeoffDao.countUnsynced(), 1);
    expect(await db.movementDao.countUnsynced(), 1);
    expect(await db.inventoryDao.countUnsynced(), 1);
    expect(await db.supplierReturnDao.countUnsynced(), 1);

    final prefs = await SharedPreferences.getInstance();
    final engine = _FakeEngine(prefs);
    final coord = CouchDbSyncCoordinator(db: db, engine: engine);

    final result = await coord.syncNow();
    expect(result.ok, isTrue, reason: result.toString());

    final types = engine.pushed.map((d) => d['type']).toSet();
    expect(
      types,
      containsAll(<String>{
        'writeoff',
        'movement',
        'inventory',
        'supplier_return',
      }),
    );

    final wPushed = engine.pushed.firstWhere((d) => d['type'] == 'writeoff');
    expect((wPushed['products'] as List), hasLength(1));
    expect((wPushed['products'] as List).first['amount'], '900');

    expect(result.pushed, greaterThanOrEqualTo(4));

    expect(await db.writeoffDao.countUnsynced(), 0);
    expect(await db.movementDao.countUnsynced(), 0);
    expect(await db.inventoryDao.countUnsynced(), 0);
    expect(await db.supplierReturnDao.countUnsynced(), 0);
  });

  test(
    'partial confirmation leaves stock docs PENDING for idempotent retry',
    () async {
      await seedWriteoff();
      await seedWriteoff();
      expect(await db.writeoffDao.countUnsynced(), 2);

      final prefs = await SharedPreferences.getInstance();
      final engine = _FakeEngine(prefs)..confirmRatio = 0.5;
      final coord = CouchDbSyncCoordinator(db: db, engine: engine);

      final result = await coord.syncNow();
      expect(result.ok, isTrue);

      expect(
        await db.writeoffDao.countUnsynced(),
        2,
        reason: 'partial batch must not silently mark records synced',
      );
    },
  );

  test(
    'unconfigured engine -> syncNow is a safe no-op; stock rows untouched',
    () async {
      await seedWriteoff();
      await seedMovement();
      await seedInventory();
      await seedSupplierReturn();

      final prefs = await SharedPreferences.getInstance();
      final engine = CouchDbSyncEngine(prefs: prefs);
      final coord = CouchDbSyncCoordinator(db: db, engine: engine);

      final result = await coord.syncNow();
      expect(result.ok, isFalse);
      expect(result.skipped, isTrue);
      expect(result.skippedReason, 'not_configured');
      expect(result.pushed, 0);

      expect(await db.writeoffDao.countUnsynced(), 1);
      expect(await db.movementDao.countUnsynced(), 1);
      expect(await db.inventoryDao.countUnsynced(), 1);
      expect(await db.supplierReturnDao.countUnsynced(), 1);
    },
  );
}
