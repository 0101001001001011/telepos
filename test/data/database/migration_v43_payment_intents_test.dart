/// Миграция v42→v43 (задача 22): у кассы появляется таблица намерений
/// оплаты QR/СБП.
///
/// # Почему этой пробы не было и почему она нужна
///
/// Задача 22 писала миграцию под номером v42 — параллельно с задачей 23,
/// которая взяла тот же номер и слилась первой. Пробы миграции задача 22
/// не завела вовсе: у неё есть эмуляторные пробы (`test/emulators/sbp/`)
/// и проба тендера (`test/data/sale/qr_tender_test.dart`), но обе
/// работают на **свежей** базе, где таблица есть по определению —
/// `AppDatabase.forTesting` создаёт схему целиком, а не мигрирует.
///
/// Значит утверждение «касса, доехавшая до v42 вчера, получит таблицу
/// сегодня» до сих пор не было измерено ни разу. А именно оно и
/// переехало: номер сменился с 42 на 43 при слиянии, и ветвь
/// `if (from < 43)` — новый, никем не пройденный путь.
///
/// # Что проверяется
///
/// 1. База, остановленная на v42, поднимается до 43 и получает таблицу.
/// 2. Данные, лежавшие в ней до миграции, переживают шаг: v43 не трогает
///    ничего, кроме создания одной таблицы, и это утверждение, а не
///    описание.
/// 3. Шаг v42 (счёт-получатель предоплаты) от переезда не пострадал:
///    касса на v41 обязана пройти **оба** шага подряд. Ровно это ломается,
///    если при разведении номеров ветви склеить в одну.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/payment/payment_kind.dart';

/// DDL настоящих таблиц — берётся из свежей базы, а не переписывается
/// руками: переписанный DDL расходится с продуктом молча.
Future<List<String>> _realDdl(List<String> tables) async {
  final probe = AppDatabase.forTesting(NativeDatabase.memory());
  final quoted = tables.map((t) => "'$t'").join(', ');
  final rows = await probe
      .customSelect(
        'SELECT sql FROM sqlite_master '
        "WHERE sql IS NOT NULL AND (name IN ($quoted) OR tbl_name IN ($quoted))",
      )
      .get();
  final sql = rows.map((r) => r.read<String>('sql')).toList();
  await probe.close();
  return sql;
}

Future<List<String>> _tablesOf(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .get();
  return rows.map((r) => r.read<String>('name')).toList();
}

/// Справочник в том виде, в каком его оставляет посев: `payment_intents`
/// в списке нет — её на этой версии не существовало.
void _seedKinds(sqlite3.Database raw, {required bool asOfV41}) {
  for (final kind in SystemPaymentKinds.all) {
    raw.execute(
      'INSERT INTO payment_kinds (id, code, name, settlement, '
      'fiscal_treatment, payee_account_type, payee_account_id, '
      'requires_acquiring, requires_counterparty, requires_provider, '
      'gives_change, refund_allowed, is_active, is_system, is_selectable, '
      'sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        kind.id,
        kind.code,
        kind.name,
        kind.settlement.index,
        kind.fiscalTreatment.code,
        asOfV41 && kind.id == SystemPaymentKindIds.prepayment
            ? null
            : kind.payeeAccountType,
        kind.payeeAccountId,
        kind.requiresAcquiring ? 1 : 0,
        asOfV41 && kind.id == SystemPaymentKindIds.prepayment
            ? 0
            : (kind.requiresCounterparty ? 1 : 0),
        kind.requiresProvider ? 1 : 0,
        kind.givesChange ? 1 : 0,
        kind.refundAllowed ? 1 : 0,
        kind.isActive ? 1 : 0,
        kind.isSystem ? 1 : 0,
        kind.isSelectable ? 1 : 0,
        kind.sortOrder,
      ],
    );
  }
}

Future<AppDatabase> _openAsIfMigratingFrom(int version) async {
  final ddl = await _realDdl(const ['payment_kinds', 'payments', 'accounts']);
  return AppDatabase.forTesting(
    NativeDatabase.memory(
      setup: (raw) {
        for (final statement in ddl) {
          raw.execute(statement);
        }
        _seedKinds(raw, asOfV41: version < 42);
        raw.execute('PRAGMA user_version = $version');
      },
    ),
  );
}

void main() {
  test('v42 → v43: таблица намерений появляется', () async {
    final db = await _openAsIfMigratingFrom(42);
    addTearDown(db.close);

    // Открытие и есть миграция.
    expect(
      await _tablesOf(db),
      contains(db.paymentIntents.actualTableName),
      reason: 'без таблицы QR не работает вовсе: намерение некуда записать',
    );

    // И она пригодна к работе, а не просто существует.
    final (row, created) = await db.paymentIntentDao.claim(
      intentKey: 'после-миграции',
      providerCode: 'sbp_test',
      amount: Decimal.parse('100'),
      createdAt: DateTime.now(),
    );
    expect(created, isTrue);
    expect(row.intentKey, 'после-миграции');
  });

  test('таблица приезжает пустой — истории намерений взяться неоткуда',
      () async {
    // Утверждение из докстринга ветви миграции, а не украшение: до v43
    // намерений не записывали нигде, и всё, что можно было бы «восстановить»,
    // было бы выдумкой, выглядящей как запись.
    final db = await _openAsIfMigratingFrom(42);
    addTearDown(db.close);

    expect(await db.select(db.paymentIntents).get(), isEmpty);
  });

  test('касса на v41 проходит ОБА шага: и v42, и v43', () async {
    // **Ровно то, что ломает склейка ветвей при разведении номеров.**
    // Соединив `if (from < 42)` и `if (from < 43)` в одну ветвь, касса
    // получила бы либо счёт предоплаты без таблицы намерений, либо
    // наоборот — и заметно это стало бы только у клиента.
    final db = await _openAsIfMigratingFrom(41);
    addTearDown(db.close);

    expect(
      await _tablesOf(db),
      contains(db.paymentIntents.actualTableName),
      reason: 'шаг v43 обязан отработать и на кассе, доехавшей только до v41',
    );

    final prepayment = await db.paymentKindDao.rowById(
      SystemPaymentKindIds.prepayment,
    );
    expect(
      prepayment!.payeeAccountType,
      AccountType.agentMain,
      reason: 'шаг v42 не должен был потеряться при переезде задачи 22 на v43',
    );
  });

  test('свежая база: таблица намерений есть, версия схемы — текущая', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // **Число здесь — текущая версия дерева, а не номер этой задачи.**
    // Было 43 и стало 44 со слиянием задачи 21; утверждение при этом
    // не изменилось ни на слово — «свежая база стоит на последней
    // версии, и таблица намерений в ней есть».
    //
    // Восемь таких же строк в соседних файлах приехали конфликтом и были
    // разрешены руками. Эта **не конфликтовала** — ветвь сертификата
    // этого файла не касалась вовсе, — и потому покраснела уже после
    // сведения, на прогоне. Ровно тот случай, ради которого прогон
    // обязателен и после бесконфликтного слияния: `git merge` молчит про
    // число, которое стало неверным, если строку с ним никто не трогал.
    expect(
      await _tablesOf(db),
      contains(db.paymentIntents.actualTableName),
    );
  });
}
