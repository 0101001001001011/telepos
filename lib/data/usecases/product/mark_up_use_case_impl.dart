import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/product/mark_up_use_case.dart';

class MarkUpUseCaseImpl implements MarkUpUseCase {
  MarkUpUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  static final _hundred = Decimal.fromInt(100);

  @override
  Future<Decimal?> getMarkUp(int categoryId) async {
    final markUp = await _db.markUpDao.findMarkUpFor(categoryId);
    if (markUp == null) {
      _logger.debug('MarkUp: no markup found for categoryId=$categoryId');
      return null;
    }

    return markUp.markup;
  }

  @override
  Future<Decimal?> getMarkUpForProduct(int ucode) async {
    final productInfo = await _db.productInfoDao.findByIdAndNotDeleted(ucode);
    if (productInfo == null) {
      _logger.warning('MarkUp: product ucode=$ucode not found');
      return null;
    }

    final categoryId = productInfo.categoryId;
    if (categoryId == null) {
      _logger.debug('MarkUp: product ucode=$ucode has no category');
      return null;
    }

    return getMarkUp(categoryId);
  }

  @override
  Decimal applyMarkUp(Decimal basePrice, Decimal markUpPercent) {
    final addition = (basePrice * markUpPercent / _hundred).toDecimal();
    return basePrice + addition;
  }
}
