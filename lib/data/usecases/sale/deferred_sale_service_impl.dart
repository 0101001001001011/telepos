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

    // Отложенный чек не принадлежит никому (I156, правило смысла v37):
    // владелец очищается тем же ходом, что и перевод в state = 3, иначе
    // строка осталась бы с чужим (устаревшим) `terminalId` при state,
    // который по контракту владельца не несёт.
    await (_db.update(_db.sales)
          ..where((s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId)))
        .write(
          const SalesCompanion(
            state: Value(_stateDeferred),
            terminalId: Value(null),
          ),
        );
    _logger.info('DeferredSale: deferred receipt=$receiptNo, pos=$posId');
  }

  @override
  Future<Sale?> undeferSale({
    required int receiptNo,
    required int terminalId,
  }) async {
    final posId = await _getPosId();

    // Условие `state = 3` живёт **в самом обновлении**, а не в проверке
    // перед ним: между чтением и записью успевает вклиниться второй
    // поднимающий, и разводить их обязана база. Проигравший получает
    // `null` — ровно потому, что строка уже не отложена.
    //
    // Безусловное обновление, стоявшее здесь до задачи 17, поднимало и
    // **чужой чек в работе**: `state` в него не смотрел вовсе, и вызов с
    // номером уже поднятого чека переписывал ему владельца на кассу.
    // Измерено пробой `deferred_pool_test.dart`: чек, поднятый седьмым
    // местом, после вызова принадлежал первому.
    final raised =
        await (_db.update(_db.sales)..where(
              (s) =>
                  s.receiptNo.equals(receiptNo) &
                  s.posId.equals(posId) &
                  s.state.equals(_stateDeferred),
            ))
            .write(
              SalesCompanion(
                state: const Value(_stateInProgress),
                // Владелец — тот, кого назвал вызывающий (правило смысла
                // `Sales.terminalId`). Своей догадки о владельце у этого
                // метода больше нет: она приписывала поднятый чек кассе,
                // кто бы его ни поднял.
                terminalId: Value(terminalId),
              ),
            );

    if (raised == 0) {
      _logger.warning(
        'DeferredSale: receipt=$receiptNo is not deferred, pos=$posId',
      );
      return null;
    }

    _logger.info(
      'DeferredSale: undeferred receipt=$receiptNo, pos=$posId, '
      'terminal=$terminalId',
    );
    return _db.saleDao.findByKey(receiptNo, posId);
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

  /// Единая политика номера кассы (`ThisPosDao.requireId`, круг правки 4
  /// задачи 7): свой бросок здесь был четвёртым способом ответить на один
  /// и тот же вопрос.
  Future<int> _getPosId() => _db.thisPosDao.requireId();
}
