/// Отчёт смены различает **два вида на одном счёте** — задача 14, шаг 8.
///
/// # Почему это проба, а не мелочь
///
/// Задача 14 сняла отказ `payment_account_conflict`, а с ним — запрет на
/// две строки одного чека, лежащие на одном счёте. Запрет был не правилом
/// учёта, а следствием старого уникального ключа
/// `{receiptNo, posId, payeeAccountId}`.
///
/// **Цена снятия названа тем же шагом:** «отчёт смены суммирует по счёту,
/// и как только на один счёт лягут два вида, он сольёт их в одну строку.
/// Значит запрос получает второе измерение `kindId` — обязательная часть
/// той же задачи, а не „потом“».
///
/// Без этой пробы правка была бы принята на веру: набор зелен и с ней, и
/// без неё — читателя у отчёта в пробах не было вовсе.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/usecases/shift/custom_bank_payments_sum_use_case_impl.dart';
import 'package:telepos/domain/payment/payment_kind.dart';

void main() {
  late AppDatabase db;
  late CustomBankPaymentsSumUseCaseImpl sums;

  const posAccountId = 11;
  const bankAccountId = 12;
  const userId = 4;
  const openTime = 1000;
  const closeTime = 9000;

  Decimal d(String v) => Decimal.parse(v);

  Future<void> seedAccount(int id, int type) => db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          id: Value(id),
          type: type,
          name: Value('Счёт $id'),
          value: Value(Decimal.zero),
          visibleToPos: const Value(true),
        ),
      );

  Future<void> seedPayment({
    required int receiptNo,
    required int seq,
    required int accountId,
    required String amount,
    int? kindId,
  }) => db
      .into(db.payments)
      .insert(
        PaymentsCompanion.insert(
          userId: userId,
          receiptNo: Value(receiptNo),
          posId: const Value(1),
          payeeAccountId: accountId,
          amount: d(amount),
          time: 5000,
          seq: Value(seq),
          kindId: Value(kindId),
        ),
      );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedAccount(posAccountId, AccountType.pos);
    await seedAccount(bankAccountId, AccountType.customBank);
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            accountId: Value(posAccountId),
            cashBoxName: Value('Касса 1'),
          ),
        );
    sums = CustomBankPaymentsSumUseCaseImpl(db: db, logger: Talker());
  });

  tearDown(() => db.close());

  test('наличные и карта на ОДНОМ счёте — две строки, а не 1000', () async {
    // Ровно то, что старый ключ запрещал и что стало законным: касса без
    // видимых банковских счетов кладёт безналичную часть на счёт кассы.
    await seedPayment(
      receiptNo: 1,
      seq: 0,
      accountId: posAccountId,
      amount: '600',
      kindId: SystemPaymentKindIds.cash,
    );
    await seedPayment(
      receiptNo: 1,
      seq: 1,
      accountId: posAccountId,
      amount: '400',
      kindId: SystemPaymentKindIds.card,
    );

    final result = await sums.getPaymentSums(
      userId: userId,
      openTime: openTime,
      closeTime: closeTime,
    );

    final onPos = result.where((e) => e.accountId == posAccountId).toList();
    expect(
      onPos,
      hasLength(2),
      reason: 'до второго измерения здесь была одна строка на 1000, и '
          'кассир не мог узнать, сколько из неё наличными',
    );
    expect(
      {for (final e in onPos) e.kindId: e.amount},
      {
        SystemPaymentKindIds.cash: d('600'),
        SystemPaymentKindIds.card: d('400'),
      },
    );
  });

  test('имя вида берётся из справочника, то есть настраивается', () async {
    await db.paymentKindDao.put(
      SystemPaymentKinds.byId(
        SystemPaymentKindIds.card,
      ).copyWith(name: 'Банковская карта'),
    );
    await seedPayment(
      receiptNo: 1,
      seq: 0,
      accountId: bankAccountId,
      amount: '400',
      kindId: SystemPaymentKindIds.card,
    );

    final result = await sums.getPaymentSums(
      userId: userId,
      openTime: openTime,
      closeTime: closeTime,
    );

    expect(
      result.firstWhere((e) => e.accountId == bankAccountId).kindName,
      'Банковская карта',
    );
  });

  test('строка без вида приходит СВОЕЙ строкой, а не подмешанной', () async {
    // Строки до v41 и строки со снесённым счётом. «Не знаю» в отчёте
    // видно; подмешанное «наличные» — нет.
    await seedPayment(
      receiptNo: 1,
      seq: 0,
      accountId: bankAccountId,
      amount: '400',
      kindId: SystemPaymentKindIds.card,
    );
    await seedPayment(
      receiptNo: 2,
      seq: 0,
      accountId: bankAccountId,
      amount: '150',
    );

    final result = await sums.getPaymentSums(
      userId: userId,
      openTime: openTime,
      closeTime: closeTime,
    );

    final onBank = result.where((e) => e.accountId == bankAccountId).toList();
    expect(onBank, hasLength(2));
    // Строка без записанного вида выводится по роду счёта — банк даёт
    // «карту». Это законно: до v41 иначе было не узнать вовсе. Слитой в
    // одну строку она при этом не оказывается — сумма 400 остаётся
    // отдельной от 150.
    expect(onBank.map((e) => e.amount).toSet(), {d('400'), d('150')});
  });

  test('счёт без единой строки за смену называется нулём', () async {
    // Отсутствие строки и ноль читаются кассиром по-разному: «карта не
    // работала весь день» — как раз то, что отчёт обязан показать.
    final result = await sums.getPaymentSums(
      userId: userId,
      openTime: openTime,
      closeTime: closeTime,
    );

    expect(
      result.map((e) => e.accountId).toSet(),
      {posAccountId, bankAccountId},
    );
    expect(result.every((e) => e.amount == Decimal.zero), isTrue);
  });

  test('строки чужой смены и чужого времени не считаются', () async {
    await seedPayment(
      receiptNo: 1,
      seq: 0,
      accountId: posAccountId,
      amount: '600',
      kindId: SystemPaymentKindIds.cash,
    );
    await db
        .into(db.payments)
        .insert(
          PaymentsCompanion.insert(
            userId: 99,
            receiptNo: const Value(2),
            posId: const Value(1),
            payeeAccountId: posAccountId,
            amount: d('777'),
            time: 5000,
            kindId: const Value(SystemPaymentKindIds.cash),
          ),
        );

    final result = await sums.getPaymentSums(
      userId: userId,
      openTime: openTime,
      closeTime: closeTime,
    );

    expect(
      result.firstWhere((e) => e.accountId == posAccountId).amount,
      d('600'),
    );
  });
}
