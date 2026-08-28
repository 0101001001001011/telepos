import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/product/kassa_price_decreasing_blocked_use_case.dart';

class KassaPriceDecreasingBlockedUseCaseImpl
    implements KassaPriceDecreasingBlockedUseCase {
  KassaPriceDecreasingBlockedUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<bool> isBlocked() async {
    final thisPos = await _db.thisPosDao.get();
    if (thisPos == null) {
      _logger.warning(
        'KassaPriceDecreasingBlocked: ThisPos config not found, allowing price changes',
      );
      return false;
    }

    return thisPos.isKassaPriceDecreasingBlocked;
  }

  @override
  Future<PriceChangeValidation> validatePriceChange({
    required int ucode,
    required Decimal newPrice,
  }) async {
    final blocked = await isBlocked();
    if (!blocked) {
      return PriceChangeValidation.allowed();
    }

    final productPrice = await _db.productPriceDao.findByUcode(ucode);
    if (productPrice == null) {
      _logger.warning(
        'KassaPriceDecreasingBlocked: Product ucode=$ucode price not found',
      );
      return PriceChangeValidation.productNotFound(ucode);
    }

    final currentPrice = productPrice.sellingPrice ?? Decimal.zero;

    if (newPrice < currentPrice) {
      _logger.info(
        'KassaPriceDecreasingBlocked: blocked price decrease for ucode=$ucode, '
        'current=$currentPrice, new=$newPrice',
      );
      return PriceChangeValidation.blocked(
        currentPrice: currentPrice,
        newPrice: newPrice,
      );
    }

    return PriceChangeValidation.allowed();
  }
}
