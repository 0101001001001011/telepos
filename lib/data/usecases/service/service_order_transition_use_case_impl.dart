import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/constants/enums/service_order_status.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/sale/receipt_numbers.dart';
import 'package:telepos/domain/entities/service/service_order_entity.dart';
import 'package:telepos/domain/entities/warranty/warranty_record_entity.dart';
import 'package:telepos/domain/repositories/warranty_repository.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/usecases/fiscal/webkassa_service.dart';
import 'package:telepos/domain/usecases/service/link_service_to_sale_use_case.dart';
import 'package:telepos/domain/usecases/service/service_order_transition_use_case.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

class ServiceOrderTransitionUseCaseImpl
    implements ServiceOrderTransitionUseCase {
  ServiceOrderTransitionUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger,
       _receiptNumbers = ReceiptNumbers(db);

  final AppDatabase _db;
  final Talker _logger;
  final ReceiptNumbers _receiptNumbers;

  static const int _pendingSync = 1;

  @override
  Future<ServiceOrderEntity> progress(int orderId) async {
    try {
      final row = await _db.serviceOrderDao.findById(orderId);
      if (row == null) {
        throw StateError('Service order not found: $orderId');
      }

      final currentStatus = ServiceOrderStatus.values[row.status];
      final entity = _mapToEntity(row);

      if (!entity.canProgress) {
        throw StateError(
          'Cannot progress order $orderId from status $currentStatus',
        );
      }

      final nextStatus = entity.nextStatus!;

      ServiceOrderEntity result = entity;
      if (nextStatus == ServiceOrderStatus.closed) {
        final hasPending = await _db.serviceMarkDao.hasPendingApprovals(
          orderId,
        );
        if (hasPending) {
          throw StateError(
            'Cannot close order $orderId: pending approvals must be '
            'approved or rejected before closing',
          );
        }
        result = await _collectClosingPayment(row, entity);
      }

      await _db.serviceOrderDao.updateStatus(orderId, nextStatus.index);

      if (nextStatus == ServiceOrderStatus.closed) {
        await _createWarrantyIfNeeded(row, result);
      }

      _logger.info(
        'Service order $orderId transitioned: '
        '$currentStatus → $nextStatus',
      );

      return result.copyWith(status: nextStatus);
    } catch (e) {
      _logger.error('Failed to progress service order $orderId: $e');
      rethrow;
    }
  }

  @override
  Future<ServiceOrderEntity> cancel(int orderId) async {
    try {
      final row = await _db.serviceOrderDao.findById(orderId);
      if (row == null) {
        throw StateError('Service order not found: $orderId');
      }

      final currentStatus = ServiceOrderStatus.values[row.status];
      if (currentStatus == ServiceOrderStatus.closed) {
        throw StateError('Cannot cancel order $orderId: already closed');
      }

      if (currentStatus == ServiceOrderStatus.cancelled) {
        throw StateError('Cannot cancel order $orderId: already cancelled');
      }

      await _db.serviceOrderDao.updateStatus(
        orderId,
        ServiceOrderStatus.cancelled.index,
      );

      try {
        final marks = await _db.serviceMarkDao.getByOrder(orderId);
        for (final m in marks) {
          if (m.approvalStatus == 2) continue;
          await _db.serviceMarkDao.restoreStockFor(m);
        }
      } catch (e) {
        _logger.warning(
          'Service cancel $orderId: failed to restore consumable stock: $e',
        );
      }

      final prepaid = row.prepaymentAmount ?? Decimal.zero;
      if (prepaid > Decimal.zero) {
        await _reversePrepayment(
          orderId: orderId,
          orderNumber: row.orderNumber,
          amount: prepaid,
        );
      }

      _logger.info(
        'Service order $orderId cancelled (was: $currentStatus), '
        'prepayment reversed: $prepaid',
      );

      return _mapToEntity(row).copyWith(status: ServiceOrderStatus.cancelled);
    } catch (e) {
      _logger.error('Failed to cancel service order $orderId: $e');
      rethrow;
    }
  }

  Future<ServiceOrderEntity> _collectClosingPayment(
    ServiceOrder row,
    ServiceOrderEntity entity,
  ) async {
    final marksTotal = await _db.serviceMarkDao.sumCostByOrder(row.id);
    final totalCost = row.finalAmount ?? marksTotal;
    final prepaid = row.prepaymentAmount ?? Decimal.zero;
    final remaining = totalCost - prepaid;

    final thisPos = await _db.thisPosDao.get();
    if (thisPos == null) {
      _logger.warning(
        'Service close ${row.id}: ThisPos not configured — '
        'recording finalAmount only, no payment booked',
      );
      await _db.serviceOrderDao.updateOrder(
        row.copyWith(finalAmount: Value(totalCost)),
      );
      return entity.copyWith(finalAmount: totalCost);
    }

    final posId = thisPos.id;

    final int? accountId = await _resolveCashAccountId(thisPos.accountId);

    if (remaining <= Decimal.zero || posId == null || accountId == null) {
      if (remaining > Decimal.zero && (posId == null || accountId == null)) {
        _logger.warning(
          'Service close ${row.id}: missing posId/account — '
          'finalAmount recorded but remaining $remaining not booked',
        );
      }
      await _db.serviceOrderDao.updateOrder(
        row.copyWith(finalAmount: Value(totalCost)),
      );
      return entity.copyWith(finalAmount: totalCost);
    }

    final int salePosId = posId;
    final int cashAccountId = accountId;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final shift = await _db.shiftDao.findOpenedShift();
    final userId = shift?.userId ?? row.userId;

    // Номер закрепляется атомарно вместе с полной строкой продажи и всем,
    // что от неё зависит (платёж, баланс счёта, заказ услуги) — тот же
    // класс, что и `sale_initiation_use_case_impl.dart`/
    // `create_table_order_use_case_impl.dart` (задача 4, круг правки 1):
    // `findLastReceiptNo() ?? 0) + 1` здесь на месте делил один и тот же
    // счётчик с продажей и с созданием заказа стола без всякой защиты от
    // гонки между ними. `_db.transaction()`, которым раньше был обёрнут
    // только этот блок, больше не нужен отдельно — `withNext` уже
    // транзакция, внутри которой всё это и происходит.
    final receiptNo = await _receiptNumbers.withNext(salePosId, (
      candidateReceiptNo,
    ) async {
      await _db
          .into(_db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: candidateReceiptNo,
              posId: salePosId,
              userId: userId,
              amount: remaining,
              time: now,
              storeId: Value(thisPos.storeId),
              state: const Value(_pendingSync),
              isOfd: const Value(false),
              customerLocalId: Value(row.clientAgentId),
              // Владелец имеет только чек в работе (state = 0) — этот
              // чек рождается сразу в «ожидает отправки» (закрытие заказа
              // услуги, оплата уже проведена), минуя корзину вовсе.
              // Явный `null`, а не умолчание колонки: колонка сегодня и
              // так осталась бы пустой без этой строки, но правило
              // требует решения на каждую запись `state`, а не молчаливого
              // совпадения с умолчанием.
              terminalId: const Value(null),
            ),
          );

      await _db
          .into(_db.payments)
          .insert(
            PaymentsCompanion.insert(
              userId: userId,
              receiptNo: Value(candidateReceiptNo),
              posId: Value(salePosId),
              payeeAccountId: cashAccountId,
              amount: remaining,
              time: now,
              state: const Value(_pendingSync),
              customerLocalId: Value(row.clientAgentId),
            ),
          );

      final account = await _db.accountDao.findById(cashAccountId);
      if (account != null) {
        final newBalance = (account.value ?? Decimal.zero) + remaining;
        await _db.accountDao.updateBalance(cashAccountId, newBalance);
      }

      await _db.serviceOrderDao.updateOrder(
        row.copyWith(finalAmount: Value(totalCost)),
      );

      return candidateReceiptNo;
    });

    try {
      final linkUseCase = GetIt.I<LinkServiceToSaleUseCase>();
      await linkUseCase.link(row.id, receiptNo, salePosId);
    } catch (e) {
      _logger.warning('Service close ${row.id}: failed to link to sale: $e');
    }

    _logger.info(
      'Service order ${row.id} closed with payment: '
      'receipt=$receiptNo, total=$totalCost, prepaid=$prepaid, '
      'collected=$remaining, account=$cashAccountId',
    );

    final fiscalItems = await _buildFiscalItems(row, remaining);
    final vatTotal = _vatTotal(fiscalItems);
    _logger.info(
      'Service close ${row.id}: receipt=$receiptNo total=$remaining '
      'НДС=$vatTotal (${fiscalItems.length} позиций)',
    );

    await _fiscalizeIfNeeded(
      receiptNo: receiptNo,
      amount: remaining,
      items: fiscalItems.map((i) => i.data).toList(),
      customerBin: null,
    );

    return entity.copyWith(
      finalAmount: totalCost,
      receiptNo: receiptNo,
      posId: salePosId,
    );
  }

  Future<void> _reversePrepayment({
    required int orderId,
    required String orderNumber,
    required Decimal amount,
  }) async {
    try {
      final accountId = await _resolveCashAccountId(
        (await _db.thisPosDao.get())?.accountId,
      );
      if (accountId == null) {
        _logger.warning(
          'Service cancel $orderNumber: no POS account — '
          'prepayment $amount not reversed',
        );
        return;
      }

      final cashController = GetIt.I<CashInOutController>();
      final result = await cashController.createExpense(
        amount: amount,
        accountId: accountId,
        expenseType: ExpenseType.other,
        note: 'Возврат предоплаты по заказ-наряду $orderNumber (отмена)',
      );

      if (result.success) {
        _logger.info(
          'Service cancel $orderNumber: prepayment reversed as cash-out: '
          'amount=$amount, account=$accountId, op=${result.operationId}',
        );
      } else {
        _logger.warning(
          'Service cancel $orderNumber: prepayment $amount not reversed: '
          '${result.refusal?.name ?? result.errorDetail}',
        );
      }
    } catch (e) {
      _logger.error(
        'Failed to reverse prepayment for order $orderId ($orderNumber): $e',
      );
    }
  }

  Future<void> _createWarrantyIfNeeded(
    ServiceOrder row,
    ServiceOrderEntity result,
  ) async {
    final days = row.warrantyDays ?? 0;
    if (days <= 0) return;

    try {
      if (!GetIt.I.isRegistered<WarrantyRepository>()) {
        _logger.warning(
          'Service close ${row.id}: WarrantyRepository not registered — '
          'warranty ($days days) not recorded',
        );
        return;
      }
      final repo = GetIt.I<WarrantyRepository>();

      final start = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final end = start + days * 86400;
      final months = days ~/ 30;

      final id = await repo.create(
        WarrantyRecordEntity(
          ucode: 0,
          warrantyStart: start,
          warrantyEnd: end,
          warrantyMonths: months > 0 ? months : null,
          saleId: result.receiptNo,
          customerId: row.clientAgentId,
          notes:
              'service-order:${row.orderNumber} (id=${row.id}); '
              'гарантия $days дн.',
          createdAt: start,
          updatedAt: start,
        ),
      );

      _logger.info(
        'Service order ${row.id} warranty created: id=$id, '
        'days=$days, start=$start, end=$end, sale=${result.receiptNo}',
      );
    } catch (e, st) {
      _logger.warning(
        'Service close ${row.id}: failed to create warranty: $e',
        e,
        st,
      );
    }
  }

  Future<int?> _resolveCashAccountId(int? configuredAccountId) async {
    if (configuredAccountId != null) return configuredAccountId;
    final posAccounts = await _db.accountDao.findByType(AccountType.pos);
    return posAccounts.isNotEmpty ? posAccounts.first.id : null;
  }

  Future<void> _fiscalizeIfNeeded({
    required int receiptNo,
    required Decimal amount,
    List<FiscalItemData>? items,
    String? customerBin,
  }) async {
    try {
      if (!GetIt.I.isRegistered<FiscalService>()) return;
      if (!await GetIt.I<FiscalService>().isEnabled()) return;
      final thisPos = await _db.thisPosDao.get();
      final ofdSyncType = thisPos?.ofdSyncType ?? 0;
      if (ofdSyncType != 0) return;

      final webKassaService = GetIt.I<WebKassaService>();
      final result = await webKassaService.fiscalizeSale(
        saleId: receiptNo,
        amount: amount,
        cashAmount: amount,
        cardAmount: Decimal.zero,
        items: items,
        customerBin: customerBin,
      );

      if (result.success) {
        _logger.info(
          'Service fiscalization succeeded: fiscalNo=${result.fiscalNo}',
        );
      } else {
        _logger.warning('Service fiscalization failed: ${result.errorMessage}');
      }
    } catch (e, stackTrace) {
      _logger.warning('Service fiscalization error: $e', e, stackTrace);
    }
  }

  Future<List<_ServiceFiscalLine>> _buildFiscalItems(
    ServiceOrder row,
    Decimal collected,
  ) async {
    final marks = await _db.serviceMarkDao.getByOrder(row.id);
    final priced = marks
        .where(
          (m) =>
              (m.approvalStatus == null || m.approvalStatus == 1) &&
              (m.cost ?? Decimal.zero) > Decimal.zero,
        )
        .toList();

    if (priced.isEmpty || collected <= Decimal.zero) {
      return [
        _buildLine(
          name: 'Услуги по заказ-наряду ${row.orderNumber}',
          gross: collected,
          vatRatePercent: FiscalDefaults.vatRatePercent.toBigInt().toInt(),
        ),
      ];
    }

    final marksTotal = priced.fold<Decimal>(
      Decimal.zero,
      (s, m) => s + (m.cost ?? Decimal.zero),
    );

    final lines = <_ServiceFiscalLine>[];
    for (final m in priced) {
      final cost = m.cost ?? Decimal.zero;
      final gross = marksTotal == collected
          ? cost
          : (cost * collected / marksTotal).toDecimal(
              scaleOnInfinitePrecision: 2,
            );
      lines.add(
        _buildLine(
          name: m.description,
          gross: gross,
          vatRatePercent: await _vatRateForMark(m),
        ),
      );
    }

    final sum = lines.fold<Decimal>(Decimal.zero, (s, l) => s + l.data.amount);
    final drift = collected - sum;
    if (drift != Decimal.zero && lines.isNotEmpty) {
      final last = lines.removeLast();
      lines.add(
        _buildLine(
          name: last.data.name,
          gross: last.data.amount + drift,
          vatRatePercent: last.vatRatePercent,
        ),
      );
    }

    return lines;
  }

  Future<int> _vatRateForMark(ServiceMark mark) async {
    final ucode = mark.productUcode;
    if (ucode != null) {
      final product = await _db.productInfoDao.findByUcode(ucode);
      final rate = product?.vatRate;
      if (rate != null) return rate;
    }
    // Умолчание — из фискальных настроек, одно на продукт. Здесь
    // стояла четвёртая копия того же числа (`VatCalculator`).
    return FiscalDefaults.vatRatePercent.toBigInt().toInt();
  }

  _ServiceFiscalLine _buildLine({
    required String name,
    required Decimal gross,
    required int vatRatePercent,
  }) {
    final vat = vatRatePercent <= 0
        ? Decimal.zero
        : ((gross * Decimal.fromInt(vatRatePercent)) /
                  Decimal.fromInt(100 + vatRatePercent))
              .toDecimal(scaleOnInfinitePrecision: 3);
    return _ServiceFiscalLine(
      vatRatePercent: vatRatePercent,
      vatAmount: vat,
      data: FiscalItemData(
        name: name,
        quantity: Decimal.one,
        price: gross,
        amount: gross,
      ),
    );
  }

  Decimal _vatTotal(List<_ServiceFiscalLine> lines) =>
      lines.fold(Decimal.zero, (s, l) => s + l.vatAmount);

  ServiceOrderEntity _mapToEntity(ServiceOrder row) {
    return ServiceOrderEntity(
      id: row.id,
      orderNumber: row.orderNumber,
      receiptNo: row.receiptNo,
      posId: row.posId,
      status: ServiceOrderStatus.values[row.status],
      userId: row.userId,
      assigneeId: row.assigneeId,
      clientAgentId: row.clientAgentId,
      clientName: row.clientName,
      clientPhone: row.clientPhone,
      clientNote: row.clientNote,
      deviceDescription: row.deviceDescription,
      serialNumber: row.serialNumber,
      complaint: row.complaint,
      intakeTime: row.intakeTime,
      estimatedCompletionTime: row.estimatedCompletionTime,
      estimatedAmount: row.estimatedAmount,
      prepaymentAmount: row.prepaymentAmount,
      finalAmount: row.finalAmount,
    );
  }
}

class _ServiceFiscalLine {
  const _ServiceFiscalLine({
    required this.vatRatePercent,
    required this.vatAmount,
    required this.data,
  });

  final int vatRatePercent;
  final Decimal vatAmount;
  final FiscalItemData data;
}
