import 'package:decimal/decimal.dart';
// `Value` и `*Companion` — вставка приехавшего чека идёт напрямую: метода
// вставки нет ни у `SaleDao`, ни у `SaleProductDao` (так же пишут и юзкейсы).
import 'package:drift/drift.dart' show Value;
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

  /// Отложенный чек: владельца не имеет, доступен для подъёма (I156).
  static const int _saleDeferred = 3;

  /// Отложенный чек, отозванный закрытием смены: не отложен и не продан.
  static const int _saleWithdrawn = 9;

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

  /// Отобрать из очереди **только те записи, чьи документы доехали**.
  ///
  /// # Почему по документу, а не по пакету
  ///
  /// До 2026-09-19 каждая из девяти отправок отмечала очередь так: «принято
  /// меньше, чем послали — оставить в очереди ВСЁ и повторить». Звучит
  /// осторожно, а работает наоборот. Отказ, который не разрешится никогда
  /// (документ без `_id`, запрет сервера), держит в очереди все соседние
  /// документы, уже лежащие на сервере. Следующий круг отправляет их снова,
  /// они сталкиваются сами с собой, и пакет не подтверждается **никогда** —
  /// очередь растёт без предела (находка 4 спеки).
  ///
  /// Отметка по документу разрывает эту связь: доехавшее уходит из очереди
  /// независимо от судьбы соседей.
  ///
  /// # Соответствие по МЕСТУ, а не по порядку ответа
  ///
  /// `docs[i]` и `keys[i]` — один и тот же объект, а CouchDB отвечает
  /// строками в своём порядке. Поэтому доехавшесть спрашивается по
  /// идентификатору документа, а не по номеру строки ответа.
  ///
  /// # Неразрешимый отказ слышен отдельно
  ///
  /// `conflict` разрешится сам, как только шаг 2 приложит ревизию, — о нём
  /// уровнем `warning` уже сказал движок. А `bad_request` не разрешится
  /// ничем, и такой документ будет возвращаться каждый круг до конца
  /// времён: об этом надо говорить громче и отдельно, иначе он утонет в
  /// шуме повторов.
  Future<int> _markLanded<K>({
    required CouchDbPushResult result,
    required List<Map<String, dynamic>> docs,
    required List<K> keys,
    required Future<void> Function(List<K> landed) mark,
    required String what,
  }) async {
    if (docs.length != keys.length) {
      // Рассинхрон списков — дефект звавшего, и молча отметить не тот
      // документ хуже, чем не отметить ничего.
      throw StateError(
        'CouchDB $what: документов ${docs.length}, ключей ${keys.length}',
      );
    }

    final landed = <K>[];
    for (var i = 0; i < docs.length; i++) {
      final id = docs[i]['_id'] as String?;
      if (id != null && result.landed(id)) landed.add(keys[i]);
    }
    if (landed.isNotEmpty) await mark(landed);

    final stuck = result.rejected.where((r) => !r.mayResolveOnRetry).toList();
    if (stuck.isNotEmpty) {
      talker.warning(
        '[CouchDB Coordinator] $what: ${stuck.length} документ(ов) не уедут '
        'без вмешательства — ${stuck.join('; ')}',
      );
    }
    return landed.length;
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
    total += await _pushBonusEntries();
    total += await _pushDeferredSales();
    return total;
  }

  /// Отправить свои записи бонусного журнала — задача 13, шаг 9.
  ///
  /// Отправляются только **свои** (`state = 1`): чужие приехали оттуда,
  /// куда их и отправлять, а стартовый остаток миграции помечен `null`
  /// нарочно — у соседней кассы он свой, и сложить их значило бы удвоить
  /// бонусы каждому клиенту.
  Future<int> _pushBonusEntries() async {
    final pending = await _db.bonusEntryDao.pendingForPush();
    if (pending.isEmpty) return 0;

    final docs = <Map<String, dynamic>>[];
    final ids = <int>[];
    for (final e in pending) {
      docs.add(CouchDbDocumentMapper.bonusEntryToDoc(_bonusEntryToMap(e)));
      ids.add(e.id);
    }

    final result = await _engine.pushDocuments(docs);
    return _markLanded(
      result: result,
      docs: docs,
      keys: ids,
      mark: _db.bonusEntryDao.markPushed,
      what: 'бонусный журнал',
    );
  }

  Map<String, dynamic> _bonusEntryToMap(BonusEntry e) => {
    'origin_pos_id': e.originPosId,
    'origin_entry_id': e.originEntryId,
    'account_id': e.accountId,
    'kind': e.kind,
    'amount': e.amount,
    'receipt_no': e.receiptNo,
    'pos_id': e.posId,
    'refund_local_id': e.refundLocalId,
    'user_id': e.userId,
    'reason': e.reason,
    'time': e.time,
  };

  /// Строка отложенного чека так, как её везёт документ.
  ///
  /// Шапки мало: у отложенного чека вся суть в строках. `_pushSales`
  /// отправляет проданные чеки **без строк** (`saleToDoc` получает пустой
  /// список по умолчанию) — вверх этого хватало, а для подъёма на соседней
  /// кассе значило бы поднять пустую корзину.
  Map<String, dynamic> _saleLineToMap(SaleProduct p) => {
    'ucode': p.ucode,
    'barcode': p.barcode,
    'category_id': p.categoryId,
    'quantity': p.quantity.toString(),
    'price': p.price.toString(),
    'price_before': p.priceBefore.toString(),
  };

  /// Отправить **свои** отложенные чеки — они и есть предмет обмена между
  /// кассами.
  ///
  /// # Почему только свои
  ///
  /// Чужой отложенный чек приехал оттуда, куда его и отправлять. Отправить
  /// его обратно значит переписать документ соседа своей ревизией и, хуже
  /// того, стереть чужую отметку о занятии.
  ///
  /// # Почему `state = 3`, а не «всё непроданное»
  ///
  /// Чек в работе (`state = 0`) принадлежит рабочему месту и не отложен —
  /// показывать его соседней кассе значит предложить поднять корзину,
  /// которую прямо сейчас набирают. Отложенный владельца не имеет (I156),
  /// и это ровно то состояние, из которого его законно поднять.
  Future<int> _pushDeferredSales() async {
    final ownPosId = await _ownPosId();
    if (ownPosId == null) return 0;

    final deferred = await _db.saleDao.findByState(_saleDeferred);
    final mine = deferred.where((s) => s.posId == ownPosId).toList();
    if (mine.isEmpty) return 0;

    final docs = <Map<String, dynamic>>[];
    final keys = <({int receiptNo, int posId})>[];
    for (final s in mine) {
      final lines = await _db.saleProductDao.findBySale(s.receiptNo, s.posId);
      docs.add(
        CouchDbDocumentMapper.saleToDoc(
          sale: {..._saleToMap(s), 'claimed_by_pos_id': null},
          products: lines.map(_saleLineToMap).toList(),
        ),
      );
      keys.add((receiptNo: s.receiptNo, posId: s.posId));
    }

    final result = await _engine.pushDocuments(docs);
    // Отложенный чек из очереди **не вычёркивается**: он остаётся отложенным
    // и обязан уезжать снова при каждом изменении. Отметка здесь означала бы
    // «отправлен один раз и забыт», и правка корзины до соседней кассы уже
    // не доехала бы.
    return result.confirmedCount;
  }

  /// Занять отложенный чек соседней кассы — «сравни и запиши».
  ///
  /// # Что здесь на самом деле происходит
  ///
  /// Занятие пишется **с текущей ревизией документа**. Кто успел — получил
  /// `ok`; опоздавший получает `409` и узнаёт, что чек занят. Проверка
  /// делается сервером и атомарна: это единственный способ не продать одну
  /// корзину дважды, когда её видят две кассы, а опрос идёт раз в пять
  /// минут.
  ///
  /// Возвращает `null` при успехе, иначе — **номер кассы**, которая заняла
  /// чек раньше, либо `0`, если занявшего назвать нечем (гонка, документа
  /// уже нет, связи нет). Ноль отдельным значением, а не `null`: «занято
  /// неизвестно кем» и «свободно» — противоположные ответы.
  ///
  /// # Без связи — отказ, а не догадка
  ///
  /// Сервера нет — занять нечем, и подъём чужого чека обязан не состояться.
  /// Свой отложенный чек поднимается как прежде, без всякой сети: его не
  /// видит никто другой, и занимать его не у кого.
  Future<int?> claimDeferred({
    required int receiptNo,
    required int posId,
    required int byPosId,
  }) async {
    final client = _engine.client;
    if (client == null) return 0;

    final docId = CouchDbDocumentMapper.saleDocId(receiptNo, posId);
    try {
      final doc = await client.getDocument(docId);
      if (doc == null) return 0;

      final already = CouchDbDocumentMapper.claimedByPosId(doc);
      if (already != null && already != byPosId) return already;

      final rev = doc['_rev'] as String?;
      if (rev == null) return 0;

      final ok = await client.putDocument(docId, {
        ...doc,
        '_rev': rev,
        'claimed_by_pos_id': byPosId,
      });
      if (ok == null) {
        // `putDocument` глотает 409 и отвечает `null`. Отличить «нас
        // опередили» от «сервер лёг» отсюда нельзя, поэтому спрашиваем
        // документ заново: если занят не нами — значит опередили.
        final after = await client.getDocument(docId);
        final who = after == null
            ? null
            : CouchDbDocumentMapper.claimedByPosId(after);
        return who != null && who != byPosId ? who : 0;
      }
      return null;
    } on Object catch (e) {
      talker.warning('[CouchDB Coordinator] Занять чек $docId не вышло: $e');
      return 0;
    }
  }

  /// Отозвать свой отложенный чек с сервера — он больше никому не нужен.
  ///
  /// Документ не удаляется, а помечается непредлагаемым: удаление в CouchDB
  /// оставляет надгробие и требует ревизии, а нам достаточно, чтобы приём у
  /// соседа увидел «уже не отложен» и убрал корзину из пула — эту ветку
  /// `_applyDeferredSale` уже умеет.
  ///
  /// Лучшее усилие: отказ не поднимается наверх. Закрытие смены важнее, чем
  /// лишняя строка в чужом пуле.
  Future<void> withdrawDeferred({
    required int receiptNo,
    required int posId,
  }) async {
    final client = _engine.client;
    if (client == null) return;
    final docId = CouchDbDocumentMapper.saleDocId(receiptNo, posId);
    try {
      final doc = await client.getDocument(docId);
      if (doc == null) return;
      final rev = doc['_rev'] as String?;
      if (rev == null) return;
      await client.putDocument(docId, {
        ...doc,
        '_rev': rev,
        // Состояние «отменён»: не отложен и не продан. Приём у соседа
        // смотрит именно на «не отложен».
        'state': _saleWithdrawn,
      });
    } on Object catch (e) {
      talker.warning('[CouchDB Coordinator] Отозвать $docId не вышло: $e');
    }
  }

  /// Номер этой кассы, либо `null` — касса ещё не настроена.
  Future<int?> _ownPosId() async {
    final pos = await _db.thisPosDao.get();
    return pos?.id;
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

    final result = await _engine.pushDocuments(docs);
    return _markLanded(
      result: result,
      docs: docs,
      keys: keys,
      what: 'чеки продаж',
      mark: (landed) async {
        for (final k in landed) {
          await _db.saleDao.markSyncedByKey(
            k.receiptNo,
            k.posId,
            syncedState: _saleSynced,
          );
        }
      },
    );
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

    final result = await _engine.pushDocuments(docs);
    return _markLanded(
      result: result,
      docs: docs,
      keys: ids,
      what: 'возвраты',
      mark: (landed) => _db.refundDao.setState(_refundSynced, landed),
    );
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

    final result = await _engine.pushDocuments(docs);
    return _markLanded(
      result: result,
      docs: docs,
      keys: ids,
      what: 'смены',
      mark: (landed) async {
        for (final id in landed) {
          await _db.shiftDao.markAsSynced(id);
        }
      },
    );
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

    final result = await _engine.pushDocuments(docs);
    return _markLanded(
      result: result,
      docs: docs,
      keys: localIds,
      what: 'контрагенты',
      mark: _db.agentDao.markAsSyncedByLocalId,
    );
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

    final result = await _engine.pushDocuments(docs);
    return _markLanded(
      result: result,
      docs: docs,
      keys: ids,
      what: 'списания',
      mark: (landed) async {
        for (final id in landed) {
          await _db.writeoffDao.setResponse(id, null, _stockDocSynced);
        }
      },
    );
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

    final result = await _engine.pushDocuments(docs);
    return _markLanded(
      result: result,
      docs: docs,
      keys: ids,
      what: 'перемещения',
      mark: (landed) async {
        for (final id in landed) {
          await _db.movementDao.setResponse(id, null, _stockDocSynced);
        }
      },
    );
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

    final result = await _engine.pushDocuments(docs);
    return _markLanded(
      result: result,
      docs: docs,
      keys: ids,
      what: 'ревизии остатков',
      mark: (landed) async {
        for (final id in landed) {
          await _db.inventoryDao.setResponse(id, null, _stockDocSynced);
        }
      },
    );
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

    final result = await _engine.pushDocuments(docs);
    return _markLanded(
      result: result,
      docs: docs,
      keys: ids,
      what: 'возвраты поставщику',
      mark: (landed) async {
        for (final id in landed) {
          await _db.supplierReturnDao.setResponse(id, null, _stockDocSynced);
        }
      },
    );
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

    // Бонусный журнал — вариант C сведения: реплицируется журнал, баланс
    // считает каждая касса сама. Порядок доставки на результат не влияет
    // (сумма не зависит от порядка слагаемых), повторная доставка ничего
    // не меняет (ключ по паре «породившая касса + её номер записи»).
    // Проверено числами в `bonus_journal_reconciliation_test.dart`.
    final bonusEntries = result.changes['bonus_entry'] ?? const [];
    for (final doc in bonusEntries) {
      try {
        applied += await _applyBonusEntry(doc);
      } catch (e) {
        talker.warning('[CouchDB Coordinator] Skip bonus_entry doc: $e');
      }
    }

    // Чеки. Документы этого рода приезжали и **молча выбрасывались**: ветки
    // `'sale'` здесь не было вовсе, хотя движок их уже группировал.
    final sales = result.changes['sale'] ?? const [];
    for (final doc in sales) {
      try {
        applied += await _applyDeferredSale(doc);
      } catch (e) {
        talker.warning('[CouchDB Coordinator] Пропущен чек: $e');
      }
    }
    return applied;
  }

  /// Применить приехавший чек — и только если он **отложенный**.
  ///
  /// # Что принимается, а что нет
  ///
  /// Принимается ровно одно: **чужой отложенный чек** (`state = 3`), и то
  /// пока он свободен. Всё остальное отбрасывается сознательно:
  ///
  /// * **проданный чек соседа** не принимается никогда. Решение заказчика
  ///   2026-09-19: между кассами ездит только отложенный, где продажи ещё
  ///   нет. Приняв проданный, мы завели бы у себя чужую выручку, и она
  ///   попала бы в нашу смену, ящик и X/Z-отчёт;
  /// * **свой собственный чек** — он приехал оттуда, куда мы его и
  ///   отправили; применить его значило бы затереть местную правду
  ///   доставкой (тот же приём, что у `_applyBonusEntry`);
  /// * **занятый чужой** — его уже поднимает другая касса, и показывать его
  ///   в пуле значит предлагать кассиру то, чего он не получит.
  ///
  /// # Идемпотентность
  ///
  /// Ключ строки — пара `{receiptNo, posId}`, та же, что у документа.
  /// Повторная доставка попадает в ту же строку. Строки товара переписы­
  /// ваются целиком: корзину правят на кассе-владельце, и «дописать
  /// разницу» здесь значило бы гадать.
  Future<int> _applyDeferredSale(Map<String, dynamic> doc) async {
    final mapped = CouchDbDocumentMapper.docToSale(doc);
    final receiptNo = mapped['receipt_no'];
    final posId = mapped['pos_id'];
    if (receiptNo is! int || posId is! int) return 0;

    final ownPosId = await _ownPosId();
    if (ownPosId == null || posId == ownPosId) return 0;

    final claimedBy = CouchDbDocumentMapper.claimedByPosId(doc);
    final isDeferred = mapped['state'] == _saleDeferred;

    if (!isDeferred || (claimedBy != null && claimedBy != ownPosId)) {
      // Чек продан, отменён или занят соседом — в нашем пуле ему не место.
      // Убираем, если он там уже лежал: пул, показывающий недоступное,
      // хуже пустого.
      final existing = await _db.saleDao.findByKey(receiptNo, posId);
      if (existing == null || existing.state != _saleDeferred) return 0;
      await _db.saleProductDao.deleteBySale(receiptNo, posId);
      await _db.saleDao.deleteSale(receiptNo, posId);
      return 1;
    }

    final lines = CouchDbDocumentMapper.docToSaleLines(doc);
    await _db.transaction(() async {
      await _db
          .into(_db.sales)
          .insertOnConflictUpdate(
            SalesCompanion.insert(
              receiptNo: receiptNo,
              posId: posId,
              userId: (mapped['user_id'] as int?) ?? 0,
              amount: _toDecimal(mapped['amount']),
              time: (mapped['time'] as int?) ?? 0,
              state: Value(_saleDeferred),
              // Владельца у отложенного чека нет (И156), и у чужого — тем
              // более: рабочих мест соседней кассы мы не знаем.
              terminalId: const Value(null),
              isWholesale: Value((mapped['is_wholesale'] as bool?) ?? false),
              storeId: Value(mapped['store_id'] as int?),
              customerLocalId: Value(mapped['customer_local_id'] as int?),
              customerServerId: Value(mapped['customer_server_id'] as int?),
            ),
          );

      await _db.saleProductDao.deleteBySale(receiptNo, posId);
      for (final line in lines) {
        final ucode = line['ucode'];
        if (ucode is! int) continue;
        await _db
            .into(_db.saleProducts)
            .insert(
              SaleProductsCompanion.insert(
                receiptNo: Value(receiptNo),
                posId: Value(posId),
                ucode: ucode,
                barcode: Value(line['barcode'] as int?),
                categoryId: Value(line['category_id'] as int?),
                quantity: _toDecimal(line['quantity']),
                price: _toDecimal(line['price']),
                priceBefore: _toDecimal(line['price_before']),
              ),
            );
      }
    });
    return 1;
  }

  /// Деньги и количества — строкой через [Decimal], никогда через `double`
  /// (И159: третий знак теряется молча).
  static Decimal _toDecimal(Object? v) {
    if (v == null) return Decimal.zero;
    return Decimal.tryParse(v.toString()) ?? Decimal.zero;
  }

  Future<int> _applyBonusEntry(Map<String, dynamic> doc) async {
    final m = CouchDbDocumentMapper.docToBonusEntry(doc);
    final originPosId = m['origin_pos_id'];
    final originEntryId = m['origin_entry_id'];
    final accountId = m['account_id'];
    final kind = m['kind'];
    if (originPosId is! int ||
        originEntryId is! int ||
        accountId is! int ||
        kind is! int) {
      return 0;
    }
    // Своя же запись, вернувшаяся из обмена, не принимается: она уже
    // здесь, и `applyRemote` отличил бы её по ключу — но тогда касса
    // пересчитывала бы баланс на каждом круге обмена без надобности.
    if (originPosId == await _db.bonusEntryDao.ownPosId()) return 0;

    final applied = await _db.bonusEntryDao.applyRemote(
      originPosId: originPosId,
      originEntryId: originEntryId,
      accountId: accountId,
      kind: kind,
      // Деньги приезжают строкой десятичного числа (I159): `double` терял
      // бы третий знак молча.
      amount: Decimal.parse((m['amount'] ?? '0').toString()),
      receiptNo: m['receipt_no'] as int?,
      posId: m['pos_id'] as int?,
      refundLocalId: m['refund_local_id'] as int?,
      userId: m['user_id'] as int?,
      reason: m['reason'] as String?,
      time: (m['time'] as num?)?.toInt() ?? 0,
    );
    return applied ? 1 : 0;
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
