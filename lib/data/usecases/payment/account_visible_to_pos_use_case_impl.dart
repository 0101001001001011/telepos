import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/payment/account_visible_to_pos_use_case.dart';

class AccountVisibleToPosUseCaseImpl implements AccountVisibleToPosUseCase {
  AccountVisibleToPosUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  static const int _accountTypeCash = 0;
  static const int _accountTypeBank = 1;

  @override
  Future<List<Account>> getVisibleAccounts() async {
    final accounts = await (_db.select(
      _db.accounts,
    )..where((a) => a.visibleToPos.equals(true))).get();

    _logger.info(
      'AccountVisibleToPos: found ${accounts.length} visible accounts',
    );

    return accounts;
  }

  @override
  Future<List<Account>> getVisibleByType(int type) async {
    final accounts = await _db.accountDao.findByTypeAndVisibility(type, true);

    _logger.info(
      'AccountVisibleToPos: found ${accounts.length} visible accounts of type=$type',
    );

    return accounts;
  }

  @override
  Future<List<Account>> getVisibleBankAccounts() async {
    return getVisibleByType(_accountTypeBank);
  }

  @override
  Future<List<Account>> getVisibleCustomAccounts() async {
    final allVisible = await getVisibleAccounts();

    final customAccounts = allVisible
        .where((a) => a.type != _accountTypeCash && a.type != _accountTypeBank)
        .toList();

    _logger.info(
      'AccountVisibleToPos: found ${customAccounts.length} custom accounts',
    );

    return customAccounts;
  }
}
