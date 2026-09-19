import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/payment/payment_kind_catalog_impl.dart';
import 'package:telepos/domain/money/money_millis.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/payment/prepayment_intake.dart';
// Ради одного кода отказа: «покупателя нет в картотеке» уже назван и
// переведён для зачёта аванса (`payCustomerUnknownCode`,
// `loyalty_customer_unknown`). Второй код о том же самом дал бы кассиру две
// разные фразы на одну беду, в зависимости от того, вносит он аванс или
// зачитывает.
import 'package:telepos/domain/sale/payment_service.dart'
    show payCustomerUnknownCode, payPrepaymentAccountMissingCode;
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/usecases/payment/customer_payment_use_case.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

class CustomerPaymentUseCaseImpl implements CustomerPaymentUseCase {
  CustomerPaymentUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
    required FiscalService fiscal,
  }) : _db = db,
       _logger = logger,
       _fiscal = fiscal;

  final AppDatabase _db;
  final Talker _logger;

  /// Фискальный узел — **обязательный** довод, тот же приём, что у
  /// `LocalPaymentService`: касса без узла называет это словом
  /// `RefusingFiscalService`, а не молчанием.
  final FiscalService _fiscal;

  @override
  Future<CustomerPaymentResult> execute({
    required int agentId,
    required Decimal amount,
    required CustomerPaymentDecision decision,
    required int tenderKindId,
    String? note,
    String? intakeKey,
  }) async {
    try {
      if (amount <= Decimal.zero) {
        return CustomerPaymentResult.failed(
          'Сумма должна быть больше 0',
          code: prepaymentAmountInvalidCode,
        );
      }

      final agent = await _db.agentDao.findByLocalId(agentId);
      if (agent == null) {
        return CustomerPaymentResult.failed(
          'Покупатель не найден',
          code: payCustomerUnknownCode,
        );
      }

      // Чем приняты деньги — **живые деньги, и только они**. Зачёт или долг
      // здесь означали бы «покупатель внёс аванс сертификатом» — то есть
      // обналичивание бумажки через счёт покупателя.
      final tender = await PaymentKindCatalogImpl(_db).byId(tenderKindId);
      if (tender == null || tender.settlement != PaymentSettlement.tender) {
        return CustomerPaymentResult.failed(
          'Деньги покупателя принимаются наличными, картой или по QR',
          code: prepaymentTenderInvalidCode,
        );
      }

      final accountId = decision == CustomerPaymentDecision.investment
          ? agent.mainAccountId
          : agent.cashbackAccountId;

      if (accountId == null) {
        return CustomerPaymentResult.failed(
          'У покупателя нет соответствующего счёта',
        );
      }

      final account = await _db.accountDao.findById(accountId);
      if (account == null) {
        return CustomerPaymentResult.failed('Счёт не найден');
      }

      // Счёт кассы, **куда лягут принятые деньги**, выясняется здесь —
      // до первой записи, а не перед самой записью.
      //
      // # Почему не «где придётся»
      //
      // До 2026-09-18 его искали внутри `_creditTenderAccount`, и оба
      // неудачных исхода — нет счёта приёма, нет строки счёта — выходили
      // **молча**, уже после того, как сальдо покупателя выросло. Итог:
      // покупатель считается внёсшим, касса о деньгах не знает, ящик не
      // сходится, а в журнале одна строка `warning`, которую никто не
      // читает в момент приёма.
      //
      // Названный отказ **до** записи — единственная форма, при которой
      // «принять нечем» не превращается в «принято наполовину». Тем же
      // правилом живут все деньги кассы: проверить есть чем всегда, и
      // необязательность проверки была тут только способом её забыть.
      final tillAccountId = await _resolveAccountId(tenderKindId);
      final tillAccount = tillAccountId == null
          ? null
          : await _db.accountDao.findById(tillAccountId);
      if (tillAccount == null) {
        _logger.warning(
          'Customer payment: счёт приёма для вида $tenderKindId не найден — '
          'приём отказан до записи',
        );
        return CustomerPaymentResult.failed(
          'У кассы нет счёта для приёма этого вида оплаты — '
          'настройте счёт приёма',
          code: prepaymentTillAccountMissingCode,
        );
      }

      final currentBalance = account.value ?? Decimal.zero;
      final newBalance = currentBalance + amount;

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final written = await _writeMoney(
        intakeKey: intakeKey,
        accountId: accountId,
        newBalance: newBalance,
        redemption: decision != CustomerPaymentDecision.investment,
        amount: amount,
        tenderKindId: tenderKindId,
        note: note ?? '${decision.displayName} на счёт покупателя',
        tillAccount: tillAccount,
        now: now,
      );

      // Повтор уже принятой заявки: деньги не тронуты, ответ — **прежний
      // исход**. Разбор, почему не отказ, — в докстринге
      // [PrepaymentIntakeService.acceptPrepayment]; почему ответ собирается
      // здесь, а не выше по стеку, — в докстринге [_writeMoney].
      final replay = written.replay;
      if (replay != null) {
        _logger.info(
          'Customer payment: повтор заявки $intakeKey — отвечаем прежним '
          'исходом (проводка ${replay.operationId})',
        );
        return CustomerPaymentResult.created(
          transactionId: replay.operationId,
          newBalance: MoneyMillis.amount(replay.balanceMillis),
          fiscalSign: replay.fiscalSign,
          fiscalError: replay.fiscalError,
        );
      }

      final operationId = written.operationId!;

      _logger.info(
        'Customer payment created: $operationId, '
        'agent: $agentId, amount: $amount, decision: ${decision.name}, '
        'tender: ${tender.code}',
      );

      final fiscal = await _fiscalizeAdvance(
        operationId: operationId,
        decision: decision,
        amount: amount,
        balanceBefore: currentBalance,
        tender: tender,
        customerName: agent.name,
      );

      // Исход чека дописывается в память заявки **после** похода к
      // оператору — разбор окна в докстринге
      // `PrepaymentIntakeDao.rememberFiscal`.
      if (intakeKey != null) {
        await _db.prepaymentIntakeDao.rememberFiscal(
          intakeKey: intakeKey,
          sign: fiscal.sign,
          error: fiscal.error,
        );
      }

      return CustomerPaymentResult.created(
        transactionId: operationId,
        newBalance: newBalance,
        fiscalSign: fiscal.sign,
        fiscalError: fiscal.error,
      );
    } catch (e, st) {
      _logger.error('Error processing customer payment', e, st);
      return CustomerPaymentResult.failed('Ошибка обработки платежа: $e');
    }
  }

  /// Выдача аванса деньгами — дыра, найденная ревизией 2026-09-19.
  ///
  /// # Почему это здесь, а не в кассовых операциях
  ///
  /// Разбор «как возврат аванса происходит сегодня» дал ответ **никак**:
  /// пути не было вовсе (разведка — в докстринге контракта
  /// [CustomerPaymentUseCase.refundPrepayment]). Значит место выбирается,
  /// а не наследуется, и выбрано то же, что у приёма, по правилу этого
  /// файла: **всё, что решает судьбу денег покупателя, стоит рядом с
  /// записью этих денег**. Кассовая операция «Расход» знает ящик и не
  /// знает счёта покупателя; половина работы там оставила бы вторую
  /// половину ненаписанной ровно так, как это и было.
  ///
  /// # Почему отказы стоят ДО транзакции, а нехватка — внутри
  ///
  /// Всё, что можно узнать заранее (сумма, покупатель, вид оплаты, счета),
  /// проверяется до первой записи — тем же доводом, что у приёма
  /// (2026-09-18): «выдать нечем» не имеет права стать «выдано
  /// наполовину».
  ///
  /// Нехватка аванса — исключение, и это не непоследовательность:
  /// остаток, прочитанный до транзакции, между чтением и записью успевает
  /// измениться вторым кассиром, выдающим те же деньги. Поэтому она живёт
  /// условной записью `AccountDao.claimCredit` внутри транзакции — тем же
  /// приёмом, каким зачёт аванса в продаже закрыт от гонки двух чеков.
  ///
  /// # Чего этот метод НЕ доказывает
  ///
  /// Что в ящике есть наличные: сальдо счёта приёма — не содержимое
  /// ящика. И что кассир имеет право на выдачу: право не спрашивается
  /// здесь ни у приёма, ни у выдачи — это вход экрана, и он открыт.
  @override
  Future<CustomerPaymentResult> refundPrepayment({
    required int agentId,
    required Decimal amount,
    required int tenderKindId,
    int? intakeOperationId,
    String? note,
    String? refundKey,
  }) async {
    try {
      if (amount <= Decimal.zero) {
        return CustomerPaymentResult.failed(
          'Сумма должна быть больше 0',
          code: prepaymentAmountInvalidCode,
        );
      }

      final agent = await _db.agentDao.findByLocalId(agentId);
      if (agent == null) {
        return CustomerPaymentResult.failed(
          'Покупатель не найден',
          code: payCustomerUnknownCode,
        );
      }

      // Чем выдаются деньги — **живыми деньгами, и только ими**, тем же
      // правилом, что у приёма. Выдать аванс сертификатом или зачётом
      // значило бы переложить обязательство, а не вернуть деньги.
      final tender = await PaymentKindCatalogImpl(_db).byId(tenderKindId);
      if (tender == null || tender.settlement != PaymentSettlement.tender) {
        return CustomerPaymentResult.failed(
          'Аванс возвращается наличными, картой или по QR',
          code: prepaymentTenderInvalidCode,
        );
      }

      // Расчётный счёт, и только он. Бонусный счёт авансом не является:
      // бонус гасится скидкой, а не выдаётся деньгами (тот же довод, что
      // в [_fiscalizeAdvance]).
      final accountId = agent.mainAccountId;
      if (accountId == null) {
        return CustomerPaymentResult.failed(
          'У покупателя нет расчётного счёта — аванса на нём быть не может',
          code: payPrepaymentAccountMissingCode,
        );
      }

      final tillAccountId = await _resolveAccountId(tenderKindId);
      final tillAccount = tillAccountId == null
          ? null
          : await _db.accountDao.findById(tillAccountId);
      if (tillAccount == null) {
        _logger.warning(
          'Prepayment refund: счёта выдачи для вида $tenderKindId нет — '
          'выдача отказана до записи',
        );
        return CustomerPaymentResult.failed(
          'У кассы нет счёта для выдачи этого вида оплаты — настройте счёт',
          code: prepaymentTillAccountMissingCode,
        );
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final written = await _payOutMoney(
        refundKey: refundKey,
        accountId: accountId,
        amount: amount,
        tenderKindId: tenderKindId,
        note: note ?? 'Возврат аванса покупателю',
        tillAccount: tillAccount,
        now: now,
      );

      // Повтор уже исполненной заявки: деньги не тронуты, ответ — **прежний
      // исход**. Разбор, почему не отказ, — в докстринге
      // [PrepaymentRefundService.payOutPrepayment]; почему ответ собирается
      // здесь, а не выше по стеку, — в докстринге [_writeMoney] (довод тот
      // же и на выдаче).
      final replay = written.replay;
      if (replay != null) {
        _logger.info(
          'Prepayment refund: повтор заявки $refundKey — отвечаем прежним '
          'исходом (проводка ${replay.operationId})',
        );
        return CustomerPaymentResult.created(
          transactionId: replay.operationId,
          newBalance: MoneyMillis.amount(replay.balanceMillis),
          fiscalSign: replay.fiscalSign,
          fiscalError: replay.fiscalError,
        );
      }

      final operationId = written.operationId;
      if (operationId == null) {
        _logger.warning(
          'Prepayment refund: на счёте $accountId нет $amount — выдача '
          'отказана, деньги не тронуты',
        );
        return CustomerPaymentResult.failed(
          'На счёте покупателя нет такой суммы аванса',
          code: prepaymentRefundExceedsBalanceCode,
        );
      }

      _logger.info(
        'Prepayment refund created: $operationId, agent: $agentId, '
        'amount: $amount, tender: ${tender.code}',
      );

      final fiscal = await _fiscalizeAdvanceRefund(
        operationId: operationId,
        intakeOperationId: intakeOperationId,
        amount: amount,
        tender: tender,
        customerName: agent.name,
      );

      // Исход документа дописывается в память заявки **после** похода к
      // оператору — то же окно и тот же довод, что у приёма
      // (`PrepaymentRefundDao.rememberFiscal`).
      if (refundKey != null) {
        await _db.prepaymentRefundDao.rememberFiscal(
          refundKey: refundKey,
          sign: fiscal.sign,
          error: fiscal.error,
        );
      }

      final account = await _db.accountDao.findById(accountId);
      return CustomerPaymentResult.created(
        transactionId: operationId,
        newBalance: account?.value ?? Decimal.zero,
        fiscalSign: fiscal.sign,
        fiscalError: fiscal.error,
      );
    } catch (e, st) {
      _logger.error('Error processing prepayment refund', e, st);
      return CustomerPaymentResult.failed('Ошибка выдачи аванса: $e');
    }
  }

  /// Четыре записи выдачи — **одной транзакцией**, как у приёма.
  ///
  /// # Что означает каждый из трёх исходов
  ///
  /// - `replay != null` — эту заявку касса уже исполняла, и деньги **не
  ///   тронуты**: наверх уходит прежний исход;
  /// - `operationId != null` — выдача записана целиком;
  /// - оба `null` — условная запись не состоялась, то есть аванса не
  ///   хватило **в момент выдачи**. Транзакция откачена целиком: ни
  ///   проводки, ни движения по счёту кассы, ни памяти о заявке.
  ///
  /// Порядок внутри не случаен: память заявки читается **первой**, а счёт
  /// покупателя списывается **до** всего остального. Условие живёт в нём, и
  /// всё прочее пишется только после того, как деньги действительно сняты.
  ///
  /// # Почему заслон двойной — и почему на выдаче он дороже
  ///
  /// [PrepaymentRefundDao.byKey] внутри транзакции — **первая линия**: она
  /// узнаёт повтор, доехавший после того, как первая попытка закончилась.
  /// Это и есть наблюдённый случай: провод рвётся уже после того, как
  /// деньги выданы, вкладка видит отказ, кассир жмёт «Выдать» снова.
  ///
  /// Вторая линия — уникальный ключ таблицы, и без неё первая дырява: два
  /// кадра, доехавшие одновременно, оба читают пустую память и оба идут
  /// выдавать. Sqlite разводит их на записи, вторая транзакция падает
  /// `UNIQUE constraint failed` и **откатывается целиком** — деньги второй
  /// раз не выданы. Здесь это падение перехватывается и превращается в тот
  /// же повтор.
  ///
  /// Ловится **именно** нарушение уникальности, а не всякая ошибка: любая
  /// другая означает, что деньги не выданы по неизвестной причине, и
  /// отвечать на неё «выдано» было бы худшим из возможного.
  ///
  /// Тот же приём, что у приёма ([_writeMoney]), и переписан он здесь
  /// заново, а не вынесен в общий метод, по одному доводу: общий метод
  /// пришлось бы учить роду записи доводом — то есть завести ровно то
  /// место, где однажды подставят не тот род и спишут вместо начисления.
  Future<({int? operationId, PrepaymentRefundRow? replay})> _payOutMoney({
    required String? refundKey,
    required int accountId,
    required Decimal amount,
    required int tenderKindId,
    required String note,
    required Account tillAccount,
    required int now,
  }) async {
    try {
      return await _db.transaction(() async {
        if (refundKey != null) {
          final seen = await _db.prepaymentRefundDao.byKey(refundKey);
          if (seen != null) return (operationId: null, replay: seen);
        }

        final claimed = await _db.accountDao.claimCredit(accountId, amount);
        if (!claimed) return (operationId: null, replay: null);

        final operationId = await _db.cashOperationDao.db
            .into(_db.cashOperations)
            .insert(
              CashOperationsCompanion.insert(
                amount: amount,
                // Род проводки — **расход**, а не приход со знаком минус:
                // смена считает наличные по роду (`CashInOutType.index`), и
                // приход на минус прибавил бы к выручке отрицательное число
                // вместо того, чтобы уменьшить её расходом.
                type: CashInOutType.expense.index,
                accountId: Value(accountId),
                note: Value(note),
                docTime: Value(now),
                state: const Value(1),
                kindId: Value(tenderKindId),
              ),
            );

        final current = tillAccount.value ?? Decimal.zero;
        await _db.accountDao.updateBalance(tillAccount.id, current - amount);

        if (refundKey != null) {
          // Сальдо перечитывается **внутри** транзакции, а не считается
          // вычитанием: `claimCredit` — условная запись, и то, что на счёте
          // осталось, знает она, а не арифметика над снимком, сделанным до
          // неё.
          final account = await _db.accountDao.findById(accountId);
          await _db.prepaymentRefundDao.remember(
            refundKey: refundKey,
            operationId: operationId,
            balance: account?.value ?? Decimal.zero,
            time: now,
          );
        }

        return (operationId: operationId, replay: null);
      });
    } catch (error) {
      if (refundKey == null ||
          !AppDatabase.isExpectedSchemaError(error, 'UNIQUE constraint')) {
        rethrow;
      }
      final seen = await _db.prepaymentRefundDao.byKey(refundKey);
      if (seen == null) rethrow;
      _logger.warning(
        'Prepayment refund: заявка $refundKey исполнена одновременно дважды '
        '— вторая транзакция откачена, отвечаем прежним исходом',
      );
      return (operationId: null, replay: seen);
    }
  }

  /// Фискальный **возврат** выдачи — той же настройкой, что приём.
  ///
  /// Зеркало [_fiscalizeAdvance] во всём, включая довод «отказ оператора
  /// денег не отменяет»: деньги к этому моменту выданы, и отказ уходит
  /// словом в исходе и строкой журнала.
  ///
  /// Долг здесь не вычитается, в отличие от приёма, и это не пропуск:
  /// выдать можно только то, что лежит кредитовым сальдо, а условная
  /// запись `claimCredit` отказала бы раньше. Должнику выдавать нечего.
  Future<({String? sign, String? error})> _fiscalizeAdvanceRefund({
    required int operationId,
    required int? intakeOperationId,
    required Decimal amount,
    required PaymentKind tender,
    required String? customerName,
  }) async {
    final settings = await _db.thisPosDao.offsetFiscalSettings();
    // **Та же настройка, что у приёма.** Касса, где приём не фискальный, а
    // выдача фискальная, показала бы оператору возврат денег, которые к
    // нему никогда не приходили.
    if (!settings.fiscalizePrepaymentReceipt) return (sign: null, error: null);
    if (!await _fiscal.isEnabled()) return (sign: null, error: null);

    final paymentKind = tender.fiscalTreatment.toFiscalKind();
    if (paymentKind == null) {
      _logger.error(
        'Prepayment refund $operationId: у вида ${tender.code} нет вида '
        'оплаты оператора (${tender.fiscalTreatment.code}) — документ '
        'возврата аванса не выписан',
      );
      return (sign: null, error: 'fiscal_treatment_not_a_payment');
    }

    final name = customerName == null || customerName.trim().isEmpty
        ? 'Возврат аванса (предоплаты)'
        : 'Возврат аванса (предоплаты) — ${customerName.trim()}';
    final result = await _fiscal.fiscalizePrepaymentRefund(
      operationId: operationId,
      intakeOperationId: intakeOperationId,
      amount: amount,
      paymentKind: paymentKind,
      positionName: name,
    );
    if (result.success) {
      _logger.info(
        'Prepayment refund $operationId: документ возврата $amount '
        '${result.queued ? '(в очереди)' : 'ok'} sign=${result.fiscalSign}',
      );
      return (sign: result.fiscalSign, error: null);
    }
    _logger.error(
      'Prepayment refund $operationId: документ возврата не выписан — '
      '${result.errorCode.name} ${result.errorMessage}',
    );
    return (sign: null, error: result.errorCode.name);
  }

  /// Деньги ложатся туда, **чем приняты**: наличные — в кассу, карта — на
  /// счёт эквайринга.
  ///
  /// # Почему это здесь, а не в контроллере экрана
  ///
  /// До 2026-09-18 этот шаг делал `CustomerPaymentController` — **после**
  /// того, как юзкейс вернул успех. Пока приём аванса умел один только
  /// кассовый диалог, разницы не было видно; операция провода
  /// (`pay.prepaymentIntake`) экрана не имеет и контроллера не зовёт, и
  /// деньги, принятые с планшета, не попадали бы в кассу вовсе: счёт
  /// покупателя вырос бы, а ящик на ту же сумму не сошёлся.
  ///
  /// Повторить шаг в обработчике значило бы завести **второй путь к
  /// деньгам** — ровно то, чего эта работа не имеет права делать. Поэтому
  /// шаг переехал в единственную дверь: теперь приём аванса целиком — это
  /// [execute], кто бы его ни звал.
  ///
  /// **Счёт приходит доводом, а не ищется здесь** (2026-09-18). До этого
  /// метод сам искал счёт и молча выходил, если не нашёл, — уже после того,
  /// как сальдо покупателя выросло: приём «наполовину», о котором знал
  /// только журнал. Теперь [execute] выясняет счёт **до первой записи** и
  /// отказывает названной причиной, а сюда доезжает уже найденная строка.
  /// Ветки «нет счёта» здесь не осталось вовсе — и завестись ей негде.
  /// Все три записи денег и ключ заявки — **одной транзакцией**.
  ///
  /// # Почему транзакция, а не три вызова подряд
  ///
  /// До 2026-09-18 это были три отдельные записи: сальдо покупателя, строка
  /// `cash_operations`, счёт приёма. Падение между ними оставляло приём
  /// «наполовину» — ровно ту беду, которую отказ по ненайденному счёту
  /// (`prepayment_till_account_missing`) закрыл только для **одной** из
  /// причин. Транзакция закрывает её для всех сразу, и делает это тем же
  /// правилом, каким живёт корзина: изменение и ключ повтора пишутся
  /// вместе или не пишутся вовсе (`LocalCartService`, `Sales.lastCommandKey`).
  ///
  /// # Почему заслон двойной
  ///
  /// [PrepaymentIntakeDao.byKey] внутри транзакции — **первая линия**: она
  /// узнаёт повтор, доехавший после того, как первая попытка закончилась,
  /// и это и есть наблюдённый случай (провод рвётся, кассир жмёт снова).
  ///
  /// Вторая линия — уникальный ключ таблицы, и без неё первая дырява: два
  /// кадра, доехавшие одновременно, оба читают пустую память и оба идут
  /// принимать. Sqlite разводит их на записи, вторая транзакция падает
  /// `UNIQUE constraint failed` и **откатывается целиком** — деньги второй
  /// раз не записаны. Здесь это падение перехватывается и превращается в
  /// тот же повтор: память перечитывается, и наверх уходит прежний исход.
  ///
  /// Ловится **именно** нарушение уникальности, а не всякая ошибка: любая
  /// другая означает, что деньги не записаны по неизвестной причине, и
  /// отвечать на неё «принято» было бы худшим из возможного.
  ///
  /// # Почему ответ повтору собирается здесь, а не выше
  ///
  /// Потому что выше его собирали бы дважды — в [acceptPrepayment] и в
  /// кассовом диалоге, — и два ответа на один вопрос разошлись бы в первую
  /// же правку. Тот же довод, по которому [acceptPrepayment] не содержит ни
  /// строки работы.
  Future<({int? operationId, PrepaymentIntakeRow? replay})> _writeMoney({
    required String? intakeKey,
    required int accountId,
    required Decimal newBalance,
    required bool redemption,
    required Decimal amount,
    required int tenderKindId,
    required String note,
    required Account tillAccount,
    required int now,
  }) async {
    try {
      return await _db.transaction(() async {
        if (intakeKey != null) {
          final seen = await _db.prepaymentIntakeDao.byKey(intakeKey);
          if (seen != null) return (operationId: null, replay: seen);
        }

        // Пополнение бонусного счёта покупателя — единственный путь, где
        // эта служба трогает бонусы. Род счёта учтён: пополнение их
        // **увеличивает**, как и на расчётном.
        await _db.accountDao.updateBalance(
          accountId,
          newBalance,
          redemption: redemption,
        );

        final operationId = await _db.cashOperationDao.db
            .into(_db.cashOperations)
            .insert(
              CashOperationsCompanion.insert(
                amount: amount,
                type: 0,
                accountId: Value(accountId),
                note: Value(note),
                docTime: Value(now),
                state: const Value(1),
                kindId: Value(tenderKindId),
              ),
            );

        await _creditTenderAccount(tillAccount, amount);

        if (intakeKey != null) {
          await _db.prepaymentIntakeDao.remember(
            intakeKey: intakeKey,
            operationId: operationId,
            balance: newBalance,
            time: now,
          );
        }

        return (operationId: operationId, replay: null);
      });
    } catch (error) {
      if (intakeKey == null ||
          !AppDatabase.isExpectedSchemaError(error, 'UNIQUE constraint')) {
        rethrow;
      }
      final seen = await _db.prepaymentIntakeDao.byKey(intakeKey);
      if (seen == null) rethrow;
      _logger.warning(
        'Customer payment: заявка $intakeKey принята одновременно дважды — '
        'вторая транзакция откачена, отвечаем прежним исходом',
      );
      return (operationId: null, replay: seen);
    }
  }

  Future<void> _creditTenderAccount(Account account, Decimal amount) async {
    final current = account.value ?? Decimal.zero;
    await _db.accountDao.updateBalance(account.id, current + amount);
  }

  Future<int?> _resolveAccountId(int tenderKindId) async {
    final thisPos = await _db.thisPosDao.get();
    if (tenderKindId != SystemPaymentKindIds.cash) {
      final acquiring = thisPos?.acquiringAccountId;
      if (acquiring != null) return acquiring;
      final banks = await _db.accountDao.findByType(AccountType.customBank);
      if (banks.isNotEmpty) return banks.first.id;
    }
    final fromPos = thisPos?.accountId;
    if (fromPos != null) return fromPos;

    final posAccounts = await _db.accountDao.findByType(AccountType.pos);
    if (posAccounts.isNotEmpty) return posAccounts.first.id;
    return null;
  }

  /// Приём аванса по проводу — требование заказчика 2026-09-18.
  ///
  /// Здесь нет ни одной строки работы: всё, что она делает, — зовёт
  /// [execute] с решением [CustomerPaymentDecision.investment] и переводит
  /// её исход в значение контракта либо в названный отказ. Иначе у денег
  /// появился бы второй путь, отличающийся от первого ровно настолько,
  /// насколько разойдутся два куска кода, которые никто не сверяет.
  ///
  /// Решение прибито к авансу и доводом не приходит — разбор в докстринге
  /// [PrepaymentIntakeService].
  ///
  /// # Ключ повтора проверяется здесь, а узнаётся ниже
  ///
  /// Здесь — только «ключ вообще есть?»: кадр без ключа отказывается
  /// названной причиной **до первой записи**, потому что принять его значит
  /// принять деньги, повтор которых опознать будет нечем (разбор — в
  /// докстринге [prepaymentIntakeKeyMissingCode]).
  ///
  /// Само опознание повтора живёт внутри транзакции денег
  /// ([_writeMoney]) — и не может жить здесь: проверка «уже принято?»,
  /// сделанная до транзакции, отделена от записи окном, в которое влезает
  /// второй такой же кадр. Отсюда правило этого файла: **всё, что решает,
  /// принимать ли деньги, стоит рядом с записью денег**.
  @override
  Future<PrepaymentIntakeOutcome> acceptPrepayment(
    PrepaymentIntakeRequest ask,
  ) async {
    if (ask.key.trim().isEmpty) {
      _logger.warning(
        'Prepayment intake: кадр без ключа повтора — отказ до записи',
      );
      throw WireRefusal(
        prepaymentIntakeKeyMissingCode,
        'заявка приёма аванса пришла без ключа повтора',
      );
    }

    final result = await execute(
      agentId: ask.customerId,
      amount: ask.amount,
      decision: CustomerPaymentDecision.investment,
      tenderKindId: ask.tenderKindId,
      note: ask.note,
      intakeKey: ask.key,
    );

    if (!result.success) {
      throw WireRefusal(
        result.refusalCode ?? prepaymentIntakeFailedCode,
        result.errorMessage ?? 'приём аванса отказан',
      );
    }

    return PrepaymentIntakeOutcome(
      // `!` здесь безопасны по построению: успешный исход заводится
      // единственной фабрикой [CustomerPaymentResult.created], у которой
      // оба поля обязательны. Умолчание нулём соврало бы про номер
      // проводки, а нулевым сальдо — про деньги.
      operationId: result.transactionId!,
      balance: result.newBalance!,
      fiscalSign: result.fiscalSign,
      fiscalError: result.fiscalError,
    );
  }

  /// Выдача аванса по проводу — решение заказчика 2026-09-18.
  ///
  /// Здесь нет ни одной строки работы: всё, что она делает, — зовёт
  /// [refundPrepayment] и переводит её исход в значение контракта либо в
  /// названный отказ. Иначе у денег, выходящих из кассы, появился бы второй
  /// путь, отличающийся от первого ровно настолько, насколько разойдутся два
  /// куска кода, которые никто не сверяет. Тот же приём и тот же довод, что
  /// у [acceptPrepayment].
  ///
  /// # Ключ повтора проверяется здесь, а узнаётся ниже
  ///
  /// Здесь — только «ключ вообще есть?»: кадр без ключа отказывается
  /// названной причиной **до первой записи**, потому что исполнить его
  /// значит выдать деньги, повтор которых опознать будет нечем.
  ///
  /// Само опознание повтора живёт внутри транзакции денег ([_payOutMoney]) —
  /// и не может жить здесь: проверка «уже выдано?», сделанная до транзакции,
  /// отделена от записи окном, в которое влезает второй такой же кадр.
  ///
  /// # Чего этот метод НЕ доказывает
  ///
  /// Что в ящике есть наличные: касса знает сальдо счёта выдачи, а не
  /// содержимое ящика. Кассир, исполняющий эту заявку с планшета, стоит у
  /// того же ящика — пересчитать его вместо него некому.
  @override
  Future<PrepaymentRefundOutcome> payOutPrepayment(
    PrepaymentRefundRequest ask,
  ) async {
    if (ask.key.trim().isEmpty) {
      _logger.warning(
        'Prepayment refund: кадр без ключа повтора — отказ до записи',
      );
      throw WireRefusal(
        prepaymentRefundKeyMissingCode,
        'заявка выдачи аванса пришла без ключа повтора',
      );
    }

    final result = await refundPrepayment(
      agentId: ask.customerId,
      amount: ask.amount,
      tenderKindId: ask.tenderKindId,
      intakeOperationId: ask.intakeOperationId,
      note: ask.note,
      refundKey: ask.key,
    );

    if (!result.success) {
      throw WireRefusal(
        result.refusalCode ?? prepaymentRefundFailedCode,
        result.errorMessage ?? 'выдача аванса отказана',
      );
    }

    return PrepaymentRefundOutcome(
      // `!` здесь безопасны по построению: успешный исход заводится
      // единственной фабрикой [CustomerPaymentResult.created], у которой оба
      // поля обязательны. Умолчание нулём соврало бы про номер проводки, а
      // нулевым сальдо — про деньги.
      operationId: result.transactionId!,
      balance: result.newBalance!,
      fiscalSign: result.fiscalSign,
      fiscalError: result.fiscalError,
    );
  }

  /// Фискальный чек **приёма аванса** — решение заказчика 2026-09-14, п.4.
  ///
  /// # Что считается авансом
  ///
  /// Деньги на расчётный счёт покупателя ([CustomerPaymentDecision
  /// .investment]) — тот самый счёт, с которого вид «Предоплата» делает
  /// зачёт. **Сверх долга**: покупатель с долгом 300, внёсший 1000, гасит
  /// долг 300 и вносит аванс 700. Чек выписывается на 700 — погашение долга
  /// авансом не является, и назвать его «Аванс (предоплата)» значило бы
  /// соврать оператору в наименовании. Как фискализовать погашение долга —
  /// вопрос бухгалтеру (отчёт дорожки A), здесь не решается.
  ///
  /// Пополнение бонусного счёта ([CustomerPaymentDecision.deposit]) —
  /// не аванс: бонус гасится скидкой, а не зачётом.
  ///
  /// # Отказ оператора денег не отменяет
  ///
  /// Деньги к этому моменту записаны; отказ возвращается словом в исходе и
  /// строкой журнала. Тот же довод, что у продажи (`SaleOutcome.fiscal`).
  Future<({String? sign, String? error})> _fiscalizeAdvance({
    required int operationId,
    required CustomerPaymentDecision decision,
    required Decimal amount,
    required Decimal balanceBefore,
    required PaymentKind tender,
    required String? customerName,
  }) async {
    const none = (sign: null, error: null);
    if (decision != CustomerPaymentDecision.investment) return none;

    final debt = balanceBefore < Decimal.zero ? -balanceBefore : Decimal.zero;
    final advance = amount - debt;
    if (advance <= Decimal.zero) return none;

    final settings = await _db.thisPosDao.offsetFiscalSettings();
    if (!settings.fiscalizePrepaymentReceipt) return none;
    if (!await _fiscal.isEnabled()) return none;

    final paymentKind = tender.fiscalTreatment.toFiscalKind();
    if (paymentKind == null) {
      // Живые деньги без вида оператора — настройка справочника, которую
      // касса не выдумывает: назвать их наличными значило бы вернуть ровно
      // тот дефект, ради снятия которого хранится вид приёма.
      _logger.error(
        'Customer payment $operationId: у вида ${tender.code} нет вида '
        'оплаты оператора (${tender.fiscalTreatment.code}) — чек аванса '
        'не выписан',
      );
      return (sign: null, error: 'fiscal_treatment_not_a_payment');
    }

    final name = customerName == null || customerName.trim().isEmpty
        ? 'Аванс (предоплата)'
        : 'Аванс (предоплата) — ${customerName.trim()}';
    final result = await _fiscal.fiscalizePrepayment(
      operationId: operationId,
      amount: advance,
      paymentKind: paymentKind,
      positionName: name,
    );
    if (result.success) {
      _logger.info(
        'Customer payment $operationId: чек аванса $advance '
        '${result.queued ? '(в очереди)' : 'ok'} sign=${result.fiscalSign}',
      );
      return (sign: result.fiscalSign, error: null);
    }
    _logger.error(
      'Customer payment $operationId: чек аванса не выписан — '
      '${result.errorCode.name} ${result.errorMessage}',
    );
    return (sign: null, error: result.errorCode.name);
  }

  @override
  Future<bool> needsDecisionDialog(int agentId) async {
    try {
      final balance = await getCustomerBalance(agentId);
      return balance > Decimal.zero;
    } catch (e) {
      _logger.warning('Error checking decision dialog need: $e');
      return false;
    }
  }

  @override
  Future<Decimal> getCustomerBalance(int agentId) async {
    try {
      final agent = await _db.agentDao.findByLocalId(agentId);
      if (agent == null || agent.mainAccountId == null) {
        return Decimal.zero;
      }

      final account = await _db.accountDao.findById(agent.mainAccountId!);
      return account?.value ?? Decimal.zero;
    } catch (e) {
      _logger.warning('Error getting customer balance: $e');
      return Decimal.zero;
    }
  }
}
