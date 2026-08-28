import 'package:decimal/decimal.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/cogs/calculate_cogs_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_config_use_case.dart';

Future<CogsMethod> resolveConfiguredCogsMethod() async {
  try {
    if (!GetIt.I.isRegistered<WmsConfigUseCase>()) return CogsMethod.fifo;
    final token = await GetIt.I<WmsConfigUseCase>().costMethod();
    return token == 'AVG' ? CogsMethod.weightedAverage : CogsMethod.fifo;
  } catch (_) {
    return CogsMethod.fifo;
  }
}

class IssueCogs {
  const IssueCogs({
    required this.ucode,
    required this.quantity,
    required this.cogs,
    required this.result,
  });

  final int ucode;
  final Decimal quantity;

  final Decimal cogs;

  final CogsResult result;
}

class ApplyCogsOnIssue {
  ApplyCogsOnIssue({required this.cogsUseCase, AppDatabase? db}) : _db = db;

  final CalculateCogsUseCase cogsUseCase;
  final AppDatabase? _db;

  AppDatabase get _database => _db ?? GetIt.I<AppDatabase>();

  Future<IssueCogs> apply({
    required int ucode,
    required Decimal quantity,
    CogsMethod method = CogsMethod.fifo,
    bool consumeBatches = true,
  }) async {
    final result = await cogsUseCase.calculate(
      ucode: ucode,
      quantity: quantity,
      method: method,
    );

    if (consumeBatches && method == CogsMethod.fifo) {
      for (final c in result.consumptions) {
        if (c.batchId == 0) continue;
        await _database.batchDao.adjustQuantity(c.batchId, -c.quantity);
      }
    }

    return IssueCogs(
      ucode: ucode,
      quantity: quantity,
      cogs: result.totalCost,
      result: result,
    );
  }

  Future<IssueCogsBatchResult> applyAll(
    List<({int ucode, Decimal quantity})> items, {
    CogsMethod method = CogsMethod.fifo,
    bool consumeBatches = true,
  }) async {
    final perItem = <IssueCogs>[];
    var total = Decimal.zero;
    for (final item in items) {
      final issue = await apply(
        ucode: item.ucode,
        quantity: item.quantity,
        method: method,
        consumeBatches: consumeBatches,
      );
      perItem.add(issue);
      total += issue.cogs;
    }
    return IssueCogsBatchResult(
      items: perItem,
      totalCogs: total,
      method: method,
    );
  }
}

class IssueCogsBatchResult {
  const IssueCogsBatchResult({
    required this.items,
    required this.totalCogs,
    required this.method,
  });

  final List<IssueCogs> items;

  final Decimal totalCogs;
  final CogsMethod method;

  String get ledgerNote {
    final m = method == CogsMethod.fifo ? 'FIFO' : 'WAVG';
    return 'COGS[$m]=$totalCogs';
  }
}
