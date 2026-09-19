/// Сколько идёт обновление установленной кассы — замер, а не оценка.
///
/// # Зачем эта проба вообще существует
///
/// Обновление установленной кассы — **единственная необратимая операция
/// продукта**: база одна, отката нет, и пока миграция идёт, касса не
/// торгует. Вилка версий в поставке — v28…v51 (v28 — самая старая, которую
/// набор ещё поднимает, см. `print_job_store_test.dart`; v39 — первая
/// версия линии «полнота продажи»). Времени этой операции **не мерил никто
/// ни разу**, то есть в инструкции по обновлению стояло бы «подождите» без
/// числа, а кассир, увидевший чёрный экран на третьей минуте, выдернет
/// питание — и получит ровно ту половину миграции, которой не бывает.
///
/// Двадцать три пробы миграций рядом мерят **правильность** каждого шага на
/// двух-трёх строках. Ни одна не мерит **цену** шага на объёме: они все
/// поднимают почти пустую базу, где любой `ALTER TABLE` бесплатен по
/// построению. Эта проба — про цену.
///
/// # Откуда взяты объёмы, и почему именно такие
///
/// Живой базы у нас нет (единственная касса, дошедшая до боя, — стенд с
/// десятком чеков). Объём собран из смысла работы магазина, а не выдуман:
///
/// * **[_kSales] = 30 000 чеков.** Магазин у дороги — 100 чеков в смену,
///   300 смен в году. Кассу обновляют не чаще раза в год, значит год
///   истории — нижняя граница того, что застанет миграция; берём ровно
///   год, чтобы число было воспроизводимым, а не «на глаз побольше».
/// * **[_kSaleLines] = 105 000 строк** — 3,5 позиции в чеке. Средний чек
///   продуктового у дороги: хлеб, вода, сигареты, пакет.
/// * **[_kPayments] = 36 000 строк оплаты** — 1,2 строки на чек: каждый
///   пятый чек смешанной оплатой (часть картой, часть наличными). Это
///   **самая дорогая таблица миграции**: v41 перестраивает её целиком.
/// * **[_kRefunds] = 600 возвратов** — 2 % чеков. Больше двух процентов
///   возвратов — это уже не магазин, а разбирательство.
/// * **[_kBonusAccounts] = 5 000 бонусных счетов** — покупателей с картой
///   лояльности у такого магазина единицы тысяч. Число значимо: v40
///   заводит **по строке журнала на каждый ненулевой счёт**, и делает это
///   по одной вставке за оборот.
/// * **[_kFiscalQueue] = 2 000 строк очереди фискализации** — двое суток
///   работы без связи с оператором (72-часовое окно КГД, из которого касса
///   обычно выбирается на вторые сутки).
/// * **[_kFiscalDocs] = 30 600 фискальных документов** — по документу на
///   каждый чек и каждый возврат. Вторая по цене таблица: v50 меняет ей
///   первичный ключ, то есть переписывает целиком.
/// * **[_kCashOps] = 3 000 кассовых операций** — десяток внесений и изъятий
///   в смену.
/// * **[_kCertificates] = 2 000 сертификатов** — подарочные карты сети к
///   Новому году; существуют только с v44, поэтому в фикстуры v28 и v39
///   не попадают вовсе (их там **неоткуда** взять — таблицы нет).
///
/// # Как построена фикстура, и почему именно так
///
/// Схема снимается **с настоящего DDL текущей версии** и урезается назад до
/// нужной — тот же приём, что у `migration_v44_certificates_test` и
/// соседей, и по той же причине: рукописный DDL старой версии расходится с
/// настоящим молча, и проба тогда мерит выдуманную базу.
///
/// **Чего урезание НЕ делает — названо вслух.** Колонки `payments.seq`,
/// `payments.kind_id` и соседи в фикстуре **остаются**: `seq` входит в
/// уникальный ключ, и `ALTER TABLE DROP COLUMN` на нём отказывает по
/// устройству sqlite. Значит из цены v41 здесь не измерена ровно одна
/// часть — пять `ALTER TABLE ADD COLUMN`. В sqlite добавление колонки со
/// значением по умолчанию — правка заголовка таблицы, O(1), не зависящая
/// от числа строк; дорогая половина шага (три `UPDATE` по всей таблице и
/// пересборка `TableMigration`) измерена целиком.
///
/// # WAL: почему копия делается именно так
///
/// Правило дерева: всякий код, копирующий базу drift, обязан сначала
/// сделать checkpoint WAL и убрать `-wal`/`-shm`. Здесь оно исполняется в
/// [_sealAndCheckpoint]: заполненная база закрывается, её журнал
/// сворачивается `wal_checkpoint(TRUNCATE)`, спутники удаляются — и только
/// после этого файл копируется под каждую точку старта. Проба, нарушившая
/// это, скопировала бы базу без последних вставок и мерила бы миграцию
/// пустой таблицы, показав прекрасное время ни о чём.
///
/// # Что именно утверждает проба (а не только печатает)
///
/// Печатаемое время — замер, и он живёт в `docs/internal/testing-notes.md`
/// вместе с машиной и датой. Красным проба становится по трём утверждениям:
///
/// 1. **до подъёма фикстура действительно старая** — таблиц, которые
///    заводит миграция, в ней нет (иначе мерить было бы нечего, и проба
///    зеленела бы, ничего не мигрируя);
/// 2. **после подъёма версия равна текущей, а `PRAGMA integrity_check`
///    отвечает `ok`** — это и есть требование «проверка целостности
///    проходит после каждой»;
/// 3. **данные пережили перестройку** — число строк в `payments` и
///    `webkassa_receipts` после пересборки равно засеянному, а бонусный
///    журнал получил ровно столько строк, сколько было ненулевых счетов.
///
/// Диверсия, которой проба показанно краснеет: поставить фикстуре
/// `PRAGMA user_version = 51` — миграция не запускается, и утверждение 1
/// падает первым же случаем.
///
/// # Почему проба не сторожит время числом
///
/// Потолка в секундах здесь нет намеренно. Он мерил бы загрузку машины, а
/// не код: на этом дереве уже измерено, что соседняя сборка роняет набор
/// таймаутами. Число живёт в записи замера с названной машиной и датой —
/// там его можно сравнить осмысленно.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/fiscal/bonus_account_types.dart';

/// Чеков за год работы магазина у дороги: 100 в смену × 300 смен.
const int _kSales = 30000;

/// Строк в чеках: 3,5 позиции на чек.
const int _kSaleLines = 105000;

/// Строк оплаты: 1,2 на чек — каждый пятый чек смешанный.
const int _kPayments = 36000;

/// Возвратов: 2 % чеков.
const int _kRefunds = 600;

/// Бонусных счетов (род 4 и 7) с ненулевым остатком.
const int _kBonusAccounts = 5000;

/// Строк очереди фискализации: двое суток без связи с оператором.
const int _kFiscalQueue = 2000;

/// Фискальных документов: по одному на чек и на возврат.
const int _kFiscalDocs = _kSales + _kRefunds;

/// Кассовых операций: десяток внесений и изъятий в смену.
const int _kCashOps = 3000;

/// Подарочных сертификатов. Существуют только с v44.
const int _kCertificates = 2000;

/// Пользователей кассы. Число маленькое намеренно: у магазина их столько
/// и есть, а два шага миграции (v33 и v45) ходят по ним вложенным циклом
/// «пользователь × право», и раздувать его значило бы мерить выдумку.
const int _kUsers = 12;

void main() {
  late Directory work;

  setUpAll(() {
    work = Directory.systemTemp.createTempSync('telepos-migration-volume');
  });

  tearDownAll(() {
    try {
      work.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows иногда держит файл ещё мгновение после закрытия. Мусор в
      // системном temp дешевле падения проходящей пробы.
    }
  });

  /// DDL текущей версии — снимается с настоящей базы, а не пишется руками.
  Future<List<String>> currentDdl() async {
    final probe = AppDatabase.forTesting(NativeDatabase.memory());
    final rows = await probe
        .customSelect(
          'SELECT sql FROM sqlite_master '
          "WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    final ddl = rows.map((r) => r.read<String>('sql')).toList();
    await probe.close();
    return ddl;
  }

  /// Заполненная база текущей формы: один файл, из которого потом растут
  /// все точки старта.
  ///
  /// Вставка идёт подготовленными выражениями в **одной** транзакции: сто
  /// с лишним тысяч строк по одной команде заняли бы больше, чем сама
  /// миграция, и замер утонул бы в подготовке.
  Future<File> buildSeededFile(List<String> ddl) async {
    final file = File('${work.path}${Platform.pathSeparator}seed.sqlite');
    if (file.existsSync()) file.deleteSync();
    final raw = sqlite3.sqlite3.open(file.path);
    for (final statement in ddl) {
      raw.execute(statement);
    }
    raw.execute('BEGIN');

    final insertUser = raw.prepare(
      'INSERT INTO users (id, name, role) VALUES (?, ?, ?)',
    );
    for (var i = 1; i <= _kUsers; i++) {
      // Роль 1 — кассир: владельцу (роль 0) права не выдаются, и цикл
      // v33/v45 его пропускает.
      insertUser.execute([i, 'Кассир $i', 1]);
    }
    insertUser.dispose();

    raw.execute(
      'INSERT INTO terminals (id, name, is_self, created_at) '
      'VALUES (1, ?, 1, 1700000000)',
      ['Касса'],
    );
    raw.execute('INSERT INTO this_pos_entries (id) VALUES (1)');

    // Счета: бонусные (род 4 и 7) с ненулевым остатком — по ним v40
    // заводит журнал; плюс один денежный, на который ссылаются оплаты.
    final insertAccount = raw.prepare(
      'INSERT INTO accounts (id, type, name, value) VALUES (?, ?, ?, ?)',
    );
    insertAccount.execute([1, 1, 'Наличные', 0.0]);
    for (var i = 0; i < _kBonusAccounts; i++) {
      insertAccount.execute([
        100 + i,
        i.isEven ? 4 : 7,
        'Бонус $i',
        // Каждый двадцатый — с нулевым остатком, каждый двадцать первый —
        // вовсе без значения. Правило нуля (`qa-depth`): в наборе обязаны
        // быть записи, которых в результате быть **не должно**. Журнал v40
        // заводит строку только на ненулевой остаток (`if (balance ==
        // Decimal.zero) continue`), и без таких счетов утверждение «строк
        // ровно столько, сколько ненулевых счетов» зеленело бы и у
        // миграции, которая пишет строку на каждый счёт подряд — то есть
        // заводит «стартовый остаток 0» пяти тысячам человек, у которых
        // бонусов нет.
        if (i % 20 == 0) 0.0 else if (i % 21 == 0) null else (i % 900 + 1) * 1.5,
      ]);
    }
    // Счёт не бонусного рода с непустым остатком — вторая запись, которой в
    // журнале быть не должно: род спрашивается у `BonusAccountTypes`, и
    // ветка, забывшая спросить, попала бы сюда.
    insertAccount.execute([99, 1, 'Касса магазина', 125000.0]);
    insertAccount.dispose();

    final insertSale = raw.prepare(
      'INSERT INTO sales (receipt_no, pos_id, user_id, amount, time, state) '
      'VALUES (?, 1, ?, ?, ?, ?)',
    );
    for (var i = 1; i <= _kSales; i++) {
      insertSale.execute([
        i,
        (i % _kUsers) + 1,
        (i % 9000) + 250.0,
        1700000000 + i * 60,
        // Ровно один чек оставлен в работе (`state = 0`) — на нём меряется
        // `UPDATE sales ... WHERE state = 0` ветки v37.
        i == _kSales ? 0 : 1,
      ]);
    }
    insertSale.dispose();

    final insertLine = raw.prepare(
      'INSERT INTO sale_products '
      '(receipt_no, pos_id, ucode, quantity, price, price_before) '
      'VALUES (?, 1, ?, ?, ?, ?)',
    );
    for (var i = 0; i < _kSaleLines; i++) {
      final receipt = (i % _kSales) + 1;
      insertLine.execute([receipt, 5000 + (i % 1200), 1.0, 99.0, 99.0]);
    }
    insertLine.dispose();

    final insertPayment = raw.prepare(
      'INSERT INTO payments '
      '(user_id, receipt_no, pos_id, seq, payee_account_id, amount, time) '
      'VALUES (?, ?, 1, ?, 1, ?, ?)',
    );
    for (var i = 0; i < _kPayments; i++) {
      // Первые [_kSales] строк — по одной на чек; остаток ложится вторыми
      // строками на первые чеки (смешанная оплата).
      final receipt = (i % _kSales) + 1;
      final seq = i ~/ _kSales;
      insertPayment.execute([
        (i % _kUsers) + 1,
        receipt,
        seq,
        (i % 900) + 50.0,
        1700000000 + i * 60,
      ]);
    }
    insertPayment.dispose();

    final insertRefund = raw.prepare(
      'INSERT INTO refunds '
      '(sale_receipt_no, sale_pos_id, user_id, amount, time) '
      'VALUES (?, 1, ?, ?, ?)',
    );
    for (var i = 1; i <= _kRefunds; i++) {
      insertRefund.execute([i, 1, (i % 900) + 10.0, 1700000000 + i * 600]);
    }
    insertRefund.dispose();

    final insertDoc = raw.prepare(
      'INSERT INTO webkassa_receipts '
      '(operation_id, receipt_no, is_sale, doc_kind, fiscal_no) '
      'VALUES (?, ?, ?, ?, ?)',
    );
    for (var i = 1; i <= _kSales; i++) {
      insertDoc.execute([i, i, 1, 0, 'F$i']);
    }
    for (var i = 1; i <= _kRefunds; i++) {
      // Возврат №N и продажа №N — та самая пара, которая до v50 сталкивалась
      // на общем первичном ключе. В фикстуре она разведена родом документа;
      // урезание до v49 сольёт её обратно, и перенос v50 будет мерен на
      // настоящем, а не на придуманном составе.
      insertDoc.execute([_kSales + i, i, 0, 1, 'R$i']);
    }
    insertDoc.dispose();

    final insertQueue = raw.prepare(
      'INSERT INTO fiscal_queue_entries '
      '(idempotency_key, op_type, payload, occurred_at) VALUES (?, 0, ?, ?)',
    );
    for (var i = 0; i < _kFiscalQueue; i++) {
      insertQueue.execute(['key-$i', '{"n":$i}', 1700000000 + i]);
    }
    insertQueue.dispose();

    final insertCash = raw.prepare(
      'INSERT INTO cash_operations (amount, type, user_id, doc_time) '
      'VALUES (?, ?, ?, ?)',
    );
    for (var i = 0; i < _kCashOps; i++) {
      insertCash.execute([
        (i % 5000) + 100.0,
        i.isEven ? 1 : 2,
        (i % _kUsers) + 1,
        1700000000 + i * 300,
      ]);
    }
    insertCash.dispose();

    final insertCert = raw.prepare(
      'INSERT INTO gift_certificates '
      '(number, nominal_millis, balance_millis, status, issued_at) '
      'VALUES (?, ?, ?, ?, ?)',
    );
    for (var i = 0; i < _kCertificates; i++) {
      insertCert.execute(['C$i', 10000000, 10000000, 'active', 1700000000 + i]);
    }
    insertCert.dispose();

    raw.execute('COMMIT');
    _sealAndCheckpoint(raw, file);
    return file;
  }

  /// Копия заполненной базы под одну точку старта.
  File copyFor(File seed, int version) {
    final target = File(
      '${work.path}${Platform.pathSeparator}from-v$version.sqlite',
    );
    if (target.existsSync()) target.deleteSync();
    seed.copySync(target.path);
    return target;
  }

  /// Замер одной точки старта.
  ///
  /// Возвращает пройденное время; утверждения — внутри, чтобы ни один
  /// случай не мог «померить» и промолчать.
  Future<Duration> measure(
    File file, {
    required int from,
    required int bonusAccountsWithBalance,
  }) async {
    // Утверждение 1: фикстура действительно старая. Проверяется по
    // таблице, которой на этой версии ещё не существует.
    final probe = sqlite3.sqlite3.open(file.path);
    expect(
      probe.select('PRAGMA user_version').first['user_version'],
      from,
      reason: 'фикстура стоит не на той версии — мерить нечего',
    );
    final tablesBefore = probe
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((r) => r['name'] as String)
        .toSet();
    final missingByDesign = _tablesIntroducedAfter(from);
    for (final name in missingByDesign) {
      expect(
        tablesBefore,
        isNot(contains(name)),
        reason:
            'таблица $name есть в фикстуре v$from — значит урезание не '
            'сработало, и миграция ничего бы не делала',
      );
    }
    // Тех же лет ближние точки старта: с v49 и v50 новых таблиц не
    // заводится вовсе, и утверждение по таблицам для них пусто. Пустое
    // утверждение — это зелёный цвет без содержания, поэтому у этих двух
    // проверяются колонки.
    Set<String> columnsOf(String table) => probe
        .select("PRAGMA table_info('$table')")
        .map((r) => r['name'] as String)
        .toSet();
    if (from < 50) {
      expect(
        columnsOf('webkassa_receipts'),
        isNot(contains('doc_kind')),
        reason: 'фикстура v$from уже несёт род документа — мерить нечего',
      );
    }
    if (from < 51) {
      expect(
        columnsOf('payment_intents'),
        isNot(contains('reversed_amount')),
        reason: 'фикстура v$from уже несёт возврат по намерению',
      );
    }

    final paymentsBefore =
        probe.select('SELECT COUNT(*) c FROM payments').first['c'] as int;
    final docsBefore =
        probe.select('SELECT COUNT(*) c FROM webkassa_receipts').first['c']
            as int;
    probe.dispose();

    final watch = Stopwatch()..start();
    final db = AppDatabase.forTesting(NativeDatabase(file));
    // Открытие drift ленивое: миграция начинается на первом запросе.
    final version = await db
        .customSelect('PRAGMA user_version')
        .map((r) => r.read<int>('user_version'))
        .getSingle();
    watch.stop();

    // Утверждение 2: версия и целостность.
    expect(version, db.schemaVersion);
    final integrity = await db
        .customSelect('PRAGMA integrity_check')
        .map((r) => r.read<String>('integrity_check'))
        .getSingle();
    expect(integrity, 'ok', reason: 'после миграции с v$from база повреждена');

    // Утверждение 3: данные пережили перестройку.
    Future<int> count(String table) => db
        .customSelect('SELECT COUNT(*) c FROM $table')
        .map((r) => r.read<int>('c'))
        .getSingle();
    expect(
      await count('payments'),
      paymentsBefore,
      reason: 'перестройка payments (v41) потеряла строки',
    );
    expect(
      await count('webkassa_receipts'),
      docsBefore,
      reason: 'смена ключа webkassa_receipts (v50) потеряла строки',
    );
    if (from < 40) {
      expect(
        await count('bonus_entries'),
        bonusAccountsWithBalance,
        reason: 'стартовые остатки бонусного журнала (v40) неполны',
      );
    }

    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    await db.close();
    return watch.elapsed;
  }

  test(
    'обновление установленной кассы с каждой точки поставки: время, '
    'целостность, сохранность данных',
    () async {
      final stage = Stopwatch()..start();
      final ddl = await currentDdl();
      final seed = await buildSeededFile(ddl);
      // ignore: avoid_print
      print('[замер] засев: ${stage.elapsedMilliseconds} мс');
      expect(
        seed.lengthSync(),
        greaterThan(5 * 1024 * 1024),
        reason:
            'заполненная база меньше пяти мегабайт — засеялось не то, и '
            'замер бы соврал в лучшую сторону',
      );

      final report = StringBuffer()
        ..writeln('')
        ..writeln('### Замер миграции на объёме')
        ..writeln(
          'Чеков $_kSales, строк $_kSaleLines, оплат $_kPayments, '
          'возвратов $_kRefunds, фискальных документов $_kFiscalDocs, '
          'очередь $_kFiscalQueue, бонусных счетов $_kBonusAccounts, '
          'кассовых операций $_kCashOps.',
        )
        ..writeln(
          'Файл базы: ${(seed.lengthSync() / 1024 / 1024).toStringAsFixed(1)} МБ.',
        );

      // **Каждая точка, а не выборка из четырёх.** Первая редакция брала
      // четыре «точки поставки» (49, 44, 39, 28), и этого хватило бы для
      // времени, но не для цены: ступень, на которой пряталась минута,
      // видна только рядом с соседкой. Шестьдесят секунд ветки v40 нашлись
      // по разрыву между v40 → v51 (0,97 с) и v39 → v51 (61,4 с), а три
      // секунды ветки v33 — только когда лестницу сняли целиком.
      //
      // Вторая причина держать все точки — целостность: требование звучит
      // «проверка целостности проходит после **каждой**», и выборка из
      // четырёх отвечала бы на него выборочно. Полная лестница v28…v50
      // стоит 23 с и поднимает базу двадцать три раза.
      //
      // Порядок от новых к старым намеренно: короткие подъёмы идут первыми,
      // и поломка формы фикстуры видна на второй секунде, а не на двадцатой.
      for (var from = 50; from >= 28; from--) {
        final file = copyFor(seed, from);
        stage.reset();
        final bonusWithBalance = _downgradeTo(file, from);
        // ignore: avoid_print
        print('[замер] урезание до v$from: ${stage.elapsedMilliseconds} мс');
        final elapsed = await measure(
          file,
          from: from,
          bonusAccountsWithBalance: bonusWithBalance,
        );
        // ignore: avoid_print
        print('[замер] v$from → 51: ${elapsed.inMilliseconds} мс');
        report.writeln(
          'v$from → 51: ${elapsed.inMilliseconds} мс '
          '(${(elapsed.inMilliseconds / 1000).toStringAsFixed(1)} с)',
        );
      }
      // ignore: avoid_print
      print(report);
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

/// Свернуть журнал и убрать спутники — правило дерева для любой копии базы
/// drift. Без него копия не содержит последних вставок.
void _sealAndCheckpoint(sqlite3.Database raw, File file) {
  raw.execute('PRAGMA wal_checkpoint(TRUNCATE)');
  raw.dispose();
  for (final suffix in const ['-wal', '-shm']) {
    final companion = File('${file.path}$suffix');
    if (companion.existsSync()) companion.deleteSync();
  }
}

/// Таблицы, которых на версии [from] ещё не существовало. Список нужен не
/// для миграции, а для утверждения 1: по нему видно, что урезание сделало
/// базу действительно старой.
Set<String> _tablesIntroducedAfter(int from) => <String>{
  if (from < 40) ...['bonus_entries', 'sale_discounts', 'discount_audit_entries'],
  if (from < 41) 'payment_kinds',
  if (from < 43) 'payment_intents',
  if (from < 44) 'gift_certificates',
  if (from < 45) ...['credit_contracts', 'credit_schedule_entries'],
  if (from < 46) 'qr_provider_configs',
  if (from < 48) 'certificate_refund_links',
  if (from < 49) 'prepayment_intakes',
  if (from < 29) ...['print_jobs', 'print_job_confirmations'],
  if (from < 34) 'security_events',
  if (from < 39) 'discount_limits',
};

/// Урезать заполненную базу текущей формы назад до версии [from].
///
/// Возвращает число бонусных счетов с ненулевым остатком — столько строк
/// обязан завести журнал v40, и это утверждение 3 замера.
///
/// Порядок обратный порядку миграций: сначала снимается самое новое.
int _downgradeTo(File file, int from) {
  final raw = sqlite3.sqlite3.open(file.path);

  void dropTable(String name) => raw.execute('DROP TABLE IF EXISTS $name');
  void dropColumn(String table, String column) {
    try {
      raw.execute('ALTER TABLE $table DROP COLUMN $column');
    } on sqlite3.SqliteException {
      // Колонки уже нет — урезание идёт сверху вниз и может пройти по
      // одному месту дважды.
    }
  }

  if (from < 51) {
    dropColumn('payment_intents', 'reversed_amount');
    dropColumn('payment_intents', 'reversed_at');
  }
  if (from < 50) {
    // Ключ вернуть `ALTER TABLE`-ом нельзя — таблица пересобирается в
    // прежнюю форму (`PRIMARY KEY(operation_id)`, без `doc_kind`). Пара
    // «продажа №N и возврат №N» при этом сталкивается — ровно тот случай,
    // ради которого v50 и заведена, — поэтому возвратные строки получают
    // прежние, неконфликтные номера операции.
    raw.execute('''
      CREATE TABLE webkassa_receipts_v49 (
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
      )''');
    raw.execute(
      'INSERT INTO webkassa_receipts_v49 '
      '(operation_id, receipt_no, fiscal_no, wk_receipt_no, wk_time, '
      'wk_offline_mode, ticket_url, is_sale, registration_number, '
      'original_total) '
      'SELECT operation_id, receipt_no, fiscal_no, wk_receipt_no, wk_time, '
      'wk_offline_mode, ticket_url, is_sale, registration_number, '
      'original_total FROM webkassa_receipts',
    );
    raw.execute('DROP TABLE webkassa_receipts');
    raw.execute(
      'ALTER TABLE webkassa_receipts_v49 RENAME TO webkassa_receipts',
    );
  }
  if (from < 49) dropTable('prepayment_intakes');
  if (from < 48) dropTable('certificate_refund_links');
  if (from < 47) {
    dropColumn('this_pos_entries', 'fiscalize_certificate_sale');
    dropColumn('this_pos_entries', 'offset_fiscal_layout');
    dropColumn('this_pos_entries', 'fiscalize_prepayment_receipt');
    dropColumn('cash_operations', 'kind_id');
  }
  if (from < 46) dropTable('qr_provider_configs');
  if (from < 45) {
    dropTable('credit_contracts');
    dropTable('credit_schedule_entries');
    raw.execute(
      "DELETE FROM user_permissions WHERE permission_key = 'op.creditRepay'",
    );
  }
  if (from < 44) dropTable('gift_certificates');
  if (from < 43) dropTable('payment_intents');
  if (from < 41) dropTable('payment_kinds');
  if (from < 40) {
    dropTable('bonus_entries');
    dropTable('sale_discounts');
    dropTable('discount_audit_entries');
  }
  if (from < 39) dropTable('discount_limits');
  if (from < 38) dropColumn('terminals', 'allowed_payment_types');
  if (from < 37) {
    dropColumn('sales', 'terminal_id');
    dropColumn('sales', 'cart_version');
    dropColumn('sales', 'last_command_key');
  }
  if (from < 36) dropColumn('terminals', 'secret_fingerprint');
  if (from < 35) {
    // v33 раздаёт права всем не-владельцам, v35 — добавленные ключи.
    // Пустая таблица прав — это и есть база, не видевшая ни того, ни
    // другого.
    raw.execute('DELETE FROM user_permissions');
  }
  if (from < 34) dropTable('security_events');
  if (from < 32) {
    dropColumn('this_pos_entries', 'walk_up_enabled');
    dropColumn('this_pos_entries', 'session_idle_minutes');
  }
  if (from < 31) {
    // v31 сносит `bug_reports`; на базе, где её нет, шаг ничего не стоит,
    // и замер соврал бы в лучшую сторону.
    raw.execute('CREATE TABLE IF NOT EXISTS bug_reports (id INTEGER)');
  }
  if (from < 29) {
    dropTable('print_jobs');
    dropTable('print_job_confirmations');
  }

  final bonusWithBalance =
      raw
              .select(
                'SELECT COUNT(*) c FROM accounts '
                'WHERE type IN ${BonusAccountTypes.sqlInList} '
                'AND value IS NOT NULL AND value != 0',
              )
              .first['c']
          as int;

  raw.execute('PRAGMA user_version = $from');
  _sealAndCheckpoint(raw, file);
  return bonusWithBalance;
}
