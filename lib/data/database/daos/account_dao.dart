import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';
import 'package:telepos/data/database/tables/organization_tables.dart';
import 'package:telepos/domain/account/account_posting.dart';
import 'package:telepos/domain/account/account_type.dart';

/// `AccountType` переехал в домен (И6: `lib/domain` — чистый Dart, а знак
/// движения по счёту знает [AccountPosting], который там и живёт).
/// Переэкспорт — чтобы ни один из прежних читателей не менял импорт.
export 'package:telepos/domain/account/account_type.dart';

part 'account_dao.g.dart';

@DriftAccessor(tables: [Accounts])
class AccountDao extends DatabaseAccessor<AppDatabase> with _$AccountDaoMixin {
  AccountDao(super.db);

  Future<Account?> findById(int id) =>
      (select(accounts)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<List<Account>> findAll() => select(accounts).get();

  /// Счета типа [type], помеченные видимыми кассе.
  ///
  /// **Предел, названный замером (задача 14, круг правки 4):** первый
  /// запрос — с отбором по эквайреру `this_pos_entries.acquiring_account_id`
  /// — выполняется и **его результат выбрасывается**: `then` игнорирует
  /// довод и делает вторую, простую выборку. То есть отбор по эквайреру
  /// мёртв, а стоит целого обращения к базе на каждый вызов.
  ///
  /// **Круг правки 5 уточняет цену: мёртвый отбор не просто стоит
  /// запроса — он расширяет границу безопасности.** На этом списке с
  /// круга правки 2 держится сверка счёта, названного браузером
  /// (`LocalPaymentService._bankAccountId`), а значит счёт **чужого
  /// эквайрера** сегодня внутри разрешённого множества: отбор, который
  /// его отсёк бы, выполняется и выбрасывается.
  ///
  /// Названо здесь, а не починено, по двум причинам. Первая: включение
  /// отбора **сужает** список, то есть меняет деньги — работа со своей
  /// спекой, а не довесок к кругу правки. Вторая: у метода есть и другие
  /// читатели, и что они ждут от отбора по эквайреру, здесь не
  /// проверено.
  Future<List<Account>> findByTypeAndVisibility(int type, bool visibleToPos) =>
      customSelect(
        'SELECT * FROM accounts a WHERE a.type = ? AND a.visible_to_pos = ? '
        'AND (a.acquirer_id IS NULL OR a.id = (SELECT p.acquiring_account_id FROM this_pos_entries p LIMIT 1))',
        variables: [Variable.withInt(type), Variable.withBool(visibleToPos)],
        readsFrom: {accounts},
      ).get().then(
        (_) =>
            (select(accounts)..where(
                  (a) =>
                      a.type.equals(type) & a.visibleToPos.equals(visibleToPos),
                ))
                .get(),
      );

  Future<List<Account>> findByType(int type) =>
      (select(accounts)..where((a) => a.type.equals(type))).get();

  Future<Account?> findLastPosAccount() =>
      (select(accounts)
            ..where((a) => a.type.isIn([0, 1, 7]))
            ..orderBy([
              (a) => OrderingTerm.desc(a.updateTime),
              (a) => OrderingTerm.desc(a.id),
            ])
            ..limit(1))
          .getSingleOrNull();

  /// Записать **посчитанный вызывающим** остаток.
  ///
  /// # Сторож: бонусный счёт так трогать нельзя
  ///
  /// У бонусного счёта платёж уменьшает остаток, а не увеличивает
  /// ([AccountPosting]), и вызывающий, который считает остаток сам, обязан
  /// это знать. Не знали все, кроме одного: возврат вычитал по бонусному
  /// счёту так же, как по кассовому, и покупатель терял списанные бонусы
  /// второй раз. Поэтому попытка посчитать остаток бонусного счёта снаружи
  /// — `StateError`, а не тихая порча.
  ///
  /// [redemption] — это не разрешение обойти правило, а **подпись под тем,
  /// что род счёта учтён**. Тот, кто её ставит, обязан сам применить
  /// [AccountPosting.apply] или его смысл. Правильный путь для всех
  /// остальных — [post]: там знак выбирает правило, и выбрать его неверно
  /// вызывающий не может.
  ///
  /// Цена сторожа — одно чтение строки, которую вызывающий почти всегда
  /// уже прочитал: остаток он откуда-то взял.
  Future<int> updateBalance(
    int id,
    Decimal newBalance, {
    bool redemption = false,
  }) async {
    if (!redemption) {
      final account = await findById(id);
      if (account != null && AccountPosting.isRedemption(account.type)) {
        throw StateError(
          'Счёт $id бонусный (тип ${account.type}): у него платёж уменьшает '
          'остаток, а не увеличивает. Считать остаток снаружи нельзя — '
          'зовите AccountDao.post(id, движение) либо, если род счёта уже '
          'учтён, updateBalance(..., redemption: true).',
        );
      }
    }
    return (update(accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(value: Value(newBalance)),
    );
  }

  /// Провести **движение** по счёту: платёж несёт `+R`, сторно `−R`.
  ///
  /// Знак выбирает [AccountPosting.apply] по роду счёта, а не вызывающий.
  /// Ради этого метод и существует: дефект возврата исчезает по
  /// построению, а не правкой ветки в одном из двух мест.
  ///
  /// Счёта нет — движения нет: молча, как и у прежних вызывающих, каждый
  /// из которых проверял `account != null` и выходил.
  Future<void> post(int id, Decimal amount) async {
    final account = await findById(id);
    if (account == null) return;
    final newBalance = AccountPosting.apply(
      accountType: account.type,
      balance: account.value ?? Decimal.zero,
      amount: amount,
    );
    await updateBalance(id, newBalance, redemption: true);
  }

  /// Списать [amount] с кредитового сальдо счёта — **условной записью**,
  /// одним оператором SQL. Не хватило или кто-то опередил — `false`, и
  /// ни одна копейка не сдвинулась.
  ///
  /// # Зачем это не [post] с проверкой перед ним
  ///
  /// Потому что «проверить, потом записать» — это два действия, а между
  /// ними помещается второй кассир. Зачёт аванса (задача 23) читает
  /// остаток в раскладке, а списывает в транзакции продажи, и в это окно
  /// входит **второй чек того же покупателя**: оба прочитают 1000, оба
  /// разложат зачёт на 1000, и с внесённой тысячи зачтётся две. Ровно
  /// та беда, которую задача 8 измерила на занятии чека — там с чека на
  /// 1000 собиралось 2000.
  ///
  /// Условие живёт **в самом операторе**, а не рядом с ним: строка,
  /// изменившаяся между чтением и записью, не совпадёт с `value = ?`, и
  /// запись не состоится. Поэтому сравнивается не «хватает ли», а
  /// **то самое число, которое было прочитано**: «хватает» верно и для
  /// остатка, ставшего другим.
  ///
  /// # Почему арифметика в Dart, а не в SQL
  ///
  /// `accounts.value` — колонка `REAL`, и `value = value - ?` считал бы
  /// деньги в `double`. Вычитание идёт в `Decimal`, а в условие уезжает
  /// прочитанное число в том же виде, в каком оно лежит на диске
  /// (`DecimalConverter.toSql`): преобразование туда-обратно устойчиво,
  /// потому что `double.toString()` даёт кратчайшую запись, читающуюся
  /// обратно в то же число.
  ///
  /// Род счёта здесь **не спрашивается намеренно**: метод говорит не
  /// «проведи платёж», а «уменьши остаток на столько-то». Для бонусного
  /// счёта это было бы неверным словом — им ведает журнал
  /// (`BonusEntryDao`), и звать это отсюда нечему.
  Future<bool> claimCredit(int id, Decimal amount) async {
    if (amount <= Decimal.zero) return true;
    final account = await findById(id);
    if (account == null) return false;
    final balance = account.value ?? Decimal.zero;
    if (balance < amount) return false;
    const converter = DecimalConverter();
    final changed = await customUpdate(
      'UPDATE accounts SET value = ? WHERE id = ? AND value = ?',
      variables: [
        Variable<double>(converter.toSql(balance - amount)),
        Variable<int>(id),
        Variable<double>(converter.toSql(balance)),
      ],
      updates: {accounts},
    );
    return changed == 1;
  }

  /// Вернуть [amount] на кредитовое сальдо счёта — обратное [claimCredit].
  ///
  /// Существует затем, чтобы возврат чека, закрытого зачётом, читался
  /// **тем же словом**, что и сам зачёт. `post(id, +amount)` сделало бы
  /// то же число, но встало бы рядом с `post(id, -amount)` тендеров,
  /// которое значит противоположное: у тендера сторно — минус, у зачёта
  /// — плюс. Два одинаковых с виду вызова с разным смыслом в одном
  /// цикле — это способ перепутать их через год.
  ///
  /// Условия здесь нет и не нужно: возвращать на счёт можно всегда.
  Future<void> releaseCredit(int id, Decimal amount) async {
    if (amount <= Decimal.zero) return;
    final account = await findById(id);
    if (account == null) return;
    await updateBalance(
      id,
      (account.value ?? Decimal.zero) + amount,
      redemption: true,
    );
  }

  Future<Account?> findInkassaciyaDestination({int? excludeId}) async {
    for (final type in const [AccountType.customBank, AccountType.customCash]) {
      final candidates = await (select(
        accounts,
      )..where((a) => a.type.equals(type))).get();
      for (final acc in candidates) {
        if (acc.id != excludeId) return acc;
      }
    }
    return null;
  }

  Future<void> transfer({
    required int fromId,
    required int toId,
    required Decimal amount,
  }) async {
    final from = await findById(fromId);
    if (from == null) {
      throw Exception('Счёт-источник не найден: $fromId');
    }
    final to = await findById(toId);
    if (to == null) {
      throw Exception('Счёт-назначение не найден: $toId');
    }

    final fromBalance = from.value ?? Decimal.zero;
    if (fromBalance < amount) {
      throw Exception(
        'Недостаточно средств для перевода. Баланс: $fromBalance, запрошено: $amount',
      );
    }
    final toBalance = to.value ?? Decimal.zero;

    await updateBalance(fromId, fromBalance - amount);
    await updateBalance(toId, toBalance + amount);
  }

  Future<int> getNextId() async {
    final expr = accounts.id.max();
    final maxId = await (selectOnly(
      accounts,
    )..addColumns([expr])).map((row) => row.read(expr)).getSingleOrNull();
    return (maxId ?? 0) + 1;
  }

  Future<int> insertAccount(AccountsCompanion account) =>
      into(accounts).insert(account);

  Future<int> createPosAccount({required String name}) async {
    final id = await getNextId();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await insertAccount(
      AccountsCompanion(
        id: Value(id),
        type: const Value(AccountType.pos),
        name: Value(name),
        value: Value(Decimal.zero),
        visibleToPos: const Value(true),
        updateTime: Value(now),
      ),
    );

    return id;
  }

  Future<int> createTeleposMainAccount({required String name}) async {
    final id = await getNextId();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await insertAccount(
      AccountsCompanion(
        id: Value(id),
        type: const Value(AccountType.teleposMain),
        name: Value(name),
        value: Value(Decimal.zero),
        visibleToPos: const Value(true),
        updateTime: Value(now),
      ),
    );

    return id;
  }

  Future<int> createAcquiringAccount({
    required String name,
    required int acquirerId,
  }) async {
    final id = await getNextId();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await insertAccount(
      AccountsCompanion(
        id: Value(id),
        type: const Value(AccountType.customBank),
        acquirerId: Value(acquirerId),
        name: Value(name),
        value: Value(Decimal.zero),
        visibleToPos: const Value(true),
        updateTime: Value(now),
      ),
    );

    return id;
  }

  Future<int> count() {
    final expr = accounts.id.count();
    return (selectOnly(
      accounts,
    )..addColumns([expr])).map((row) => row.read(expr)!).getSingle();
  }

  Future<int> countByType(int type) {
    final expr = accounts.id.count();
    return (selectOnly(accounts)
          ..addColumns([expr])
          ..where(accounts.type.equals(type)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> countPosAccounts() {
    final expr = accounts.id.count();
    return (selectOnly(accounts)
          ..addColumns([expr])
          ..where(
            accounts.type.isIn([
              AccountType.pos,
              AccountType.customBank,
              AccountType.customCash,
              AccountType.cashback,
            ]),
          ))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> countVisibleToPos() {
    final expr = accounts.id.count();
    return (selectOnly(accounts)
          ..addColumns([expr])
          ..where(accounts.visibleToPos.equals(true)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<bool> hasAny() async {
    final c = await count();
    return c > 0;
  }

  Future<bool> hasPosAccount() async {
    final c = await countByType(AccountType.pos);
    return c > 0;
  }

  Future<AccountStats> getStats() async {
    final total = await count();
    final pos = await countByType(AccountType.pos);
    final bank = await countByType(AccountType.customBank);
    final cash = await countByType(AccountType.customCash);
    final agentMain = await countByType(AccountType.agentMain);
    final agentCashback = await countByType(AccountType.agentCashback);
    final teleposMain = await countByType(AccountType.teleposMain);
    final visible = await countVisibleToPos();

    return AccountStats(
      total: total,
      posAccounts: pos,
      bankAccounts: bank,
      cashAccounts: cash,
      agentMainAccounts: agentMain,
      agentCashbackAccounts: agentCashback,
      teleposMainAccounts: teleposMain,
      visibleToPos: visible,
    );
  }
}

class AccountStats {
  final int total;
  final int posAccounts;
  final int bankAccounts;
  final int cashAccounts;
  final int agentMainAccounts;
  final int agentCashbackAccounts;
  final int teleposMainAccounts;
  final int visibleToPos;

  const AccountStats({
    required this.total,
    required this.posAccounts,
    required this.bankAccounts,
    required this.cashAccounts,
    required this.agentMainAccounts,
    required this.agentCashbackAccounts,
    required this.teleposMainAccounts,
    required this.visibleToPos,
  });

  @override
  String toString() =>
      'total=$total (POS=$posAccounts, bank=$bankAccounts, cash=$cashAccounts, '
      'agentMain=$agentMainAccounts, agentCB=$agentCashbackAccounts, '
      'teleposMain=$teleposMainAccounts), visible=$visibleToPos';
}
