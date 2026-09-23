/// Часы запрета в базе: родитель, несколько окон, выключенное окно.
///
/// # Главное, что здесь проверяется
///
/// Запрет, поставленный на «Алкоголь», обязан доходить до «Пива» внутри
/// него. Прежний DAO это и пытался сделать — и выбрасывал результат
/// собственного запроса, возвращая другой, без родителя. Проба ловит именно
/// это: дерево в два и в три уровня.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/data/catalog/local_selling_hours.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/catalog/selling_hours.dart';
import 'package:telepos/domain/catalog/selling_hours_repository.dart';

void main() {
  late AppDatabase db;
  late LocalSellingHours hours;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    hours = LocalSellingHours(db);
  });

  tearDown(() async => db.close());

  Future<void> category(int id, String name, {int? parent}) => db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          id: Value(id),
          name: Value(name),
          parentId: Value(parent),
          createTime: DateTime.now(),
        ),
      );

  DateTime at(int hour) => DateTime(2026, 9, 22, hour);

  test('запрет родителя доходит до ребёнка', () async {
    await category(1, 'Напитки');
    await category(2, 'Алкоголь', parent: 1);
    await hours.save(
      const SellingHoursRule(
        categoryId: 1,
        categoryName: 'Напитки',
        beginTime: '23:00',
        endTime: '08:00',
      ),
    );

    final own = await hours.bansForCategory(2);
    expect(own, hasLength(1), reason: 'запрет родителя потерян');
    expect(activeBan(own, at(2)), isNotNull);
    expect(activeBan(own, at(12)), isNull);
  });

  test('и до внука тоже — дерево бывает глубже одного шага', () async {
    await category(1, 'Напитки');
    await category(2, 'Алкоголь', parent: 1);
    await category(3, 'Пиво', parent: 2);
    await hours.save(
      const SellingHoursRule(
        categoryId: 1,
        categoryName: 'Напитки',
        beginTime: '23:00',
        endTime: '08:00',
      ),
    );

    expect(await hours.bansForCategory(3), hasLength(1));
  });

  test('кольцо в дереве не вешает кассу', () async {
    // Родитель самому себе заводится одной опечаткой в каталоге. Без
    // предела подъём по дереву крутился бы вечно — на добавлении товара.
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: const Value(7),
            name: const Value('Кольцо'),
            parentId: const Value(7),
            createTime: DateTime.now(),
          ),
        );
    await expectLater(hours.bansForCategory(7), completes);
  });

  test('выключенное окно хранится, но не запрещает', () async {
    await category(1, 'Алкоголь');
    await hours.save(
      const SellingHoursRule(
        categoryId: 1,
        categoryName: 'Алкоголь',
        beginTime: '23:00',
        endTime: '08:00',
        isActive: false,
      ),
    );

    expect(await hours.bansForCategory(1), isEmpty);
    expect(
      await hours.all(),
      hasLength(1),
      reason: 'выключенное окно обязано остаться — часы не переписывают',
    );
  });

  test('несколько окон у одной категории живут все', () async {
    await category(1, 'Алкоголь');
    await hours.save(
      const SellingHoursRule(
        categoryId: 1,
        categoryName: 'Алкоголь',
        beginTime: '23:00',
        endTime: '08:00',
      ),
    );
    await hours.save(
      const SellingHoursRule(
        categoryId: 1,
        categoryName: 'Алкоголь',
        beginTime: '13:00',
        endTime: '14:00',
      ),
    );

    final bans = await hours.bansForCategory(1);
    expect(bans, hasLength(2), reason: 'прежний код брал только первое окно');
    expect(activeBan(bans, at(13))!.label, '13:00–14:00');
  });

  test('непригодное окно до кассы не доезжает', () async {
    await category(1, 'Алкоголь');
    await hours.save(
      const SellingHoursRule(
        categoryId: 1,
        categoryName: 'Алкоголь',
        beginTime: 'ночью',
        endTime: '08:00',
      ),
    );
    expect(await hours.bansForCategory(1), isEmpty);
  });

  test('убранное окно перестаёт запрещать, но строка остаётся', () async {
    await category(1, 'Алкоголь');
    await hours.save(
      const SellingHoursRule(
        categoryId: 1,
        categoryName: 'Алкоголь',
        beginTime: '23:00',
        endTime: '08:00',
      ),
    );
    final saved = (await hours.all()).single;
    await hours.remove(saved.id!);

    expect(await hours.bansForCategory(1), isEmpty);
    // Стереть строку значило бы дать ей вернуться живой с соседней кассы
    // при обмене: удаление помечается, а не выполняется.
    final rows = await db.select(db.categoryRestrictions).get();
    expect(rows, hasLength(1));
    expect(rows.single.isDeleted, isTrue);
  });

  test('имя категории приезжает на экран вместе с окном', () async {
    await category(4, 'Алкоголь');
    await hours.save(
      const SellingHoursRule(
        categoryId: 4,
        categoryName: '',
        beginTime: '23:00',
        endTime: '08:00',
      ),
    );
    expect((await hours.all()).single.categoryName, 'Алкоголь');
  });
}
