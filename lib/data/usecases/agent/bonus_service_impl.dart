import 'package:decimal/decimal.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/bonus/bonus_entry_kind.dart';
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
      // Журналом, а не перезаписью остатка (задача 13). Именно отсюда
      // возврат потом узнаёт, **сколько было начислено по этому чеку**:
      // пересчитать это по нынешней ставке нельзя — `cashback_rate` к
      // моменту возврата может быть другой, и пересчёт дал бы
      // правдоподобное неверное число.
      await _db.bonusEntryDao.record(
        accountId: resolved.account.id,
        kind: BonusEntryKind.accrual,
        amount: accrued,
        receiptNo: saleReceiptNo,
        posId: await _posId(),
        reason: 'кэшбэк за покупку по ставке $rate %',
      );
    }

    return BonusAccrualResult(
      success: true,
      transactionId: _localTxnId('accrual', saleReceiptNo),
      accruedAmount: accrued,
      newBalance: newBalance,
    );
  }

  Future<Decimal> _cashbackRate() async {
    final thisPos = await _db.thisPosDao.get();
    final rate = thisPos?.cashbackRate ?? 0;
    return Decimal.fromInt(rate);
  }

  /// Номер кассы для записи журнала. Не настроена — `0`, тем же доводом,
  /// что в [BonusEntryDao]: начисление кэшбэка не повод не продать.
  Future<int> _posId() async {
    try {
      return (await _db.thisPosDao.get())?.id ?? 0;
    } catch (_) {
      return 0;
    }
  }

  String _localTxnId(String kind, int saleReceiptNo) =>
      'local-$kind-$saleReceiptNo-${DateTime.now().millisecondsSinceEpoch}';
}

class _CustomerCashback {
  const _CustomerCashback({required this.agent, required this.account});

  final Agent agent;
  final Account account;
}
