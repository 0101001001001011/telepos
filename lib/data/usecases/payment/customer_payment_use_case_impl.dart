import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/payment/customer_payment_use_case.dart';

class CustomerPaymentUseCaseImpl implements CustomerPaymentUseCase {
  CustomerPaymentUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<CustomerPaymentResult> execute({
    required int agentId,
    required Decimal amount,
    required CustomerPaymentDecision decision,
    String? note,
  }) async {
    try {
      if (amount <= Decimal.zero) {
        return CustomerPaymentResult.failed('Сумма должна быть больше 0');
      }

      final agent = await _db.agentDao.findByLocalId(agentId);
      if (agent == null) {
        return CustomerPaymentResult.failed('Покупатель не найден');
      }

      final accountId = decision == CustomerPaymentDecision.investment
          ? agent.mainAccountId
          : agent.cashbackAccountId;

      if (accountId == null) {
        return CustomerPaymentResult.failed(
          'У покупателя нет соответствующего счёта',
        );
      }

      final account = await _db.accountDao.findById(accountId);
      if (account == null) {
        return CustomerPaymentResult.failed('Счёт не найден');
      }

      final currentBalance = account.value ?? Decimal.zero;
      final newBalance = currentBalance + amount;

      await _db.accountDao.updateBalance(accountId, newBalance);

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final operationId = await _db.cashOperationDao.db
          .into(_db.cashOperations)
          .insert(
            CashOperationsCompanion.insert(
              amount: amount,
              type: 0,
              accountId: Value(accountId),
              note: Value(note ?? '${decision.displayName} на счёт покупателя'),
              docTime: Value(now),
              state: const Value(1),
            ),
          );

      _logger.info(
        'Customer payment created: $operationId, '
        'agent: $agentId, amount: $amount, decision: ${decision.name}',
      );

      return CustomerPaymentResult.created(
        transactionId: operationId,
        newBalance: newBalance,
      );
    } catch (e, st) {
      _logger.error('Error processing customer payment', e, st);
      return CustomerPaymentResult.failed('Ошибка обработки платежа: $e');
    }
  }

  @override
  Future<bool> needsDecisionDialog(int agentId) async {
    try {
      final balance = await getCustomerBalance(agentId);
      return balance > Decimal.zero;
    } catch (e) {
      _logger.warning('Error checking decision dialog need: $e');
      return false;
    }
  }

  @override
  Future<Decimal> getCustomerBalance(int agentId) async {
    try {
      final agent = await _db.agentDao.findByLocalId(agentId);
      if (agent == null || agent.mainAccountId == null) {
        return Decimal.zero;
      }

      final account = await _db.accountDao.findById(agent.mainAccountId!);
      return account?.value ?? Decimal.zero;
    } catch (e) {
      _logger.warning('Error getting customer balance: $e');
      return Decimal.zero;
    }
  }
}
