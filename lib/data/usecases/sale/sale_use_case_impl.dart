import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/esf/esf_settings_store.dart';
import 'package:telepos/domain/entities/sale/sale_entity.dart';
import 'package:telepos/domain/entities/sale/sale_product_entity.dart';
import 'package:telepos/domain/esf/esf_draft_builder.dart';
import 'package:telepos/domain/esf/esf_models.dart';
import 'package:telepos/domain/esf/esf_provider.dart';
import 'package:telepos/domain/esf/esf_provider_registry.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';
import 'package:telepos/domain/usecases/wms/serial_tracking_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_config_use_case.dart';

class SaleUseCaseImpl implements SaleUseCase {
  SaleUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  static const int _pendingSync = 1;

  static const int _accountTypeCustomBank = 1;

  @override
  Future<void> perform({
    required int receiptNo,
    required int posId,
    required Decimal amount,
    required List<PaymentEntry> payments,
    required Decimal change,
    required bool selectiveOfd,
    String? customerBin,
    int? agentLocalId,
    int? agentServerId,
    List<CustomFieldEntry>? customFields,
    WithdrawalEntry? withdrawal,
  }) async {
    final isOfd = await _isOfd(payments, selectiveOfd);

    final shift = await _db.shiftDao.findOpenedShift();
    final userId = shift?.userId ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    const saleState = _pendingSync;

    await _db.transaction(() async {
      await ((_db.update(_db.sales))..where(
            (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId),
          ))
          .write(
            SalesCompanion(
              state: const Value(saleState),
              change: Value(change),
              time: Value(now),
              isOfd: Value(isOfd),
              customerBin: Value(customerBin),
              customerLocalId: Value(agentLocalId),
              customerServerId: Value(agentServerId),
            ),
          );

      await _db.batch((batch) {
        for (final p in payments) {
          batch.insert(
            _db.payments,
            PaymentsCompanion.insert(
              userId: userId,
              receiptNo: Value(receiptNo),
              posId: Value(posId),
              payeeAccountId: p.payeeAccountId,
              amount: p.amount,
              time: now,
              state: const Value(saleState),
              customerLocalId: Value(p.customerLocalId),
              approvalCode: Value(p.approvalCode),
              cardMask: Value(p.cardMask),
              terminalTransactionId: Value(p.terminalTransactionId),
            ),
          );
        }
      });

      if (customFields != null && customFields.isNotEmpty) {
        await _db.batch((batch) {
          for (final cf in customFields) {
            batch.insert(
              _db.saleCustomFields,
              SaleCustomFieldsCompanion(
                receiptNo: Value(receiptNo),
                posId: Value(posId),
                customFieldId: Value(cf.customFieldId),
                customFieldItemId: Value(cf.customFieldItemId),
              ),
            );
          }
        });
      }

      if (withdrawal != null) {
        await _db
            .into(_db.saleWithdrawals)
            .insert(
              SaleWithdrawalsCompanion(
                receiptNo: Value(receiptNo),
                posId: Value(posId),
                agentAccountId: Value(withdrawal.agentAccountId),
                amount: Value(withdrawal.amount),
              ),
            );
      }

      final saleProducts = await _db.saleProductDao.findBySale(
        receiptNo,
        posId,
      );
      for (final sp in saleProducts) {
        await _db.productInfoDao.adjustQuantity(sp.ucode, -sp.quantity);

        await _depleteWmsStock(sp.ucode, sp.quantity);

        await _consumeSerials(
          ucode: sp.ucode,
          quantity: sp.quantity,
          receiptNo: receiptNo,
          userId: userId,
        );

        await _depleteDishIngredients(sp.ucode, sp.quantity);
      }

      for (final p in payments) {
        final account = await _db.accountDao.findById(p.payeeAccountId);
        if (account != null) {
          final currentBalance = account.value ?? Decimal.zero;
          final isCashbackRedemption =
              account.type == AccountType.agentCashback ||
              account.type == AccountType.cashback;
          final newBalance = isCashbackRedemption
              ? currentBalance - p.amount
              : currentBalance + p.amount;
          await _db.accountDao.updateBalance(p.payeeAccountId, newBalance);
        }
      }

      if (agentLocalId != null) {
        final paymentSum = payments.fold<Decimal>(
          Decimal.zero,
          (sum, p) => sum + p.amount,
        );
        final debitAmount = amount - paymentSum;
        await _updateAgentBalance(agentLocalId, -debitAmount);
      }
    });

    _logger.info(
      'SaleUseCase: sale completed receipt=$receiptNo, '
      'amount=$amount, isOfd=$isOfd, payments=${payments.length}',
    );

    if (isOfd) {
      try {
        final fiscalService = GetIt.I<FiscalService>();

        var cashAmount = Decimal.zero;
        var cardAmount = Decimal.zero;

        for (final p in payments) {
          final account = await _db.accountDao.findById(p.payeeAccountId);
          if (account != null) {
            if (account.type == AccountType.pos) {
              cashAmount += p.amount;
            } else if (account.type == AccountType.customBank) {
              cardAmount += p.amount;
            }
          }
        }

        final result = await fiscalService.fiscalizeSale(
          saleReceiptNo: receiptNo,
          salePosId: posId,
          amount: amount,
          cashAmount: cashAmount,
          cardAmount: cardAmount,
          customerBin: customerBin,
        );

        if (result.success) {
          _logger.info(
            'Fiscalization ${result.queued ? 'queued' : 'ok'}: '
            'sign=${result.fiscalSign}',
          );
        } else {
          _logger.warning('Fiscalization failed: ${result.errorMessage}');
        }
      } catch (e, stackTrace) {
        _logger.warning('Fiscalization error: $e', e, stackTrace);
      }
    }

    await _buildAndEnqueueEsf(
      receiptNo: receiptNo,
      posId: posId,
      amount: amount,
      customerBin: customerBin,
      userId: userId,
      time: now,
      change: change,
      isOfd: isOfd,
    );
  }

  @override
  Future<void> reverseSaleStock({
    required int receiptNo,
    required int posId,
  }) async {
    final saleProducts = await _db.saleProductDao.findBySale(receiptNo, posId);
    for (final sp in saleProducts) {
      if (sp.quantity <= Decimal.zero) continue;
      await _db.productInfoDao.adjustQuantity(sp.ucode, sp.quantity);
    }
  }

  Future<void> _buildAndEnqueueEsf({
    required int receiptNo,
    required int posId,
    required Decimal amount,
    required String? customerBin,
    required int userId,
    required int time,
    required Decimal change,
    required bool isOfd,
  }) async {
    try {
      final bin = customerBin?.trim();
      if (bin == null || bin.isEmpty) return;

      if (!GetIt.I.isRegistered<EsfDraftBuilder>() ||
          !GetIt.I.isRegistered<EsfProviderRegistry>() ||
          !GetIt.I.isRegistered<EsfSettingsStore>()) {
        return;
      }

      final settings = GetIt.I<EsfSettingsStore>().load();
      if (!settings.isEnabled) return;

      final saleRow = await _db.saleDao.findByKey(receiptNo, posId);
      if (saleRow == null) return;
      final saleProducts = await _db.saleProductDao.findBySale(
        receiptNo,
        posId,
      );
      if (saleProducts.isEmpty) return;

      final sale = SaleEntity(
        receiptNo: receiptNo,
        posId: posId,
        userId: userId,
        amount: amount,
        change: change,
        time: time,
        isOfd: isOfd,
        customerBin: bin,
        state: saleRow.state,
      );

      final lines = <EsfLineSpec>[];
      for (final sp in saleProducts) {
        final info = await _db.productInfoDao.findByUcode(sp.ucode);
        final vatRate = info?.vatRate;
        final EsfTaxMode? mode = vatRate == null ? null : EsfTaxMode.vat;
        lines.add(
          EsfLineSpec(
            product: SaleProductEntity(
              ucode: sp.ucode,
              quantity: sp.quantity,
              price: sp.price,
              priceBefore: sp.priceBefore,
            ),
            name: info?.name ?? 'Товар ${sp.ucode}',
            ntin: info?.ntin,
            vatMode: mode,
            vatRatePercent: vatRate != null ? Decimal.fromInt(vatRate) : null,
          ),
        );
      }

      final builder = GetIt.I<EsfDraftBuilder>();
      final guid = 'ESF-$posId-$receiptNo';
      final outcome = builder.buildFromSale(
        sale: sale,
        lines: lines,
        settings: settings,
        idempotencyKey: guid,
        accountingNumber: '$posId-$receiptNo',
      );

      if (!outcome.built) {
        _logger.info(
          'ЭСФ skipped for receipt=$receiptNo: '
          '${outcome.skipReason?.name}',
        );
        return;
      }

      final provider = GetIt.I<EsfProviderRegistry>().resolve(settings);
      final result = await provider.submit(outcome.invoice!);
      _logger.info(
        'ЭСФ draft enqueued for receipt=$receiptNo: '
        'queued=${result.queued} success=${result.success}',
      );
    } catch (e, stackTrace) {
      _logger.warning('ЭСФ post-sale hook error: $e', e, stackTrace);
    }
  }

  Future<void> _depleteWmsStock(int ucode, Decimal quantity) async {
    if (quantity <= Decimal.zero) return;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final pickedBatchIds = <int>{};
    final batches = await _db.batchDao.findActiveByUcode(ucode);
    await _reorderByPickingStrategy(batches);
    if (batches.isNotEmpty) {
      var remaining = quantity;
      for (final b in batches) {
        if (remaining <= Decimal.zero) break;
        final avail = b.currentQuantity;
        if (avail <= Decimal.zero) continue;
        final take = avail < remaining ? avail : remaining;
        await _db.batchDao.adjustQuantity(b.id, -take);
        if (avail - take <= Decimal.zero) {
          await _db.batchDao.updateBatch(
            b.id,
            const BatchesCompanion(isActive: Value(false)),
          );
        }
        pickedBatchIds.add(b.id);
        remaining -= take;
      }
    }

    final cells = await _db.cellStockDao.findByUcode(ucode);
    if (cells.isNotEmpty) {
      cells.sort((a, b) {
        final ap = pickedBatchIds.contains(a.batchId) ? 0 : 1;
        final bp = pickedBatchIds.contains(b.batchId) ? 0 : 1;
        if (ap != bp) return ap.compareTo(bp);
        return a.id.compareTo(b.id);
      });
      var remaining = quantity;
      for (final c in cells) {
        if (remaining <= Decimal.zero) break;
        if (c.quantity <= Decimal.zero) continue;
        final take = c.quantity < remaining ? c.quantity : remaining;
        await _db.cellStockDao.upsertStock(
          CellStocksCompanion(
            id: Value(c.id),
            cellId: Value(c.cellId),
            ucode: Value(c.ucode),
            batchId: c.batchId == null
                ? const Value.absent()
                : Value(c.batchId),
            quantity: Value(c.quantity - take),
            reservedQty: Value(c.reservedQty),
            updatedAt: Value(now),
          ),
        );
        remaining -= take;
      }
    }
  }

  Future<void> _reorderByPickingStrategy(List<Batche> batches) async {
    if (batches.length < 2) return;
    var strategy = 'FEFO';
    try {
      if (GetIt.I.isRegistered<WmsConfigUseCase>()) {
        strategy = await GetIt.I<WmsConfigUseCase>().pickingStrategy();
      }
    } catch (_) {
      return;
    }
    switch (strategy) {
      case 'FIFO':
        batches.sort(
          (a, b) => (a.receivedDate ?? 0).compareTo(b.receivedDate ?? 0),
        );
        break;
      case 'LIFO':
        batches.sort(
          (a, b) => (b.receivedDate ?? 0).compareTo(a.receivedDate ?? 0),
        );
        break;
    }
  }

  Future<void> _consumeSerials({
    required int ucode,
    required Decimal quantity,
    required int receiptNo,
    required int userId,
  }) async {
    if (quantity <= Decimal.zero) return;
    try {
      if (!GetIt.I.isRegistered<WmsConfigUseCase>() ||
          !GetIt.I.isRegistered<SerialTrackingUseCase>()) {
        return;
      }
      final enabled = await GetIt.I<WmsConfigUseCase>().isModuleEnabled(
        'serialTracking',
      );
      if (!enabled) return;

      final toConsume = quantity.truncate().toBigInt().toInt();
      if (toConsume <= 0) return;

      final available = await _db.serialDao.findByStatus(0);
      final mine = available.where((s) => s.ucode == ucode).toList()
        ..sort((a, b) => a.id.compareTo(b.id));

      final serialUc = GetIt.I<SerialTrackingUseCase>();
      final n = toConsume < mine.length ? toConsume : mine.length;
      for (var i = 0; i < n; i++) {
        await serialUc.markAsSold(
          mine[i].id,
          saleId: receiptNo,
          userId: userId,
        );
      }
    } catch (e, st) {
      _logger.warning('Serial consume error (ucode=$ucode): $e', e, st);
    }
  }

  Future<void> _depleteDishIngredients(int ucode, Decimal quantity) async {
    if (quantity <= Decimal.zero) return;

    final ingredients = await _db.dishIngredientDao.findByDish(ucode);
    if (ingredients.isEmpty) return;

    for (final ing in ingredients) {
      final consumed = ing.netQuantity * quantity;
      if (consumed <= Decimal.zero) continue;
      await _db.productInfoDao.adjustQuantity(ing.ingredientUcode, -consumed);
    }
  }

  Future<bool> _isOfd(List<PaymentEntry> payments, bool selectiveOfd) async {
    if (!GetIt.I.isRegistered<FiscalService>()) return false;
    final fiscalEnabled = await GetIt.I<FiscalService>().isEnabled();
    if (!fiscalEnabled) return false;

    final thisPos = await _db.thisPosDao.get();
    final ofdSyncType = thisPos?.ofdSyncType ?? 0;

    switch (ofdSyncType) {
      case 0:
        return true;
      case 1:
        return selectiveOfd;
      case 2:
        if (payments.isEmpty) return false;
        for (final p in payments) {
          final account = await _db.accountDao.findById(p.payeeAccountId);
          if (account == null || account.type != _accountTypeCustomBank) {
            return false;
          }
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _updateAgentBalance(int agentLocalId, Decimal amount) async {
    final agents = await (_db.select(
      _db.agents,
    )..where((a) => a.localId.equals(agentLocalId))).get();

    if (agents.isEmpty) return;
    final agent = agents.first;
    final mainAccountId = agent.mainAccountId;
    if (mainAccountId == null) return;

    final account = await _db.accountDao.findById(mainAccountId);
    if (account == null) return;

    final currentBalance = account.value ?? Decimal.zero;
    final newBalance = currentBalance + amount;

    await ((_db.update(_db.accounts))..where((a) => a.id.equals(mainAccountId)))
        .write(AccountsCompanion(value: Value(newBalance)));
  }
}
