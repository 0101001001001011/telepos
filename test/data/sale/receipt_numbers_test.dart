import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/sale/receipt_numbers.dart';

/// Задача 4 плана «продажа с браузерного терминала», круги правки 1–3.
///
/// **Круг 0 (первая версия):** `SaleInitiationUseCaseImpl` выдавал номер
/// чтением `findLastReceiptNo() + 1` прямо у вызывающего — гонка, две
/// одновременных начала чека получали один и тот же номер.
///
/// **Круг 1 (этот файл): первая версия самого исправления была новым
/// дефектом.** `next()` отдавал голый номер и *отдельно* вставлял
/// бронирующую строку без состояния (`userId = 0`, `state = NULL`) —
/// настоящие данные дописывались следующим, отдельным `UPDATE`. Между
/// этими двумя операциями существовало окно: авария в нём оставляла в
/// `Sales` строку без состояния навсегда, а `SaleDao.findLastReceiptNo()`
/// (голый `MAX(receipt_no)` без фильтра по состоянию, которым пользуется
/// живой пункт меню «Печать последнего чека») печатала её как настоящий
/// последний чек — дубликат на нулевую сумму, без товаров и оплат.
///
/// Правка: `withNext` не возвращает номер сам по себе — он прогоняет
/// переданную запись **внутри той же транзакции**, что вычислила номер.
/// Строка рождается сразу полной; шага «бронь, потом дозаполнение» не
/// существует.
///
/// **Круг 2: повтор ловил слишком широко.** Распознавание конфликта по
/// тексту `UNIQUE constraint failed` совпадало с конфликтом на **любом**
/// уникальном ключе, задетом внутри `writeSale` — например, на
/// `Payments.uniqueKeys`, который тоже содержит `receiptNo`/`posId`.
/// Такой повтор лечит не ту причину: маскирует настоящую ошибку и делает
/// вторую попытку с частично испорченными данными, да ещё и с новым
/// номером чека там, где номер был ни при чём. Правка сузила текст до
/// конфликта именно на `Sales(receipt_no, pos_id)`.
///
/// **Круг 3: у сужения не было потолка.** Узкое распознавание убрало одну
/// уже найденную причину ложного повтора, но `while (true)` без счётчика
/// не гарантирует, что «свой» конфликт по ключу продажи когда-нибудь
/// перестанет повторяться — появись второй писатель с фиксированным
/// номером, симптом тот же: тихий вечный цикл, теперь по «законной»
/// причине, которую узкое условие пропускает внутрь по определению.
/// Правка: [ReceiptNumbers.maxAttempts] попыток, по превышении —
/// [ReceiptNumberExhausted] с номером кассы и числом попыток.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertFullSale(int receiptNo, {int posId = 1}) async {
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: receiptNo,
            posId: posId,
            userId: 7,
            amount: Decimal.zero,
            time: 0,
            state: const Value(0),
            terminalId: const Value(7),
          ),
        );
    return receiptNo;
  }

  test('два одновременных начала чека получают разные номера', () async {
    final numbers = ReceiptNumbers(db);

    final issued = await Future.wait([
      numbers.withNext(1, insertFullSale),
      numbers.withNext(1, insertFullSale),
      numbers.withNext(1, insertFullSale),
      numbers.withNext(1, insertFullSale),
      numbers.withNext(1, insertFullSale),
    ]);

    expect(issued.toSet().length, 5, reason: 'номер выдан дважды');
  });

  test('номера растут последовательно от последнего выданного', () async {
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: 41,
            posId: 1,
            userId: 1,
            amount: Decimal.zero,
            time: 0,
            state: const Value(4),
          ),
        );

    final numbers = ReceiptNumbers(db);

    expect(await numbers.withNext(1, insertFullSale), 42);
    expect(await numbers.withNext(1, insertFullSale), 43);
  });

  test(
    'ГЛАВНЫЙ ТЕСТ (круг правки 1): авария между выдачей номера и записью '
    'настоящей строки не оставляет в базе сироту без состояния',
    () async {
      final numbers = ReceiptNumbers(db);

      // Симуляция краха: настоящая вставка внутри `writeSale` выполняется
      // (значит, будь `withNext` реализован через «бронь, потом отдельный
      // UPDATE», бронь уже легла бы в базу), а затем происходит исключение
      // — ровно то, чем для реальной кассы был бы обрыв процесса между
      // двумя отдельными операторами.
      await expectLater(
        numbers.withNext(1, (receiptNo) async {
          await db
              .into(db.sales)
              .insert(
                SalesCompanion.insert(
                  receiptNo: receiptNo,
                  posId: 1,
                  userId: 7,
                  amount: Decimal.zero,
                  time: 0,
                  state: const Value(0),
                  terminalId: const Value(7),
                ),
              );
          throw Exception('симулированный крах после вставки');
        }),
        throwsException,
      );

      final allSales = await db.select(db.sales).get();
      expect(
        allSales,
        isEmpty,
        reason:
            'вставка внутри writeSale не закоммичена без коммита всей '
            'транзакции — крах должен откатить всё целиком, не оставляя '
            'строку без состояния',
      );

      // Живой пункт меню «Печать последнего чека» опирается именно на
      // этот метод без фильтра по состоянию (additional_screen.dart) —
      // после краха ему нечего найти, а не «нашёл сироту».
      expect(await db.saleDao.findLastReceiptNo(), isNull);

      // Следующая настоящая выдача не перескакивает номер, потерянный при
      // крахе, — считает от того, что реально закоммичено (ничего),
      // и не спотыкается об удалённый черновик первичного ключа.
      expect(await numbers.withNext(1, insertFullSale), 1);
    },
  );

  test(
    'строка, вставленная через withNext, рождается сразу полной — '
    'без промежуточного состояния без состояния',
    () async {
      final numbers = ReceiptNumbers(db);
      final receiptNo = await numbers.withNext(3, (receiptNo) async {
        await db
            .into(db.sales)
            .insert(
              SalesCompanion.insert(
                receiptNo: receiptNo,
                posId: 3,
                userId: 42,
                amount: Decimal.zero,
                time: 0,
                state: const Value(0),
                terminalId: const Value(9),
              ),
            );
        return receiptNo;
      });

      final row = await db.saleDao.findByKey(receiptNo, 3);
      expect(row, isNotNull);
      expect(row!.userId, 42, reason: 'настоящий кассир, не заглушка');
      expect(row.state, 0);
      expect(row.terminalId, 9);
    },
  );

  test(
    'круг правки 2: конфликт по чужому уникальному ключу внутри writeSale '
    'не запускает повтор',
    () async {
      // `Payments.uniqueKeys` тоже содержит `{receiptNo, posId, ...}`
      // (`payment_tables.dart`) — конфликт на нём даёт тот же текст
      // `UNIQUE constraint failed`, что и конфликт на ключе продажи, но
      // это другая ошибка: номер чека здесь ни при чём. Узнав его за
      // «свой» конфликт, `withNext` повторил бы всю запись с новым
      // номером — маскируя настоящую ошибку и повторяя попытку с уже
      // частично написанными (испорченными) данными.
      final numbers = ReceiptNumbers(db);
      final accId = await db
          .into(db.accounts)
          .insert(AccountsCompanion.insert(name: const Value('cash'), type: 1));
      await db
          .into(db.payments)
          .insert(
            PaymentsCompanion.insert(
              userId: 1,
              payeeAccountId: accId,
              amount: Decimal.zero,
              time: 0,
              receiptNo: const Value(999),
              posId: const Value(1),
            ),
          );

      var attempts = 0;
      await expectLater(
        numbers.withNext(1, (receiptNo) async {
          attempts++;
          await insertFullSale(receiptNo);
          // Тот же ключ (999, 1, accId) уже занят строкой выше — конфликт
          // на Payments, не на Sales.
          await db
              .into(db.payments)
              .insert(
                PaymentsCompanion.insert(
                  userId: 1,
                  payeeAccountId: accId,
                  amount: Decimal.zero,
                  time: 0,
                  receiptNo: const Value(999),
                  posId: const Value(1),
                ),
              );
          return receiptNo;
        }),
        throwsA(isA<Exception>()),
      );

      expect(
        attempts,
        1,
        reason:
            'withNext повторил попытку на чужом конфликте — узкое '
            'распознавание не должно было счесть его конфликтом по ключу '
            'продажи',
      );
    },
  );

  test('разные рабочие места (posId) не мешают друг другу', () async {
    final numbers = ReceiptNumbers(db);

    final results = await Future.wait([
      numbers.withNext(1, (r) => insertFullSale(r, posId: 1)),
      numbers.withNext(2, (r) => insertFullSale(r, posId: 2)),
      numbers.withNext(1, (r) => insertFullSale(r, posId: 1)),
      numbers.withNext(2, (r) => insertFullSale(r, posId: 2)),
    ]);

    // Нумерация в этом дереве общая на кассу (сквозной MAX по всей Sales,
    // не по каждому posId отдельно) — важно, что при этом ни один номер не
    // выдан дважды даже вперемешку между рабочими местами.
    expect(results.toSet().length, 4, reason: 'номер выдан дважды');
  });

  test(
    'круг правки 3: исчерпание попыток бросает ReceiptNumberExhausted с '
    'кассой и числом попыток, а не тихо зависает',
    () async {
      // Навсегда занимает (1, 9) — `writeSale` ниже игнорирует выданный
      // номер и раз за разом пытается занять именно эту пару, гарантируя
      // конфликт по ключу продажи на каждой без единой попытки исключения.
      await insertFullSale(1, posId: 9);

      final numbers = ReceiptNumbers(db);
      var attempts = 0;
      await expectLater(
        numbers.withNext(9, (receiptNo) async {
          attempts++;
          return insertFullSale(1, posId: 9);
        }),
        throwsA(
          isA<ReceiptNumberExhausted>()
              .having((e) => e.posId, 'posId', 9)
              .having(
                (e) => e.attempts,
                'attempts',
                ReceiptNumbers.maxAttempts,
              ),
        ),
      );

      expect(
        attempts,
        ReceiptNumbers.maxAttempts,
        reason:
            'ровно потолок попыток — ни одной лишней, ни одной '
            'недостающей',
      );
    },
  );

  test(
    'ReceiptNumberExhausted называет кассу и число попыток в тексте — '
    'иначе оператору нечего сказать, кроме «зависло»',
    () {
      const error = ReceiptNumberExhausted(posId: 42, attempts: 8);
      expect(error.toString(), contains('42'));
      expect(error.toString(), contains('8'));
    },
  );
}
