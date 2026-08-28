import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/constants/enums/account_type.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/shift/shift_receipt.dart';
import 'package:telepos/domain/usecases/shift/custom_bank_payments_sum_use_case.dart';

class CustomBankPaymentsSumUseCaseImpl implements CustomBankPaymentsSumUseCase {
  CustomBankPaymentsSumUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<List<PaymentSumEntry>> getPaymentSums({
    required int userId,
    required int openTime,
    required int closeTime,
  }) async {
    final result = <PaymentSumEntry>[];

    final customBankAccounts = await _db.accountDao.findByTypeAndVisibility(
      AccountType.customBank.index,
      true,
    );

    final thisPos = await _db.thisPosDao.get();
    Account? posAccount;
    final posAccountId = thisPos?.accountId;
    if (posAccountId != null) {
      posAccount = await _db.accountDao.findById(posAccountId);
    }

    final allAccounts = <Account>[...customBankAccounts];
    if (posAccount != null) {
      allAccounts.add(posAccount);
    }

    for (final account in allAccounts) {
      final sum = await _db.paymentDao.sumByUserAndPayeeAccountIdBetween(
        userId,
        account.id,
        openTime,
        closeTime,
      );

      final amount = sum != null
          ? Decimal.parse(sum.toStringAsFixed(3))
          : Decimal.zero;

      result.add(
        PaymentSumEntry(
          accountId: account.id,
          accountName: account.name ?? '',
          accountType: account.type,
          amount: amount,
        ),
      );
    }

    _logger.info('CustomBankPaymentsSum: ${result.length} accounts processed');
    return result;
  }
}
