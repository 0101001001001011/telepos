import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/product/is_category_blocked_use_case.dart';
import 'package:telepos/domain/usecases/product/is_product_info_blocked_use_case.dart';

class IsProductInfoBlockedUseCaseImpl implements IsProductInfoBlockedUseCase {
  IsProductInfoBlockedUseCaseImpl({
    required AppDatabase db,
    required IsCategoryBlockedUseCase isCategoryBlockedUseCase,
    required Talker logger,
  }) : _db = db,
       _isCategoryBlockedUseCase = isCategoryBlockedUseCase,
       _logger = logger;

  final AppDatabase _db;
  final IsCategoryBlockedUseCase _isCategoryBlockedUseCase;
  final Talker _logger;

  @override
  Future<CategoryBlockResult> isBlocked(int ucode) async {
    return isBlockedAt(ucode, DateTime.now());
  }

  @override
  Future<CategoryBlockResult> isBlockedByBarcode(int barcode) async {
    final productInfo =
        await (_db.select(_db.productInfos)
              ..where((p) => p.barcode.equals(barcode))
              ..where((p) => p.isDeleted.equals(false))
              ..limit(1))
            .getSingleOrNull();

    if (productInfo == null) {
      _logger.warning(
        'IsProductInfoBlocked: product barcode=$barcode not found',
      );
      return CategoryBlockResult.allowed();
    }

    return isBlocked(productInfo.ucode);
  }

  @override
  Future<CategoryBlockResult> isBlockedAt(int ucode, DateTime checkTime) async {
    final productInfo = await _db.productInfoDao.findByIdAndNotDeleted(ucode);

    if (productInfo == null) {
      _logger.warning('IsProductInfoBlocked: product ucode=$ucode not found');
      return CategoryBlockResult.allowed();
    }

    final categoryId = productInfo.categoryId;
    if (categoryId == null) {
      return CategoryBlockResult.allowed();
    }

    return _isCategoryBlockedUseCase.isBlockedAt(categoryId, checkTime);
  }
}
