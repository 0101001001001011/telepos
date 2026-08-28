import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/supply/supply_entity.dart';
import 'package:telepos/domain/entities/supply/supply_product_entity.dart';

class SupplyMapper {
  SupplyMapper._();

  static SupplyEntity fromDrift(Supply supply) {
    return SupplyEntity(
      id: supply.id,
      operationType: supply.operationType,
      userId: supply.userId,
      supplierId: supply.supplierId,
      editTime: supply.editTime,
      amount: supply.amount,
      paymentType: supply.paymentType,
      accountId: supply.accountId,
      comment: supply.comment,
      payment: supply.payment,
      consignmentAmount: supply.consignmentAmount,
      paidAmount: supply.paidAmount,
      state: supply.state,
      status: supply.status,
      msg: supply.msg,
    );
  }

  static SuppliesCompanion toDrift(SupplyEntity entity) {
    return SuppliesCompanion(
      id: entity.id != null ? Value(entity.id!) : const Value.absent(),
      operationType: Value(entity.operationType),
      userId: Value(entity.userId),
      supplierId: Value(entity.supplierId),
      editTime: Value(entity.editTime),
      amount: Value(entity.amount),
      paymentType: Value(entity.paymentType),
      accountId: Value(entity.accountId),
      comment: Value(entity.comment),
      payment: Value(entity.payment),
      consignmentAmount: Value(entity.consignmentAmount),
      paidAmount: Value(entity.paidAmount),
      state: Value(entity.state),
      status: Value(entity.status),
      msg: Value(entity.msg),
    );
  }

  static List<SupplyEntity> fromDriftList(List<Supply> supplies) {
    return supplies.map(fromDrift).toList();
  }
}

class SupplyProductMapper {
  SupplyProductMapper._();

  static SupplyProductEntity fromDrift(SupplyProduct product) {
    return SupplyProductEntity(
      id: product.id,
      supplyId: product.supplyId,
      ucode: product.ucode,
      quantity: product.quantity,
      price: product.price,
      amount: product.amount,
      serialNumbers: decodeSerialNumbers(product.serialNumbers),
    );
  }

  static SupplyProductsCompanion toDrift(SupplyProductEntity entity) {
    return SupplyProductsCompanion(
      id: entity.id != null ? Value(entity.id!) : const Value.absent(),
      supplyId: Value(entity.supplyId),
      ucode: Value(entity.ucode),
      quantity: Value(entity.quantity),
      price: Value(entity.price),
      amount: Value(entity.amount),
      serialNumbers: Value(encodeSerialNumbers(entity.serialNumbers)),
    );
  }

  static String? encodeSerialNumbers(List<String>? serials) {
    if (serials == null) return null;
    final cleaned = serials
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) return null;
    return jsonEncode(cleaned);
  }

  static List<String>? decodeSerialNumbers(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final list = decoded
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
      return list.isEmpty ? null : list;
    } catch (_) {
      return null;
    }
  }

  static List<SupplyProductEntity> fromDriftList(List<SupplyProduct> products) {
    return products.map(fromDrift).toList();
  }
}
