import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/services/shift_service.dart';
import 'package:telepos/domain/usecases/sale/sale_initiation_use_case.dart';

class SaleInitiationUseCaseImpl implements SaleInitiationUseCase {
  SaleInitiationUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
    required ShiftService shiftService,
  }) : _db = db,
       _logger = logger,
       _shiftService = shiftService;

  final AppDatabase _db;
  final Talker _logger;
  final ShiftService _shiftService;

  static const int _stateInProgress = 0;

  @override
  Future<Sale?> initiate({bool isWholesale = false, int? userId}) async {
    final thisPos = await _db.thisPosDao.get();
    if (thisPos == null) {
      _logger.warning('SaleInitiation: ThisPos not found');
      return null;
    }

    final weightRound = thisPos.weightProductRoundType;
    final discountRound = thisPos.discountsRoundType;

    final existingSale = await _db.saleDao.findInProgress();

    if (existingSale != null) {
      await (_db.update(_db.sales)..where(
            (s) =>
                s.receiptNo.equals(existingSale.receiptNo) &
                s.posId.equals(existingSale.posId),
          ))
          .write(
            SalesCompanion(
              weightProductRoundType: Value(weightRound),
              discountsRoundType: Value(discountRound),
              isWholesale: Value(isWholesale),
            ),
          );

      _logger.info(
        'SaleInitiation: resumed sale '
        'receipt=${existingSale.receiptNo}, pos=${existingSale.posId}',
      );

      return _db.saleDao.findInProgress();
    }

    var shift = await _db.shiftDao.findOpenedShift();
    if (shift == null) {
      _logger.info('SaleInitiation: no opened shift — auto-opening');
      final lastShift = await _db.shiftDao.findLastClosedShiftReport();
      final effectiveUserId = userId ?? lastShift?.userId ?? 1;
      await _shiftService.onOpenShift(effectiveUserId);
      shift = await _db.shiftDao.findOpenedShift();
      if (shift == null) {
        _logger.warning('SaleInitiation: failed to auto-open shift');
        return null;
      }
    }

    final lastReceipt = await _db.saleDao.findLastReceiptNo();
    final nextReceiptNo = (lastReceipt ?? 0) + 1;

    final posId = thisPos.id;
    if (posId == null) {
      _logger.warning('SaleInitiation: ThisPos has no id');
      return null;
    }

    await _db
        .into(_db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: nextReceiptNo,
            posId: posId,
            userId: shift.userId,
            amount: Decimal.zero,
            time: 0,
            storeId: Value(thisPos.storeId),
            state: const Value(_stateInProgress),
            isWholesale: Value(isWholesale),
            weightProductRoundType: Value(weightRound),
            discountsRoundType: Value(discountRound),
            isOfd: const Value(false),
          ),
        );

    _logger.info(
      'SaleInitiation: created new sale '
      'receipt=$nextReceiptNo, pos=$posId, user=${shift.userId}',
    );

    return _db.saleDao.findInProgress();
  }
}
