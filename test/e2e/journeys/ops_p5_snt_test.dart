library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/snt/snt_service.dart';
import 'package:telepos/data/snt/webkassa_snt_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/entities/agent/agent_entity.dart';
import 'package:telepos/domain/entities/supply/supply_entity.dart';
import 'package:telepos/domain/entities/supply/supply_product_entity.dart';
import 'package:telepos/domain/snt/refusing_snt_provider.dart';
import 'package:telepos/domain/snt/snt_assembly.dart';
import 'package:telepos/domain/snt/snt_models.dart';
import 'package:telepos/domain/snt/snt_provider.dart';
import 'package:telepos/domain/snt/snt_provider_registry.dart';
import 'package:telepos/domain/snt/snt_settings.dart';
import 'package:telepos/domain/snt/snt_store.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  const selfBin = '123456789012';
  const supplierBin = '987654321098';

  final self = SntParty(
    bin: selfBin,
    name: 'ТОО TelePOS',
    warehouseCode: 'WH-MAIN',
  );

  final supplier = AgentEntity(
    localId: 1,
    type: 0,
    name: 'ТОО Поставщик',
    legalName: 'ТОО Поставщик Casamel',
    bin: supplierBin,
  );

  SntProductInfo productInfo(int ucode) {
    switch (ucode) {
      case 7001:
        return const SntProductInfo(
          ucode: 7001,
          name: 'Холодильник Samsung RB37',
          unitCode: 796,
          ntin: 'KZ.M.01.7001',
          gtin: '08806090000017',
          tnved: '8418102001',
          isTraceable: true,
          originCountry: 'KR',
        );
      case 7002:
        return const SntProductInfo(
          ucode: 7002,
          name: 'Шина Nokian 205/55 R16',
          unitCode: 796,
          ntin: 'KZ.M.01.7002',
          gtin: '06419440000027',
          isTraceable: true,
          originCountry: 'FI',
        );
      default:
        return SntProductInfo(ucode: ucode, name: 'Товар $ucode');
    }
  }

  const assembly = SntAssembly();

  SntDocument buildInboundSnt({
    required String key,
    required int ucode,
    required String qty,
    required String price,
  }) {
    final supply = SupplyEntity(
      id: 100,
      supplierId: supplier.localId,
      comment: 'Поставка прослеживаемого товара',
      editTime: DateTime(2026, 6, 1).millisecondsSinceEpoch ~/ 1000,
    );
    final products = [
      SupplyProductEntity(
        supplyId: 100,
        ucode: ucode,
        quantity: d(qty),
        price: d(price),
        amount: d(qty) * d(price),
      ),
    ];
    return assembly.fromSupply(
      supply: supply,
      products: products,
      supplier: supplier,
      self: self,
      productInfo: productInfo,
      idempotencyKey: key,
    );
  }

  test(
    'inbound supply of a TRACEABLE good assembles a mandatory СНТ draft',
    () async {
      final doc = buildInboundSnt(
        key: 'snt-A',
        ucode: 7001,
        qty: '5',
        price: '250000',
      );

      expect(doc.direction, SntDirection.inbound);
      expect(doc.operationType, SntOperationType.supply);
      expect(
        doc.sender.bin,
        supplierBin,
        reason: 'inbound sender is the supplier',
      );
      expect(doc.recipient.bin, selfBin, reason: 'inbound recipient is us');
      expect(doc.localSourceType, 'supply');
      expect(doc.localSourceId, 100);
      expect(doc.status, SntStatus.draft);

      expect(doc.lines.length, 1);
      final line = doc.lines.single;
      expect(line.productCode, 7001);
      expect(line.ntin, 'KZ.M.01.7001', reason: 'НКТ carried onto the line');
      expect(line.gtin, '08806090000017', reason: 'GTIN carried onto the line');
      expect(line.isTraceable, isTrue);
      expect(line.quantity, d('5'));
      expect(
        line.amount,
        d('1250000'),
        reason: 'amount = qty*price, Decimal-exact',
      );

      expect(
        doc.hasTraceableGoods,
        isTrue,
        reason: 'traceable goods make the СНТ mandatory',
      );

      final store = InMemorySntDocumentStore();
      final service = SntService(
        provider: const RefusingSntProvider(),
        store: store,
        warehouse: InMemoryVirtualWarehouseStore(),
      );
      await service.saveDraft(doc);
      final loaded = await store.findByKey('snt-A');
      expect(loaded, isNotNull);
      expect(loaded!.status, SntStatus.draft);

      final rt = SntDocument.fromJson(doc.toJson());
      expect(rt.lines.single.amount, d('1250000'));
      expect(rt.sender.bin, supplierBin);
      expect(rt.lines.single.isTraceable, isTrue);
    },
  );

  test(
    'register() while OFFLINE queues the СНТ to the outbox (never blocks)',
    () async {
      final store = InMemorySntDocumentStore();
      final service = SntService(
        provider: const RefusingSntProvider(),
        store: store,
        warehouse: InMemoryVirtualWarehouseStore(),
        isReachable: () async => false,
      );

      final doc = buildInboundSnt(
        key: 'snt-B',
        ucode: 7001,
        qty: '5',
        price: '250000',
      );

      final result = await service.register(doc);
      expect(result.success, isTrue, reason: 'offline never blocks the WMS op');
      expect(result.queued, isTrue);
      expect(result.status, SntStatus.queued);

      final outbox = await store.outbox();
      expect(outbox.length, 1, reason: 'the СНТ is parked in the outbox');
      expect(outbox.single.idempotencyKey, 'snt-B');

      expect(outbox.single.registrationNumber, isNull);
    },
  );

  test(
    'confirming an inbound СНТ books a Виртуальный склад balance (приход)',
    () async {
      final store = InMemorySntDocumentStore();
      final warehouse = InMemoryVirtualWarehouseStore();
      final service = SntService(
        provider: const _ConfirmingSntProvider(),
        store: store,
        warehouse: warehouse,
      );

      final doc = buildInboundSnt(
        key: 'snt-C',
        ucode: 7001,
        qty: '5',
        price: '250000',
      );
      await service.saveDraft(doc);

      expect(await warehouse.balanceOf(7001), isNull);

      final booked = await service.confirmInbound(doc);
      expect(booked.length, 1);
      expect(booked.single.productCode, 7001);
      expect(booked.single.quantity, d('5'), reason: 'приход = +5');

      final stored = await store.findByKey('snt-C');
      expect(stored!.status, SntStatus.confirmed);
      expect(stored.status.isConfirmed, isTrue);

      final bal = await warehouse.balanceOf(7001);
      expect(bal, isNotNull);
      expect(bal!.quantity, d('5'));
      expect(bal.name, 'Холодильник Samsung RB37');
      expect(
        bal.warehouseCode,
        'WH-MAIN',
        reason: 'booked into our receiving warehouse',
      );
    },
  );

  test(
    'two confirmed inbound СНТ accumulate the ВС balance (Decimal-exact)',
    () async {
      final store = InMemorySntDocumentStore();
      final warehouse = InMemoryVirtualWarehouseStore();
      final service = SntService(
        provider: const _ConfirmingSntProvider(),
        store: store,
        warehouse: warehouse,
      );

      await service.confirmInbound(
        buildInboundSnt(key: 'snt-D1', ucode: 7001, qty: '2.355', price: '100'),
      );
      await service.confirmInbound(
        buildInboundSnt(key: 'snt-D2', ucode: 7001, qty: '0.045', price: '100'),
      );

      final bal = await warehouse.balanceOf(7001);
      expect(
        bal!.quantity,
        d('2.400'),
        reason: '2.355 + 0.045 = 2.400 exactly (Decimal, not double)',
      );
    },
  );

  test(
    'outbound supplier-return СНТ books a Виртуальный склад расход',
    () async {
      final store = InMemorySntDocumentStore();
      final warehouse = InMemoryVirtualWarehouseStore();
      final service = SntService(
        provider: const _ConfirmingSntProvider(),
        store: store,
        warehouse: warehouse,
      );

      await service.confirmInbound(
        buildInboundSnt(key: 'snt-E0', ucode: 7002, qty: '10', price: '40000'),
      );
      expect((await warehouse.balanceOf(7002))!.quantity, d('10'));

      final ret = assembly.fromSupplierReturn(
        returnId: 55,
        lines: [SntLineInput(ucode: 7002, quantity: d('3'))],
        supplier: supplier,
        self: self,
        productInfo: productInfo,
        idempotencyKey: 'snt-E1',
      );
      expect(ret.direction, SntDirection.outbound);
      expect(ret.operationType, SntOperationType.supplierReturn);
      expect(ret.sender.bin, selfBin, reason: 'outbound sender is us');
      expect(ret.recipient.bin, supplierBin);

      final booked = await service.confirmOutbound(ret);
      expect(booked.single.quantity, d('7'), reason: '10 − 3 = 7 (расход)');
      expect((await warehouse.balanceOf(7002))!.quantity, d('7'));
      expect((await store.findByKey('snt-E1'))!.status, SntStatus.confirmed);
    },
  );

  test('account-gated WebKassa СНТ provider honestly fails to submit without '
      'creds (no faked КГД registration; doc stays queued)', () async {
    final registry = SntProviderRegistry()
      ..register(
        SntProviderType.webkassa,
        (s) => WebKassaSntProvider(
          fiscalSettings: FiscalSettings(
            operatorType: FiscalOperatorType.webkassa,
          ),
          logger: Talker(),
        ),
      );

    final settings = SntSettings(
      providerType: SntProviderType.webkassa,
      enabled: true,
      ownBin: selfBin,
    );
    final provider = registry.resolve(settings);
    expect(provider.id, 'webkassa', reason: 'real WebKassa provider resolved');

    final reason = provider.validateConfig(settings);
    expect(reason, isNotNull);

    final store = InMemorySntDocumentStore();
    final service = SntService(
      provider: provider,
      store: store,
      warehouse: InMemoryVirtualWarehouseStore(),
      isReachable: () async => true,
    );

    final doc = buildInboundSnt(
      key: 'snt-F',
      ucode: 7001,
      qty: '5',
      price: '250000',
    );
    final result = await service.register(doc);

    expect(result.success, isFalse);
    expect(
      result.registrationNumber,
      isNull,
      reason: 'NEVER fabricate a КГД registration number',
    );

    final stored = await store.findByKey('snt-F');
    expect(stored!.status, SntStatus.queued);
    expect(stored.registrationNumber, isNull);
    expect((await store.outbox()).length, 1);

    final off = SntProviderRegistry().resolve(SntSettings.disabled());
    expect(off.id, 'refusing');
  });

  // Изменение поведения, введённое задачей 2, закреплено здесь, а не
  // оставлено на веру.
  //
  // Раньше эти же пробы про Виртуальный склад ходили через
  // `NoOpSntProvider`: он объявлял `canConfirmInbound: true` и его
  // `confirmInbound` отвечал `ok(status: confirmed)`. То есть на кассе БЕЗ
  // оператора СНТ входящая накладная отмечалась принятой, а в ИС ЭСФ не
  // уходило ничего: подтверждалась накладная, которой никто не видел.
  // Теперь такая касса получает отказ. Пользователь увидит **изменение** —
  // приёмка входящих без оператора перестанет работать, — но работала она
  // только на бумаге.
  test(
    'без оператора СНТ приёмка входящей НЕ подтверждается и склад не двигается',
    () async {
      final store = InMemorySntDocumentStore();
      final warehouse = InMemoryVirtualWarehouseStore();
      final service = SntService(
        provider: const RefusingSntProvider(),
        store: store,
        warehouse: warehouse,
      );

      // Возможность больше не объявляется — именно она заводила
      // вызывающего в этот путь.
      expect(const RefusingSntProvider().capabilities.canConfirmInbound, isFalse);

      final doc = buildInboundSnt(
        key: 'snt-G',
        ucode: 7003,
        qty: '5',
        price: '250000',
      );
      await service.saveDraft(doc);

      final booked = await service.confirmInbound(doc);
      expect(booked, isEmpty, reason: 'ничего не приходуем');
      expect(await warehouse.balanceOf(7003), isNull, reason: 'склад не тронут');

      final stored = await store.findByKey('snt-G');
      expect(stored!.status, SntStatus.failed);
      expect(
        stored.status.isConfirmed,
        isFalse,
        reason: 'накладная НЕ отмечена принятой',
      );
      expect(stored.lastError, isNotNull, reason: 'причина названа словами');
    },
  );
}

/// Настроенный оператор СНТ — тот, у кого приёмка действительно проходит.
///
/// Нужен пробам про Виртуальный склад: их предмет — арифметика прихода и
/// расхода, а не заглушка. Раньше эту роль исполнял `NoOpSntProvider`, и
/// исполнял враньём: подтверждал, ничего никуда не отправив. Здесь роль
/// названа своим именем, и `RefusingSntProvider` из этих проб убран.
class _ConfirmingSntProvider implements SntProvider {
  const _ConfirmingSntProvider();

  @override
  String get id => 'confirming-fake';

  @override
  SntCapabilities get capabilities =>
      const SntCapabilities(canSubmit: true, canConfirmInbound: true);

  @override
  String? validateConfig(SntSettings config) => null;

  @override
  Future<SntResult> authorize(SntSettings config) async => SntResult.ok();

  @override
  Future<SntResult> submit(SntDocument doc) async =>
      SntResult.ok(status: SntStatus.registered, registrationNumber: 'KGD-FAKE');

  @override
  Future<SntResult> confirmInbound(SntDocument doc) async =>
      SntResult.ok(status: SntStatus.confirmed);

  @override
  Future<SntResult> rejectInbound(SntDocument doc, {String? reason}) async =>
      SntResult.ok(status: SntStatus.rejected);

  @override
  Future<SntResult> revoke(SntDocument doc, {String? reason}) async =>
      SntResult.ok(status: SntStatus.revoked);
}
