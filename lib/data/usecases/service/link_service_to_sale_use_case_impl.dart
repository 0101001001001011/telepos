import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/service/link_service_to_sale_use_case.dart';

class LinkServiceToSaleUseCaseImpl implements LinkServiceToSaleUseCase {
  LinkServiceToSaleUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<void> link(int serviceOrderId, int receiptNo, int posId) async {
    try {
      await _db.serviceOrderDao.linkToSale(serviceOrderId, receiptNo, posId);

      _logger.info(
        'Service order $serviceOrderId linked to sale: '
        'receiptNo=$receiptNo, posId=$posId',
      );
    } catch (e) {
      _logger.error(
        'Failed to link service order $serviceOrderId to sale '
        '(receiptNo=$receiptNo, posId=$posId): $e',
      );
      rethrow;
    }
  }
}
