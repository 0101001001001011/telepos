import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/constants/enums/account_type.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/payment/payment_kind_resolver_impl.dart';
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
    final byId = {for (final a in allAccounts) a.id: a};

    // **Второе измерение — вид оплаты** (задача 14, шаг 8). Цена снятия
    // отказа `payment_account_conflict`, названная тем же шагом и
    // уплаченная здесь: без вида отчёт слил бы наличные и карту, обе
    // упавшие на счёт кассы, в одну строку «Счёт кассы».
    final rows = await _db.paymentDao.sumsByAccountAndKindBetween(
      userId,
      byId.keys.toList(),
      openTime,
      closeTime,
    );

    final resolver = PaymentKindResolver(_db);
    final seen = <int>{};
    for (final row in rows) {
      final accountId = row.read<int>('payee_account_id');
      final account = byId[accountId];
      if (account == null) continue;
      seen.add(accountId);

      final kindId = row.read<int?>('kind_id');
      final kind = await resolver.resolve(
        kindId: kindId,
        payeeAccountId: accountId,
      );
      final total = row.read<double?>('total');

      result.add(
        PaymentSumEntry(
          accountId: accountId,
          accountName: account.name ?? '',
          accountType: account.type,
          amount: total != null
              ? Decimal.parse(total.toStringAsFixed(3))
              : Decimal.zero,
          kindId: kind?.id ?? kindId,
          kindName: kind?.name,
        ),
      );
    }

    // Счёт, по которому за смену не прошло ни одной строки, всё равно
    // называется — нулём. Так было до этой правки, и убирать это
    // молчанием нельзя: отсутствие строки и ноль читаются кассиром
    // по-разному, а «карта не работала весь день» — как раз то, что
    // отчёт обязан показать.
    for (final account in allAccounts) {
      if (seen.contains(account.id)) continue;
      result.add(
        PaymentSumEntry(
          accountId: account.id,
          accountName: account.name ?? '',
          accountType: account.type,
          amount: Decimal.zero,
        ),
      );
    }

    _logger.info('CustomBankPaymentsSum: ${result.length} accounts processed');
    return result;
  }
}
