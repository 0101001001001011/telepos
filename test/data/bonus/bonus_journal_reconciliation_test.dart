import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/sync/couchdb_document_mapper.dart';
import 'package:telepos/domain/bonus/bonus_entry_kind.dart';

/// Сведение бонусов между кассами — вариант C, шаг 9 задачи 13.
///
/// # Что доказывается числами
///
/// Реплицируется **журнал**, баланс считает каждая касса сама. Отсюда два
/// свойства, которые до журнала были недостижимы по построению (остаток
/// перезаписывался целиком, и последняя доставка выигрывала):
///
/// 1. **Порядок доставки на баланс не влияет** — сумма не зависит от
///    порядка слагаемых;
/// 2. **Повторная доставка ничего не меняет** — ключ по паре
///    «породившая касса + её номер записи».
///
/// # Названная цена варианта C
///
/// Две кассы, торгующие оффлайн, могут списать один остаток дважды: обе
/// видели его целым. Журнал этого **не предотвращает** — он делает это
/// видимым, и последняя проба здесь именно про это.
void main() {
  const cashbackAccountId = 13;

  Decimal d(String v) => Decimal.parse(v);

  Future<AppDatabase> till({int posId = 1, String opening = '0'}) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.thisPosEntries)
        .insert(
          ThisPosEntriesCompanion(
            id: Value(posId),
            cashBoxName: Value('Касса $posId'),
          ),
        );
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(cashbackAccountId),
            type: AccountType.agentCashback,
            name: const Value('Бонусы клиента'),
            value: Value(d(opening)),
          ),
        );
    return db;
  }

  /// Доставка одной записи с чужой кассы — то, что делал бы приём
  /// репликации. Форма довода нарочно та же, что у строки журнала: если
  /// приём начнёт что-то досочинять, это станет видно здесь.
  Future<bool> deliver(AppDatabase to, BonusEntry e) => to.bonusEntryDao
      .applyRemote(
        originPosId: e.originPosId,
        originEntryId: e.originEntryId,
        accountId: e.accountId,
        kind: e.kind,
        amount: e.amount,
        receiptNo: e.receiptNo,
        posId: e.posId,
        refundLocalId: e.refundLocalId,
        userId: e.userId,
        reason: e.reason,
        time: e.time,
      );

  test('сверка умеет краснеть: остаток, тронутый мимо журнала, виден',
      () async {
    // **Без этой пробы весь сторож — театр.** Все прочие утверждения про
    // сверку в этом файле и в соседних имеют вид `expect(divergences,
    // isEmpty)`, и реализация `divergences() => []` прошла бы их все до
    // единого. Утверждение, зелёное в пустоте, — записанная ловушка
    // (`feedback_guard_must_redden`), и закрывается она только случаем, где
    // сторож обязан покраснеть.
    final db = await till(posId: 1, opening: '0');
    addTearDown(db.close);

    await db.bonusEntryDao.record(
      accountId: cashbackAccountId,
      kind: BonusEntryKind.accrual,
      amount: d('100'),
      receiptNo: 1,
      posId: 1,
    );
    expect(await db.bonusEntryDao.divergences(), isEmpty);

    // Путь мимо журнала — ровно то, чем были продажа и возврат до задачи 13.
    await db.accountDao.updateBalance(
      cashbackAccountId,
      d('999'),
      redemption: true,
    );

    final found = await db.bonusEntryDao.divergences();
    expect(found, hasLength(1), reason: 'сверка обязана это увидеть');
    expect(found.single.accountId, cashbackAccountId);
    expect(found.single.stored, d('999'));
    expect(
      found.single.journal,
      d('100'),
      reason: 'расхождение называется числами, а не словом «есть»: '
          'без них искать причину пришлось бы в чеках',
    );
    expect(found.single.toString(), contains('999'));
  });

  test('счёт с остатком и пустым журналом — самое опасное расхождение',
      () async {
    // «Нет записей — нечего сверять» пропустило бы ровно его: счёт,
    // заведённый мимо миграции и мимо журнала.
    final db = await till(posId: 1, opening: '250');
    addTearDown(db.close);

    final found = await db.bonusEntryDao.divergences();
    expect(found, hasLength(1));
    expect(found.single.stored, d('250'));
    expect(found.single.journal, Decimal.zero);
  });

  test('счёт не бонусного рода сверка не трогает', () async {
    // Слом в обратную сторону: сверка, перебирающая все счета, краснела бы
    // на каждой кассе — у кассового счёта журнала нет и быть не должно.
    final db = await till(posId: 1);
    addTearDown(db.close);
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(11),
            type: AccountType.pos,
            name: const Value('Касса'),
            value: Value(d('700')),
          ),
        );

    expect(await db.bonusEntryDao.divergences(), isEmpty);
  });

  test('порядок доставки на баланс не влияет', () async {
    // Две кассы работали врозь: первая начислила 100 и списала 30, вторая
    // начислила 50. Третья принимает всё — в двух разных порядках.
    final a = await till(posId: 1);
    final b = await till(posId: 2);
    addTearDown(a.close);
    addTearDown(b.close);

    await a.bonusEntryDao.record(
      accountId: cashbackAccountId,
      kind: BonusEntryKind.accrual,
      amount: d('100'),
      receiptNo: 1,
      posId: 1,
    );
    await a.bonusEntryDao.record(
      accountId: cashbackAccountId,
      kind: BonusEntryKind.redemption,
      amount: d('30'),
      receiptNo: 2,
      posId: 1,
    );
    await b.bonusEntryDao.record(
      accountId: cashbackAccountId,
      kind: BonusEntryKind.accrual,
      amount: d('50'),
      receiptNo: 1,
      posId: 2,
    );

    final produced = [
      ...await a.bonusEntryDao.findByAccount(cashbackAccountId),
      ...await b.bonusEntryDao.findByAccount(cashbackAccountId),
    ];
    expect(produced, hasLength(3));

    final forward = await till(posId: 3);
    addTearDown(forward.close);
    for (final e in produced) {
      expect(await deliver(forward, e), isTrue);
    }

    final backward = await till(posId: 4);
    addTearDown(backward.close);
    for (final e in produced.reversed) {
      expect(await deliver(backward, e), isTrue);
    }

    // 100 − 30 + 50 = 120, обоими порядками.
    expect(
      await forward.bonusEntryDao.balanceOf(cashbackAccountId),
      d('120'),
    );
    expect(
      await backward.bonusEntryDao.balanceOf(cashbackAccountId),
      d('120'),
    );
    expect(
      (await backward.accountDao.findById(cashbackAccountId))?.value,
      d('120'),
      reason: 'записанный остаток пересчитывается по журналу при приёме',
    );
    expect(await forward.bonusEntryDao.divergences(), isEmpty);
    expect(await backward.bonusEntryDao.divergences(), isEmpty);
  });

  test('запись переживает обмен: деньги строкой, третий знак цел',
      () async {
    // Доставка здесь идёт **через настоящий формат обмена**, а не мимо
    // него: `applyRemote` без такого пути был бы методом, который зовут
    // одни пробы, — то самое «выглядит живым» из
    // `project_dead_code_pattern`.
    //
    // Третий знак — не украшение: деньги в этом дереве P18,S3, и `double`
    // потерял бы его молча. Поэтому сумма едет **строкой** (I159), и
    // проверяется это числом, которое в `double` не представимо точно.
    final a = await till(posId: 1);
    final target = await till(posId: 3);
    addTearDown(a.close);
    addTearDown(target.close);

    await a.bonusEntryDao.record(
      accountId: cashbackAccountId,
      kind: BonusEntryKind.accrual,
      amount: d('12.345'),
      receiptNo: 42,
      posId: 1,
      userId: 4,
      reason: 'кэшбэк за покупку',
    );
    final mine = (await a.bonusEntryDao.pendingForPush()).single;

    final doc = CouchDbDocumentMapper.bonusEntryToDoc({
      'origin_pos_id': mine.originPosId,
      'origin_entry_id': mine.originEntryId,
      'account_id': mine.accountId,
      'kind': mine.kind,
      'amount': mine.amount,
      'receipt_no': mine.receiptNo,
      'pos_id': mine.posId,
      'refund_local_id': mine.refundLocalId,
      'user_id': mine.userId,
      'reason': mine.reason,
      'time': mine.time,
    });

    expect(
      doc['_id'],
      'bonus_entry:1:1',
      reason: 'ключ — пара «касса + её номер», а не местный id: местные '
          'номера у двух касс совпадают постоянно',
    );
    expect(
      doc['amount'],
      '12.345',
      reason: 'деньги едут строкой десятичного числа (I159)',
    );
    expect(
      doc.containsKey('_rev'),
      isFalse,
      reason: 'запись журнала неизменяема — конфликт означает «уже там», '
          'и отправлять _rev значило бы разрешать перезапись факта',
    );

    final back = CouchDbDocumentMapper.docToBonusEntry(doc);
    await target.bonusEntryDao.applyRemote(
      originPosId: back['origin_pos_id'] as int,
      originEntryId: back['origin_entry_id'] as int,
      accountId: back['account_id'] as int,
      kind: back['kind'] as int,
      amount: Decimal.parse(back['amount'].toString()),
      receiptNo: back['receipt_no'] as int?,
      posId: back['pos_id'] as int?,
      refundLocalId: back['refund_local_id'] as int?,
      userId: back['user_id'] as int?,
      reason: back['reason'] as String?,
      time: (back['time'] as num).toInt(),
    );

    expect(
      await target.bonusEntryDao.balanceOf(cashbackAccountId),
      d('12.345'),
      reason: 'третий знак дошёл — через double он стал бы 12.34499999…',
    );
    final landed = (await target.bonusEntryDao.findByAccount(
      cashbackAccountId,
    )).single;
    expect(landed.receiptNo, 42);
    expect(landed.userId, 4);
    expect(landed.reason, 'кэшбэк за покупку');
    expect(
      landed.state,
      isNull,
      reason: 'чужая запись отправке не подлежит — она уже там, откуда '
          'пришла',
    );

    // И отправленная у себя больше не ждёт отправки.
    await a.bonusEntryDao.markPushed([mine.id]);
    expect(await a.bonusEntryDao.pendingForPush(), isEmpty);
  });

  test('повторная доставка ничего не меняет', () async {
    final a = await till(posId: 1);
    final target = await till(posId: 3);
    addTearDown(a.close);
    addTearDown(target.close);

    await a.bonusEntryDao.record(
      accountId: cashbackAccountId,
      kind: BonusEntryKind.accrual,
      amount: d('100'),
      receiptNo: 1,
      posId: 1,
    );
    final entry = (await a.bonusEntryDao.findByAccount(
      cashbackAccountId,
    )).single;

    expect(await deliver(target, entry), isTrue);
    expect(
      await deliver(target, entry),
      isFalse,
      reason: 'вторая доставка обязана сказать «уже есть», а не сложить',
    );
    expect(await deliver(target, entry), isFalse);

    expect(
      await target.bonusEntryDao.findByAccount(cashbackAccountId),
      hasLength(1),
    );
    expect(
      await target.bonusEntryDao.balanceOf(cashbackAccountId),
      d('100'),
      reason: 'трижды доставленное начисление — по-прежнему сто, а не триста',
    );
  });

  test('две кассы, списавшие один остаток, видны как перерасход', () async {
    // Названная цена варианта C. У покупателя 100 бонусов; обе кассы
    // оффлайн видят их целыми и обе списывают по 80. Сведение обязано дать
    // −60 — и это **не** ошибка журнала, а правда о том, что произошло.
    final a = await till(posId: 1);
    final b = await till(posId: 2);
    addTearDown(a.close);
    addTearDown(b.close);

    for (final db in [a, b]) {
      await db.bonusEntryDao.record(
        accountId: cashbackAccountId,
        kind: BonusEntryKind.opening,
        amount: d('100'),
        reason: 'стартовый остаток',
      );
    }
    await a.bonusEntryDao.record(
      accountId: cashbackAccountId,
      kind: BonusEntryKind.redemption,
      amount: d('80'),
      receiptNo: 1,
      posId: 1,
    );
    await b.bonusEntryDao.record(
      accountId: cashbackAccountId,
      kind: BonusEntryKind.redemption,
      amount: d('80'),
      receiptNo: 1,
      posId: 2,
    );

    // Сводим на первой: стартовый остаток соседа не принимается (у каждой
    // кассы он свой, и сложить их значило бы удвоить), а списание — да.
    final foreign = (await b.bonusEntryDao.findByAccount(
      cashbackAccountId,
    )).where((e) => e.kind != BonusEntryKind.opening);
    for (final e in foreign) {
      expect(await deliver(a, e), isTrue);
    }

    expect(
      await a.bonusEntryDao.balanceOf(cashbackAccountId),
      d('-60'),
      reason: '100 − 80 − 80: перерасход виден числом, а не пропадает',
    );

    // Перерасход **записывается**, а не прощается молча: без записи он
    // остался бы отрицательным остатком без объяснения, и первый же
    // смотрящий счёл бы его дефектом расчёта.
    await a.bonusEntryDao.record(
      accountId: cashbackAccountId,
      kind: BonusEntryKind.overspend,
      amount: Decimal.zero,
      reason: 'две кассы списали один остаток оффлайн',
    );
    final marks = (await a.bonusEntryDao.findByAccount(
      cashbackAccountId,
    )).where((e) => e.kind == BonusEntryKind.overspend);
    expect(marks, hasLength(1));
    expect(marks.single.reason, isNotNull);
    expect(
      await a.bonusEntryDao.balanceOf(cashbackAccountId),
      d('-60'),
      reason: 'отметка объясняет перерасход, а не двигает его',
    );
  });

  test('запись неизвестного рода не принимается молча', () async {
    // Запись из будущей версии, приехавшая со свежей кассы. Принять её и
    // посчитать «ноль» значило бы тихо выкинуть слагаемое: сверка показала
    // бы расхождение, а причину искали бы в чеках.
    final target = await till(posId: 3);
    addTearDown(target.close);

    expect(
      () => target.bonusEntryDao.applyRemote(
        originPosId: 9,
        originEntryId: 1,
        accountId: cashbackAccountId,
        kind: 99,
        amount: d('10'),
        time: 1000,
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(await target.bonusEntryDao.findByAccount(cashbackAccountId), isEmpty);
  });

  test('отрицательная сумма движения — отказ, а не «поймём по знаку»', () async {
    final db = await till();
    addTearDown(db.close);

    expect(
      () => db.bonusEntryDao.record(
        accountId: cashbackAccountId,
        kind: BonusEntryKind.accrual,
        amount: d('-10'),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('номера записей своей кассы идут подряд и не спорят с чужими',
      () async {
    // Номер считается от максимума **среди своих**. Считай он от `id`,
    // номера своих зияли бы дырами после каждой принятой чужой записи, и
    // принимающая сторона не смогла бы отличить «ещё не доехало» от
    // «такой и не было».
    final db = await till(posId: 1);
    addTearDown(db.close);

    await db.bonusEntryDao.record(
      accountId: cashbackAccountId,
      kind: BonusEntryKind.accrual,
      amount: d('10'),
    );
    await db.bonusEntryDao.applyRemote(
      originPosId: 2,
      originEntryId: 77,
      accountId: cashbackAccountId,
      kind: BonusEntryKind.accrual,
      amount: d('5'),
      time: 1000,
    );
    await db.bonusEntryDao.record(
      accountId: cashbackAccountId,
      kind: BonusEntryKind.accrual,
      amount: d('10'),
    );

    final mine =
        (await db.bonusEntryDao.findByAccount(cashbackAccountId))
            .where((e) => e.originPosId == 1)
            .map((e) => e.originEntryId)
            .toList()
          ..sort();
    expect(mine, [1, 2], reason: 'без дыры, оставленной чужой записью');
    expect(await db.bonusEntryDao.balanceOf(cashbackAccountId), d('25'));
  });
}
