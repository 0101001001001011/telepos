import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/sale/deferred_sale_service.dart';

class DeferredSaleServiceImpl implements DeferredSaleService {
  DeferredSaleServiceImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  static const int _stateDeferred = 3;

  static const int _stateInProgress = 0;

  @override
  Future<void> deferSale({required int receiptNo}) async {
    final posId = await _getPosId();

    await _db.saleDao.updateState(receiptNo, posId, _stateDeferred);
    _logger.info('DeferredSale: deferred receipt=$receiptNo, pos=$posId');
  }

  @override
  Future<Sale?> undeferSale({required int receiptNo}) async {
    final posId = await _getPosId();

    final inProgress = await _db.saleDao.findInProgress();
    if (inProgress != null) {
      await (_db.delete(_db.sales)..where(
            (s) =>
                s.receiptNo.equals(inProgress.receiptNo) &
                s.posId.equals(inProgress.posId),
          ))
          .go();
      _logger.info(
        'DeferredSale: deleted in-progress receipt=${inProgress.receiptNo}',
      );
    }

    await _db.saleDao.updateState(receiptNo, posId, _stateInProgress);

    final sales =
        await (_db.select(_db.sales)..where(
              (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId),
            ))
            .get();

    if (sales.isEmpty) {
      _logger.warning(
        'DeferredSale: cannot find undeferred sale receipt=$receiptNo',
      );
      return null;
    }

    _logger.info('DeferredSale: undeferred receipt=$receiptNo, pos=$posId');
    return sales.first;
  }

  @override
  Future<List<Sale>> getDeferredSales() async {
    return _db.saleDao.findByState(_stateDeferred);
  }

  @override
  Future<List<DeferredSaleProduct>> getProducts({
    required int receiptNo,
    required int posId,
  }) async {
    final saleProducts = await _db.saleProductDao.findBySale(receiptNo, posId);
    final result = <DeferredSaleProduct>[];

    for (final sp in saleProducts) {
      final productInfo = await _db.productInfoDao.findByIdAndNotDeleted(
        sp.ucode,
      );
      if (productInfo != null) {
        result.add(
          DeferredSaleProduct(
            ucode: sp.ucode,
            name: productInfo.name,
            quantity: sp.quantity,
            price: sp.price,
          ),
        );
      }
    }

    return result;
  }

  Future<int> _getPosId() async {
    final thisPos = await _db.thisPosDao.get();
    if (thisPos == null || thisPos.id == null) {
      throw StateError('DeferredSale: ThisPos not found');
    }
    return thisPos.id!;
  }
}
