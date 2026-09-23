import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/core/constants/enums/user_role.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/discount_tables.dart';
import 'package:telepos/data/discount/local_discount_policy.dart';
import 'package:telepos/domain/discount/discount_policy.dart';

/// Миграция v38→v39 (задача 12 плана «Полнота продажи»): у кассы
/// появляется объявленный предел ручной скидки.
///
/// # Главное утверждение здесь — «касса не ужесточилась»
///
/// Не «таблица появилась». Таблица, появившаяся со строгим умолчанием,
/// в день установки обновления остановила бы каждую скидку на каждой
/// кассе — то есть миграция сама стала бы отказом. Поэтому I165 звучит
/// «предела нет» не существует, существует **объявленное значение
/// `100 %`», и проверяется именно оно: после подъёма с v38 читатель
/// предела отдаёт сто процентов и «подтверждение не требуется».
///
/// # Почему фикстура строится сносом настоящей таблицы
///
/// Образец — `migration_v38_test.dart`: вид предыдущей версии получается
/// `DROP TABLE` над настоящей текущей схемой, а не переписыванием DDL
/// руками. Руками написанная фикстура расходится со схемой на первой же
/// правке и начинает проверять вымышленную базу.
AppDatabase _openAsIfMigratingFromV38({
  required void Function(sqlite3.Database raw) seed,
}) {
  return AppDatabase.forTesting(
    NativeDatabase.memory(
      setup: (raw) {
        raw.execute('PRAGMA user_version = 38');
        seed(raw);
      },
    ),
  );
}

Future<Set<String>> _tablesOf(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  test('свежая база: таблица есть с самого начала, версия схемы — текущая', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await _tablesOf(db), contains(db.discountLimits.actualTableName));
  });

  test('свежая установка тоже получает строку умолчания, а не пустую таблицу',
      () async {
    // Найдено пробой экрана, а не рассуждением: `onCreate` миграций не
    // исполняет, и первая редакция клала строку **только** на пути подъёма.
    // Касса вела бы себя верно (читатель отдаёт сто процентов и не найдя
    // строки), а экран пределов показывал бы пустое поле — то есть I165
    // («существует объявленное значение») держался бы только у
    // мигрировавших баз.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final rows = await db.select(db.discountLimits).get();
    expect(rows.map((r) => r.role), [DiscountLimitRoles.anyRole]);
    expect(rows.single.maxPercentPerLine, Decimal.fromInt(100));
    expect(rows.single.approvalAbovePercent, isNull);
  });

  test('умолчание миграции v39 не ужесточает кассу', () async {
    // База, поднятая с v38: строки предела в ней нет и быть не может —
    // таблицы вчера не существовало. Значит читателю предела приходится
    // отвечать на вопрос «что разрешено» **до** того, как кто-либо что-то
    // настроил, и ответ обязан быть «как вчера».
    final db = _openAsIfMigratingFromV38(seed: (raw) {});
    addTearDown(db.close);

    final policy = LocalDiscountPolicy(db);
    final cap = await policy.capFor(UserRole.cashier.index);

    expect(
      cap.maxPercent,
      Decimal.fromInt(100),
      reason: 'миграция кладёт одну строку role = -1 со стом процентов',
    );
    expect(cap.approvalAbove, isNull);

    // И это не «читатель выдумал сто, не найдя строки»: строка есть в базе.
    final rows = await db.select(db.discountLimits).get();
    expect(rows.map((r) => r.role), [
      DiscountLimitRoles.anyRole,
    ], reason: 'ровно одна строка умолчания, а не ни одной и не четыре');
    expect(rows.single.maxPercentPerLine, Decimal.fromInt(100));
    expect(rows.single.approvalAbovePercent, isNull);
  });

  test(
    'предел роли перекрывает умолчание, а незаданная роль его наследует',
    () async {
      final db = _openAsIfMigratingFromV38(seed: (raw) {});
      addTearDown(db.close);

      await db
          .into(db.discountLimits)
          .insert(
            DiscountLimitsCompanion.insert(
              role: Value(UserRole.cashier.index),
              maxPercentPerLine: Value(Decimal.fromInt(20)),
            ),
          );

      final policy = LocalDiscountPolicy(db);

      final cashier = await policy.capFor(UserRole.cashier.index);
      expect(cashier.maxPercent, Decimal.fromInt(20));
      expect(
        cashier.source,
        contains('cashier'),
        reason:
            'отказ обязан назвать, ЧЕЙ это предел. Ключ, а не слово '
            '«Кассир»: строка уходит вторым доводом `WireRefusal` (его '
            'читает журнал, на экран едет код) и в столбец аудита '
            '`DiscountAudits.capSource`. Запись аудита не имеет права '
            'зависеть от языка кассы — иначе одно и то же событие на двух '
            'кассах записалось бы разными словами',
      );

      final owner = await policy.capFor(UserRole.owner.index);
      expect(
        owner.maxPercent,
        Decimal.fromInt(100),
        reason: 'у владельца своей строки нет — действует умолчание',
      );
    },
  );

  test(
    'повторная миграция на уже заведённой таблице не удваивает умолчание',
    () async {
      // Установка, прошедшая v39 и открытая заново (или откатившаяся к
      // прежней сборке и поднятая снова), придёт сюда второй раз. Вторая
      // строка `role = -1` сделала бы ответ предела зависящим от порядка
      // выборки.
      final probe = AppDatabase.forTesting(NativeDatabase.memory());
      final sql =
          (await probe
                  .customSelect(
                    "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
                    variables: [
                      Variable.withString(probe.discountLimits.actualTableName),
                    ],
                  )
                  .getSingle())
              .read<String>('sql');
      await probe.close();

      final db = _openAsIfMigratingFromV38(
        seed: (raw) {
          raw.execute(sql);
          raw.execute(
            'INSERT INTO discount_limits (role, max_percent_per_line) '
            'VALUES (?, ?)',
            [DiscountLimitRoles.anyRole, 100.0],
          );
        },
      );
      addTearDown(db.close);

      final rows = await db.select(db.discountLimits).get();
      expect(rows, hasLength(1));
    },
  );
}
