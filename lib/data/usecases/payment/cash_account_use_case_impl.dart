import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/payment/cash_account_use_case.dart';

class CashAccountUseCaseImpl implements CashAccountUseCase {
  CashAccountUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<Account?> get() async {
    final thisPos = await _db.thisPosDao.get();
    final accountId = thisPos?.accountId;

    if (accountId == null) {
      _logger.warning('CashAccountUseCase: no accountId in ThisPos');
      return null;
    }

    final account = await _db.accountDao.findById(accountId);

    if (account == null) {
      _logger.warning('CashAccountUseCase: account $accountId not found');
      return null;
    }

    _logger.info('CashAccountUseCase: got cash account id=$accountId');
    return account;
  }

  @override
  Future<int?> getAccountId() async {
    final thisPos = await _db.thisPosDao.get();
    return thisPos?.accountId;
  }
}
