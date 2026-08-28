import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:get_it/get_it.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/usecases/cogs/apply_cogs_on_issue.dart';
import 'package:telepos/domain/usecases/cogs/calculate_cogs_use_case.dart';

class SupplierReturnCogsLine {
  const SupplierReturnCogsLine({required this.ucode, required this.quantity});

  final int ucode;
  final Decimal quantity;
}

class SupplierReturnCogs {
  const SupplierReturnCogs({
    required this.totalCogs,
    required this.batchResult,
  });

  final Decimal totalCogs;
  final IssueCogsBatchResult batchResult;

  String get ledgerNote => batchResult.ledgerNote;
}

class ApplySupplierReturnCogsUseCase {
  ApplySupplierReturnCogsUseCase({
    CalculateCogsUseCase? cogsUseCase,
    AppDatabase? db,
  }) : _cogsUseCase = cogsUseCase,
       _db = db;

  final CalculateCogsUseCase? _cogsUseCase;
  final AppDatabase? _db;

  AppDatabase get _database => _db ?? GetIt.I<AppDatabase>();
  CalculateCogsUseCase get _cogs =>
      _cogsUseCase ?? GetIt.I<CalculateCogsUseCase>();

  Future<SupplierReturnCogs> apply({
    required List<SupplierReturnCogsLine> lines,
    CogsMethod method = CogsMethod.fifo,
    bool consumeBatches = true,
    int? persistNoteToReturnId,
  }) async {
    final applier = ApplyCogsOnIssue(cogsUseCase: _cogs, db: _database);
    final batchResult = await applier.applyAll(
      [for (final l in lines) (ucode: l.ucode, quantity: l.quantity)],
      method: method,
      consumeBatches: consumeBatches,
    );

    if (persistNoteToReturnId != null) {
      final existing = await _database.supplierReturnDao.findById(
        persistNoteToReturnId,
      );
      final base = existing?.comment;
      final merged = [
        if (base != null && base.isNotEmpty) base,
        batchResult.ledgerNote,
      ].join(' | ');
      await _database.supplierReturnDao.updateReturn(
        persistNoteToReturnId,
        SupplierReturnsCompanion(comment: Value(merged)),
      );
    }

    return SupplierReturnCogs(
      totalCogs: batchResult.totalCogs,
      batchResult: batchResult,
    );
  }
}
