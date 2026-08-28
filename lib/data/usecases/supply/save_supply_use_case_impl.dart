import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/supply_mapper.dart';
import 'package:telepos/data/snt/snt_service.dart';
import 'package:telepos/data/snt/snt_settings_store.dart';
import 'package:telepos/domain/entities/agent/agent_entity.dart';
import 'package:telepos/domain/entities/supply/supply_entity.dart';
import 'package:telepos/domain/entities/supply/supply_product_entity.dart';
import 'package:telepos/domain/snt/snt_assembly.dart';
import 'package:telepos/domain/snt/snt_models.dart';
import 'package:telepos/domain/usecases/supply/create_supply_use_case.dart';
import 'package:telepos/domain/usecases/supply/get_supplies_history_use_case.dart';
import 'package:telepos/domain/usecases/supply/save_supply_use_case.dart';
import 'package:telepos/domain/usecases/wms/batch_tracking_use_case.dart';
import 'package:telepos/domain/usecases/wms/cell_stock_use_case.dart';
import 'package:telepos/domain/usecases/wms/serial_tracking_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_config_use_case.dart';

class SaveSupplyUseCaseImpl implements SaveSupplyUseCase {
  SaveSupplyUseCaseImpl(this._db);

  final AppDatabase _db;

  @override
  Future<SaveSupplyResult> execute(int supplyId) async {
    try {
      final supply = await _db.supplyDao.findById(supplyId);
      if (supply == null) {
        return SaveSupplyResult.failed('Приёмка не найдена');
      }

      if (supply.supplierId == null) {
        return SaveSupplyResult.failed('Не указан поставщик');
      }

      final productCount = await _db.supplyProductDao.countBySupplyId(supplyId);
      if (productCount == 0) {
        return SaveSupplyResult.failed('Добавьте минимум один товар');
      }

      final paymentType = SupplyPaymentTypeExtension.fromIndex(
        supply.paymentType,
      );
      if (paymentType == SupplyPaymentType.fullSupply &&
          supply.accountId == null) {
        return SaveSupplyResult.failed(
          'Для полной оплаты необходимо указать счёт',
        );
      }

      final totalAmount = await _calculateTotalAmount(supplyId);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      Decimal payment;
      Decimal consignmentAmount;

      if (paymentType == SupplyPaymentType.fullSupply) {
        payment = totalAmount;
        consignmentAmount = Decimal.zero;
      } else {
        payment = Decimal.zero;
        consignmentAmount = totalAmount;
      }

      await _db.supplyDao.updateSupply(
        supplyId,
        SuppliesCompanion(
          amount: Value(totalAmount),
          payment: Value(payment),
          consignmentAmount: Value(consignmentAmount),
          paidAmount: Value(payment),
          editTime: Value(now),
          state: const Value(1),
        ),
      );

      final products = await _db.supplyProductDao.findBySupplyId(supplyId);
      for (final p in products) {
        await _db.productInfoDao.adjustQuantity(p.ucode, p.quantity);

        await _receiveIntoWms(
          ucode: p.ucode,
          quantity: p.quantity,
          unitCost: p.price,
          supplierId: supply.supplierId,
          expiryDate: null,
          batchNumber: 'SUP-$supplyId-${p.ucode}',
          serialNumbers: SupplyProductMapper.decodeSerialNumbers(
            p.serialNumbers,
          ),
        );
      }

      if (payment > Decimal.zero && supply.accountId != null) {
        final account = await _db.accountDao.findById(supply.accountId!);
        if (account != null) {
          final currentBalance = account.value ?? Decimal.zero;
          await _db.accountDao.updateBalance(
            supply.accountId!,
            currentBalance - payment,
          );
        }
      }

      final ledgerDelta = totalAmount - payment;
      if (ledgerDelta != Decimal.zero || payment > Decimal.zero) {
        await _db.agentDao.postLedgerAdjustment(
          supply.supplierId!,
          ledgerDelta,
        );
      }

      await _assembleSntFromSupply(supplyId);

      return SaveSupplyResult.saved(
        supplyId: supplyId,
        totalAmount: totalAmount,
        productCount: productCount,
      );
    } catch (e) {
      return SaveSupplyResult.failed('Ошибка сохранения приёмки: $e');
    }
  }

  @override
  Future<void> updateSupply({
    required int supplyId,
    int? supplierId,
    SupplyPaymentType? paymentType,
    int? accountId,
    String? comment,
  }) async {
    final companion = SuppliesCompanion(
      supplierId: supplierId != null ? Value(supplierId) : const Value.absent(),
      paymentType: paymentType != null
          ? Value(paymentType.index)
          : const Value.absent(),
      accountId: accountId != null ? Value(accountId) : const Value.absent(),
      comment: comment != null ? Value(comment) : const Value.absent(),
    );

    await _db.supplyDao.updateSupply(supplyId, companion);
  }

  Future<void> _receiveIntoWms({
    required int ucode,
    required Decimal quantity,
    required Decimal unitCost,
    int? supplierId,
    int? expiryDate,
    required String batchNumber,
    List<String>? serialNumbers,
  }) async {
    if (!GetIt.I.isRegistered<WmsConfigUseCase>()) return;
    final wmsConfig = GetIt.I<WmsConfigUseCase>();

    final batchEnabled = await wmsConfig.isModuleEnabled('batchTracking');
    final cellEnabled = await wmsConfig.isModuleEnabled('cellStorage');
    final serialEnabled = await wmsConfig.isModuleEnabled('serialTracking');
    if (!batchEnabled && !cellEnabled && !serialEnabled) return;

    int? batchId;

    if (batchEnabled && GetIt.I.isRegistered<BatchTrackingUseCase>()) {
      final batchUc = GetIt.I<BatchTrackingUseCase>();
      final res = await batchUc.createBatch(
        ucode: ucode,
        batchNumber: batchNumber,
        expiryDate: expiryDate,
        supplierId: supplierId,
        quantity: quantity,
        unitCost: unitCost,
      );
      if (res.success) batchId = res.id;
    }

    if (cellEnabled && GetIt.I.isRegistered<CellStockUseCase>()) {
      final cellId = await _defaultCellId();
      if (cellId != null) {
        final cellUc = GetIt.I<CellStockUseCase>();
        await cellUc.placeStock(
          cellId: cellId,
          ucode: ucode,
          quantity: quantity,
          batchId: batchId,
        );
      }
    }

    if (serialEnabled &&
        serialNumbers != null &&
        serialNumbers.isNotEmpty &&
        GetIt.I.isRegistered<SerialTrackingUseCase>()) {
      final serialUc = GetIt.I<SerialTrackingUseCase>();
      for (final sn in serialNumbers) {
        final trimmed = sn.trim();
        if (trimmed.isEmpty) continue;
        await serialUc.registerSerial(
          ucode: ucode,
          serialNumber: trimmed,
          batchId: batchId,
          supplierId: supplierId,
          purchasePrice: unitCost,
        );
      }
    }
  }

  Future<int?> _defaultCellId() async {
    final cells = await _db.select(_db.warehouseCells).get();
    if (cells.isEmpty) return null;
    for (final c in cells) {
      if (c.isActive && !c.isBlocked) return c.id;
    }
    return cells.first.id;
  }

  Future<Decimal> _calculateTotalAmount(int supplyId) async {
    final products = await _db.supplyProductDao.findBySupplyId(supplyId);
    return products.fold<Decimal>(Decimal.zero, (sum, p) => sum + (p.amount));
  }

  Future<void> _assembleSntFromSupply(int supplyId) async {
    try {
      if (!GetIt.I.isRegistered<SntService>() ||
          !GetIt.I.isRegistered<SntAssembly>() ||
          !GetIt.I.isRegistered<SntSettingsStore>()) {
        return;
      }

      final settings = GetIt.I<SntSettingsStore>().load();
      final ownBin = settings.ownBin;
      if (ownBin == null || ownBin.isEmpty) return;

      final supplyRow = await _db.supplyDao.findById(supplyId);
      if (supplyRow == null || supplyRow.supplierId == null) return;

      final supplierRow = await _db.agentDao.findById(supplyRow.supplierId!);
      if (supplierRow == null) return;

      final productRows = await _db.supplyProductDao.findBySupplyId(supplyId);
      if (productRows.isEmpty) return;

      final infoByUcode = <int, ProductInfo?>{};
      var hasTraceable = false;
      for (final p in productRows) {
        final info = await _db.productInfoDao.findByUcode(p.ucode);
        infoByUcode[p.ucode] = info;
        if (info?.isMarkable == true) hasTraceable = true;
      }
      if (!hasTraceable) return;

      final supply = SupplyEntity(
        id: supplyRow.id,
        supplierId: supplyRow.supplierId,
        editTime: supplyRow.editTime,
        amount: supplyRow.amount,
        comment: supplyRow.comment,
      );
      final products = productRows
          .map(
            (p) => SupplyProductEntity(
              supplyId: p.supplyId,
              ucode: p.ucode,
              quantity: p.quantity,
              price: p.price,
              amount: p.amount,
            ),
          )
          .toList();
      final supplier = AgentEntity(
        localId: supplierRow.localId,
        name: supplierRow.name,
        bin: supplierRow.bin,
        legalName: supplierRow.legalName,
      );

      final assembly = GetIt.I<SntAssembly>();
      final doc = assembly.fromSupply(
        supply: supply,
        products: products,
        supplier: supplier,
        self: SntParty(
          bin: ownBin,
          name: settings.ownWarehouseCode,
          warehouseCode: settings.ownWarehouseCode,
        ),
        productInfo: (ucode) {
          final info = infoByUcode[ucode];
          return SntProductInfo(
            ucode: ucode,
            name: info?.name ?? 'Товар $ucode',
            ntin: info?.ntin,
            isTraceable: info?.isMarkable ?? false,
            originCountry: info?.countryOfOrigin,
          );
        },
        idempotencyKey: 'SNT-SUP-$supplyId',
      );

      await GetIt.I<SntService>().register(doc);
    } catch (_) {}
  }
}
