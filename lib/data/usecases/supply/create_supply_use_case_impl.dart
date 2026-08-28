import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/supply/create_supply_use_case.dart';
import 'package:telepos/domain/usecases/supply/get_supplies_history_use_case.dart';

class CreateSupplyUseCaseImpl implements CreateSupplyUseCase {
  CreateSupplyUseCaseImpl(this._db);

  final AppDatabase _db;

  @override
  Future<CreateSupplyResult> execute({
    required int userId,
    required int supplierId,
    required SupplyPaymentType paymentType,
    int? accountId,
    String? comment,
  }) async {
    try {
      if (paymentType == SupplyPaymentType.fullSupply && accountId == null) {
        return CreateSupplyResult.failed(
          'Для полной оплаты необходимо указать счёт',
        );
      }

      final existingDraft = await getDraft();
      if (existingDraft != null) {
        await deleteDraft(existingDraft.id);
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final supplyId = await _db.supplyDao.insertSupply(
        SuppliesCompanion.insert(
          operationType: const Value(0),
          userId: Value(userId),
          supplierId: Value(supplierId),
          editTime: Value(now),
          amount: Value(Decimal.zero),
          paymentType: Value(paymentType.index),
          accountId: Value(accountId),
          comment: Value(comment),
          payment: Value(Decimal.zero),
          consignmentAmount: Value(Decimal.zero),
          paidAmount: Value(Decimal.zero),
          state: const Value(0),
          status: const Value(0),
        ),
      );

      return CreateSupplyResult.created(supplyId);
    } catch (e) {
      return CreateSupplyResult.failed('Ошибка создания приёмки: $e');
    }
  }

  @override
  Future<SupplyDraft?> getDraft() async {
    final supply = await _db.supplyDao.findDraft();
    if (supply == null) return null;

    return SupplyDraft(
      id: supply.id,
      supplierId: supply.supplierId ?? 0,
      paymentType: SupplyPaymentTypeExtension.fromIndex(supply.paymentType),
      accountId: supply.accountId,
      comment: supply.comment,
      amount: supply.amount ?? Decimal.zero,
      editTime: DateTime.fromMillisecondsSinceEpoch(
        (supply.editTime ?? 0) * 1000,
      ),
    );
  }

  @override
  Future<void> deleteDraft(int supplyId) async {
    await _db.supplyProductDao.deleteBySupplyId(supplyId);
    await _db.supplyDao.deleteSupply(supplyId);
  }
}
