import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/sync/couchdb_document_mapper.dart';
import 'package:telepos/data/sync/couchdb_sync_engine.dart';
import 'package:telepos/core/logging/app_talker.dart';

class CoordinatorSyncResult {
  const CoordinatorSyncResult({
    required this.ok,
    this.pushed = 0,
    this.pulled = 0,
    this.skippedReason,
  });

  final bool ok;

  final int pushed;

  final int pulled;

  final String? skippedReason;

  bool get skipped => skippedReason != null;

  CoordinatorSyncResult copyWith({
    bool? ok,
    int? pushed,
    int? pulled,
    String? skippedReason,
  }) {
    return CoordinatorSyncResult(
      ok: ok ?? this.ok,
      pushed: pushed ?? this.pushed,
      pulled: pulled ?? this.pulled,
      skippedReason: skippedReason ?? this.skippedReason,
    );
  }

  @override
  String toString() =>
      'CoordinatorSyncResult(ok=$ok, pushed=$pushed, pulled=$pulled, '
      'skipped=$skippedReason)';
}

class CouchDbSyncCoordinator {
  CouchDbSyncCoordinator({
    required AppDatabase db,
    required CouchDbSyncEngine engine,
  }) : _db = db,
       _engine = engine;

  final AppDatabase _db;
  final CouchDbSyncEngine _engine;

  bool _running = false;

  static const int _salePending = 1;
  static const int _saleSynced = 4;
  static const int _refundPending = 1;
  static const int _refundSynced = 3;
  static const int _agentCustomerType = 1;
  static const int _stockDocSynced = 3;

  bool get isConfigured => _engine.isConfigured;

  Future<CoordinatorSyncResult> syncNow() async {
    if (_running) {
      return const CoordinatorSyncResult(
        ok: false,
        skippedReason: 'already_running',
      );
    }
    _running = true;
    try {
      if (!_engine.isConfigured) {
        bool restored = false;
        try {
          restored = await _engine.tryRestore();
        } catch (e) {
          talker.warning('[CouchDB Coordinator] tryRestore failed: $e');
          restored = false;
        }
        if (!restored || !_engine.isConfigured) {
          return const CoordinatorSyncResult(
            ok: false,
            skippedReason: 'not_configured',
          );
        }
      }

      final client = _engine.client;
      if (client == null) {
        return const CoordinatorSyncResult(
          ok: false,
          skippedReason: 'not_configured',
        );
      }
      final reachable = await client.ping();
      if (!reachable) {
        return const CoordinatorSyncResult(ok: false, skippedReason: 'offline');
      }

      _engine.markSyncStarted();
      int pushed = 0;
      int pulled = 0;
      try {
        pushed = await _pushAll();
        pulled = await _pullAll();
        _engine.markSyncComplete();
        talker.info(
          '[CouchDB Coordinator] Sync done (pushed=$pushed, pulled=$pulled)',
        );
        return CoordinatorSyncResult(ok: true, pushed: pushed, pulled: pulled);
      } catch (e, st) {
        _engine.markSyncFailed();
        talker.error('[CouchDB Coordinator] Sync failed', e, st);
        return CoordinatorSyncResult(
          ok: false,
          pushed: pushed,
          pulled: pulled,
          skippedReason: 'error',
        );
      }
    } catch (e, st) {
      talker.error('[CouchDB Coordinator] Unexpected sync error', e, st);
      return const CoordinatorSyncResult(ok: false, skippedReason: 'error');
    } finally {
      _running = false;
    }
  }

  Future<int> _pushAll() async {
    int total = 0;
    total += await _pushSales();
    total += await _pushRefunds();
    total += await _pushShifts();
    total += await _pushAgents();
    total += await _pushWriteoffs();
    total += await _pushMovements();
    total += await _pushInventories();
    total += await _pushSupplierReturns();
    return total;
  }

  Future<int> _pushSales() async {
    final pending = await _db.saleDao.findByState(_salePending);
    if (pending.isEmpty) return 0;

    final docs = <Map<String, dynamic>>[];
    final keys = <({int receiptNo, int posId})>[];
    for (final s in pending) {
      docs.add(CouchDbDocumentMapper.saleToDoc(sale: _saleToMap(s)));
      keys.add((receiptNo: s.receiptNo, posId: s.posId));
    }

    final confirmed = await _engine.pushDocuments(docs);
    if (confirmed <= 0) return 0;

    if (confirmed < docs.length) {
      talker.warning(
        '[CouchDB Coordinator] Partial sale push ($confirmed/${docs.length}); '
        'leaving all PENDING for retry',
      );
      return confirmed;
    }
    for (final k in keys) {
      await _db.saleDao.markSyncedByKey(
        k.receiptNo,
        k.posId,
        syncedState: _saleSynced,
      );
    }
    return confirmed;
  }

  Future<int> _pushRefunds() async {
    final pending = await _db.refundDao.findByState(_refundPending);
    if (pending.isEmpty) return 0;

    final docs = <Map<String, dynamic>>[];
    final ids = <int>[];
    for (final r in pending) {
      docs.add(CouchDbDocumentMapper.refundToDoc(refund: _refundToMap(r)));
      ids.add(r.localId);
    }

    final confirmed = await _engine.pushDocuments(docs);
    if (confirmed <= 0) return 0;

    if (confirmed < docs.length) {
      talker.warning(
        '[CouchDB Coordinator] Partial refund push ($confirmed/${docs.length}); '
        'leaving all PENDING for retry',
      );
      return confirmed;
    }
    await _db.refundDao.setState(_refundSynced, ids);
    return confirmed;
  }

  Future<int> _pushShifts() async {
    final pending = await _db.shiftDao.findAllNonSync();
    if (pending.isEmpty) return 0;

    final docs = <Map<String, dynamic>>[];
    final ids = <int>[];
    for (final sh in pending) {
      docs.add(CouchDbDocumentMapper.shiftToDoc(shift: _shiftToMap(sh)));
      ids.add(sh.id);
    }

    final confirmed = await _engine.pushDocuments(docs);
    if (confirmed <= 0) return 0;

    if (confirmed < docs.length) {
      talker.warning(
        '[CouchDB Coordinator] Partial shift push ($confirmed/${docs.length}); '
        'leaving all PENDING for retry',
      );
      return confirmed;
    }
    for (final id in ids) {
      await _db.shiftDao.markAsSynced(id);
    }
    return confirmed;
  }

  Future<int> _pushAgents() async {
    final candidates = await _db.agentDao.findWithType(_agentCustomerType);
    final pending = candidates.where((a) => a.state != 3).toList();
    if (pending.isEmpty) return 0;

    final docs = <Map<String, dynamic>>[];
    final localIds = <int>[];
    for (final a in pending) {
      docs.add(CouchDbDocumentMapper.agentToDoc(agent: _agentToMap(a)));
      localIds.add(a.localId);
    }

    final confirmed = await _engine.pushDocuments(docs);
    if (confirmed <= 0) return 0;

    if (confirmed < docs.length) {
      talker.warning(
        '[CouchDB Coordinator] Partial agent push ($confirmed/${docs.length}); '
        'leaving all PENDING for retry',
      );
      return confirmed;
    }
    await _db.agentDao.markAsSyncedByLocalId(localIds);
    return confirmed;
  }

  Future<int> _pushWriteoffs() async {
    final pending = await _db.writeoffDao.findNonSynced();
    if (pending.isEmpty) return 0;

    final docs = <Map<String, dynamic>>[];
    final ids = <int>[];
    for (final w in pending) {
      final lines = await _db.writeoffProductDao.findByWriteoffId(w.id);
      docs.add(
        CouchDbDocumentMapper.writeoffToDoc(
          writeoff: _writeoffToMap(w),
          products: lines.map(_writeoffProductToMap).toList(),
        ),
      );
      ids.add(w.id);
    }

    final confirmed = await _engine.pushDocuments(docs);
    if (confirmed <= 0) return 0;
    if (confirmed < docs.length) {
      talker.warning(
        '[CouchDB Coordinator] Partial writeoff push ($confirmed/${docs.length}); '
        'leaving all PENDING for retry',
      );
      return confirmed;
    }
    for (final id in ids) {
      await _db.writeoffDao.setResponse(id, null, _stockDocSynced);
    }
    return confirmed;
  }

  Future<int> _pushMovements() async {
    final pending = await _db.movementDao.findNonSynced();
    if (pending.isEmpty) return 0;

    final docs = <Map<String, dynamic>>[];
    final ids = <int>[];
    for (final m in pending) {
      final lines = await _db.movementProductDao.findByMovementId(m.id);
      docs.add(
        CouchDbDocumentMapper.movementToDoc(
          movement: _movementToMap(m),
          products: lines.map(_movementProductToMap).toList(),
        ),
      );
      ids.add(m.id);
    }

    final confirmed = await _engine.pushDocuments(docs);
    if (confirmed <= 0) return 0;
    if (confirmed < docs.length) {
      talker.warning(
        '[CouchDB Coordinator] Partial movement push ($confirmed/${docs.length}); '
        'leaving all PENDING for retry',
      );
      return confirmed;
    }
    for (final id in ids) {
      await _db.movementDao.setResponse(id, null, _stockDocSynced);
    }
    return confirmed;
  }

  Future<int> _pushInventories() async {
    final pending = await _db.inventoryDao.findNonSynced();
    if (pending.isEmpty) return 0;

    final docs = <Map<String, dynamic>>[];
    final ids = <int>[];
    for (final inv in pending) {
      final lines = await _db.inventoryProductDao.findByInventoryId(inv.id);
      docs.add(
        CouchDbDocumentMapper.inventoryToDoc(
          inventory: _inventoryToMap(inv),
          products: lines.map(_inventoryProductToMap).toList(),
        ),
      );
      ids.add(inv.id);
    }

    final confirmed = await _engine.pushDocuments(docs);
    if (confirmed <= 0) return 0;
    if (confirmed < docs.length) {
      talker.warning(
        '[CouchDB Coordinator] Partial inventory push ($confirmed/${docs.length}); '
        'leaving all PENDING for retry',
      );
      return confirmed;
    }
    for (final id in ids) {
      await _db.inventoryDao.setResponse(id, null, _stockDocSynced);
    }
    return confirmed;
  }

  Future<int> _pushSupplierReturns() async {
    final pending = await _db.supplierReturnDao.findNonSynced();
    if (pending.isEmpty) return 0;

    final docs = <Map<String, dynamic>>[];
    final ids = <int>[];
    for (final sr in pending) {
      final lines = await _db.supplierReturnProductDao.findByReturnId(sr.id);
      docs.add(
        CouchDbDocumentMapper.supplierReturnToDoc(
          supplierReturn: _supplierReturnToMap(sr),
          products: lines.map(_supplierReturnProductToMap).toList(),
        ),
      );
      ids.add(sr.id);
    }

    final confirmed = await _engine.pushDocuments(docs);
    if (confirmed <= 0) return 0;
    if (confirmed < docs.length) {
      talker.warning(
        '[CouchDB Coordinator] Partial supplier_return push ($confirmed/${docs.length}); '
        'leaving all PENDING for retry',
      );
      return confirmed;
    }
    for (final id in ids) {
      await _db.supplierReturnDao.setResponse(id, null, _stockDocSynced);
    }
    return confirmed;
  }

  Future<int> _pullAll() async {
    final result = await _engine.pullChanges();
    if (result.count == 0) return 0;

    int applied = 0;
    final categories = result.changes['category'] ?? const [];
    for (final doc in categories) {
      try {
        applied += await _applyCategory(doc);
      } catch (e) {
        talker.warning('[CouchDB Coordinator] Skip category doc: $e');
      }
    }
    return applied;
  }

  Future<int> _applyCategory(Map<String, dynamic> doc) async {
    final mapped = CouchDbDocumentMapper.docToCategory(doc);
    final id = mapped['id'];
    if (id is! int) return 0;

    await _db.categoryDao.upsertCategory(
      id: id,
      parentId: mapped['parent_id'] as int?,
      name: mapped['name'] as String?,
      globalCategory: mapped['global_category'] as int?,
      createTime: _toDateTime(mapped['create_time']) ?? DateTime.now(),
      editTime: _toDateTime(mapped['edit_time']),
    );
    return 1;
  }

  Map<String, dynamic> _saleToMap(Sale s) => {
    'receipt_no': s.receiptNo,
    'pos_id': s.posId,
    'sale_id': s.saleId,
    'user_id': s.userId,
    'amount': s.amount,
    'change': s.change,
    'time': s.time,
    'store_id': s.storeId,
    'customer_local_id': s.customerLocalId,
    'customer_server_id': s.customerServerId,
    'is_ofd': s.isOfd,
    'state': s.state,
    'is_wholesale': s.isWholesale,
  };

  Map<String, dynamic> _refundToMap(Refund r) => {
    'local_id': r.localId,
    'server_id': r.serverId,
    'sale_receipt_no': r.saleReceiptNo,
    'sale_pos_id': r.salePosId,
    'user_id': r.userId,
    'amount': r.amount,
    'cashback_amount': r.cashbackAmount,
    'time': r.time,
    'state': r.state,
    'is_ofd': r.isOfd,
  };

  Map<String, dynamic> _shiftToMap(Shift sh) => {
    'id': sh.id,
    'user_id': sh.userId,
    'open_time': sh.openTime,
    'is_opened': sh.isOpened,
    'close_time': sh.closeTime,
    'cash_in_pos_on_shift_close': sh.cashInPosOnShiftClose,
    'is_synced': sh.isSynced,
  };

  Map<String, dynamic> _agentToMap(Agent a) => {
    'local_id': a.localId,
    'server_id': a.serverId,
    'type': a.type,
    'store_id': a.storeId,
    'name': a.name,
    'phone': a.phone,
    'bin': a.bin,
    'legal_type': a.legalType,
    'legal_address': a.legalAddress,
    'actual_address': a.actualAddress,
    'note': a.note,
    'legal_name': a.legalName,
    'is_deleted': a.isDeleted,
    'edit_time': a.editTime,
    'server_edit_time': a.serverEditTime,
    'state': a.state,
  };

  Map<String, dynamic> _writeoffToMap(Writeoff w) => {
    'id': w.id,
    'user_id': w.userId,
    'doc_time': w.docTime,
    'reason': w.reason,
    'comment': w.comment,
    'amount': w.amount,
    'state': w.state,
  };

  Map<String, dynamic> _writeoffProductToMap(WriteoffProduct p) => {
    'ucode': p.ucode,
    'quantity': p.quantity.toString(),
    'price': p.price.toString(),
    'amount': p.amount.toString(),
  };

  Map<String, dynamic> _movementToMap(Movement m) => {
    'id': m.id,
    'user_id': m.userId,
    'edit_time': m.editTime,
    'amount': m.amount,
    'comment': m.comment,
    'from_location': m.fromLocation,
    'to_location': m.toLocation,
    'state': m.state,
    'status': m.status,
  };

  Map<String, dynamic> _movementProductToMap(MovementProduct p) => {
    'ucode': p.ucode,
    'quantity': p.quantity.toString(),
    'price': p.price.toString(),
    'amount': p.amount.toString(),
  };

  Map<String, dynamic> _inventoryToMap(Inventory inv) => {
    'id': inv.id,
    'user_id': inv.userId,
    'start_time': inv.startTime,
    'end_time': inv.endTime,
    'status': inv.status,
    'comment': inv.comment,
    'discrepancy_count': inv.discrepancyCount,
    'is_full_count': inv.isFullCount,
    'state': inv.state,
  };

  Map<String, dynamic> _inventoryProductToMap(InventoryProduct p) => {
    'ucode': p.ucode,
    'expected_qty': p.expectedQty.toString(),
    'actual_qty': p.actualQty.toString(),
    'difference': p.difference.toString(),
    'price': p.price.toString(),
  };

  Map<String, dynamic> _supplierReturnToMap(SupplierReturn sr) => {
    'id': sr.id,
    'user_id': sr.userId,
    'supplier_id': sr.supplierId,
    'edit_time': sr.editTime,
    'amount': sr.amount,
    'account_id': sr.accountId,
    'comment': sr.comment,
    'supply_id': sr.supplyId,
    'state': sr.state,
    'status': sr.status,
  };

  Map<String, dynamic> _supplierReturnProductToMap(SupplierReturnProduct p) => {
    'ucode': p.ucode,
    'quantity': p.quantity.toString(),
    'price': p.price.toString(),
    'amount': p.amount.toString(),
  };

  DateTime? _toDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) {
      final ms = raw > 100000000000 ? raw : raw * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    if (raw is String) {
      final asInt = int.tryParse(raw);
      if (asInt != null) return _toDateTime(asInt);
      return DateTime.tryParse(raw);
    }
    return null;
  }
}
