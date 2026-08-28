import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/product/is_category_blocked_use_case.dart';

class IsCategoryBlockedUseCaseImpl implements IsCategoryBlockedUseCase {
  IsCategoryBlockedUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<CategoryBlockResult> isBlocked(int categoryId) async {
    return isBlockedAt(categoryId, DateTime.now());
  }

  @override
  Future<CategoryBlockResult> isBlockedAt(
    int categoryId,
    DateTime checkTime,
  ) async {
    final restrictions = await _db.categoryRestrictionDao.findActiveForCategory(
      categoryId,
    );

    if (restrictions.isEmpty) {
      return CategoryBlockResult.allowed();
    }

    final restriction = restrictions.first;

    final beginTime = restriction.beginTime;
    final endTime = restriction.endTime;

    if (beginTime == null || endTime == null) {
      return CategoryBlockResult.allowed();
    }

    final beginMinutes = _parseTimeToMinutes(beginTime);
    final endMinutes = _parseTimeToMinutes(endTime);

    if (beginMinutes == null || endMinutes == null) {
      _logger.warning(
        'IsCategoryBlocked: invalid time format begin=$beginTime, end=$endTime',
      );
      return CategoryBlockResult.allowed();
    }

    final currentMinutes = checkTime.hour * 60 + checkTime.minute;

    final isInRange = _isTimeInRange(currentMinutes, beginMinutes, endMinutes);

    if (isInRange) {
      _logger.info(
        'IsCategoryBlocked: category $categoryId blocked at ${checkTime.hour}:${checkTime.minute} '
        '(range $beginTime-$endTime)',
      );
      return CategoryBlockResult.blocked(
        beginTime: beginTime,
        endTime: endTime,
      );
    }

    return CategoryBlockResult.allowed();
  }

  int? _parseTimeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return hour * 60 + minute;
  }

  bool _isTimeInRange(int current, int begin, int end) {
    if (begin <= end) {
      return current >= begin && current < end;
    } else {
      return current >= begin || current < end;
    }
  }
}
