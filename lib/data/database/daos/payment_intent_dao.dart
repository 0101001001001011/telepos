import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/payment_intent_tables.dart';
import 'package:telepos/domain/payment/payment_intent.dart';

part 'payment_intent_dao.g.dart';

/// Чтение и запись намерений оплаты QR/СБП.
///
/// **Метода `delete` здесь нет намеренно** — тот же довод, что у
/// `PaymentKindDao`, только дороже: строка намерения — единственный след
/// денег, которых, может быть, нет в `Payments`. Тихая чистка того, что
/// не разобрано, — способ потерять деньги покупателя без единой записи в
/// журнале. Разобранное помечается [markSettled] или [markAbandoned] и
/// остаётся.
@DriftAccessor(tables: [PaymentIntents])
class PaymentIntentDao extends DatabaseAccessor<AppDatabase>
    with _$PaymentIntentDaoMixin {
  PaymentIntentDao(super.db);

  /// Завести намерение — **или вернуть уже заведённое с тем же ключом**.
  ///
  /// Это и есть идемпотентность на уровне базы. `insertOrIgnore` плюс
  /// чтение по ключу: вторая вкладка, пришедшая с тем же [intentKey],
  /// получает **ту же строку**, а не вторую. Проверка «а нет ли уже» до
  /// вставки была бы гонкой с собой — ровно той, что развела двоих
  /// гонщиков в `payments` до задачи 8.
  ///
  /// Возвращаемая пара говорит, **новая** ли строка: без этого «повтор не
  /// создал второго» доказывается только числом строк, а число строк
  /// зелено и когда обе попытки записали одну и ту же строку дважды.
  Future<(PaymentIntent intent, bool created)> claim({
    required String intentKey,
    required String providerCode,
    required Decimal amount,
    required DateTime createdAt,
    int? posId,
    int? receiptNo,
    int? terminalId,
  }) async {
    final rows = await into(paymentIntents).insert(
      PaymentIntentsCompanion.insert(
        intentKey: intentKey,
        providerCode: providerCode,
        status: QrIntentStatus.created.code,
        amount: amount,
        createdAt: createdAt.millisecondsSinceEpoch,
        posId: Value(posId),
        receiptNo: Value(receiptNo),
        terminalId: Value(terminalId),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    final row = await byKey(intentKey);
    if (row == null) {
      // Недостижимо: `insertOrIgnore` либо вставил, либо строка уже была.
      // Оставлено падать, а не молчать: `null` здесь означал бы, что
      // намерение потеряно между вставкой и чтением, и подставлять на
      // этом месте пустое значение значило бы прятать потерю денег.
      throw StateError('намерение $intentKey не найдено сразу после claim');
    }
    return (row, rows > 0);
  }

  Future<PaymentIntent?> byKey(String intentKey) async {
    final row = await (select(
      paymentIntents,
    )..where((i) => i.intentKey.equals(intentKey))).getSingleOrNull();
    return row == null ? null : toDomain(row);
  }

  Future<PaymentIntent?> byId(int id) async {
    final row = await (select(
      paymentIntents,
    )..where((i) => i.id.equals(id))).getSingleOrNull();
    return row == null ? null : toDomain(row);
  }

  Future<PaymentIntent?> byProviderIntentId(String providerIntentId) async {
    final row =
        await (select(paymentIntents)
              ..where((i) => i.providerIntentId.equals(providerIntentId)))
            .getSingleOrNull();
    return row == null ? null : toDomain(row);
  }

  /// Намерения, про которые провайдер ещё не сказал последнего слова.
  ///
  /// Читается **при старте кассы**: именно эти строки и есть «подтвердить
  /// могли, пока нас не было».
  Future<List<PaymentIntent>> unresolved() async {
    final rows =
        await (select(paymentIntents)
              ..where(
                // Список собирается **из перечисления**, а не пишется
                // строками рядом. Строки, отставшие от перечисления на
                // один член, — порча, которой негде покраснеть: запрос
                // тихо перестанет находить новое незавершённое состояние,
                // и разбор при старте пройдёт мимо денег, ни разу не
                // пожаловавшись. Тот же довод, что у
                // `PaymentKindDerivation.sqlCase` в миграции v41.
                (i) => i.status.isIn(
                  QrIntentStatus.values
                      .where((s) => !s.isTerminal)
                      .map((s) => s.code)
                      .toList(),
                ),
              )
              ..orderBy([(i) => OrderingTerm(expression: i.createdAt)]))
            .get();
    return rows.map(toDomain).toList();
  }

  /// **Деньги без чека** — оплачено, а строки в `Payments` нет.
  ///
  /// Утверждение о двух полях (`status = paid` И `settled_at IS NULL`), а
  /// не о статусе: «есть оплаченные намерения» зелено и тогда, когда все
  /// они давно легли в чеки.
  Future<List<PaymentIntent>> orphanMoney() async {
    final rows =
        await (select(paymentIntents)
              ..where(
                (i) =>
                    i.status.equals(QrIntentStatus.paid.code) &
                    i.settledAt.isNull(),
              )
              ..orderBy([(i) => OrderingTerm(expression: i.createdAt)]))
            .get();
    return rows.map(toDomain).toList();
  }

  /// Последние намерения — **все**, включая завершённые, новые первыми.
  ///
  /// Отличается от [unresolved] и [orphanMoney] ровно тем, ради чего и
  /// заведена: те два отвечают на вопрос «где беда», а этот — на вопрос «а
  /// разговаривает ли касса с провайдером вообще». На исправной кассе первые
  /// два пусты, и эта пустота неотличима от «провайдер не настроен» — ровно
  /// та же ловушка, что разобрана на вкладке фискального оператора
  /// (`fiscal_diagnostics_tab.dart`, «две половины»).
  ///
  /// Предел обязателен: намерения не чистятся никогда (см. докстринг класса),
  /// и через год работы касса читала бы их все, чтобы показать десять.
  Future<List<PaymentIntent>> recent({int limit = 20}) async {
    final rows =
        await (select(paymentIntents)
              ..orderBy([
                (i) => OrderingTerm(
                  expression: i.createdAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(limit))
            .get();
    return rows.map(toDomain).toList();
  }

  Future<void> attachProviderIntent({
    required int id,
    required String providerIntentId,
    required QrIntentStatus status,
    String? qrPayload,
    DateTime? expiresAt,
  }) async {
    await (update(paymentIntents)..where((i) => i.id.equals(id))).write(
      PaymentIntentsCompanion(
        providerIntentId: Value(providerIntentId),
        status: Value(status.code),
        qrPayload: Value(qrPayload),
        expiresAt: Value(expiresAt?.millisecondsSinceEpoch),
      ),
    );
  }

  /// Записать состояние, названное провайдером.
  ///
  /// [confirmations] **увеличивается на единицу при каждом подтверждении**
  /// — в том числе при повторном. Второе подтверждение денег второй раз не
  /// берёт (за это отвечает [settledAt]), но пройти молча не имеет права:
  /// вебхук, приехавший дважды, — событие, о котором надо знать.
  Future<void> applyState({
    required int id,
    required QrIntentStatus status,
    Decimal? paidAmount,
    DateTime? confirmedAt,
    String? refusalCode,
    String? refusalMessage,
    bool countConfirmation = false,
  }) async {
    await (update(paymentIntents)..where((i) => i.id.equals(id))).write(
      PaymentIntentsCompanion(
        status: Value(status.code),
        paidAmount: paidAmount == null
            ? const Value.absent()
            : Value(paidAmount),
        confirmedAt: confirmedAt == null
            ? const Value.absent()
            : Value(confirmedAt.millisecondsSinceEpoch),
        refusalCode: Value(refusalCode),
        refusalMessage: Value(refusalMessage),
      ),
    );
    if (countConfirmation) {
      await customUpdate(
        'UPDATE payment_intents SET confirmations = confirmations + 1 '
        'WHERE id = ?',
        variables: [Variable.withInt(id)],
        updates: {paymentIntents},
      );
    }
  }

  /// Касса перестала ждать. **Состояние не трогается** — см. докстринг
  /// `QrIntentStatus.expired`.
  ///
  /// **Пишется один раз** — `abandoned_at IS NULL` в условии. Отметка
  /// значит «когда касса сдалась **впервые**»: повторная отмена (связь
  /// вернулась, кассир нажал «проверить снова») не имеет права сдвинуть её
  /// вперёд. Иначе отмена кассиром, повторённая через пять минут,
  /// читалась бы как исчерпанное терпение (`QrTenderPhase.of` различает
  /// их именно по этой отметке), а разбор беды видел бы время последней
  /// попытки вместо времени решения.
  Future<void> markAbandoned(int id, DateTime at) =>
      (update(
        paymentIntents,
      )..where((i) => i.id.equals(id) & i.abandonedAt.isNull())).write(
        PaymentIntentsCompanion(abandonedAt: Value(at.millisecondsSinceEpoch)),
      );

  /// Живые намерения чека — провайдер ещё не сказал последнего слова, и
  /// касса **не** перестала ждать.
  ///
  /// Читается перед заведением нового: два живых кода на одном чеке — это
  /// покупатель, который может заплатить по обоим, и касса, которая
  /// зачтёт только один.
  Future<List<PaymentIntent>> liveForReceipt({
    required int posId,
    required int receiptNo,
  }) async {
    final rows =
        await (select(paymentIntents)..where(
              (i) =>
                  i.posId.equals(posId) &
                  i.receiptNo.equals(receiptNo) &
                  i.abandonedAt.isNull() &
                  i.status.isIn(
                    QrIntentStatus.values
                        .where((s) => !s.isTerminal)
                        .map((s) => s.code)
                        .toList(),
                  ),
            ))
            .get();
    return rows.map(toDomain).toList();
  }

  /// Деньги легли в чек.
  ///
  /// **Условная запись по `settled_at IS NULL`**, а не безусловная: две
  /// попытки закрыть один чек не имеют права записать намерение в оба.
  /// Возвращает `true`, если записала именно эта попытка, — и `false`
  /// повторной, чтобы та не построила вторую строку `Payments` на те же
  /// деньги.
  Future<bool> markSettled({
    required int id,
    required int receiptNo,
    required DateTime at,
  }) async {
    final changed = await customUpdate(
      'UPDATE payment_intents SET settled_at = ?, settled_receipt_no = ? '
      'WHERE id = ? AND settled_at IS NULL',
      variables: [
        Variable.withInt(at.millisecondsSinceEpoch),
        Variable.withInt(receiptNo),
        Variable.withInt(id),
      ],
      updates: {paymentIntents},
    );
    return changed > 0;
  }

  /// Деньги по намерению **вернулись покупателю** — v51, ревизия
  /// 2026-09-19, дыра 3.
  ///
  /// # Почему запись, а не вывод при чтении
  ///
  /// До этой правки возврат QR не трогал намерение ничем: провайдер отдавал
  /// деньги, а строка оставалась `paid` со `settled_at` — то есть читалась
  /// как «деньги взяты и легли в чек». Разбор беды, вкладка диагностики и
  /// `QrTenderPhase.of` видели оплату там, где её уже нет. Вывести это
  /// чтением (сложить строки сторно по `terminal_transaction_id`) значило
  /// бы завести второе мнение о деньгах и держать его на совпадении двух
  /// идентификаторов — ровно тот класс расхождения, ради которого
  /// `routeBySeq` в возврате пишется, а не перевыводится.
  ///
  /// # Условная запись по `reversed_at IS NULL`
  ///
  /// Тот же приём и тот же довод, что у [markSettled] и [markAbandoned]:
  /// повтор не имеет права ни удвоить сумму, ни сдвинуть время вперёд.
  /// Возвращает `true`, если записала **эта** попытка.
  ///
  /// # Статус переводится, только когда вернулось ВСЁ
  ///
  /// `reversed` значит «оплата возвращена покупателю», и писать его при
  /// частичном возврате — соврать: на намерении осталась половина денег.
  /// Частичный возврат оставляет [QrIntentStatus.paid] и говорит о себе
  /// суммой. Сравнивается с подтверждённым (`paid_amount`), а не с
  /// запрошенным: провайдер вправе подтвердить меньше, чем просили, и
  /// вернуть больше подтверждённого нельзя.
  ///
  /// # Чего это НЕ доказывает
  ///
  /// Что сумма верна при **двух** возвратах по одному намерению. Она
  /// записывается один раз, и второй возврат сюда не попадёт — сегодня это
  /// верно, потому что второго возврата одного чека не бывает вовсе
  /// (`Refunds.uniqueKeys = {saleReceiptNo, salePosId}`, замер
  /// `test/data/refund/refund_repeat_partial_test.dart`). Снимут тот ключ —
  /// перечитать и это место: накопление придётся заводить настоящее.
  Future<bool> markReversed({
    required int id,
    required Decimal amount,
    required DateTime at,
  }) async {
    final row = await byId(id);
    if (row == null) return false;
    final confirmed = row.paidAmount ?? row.amount;
    final whole = amount >= confirmed;
    // Запись **типизованная**, а не `customUpdate` строкой: сумма обязана
    // пройти через `DecimalConverter`, и любой ручной `toDouble()` на этом
    // месте был бы деньгами в `double` (I159).
    final changed =
        await (update(
          paymentIntents,
        )..where((i) => i.id.equals(id) & i.reversedAt.isNull())).write(
          PaymentIntentsCompanion(
            reversedAmount: Value(amount),
            reversedAt: Value(at.millisecondsSinceEpoch),
            status: whole
                ? Value(QrIntentStatus.reversed.code)
                : const Value.absent(),
          ),
        );
    return changed > 0;
  }

  /// Строка → домен.
  ///
  /// Незнакомый `status` (строка приехала от более новой сборки) —
  /// `failed` с названной причиной, а не выдуманное состояние: объявить
  /// неизвестное оплаченным значило бы построить чек на деньгах, которых
  /// никто не подтверждал.
  static PaymentIntent toDomain(PaymentIntentEntry row) => PaymentIntent(
    id: row.id,
    intentKey: row.intentKey,
    providerCode: row.providerCode,
    amount: row.amount,
    paidAmount: row.paidAmount,
    status: QrIntentStatus.byCode(row.status) ?? QrIntentStatus.failed,
    providerIntentId: row.providerIntentId,
    qrPayload: row.qrPayload,
    posId: row.posId,
    receiptNo: row.receiptNo,
    terminalId: row.terminalId,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    expiresAt: row.expiresAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.expiresAt!),
    confirmedAt: row.confirmedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.confirmedAt!),
    abandonedAt: row.abandonedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.abandonedAt!),
    settledAt: row.settledAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.settledAt!),
    settledReceiptNo: row.settledReceiptNo,
    reversedAmount: row.reversedAmount,
    reversedAt: row.reversedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.reversedAt!),
    refusalCode: row.refusalCode,
    refusalMessage: row.refusalMessage,
    confirmations: row.confirmations,
  );
}
