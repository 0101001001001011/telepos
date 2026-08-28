import 'package:decimal/decimal.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/agent/bonus_service.dart';

class BonusServiceImpl implements BonusService {
  BonusServiceImpl({AppDatabase? db}) : _db = db ?? GetIt.I<AppDatabase>();

  final AppDatabase _db;

  static final Decimal _hundred = Decimal.fromInt(100);

  Future<_CustomerCashback?> _resolveCashback(int phone) async {
    var agent = await _db.agentDao.findByPhoneAndType(phone, 1);
    agent ??= await _db.agentDao.findByPhone(phone);
    if (agent == null || agent.cashbackAccountId == null) return null;

    final account = await _db.accountDao.findById(agent.cashbackAccountId!);
    if (account == null) return null;

    return _CustomerCashback(agent: agent, account: account);
  }

  @override
  Future<BonusBalance> getBonusBalance(int phone) async {
    final resolved = await _resolveCashback(phone);
    final balance = resolved?.account.value ?? Decimal.zero;

    return BonusBalance(
      phone: phone,
      balance: balance,
      name: resolved?.agent.name,
    );
  }

  @override
  Future<BonusDeductResult> deductBonuses({
    required int phone,
    required Decimal amount,
    required int saleReceiptNo,
  }) async {
    final resolved = await _resolveCashback(phone);
    if (resolved == null) {
      return BonusDeductResult(
        success: false,
        transactionId: '',
        deductedAmount: Decimal.zero,
        remainingBalance: Decimal.zero,
        errorMessage: 'Клиент или кешбэк-счёт не найден',
      );
    }

    final current = resolved.account.value ?? Decimal.zero;
    if (amount <= Decimal.zero || amount > current) {
      return BonusDeductResult(
        success: false,
        transactionId: '',
        deductedAmount: Decimal.zero,
        remainingBalance: current,
        errorMessage: 'Недостаточно бонусов для списания',
      );
    }

    final remaining = current - amount;
    await _db.accountDao.updateBalance(resolved.account.id, remaining);

    return BonusDeductResult(
      success: true,
      transactionId: _localTxnId('deduct', saleReceiptNo),
      deductedAmount: amount,
      remainingBalance: remaining,
    );
  }

  @override
  Future<BonusAccrualResult> accrualBonuses({
    required int phone,
    required Decimal saleAmount,
    required int saleReceiptNo,
  }) async {
    final resolved = await _resolveCashback(phone);
    if (resolved == null) {
      return BonusAccrualResult(
        success: false,
        transactionId: '',
        accruedAmount: Decimal.zero,
        newBalance: Decimal.zero,
        errorMessage: 'Клиент или кешбэк-счёт не найден',
      );
    }

    final rate = await _cashbackRate();
    final accrued = rate <= Decimal.zero
        ? Decimal.zero
        : (saleAmount * rate / _hundred).toDecimal().round(scale: 3);

    final current = resolved.account.value ?? Decimal.zero;
    final newBalance = current + accrued;
    if (accrued > Decimal.zero) {
      await _db.accountDao.updateBalance(resolved.account.id, newBalance);
    }

    return BonusAccrualResult(
      success: true,
      transactionId: _localTxnId('accrual', saleReceiptNo),
      accruedAmount: accrued,
      newBalance: newBalance,
    );
  }

  @override
  Future<void> cancelTransaction(String transactionId) async {
    return;
  }

  Future<Decimal> _cashbackRate() async {
    final thisPos = await _db.thisPosDao.get();
    final rate = thisPos?.cashbackRate ?? 0;
    return Decimal.fromInt(rate);
  }

  String _localTxnId(String kind, int saleReceiptNo) =>
      'local-$kind-$saleReceiptNo-${DateTime.now().millisecondsSinceEpoch}';
}

class _CustomerCashback {
  const _CustomerCashback({required this.agent, required this.account});

  final Agent agent;
  final Account account;
}
