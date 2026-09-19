import 'package:decimal/decimal.dart';
import 'package:telepos/domain/entities/sale/sale_entity.dart';
import 'package:telepos/domain/entities/sale/sale_product_entity.dart';

abstract class SaleRepository {
  Future<SaleEntity?> findByKey(int receiptNo, int posId);

  Future<SaleEntity?> findBySaleId(int saleId);

  Future<int?> findLastReceiptNo();

  /// Чек в работе **этого** рабочего места ([terminalId]) **на этой кассе**
  /// ([posId]) — не кассы вообще и не сети вообще. Оба довода обязательны,
  /// и почему именно оба — в докстринге `SaleDao.findInProgress`
  /// (`lib/data/database/daos/sale_dao.dart`): без кассы выборка отбирает
  /// по двум третям составного ключа владения и находит чек соседней
  /// кассы, попавший в базу обменом.
  Future<SaleEntity?> findInProgress({
    required int posId,
    required int terminalId,
  });

  Future<List<SaleEntity>> findByState(int state);

  Future<int> countWithState(int state);

  Future<Decimal?> amountOfShift(int userId, int fromTime, int toTime);

  Future<void> insert(SaleEntity entity);

  Future<void> updateState(int receiptNo, int posId, int state);

  Future<SaleEntity?> findFirstSaleAfter(int timestamp);

  Future<List<SaleProductEntity>> findProductsByKey(int receiptNo, int posId);
}
