import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/certificate_refund_tables.dart';
import 'package:telepos/data/database/tables/certificate_tables.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';

part 'certificate_dao.g.dart';

/// Сертификаты: чтение и **условные** записи.
///
/// # Здесь нет ни одного «прочитать, посчитать, записать»
///
/// И это единственное, ради чего стоит читать этот файл. Остаток
/// сертификата — то самое число, ради которого вся задача: списать его
/// дважды значит подарить товар, а не списать вовсе — значит подарить
/// сертификат. Оба исхода достижимы одним и тем же способом — чтением
/// остатка в память и записью посчитанного обратно, — потому что между
/// этими двумя действиями помещается чужая транзакция.
///
/// Поэтому [redeem] и [redeemRemainder] — **одна инструкция** `UPDATE ... WHERE`,
/// и решение принимает sqlite, а не Dart. Возвращается число затронутых
/// строк: ноль означает «условие не выполнилось», и вызывающий обязан на
/// него ответить, а не считать, что записалось.
///
/// # Почему нет метода «поставить остаток»
///
/// Потому что он и есть тот дефект, от которого этот файл сторожит.
/// Его отсутствие — не забывчивость: любой, кому он понадобится, обязан
/// сначала объяснить, чем его случай отличается.
@DriftAccessor(tables: [GiftCertificates, CertificateRefundLinks])
class CertificateDao extends DatabaseAccessor<AppDatabase>
    with _$CertificateDaoMixin {
  CertificateDao(super.db);

  Future<GiftCertificate?> byNumber(String number) async {
    final row = await (select(
      giftCertificates,
    )..where((c) => c.number.equals(number))).getSingleOrNull();
    return row == null ? null : toDomain(row);
  }

  Future<GiftCertificate?> byId(int id) async {
    final row = await (select(
      giftCertificates,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    return row == null ? null : toDomain(row);
  }

  Future<List<GiftCertificate>> all() async =>
      (await select(giftCertificates).get()).map(toDomain).toList();

  /// Завести сертификат. Возвращает его ид.
  ///
  /// Уникальный ключ по номеру бросит `SqliteException(2067)` на втором
  /// выпуске под тем же номером — вызывающий обязан это поймать и
  /// перевести в названный отказ ([certificateDuplicateNumberCode]).
  /// Ловить здесь было бы неправильно: DAO не знает, кто спрашивает, а
  /// отказ приходит значением только на пути провода.
  Future<int> insertCertificate({
    required String number,
    required Decimal nominal,
    required int issuedAt,
    required CertificateStatus status,
    String? pinHash,
    int? expiresAt,
    int? issuedReceiptNo,
    int? issuedPosId,
    int? issuedByUserId,
    int? liabilityAccountId,
  }) {
    final millis = GiftCertificate.millisOf(nominal);
    return into(giftCertificates).insert(
      GiftCertificatesCompanion.insert(
        number: number,
        nominalMillis: millis,
        balanceMillis: millis,
        status: status.code,
        issuedAt: issuedAt,
        pinHash: Value(pinHash),
        expiresAt: Value(expiresAt),
        issuedReceiptNo: Value(issuedReceiptNo),
        issuedPosId: Value(issuedPosId),
        issuedByUserId: Value(issuedByUserId),
        liabilityAccountId: Value(liabilityAccountId),
      ),
    );
  }

  /// **Условное гашение — единственный настоящий заслон от двойного
  /// списания.**
  ///
  /// Списывает [amount] с сертификата [number] **одной инструкцией**:
  /// условие «остаток не меньше просимого и сертификат жив» и запись
  /// нового остатка происходят внутри sqlite, между ними ничего не
  /// помещается. Возвращает число затронутых строк.
  ///
  /// `0` значит **ровно одно**: между тем, как вызывающий посмотрел на
  /// остаток, и этой инструкцией остаток перестал покрывать сумму. Причин
  /// две и обе законные — второй чек погасил сертификат первым, либо тот
  /// же сертификат назван в этой оплате дважды. Вызывающий обязан
  /// бросить: молчаливое «ну не списалось» — это отданный товар без
  /// денег.
  ///
  /// Состояние переводится **той же инструкцией**: остаток, ставший
  /// нулём, обязан стать [CertificateStatus.redeemed] в тот же миг, иначе
  /// между двумя записями сертификат с нулём выглядит активным.
  ///
  /// **Зовётся только внутри транзакции продажи.** Отдельно от неё
  /// гашение — это подарок, повторяемый бесконечно (упавшая после
  /// списания продажа) либо отданный даром товар (упавшее после продажи
  /// списание). Сторож — `certificate_atomicity_test.dart`.
  Future<int> redeem({
    required String number,
    required Decimal amount,
  }) async {
    final millis = GiftCertificate.millisOf(amount);
    if (millis <= 0) return 0;
    return customUpdate(
      'UPDATE gift_certificates '
      'SET balance_millis = balance_millis - ?1, '
      "    status = CASE WHEN balance_millis - ?1 <= 0 THEN 'redeemed' "
      '                  ELSE status END '
      "WHERE number = ?2 AND status = 'active' AND balance_millis >= ?1",
      variables: [Variable.withInt(millis), Variable.withString(number)],
      updates: {giftCertificates},
    );
  }

  // # Здесь был `restore` — снят решением заказчика 2026-09-16, пункт 2
  //
  // Он возвращал долю **на ту же бумажку** при возврате оплаченного ею
  // чека. Заказчик решение отменил: сертификат не восстанавливается никак,
  // а покупатель получает новую бумажку (`RefundUseCaseImpl`, ветвь
  // `RefundRoute.certificate`).
  //
  // **Метод удалён, а не оставлен без вызывающих.** Оставить его значило бы
  // завести ровно тот мёртвый код, который выглядит живым: полностью
  // рабочая, покрытая пробами дверь «положить деньги обратно на
  // сертификат», к которой однажды потянется рука — и решение 2 будет
  // отменено одной строкой, без единого красного теста. Его пробы
  // (`certificate_ledger_test.dart`, группа «возврат на сертификат») сняты
  // вместе с ним: проба к снятой работе зеленеет впустую.

  /// Проставить «срок вышел».
  ///
  /// Отдельным методом и **вне транзакции продажи** — разбор в докстринге
  /// [CertificateStatus.expired]: отказ откатил бы отметку вместе с
  /// транзакцией, и сертификат приходил бы активным на каждой следующей
  /// попытке.
  Future<int> markExpired(String number) => customUpdate(
    "UPDATE gift_certificates SET status = 'expired' "
    "WHERE number = ?1 AND status = 'active'",
    variables: [Variable.withString(number)],
    updates: {giftCertificates},
  );

  /// Отозвать сертификат: утерян, испорчен, выпущен по ошибке.
  Future<int> cancel(String number) => customUpdate(
    "UPDATE gift_certificates SET status = 'cancelled' "
    "WHERE number = ?1 AND status IN ('active', 'expired')",
    variables: [Variable.withString(number)],
    updates: {giftCertificates},
  );

  /// Бумажки, **проданные** чеком [receiptNo] — решение заказчика
  /// 2026-09-16, пункт 1.
  ///
  /// Связь «чек продажи → сертификат» держится **только** колонкой
  /// `issued_receipt_no`, и другой её нет: строки `Payments` этого чека
  /// говорят, чем за сертификат заплатили, а не какой сертификат выпустили.
  ///
  /// [posId] сверяется **мягко**: сегодняшний путь выпуска
  /// (`pay.certificateIssue` → `LocalCertificateIssuer.issue`) номера кассы
  /// не передаёт вовсе, и у всех выпущенных проводом бумажек
  /// `issued_pos_id` пуст. Требовать совпадения значило бы не найти ни
  /// одной — то есть молча не погасить ничего. Пустой номер кассы читается
  /// как «эта касса»; названный — сверяется.
  Future<List<GiftCertificate>> byIssuedReceipt({
    required int receiptNo,
    int? posId,
  }) async {
    final rows =
        await (select(giftCertificates)..where((c) {
          final byReceipt = c.issuedReceiptNo.equals(receiptNo);
          if (posId == null) return byReceipt;
          return byReceipt &
              (c.issuedPosId.equals(posId) | c.issuedPosId.isNull());
        })).get();
    return rows.map(toDomain).toList();
  }

  /// Погасить **весь остаток** бумажки — возврат чека, которым её продали.
  ///
  /// # Почему это не `redeem(остаток)`
  ///
  /// [redeem] списывает названную сумму и оставляет состояние на месте,
  /// пока остаток не дошёл до нуля. Здесь задача обратная: бумажка обязана
  /// перестать быть действующей **независимо** от того, сколько на ней
  /// лежало. Посчитать остаток снаружи и передать его в [redeem] значило бы
  /// вернуть ровно то окно между чтением и записью, ради закрытия которого
  /// весь этот файл и написан: между чтением остатка и списанием соседний
  /// чек успел бы погасить часть, и `WHERE balance >= :x` не выполнилось бы
  /// — бумажка осталась бы годной, а деньги за неё уже ушли бы покупателю.
  ///
  /// Поэтому остаток обнуляется **одной инструкцией**, без чтения: условие
  /// здесь не про сумму, а про состояние.
  ///
  /// Просроченная гасится тоже (`expired` в списке): срок вышел, но деньги
  /// за неё касса возвращает, и оставить её «истёкшей, но с остатком»
  /// значило бы оставить обязательство, которое кто-нибудь однажды
  /// восстановит. Отозванная (`cancelled`) не трогается — её уже погасил
  /// владелец, и второй раз гасить нечего.
  ///
  /// Возвращает число затронутых строк: `0` значит «гасить было нечего» —
  /// бумажка уже погашена или отозвана. Вызывающий обязан на него ответить.
  Future<int> redeemRemainder(String number) => customUpdate(
    'UPDATE gift_certificates '
    "SET balance_millis = 0, status = 'redeemed' "
    "WHERE number = ?1 AND status IN ('active', 'expired')",
    variables: [Variable.withString(number)],
    updates: {giftCertificates},
  );

  /// Записать связь «возврат → сертификат» — журнал v48.
  ///
  /// Уникальный ключ `{refundLocalId, sourceNumber}` бросит
  /// `SqliteException(2067)` на второй попытке связать тот же возврат с той
  /// же бумажкой. Ловить здесь нельзя по тому же доводу, что у
  /// [insertCertificate]: DAO не знает, кто спрашивает, а отказ приходит
  /// значением только на пути провода.
  Future<int> linkRefund({
    required int refundLocalId,
    required String sourceNumber,
    required Decimal amount,
    required CertificateRefundReason reason,
    required int time,
    String? issuedNumber,
  }) => into(certificateRefundLinks).insert(
    CertificateRefundLinksCompanion.insert(
      refundLocalId: refundLocalId,
      sourceNumber: sourceNumber,
      issuedNumber: Value(issuedNumber),
      amountMillis: GiftCertificate.millisOf(amount),
      reason: reason.code,
      time: time,
    ),
  );

  /// Сумма номиналов бумажек, **выпущенных** в окне [from]…[to] — строка
  /// «выпущено сертификатов» X- и Z-отчёта.
  ///
  /// # Почему источник — эта таблица, а не строки продажи
  ///
  /// Вопрос, на который отвечает строка отчёта, звучит так: **на сколько за
  /// смену выросло обязательство кассы**. Ответить на него можно из двух
  /// мест, и ответы разойдутся молча:
  ///
  /// 1. **Позиции чеков рода `ProductType.giftCertificate`.** Это цена, за
  ///    которую бумажку продали. Она не обязана равняться номиналу:
  ///    сертификат номиналом 10 000 продают за 9 000 по акции, и должна
  ///    касса всё равно 10 000. Сверх того, позиция рода «сертификат» — это
  ///    товар в каталоге, а выпуск бумажки — отдельная операция провода
  ///    (`pay.certificateIssue`), и позиция без выпуска (кассир пробил, а
  ///    бумажку не завёл) дала бы обязательство, которого нет ни на одной
  ///    бумажке.
  /// 2. **Строки оплаты чека, которым сертификат куплен.** Они говорят,
  ///    **чем** за бумажку заплатили (наличные, карта), а не какая бумажка
  ///    выпущена. Тот же вопрос — другой ответ.
  ///
  /// Обязательство берёт на себя `LocalCertificateIssuer.issue` — той же
  /// транзакцией, что и строку этой таблицы, движением `post(счёт,
  /// −номинал)`. Поэтому единственный источник, у которого число совпадает
  /// со счётом обязательства **по построению**, — `nominal_millis` этой
  /// таблицы. Сторож на совпадение —
  /// `test/data/payment/certificate_shift_totals_test.dart`.
  ///
  /// # Отозванные и погашенные считаются тоже
  ///
  /// Потому что [cancel] и [redeem] **не трогают счёт обязательства** сами:
  /// отзыв только переводит состояние, а гашение проходит строкой оплаты
  /// (её и считает вторая строка отчёта). Отбор по `status = 'active'` увёл
  /// бы число от счёта ровно на отозванные за смену бумажки.
  ///
  /// # Кассир сверяется строго у названных и мягко у пустых
  ///
  /// [userId] сверяется так же, как номер кассы в [byIssuedReceipt]:
  /// названный `issued_by_user_id` **обязан совпасть**, пустой читается
  /// как «эта смена».
  ///
  /// Так было написано с самого начала, но строгая половина правила до
  /// 2026-09-19 не работала ни на одной бумажке, выпущенной с планшета:
  /// обработчик `pay.certificateIssue` не передавал `userId` вовсе, и
  /// поле оставалось пустым у всех. Мягкость была не послаблением, а
  /// единственной действующей веткой, и выпуск **чужой смены** попадал в
  /// строку этой. Хвост закрыт правкой обработчика (разбор — в
  /// `TillOperations`, у самой записи карты); с тех пор отбор строг по
  /// делу, а не только по тексту запроса.
  ///
  /// Мягкость оставлена намеренно и снята не будет: у строк, выпущенных
  /// **до** той правки, поле пусто навсегда, и потребовать от них
  /// совпадения значило бы задним числом вычесть их из уже напечатанных
  /// отчётов. Обе ветки под сторожем —
  /// `test/data/shift/assemble_shift_certificates_test.dart`
  /// («выпуск чужой смены…» и «бумажка без кассира…»).
  ///
  /// # Чего это НЕ доказывает
  ///
  /// Не доказывает, что деньги за бумажки лежат в ящике: сертификат могли
  /// оплатить картой, а бумажку — выпустить переносом тиража вовсе без
  /// чека (`issued_receipt_no IS NULL`). Число отвечает только на вопрос
  /// «на сколько выросло обязательство», и печатается рядом с выручкой
  /// именно затем, чтобы их не складывали.
  ///
  /// Не доказывает и того, что обязательство на конец смены равно этому
  /// числу: бумажки живут годами, и остаток счёта копит все смены сразу.
  Future<Decimal> issuedNominalBetween({
    required int from,
    required int to,
    int? userId,
  }) async {
    final rows = await customSelect(
      'SELECT COALESCE(SUM(nominal_millis), 0) AS millis '
      'FROM gift_certificates '
      'WHERE issued_at BETWEEN ?1 AND ?2 '
      'AND (?3 IS NULL OR issued_by_user_id IS NULL '
      '     OR issued_by_user_id = ?3)',
      variables: [
        Variable.withInt(from),
        Variable.withInt(to),
        if (userId == null) const Variable<int>(null) else Variable.withInt(userId),
      ],
      readsFrom: {giftCertificates},
    ).get();
    // Целые тысячные складываются **целыми**: `SUM` по `INTEGER` точен по
    // построению, и деньги не проходят через `double` ни на одном шаге.
    final millis = rows.isEmpty ? 0 : (rows.first.read<int>('millis'));
    return GiftCertificate.amountOf(millis);
  }

  /// Чем этот возврат уже связан с сертификатами.
  Future<List<CertificateRefundLinkRow>> linksByRefund(int refundLocalId) =>
      (select(certificateRefundLinks)
            ..where((l) => l.refundLocalId.equals(refundLocalId)))
          .get();

  /// Связь этого возврата с этой бумажкой — **первая линия** заслона от
  /// двойного выпуска (вторая — уникальный ключ таблицы).
  Future<CertificateRefundLinkRow?> linkFor({
    required int refundLocalId,
    required String sourceNumber,
  }) =>
      (select(certificateRefundLinks)..where(
            (l) =>
                l.refundLocalId.equals(refundLocalId) &
                l.sourceNumber.equals(sourceNumber),
          ))
          .getSingleOrNull();

  /// Строка базы в доменную модель.
  ///
  /// Незнакомое состояние (строка приехала от кассы более новой сборки)
  /// читается как [CertificateStatus.cancelled], а не как `active`:
  /// «не знаю, что это» обязано отказывать в гашении, а не разрешать его.
  static GiftCertificate toDomain(GiftCertificateRow row) => GiftCertificate(
    id: row.id,
    number: row.number,
    nominal: GiftCertificate.amountOf(row.nominalMillis),
    balance: GiftCertificate.amountOf(row.balanceMillis),
    status:
        CertificateStatus.byCode(row.status) ?? CertificateStatus.cancelled,
    issuedAt: row.issuedAt,
    pinHash: row.pinHash,
    expiresAt: row.expiresAt,
    issuedReceiptNo: row.issuedReceiptNo,
    issuedPosId: row.issuedPosId,
    issuedByUserId: row.issuedByUserId,
    liabilityAccountId: row.liabilityAccountId,
  );
}
