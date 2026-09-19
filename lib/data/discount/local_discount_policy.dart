import 'package:decimal/decimal.dart';
import 'package:telepos/core/constants/enums/user_role.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/discount_tables.dart';
import 'package:telepos/domain/discount/discount_policy.dart';

/// Кассовый читатель пределов скидки — задача 12.
///
/// # Правило разрешения объявлено здесь и только здесь
///
/// Строка роли перекрывает строку умолчания; своей строки нет — действует
/// умолчание; нет и умолчания — сто процентов, «как вчера». Третий случай не
/// должен наступать никогда (миграция v39 кладёт строку умолчания), и именно
/// поэтому он назван значением, а не исключением: касса, у которой строку
/// умолчания снесли руками, обязана продолжать продавать, а не встать.
class LocalDiscountPolicy implements DiscountPolicy {
  LocalDiscountPolicy(this._db);

  final AppDatabase _db;

  static final _hundred = Decimal.fromInt(100);

  @override
  Future<DiscountCap> capFor(int roleIndex) async {
    final rows =
        await (_db.select(_db.discountLimits)..where(
              (t) => t.role.isIn([roleIndex, DiscountLimitRoles.anyRole]),
            ))
            .get();

    final own = rows.where((r) => r.role == roleIndex).firstOrNull;
    final fallback = rows
        .where((r) => r.role == DiscountLimitRoles.anyRole)
        .firstOrNull;
    final row = own ?? fallback;

    if (row == null) {
      return DiscountCap(
        maxPercent: _hundred,
        approvalAbove: null,
        source: 'предел не настроен',
      );
    }

    return DiscountCap(
      maxPercent: row.maxPercentPerLine,
      approvalAbove: row.approvalAbovePercent,
      source: row.role == DiscountLimitRoles.anyRole
          ? 'предел кассы по умолчанию'
          : 'предел роли «${_roleName(row.role)}»',
    );
  }

  static String _roleName(int index) =>
      index >= 0 && index < UserRole.values.length
      ? UserRole.values[index].displayName
      : 'роль #$index';
}
