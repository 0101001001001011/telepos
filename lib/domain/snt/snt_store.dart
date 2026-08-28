import 'package:decimal/decimal.dart';

import 'package:telepos/domain/snt/snt_models.dart';

abstract interface class SntDocumentStore {
  Future<void> save(SntDocument doc);

  Future<SntDocument?> findByKey(String idempotencyKey);

  Future<List<SntDocument>> list({SntDirection? direction, SntStatus? status});

  Future<List<SntDocument>> outbox();

  Future<void> remove(String idempotencyKey);
}

class InMemorySntDocumentStore implements SntDocumentStore {
  final Map<String, SntDocument> _docs = {};

  @override
  Future<void> save(SntDocument doc) async {
    _docs[doc.idempotencyKey] = doc;
  }

  @override
  Future<SntDocument?> findByKey(String idempotencyKey) async =>
      _docs[idempotencyKey];

  @override
  Future<List<SntDocument>> list({
    SntDirection? direction,
    SntStatus? status,
  }) async {
    final list = _docs.values.where((d) {
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
    _docs.remove(idempotencyKey);
  }
}

abstract interface class VirtualWarehouseStore {
  Future<VirtualWarehouseBalance> applyDelta({
    required int productCode,
    required String name,
    required Decimal delta,
    int unitCode = 796,
    String? warehouseCode,
    String? originCountry,
  });

  Future<VirtualWarehouseBalance?> balanceOf(int productCode);

  Future<List<VirtualWarehouseBalance>> all();
}

class InMemoryVirtualWarehouseStore implements VirtualWarehouseStore {
  final Map<int, VirtualWarehouseBalance> _balances = {};

  @override
  Future<VirtualWarehouseBalance> applyDelta({
    required int productCode,
    required String name,
    required Decimal delta,
    int unitCode = 796,
    String? warehouseCode,
    String? originCountry,
  }) async {
    final existing = _balances[productCode];
    final next = (existing?.quantity ?? Decimal.zero) + delta;
    final updated = VirtualWarehouseBalance(
      productCode: productCode,
      name: existing?.name ?? name,
      quantity: next,
      unitCode: existing?.unitCode ?? unitCode,
      warehouseCode: warehouseCode ?? existing?.warehouseCode,
      originCountry: originCountry ?? existing?.originCountry,
    );
    _balances[productCode] = updated;
    return updated;
  }

  @override
  Future<VirtualWarehouseBalance?> balanceOf(int productCode) async =>
      _balances[productCode];

  @override
  Future<List<VirtualWarehouseBalance>> all() async =>
      _balances.values.toList()
        ..sort((a, b) => a.productCode.compareTo(b.productCode));
}
