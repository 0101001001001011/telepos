import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/presentation/controllers/agent/agent_controller.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';

@immutable
class SupplierPaymentOutcome {
  const SupplierPaymentOutcome({
    required this.success,
    this.newSupplierBalance,
    this.errorMessage,
  });

  final bool success;

  final Decimal? newSupplierBalance;

  final String? errorMessage;
}

class SupplierPaymentController
    extends Notifier<AsyncValue<SupplierPaymentOutcome?>> {
  @override
  AsyncValue<SupplierPaymentOutcome?> build() => const AsyncData(null);

  AppDatabase get _db => GetIt.I<AppDatabase>();

  Future<SupplierPaymentOutcome> repay({
    required int agentId,
    required Decimal amount,
  }) async {
    state = const AsyncLoading();

    try {
      final newBalance = await _db.agentDao.postLedgerAdjustment(
        agentId,
        -amount,
      );

      await _debitPosAccount(amount);

      ref.invalidate(shiftControllerProvider);
      ref.invalidate(agentSearchProvider);

      final outcome = SupplierPaymentOutcome(
        success: true,
        newSupplierBalance: newBalance,
      );
      state = AsyncData(outcome);
      return outcome;
    } catch (e) {
      final outcome = SupplierPaymentOutcome(
        success: false,
        errorMessage: e.toString(),
      );
      state = AsyncData(outcome);
      return outcome;
    }
  }

  Future<void> _debitPosAccount(Decimal amount) async {
    final posAccountId = await _resolvePosAccountId();
    if (posAccountId == null) return;

    final account = await _db.accountDao.findById(posAccountId);
    if (account == null) return;

    final current = account.value ?? Decimal.zero;
    await _db.accountDao.updateBalance(posAccountId, current - amount);
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

final supplierPaymentControllerProvider =
    NotifierProvider<
      SupplierPaymentController,
      AsyncValue<SupplierPaymentOutcome?>
    >(SupplierPaymentController.new);
