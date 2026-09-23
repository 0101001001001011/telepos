import 'package:telepos/domain/catalog/selling_hours.dart';

/// Часы запрета продажи, как их видит касса.
///
/// # Почему договор, а не прямое чтение таблицы
///
/// Запрет проверяется на пути продажи, а продажа бывает и браузерной. У
/// вкладки нет ни базы, ни `drift`; спросить она может только кассу. Тот же
/// приём, что у налоговых настроек и у отложенных чеков.
abstract interface class SellingHoursRepository {
  /// Все окна запрета — для экрана настройки.
  Future<List<SellingHoursRule>> all();

  /// Окна, действующие для категории СЕЙЧАС, вместе с родительскими.
  ///
  /// Родитель обязателен: запрет на «Алкоголь» бессмыслен, если «Пиво»
  /// внутри него продаётся. Прежняя реализация родителя запрашивала и
  /// результат запроса выбрасывала.
  Future<List<SellingBan>> bansForCategory(int categoryId);

  /// Завести или изменить окно.
  Future<void> save(SellingHoursRule rule);

  /// Убрать окно.
  Future<void> remove(int id);
}

/// Окно запрета вместе с тем, к чему оно привязано.
class SellingHoursRule {
  const SellingHoursRule({
    this.id,
    required this.categoryId,
    required this.categoryName,
    required this.beginTime,
    required this.endTime,
    this.isActive = true,
  });

  /// `null` — окно ещё не заведено.
  final int? id;

  final int categoryId;

  /// Имя категории — для экрана; пусто, если категорию переименовали в
  /// ничто.
  final String categoryName;

  /// Начало и конец запрета записью `ЧЧ:ММ`.
  final String beginTime;
  final String endTime;

  /// Выключенное окно хранится, но не запрещает.
  ///
  /// Владельцу нужно снять запрет на день — например, в праздник, когда
  /// закон его снимает. Удалять и заводить заново значило бы терять часы.
  final bool isActive;

  SellingBan? get ban => SellingBan.parse(beginTime, endTime);

  /// Пригодно ли окно к работе: разбирается и не пусто.
  bool get isUsable {
    final parsed = ban;
    return parsed != null && !parsed.isEmpty;
  }

  SellingHoursRule copyWith({
    int? id,
    int? categoryId,
    String? categoryName,
    String? beginTime,
    String? endTime,
    bool? isActive,
  }) => SellingHoursRule(
    id: id ?? this.id,
    categoryId: categoryId ?? this.categoryId,
    categoryName: categoryName ?? this.categoryName,
    beginTime: beginTime ?? this.beginTime,
    endTime: endTime ?? this.endTime,
    isActive: isActive ?? this.isActive,
  );
}
