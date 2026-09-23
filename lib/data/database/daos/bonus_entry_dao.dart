import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/bonus_tables.dart';
import 'package:telepos/domain/bonus/bonus_entry_kind.dart';
import 'package:telepos/domain/fiscal/bonus_account_types.dart';

part 'bonus_entry_dao.g.dart';

/// Журнал бонусных движений — **и единственный, кто двигает бонусный
/// остаток**.
///
/// # Почему запись и остаток здесь неразделимы
///
/// Инвариант задачи один: «остаток бонусного счёта равен сумме журнала».
/// Он держится ровно до первого пути, который тронул `accounts.value` в
/// обход журнала. Таких путей в этом дереве было два — продажа и возврат, —
/// и оба были написаны независимо друг от друга (`AccountPosting` завёлся
/// именно потому, что второй не знал того, что знал первый).
///
/// Поэтому [record] делает **оба** дела одним вызовом: пишет запись и
/// двигает остаток. Разнести их по двум методам значило бы снова сделать
/// правило вопросом дисциплины вызывающего, а дисциплина здесь уже
/// проверена: не вспомнил никто.
///
/// Сторож на инвариант — [divergences]: он краснеет, если такой путь
/// появится вновь.
@DriftAccessor(tables: [BonusEntries])
class BonusEntryDao extends DatabaseAccessor<AppDatabase>
    with _$BonusEntryDaoMixin {
  BonusEntryDao(super.db);

  /// «Ожидает отправки» — то же число и тот же смысл, что `payments.state`.
  static const int _pendingSync = 1;

  /// Записать движение и сдвинуть на него остаток счёта.
  ///
  /// Вызывать **внутри транзакции вызывающего**, если движение — часть
  /// чего-то большего (продажи, возврата). Метод своей транзакции не
  /// открывает намеренно: продажа обязана откатываться целиком, включая
  /// бонусную часть, — иначе чек, не состоявшийся из-за нарушения ключа
  /// платежей, оставил бы за собой начисленные бонусы
  /// (`test/data/sale/payment_claim_race_test.dart`).
  ///
  /// [amount] обязана быть неотрицательной: направление называет [kind].
  /// Отрицательная — `ArgumentError`, а не «поймём по знаку»: понять по
  /// знаку значит завести второе правило направления рядом с первым.
  /// Ноль допустим и записывается: «начислено ноль» — тоже факт, и
  /// молчание о нём делает журнал неполным.
  Future<BonusEntry> record({
    required int accountId,
    required int kind,
    required Decimal amount,
    int? receiptNo,
    int? posId,
    int? refundLocalId,
    int? userId,
    String? reason,
    int? at,
  }) async {
    if (amount < Decimal.zero) {
      throw ArgumentError.value(
        amount.toString(),
        'amount',
        'сумма движения не бывает отрицательной — направление называет kind',
      );
    }
    final sign = BonusEntryKind.signOf(kind);
    final originPosId = await _originPosId();
    final now = at ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final entryId = await _nextOriginEntryId(originPosId);

    final row = await into(bonusEntries).insertReturning(
      BonusEntriesCompanion.insert(
        accountId: accountId,
        kind: kind,
        amount: amount,
        time: now,
        originPosId: originPosId,
        originEntryId: entryId,
        receiptNo: Value(receiptNo),
        posId: Value(posId),
        refundLocalId: Value(refundLocalId),
        userId: Value(userId),
        reason: Value(reason),
        state: const Value(_pendingSync),
      ),
    );

    await _shiftBalance(accountId, amount * Decimal.fromInt(sign));
    return row;
  }

  /// Принять чужую запись. Повтор — **ничего не меняет**.
  ///
  /// Возвращает `true`, если запись легла впервые. После приёма остаток
  /// счёта пересчитывается по журналу целиком, а не сдвигается на сумму:
  /// записи приходят в произвольном порядке, и «сдвинуть на слагаемое»
  /// верно только если ни одна не потерялась по дороге. Пересчёт же
  /// одинаково верен при любом порядке и при любых пропусках — это и есть
  /// то свойство, ради которого выбран вариант C.
  Future<bool> applyRemote({
    required int originPosId,
    required int originEntryId,
    required int accountId,
    required int kind,
    required Decimal amount,
    int? receiptNo,
    int? posId,
    int? refundLocalId,
    int? userId,
    String? reason,
    required int time,
  }) async {
    // Род читается **до** вставки: запись неизвестного рода выпала бы из
    // баланса молча (см. `BonusEntryKind.signOf`).
    BonusEntryKind.signOf(kind);

    final existing =
        await (select(bonusEntries)..where(
              (e) =>
                  e.originPosId.equals(originPosId) &
                  e.originEntryId.equals(originEntryId),
            ))
            .getSingleOrNull();
    if (existing != null) return false;

    await into(bonusEntries).insert(
      BonusEntriesCompanion.insert(
        accountId: accountId,
        kind: kind,
        amount: amount,
        time: time,
        originPosId: originPosId,
        originEntryId: originEntryId,
        receiptNo: Value(receiptNo),
        posId: Value(posId),
        refundLocalId: Value(refundLocalId),
        userId: Value(userId),
        reason: Value(reason),
        // Чужая запись отправке не подлежит: она уже там, откуда пришла.
        state: const Value(null),
      ),
    );

    await _rebuildBalance(accountId);
    return true;
  }

  /// Возврат чека для бонусов — **оба движения одним вызовом**.
  ///
  /// # Почему одним, а не двумя
  ///
  /// Их два, и они противоположны: списанное покупателю **возвращается**
  /// (плюс), начисленное **сторнируется** (минус) — товара нет, начислять
  /// было не за что. Пока одно делает журнал, а другое платёжный цикл,
  /// журнал перестаёт объяснять баланс, и сверка начинает краснеть на
  /// исправном возврате. Один вызов на один возврат — единственная форма,
  /// в которой забыть половину нельзя.
  ///
  /// # Возврат списанного берётся суммой, а сторно — долей
  ///
  /// [returnedByAccount] — сколько по каждому бонусному счёту **уже
  /// посчитал сторно платежей**: там эта сумма точная, вплоть до остатка,
  /// доставшегося последней строке. Пересчитывать её здесь своей долей
  /// значило бы завести второй ответ, расходящийся с первым на копейки, —
  /// и расходился бы он молча.
  ///
  /// Сторно начисления пересчитать больше нечем, и оно берётся долей
  /// возврата в чеке. **Не пересчётом по ставке**: `cashback_rate` к
  /// моменту возврата может быть другой, и пересчёт дал бы правдоподобное
  /// неверное число — ровно та порча, ради которой журнал и заведён.
  ///
  /// Частичный возврат сторнирует свою долю, и это названное решение, а не
  /// умолчание: половину товара вернули — половину начисленного забрали.
  /// Доля считается от суммы чека, округляется до денег (S3) и **не может
  /// превысить неотсторнированный остаток** — иначе череда частичных
  /// возвратов на округлениях увела бы счёт ниже, чем было начислено.
  Future<void> reverseForRefund({
    required int receiptNo,
    required int posId,
    required int refundLocalId,
    required Map<int, Decimal> returnedByAccount,
    required Decimal refundAmount,
    required Decimal saleAmount,
    int? userId,
  }) async {
    for (final entry in returnedByAccount.entries) {
      if (entry.value <= Decimal.zero) continue;
      await record(
        accountId: entry.key,
        kind: BonusEntryKind.redemptionReturn,
        amount: entry.value,
        receiptNo: receiptNo,
        posId: posId,
        refundLocalId: refundLocalId,
        userId: userId,
        reason: 'возврат бонусов, которыми был оплачен чек',
      );
    }

    final onReceipt = await findBySale(receiptNo, posId);
    if (onReceipt.isEmpty) return;

    final accruedByAccount = <int, Decimal>{};
    final reversedByAccount = <int, Decimal>{};
    for (final e in onReceipt) {
      if (e.kind == BonusEntryKind.accrual) {
        accruedByAccount[e.accountId] =
            (accruedByAccount[e.accountId] ?? Decimal.zero) + e.amount;
      } else if (e.kind == BonusEntryKind.accrualReversal) {
        reversedByAccount[e.accountId] =
            (reversedByAccount[e.accountId] ?? Decimal.zero) + e.amount;
      }
    }

    for (final entry in accruedByAccount.entries) {
      final accrued = entry.value;
      final already = reversedByAccount[entry.key] ?? Decimal.zero;
      final left = accrued - already;
      if (left <= Decimal.zero) continue;

      var share = accrued;
      if (saleAmount > Decimal.zero && refundAmount < saleAmount) {
        share = (accrued * refundAmount / saleAmount)
            .toDecimal(scaleOnInfinitePrecision: 6)
            .round(scale: 3);
      }
      if (share > left) share = left;
      if (share <= Decimal.zero) continue;

      await record(
        accountId: entry.key,
        kind: BonusEntryKind.accrualReversal,
        amount: share,
        receiptNo: receiptNo,
        posId: posId,
        refundLocalId: refundLocalId,
        userId: userId,
        reason: 'товар вернули — начислять было не за что',
      );
    }
  }

  /// Остаток счёта **по журналу** — то, чему обязан равняться
  /// `accounts.value`.
  ///
  /// Складывается в Dart, а не `SUM`-ом в SQL, и это решение, а не лень:
  /// `SUM` потребовал бы `CASE WHEN kind IN (…)`, то есть **второй копии
  /// таблицы знаков** — ровно того, что этот план из дерева и убирает.
  /// Цена — чтение журнала счёта целиком; платится она на сверке и на
  /// приёме чужих записей, а не на каждой продаже (продажа сдвигает
  /// остаток слагаемым).
  Future<Decimal> balanceOf(int accountId) async {
    final rows = await (select(
      bonusEntries,
    )..where((e) => e.accountId.equals(accountId))).get();
    var sum = Decimal.zero;
    for (final e in rows) {
      sum += e.amount * Decimal.fromInt(BonusEntryKind.signOf(e.kind));
    }
    return sum;
  }

  /// Свои записи, ещё не отправленные в обмен.
  ///
  /// Только `state = 1`. Чужие записи приезжают со `state = null` — их
  /// незачем отправлять обратно туда, откуда они пришли; стартовый остаток
  /// миграции помечен так же и по другой причине: у соседней кассы он
  /// свой, и сложить их значило бы удвоить бонусы каждому клиенту.
  Future<List<BonusEntry>> pendingForPush() =>
      (select(bonusEntries)..where((e) => e.state.equals(_pendingSync))).get();

  /// Пометить отправленными.
  Future<void> markPushed(List<int> ids) async {
    if (ids.isEmpty) return;
    await (update(bonusEntries)..where((e) => e.id.isIn(ids))).write(
      const BonusEntriesCompanion(state: Value(null)),
    );
  }

  /// Номер этой кассы — тот же, что попадает в [BonusEntries.originPosId].
  ///
  /// Нужен приёму обмена: своя же запись, вернувшаяся кругом, отличается
  /// именно по нему.
  Future<int> ownPosId() => _originPosId();

  Future<List<BonusEntry>> findByAccount(int accountId) =>
      (select(bonusEntries)..where((e) => e.accountId.equals(accountId))).get();

  Future<List<BonusEntry>> findBySale(int receiptNo, int posId) => (select(
    bonusEntries,
  )..where((e) => e.receiptNo.equals(receiptNo) & e.posId.equals(posId))).get();

  /// Счета, у которых записанный остаток разошёлся с журналом.
  ///
  /// **Это и есть сторож инварианта в продукте**, а не только в наборе:
  /// путь, тронувший `accounts.value` мимо [record], попадёт сюда, и
  /// попадёт с числами — сколько записано, сколько по журналу.
  ///
  /// Перебираются **все** бонусные счета, включая те, у кого журнала нет
  /// вовсе: счёт с остатком и пустым журналом — самое опасное расхождение,
  /// и «нет записей — нечего сверять» пропустило бы ровно его.
  Future<List<BonusDivergence>> divergences() async {
    final accounts = await (db.select(
      db.accounts,
    )..where((a) => a.type.isIn(BonusAccountTypes.values))).get();

    final out = <BonusDivergence>[];
    for (final a in accounts) {
      final stored = a.value ?? Decimal.zero;
      final journal = await balanceOf(a.id);
      if (stored != journal) {
        out.add(
          BonusDivergence(accountId: a.id, stored: stored, journal: journal),
        );
      }
    }
    return out;
  }

  /// Номер кассы для [BonusEntries.originPosId].
  ///
  /// Касса не настроена — `0`. Отказ здесь был бы хуже: он остановил бы
  /// продажу из-за ненастроенного номера кассы, которого продаже и так
  /// хватает (`Sales.posId` берётся тем же путём). Ноль — видимое «эта
  /// запись родилась там, где кассу не назвали», и сведение его не
  /// перепутает с настоящим номером, потому что настоящие начинаются с
  /// единицы.
  Future<int> _originPosId() async {
    try {
      return (await db.thisPosDao.get())?.id ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Следующий номер записи **этой кассы**.
  ///
  /// Считается от максимума среди своих, а не от `id`: `id` растёт и на
  /// чужих записях, и тогда номера своих зияли бы дырами, по которым
  /// принимающая сторона не смогла бы отличить «ещё не доехало» от «такой
  /// и не было».
  Future<int> _nextOriginEntryId(int originPosId) async {
    final maxOf = bonusEntries.originEntryId.max();
    final row =
        await (selectOnly(bonusEntries)
              ..addColumns([maxOf])
              ..where(bonusEntries.originPosId.equals(originPosId)))
            .getSingle();
    return (row.read(maxOf) ?? 0) + 1;
  }

  /// Сдвинуть остаток на [delta] — **с уже выбранным знаком**.
  ///
  /// Мимо [AccountDao.post] намеренно: `post` выбирает знак сам, по роду
  /// счёта, и для бонусного он выбирает «платёж уменьшает». Здесь знак уже
  /// выбран родом движения, и второй выбор поверх первого перевернул бы
  /// начисление в списание.
  Future<void> _shiftBalance(int accountId, Decimal delta) async {
    final account = await db.accountDao.findById(accountId);
    if (account == null) return;
    await db.accountDao.updateBalance(
      accountId,
      (account.value ?? Decimal.zero) + delta,
      redemption: true,
    );
  }

  Future<void> _rebuildBalance(int accountId) async {
    final account = await db.accountDao.findById(accountId);
    if (account == null) return;
    await db.accountDao.updateBalance(
      accountId,
      await balanceOf(accountId),
      redemption: true,
    );
  }
}

/// Расхождение между записанным остатком и журналом.
class BonusDivergence {
  const BonusDivergence({
    required this.accountId,
    required this.stored,
    required this.journal,
  });

  final int accountId;

  /// Что лежит в `accounts.value`.
  final Decimal stored;

  /// Что получается сложением журнала.
  final Decimal journal;

  @override
  String toString() => 'счёт $accountId: записано $stored, по журналу $journal';
}
