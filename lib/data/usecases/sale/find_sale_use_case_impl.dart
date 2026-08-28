import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/sale/find_sale_use_case.dart';

class FindSaleUseCaseImpl implements FindSaleUseCase {
  FindSaleUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<Sale?> find({required int receiptNo, required int posId}) async {
    final sales =
        await (_db.select(_db.sales)..where(
              (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId),
            ))
            .get();

    if (sales.isNotEmpty) {
      _logger.info(
        'FindSale: found in local DB receipt=$receiptNo, pos=$posId',
      );
      return sales.first;
    }

    _logger.info(
      'FindSale: not found in local DB receipt=$receiptNo, pos=$posId',
    );
    return null;
  }
}
