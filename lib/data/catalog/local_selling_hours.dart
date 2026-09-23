import 'package:drift/drift.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/catalog/selling_hours.dart';
import 'package:telepos/domain/catalog/selling_hours_repository.dart';

/// Часы запрета продажи в базе кассы.
///
/// # Что здесь было до 2026-09-22
///
/// Таблица `category_restrictions`, `CategoryRestrictionDao` и договор
/// `IsCategoryBlockedUseCase` существовали — и не звались ниоткуда. Запрет
/// был объявлен и не работал; заполнить его тоже было нечем, экрана не
/// существовало.
///
/// Внутри DAO пряталась вторая беда. `findActiveForCategory` выполняла
/// `customSelect` **с учётом родительской категории**, выбрасывала её
/// результат (`.then((_) => …)`) и возвращала другой запрос — без родителя.
/// То есть запрет на «Алкоголь» не дошёл бы до «Пива» внутри него, даже
/// если бы кто-нибудь этот код вызвал.
class LocalSellingHours implements SellingHoursRepository {
  LocalSellingHours(this._db);

  final AppDatabase _db;

  @override
  Future<List<SellingHoursRule>> all() async {
    final rows =
        await (_db.select(_db.categoryRestrictions)
              ..where((cr) => cr.isDeleted.equals(false))
              ..orderBy([(cr) => OrderingTerm.asc(cr.categoryId)]))
            .get();
    if (rows.isEmpty) return const [];

    final categories = await _db.select(_db.categories).get();
    final names = {for (final c in categories) c.id: c.name ?? ''};

    return rows
        .map(
          (r) => SellingHoursRule(
            id: r.id,
            categoryId: r.categoryId,
            categoryName: names[r.categoryId] ?? '',
            beginTime: r.beginTime ?? '',
            endTime: r.endTime ?? '',
            isActive: r.isActive,
          ),
        )
        .toList();
  }

  @override
  Future<List<SellingBan>> bansForCategory(int categoryId) async {
    // Цепочка «категория → родитель → его родитель». Не один шаг вверх:
    // дерево в продукте многоуровневое («Напитки → Алкоголь → Пиво»), и
    // запрет, поставленный на верхний узел, обязан доходить до листа.
    final ids = <int>{categoryId};
    var current = categoryId;
    // Предел на случай кольца в данных: дерево строит человек, и «родитель
    // самому себе» заводится одной опечаткой. Без предела касса зависла бы
    // на добавлении товара.
    for (var depth = 0; depth < 16; depth++) {
      final row =
          await (_db.select(_db.categories)
                ..where((c) => c.id.equals(current))
                ..limit(1))
              .getSingleOrNull();
      final parent = row?.parentId;
      if (parent == null || !ids.add(parent)) break;
      current = parent;
    }

    final rows =
        await (_db.select(_db.categoryRestrictions)..where(
              (cr) =>
                  cr.isActive.equals(true) &
                  cr.isDeleted.equals(false) &
                  cr.categoryId.isIn(ids),
            ))
            .get();

    // Непригодные записи отбрасываются молча ЗДЕСЬ, но не молча вообще:
    // экран настройки помечает такое окно и не даёт его сохранить.
    return rows
        .map((r) => SellingBan.parse(r.beginTime, r.endTime))
        .whereType<SellingBan>()
        .where((b) => !b.isEmpty)
        .toList();
  }

  @override
  Future<void> save(SellingHoursRule rule) async {
    final now = DateTime.now();
    if (rule.id == null) {
      final nextId = (await _db.categoryRestrictionDao.findLast())?.id ?? 0;
      await _db
          .into(_db.categoryRestrictions)
          .insert(
            CategoryRestrictionsCompanion.insert(
              id: Value(nextId + 1),
              categoryId: rule.categoryId,
              isActive: Value(rule.isActive),
              beginTime: Value(rule.beginTime),
              endTime: Value(rule.endTime),
              createTime: Value(now),
              editTime: now,
            ),
          );
      return;
    }
    await (_db.update(
      _db.categoryRestrictions,
    )..where((cr) => cr.id.equals(rule.id!))).write(
      CategoryRestrictionsCompanion(
        categoryId: Value(rule.categoryId),
        isActive: Value(rule.isActive),
        beginTime: Value(rule.beginTime),
        endTime: Value(rule.endTime),
        editTime: Value(now),
      ),
    );
  }

  @override
  Future<void> remove(int id) async {
    // Помечаем удалённым, а не стираем: обмен между кассами возит строки,
    // и исчезнувшая строка вернулась бы с соседней кассы живой.
    await (_db.update(
      _db.categoryRestrictions,
    )..where((cr) => cr.id.equals(id))).write(
      CategoryRestrictionsCompanion(
        isDeleted: const Value(true),
        editTime: Value(DateTime.now()),
      ),
    );
  }
}
