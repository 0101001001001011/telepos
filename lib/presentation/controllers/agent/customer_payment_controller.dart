import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/domain/usecases/payment/customer_payment_use_case.dart';
import 'package:telepos/presentation/controllers/agent/agent_controller.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';

@immutable
class CustomerPaymentOutcome {
  const CustomerPaymentOutcome({
    required this.success,
    this.newAgentBalance,
    this.errorMessage,
  });

  final bool success;

  final Decimal? newAgentBalance;

  final String? errorMessage;
}

class CustomerPaymentController
    extends Notifier<AsyncValue<CustomerPaymentOutcome?>> {
  @override
  AsyncValue<CustomerPaymentOutcome?> build() => const AsyncData(null);

  AppDatabase get _db => GetIt.I<AppDatabase>();
  CustomerPaymentUseCase get _useCase => GetIt.I<CustomerPaymentUseCase>();

  Future<CustomerPaymentOutcome> record({
    required int agentId,
    required Decimal amount,
    CustomerPaymentDecision decision = CustomerPaymentDecision.investment,
    String? note,
  }) async {
    state = const AsyncLoading();

    final result = await _useCase.execute(
      agentId: agentId,
      amount: amount,
      decision: decision,
      note: note,
    );

    if (!result.success) {
      final outcome = CustomerPaymentOutcome(
        success: false,
        errorMessage: result.errorMessage,
      );
      state = AsyncData(outcome);
      return outcome;
    }

    await _creditPosAccount(amount);

    ref.invalidate(shiftControllerProvider);
    ref.invalidate(agentSearchProvider);

    final outcome = CustomerPaymentOutcome(
      success: true,
      newAgentBalance: result.newBalance,
    );
    state = AsyncData(outcome);
    return outcome;
  }

  Future<void> _creditPosAccount(Decimal amount) async {
    final posAccountId = await _resolvePosAccountId();
    if (posAccountId == null) return;

    final account = await _db.accountDao.findById(posAccountId);
    if (account == null) return;

    final current = account.value ?? Decimal.zero;
    await _db.accountDao.updateBalance(posAccountId, current + amount);
  }

  Future<int?> _resolvePosAccountId() async {
    final thisPos = await _db.thisPosDao.get();
    final fromPos = thisPos?.accountId;
    if (fromPos != null) return fromPos;

    final posAccounts = await _db.accountDao.findByType(AccountType.pos);
    if (posAccounts.isNotEmpty) return posAccounts.first.id;
    return null;
  }
}

final customerPaymentControllerProvider =
    NotifierProvider<
      CustomerPaymentController,
      AsyncValue<CustomerPaymentOutcome?>
    >(CustomerPaymentController.new);
