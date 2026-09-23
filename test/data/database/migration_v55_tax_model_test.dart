/// Миграция v55: ставка перестаёт быть числом у товара.
///
/// # Зачем
///
/// v54, выпущенная в тот же день, прикрепляла к товару процент, а юрисдикции
/// держала плоским списком. Разбор мировой практики
/// (`docs/internal/research/2026-09-21-tax-configuration-models.md`) показал,
/// что так не устроено нигде: ставку выводят из юрисдикции, КАТЕГОРИИ товара
/// и даты.
///
/// # Что здесь главное
///
/// Не то, что таблицы появились, — это видно чтением DDL. Главное, что
/// **ставки, уже заданные на работающей кассе, остаются теми же числами**.
/// Касса, которую никто не перенастраивал, обязана после обновления печатать
/// ровно тот же налог; заметил бы разницу покупатель, а не мы.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/data/database/app_database.dart';

void main() {
  /// База в состоянии v54, поверх которой открывается настоящая.
  ///
  /// Схема берётся из НАСТОЯЩЕГО DDL текущей версии и приводится к v54, а не
  /// пишется руками: фикстура, разошедшаяся со схемой, проверяла бы
  /// вымышленную базу.
  Future<AppDatabase> openFromV54({
    void Function(sqlite3.Database raw)? seed,
  }) async {
    final probe = AppDatabase.forTesting(NativeDatabase.memory());
    final ddl =
        (await probe
                .customSelect(
                  'SELECT sql FROM sqlite_master '
                  "WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%'",
                )
                .get())
            .map((r) => r.read<String>('sql'))
            .toList();
    await probe.close();

    final raw = sqlite3.sqlite3.openInMemory();
    for (final statement in ddl) {
      raw.execute(statement);
    }

    // Откатываем всё, что заводит v55, и возвращаем то, что было в v54, —
    // иначе проба зеленела бы и без миграции.
    raw.execute('DROP TABLE IF EXISTS tax_categories');
    raw.execute('DROP TABLE IF EXISTS tax_rules');
    raw.execute('ALTER TABLE tax_jurisdictions DROP COLUMN parent_id');
    raw.execute('ALTER TABLE tax_jurisdictions DROP COLUMN level');
    raw.execute('ALTER TABLE tax_jurisdictions DROP COLUMN is_till_location');
    raw.execute('ALTER TABLE product_infos DROP COLUMN tax_category_id');
    raw.execute('ALTER TABLE product_infos ADD COLUMN tax_rate_percent REAL');
    raw.execute(
      'ALTER TABLE product_infos ADD COLUMN is_tax_exempt '
      'INTEGER NOT NULL DEFAULT 0',
    );
    raw.execute(
      'ALTER TABLE this_pos_entries ADD COLUMN tax_rate_percent REAL',
    );
    raw.execute('PRAGMA user_version = 54');

    expect(
      raw.select("SELECT name FROM sqlite_master WHERE name = 'tax_rules'"),
      isEmpty,
      reason: 'фикстура уже содержит таблицы v55 — мерить нечего',
    );

    seed?.call(raw);
    return AppDatabase.forTesting(NativeDatabase.opened(raw));
  }

  /// `barcode`, `type` и `measure` обязательны — на этом уже спотыкались.
  String insertProduct(
    int ucode,
    String name, {
    String? rate,
    bool exempt = false,
  }) =>
      'INSERT INTO product_infos '
      '(ucode, barcode, name, type, measure, tax_rate_percent, is_tax_exempt) '
      "VALUES ($ucode, 460700$ucode, '$name', 0, 0, ${rate ?? 'NULL'}, "
      '${exempt ? 1 : 0})';

  test('свежая база: категории и правила есть, обе пусты', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await db.select(db.taxCategories).get(), isEmpty);
    expect(await db.select(db.taxRules).get(), isEmpty);
  });

  test('ставка кассы становится правилом корневой юрисдикции', () async {
    final db = await openFromV54(
      seed: (raw) => raw.execute(
        'INSERT INTO this_pos_entries (r_id, company_name, tax_rate_percent) '
        "VALUES (1, 'Northwind', 12.0)",
      ),
    );
    addTearDown(db.close);

    final rules = await db
        .customSelect(
          'SELECT rate_percent, category_id, kind FROM tax_rules '
          'WHERE category_id IS NULL',
        )
        .get();

    expect(rules, hasLength(1));
    expect(
      rules.first.read<double>('rate_percent'),
      12.0,
      reason:
          'ставка потеряна при обновлении: касса, которую не трогали, '
          'начала бы печатать другой налог',
    );

    final root = await db.select(db.taxJurisdictions).getSingle();
    expect(
      root.isTillLocation,
      isTrue,
      reason:
          'юрисдикция, в которой касса не стоит, в расчёт не попадает — '
          'ставка была бы заведена и не применялась',
    );
  });

  test('плоский список v54 целиком становится местом кассы', () async {
    final db = await openFromV54(
      seed: (raw) {
        raw.execute(
          'INSERT INTO this_pos_entries (r_id, company_name, tax_rate_percent) '
          "VALUES (1, 'Northwind', 9.15)",
        );
        raw.execute(
          'INSERT INTO tax_jurisdictions (name, sort_order, is_active) '
          "VALUES ('CO State', 0, 1)",
        );
        raw.execute(
          'INSERT INTO tax_jurisdictions (name, sort_order, is_active) '
          "VALUES ('Denver', 1, 1)",
        );
      },
    );
    addTearDown(db.close);

    final all = await db.select(db.taxJurisdictions).get();
    expect(all, hasLength(2));
    expect(
      all.every((j) => j.isTillLocation),
      isTrue,
      reason:
          'до v55 все доли плоского списка складывались безусловно; '
          'не отметить их значит недобрать налог',
    );
    expect(
      all.every((j) => j.parentId == null),
      isTrue,
      reason: 'плоский список состоял только из корней — иерархии в нём не было',
    );
  });

  test('освобождённый товар попадает в отдельную категорию', () async {
    final db = await openFromV54(
      seed: (raw) {
        raw.execute(
          'INSERT INTO this_pos_entries (r_id, company_name, tax_rate_percent) '
          "VALUES (1, 'Northwind', 8.25)",
        );
        raw.execute(insertProduct(1001, 'Milk', exempt: true));
        raw.execute(insertProduct(1002, 'Coffee'));
      },
    );
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          'SELECT p.ucode, c.code, r.kind FROM product_infos p '
          'JOIN tax_categories c ON c.id = p.tax_category_id '
          'LEFT JOIN tax_rules r ON r.category_id = c.id '
          'ORDER BY p.ucode',
        )
        .get();

    expect(rows.first.read<String>('code'), 'exempt');
    expect(
      rows.first.read<int?>('kind'),
      2,
      reason:
          'освобождение обязано остаться освобождением, а не стать нулевой '
          'ставкой: это разные режимы, и отчётность по ним разная',
    );
    expect(
      rows.last.read<String>('code'),
      'standard',
      reason: 'товар без своей ставки — в категории по умолчанию',
    );
  });

  test('отличная ставка товара становится своей категорией', () async {
    final db = await openFromV54(
      seed: (raw) {
        raw.execute(
          'INSERT INTO this_pos_entries (r_id, company_name, tax_rate_percent) '
          "VALUES (1, 'Northwind', 12.0)",
        );
        raw.execute(insertProduct(1001, 'Bread', rate: '0.0'));
        raw.execute(insertProduct(1002, 'Pills', rate: '0.0'));
        raw.execute(insertProduct(1003, 'Coffee', rate: '12.0'));
      },
    );
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          'SELECT p.ucode, c.code, r.rate_percent FROM product_infos p '
          'JOIN tax_categories c ON c.id = p.tax_category_id '
          'LEFT JOIN tax_rules r ON r.category_id = c.id '
          'ORDER BY p.ucode',
        )
        .get();

    expect(
      rows[0].read<String>('code'),
      rows[1].read<String>('code'),
      reason:
          'две одинаковые ставки обязаны дать ОДНУ категорию: иначе каталог '
          'из тысячи товаров даст тысячу категорий',
    );
    expect(
      rows[0].read<double?>('rate_percent'),
      0.0,
      reason: 'ставка товара потеряна при обновлении',
    );
    expect(
      rows[2].read<String>('code'),
      'standard',
      reason:
          'товар со ставкой, равной кассовой, отдельной категории не '
          'заслуживает — она повторяла бы правило без категории',
    );
  });

  test('старые колонки убраны: двух источников правды о ставке нет', () async {
    final db = await openFromV54(
      seed: (raw) => raw.execute(
        'INSERT INTO this_pos_entries (r_id, company_name, tax_rate_percent) '
        "VALUES (1, 'Northwind', 12.0)",
      ),
    );
    addTearDown(db.close);

    Future<List<String>> columns(String table) async =>
        (await db.customSelect('PRAGMA table_info($table)').get())
            .map((r) => r.read<String>('name'))
            .toList();

    expect(await columns('product_infos'), isNot(contains('tax_rate_percent')));
    expect(await columns('product_infos'), isNot(contains('is_tax_exempt')));
    expect(
      await columns('this_pos_entries'),
      isNot(contains('tax_rate_percent')),
      reason:
          'два места, говорящих о налоге, однажды разойдутся, и узнает об '
          'этом покупатель',
    );
  });

  test('правила пишутся и читаются с датой', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final jurisdiction = await db
        .into(db.taxJurisdictions)
        .insert(TaxJurisdictionsCompanion.insert(name: 'Denver'));

    await db
        .into(db.taxRules)
        .insert(
          TaxRulesCompanion.insert(
            jurisdictionId: jurisdiction,
            ratePercent: Decimal.parse('5.15'),
            validFrom: DateTime.utc(2026, 7),
          ),
        );

    final saved = await db.select(db.taxRules).getSingle();
    expect(
      saved.ratePercent,
      Decimal.parse('5.15'),
      reason: 'дробная доля обязана храниться без усечения',
    );
    expect(saved.validTo, isNull, reason: 'null — бессрочно');
  });
}
