import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/restaurant/calculate_service_charge_use_case.dart';

class CalculateServiceChargeUseCaseImpl
    implements CalculateServiceChargeUseCase {
  CalculateServiceChargeUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  static final Decimal _hundred = Decimal.fromInt(100);

  @override
  Future<Decimal> calculate(Decimal subtotal) async {
    try {
      final thisPos = await _db.thisPosDao.get();
      if (thisPos == null) {
        _logger.warning('ServiceCharge: ThisPos not configured');
        return Decimal.zero;
      }

      if (!thisPos.serviceChargeEnabled) {
        return Decimal.zero;
      }

      final percent = thisPos.defaultServiceChargePercent;
      if (percent == null || percent == Decimal.zero) {
        return Decimal.zero;
      }

      final charge = (subtotal * percent / _hundred).toDecimal().round(
        scale: 3,
      );

      _logger.info('ServiceCharge: $subtotal * $percent% = $charge');

      return charge;
    } catch (e) {
      _logger.error('ServiceCharge: failed to calculate for $subtotal: $e');
      rethrow;
    }
  }

  @override
  Future<void> applyToSale(int receiptNo, int posId) async {
    try {
      final products = await _db.saleProductDao.findBySale(receiptNo, posId);

      var subtotal = Decimal.zero;
      for (final product in products) {
        subtotal += product.price * product.quantity;
      }

      final charge = await calculate(subtotal);

      if (charge == Decimal.zero) {
        _logger.info(
          'ServiceCharge: no charge to apply for '
          'receipt=$receiptNo, pos=$posId',
        );
        return;
      }

      await (_db.update(_db.sales)..where(
            (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId),
          ))
          .write(SalesCompanion(serviceCharge: Value(charge)));

      _logger.info(
        'ServiceCharge: applied $charge to '
        'receipt=$receiptNo, pos=$posId',
      );
    } catch (e) {
      _logger.error(
        'ServiceCharge: failed to apply to '
        'receipt=$receiptNo, pos=$posId: $e',
      );
      rethrow;
    }
  }
}
