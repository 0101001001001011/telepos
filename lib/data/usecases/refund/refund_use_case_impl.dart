import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import 'package:telepos/domain/usecases/refund/refund_use_case.dart';

class RefundUseCaseImpl implements RefundUseCase {
  RefundUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  static const int _statePendingSync = 1;

  @override
  Future<RefundResult> perform({
    required int refundLocalId,
    required Decimal amount,
    Decimal? cashbackAmount,
    required int userId,
    int? saleReceiptNo,
    int? salePosId,
    int? customerLocalId,
    int? customerServerId,
    required List<RefundProductEntry> products,
  }) async {
    _validateRefund(amount, products, saleReceiptNo, salePosId);

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    Sale? sale;
    int? saleId;
    bool isOfd = false;

    if (saleReceiptNo != null && salePosId != null) {
      final sales =
          await (_db.select(_db.sales)..where(
                (s) =>
                    s.receiptNo.equals(saleReceiptNo) &
                    s.posId.equals(salePosId),
              ))
              .get();
      if (sales.isNotEmpty) {
        sale = sales.first;
        saleId = sale.saleId;
        isOfd = sale.isOfd;
      }
    }

    final result = await _db.transaction(() async {
      await (_db.update(
        _db.refunds,
      )..where((r) => r.localId.equals(refundLocalId))).write(
        RefundsCompanion(
          amount: Value(amount),
          cashbackAmount: Value(cashbackAmount),
          time: Value(now),
          state: const Value(_statePendingSync),
          saleId: Value(saleId),
          saleReceiptNo: Value(saleReceiptNo),
          salePosId: Value(salePosId),
          customerLocalId: Value(customerLocalId),
          customerServerId: Value(customerServerId),
          isOfd: Value(isOfd),
        ),
      );

      final refundProductService = GetIt.I<RefundProductService>();
      for (final product in products) {
        await refundProductService.add(
          refundLocalId: refundLocalId,
          ucode: product.ucode,
          quantity: product.quantity,
          price: product.price,
          inSalePrice: product.inSalePrice,
          inSaleQuantity: product.inSaleQuantity,
          inSalePriceBefore: product.inSalePriceBefore,
        );
      }

      for (final product in products) {
        await _db.productInfoDao.adjustQuantity(
          product.ucode,
          product.quantity,
        );
      }

      int paymentCount = 0;
      if (sale != null) {
        paymentCount = await _createReversalPayments(
          refundLocalId: refundLocalId,
          sale: sale,
          refundAmount: amount,
          userId: userId,
          now: now,
        );
      } else {
        paymentCount = await _createSingleRefundPayment(
          refundLocalId: refundLocalId,
          amount: amount,
          userId: userId,
          now: now,
        );
      }

      if (customerLocalId != null) {
        await _updateAgentBalance(customerLocalId, amount);
      }

      _logger.info(
        'RefundUseCase: completed refund=$refundLocalId, '
        'amount=$amount, products=${products.length}, payments=$paymentCount',
      );

      return RefundResult(
        refundLocalId: refundLocalId,
        amount: amount,
        productCount: products.length,
        paymentCount: paymentCount,
      );
    });

    if (isOfd) {
      try {
        final fiscalService = GetIt.I<FiscalService>();
        final fiscalResult = await fiscalService.fiscalizeRefund(
          refundLocalId: refundLocalId,
          originalSaleReceiptNo: saleReceiptNo,
          amount: amount,
        );

        if (fiscalResult.success) {
          _logger.info(
            'RefundUseCase: fiscalization '
            '${fiscalResult.queued ? 'queued' : 'ok'}, '
            'sign=${fiscalResult.fiscalSign}',
          );
        } else {
          _logger.warning(
            'RefundUseCase: fiscalization failed: ${fiscalResult.errorMessage}',
          );
        }
      } catch (e, stackTrace) {
        _logger.warning(
          'RefundUseCase: fiscalization error: $e',
          e,
          stackTrace,
        );
      }
    }

    return result;
  }

  void _validateRefund(
    Decimal amount,
    List<RefundProductEntry> products,
    int? saleReceiptNo,
    int? salePosId,
  ) {
    final isRefundByReceipt = saleReceiptNo != null && salePosId != null;

    final isTotalDiscountSale =
        isRefundByReceipt &&
        products.every((p) => p.inSalePrice == Decimal.zero);

    if (amount <= Decimal.zero &&
        (!isRefundByReceipt || !isTotalDiscountSale)) {
      throw const InvalidRefundException(
        'Сумма возврата не может быть нулевой',
      );
    }

    final hasZeroPriceWithoutSale = products.any(
      (p) => p.inSalePrice == null && p.price == Decimal.zero,
    );
    if (hasZeroPriceWithoutSale) {
      throw const InvalidRefundException(
        'Продукт с нулевой ценой нельзя вернуть',
      );
    }
  }

  Future<int> _createReversalPayments({
    required int refundLocalId,
    required Sale sale,
    required Decimal refundAmount,
    required int userId,
    required int now,
  }) async {
    final salePayments = await _db.paymentDao.findBySale(
      sale.receiptNo,
      sale.posId,
    );

    if (salePayments.isEmpty) {
      return _createSingleRefundPayment(
        refundLocalId: refundLocalId,
        amount: refundAmount,
        userId: userId,
        now: now,
      );
    }

    final saleTotalPayments = salePayments.fold<Decimal>(
      Decimal.zero,
      (sum, p) => sum + p.amount,
    );

    var remainingAmount = refundAmount;
    var count = 0;

    for (var i = 0; i < salePayments.length; i++) {
      final payment = salePayments[i];
      final isLast = i == salePayments.length - 1;

      Decimal reversalAmount;
      if (isLast) {
        reversalAmount = remainingAmount;
      } else if (saleTotalPayments > Decimal.zero) {
        final ratio = (payment.amount / saleTotalPayments).toDecimal(
          scaleOnInfinitePrecision: 10,
        );
        final rawAmount = refundAmount * ratio;
        reversalAmount = rawAmount.truncate(scale: 3);
        if (reversalAmount > remainingAmount) {
          reversalAmount = remainingAmount;
        }
      } else {
        reversalAmount = Decimal.zero;
      }

      if (reversalAmount > Decimal.zero) {
        await _db
            .into(_db.payments)
            .insert(
              PaymentsCompanion.insert(
                userId: userId,
                payeeAccountId: payment.payeeAccountId,
                amount: -reversalAmount,
                time: now,
                refundLocalId: Value(refundLocalId),
                state: const Value(_statePendingSync),
              ),
            );

        final account = await _db.accountDao.findById(payment.payeeAccountId);
        if (account != null) {
          final newBalance = (account.value ?? Decimal.zero) - reversalAmount;
          await _db.accountDao.updateBalance(
            payment.payeeAccountId,
            newBalance,
          );
        }

        remainingAmount -= reversalAmount;
        count++;
      }
    }

    return count;
  }

  Future<int> _createSingleRefundPayment({
    required int refundLocalId,
    required Decimal amount,
    required int userId,
    required int now,
  }) async {
    final thisPos = await _db.thisPosDao.get();
    final accountId = thisPos?.accountId;

    if (accountId == null) {
      _logger.warning('RefundUseCase: no pos account for refund payment');
      return 0;
    }

    await _db
        .into(_db.payments)
        .insert(
          PaymentsCompanion.insert(
            userId: userId,
            payeeAccountId: accountId,
            amount: -amount,
            time: now,
            refundLocalId: Value(refundLocalId),
            state: const Value(_statePendingSync),
          ),
        );

    final account = await _db.accountDao.findById(accountId);
    if (account != null) {
      final newBalance = (account.value ?? Decimal.zero) - amount;
      await _db.accountDao.updateBalance(accountId, newBalance);
    }

    return 1;
  }

  Future<void> _updateAgentBalance(int customerLocalId, Decimal amount) async {
    final agents = await (_db.select(
      _db.agents,
    )..where((a) => a.localId.equals(customerLocalId))).get();
    if (agents.isEmpty) {
      return;
    }
    final agent = agents.first;
    final mainAccountId = agent.mainAccountId;
    if (mainAccountId == null) {
      return;
    }

    final account = await _db.accountDao.findById(mainAccountId);
    if (account == null) {
      return;
    }

    final newBalance = (account.value ?? Decimal.zero) - amount;
    await (_db.update(_db.accounts)..where((a) => a.id.equals(mainAccountId)))
        .write(AccountsCompanion(value: Value(newBalance)));

    _logger.info(
      'RefundUseCase: updated agent $customerLocalId balance → $newBalance',
    );
  }
}
