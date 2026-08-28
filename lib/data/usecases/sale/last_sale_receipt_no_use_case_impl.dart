import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/sale/last_sale_receipt_no_use_case.dart';

class LastSaleReceiptNoUseCaseImpl implements LastSaleReceiptNoUseCase {
  LastSaleReceiptNoUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<void> perform() async {
    final int? serverLastReceiptNo = await _fetchLastReceiptNoFromServer();

    if (serverLastReceiptNo == null) {
      _logger.info('LastSaleReceiptNo: server unavailable, using local');
      return;
    }

    final localLastReceiptNo = await _db.saleDao.findLastReceiptNo() ?? 0;

    if (serverLastReceiptNo != 0 && localLastReceiptNo < serverLastReceiptNo) {
      await _renumberInProgressSale(serverLastReceiptNo);
    }
  }

  Future<int?> _fetchLastReceiptNoFromServer() async {
    return null;
  }

  Future<void> _renumberInProgressSale(int serverLastReceiptNo) async {
    final inProgressSale = await _db.saleDao.findInProgress();
    if (inProgressSale == null) {
      return;
    }

    final thisPos = await _db.thisPosDao.get();
    if (thisPos == null) {
      _logger.warning('LastSaleReceiptNo: thisPos not found');
      return;
    }

    final newReceiptNo = serverLastReceiptNo + 1;
    final oldReceiptNo = inProgressSale.receiptNo;
    final oldPosId = inProgressSale.posId;

    _logger.info(
      'LastSaleReceiptNo: renumbering receipt $oldReceiptNo → $newReceiptNo',
    );

    await _db.transaction(() async {
      await (_db.delete(_db.sales)..where(
            (s) => s.receiptNo.equals(oldReceiptNo) & s.posId.equals(oldPosId),
          ))
          .go();

      final newPosId = thisPos.id ?? oldPosId;
      final saleProducts = await _db.saleProductDao.findBySale(
        oldReceiptNo,
        oldPosId,
      );
      for (final sp in saleProducts) {
        await _db
            .into(_db.saleProducts)
            .insert(
              SaleProductsCompanion.insert(
                ucode: sp.ucode,
                quantity: sp.quantity,
                price: sp.price,
                priceBefore: sp.priceBefore,
                receiptNo: Value(newReceiptNo),
                posId: Value(newPosId),
                barcode: Value(sp.barcode),
                categoryId: Value(sp.categoryId),
              ),
            );
      }

      final universalProducts = await _db.saleProductDao.findUniversalBySale(
        oldReceiptNo,
        oldPosId,
      );
      for (final up in universalProducts) {
        await _db
            .into(_db.universalProducts)
            .insert(
              UniversalProductsCompanion.insert(
                quantity: up.quantity,
                price: up.price,
                receiptNo: Value(newReceiptNo),
                posId: Value(newPosId),
                priceBefore: Value(up.priceBefore),
              ),
            );
      }

      await _db
          .into(_db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: newReceiptNo,
              posId: newPosId,
              userId: inProgressSale.userId,
              amount: inProgressSale.amount,
              time: inProgressSale.time,
              state: Value(0),
              isOfd: Value(inProgressSale.isOfd),
              isWholesale: Value(inProgressSale.isWholesale),
            ),
          );
    });
  }
}
