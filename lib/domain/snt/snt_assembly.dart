import 'package:decimal/decimal.dart';

import 'package:telepos/domain/entities/agent/agent_entity.dart';
import 'package:telepos/domain/entities/supply/supply_entity.dart';
import 'package:telepos/domain/entities/supply/supply_product_entity.dart';
import 'package:telepos/domain/snt/snt_models.dart';

class SntProductInfo {
  const SntProductInfo({
    required this.ucode,
    required this.name,
    this.unitCode = 796,
    this.ntin,
    this.gtin,
    this.tnved,
    this.isTraceable = false,
    this.originCountry,
  });

  final int ucode;
  final String name;
  final int unitCode;
  final String? ntin;
  final String? gtin;
  final String? tnved;
  final bool isTraceable;
  final String? originCountry;
}

class SntAssembly {
  const SntAssembly();

  SntDocument fromSupply({
    required SupplyEntity supply,
    required List<SupplyProductEntity> products,
    required AgentEntity supplier,
    required SntParty self,
    required SntProductInfo Function(int ucode) productInfo,
    required String idempotencyKey,
    DateTime? occurredAt,
    bool withTransport = true,
  }) {
    final lines = products
        .map((p) => _line(p.ucode, p.quantity, p.price, productInfo))
        .toList();
    return SntDocument(
      idempotencyKey: idempotencyKey,
      direction: SntDirection.inbound,
      operationType: SntOperationType.supply,
      sender: SntParty(
        bin: supplier.bin ?? '',
        name: supplier.legalName ?? supplier.name,
      ),
      recipient: self,
      lines: lines,
      occurredAt:
          occurredAt ??
          (supply.editTime != null
              ? DateTime.fromMillisecondsSinceEpoch(supply.editTime! * 1000)
              : DateTime.now()),
      localSourceType: 'supply',
      localSourceId: supply.id,
      withTransport: withTransport,
      comment: supply.comment,
    );
  }

  SntDocument fromSupplierReturn({
    required int returnId,
    required List<SntLineInput> lines,
    required AgentEntity supplier,
    required SntParty self,
    required SntProductInfo Function(int ucode) productInfo,
    required String idempotencyKey,
    DateTime? occurredAt,
    bool withTransport = true,
    String? comment,
  }) {
    return SntDocument(
      idempotencyKey: idempotencyKey,
      direction: SntDirection.outbound,
      operationType: SntOperationType.supplierReturn,
      sender: self,
      recipient: SntParty(
        bin: supplier.bin ?? '',
        name: supplier.legalName ?? supplier.name,
      ),
      lines: lines
          .map((l) => _line(l.ucode, l.quantity, l.price, productInfo))
          .toList(),
      occurredAt: occurredAt ?? DateTime.now(),
      localSourceType: 'supplier_return',
      localSourceId: returnId,
      withTransport: withTransport,
      comment: comment,
    );
  }

  SntDocument fromShipment({
    required int shipmentId,
    required List<SntLineInput> lines,
    required SntParty self,
    required SntParty recipient,
    required SntProductInfo Function(int ucode) productInfo,
    required String idempotencyKey,
    SntOperationType operationType = SntOperationType.supply,
    DateTime? occurredAt,
    bool withTransport = true,
    String? comment,
  }) {
    return SntDocument(
      idempotencyKey: idempotencyKey,
      direction: SntDirection.outbound,
      operationType: operationType,
      sender: self,
      recipient: recipient,
      lines: lines
          .map((l) => _line(l.ucode, l.quantity, l.price, productInfo))
          .toList(),
      occurredAt: occurredAt ?? DateTime.now(),
      localSourceType: 'shipment',
      localSourceId: shipmentId,
      withTransport: withTransport,
      comment: comment,
    );
  }

  SntLine _line(
    int ucode,
    Decimal quantity,
    Decimal? price,
    SntProductInfo Function(int) productInfo,
  ) {
    final info = productInfo(ucode);
    final amount = price == null ? null : price * quantity;
    return SntLine(
      productCode: ucode,
      name: info.name,
      quantity: quantity,
      unitCode: info.unitCode,
      price: price,
      amount: amount,
      ntin: info.ntin,
      gtin: info.gtin,
      tnved: info.tnved,
      isTraceable: info.isTraceable,
      originCountry: info.originCountry,
    );
  }
}

class SntLineInput {
  const SntLineInput({required this.ucode, required this.quantity, this.price});

  final int ucode;
  final Decimal quantity;
  final Decimal? price;
}
