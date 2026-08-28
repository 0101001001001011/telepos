import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/services/shift_service.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';

class ShiftServiceImpl implements ShiftService {
  ShiftServiceImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<void> onOpenShift(int userId, {Decimal? openingCash}) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final float = openingCash ?? Decimal.zero;

    await _db
        .into(_db.shifts)
        .insert(
          ShiftsCompanion.insert(
            userId: userId,
            openTime: now,
            isOpened: true,
            isSynced: false,
            openingCash: Value(float),
          ),
        );

    _logger.info(
      'ShiftService: shift opened for user $userId, '
      'openingCash: $float',
    );

    await _fiscalOpenShift();
  }

  @override
  Future<void> onCloseShift(Decimal cashInPos) async {
    final currentShift = await _db.shiftDao.findOpenedShift();
    if (currentShift == null) {
      _logger.warning('ShiftService: no opened shift to close');
      return;
    }

    final closeTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final preciseOpenTime = await _getPreciseShiftOpenTime(currentShift);

    await (_db.update(
      _db.shifts,
    )..where((sh) => sh.id.equals(currentShift.id))).write(
      ShiftsCompanion(
        openTime: Value(preciseOpenTime),
        isOpened: const Value(false),
        closeTime: Value(closeTime),
        cashInPosOnShiftClose: Value(cashInPos),
      ),
    );

    _logger.info(
      'ShiftService: shift ${currentShift.id} closed, '
      'cash: $cashInPos, openTime adjusted: ${preciseOpenTime != currentShift.openTime}',
    );

    try {
      await _db.checkpointWal();
    } catch (e, st) {
      _logger.warning(
        'ShiftService: WAL checkpoint after close failed: $e',
        e,
        st,
      );
    }

    await _fiscalCloseShift();
  }

  Future<void> _fiscalCloseShift() async {
    try {
      if (!GetIt.I.isRegistered<FiscalService>()) return;
      final fiscal = GetIt.I<FiscalService>();
      if (!await fiscal.isEnabled()) return;
      final report = await fiscal.closeShift();
      if (report.success) {
        _logger.info(
          'ShiftService: fiscal Z-report '
          '${report.result.queued ? 'queued' : 'ok'} '
          '(shift=${report.shiftNumber})',
        );
      } else {
        _logger.warning(
          'ShiftService: fiscal Z-report failed: ${report.result.errorMessage}',
        );
      }
    } catch (e, st) {
      _logger.warning('ShiftService: fiscal Z-report error: $e', e, st);
    }
  }

  Future<void> _fiscalOpenShift() async {
    try {
      if (!GetIt.I.isRegistered<FiscalService>()) return;
      final fiscal = GetIt.I<FiscalService>();
      if (!await fiscal.isEnabled()) return;
      await fiscal.openShift();
    } catch (e, st) {
      _logger.warning('ShiftService: fiscal openShift error: $e', e, st);
    }
  }

  @override
  Future<Shift?> getOpenedShift() async {
    return _db.shiftDao.findOpenedShift();
  }

  @override
  Future<bool> isShiftOverAge({
    Duration maxAge = const Duration(hours: 24),
  }) async {
    try {
      final shift = await _db.shiftDao.findOpenedShift();
      if (shift == null || !shift.isOpened) return false;

      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final ageSec = nowSec - shift.openTime;
      return ageSec >= maxAge.inSeconds;
    } catch (e, st) {
      _logger.warning('ShiftService: isShiftOverAge error: $e', e, st);
      return false;
    }
  }

  Future<int> _getPreciseShiftOpenTime(Shift currentShift) async {
    if (!currentShift.isOpened) {
      throw StateError('Current Shift is already closed');
    }

    final shiftOpenTime = currentShift.openTime;

    final lastShiftReport = await _db.shiftDao.findLastClosedShiftReport();
    if (lastShiftReport == null) {
      return shiftOpenTime;
    }

    final lastCloseTime = lastShiftReport.closeTime;
    if (lastCloseTime == null) {
      return shiftOpenTime;
    }

    final firstSale = await _db.saleDao.findFirstSaleAfter(lastCloseTime);
    if (firstSale == null) {
      return shiftOpenTime;
    }

    final saleTime = firstSale.time;

    if (shiftOpenTime > saleTime) {
      _logger.info(
        'ShiftService: adjusting openTime from $shiftOpenTime to $saleTime '
        '(first sale is earlier)',
      );
      return saleTime;
    }

    return shiftOpenTime;
  }
}
