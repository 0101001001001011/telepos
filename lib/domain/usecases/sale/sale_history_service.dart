import 'package:decimal/decimal.dart';

abstract class SaleHistoryService {
  Future<List<HistoricalSale>> getSalesBetweenDates({
    required int posId,
    required int fromTimestamp,
    required int toTimestamp,
    required int page,
  });

  Future<HistoricalSale> findSale({required int receiptNo, required int posId});

  static const int pageSize = 23;
}

class HistoricalSale {
  const HistoricalSale({
    required this.receiptNo,
    required this.posId,
    required this.userId,
    required this.amount,
    required this.time,
    required this.state,
    this.saleId,
    this.isOfd = false,
    this.isWholesale = false,
    this.customerBin,
    this.posName,
    this.userName,
    this.payments = const [],
    this.withdrawalAmount,
    this.withdrawalAccountId,
    this.hasWebkassaReceipt = false,
    this.canRefund = false,
  });

  final int receiptNo;
  final int posId;
  final int? saleId;
  final int userId;
  final Decimal amount;
  final int time;
  final int? state;
  final bool isOfd;
  final bool isWholesale;
  final String? customerBin;

  final String? posName;
  final String? userName;
  final List<HistoricalPayment> payments;
  final Decimal? withdrawalAmount;
  final int? withdrawalAccountId;
  final bool hasWebkassaReceipt;
  final bool canRefund;
}

class HistoricalPayment {
  const HistoricalPayment({
    required this.payeeAccountId,
    required this.amount,
    this.accountName,
    this.accountType,
  });

  final int payeeAccountId;
  final Decimal amount;
  final String? accountName;
  final int? accountType;
}

class HasNoSaleInRange implements Exception {
  const HasNoSaleInRange([this.message = 'В этот промежуток не было продаж']);
  final String message;

  @override
  String toString() => 'HasNoSaleInRange: $message';
}
