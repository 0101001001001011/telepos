import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/constants/enums/product_type.dart';
import 'package:telepos/data/database/tables/certificate_refund_tables.dart';
import 'package:telepos/data/refund/refund_plan.dart';
import 'package:telepos/domain/payment/certificate_slip_printer.dart';
import 'package:telepos/domain/payment/credit_service.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/data/payment/payment_kind_catalog_impl.dart';
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/refund/refund_allocation.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/refund/refund_tender_gateway.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import 'package:telepos/domain/usecases/refund/refund_use_case.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

class RefundUseCaseImpl implements RefundUseCase {
  RefundUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
    required FiscalService fiscal,
    RefundTenderGateway? tenders,
    CertificateSlipPrinter? slips,
  }) : _db = db,
       _logger = logger,
       _fiscal = fiscal,
       _tenders = tenders,
       _slips = slips;

  final AppDatabase _db;
  final Talker _logger;

  /// Фискальный оператор возврата — **необнуляемый и обязательный** довод.
  ///
  /// # Что здесь было и чем это кончилось
  ///
  /// До этой правки узла не было вовсе: ветвь `isOfd` доставала его из
  /// `GetIt` сама и делала это **внутри того же `try`**, который ловит беды
  /// самой фискализации. Поэтому «службы в контейнере нет» и «оператор
  /// ответил отказом» приходили в один и тот же `catch` и оба превращались
  /// в строку предупреждения в журнале.
  ///
  /// Разница между ними — вся: второе означает «касса работает, оператор
  /// недоступен», первое — «кассу собрали без фискализации, и она об этом
  /// не скажет никому». Стенд живой приёмки полгода проводил возвраты
  /// **без фискального документа** и выглядел при этом исправным; нашли
  /// это глазами 2026-09-17, а не сборкой и не набором.
  ///
  /// # Почему довод обязательный, а не обнуляемый
  ///
  /// Тот же разбор, что у `LocalPaymentService._fiscal` (задача 3):
  /// обнуляемый довод — это не осторожная деградация, а её видимость. Из
  /// мест сборки его не передаёт тот, кто про фискализацию попросту не
  /// думал, и компилятор молчит одинаково и там, и в единственном месте,
  /// где отсутствие узла было настоящим решением.
  ///
  /// Теперь «узла нет» — **тип**, а не молчание: касса без фискализации
  /// собирается с `const RefusingFiscalService()`, написанным своей рукой.
  /// Возврат на такой кассе проводится целиком и без падения —
  /// `fiscalizeRefund` отвечает `FiscalResult.notConfigured()`, деньги
  /// уходят, документа нет, — но сказано это вслух.
  ///
  /// Сверка «касса и стенд собирают `RefundUseCaseImpl` всеми его доводами»
  /// в `test/architecture/stand_matches_till_test.dart` читает объявление
  /// конструктора, поэтому новый довод она ловит сама.
  final FiscalService _fiscal;

  /// Печать слипа бумажки, **выпущенной этим возвратом** — решение
  /// заказчика 2026-09-16.
  ///
  /// `null` — печати нет, и это не ошибка: тот же довод, что у [_tenders] и у
  /// `LocalRefundService._printer`. Возврат обязан проводиться на кассе без
  /// принтера, а пробы раскладки не должны поднимать очередь печати.
  ///
  /// До этой правки кассир переписывал номер новой бумажки от руки — а номер
  /// у неё вида `<исходный>-R<возврат>`, то есть переписывать было что.
  final CertificateSlipPrinter? _slips;

  /// Эквайринг и провайдер QR — задача 26.
  ///
  /// `null` — вернуть безнал **нечем**, и возврат строки карты или QR
  /// получает отказ [refundCashlessUnavailableCode], а не наличные из ящика
  /// и не молчаливую запись «вернули на карту». Необязателен затем, чтобы
  /// чек без безнала возвращался и там, где эквайринга нет вовсе.
  final RefundTenderGateway? _tenders;

  static const int _statePendingSync = 1;

  @override
  Future<RefundResult> perform({
    required int refundLocalId,
    required Decimal amount,
    Decimal? cashbackAmount,
    required int userId,
    int? saleReceiptNo,
    int? salePosId,
    int? customerLocalId,
    int? customerServerId,
    required List<RefundProductEntry> products,
    int? terminalId,
  }) async {
    _validateRefund(amount, products, saleReceiptNo, salePosId);

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    Sale? sale;
    int? saleId;
    bool isOfd = false;

    if (saleReceiptNo != null && salePosId != null) {
      final sales =
          await (_db.select(_db.sales)..where(
                (s) =>
                    s.receiptNo.equals(saleReceiptNo) &
                    s.posId.equals(salePosId),
              ))
              .get();
      if (sales.isNotEmpty) {
        sale = sales.first;
        saleId = sale.saleId;
        isOfd = sale.isOfd;
      }
    }

    // ── возврат рассрочного чека ОТКАЗЫВАЕТСЯ — шаг 7 задачи 24 ───────
    //
    // **До единой записи**, и не «до вставки строк», а раньше самой
    // транзакции: возврат правит строку `Refunds` первым же оборотом, и
    // отказ изнутри оставил бы её изменённой, если бы кто-нибудь однажды
    // вынес часть работы наружу.
    //
    // Довод измерен, а не выведен. Чек 10 000: первый взнос 2 000
    // наличными, рассрочка 8 000. Возврат целиком выдал бы из ящика
    // 2 000 — долю наличной строки, — а `_updateAgentBalance` ниже
    // сдвинул бы счёт покупателя на `amount − reversed` = 8 000 в плюс:
    // то есть касса **вернула бы деньги, которых покупатель не платил**.
    // При этом строки `credit_schedule_entries` возврат не читает ни
    // одной веткой, и договор остался бы живым — покупатель был бы должен
    // по графику за товар, который вернул.
    //
    // Почему отказ, а не «правильный возврат»: правильный возврат
    // рассрочки — это **расторжение договора**, и оно требует решений,
    // меняющих подписанный график (что с внесёнными взносами, что с
    // надбавкой, что при возврате одного товара из трёх). Всё, что меняет
    // график после подписи, лежит за границей кассы — в банковском
    // модуле. Отказ честен: он называет причину и не портит денег.
    if (sale != null) {
      final contract = await _db.creditDao.rowByReceipt(
        receiptNo: sale.receiptNo,
        posId: sale.posId,
      );
      if (contract != null) {
        _logger.warning(
          'RefundUseCase: receipt ${sale.receiptNo}/${sale.posId} is sold on '
          'credit contract ${contract.number} — refund refused',
        );
        throw WireRefusal(
          refundInstallmentRefusedCode,
          'чек ${sale.receiptNo} продан в рассрочку по договору '
          '${contract.number} — возврат по нему касса не делает: '
          'расторжение договора оформляется отдельно',
        );
      }
    }

    // ── раскладка по видам — задача 26 ────────────────────────────────
    //
    // Одно место в домене (`RefundAllocation`), одно чтение базы
    // (`RefundPlan`) — то же самое, которым снимок черновика показывает
    // кассиру, куда уйдут деньги. Разбор правила частичного возврата —
    // в докстринге `RefundAllocation`.
    final plan = await RefundPlan.of(
      _db,
      amount: amount,
      receiptNo: sale?.receiptNo,
      posId: sale?.posId,
    );
    // # Деньгами уходит ОСТАТОК проданной бумажки, а не её цена
    //
    // Решение заказчика 2026-09-16, пункт 1. Бумажка на 5000, с которой уже
    // отоварили 1200: вернуть 5000 значит отдать эти 1200 дважды — один раз
    // товаром, второй деньгами. Разбор и само вычитание — в
    // `RefundPlan.refundable`; здесь только имя, которым дальше пользуется
    // **всё** движение денег, чтобы места, где осталась бы названная сумма,
    // не существовало.
    //
    // У чека, не продававшего сертификатов (подавляющее большинство), это
    // ровно [amount] — список проданных бумажек пуст, вычитать нечего.
    final refundable = plan.refundable;

    await _checkBeforeMoneyLeaves(plan, refundLocalId);
    final returned = await _returnExternally(plan, refundLocalId, terminalId);

    // Куда ушли деньги каждой строки сторно: `seq` строки → маршрут
    // раскладки. Заполняет [_writeReversal] (там пишутся и строки, и их
    // номера), читает фискальный конверт [_refundFiscalBuckets] — строке
    // без вида оплаты он отвечает **маршрутом**, а не наличными остатком
    // (ревизия 2026-09-19, дыра 2).
    //
    // Объявлено здесь, а не возвращено из транзакции, по единственной
    // причине: конверт собирается **после** неё — фискализация не держит
    // замок базы и не откатывает возврат отказом оператора.
    final routeBySeq = <int, RefundRoute>{};

    final result = await _db.transaction(() async {
      await (_db.update(
        _db.refunds,
      )..where((r) => r.localId.equals(refundLocalId))).write(
        RefundsCompanion(
          amount: Value(refundable),
          cashbackAmount: Value(cashbackAmount),
          time: Value(now),
          state: const Value(_statePendingSync),
          saleId: Value(saleId),
          saleReceiptNo: Value(saleReceiptNo),
          salePosId: Value(salePosId),
          customerLocalId: Value(customerLocalId),
          customerServerId: Value(customerServerId),
          isOfd: Value(isOfd),
        ),
      );

      final refundProductService = GetIt.I<RefundProductService>();
      for (final product in products) {
        await refundProductService.add(
          refundLocalId: refundLocalId,
          ucode: product.ucode,
          quantity: product.quantity,
          price: product.price,
          inSalePrice: product.inSalePrice,
          inSaleQuantity: product.inSaleQuantity,
          inSalePriceBefore: product.inSalePriceBefore,
        );
      }

      for (final product in products) {
        await _db.productInfoDao.adjustQuantity(
          product.ucode,
          product.quantity,
        );
      }

      final reversal = await _writeReversal(
        refundLocalId: refundLocalId,
        sale: sale,
        plan: plan,
        returned: returned,
        routeBySeq: routeBySeq,
        refundAmount: refundable,
        userId: userId,
        now: now,
      );

      // ── гашение проданных бумажек — решение 1 (2026-09-16) ────────────
      //
      // **В той же транзакции, и это не украшение.** Гашение отдельно от
      // возврата ломается в обе стороны, и обе денежные: погасить и не
      // вернуть деньги — отнять бумажку даром; вернуть деньги и не погасить
      // — отдать и деньги, и годный сертификат. Второе и было дефектом до
      // этой правки, измеренным пробой: возврат чека продажи возвращал 5000
      // из ящика, а бумажка оставалась `active` с полным остатком
      // (`refund_certificate_sale_test.dart`).
      //
      // Гасится **остаток целиком**, одной условной инструкцией без чтения
      // (`CertificateDao.redeemRemainder`): посчитать остаток снаружи
      // значило бы вернуть то самое окно между чтением и записью, ради
      // закрытия которого условные записи здесь и заведены.
      for (final sold in plan.soldCertificates) {
        final touched = await _db.certificateDao.redeemRemainder(sold.number);
        if (touched == 0 && sold.balance > Decimal.zero) {
          // Остаток был, а погасить не удалось: бумажку в ту же секунду
          // отоварили на другой кассе или отозвал владелец. Бросок
          // откатывает весь возврат — деньги за неё уйти не должны.
          _logger.warning(
            'RefundUseCase: certificate ${sold.number} changed under refund '
            '$refundLocalId — rolled back',
          );
          throw WireRefusal(
            certificateRaceCode,
            'остаток сертификата ${sold.number} изменился, пока шёл '
            'возврат — повторите',
          );
        }

        // Обязательство кассы закрыто: за бумажку отданы деньги. Знак
        // выбирает `AccountPosting` по роду счёта — у
        // `certificateLiability` платёж **уменьшает** обязательство,
        // поэтому здесь `post(+остаток)`, зеркально выпуску с его
        // `post(-номинал)`.
        final liability = sold.liabilityAccountId;
        if (liability != null && sold.balance > Decimal.zero) {
          await _db.accountDao.post(liability, sold.balance);
        }

        // Журнал — **обязателен**: без него повторный возврат по тому же
        // чеку не с чем сверить (докстринг `CertificateRefundLinks`).
        await _db.certificateDao.linkRefund(
          refundLocalId: refundLocalId,
          sourceNumber: sold.number,
          amount: sold.balance,
          reason: CertificateRefundReason.redeemed,
          time: now,
        );
      }

      // Долговой счёт покупателя двигает **то, что не вернулось
      // деньгами**, — зеркально продаже, где он двигается на то, что не
      // было оплачено (`SaleUseCaseImpl`: `amount − Σпоступлений`).
      //
      // До этой правки здесь стояла вся сумма возврата, безусловно, при
      // любом виде оплаты: возврат полностью оплаченного чека на 1000
      // оставлял покупателю **−1000** долга, которого он не делал.
      // Держалось это на том, что вызывающий подставляет `null`
      // (`Sales.customerLocalId` сегодня не заполняется). Правило,
      // живущее в чужой сдержанности, — не правило: разбудят соседний
      // сервис, который поле заполнит, и дефект вернётся целиком.
      if (customerLocalId != null) {
        await _updateAgentBalance(
          customerLocalId,
          refundable - reversal.reversed,
        );
      }

      _logger.info(
        'RefundUseCase: completed refund=$refundLocalId, '
        'amount=$amount, products=${products.length}, '
        'payments=${reversal.count}, reversed=${reversal.reversed}, '
        'parts=${plan.parts}',
      );

      return RefundResult(
        refundLocalId: refundLocalId,
        // Отдаётся **то, что ушло деньгами**: чек возврата и снимок
        // терминала печатают этот исход, и назвать в нём цену бумажки
        // вместо возвращённого остатка значило бы напечатать сумму,
        // которой покупатель не получал.
        amount: refundable,
        productCount: products.length,
        paymentCount: reversal.count,
        // Из той же раскладки, по которой только что сделаны проводки
        // (`_writeReversal`: ветвь `RefundRoute.drawer` снимает деньги со
        // счёта ящика), — а не пересчётом снаружи: ящик обязан открываться
        // ровно тогда, когда из него по книгам ушли деньги.
        drawerAmount: _drawerAmountOf(plan),
      );
    });

    // ── слипы бумажек, выпущенных этим возвратом ──────────────────────
    //
    // **После транзакции, и это не косметика.** Внутри неё сборка документа
    // держала бы замок базы, а отказ принтера откатил бы возврат целиком —
    // деньги, уже возвращённые банком, «вернулись» бы только по книгам.
    //
    // Читается **журнал связи** (v48), а не локальные переменные ветви: он и
    // есть запись о том, что выпущено, и по нему же возврат защищается от
    // двойного выпуска. Второго мнения о том, какие бумажки родились, здесь
    // не заводится.
    await _printIssuedSlips(refundLocalId, userId);

    if (isOfd) {
      // `try` остаётся, но сторожит **только работу оператора**: связь,
      // отказ протокола, беду очереди. Деньги к этой строке уже вернулись
      // покупателю, и бросок наружу оставил бы вызывающего с мыслью, что
      // возврата не было, — при том что он был.
      //
      // Чего в этом `try` больше нет — поиска службы в `GetIt`. Раньше он
      // стоял первой строкой, и «кассу собрали без фискализации» приходило
      // сюда же и уходило той же строкой журнала (разбор — у [_fiscal]).
      try {
        final buckets = await _refundFiscalBuckets(
          refundLocalId,
          amount,
          routeBySeq,
        );
        if (buckets.certificatesOnly) {
          // Зеркало продажи (A1): чек из одних проданных сертификатов
          // документа не давал — возвращать по документу нечего.
          _logger.info(
            'RefundUseCase: refund $refundLocalId returns sold certificates '
            'only, their sale was not fiscalized — no fiscal document',
          );
          return result;
        }
        final live = buckets.cash + buckets.card + buckets.mobile;
        if (live == Decimal.zero &&
            buckets.offset + buckets.credit > Decimal.zero) {
          // Возврат целиком ушёл на сертификат, в аванс или в погашение
          // долга: живых денег не вышло, и фискальный возврат денег
          // выписать не на что — зеркало продажи, закрытой зачётом целиком.
          _logger.info(
            'RefundUseCase: refund $refundLocalId returned to certificate '
            'or advance entirely (${buckets.offset}) — no fiscal document',
          );
          return result;
        }
        final fiscalResult = await _fiscal.fiscalizeRefund(
          refundLocalId: refundLocalId,
          originalSaleReceiptNo: saleReceiptNo,
          amount: amount,
          cashAmount: buckets.cash,
          cardAmount: buckets.card,
          mobileAmount: buckets.mobile,
          bonusAmount: buckets.bonus,
          creditAmount: buckets.credit,
          offsetAmount: buckets.offset,
          offsetLayout: buckets.layout,
          excludeCertificatePositions: buckets.excludeCertificates,
        );

        if (fiscalResult.success) {
          _logger.info(
            'RefundUseCase: fiscalization '
            '${fiscalResult.queued ? 'queued' : 'ok'}, '
            'sign=${fiscalResult.fiscalSign}',
          );
        } else {
          _logger.warning(
            'RefundUseCase: fiscalization failed: ${fiscalResult.errorMessage}',
          );
        }
      } catch (e, stackTrace) {
        _logger.warning(
          'RefundUseCase: fiscalization error: $e',
          e,
          stackTrace,
        );
      }
    }

    return result;
  }

  void _validateRefund(
    Decimal amount,
    List<RefundProductEntry> products,
    int? saleReceiptNo,
    int? salePosId,
  ) {
    final isRefundByReceipt = saleReceiptNo != null && salePosId != null;

    final isTotalDiscountSale =
        isRefundByReceipt &&
        products.every((p) => p.inSalePrice == Decimal.zero);

    if (amount <= Decimal.zero &&
        (!isRefundByReceipt || !isTotalDiscountSale)) {
      throw const InvalidRefundException(
        'Сумма возврата не может быть нулевой',
      );
    }

    final hasZeroPriceWithoutSale = products.any(
      (p) => p.inSalePrice == null && p.price == Decimal.zero,
    );
    if (hasZeroPriceWithoutSale) {
      throw const InvalidRefundException(
        'Продукт с нулевой ценой нельзя вернуть',
      );
    }
  }

  /// Сумма частей раскладки, выданных **наличными из ящика** — см.
  /// [RefundResult.drawerAmount].
  static Decimal _drawerAmountOf(RefundPlan plan) {
    var total = Decimal.zero;
    for (final part in plan.parts) {
      if (part.route == RefundRoute.drawer) total += part.amount;
    }
    return total;
  }

  /// Всё, что можно проверить **до того, как деньги уйдут наружу**.
  ///
  /// Возврат на карту и через QR не откатывается транзакцией базы: банк уже
  /// вернул деньги. Поэтому отказы, которые иначе случились бы внутри
  /// транзакции — вид с запретом возврата, сертификат, не принимающий
  /// деньги обратно, — стоят **раньше** внешних вызовов. Условная запись
  /// сертификата внутри транзакции остаётся настоящим заслоном; здесь —
  /// только слово кассиру до банка.
  Future<void> _checkBeforeMoneyLeaves(
    RefundPlan plan,
    int refundLocalId,
  ) async {
    // # Наличными за сертификат не возвращают — решение 3 (2026-09-16)
    //
    // Раньше всего остального. Чек, которым бумажку продали, оплачивался
    // наличными, и раскладка честно кладёт их обратно в ящик — измеренная
    // проба показала ровно это: `parts=[RefundPart(drawer 5000)]`. Так
    // делать нельзя, и разбор — в докстринге
    // [certificateCashRefundRefusedCode]: сертификат это **аванс**,
    // наличными аванс не обналичивают (КГД РК), а п.36 Правил внутренней
    // торговли требует возврата «на указанные предъявителем реквизиты».
    // Денег за бумажку в сегодняшнем ящике нет и быть не может — они
    // пришли при выпуске и лежат обязательством.
    if (plan.soldCertificates.isNotEmpty) {
      for (final part in plan.parts) {
        if (part.route != RefundRoute.drawer) continue;
        if (part.amount <= Decimal.zero) continue;
        final numbers = [for (final c in plan.soldCertificates) c.number];
        _logger.warning(
          'RefundUseCase: refund $refundLocalId would pay ${part.amount} in '
          'cash for certificates ${numbers.join(', ')} — refused',
        );
        throw WireRefusal(
          certificateCashRefundRefusedCode,
          'наличными за сертификат вернуть нельзя — укажите реквизиты',
        );
      }
    }

    // # Строка уходит на бумажку, а номера бумажки нет — отказ
    //
    // Находка ревизии 2026-09-19, измеренная пробой. Разбор целиком — в
    // докстринге [certificateRefundNoSourceCode]; коротко: ветвь
    // `RefundRoute.certificate` ниже выпускает новую бумажку **только**
    // при наличии `reference`, а `releaseCredit` двигает счёт
    // обязательства безусловно. Строка без документа проходила молча:
    // обязательство росло, бумажки не появлялось, покупатель не получал
    // ничего.
    //
    // **Раньше денег, а не в ветви.** Отказ изнутри транзакции откатил бы
    // её верно, но случился бы уже после возврата на карту и через QR —
    // тех, что этой транзакцией не откатываются (докстринг метода выше).
    for (final part in plan.parts) {
      if (part.route != RefundRoute.certificate) continue;
      if (part.amount <= Decimal.zero) continue;
      final number = part.source?.reference;
      if (number != null && number.trim().isNotEmpty) continue;
      _logger.warning(
        'RefundUseCase: refund $refundLocalId has a certificate-route row '
        'without a source number — refused',
      );
      throw const WireRefusal(
        certificateRefundNoSourceCode,
        'строка чека возвращается сертификатом, но номера сертификата у '
        'неё нет — возврат по ней касса не проводит',
      );
    }

    // # Вид записан, а справочника на него нет — отказ, а не наличные
    //
    // Ревизия 2026-09-19, дыра 2. Разбор целиком — в докстринге
    // [refundKindUnknownCode]; коротко: такой чек приехал с кассы, где
    // оператор завёл свой вид, и чем платили — касса не знает. Раскладка
    // отправляла эту строку из ящика, а фискальный конверт добирал её
    // остатком в наличные, и кассир не видел ни причины, ни следа.
    //
    // **Раньше денег, а не в конверте.** Отказ внутри `_refundFiscalBuckets`
    // случился бы после того, как деньги ушли: тот блок обёрнут `try`,
    // который сторожит работу оператора, и бросок из него стал бы строкой
    // журнала — то же молчание, только в другом месте.
    //
    // Строка **до v41** (вида не записано вовсе) сюда не попадает: у неё
    // решение другое и принятое — из ящика, как и раньше.
    final catalog = PaymentKindCatalogImpl(_db);
    for (final part in plan.parts) {
      if (part.amount <= Decimal.zero) continue;
      final kindId = part.source?.kindId;
      if (kindId == null) continue;
      if (await catalog.byId(kindId) != null) continue;
      _logger.warning(
        'RefundUseCase: refund $refundLocalId hits payment kind $kindId '
        'unknown to this till — refused',
      );
      throw WireRefusal(
        refundKindUnknownCode,
        'чек оплачен видом $kindId, которого нет в справочнике этой кассы '
        '— возврат по нему касса не проводит',
      );
    }

    for (final part in plan.parts) {
      final source = part.source;
      if (source == null) continue;
      if (!source.refundAllowed) {
        throw WireRefusal(
          refundKindNotRefundableCode,
          'на вид оплаты «${source.kindName ?? source.kindId}» возврат '
          'запрещён настройкой справочника',
        );
      }
      final number = source.reference;
      if (part.route == RefundRoute.certificate && number != null) {
        // # Потолка номинала здесь больше нет — решение 2 (2026-09-16)
        //
        // Он сторожил возврат **на ту же бумажку** (`CertificateDao.restore`):
        // вернуть больше списанного значило напечатать деньги. Возврата на
        // ту же бумажку больше не бывает — выпускается новая, — и потолок
        // проверял бы остаток, которого операция уже не касается.
        //
        // От двойного выпуска сторожит **журнал связи** (v48): ключ
        // `{возврат, исходная бумажка}` в таблице, а первая линия —
        // проверка в самом выпуске.
        final certificate = await _db.certificateDao.byNumber(number);
        if (certificate == null ||
            certificate.status == CertificateStatus.cancelled) {
          throw WireRefusal(
            certificateExhaustedCode,
            'на сертификат $number вернуть нельзя: он отозван либо его нет '
            'на этой кассе',
          );
        }
      }
    }
  }

  /// Возврат безнала через эквайринг и провайдера — **до записи в базу**.
  ///
  /// Порядок — порядок раскладки. Отказ на второй доле после успеха первой
  /// не откатывает первую: банк её уже вернул. Кассир получает отказ, в
  /// тексте которого названо уже возвращённое, а повтор того же возврата
  /// несёт **тот же ключ** (`refund:<возврат>:<строка чека>`), и внешняя
  /// сторона отдаёт по нему прежний ответ, не возвращая деньги второй раз.
  Future<Map<int, TenderReturn>> _returnExternally(
    RefundPlan plan,
    int refundLocalId,
    int? terminalId,
  ) async {
    final returned = <int, TenderReturn>{};
    for (var i = 0; i < plan.parts.length; i++) {
      final part = plan.parts[i];
      final source = part.source;
      if (source == null || !part.route.isExternal) continue;
      if (part.amount <= Decimal.zero) continue;

      final what = part.route == RefundRoute.card ? 'карту' : 'QR';
      final tenders = _tenders;
      final reference = source.transactionId;
      if (tenders == null || reference == null || reference.isEmpty) {
        _logger.warning(
          'RefundUseCase: refund $refundLocalId needs ${part.route.code} '
          'return of ${part.amount}, but there is no way to return it',
        );
        throw WireRefusal(
          refundCashlessUnavailableCode,
          '${part.amount} надо вернуть на $what, а '
          '${tenders == null ? 'эквайринга на кассе нет' : 'у оплаты нет номера операции'}'
          '${_alreadyText(plan, returned)}',
        );
      }

      final key = 'refund:$refundLocalId:${source.seq}';
      final reply = part.route == RefundRoute.card
          ? await tenders.returnCard(
              terminalId: terminalId,
              transactionId: reference,
              amount: part.amount,
              refundKey: key,
            )
          : await tenders.returnQr(
              providerIntentId: reference,
              amount: part.amount,
              refundKey: key,
            );
      if (!reply.ok) {
        _logger.warning(
          'RefundUseCase: ${part.route.code} return of ${part.amount} for '
          'refund $refundLocalId refused: ${reply.code}',
        );
        // Код назван константой в месте броска, а не пробрасывается полем
        // ответа: сторож «названный отказ доходит до кассира» разбирает
        // коды по тексту, и `reply.code!` был бы для него невидим.
        final message = '${reply.message}${_alreadyText(plan, returned)}';
        throw reply.code == refundCashlessUnavailableCode
            ? WireRefusal(refundCashlessUnavailableCode, message)
            : WireRefusal(refundCashlessRefusedCode, message);
      }
      returned[i] = reply;
      if (part.route == RefundRoute.provider) {
        await _markIntentReversed(reference, part.amount, refundLocalId);
      }
    }
    return returned;
  }

  /// Намерение QR, по которому деньги **уже вернулись покупателю**, —
  /// ревизия 2026-09-19, дыра 3.
  ///
  /// # Что было и почему это брак
  ///
  /// `paymentIntentDao` не упоминался в этом файле **вовсе**. Провайдер
  /// отдавал деньги, возврат уходил дальше, а строка намерения оставалась
  /// `paid` со `settled_at` — то есть читалась как «деньги взяты и легли в
  /// чек». Разбор беды при подъёме, вкладка диагностики QR и
  /// `QrTenderPhase.of` видели оплату там, где её уже нет; член
  /// `QrIntentStatus.reversed` не писал никто — `git grep` находил его
  /// только в объявлении, в `switch` показа и в пробе эмулятора.
  ///
  /// # Почему здесь, а не в шлюзе и не в транзакции
  ///
  /// **Здесь** — потому что знание «эта доля возврата ушла через
  /// провайдера» живёт в раскладке, а `LocalRefundTenderGateway` — адаптер
  /// к чужой системе, и знать про журнал кассы ему незачем.
  ///
  /// **Вне транзакции** — потому что провайдер деньги уже вернул. Запись,
  /// откатившаяся вместе с возвратом, стёрла бы след денег, которых у кассы
  /// больше нет: намерение осталось бы `paid`, и разбор при подъёме
  /// попытался бы уложить их в чек второй раз.
  ///
  /// # Не бросает
  ///
  /// Ни одна ветка отсюда не отменяет возврата: деньги ушли из банка, и
  /// отказ записи в журнал не имеет права сделать вид, что их не отдавали.
  /// О беде говорит журнал — тем же правилом, что у [_printIssuedSlips].
  ///
  /// # Чего это НЕ доказывает
  ///
  /// Что намерение найдётся. Связь ведётся по `provider_intent_id` из
  /// строки оплаты (`Payments.terminal_transaction_id`), и у чека, чья
  /// оплата приехала обменом с другой кассы, такой строки намерения здесь
  /// нет. Это названо строкой журнала, а не молчанием.
  Future<void> _markIntentReversed(
    String providerIntentId,
    Decimal amount,
    int refundLocalId,
  ) async {
    try {
      final intent = await _db.paymentIntentDao.byProviderIntentId(
        providerIntentId,
      );
      if (intent == null) {
        _logger.warning(
          'RefundUseCase: refund $refundLocalId returned $amount by QR '
          '$providerIntentId, but there is no such intent on this till — '
          'nothing to mark',
        );
        return;
      }
      final written = await _db.paymentIntentDao.markReversed(
        id: intent.id,
        amount: amount,
        at: DateTime.now(),
      );
      _logger.info(
        'RefundUseCase: QR intent ${intent.intentKey} marked reversed by '
        '$amount (written=$written)',
      );
    } catch (e, stackTrace) {
      _logger.warning(
        'RefundUseCase: возврат $refundLocalId не записался в намерение '
        '$providerIntentId: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Слипы бумажек, **выпущенных этим возвратом**, — решение заказчика
  /// 2026-09-16.
  ///
  /// # Источник — журнал, а не память ветви
  ///
  /// Что выпущено, знает `CertificateRefundLinks`: ветвь
  /// [RefundRoute.certificate] пишет туда связь с причиной
  /// [CertificateRefundReason.issued] и номером новой бумажки. Собирать тот
  /// же список во второй раз, локальными переменными транзакции, значило бы
  /// завести второе мнение о том, какие бумажки родились, — и разошлось бы
  /// оно молча, на первом же возврате, где выпуска не случилось
  /// (`linkFor` нашла прежнюю связь и повтора не сделала).
  ///
  /// Гашение (`CertificateRefundReason.redeemed`) слипа не даёт: там бумажку
  /// **отняли**, а не выдали, и печатать покупателю нечего.
  ///
  /// # Не ждёт и не бросает
  ///
  /// Отправка слипа не ожидается: возврат уже состоялся, и задержка сборки
  /// документа лежала бы на ответе кассиру. Ни одна ветка отсюда не
  /// выбрасывает — отказ принтера не имеет права отменить возврат, деньги по
  /// которому уже ушли из банка.
  Future<void> _printIssuedSlips(int refundLocalId, int userId) async {
    final slips = _slips;
    if (slips == null) return;
    try {
      final links = await _db.certificateDao.linksByRefund(refundLocalId);
      for (final link in links) {
        if (CertificateRefundReason.byCode(link.reason) !=
            CertificateRefundReason.issued) {
          continue;
        }
        final issuedNumber = link.issuedNumber;
        if (issuedNumber == null) continue;
        final certificate = await _db.certificateDao.byNumber(issuedNumber);
        if (certificate == null) continue;
        // Отправка **не ожидается**: `printIssued` складывает задание в свою
        // цепочку (`CertificateSlipPrinter.pending`), и ждать её здесь
        // значило бы задержать ответ возврата на сборку документа.
        slips.printIssued(
          certificate: certificate,
          userId: userId,
          refundLocalId: refundLocalId,
          sourceNumber: link.sourceNumber,
        );
      }
    } catch (e, stackTrace) {
      _logger.warning(
        'RefundUseCase: слипы возврата $refundLocalId не собрались: $e',
        e,
        stackTrace,
      );
    }
  }

  static String _alreadyText(RefundPlan plan, Map<int, TenderReturn> done) {
    if (done.isEmpty) return '';
    final parts = [
      for (final i in done.keys)
        '${plan.parts[i].amount} (${plan.parts[i].route.code})',
    ];
    return '; уже возвращено: ${parts.join(', ')} — повтор возврата не '
        'вернёт их второй раз';
  }

  /// Строки сторно по раскладке: сколько записано и **сколько нашло своего
  /// получателя**.
  ///
  /// Сумма нужна вызывающему: по ней считается долговая часть возврата
  /// ([_updateAgentBalance]). Возвращать её отсюда, а не считать заново
  /// снаружи, — единственный способ держать правило «долг двигает то, что
  /// не вернулось деньгами» в правиле.
  Future<_Reversal> _writeReversal({
    required int refundLocalId,
    required Sale? sale,
    required RefundPlan plan,
    required Map<int, TenderReturn> returned,
    required Map<int, RefundRoute> routeBySeq,
    required Decimal refundAmount,
    required int userId,
    required int now,
  }) async {
    final posAccountId = (await _db.thisPosDao.get())?.accountId;

    var reversedTotal = Decimal.zero;
    var count = 0;

    /// Сколько по каждому бонусному счёту вернулось покупателю. Копится
    /// здесь, отдаётся журналу одним вызовом после цикла.
    final returnedByBonusAccount = <int, Decimal>{};

    // Строки пишутся **в порядке чека**, а не в порядке раскладки: правило
    // частичного возврата решает, сколько досталось каждой строке, а номер
    // строки сторно (`seq`) остаётся рядом с номером строки продажи, как до
    // задачи 26. Остаток сверх строк — последним.
    final order = [for (var i = 0; i < plan.parts.length; i++) i]
      ..sort((a, b) {
        final sa = plan.parts[a].source?.seq ?? plan.rows.length;
        final sb = plan.parts[b].source?.seq ?? plan.rows.length;
        return sa.compareTo(sb);
      });

    for (final i in order) {
      final part = plan.parts[i];
      if (part.amount <= Decimal.zero) continue;
      final source = part.source;
      final row = source == null ? null : plan.rows[source.seq];
      final accountId = row?.payeeAccountId ?? posAccountId;
      if (accountId == null) {
        _logger.warning('RefundUseCase: no pos account for refund payment');
        continue;
      }
      final tender = returned[i];

      await _db
          .into(_db.payments)
          .insert(
            PaymentsCompanion.insert(
              userId: userId,
              payeeAccountId: accountId,
              amount: -part.amount,
              time: now,
              refundLocalId: Value(refundLocalId),
              state: const Value(_statePendingSync),
              // Вид переносится **со строки продажи**, а не выводится
              // заново по счёту: сторно оплаты картой обязано остаться
              // сторно оплаты картой, даже если счёт с тех пор сменил
              // род. `null` у строки, чей вид не был записан (до v41),
              // — честнее выдуманного. Остаток сверх строк чека и возврат
              // без чека выдаются из ящика — вид назван явно.
              kindId: Value(
                source == null ? SystemPaymentKindIds.cash : row?.kindId,
              ),
              // `seq` — **номер в этом возврате, от нуля**. Тот же
              // довод, что в `SaleUseCaseImpl.perform`: ключ
              // `{refundLocalId, seq}` защищает, только пока номер не
              // продолжает чужую нумерацию.
              seq: Value(count),
              // Номер операции возврата на стороне банка или провайдера —
              // то, по чему возврат сверяют с выпиской (задача 26).
              terminalTransactionId: Value(tender?.transactionId),
              approvalCode: Value(tender?.approvalCode),
              cardMask: Value(row?.cardMask),
              providerCode: Value(
                part.route == RefundRoute.provider ? row?.providerCode : null,
              ),
            ),
          );

      // Маршрут строки — рядом с её номером, для фискального конверта.
      // Пишется здесь, а не выводится заново снаружи: второе мнение о
      // том, куда ушли деньги, — это и есть расхождение ящика с ОФД.
      routeBySeq[count] = part.route;

      switch (part.route) {
        case RefundRoute.debt:
          // **Обязательство из ящика не выходит — задача 14.** Счёт
          // покупателя гасит вызывающий выражением `amount − reversed`;
          // посчитать долю здесь значило бы сдвинуть тот же счёт дважды.
          count++;
          continue;

        case RefundRoute.certificate:
          // # НОВАЯ бумажка вместо восстановления старой — решение 2
          //
          // Деньги по-прежнему не идут в руки: живых денег эта строка в
          // ящик не приносила (разбор задачи 21 и решение
          // `givesChange = false`). Изменилось **куда** они идут.
          //
          // Старый сертификат остаётся погашенным навсегда, а покупатель
          // получает **новый** на сумму, которую тот закрыл. Так делают
          // Спортмастер, М.Видео и Magnum, и довод у них общий: бумажка,
          // «ожившая» задним числом, неотличима от непогашенной, и её
          // предъявляют второй раз — в том числе на кассе, которая о
          // возврате не знает.
          //
          // **Обязательство кассы при этом не меняется**: старое закрыто
          // продажей, новое берётся выпуском на ту же сумму, и
          // `releaseCredit` ниже остаётся ровно тем же движением, что и до
          // правки. Меняется бумажка, а не деньги.
          final number = row?.reference;
          if (number != null) {
            // Первая линия заслона от двойного выпуска — журнал; вторая,
            // структурная, — уникальный ключ самой таблицы.
            final already = await _db.certificateDao.linkFor(
              refundLocalId: refundLocalId,
              sourceNumber: number,
            );
            if (already == null) {
              final origin = await _db.certificateDao.byNumber(number);
              final issuedNumber = '$number-R$refundLocalId';
              await _db.certificateDao.insertCertificate(
                number: issuedNumber,
                nominal: part.amount,
                issuedAt: now,
                status: CertificateStatus.active,
                expiresAt: _inheritedExpiry(origin),
                // **Чек выпуска не заполняется, и это не пропуск.** Бумажка
                // рождена возвратом, а не продажей. Записать сюда
                // возвращаемый чек значило бы соврать — тот чек её не
                // продавал, — и, хуже того, `byIssuedReceipt` нашла бы её
                // при следующем возврате того же чека и погасила бы как
                // «проданную им». Происхождение держит журнал.
                issuedByUserId: userId,
                liabilityAccountId: accountId,
              );
              await _db.certificateDao.linkRefund(
                refundLocalId: refundLocalId,
                sourceNumber: number,
                issuedNumber: issuedNumber,
                amount: part.amount,
                reason: CertificateRefundReason.issued,
                time: now,
              );
              _logger.info(
                'RefundUseCase: refund $refundLocalId issued certificate '
                '$issuedNumber for ${part.amount} instead of restoring '
                '$number',
              );
            }
          }
          await _db.accountDao.releaseCredit(accountId, part.amount);

        case RefundRoute.advance:
          // # Аванс возвращается АВАНСОМ, а не деньгами — решение задачи 23
          //
          // Этих денег в ящике нет: они пришли раньше, и на этом чеке касса
          // их не получала. Выдача аванса деньгами — свой документ расчёта
          // с контрагентом. Восстановленный аванс можно выдать деньгами;
          // выданные деньги обратно в аванс не соберёшь.
          await _db.accountDao.releaseCredit(accountId, part.amount);

        case RefundRoute.bonus:
          returnedByBonusAccount[accountId] =
              (returnedByBonusAccount[accountId] ?? Decimal.zero) +
              part.amount;

        case RefundRoute.drawer:
        case RefundRoute.card:
        case RefundRoute.provider:
        case RefundRoute.manual:
          // Сторно — это движение `−R`: у ящика и у банковского счёта
          // `AccountPosting` даст `balance − R`.
          await _db.accountDao.post(accountId, -part.amount);
      }

      // **Зачёт считается в [reversedTotal], и это не оговорка.** Число
      // отвечает на вопрос «нашла ли строка своего получателя»: наличные
      // нашли ящик, бонус — журнал, аванс — счёт покупателя. Не нашло
      // только обязательство, и его гасит вызывающий.
      reversedTotal += part.amount;
      count++;
    }

    // Оба бонусных движения — одним вызовом на один возврат (задача 13,
    // шаг 8): возврат списанного и сторно начисленного. Только у возврата
    // по чеку со строками оплаты — так было и до задачи 26.
    if (sale != null && plan.rows.isNotEmpty) {
      await _db.bonusEntryDao.reverseForRefund(
        receiptNo: sale.receiptNo,
        posId: sale.posId,
        refundLocalId: refundLocalId,
        returnedByAccount: returnedByBonusAccount,
        refundAmount: refundAmount,
        saleAmount: sale.amount,
        userId: userId,
      );
    }

    return _Reversal(count: count, reversed: reversedTotal);
  }

  /// Чем возврат вернулся — **по строкам сторно этого возврата**, для
  /// фискального документа. Решение заказчика 2026-09-14, п.7 (A4), и
  /// задача 26.
  ///
  /// Трактовка спрашивается **через тот же сторож**, что у продажи
  /// (`FiscalOffsetSettings.effectiveTreatment`).
  ///
  /// # Что изменила задача 26
  ///
  /// До неё бонус (`notAPayment`) и долг (`credit`) уходили оператору
  /// **наличными остатком**: чек «300 бонусами + 700 наличными» давал
  /// фискальный возврат наличных 1000 при 700 из ящика. Теперь бонус —
  /// скидка позиций (зеркало продажи, `FiscalPositionBuilder.extraDiscount`),
  /// долг — раскладка позиций настройкой оператора, как зачёт: `PaymentType
  /// 2` «кредит» исключён протоколом ОФД 2.0.2, и оплатой долг не едет.
  ///
  /// # Строка без вида — по МАРШРУТУ, а не остатком в наличные
  ///
  /// Ревизия 2026-09-19, дыра 2. До неё строка, вид которой определить не
  /// удалось, выпадала из цикла (`if (kind == null) continue`), а её сумма
  /// добиралась **остатком** в наличную часть (`rest > 0 → cash += rest`).
  /// Два довода, почему это брак:
  ///
  /// 1. **Остаток — не знание, а совпадение.** Для строки до v41, ушедшей
  ///    из ящика, он давал верный ответ случайно; для бонусной строки того
  ///    же чека — заведомо неверный: деньги вернулись на бонусный счёт, а
  ///    оператор получал «выдано наличными». Ящик и ОФД расходились ровно
  ///    на бонус.
  /// 2. **Молчание.** Ни отказа, ни строки журнала: кассир видел обычный
  ///    успешный возврат.
  ///
  /// Теперь такая строка классифицируется **тем маршрутом, которым
  /// деньги на самом деле ушли** (`RefundRoute` из раскладки, [routeBySeq]):
  /// из ящика — наличные, на бонусный счёт — бонус, в долг — долг, на
  /// бумажку или в аванс — зачёт. Это не вывод вида по роду счёта (он
  /// сказал бы «карта» там, где деньги ушли из ящика, — и развёл бы ящик с
  /// ОФД в другую сторону), а запись о случившемся.
  ///
  /// Вид, **записанный** в строке и неизвестный справочнику, сюда не
  /// доезжает вовсе: возврат такого чека отказан раньше денег
  /// ([refundKindUnknownCode]).
  ///
  /// # Чего это НЕ доказывает
  ///
  /// Что конверт сойдётся всегда. Остаток, не покрытый ни одной строкой
  /// сторно (возврат залога за тару — у него нет ведра в конверте вовсе;
  /// строка, которую не удалось записать), в наличные больше **не
  /// превращается**: он остаётся недостачей конверта, и оператор ответит
  /// кодом 9. Это видно — в отличие от прежней выдумки.
  ///
  /// # Проданные сертификаты
  ///
  /// Зеркало продажи (A1): при выключенной фискализации продажи сертификата
  /// его строки в документ не шли, а их деньги вычитались из живых —
  /// наличные, затем карта, затем телефон. Возврат обязан сделать то же,
  /// иначе он возвращает по документу то, чего документ не продавал.
  Future<
    ({
      Decimal cash,
      Decimal card,
      Decimal mobile,
      Decimal bonus,
      Decimal credit,
      Decimal offset,
      OffsetFiscalLayout layout,
      bool excludeCertificates,
      bool certificatesOnly,
    })
  >
  _refundFiscalBuckets(
    int refundLocalId,
    Decimal amount,
    Map<int, RefundRoute> routeBySeq,
  ) async {
    final settings = await _db.thisPosDao.offsetFiscalSettings();
    final catalog = PaymentKindCatalogImpl(_db);
    var cash = Decimal.zero;
    var card = Decimal.zero;
    var mobile = Decimal.zero;
    var bonus = Decimal.zero;
    var credit = Decimal.zero;
    var offset = Decimal.zero;
    for (final row in await _db.paymentDao.findByRefund(refundLocalId)) {
      final returned = -row.amount;
      final kindId = row.kindId;
      final kind = kindId == null ? null : await catalog.byId(kindId);
      if (kind == null) {
        // Вида нет — спрашиваем маршрут: куда деньги ушли на самом деле.
        // `switch` **исчерпывающий и без `default`**: новый маршрут
        // сломает сборку здесь, и это хорошо.
        final route = routeBySeq[row.seq];
        if (route == null) {
          // Строки сторно без маршрута быть не может: оба пишет один
          // проход (`_writeReversal`). Если она всё же появилась —
          // сказать о ней вслух, а не досчитать наличными.
          _logger.warning(
            'RefundUseCase: refund $refundLocalId payment row ${row.seq} has '
            'neither kind nor route — left out of the fiscal envelope',
          );
          continue;
        }
        switch (route) {
          case RefundRoute.drawer:
            cash += returned;
          // Вне кассы возвращают тем же, чем приняли, — эквайрингом.
          case RefundRoute.manual:
          case RefundRoute.card:
            card += returned;
          case RefundRoute.provider:
            mobile += returned;
          case RefundRoute.bonus:
            bonus += returned;
          case RefundRoute.debt:
            credit += returned;
          case RefundRoute.certificate:
          case RefundRoute.advance:
            offset += returned;
        }
        continue;
      }
      switch (settings.effectiveTreatment(kind)) {
        case FiscalTreatment.cash:
          cash += returned;
        case FiscalTreatment.card:
          card += returned;
        case FiscalTreatment.mobile:
          mobile += returned;
        case FiscalTreatment.offsetNotFiscal:
          offset += returned;
        case FiscalTreatment.notAPayment:
          bonus += returned;
        case FiscalTreatment.credit:
          credit += returned;
        case FiscalTreatment.tare:
          break;
      }
    }
    // **Остаток наличными больше не становится** — ревизия 2026-09-19,
    // дыра 2. Разбор в докстринге выше; здесь остаётся одно: сказать о
    // недостаче вслух. Молчаливая прибавка выглядела знанием, а была
    // выдумкой: «чего не узнали — то наличные».
    final rest = amount - cash - card - mobile - bonus - credit - offset;
    if (rest != Decimal.zero) {
      _logger.warning(
        'RefundUseCase: refund $refundLocalId fiscal envelope is off by '
        '$rest (amount=$amount, cash=$cash, card=$card, mobile=$mobile, '
        'bonus=$bonus, credit=$credit, offset=$offset)',
      );
    }

    var excludeCertificates = false;
    var certificatesOnly = false;
    if (!settings.fiscalizeCertificateSale) {
      var certificateLines = Decimal.zero;
      var allLines = Decimal.zero;
      for (final rp in await _db.refundDao.findProductsByRefund(refundLocalId)) {
        final line = rp.quantity * rp.price;
        allLines += line;
        final product = await _db.productInfoDao.findByUcode(rp.ucode);
        if (product?.type == ProductType.giftCertificate.index) {
          certificateLines += line;
        }
      }
      if (certificateLines > Decimal.zero) {
        if (certificateLines >= allLines) {
          certificatesOnly = true;
        } else {
          excludeCertificates = true;
          var left = certificateLines;
          Decimal take(Decimal bucket) {
            final taken = bucket < left ? bucket : left;
            left -= taken;
            return taken;
          }

          cash -= take(cash);
          card -= take(card);
          mobile -= take(mobile);
        }
      }
    }

    return (
      cash: cash,
      card: card,
      mobile: mobile,
      bonus: bonus,
      credit: credit,
      offset: offset,
      layout: settings.offsetLayout,
      excludeCertificates: excludeCertificates,
      certificatesOnly: certificatesOnly,
    );
  }

  /// Срок бумажки, выпущенной возвратом: **наследуется от исходной, но не
  /// более трёх лет от первичной продажи** — решение заказчика 2026-09-16.
  ///
  /// Наследование, а не новый срок с сегодняшнего дня: иначе возврат стал бы
  /// способом бесплатно продлевать сертификат. Купил бумажку, отоварил,
  /// вернул товар — и получил свежие три года; повтори раз в год, и срок не
  /// кончится никогда. Потолок «три года от **первичной** продажи» этот
  /// круг закрывает: он считается от [GiftCertificate.issuedAt] исходной
  /// бумажки, а не от даты возврата.
  ///
  /// Бессрочная исходная (`expiresAt == null`) даёт новой **потолок**, а не
  /// бессрочность. Это решение, а не вывод из правила, и оно помечено в
  /// отчёте как подлежащее подтверждению у заказчика: бессрочность,
  /// пережившая возврат, оставила бы обязательство кассы без срока
  /// давности.
  ///
  /// Арифметика календарная, а не «3 × 365 суток»: три года от 29 февраля
  /// считаются годами, и разница в сутки на бумажке, которую покупатель
  /// держит в руках, — это спор у кассы, а не округление.
  static int? _inheritedExpiry(GiftCertificate? origin) {
    if (origin == null) return null;
    final issued = DateTime.fromMillisecondsSinceEpoch(
      origin.issuedAt * 1000,
      isUtc: true,
    );
    final cap =
        DateTime.utc(
          issued.year + 3,
          issued.month,
          issued.day,
          issued.hour,
          issued.minute,
          issued.second,
        ).millisecondsSinceEpoch ~/
        1000;
    final inherited = origin.expiresAt;
    if (inherited == null) return cap;
    return inherited < cap ? inherited : cap;
  }

  /// Погашение долга покупателя: [debtPart] — часть возврата, не
  /// вернувшаяся деньгами.
  ///
  /// Знак — зеркало продажи. Там долг уводит баланс **вниз**
  /// (`_updateAgentBalance(agentLocalId, −debitAmount)`), здесь погашение
  /// поднимает его вверх. Прежний код вычитал, то есть возврат **увеличивал**
  /// долг покупателя, а не гасил его.
  Future<void> _updateAgentBalance(
    int customerLocalId,
    Decimal debtPart,
  ) async {
    if (debtPart == Decimal.zero) return;

    final agents = await (_db.select(
      _db.agents,
    )..where((a) => a.localId.equals(customerLocalId))).get();
    if (agents.isEmpty) {
      return;
    }
    final mainAccountId = agents.first.mainAccountId;
    if (mainAccountId == null) {
      return;
    }

    await _db.accountDao.post(mainAccountId, debtPart);

    _logger.info(
      'RefundUseCase: agent $customerLocalId debt part $debtPart returned',
    );
  }
}

/// Итог сторно: сколько строк оплаты создано и на какую сумму.
class _Reversal {
  const _Reversal({required this.count, required this.reversed});

  final int count;
  final Decimal reversed;
}
