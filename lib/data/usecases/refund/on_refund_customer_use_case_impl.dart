import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/refund/on_refund_customer_use_case.dart';

class OnRefundCustomerUseCaseImpl implements OnRefundCustomerUseCase {
  OnRefundCustomerUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<void> perform({
    required Decimal refundAmount,
    required Decimal cashbackAmount,
    required List<Decimal> paymentAmounts,
    required int customerLocalId,
  }) async {
    final agents = await (_db.select(
      _db.agents,
    )..where((a) => a.localId.equals(customerLocalId))).get();

    if (agents.isEmpty) {
      throw const AgentNotFound('Customer not found');
    }

    final agent = agents.first;
    final mainAccountId = agent.mainAccountId;

    if (mainAccountId == null) {
      _logger.info(
        'OnRefundCustomer: agent $customerLocalId has no mainAccountId',
      );
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await (_db.update(_db.agents)
          ..where((a) => a.localId.equals(customerLocalId)))
        .write(AgentsCompanion(editTime: Value(now)));

    final paymentSum = paymentAmounts.fold<Decimal>(
      Decimal.zero,
      (sum, amount) => sum + amount,
    );
    final debtPayback = refundAmount - cashbackAmount + paymentSum;

    final account = await _db.accountDao.findById(mainAccountId);
    if (account == null) {
      _logger.warning('OnRefundCustomer: account $mainAccountId not found');
      return;
    }

    final newBalance = (account.value ?? Decimal.zero) + debtPayback;
    await (_db.update(_db.accounts)..where((a) => a.id.equals(mainAccountId)))
        .write(AccountsCompanion(value: Value(newBalance)));

    _logger.info(
      'OnRefundCustomer: credited agent $customerLocalId '
      'account $mainAccountId by $debtPayback → $newBalance',
    );
  }
}
