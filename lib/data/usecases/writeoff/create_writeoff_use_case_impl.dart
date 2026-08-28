import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/usecases/cogs/apply_cogs_on_issue.dart';
import 'package:telepos/domain/usecases/cogs/calculate_cogs_use_case.dart';
import 'package:telepos/domain/usecases/writeoff/create_writeoff_use_case.dart';

class CreateWriteoffUseCaseImpl implements CreateWriteoffUseCase {
  CreateWriteoffUseCaseImpl({
    CalculateCogsUseCase? cogsUseCase,
    CogsMethod? cogsMethod,
  }) : _cogsUseCase = cogsUseCase,
       _cogsMethod = cogsMethod;

  final CalculateCogsUseCase? _cogsUseCase;

  final CogsMethod? _cogsMethod;

  AppDatabase get _db => GetIt.I<AppDatabase>();
  Talker get _logger => GetIt.I<Talker>();

  CalculateCogsUseCase get _cogs =>
      _cogsUseCase ?? GetIt.I<CalculateCogsUseCase>();

  Decimal? lastCogs;

  @override
  Future<CreateWriteoffResult> create({
    required WriteoffReason reason,
    required List<WriteoffProductEntry> products,
    String? comment,
    int? userId,
  }) async {
    if (products.isEmpty) {
      return CreateWriteoffResult.failed('Нет товаров для списания');
    }

    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final totalAmount = products.fold<Decimal>(
        Decimal.zero,
        (sum, p) => sum + p.amount,
      );

      return await _db.transaction(() async {
        final applier = ApplyCogsOnIssue(cogsUseCase: _cogs, db: _db);
        final method = _cogsMethod ?? await resolveConfiguredCogsMethod();
        final cogsResult = await applier.applyAll([
          for (final p in products) (ucode: p.ucode, quantity: p.quantity),
        ], method: method);
        lastCogs = cogsResult.totalCogs;

        final commentWithCogs = [
          if (comment != null && comment.isNotEmpty) comment,
          cogsResult.ledgerNote,
        ].join(' | ');

        final writeoffId = await _db.writeoffDao.insertWriteoff(
          WriteoffsCompanion(
            userId: Value(userId),
            docTime: Value(now),
            reason: Value(reason.value),
            comment: Value(commentWithCogs),
            amount: Value(totalAmount),
            state: const Value(1),
          ),
        );

        for (final product in products) {
          await _db.writeoffProductDao.insertProduct(
            WriteoffProductsCompanion(
              writeoffId: Value(writeoffId),
              ucode: Value(product.ucode),
              quantity: Value(product.quantity),
              price: Value(product.price),
              amount: Value(product.amount),
            ),
          );
        }

        for (final product in products) {
          await _db.productInfoDao.adjustQuantity(
            product.ucode,
            -product.quantity,
          );
        }

        _logger.info(
          'Writeoff created: id=$writeoffId, reason=$reason, '
          '${products.length} products, total: $totalAmount, '
          'COGS(${cogsResult.method.name})=${cogsResult.totalCogs}',
        );

        return CreateWriteoffResult.saved(
          writeoffId: writeoffId,
          totalAmount: totalAmount,
          productCount: products.length,
        );
      });
    } catch (e) {
      _logger.error('Failed to create writeoff: $e');
      return CreateWriteoffResult.failed('Ошибка создания списания: $e');
    }
  }
}
