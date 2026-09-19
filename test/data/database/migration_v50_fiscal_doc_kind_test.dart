/// Миграция v49→v50: род фискального документа и расширенный ключ строки.
///
/// # Что именно чинится, и чем это измерено
///
/// До v50 первичным ключом `webkassa_receipts` был **один** `operation_id`,
/// а класть в него ходили три разные последовательности: номер чека
/// продажи, `Refunds.localId` и `CashOperations.id` (аванс — с этой же
/// правки). На новой кассе все три начинаются с единицы, поэтому
/// столкновение — не редкость, а правило.
///
/// Замер 2026-09-19 на дереве до правки:
/// `UNIQUE constraint failed: webkassa_receipts.operation_id` на паре
/// «продажа №5 и возврат №5», и `FiscalServiceImpl._persistReceipt`
/// глотает это падение строкой журнала. То есть документ у оператора есть,
/// а местной записи о нём нет — **уже сегодня**, ещё до всякого аванса.
///
/// # Три проверки, и каждая отдельно нужна
///
///  1. **Фикстура v49 действительно столкновением болеет.** Без этого
///     проба «после миграции три строки уживаются» зелена и на базе,
///     которая и раньше их принимала, — то есть не доказывает ничего.
///  2. **Перенос выводит род из `is_sale`.** Строки, записанные до v50,
///     обязаны остаться собой: продажа продажей, возврат возвратом.
///     Умолчание `0` на всё подряд назвало бы старые возвраты продажами.
///  3. **Ключ после миграции — пара.** Проверяется **вставкой**, а не
///     разбором DDL: таблица с неправильным ключом при чтении выглядит
///     точно так же.
///
/// # Чего эта проба НЕ доказывает
///
/// Она не возвращает строки, потерянные столкновением до v50: документ
/// уехал оператору, локальной записи не осталось, и восстановить её не из
/// чего. Она также ничего не говорит о том, что род **проставляется**
/// верно при записи новых документов — это мерит
/// `prepayment_fiscal_receipt_test.dart`.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/fiscal/fiscal_doc_kind.dart';

/// Таблица **в том виде, в каком её оставила v49**.
///
/// Написана здесь дословно, потому что урезать нынешний DDL строковой
/// хирургией (вырезать колонку и переписать `PRIMARY KEY`) — это тот же
/// риск расхождения, только менее заметный. Расхождение ловит проверка
/// состава колонок ниже: фикстура обязана совпадать с нынешней таблицей
/// **ровно на одну колонку** `doc_kind`.
const _v49WebkassaReceipts = '''
CREATE TABLE webkassa_receipts (
  operation_id INTEGER NOT NULL,
  receipt_no INTEGER NULL,
  fiscal_no TEXT NULL,
  wk_receipt_no TEXT NULL,
  wk_time INTEGER NULL,
  wk_offline_mode INTEGER NULL,
  ticket_url TEXT NULL,
  is_sale INTEGER NULL,
  registration_number TEXT NULL,
  original_total TEXT NULL,
  PRIMARY KEY (operation_id)
)''';

void main() {
  Set<String> columnsOf(sqlite3.Database raw, String table) => raw
      .select('PRAGMA table_info($table)')
      .map((r) => r['name'] as String)
      .toSet();

  /// База в состоянии v49: нынешний DDL, но `webkassa_receipts` — старая.
  Future<(AppDatabase, sqlite3.Database)> openFromV49() async {
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
    final current = columnsOf(raw, 'webkassa_receipts');

    raw.execute('DROP TABLE webkassa_receipts');
    raw.execute(_v49WebkassaReceipts);
    raw.execute('PRAGMA user_version = 49');

    final fixture = columnsOf(raw, 'webkassa_receipts');
    expect(
      current.difference(fixture),
      {'doc_kind'},
      reason:
          'фикстура v49 разошлась с нынешней таблицей больше, чем на '
          'одну колонку рода — значит она проверяет вымышленную базу',
    );
    expect(
      fixture.difference(current),
      isEmpty,
      reason: 'в фикстуре есть колонка, которой нет в нынешней таблице',
    );

    return (AppDatabase.forTesting(NativeDatabase.opened(raw)), raw);
  }

  void insertRaw(
    sqlite3.Database raw, {
    required int operationId,
    required String fiscalNo,
    required bool isSale,
  }) {
    raw.execute(
      'INSERT INTO webkassa_receipts (operation_id, receipt_no, fiscal_no, '
      'is_sale) VALUES (?, ?, ?, ?)',
      [operationId, operationId, fiscalNo, isSale ? 1 : 0],
    );
  }

  test('фикстура v49 действительно не пускает второй документ с тем же '
      'номером — иначе мерить нечего', () async {
    final (db, raw) = await openFromV49();
    addTearDown(db.close);

    insertRaw(raw, operationId: 5, fiscalNo: 'ПРОДАЖА-5', isSale: true);

    // Тот самый замер, ради которого заведена v50. Если эта строка
    // перестанет краснеть — значит фикстура больше не воспроизводит
    // состояние v49, и все пробы ниже зелены ни о чём.
    expect(
      () =>
          insertRaw(raw, operationId: 5, fiscalNo: 'ВОЗВРАТ-5', isSale: false),
      throwsA(
        isA<sqlite3.SqliteException>().having(
          (e) => e.message,
          'message',
          contains('UNIQUE constraint failed'),
        ),
      ),
    );
  });

  test(
    'подъём с v49: род выведен из is_sale, и продажа осталась продажей',
    () async {
      final (db, raw) = await openFromV49();
      addTearDown(db.close);

      insertRaw(raw, operationId: 11, fiscalNo: 'ПРОДАЖА-11', isSale: true);
      insertRaw(raw, operationId: 12, fiscalNo: 'ВОЗВРАТ-12', isSale: false);

      // Открытие настоящей базы и есть миграция.
        final sale = await db.webkassaReceiptDao.findByKindAndOperationId(
        FiscalDocKind.sale,
        11,
      );
      final refund = await db.webkassaReceiptDao.findByKindAndOperationId(
        FiscalDocKind.refund,
        12,
      );

      expect(sale, isNotNull, reason: 'продажа v49 обязана остаться продажей');
      expect(sale!.fiscalNo, 'ПРОДАЖА-11');
      expect(sale.docKind, FiscalDocKind.sale.index);

      expect(
        refund,
        isNotNull,
        reason:
            'возврат v49, помеченный родом «продажа», означал бы, что '
            'возврат аванса нашёл бы его основанием',
      );
      expect(refund!.fiscalNo, 'ВОЗВРАТ-12');
      expect(refund.docKind, FiscalDocKind.refund.index);

      // Обратный полюс: продажи под номером возврата нет, и наоборот.
      expect(
        await db.webkassaReceiptDao.findByKindAndOperationId(
          FiscalDocKind.sale,
          12,
        ),
        isNull,
      );
    },
  );

  test('после миграции четыре рода с одним номером уживаются', () async {
    final (db, raw) = await openFromV49();
    addTearDown(db.close);

    insertRaw(raw, operationId: 5, fiscalNo: 'ПРОДАЖА-5', isSale: true);
    // Подъём — первое обращение к базе через drift.
    await db.webkassaReceiptDao.findByKindAndOperationId(FiscalDocKind.sale, 5);

    for (final kind in FiscalDocKind.values) {
      if (kind == FiscalDocKind.sale) continue;
      await db.webkassaReceiptDao.insertReceipt(
        WebkassaReceiptsCompanion.insert(
          operationId: 5,
          receiptNo: const Value(5),
          fiscalNo: Value('${kind.name}-5'),
          isSale: Value(kind.isSale),
          docKind: Value(kind.index),
        ),
      );
    }

    for (final kind in FiscalDocKind.values) {
      final row = await db.webkassaReceiptDao.findByKindAndOperationId(kind, 5);
      expect(
        row,
        isNotNull,
        reason:
            'документ рода ${kind.name} с номером 5 потерян — ровно та '
            'дыра, которую закрывает v50',
      );
      expect(row!.isSale, kind.isSale);
    }
  });

  test('свежая база: род есть, а ключ — пара', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.webkassaReceiptDao.insertReceipt(
      WebkassaReceiptsCompanion.insert(
        operationId: 1,
        fiscalNo: const Value('П-1'),
        isSale: const Value(true),
        docKind: Value(FiscalDocKind.sale.index),
      ),
    );
    await db.webkassaReceiptDao.insertReceipt(
      WebkassaReceiptsCompanion.insert(
        operationId: 1,
        fiscalNo: const Value('А-1'),
        isSale: const Value(true),
        docKind: Value(FiscalDocKind.prepayment.index),
      ),
    );

    expect(
      (await db.webkassaReceiptDao.findByKindAndOperationId(
        FiscalDocKind.prepayment,
        1,
      ))!.fiscalNo,
      'А-1',
      reason:
          'приём аванса №1 и продажа №1 — два документа, а не один; '
          'до v50 второй из них терялся молча',
    );

    // Тот же род с тем же номером дважды — по-прежнему невозможен: ключ
    // расширен, а не снят.
    await expectLater(
      db.webkassaReceiptDao.insertReceipt(
        WebkassaReceiptsCompanion.insert(
          operationId: 1,
          fiscalNo: const Value('П-1-второй'),
          isSale: const Value(true),
          docKind: Value(FiscalDocKind.sale.index),
        ),
      ),
      throwsA(anything),
    );
  });
}
