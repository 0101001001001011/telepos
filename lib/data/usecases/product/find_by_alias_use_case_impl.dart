import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/product/find_by_alias_use_case.dart';

class FindByAliasUseCaseImpl implements FindByAliasUseCase {
  FindByAliasUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<int?> find(String alias) async {
    final productAlias = await _db.productAliasDao.findProductByAlias(alias);

    if (productAlias != null) {
      _logger.info(
        'FindByAlias: found ucode=${productAlias.productUcode} for alias=$alias',
      );
      return productAlias.productUcode;
    }

    _logger.info('FindByAlias: not found for alias=$alias');
    return null;
  }

  @override
  Future<List<int>> findByPart(String aliasPart) async {
    final ucodes = await _db.productAliasDao.findActiveProductIdsByAliasPart(
      aliasPart,
    );

    _logger.info(
      'FindByAlias: found ${ucodes.length} products for aliasPart=$aliasPart',
    );
    return ucodes;
  }
}
