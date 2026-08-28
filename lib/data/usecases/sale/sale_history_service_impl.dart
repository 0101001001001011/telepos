import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/sale/can_sale_be_refunded_use_case.dart';
import 'package:telepos/domain/usecases/sale/sale_history_service.dart';

class SaleHistoryServiceImpl implements SaleHistoryService {
  SaleHistoryServiceImpl({
    required AppDatabase db,
    required CanSaleBeRefundedUseCase canSaleBeRefundedUseCase,
    required Talker logger,
  }) : _db = db,
       _canSaleBeRefundedUseCase = canSaleBeRefundedUseCase,
       _logger = logger;

  final AppDatabase _db;
  final CanSaleBeRefundedUseCase _canSaleBeRefundedUseCase;
  final Talker _logger;

  @override
  Future<List<HistoricalSale>> getSalesBetweenDates({
    required int posId,
    required int fromTimestamp,
    required int toTimestamp,
    required int page,
  }) async {
    final offset = page * SaleHistoryService.pageSize;
    final paginatedSales =
        await (_db.select(_db.sales)
              ..where(
                (s) =>
                    s.posId.equals(posId) &
                    s.time.isBiggerThanValue(fromTimestamp) &
                    s.time.isSmallerThanValue(toTimestamp) &
                    s.state.equals(3).not(),
              )
              ..orderBy([(s) => OrderingTerm.desc(s.time)])
              ..limit(SaleHistoryService.pageSize, offset: offset))
            .get();

    if (paginatedSales.isEmpty) {
      _logger.info('SaleHistory: no sales in range pos=$posId');
      throw const HasNoSaleInRange();
    }

    final result = <HistoricalSale>[];
    for (final sale in paginatedSales) {
      result.add(await _buildHistoricalSale(sale));
    }
    return result;
  }

  @override
  Future<HistoricalSale> findSale({
    required int receiptNo,
    required int posId,
  }) async {
    final sales =
        await (_db.select(_db.sales)..where(
              (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId),
            ))
            .get();

    if (sales.isEmpty) {
      throw const HasNoSaleInRange('Продажи нет в локальной базе');
    }

    return _buildHistoricalSale(sales.first);
  }

  Future<HistoricalSale> _buildHistoricalSale(Sale sale) async {
    final pos = await (_db.select(
      _db.posEntries,
    )..where((p) => p.id.equals(sale.posId))).getSingleOrNull();

    final user = await _db.userDao.findById(sale.userId);

    final payments = await _db.paymentDao.findBySale(
      sale.receiptNo,
      sale.posId,
    );
    final historicalPayments = <HistoricalPayment>[];
    for (final payment in payments) {
      final account = await _db.accountDao.findById(payment.payeeAccountId);
      historicalPayments.add(
        HistoricalPayment(
          payeeAccountId: payment.payeeAccountId,
          amount: payment.amount,
          accountName: account?.name,
          accountType: account?.type,
        ),
      );
    }

    final withdrawal = await _db.saleDao.findWithdrawalBySale(
      sale.receiptNo,
      sale.posId,
    );

    final hasWebkassa = sale.saleId != null
        ? (await _db.webkassaReceiptDao.findByIsSaleAndOperationId(
                true,
                sale.saleId!,
              )) !=
              null
        : false;

    bool canRefund;
    try {
      canRefund = await _canSaleBeRefundedUseCase.canBeRefunded(
        receiptNo: sale.receiptNo,
        posId: sale.posId,
      );
    } catch (_) {
      canRefund = false;
    }

    return HistoricalSale(
      receiptNo: sale.receiptNo,
      posId: sale.posId,
      saleId: sale.saleId,
      userId: sale.userId,
      amount: sale.amount,
      time: sale.time,
      state: sale.state,
      isOfd: sale.isOfd,
      isWholesale: sale.isWholesale,
      customerBin: sale.customerBin,
      posName: pos?.name,
      userName: user?.name,
      payments: historicalPayments,
      withdrawalAmount: withdrawal?.amount,
      withdrawalAccountId: withdrawal?.agentAccountId,
      hasWebkassaReceipt: hasWebkassa,
      canRefund: canRefund,
    );
  }
}
