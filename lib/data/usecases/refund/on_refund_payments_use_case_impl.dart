import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/refund/on_refund_payments_use_case.dart';

class OnRefundPaymentsUseCaseImpl implements OnRefundPaymentsUseCase {
  OnRefundPaymentsUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  static const int _accountTypeCash = 0;
  static const int _accountTypeBank = 1;

  @override
  Future<List<RefundPaymentEntry>> create({
    required int refundLocalId,
    required Decimal refundAmount,
    required int userId,
    int? saleReceiptNo,
    int? salePosId,
  }) async {
    final thisPos = await _db.thisPosDao.get();
    final posAccountId = thisPos?.accountId;

    if (saleReceiptNo == null || salePosId == null) {
      if (posAccountId == null) {
        _logger.warning('OnRefundPayments: no pos accountId');
        return [];
      }
      return [
        RefundPaymentEntry(payeeAccountId: posAccountId, amount: -refundAmount),
      ];
    }

    final salePayments = await _db.paymentDao.findBySale(
      saleReceiptNo,
      salePosId,
    );

    if (salePayments.isEmpty) {
      if (posAccountId == null) {
        _logger.warning('OnRefundPayments: no pos accountId');
        return [];
      }
      return [
        RefundPaymentEntry(payeeAccountId: posAccountId, amount: -refundAmount),
      ];
    }

    final paymentAccounts = <int, _PaymentAccountInfo>{};
    for (final payment in salePayments) {
      final account = await _db.accountDao.findById(payment.payeeAccountId);
      if (account != null) {
        paymentAccounts[payment.payeeAccountId] = _PaymentAccountInfo(
          accountId: payment.payeeAccountId,
          accountType: account.type,
          saleAmount: payment.amount,
        );
      }
    }

    final cashPayments = paymentAccounts.values
        .where(
          (p) =>
              p.accountType == _accountTypeCash || p.accountId == posAccountId,
        )
        .toList();
    final bankPayments = paymentAccounts.values
        .where(
          (p) =>
              p.accountType == _accountTypeBank && p.accountId != posAccountId,
        )
        .toList();
    final customPayments = paymentAccounts.values
        .where(
          (p) =>
              p.accountType != _accountTypeCash &&
              p.accountType != _accountTypeBank &&
              p.accountId != posAccountId,
        )
        .toList();

    final result = <RefundPaymentEntry>[];
    var remainingAmount = refundAmount;

    remainingAmount = _distributeToPayments(
      cashPayments,
      remainingAmount,
      result,
    );
    remainingAmount = _distributeToPayments(
      bankPayments,
      remainingAmount,
      result,
    );
    remainingAmount = _distributeToPayments(
      customPayments,
      remainingAmount,
      result,
    );

    if (remainingAmount > Decimal.zero && posAccountId != null) {
      result.add(
        RefundPaymentEntry(
          payeeAccountId: posAccountId,
          amount: -remainingAmount,
        ),
      );
      remainingAmount = Decimal.zero;
    }

    if (remainingAmount > Decimal.zero) {
      _logger.warning('OnRefundPayments: $remainingAmount not distributed');
    }

    _logger.info(
      'OnRefundPayments: created ${result.length} reversal payments '
      'for refund=$refundLocalId',
    );

    return result;
  }

  Decimal _distributeToPayments(
    List<_PaymentAccountInfo> payments,
    Decimal remainingAmount,
    List<RefundPaymentEntry> result,
  ) {
    if (remainingAmount <= Decimal.zero || payments.isEmpty) {
      return remainingAmount;
    }

    final totalSaleAmount = payments.fold<Decimal>(
      Decimal.zero,
      (sum, p) => sum + p.saleAmount,
    );

    if (totalSaleAmount <= Decimal.zero) {
      return remainingAmount;
    }

    for (final payment in payments) {
      if (remainingAmount <= Decimal.zero) break;

      final maxAmount = payment.saleAmount;
      final refundAmount = remainingAmount > maxAmount
          ? maxAmount
          : remainingAmount;

      if (refundAmount > Decimal.zero) {
        result.add(
          RefundPaymentEntry(
            payeeAccountId: payment.accountId,
            amount: -refundAmount,
          ),
        );
        remainingAmount -= refundAmount;
      }
    }

    return remainingAmount;
  }
}

class _PaymentAccountInfo {
  const _PaymentAccountInfo({
    required this.accountId,
    required this.accountType,
    required this.saleAmount,
  });

  final int accountId;
  final int accountType;
  final Decimal saleAmount;
}
