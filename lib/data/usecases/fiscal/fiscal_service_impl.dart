import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/constants/enums/product_type.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/usecases/fiscal/fiscal_position_builder.dart';
import 'package:telepos/domain/fiscal/fiscal_idempotency.dart';
import 'package:telepos/domain/fiscal/fiscal_doc_kind.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';
import 'package:telepos/domain/fiscal/fiscal_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_provider_registry.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';

class FiscalServiceImpl implements FiscalService {
  FiscalServiceImpl({
    required AppDatabase db,
    required FiscalProviderRegistry registry,
    required FiscalSettingsSource settingsSource,
    required Talker logger,
    FiscalPositionBuilder? positionBuilder,
  }) : _db = db,
       _registry = registry,
       _settingsSource = settingsSource,
       _logger = logger,
       _positions = positionBuilder ?? const FiscalPositionBuilder();

  final AppDatabase _db;
  final FiscalProviderRegistry _registry;
  final FiscalSettingsSource _settingsSource;
  final Talker _logger;
  final FiscalPositionBuilder _positions;

  @override
  Future<FiscalSettings> currentSettings() => _settingsSource.load();

  @override
  Future<bool> isEnabled() async => (await currentSettings()).isEnabled;

  Future<(FiscalProvider, FiscalSettings)> _resolve() async {
    final settings = await currentSettings();
    return (_registry.resolve(settings), settings);
  }

  @override
  Future<FiscalResult> fiscalizeSale({
    required int saleReceiptNo,
    required int salePosId,
    required Decimal amount,
    required Decimal cashAmount,
    required Decimal cardAmount,
    required Decimal mobileAmount,
    required Decimal bonusAmount,
    required Decimal offsetAmount,
    required OffsetFiscalLayout offsetLayout,
    required bool excludeCertificatePositions,
    String? customerBin,
  }) async {
    // Объявлен **снаружи** try намеренно (задача 11): при отказе документ
    // уезжает обратно вместе с результатом, чтобы строка отказа могла его
    // сохранить, а человек — повторить ровно его, тем же ключом. Внутри
    // try переменная была бы недоступна из `catch`, и брошенное исключение
    // оставило бы строку без документа — то есть неповторяемой.
    FiscalSaleRequest? built;
    try {
      final (provider, settings) = await _resolve();

      // Эпоха ключа идемпотентности — время самой продажи. Читается
      // **до** сборки позиций и до разговора с оператором: без неё
      // документу нечем назваться, а назваться занятым именем хуже, чем
      // не назваться вовсе. Разбор выбора — `FiscalIdempotency`.
      final sale = await _db.saleDao.findByKey(saleReceiptNo, salePosId);
      if (sale == null) {
        _logger.error(
          'FiscalService: чек $saleReceiptNo кассы $salePosId — '
          '${FiscalIdempotency.saleRowMissing}',
        );
        return FiscalResult.failure(
          FiscalIdempotency.saleRowMissing,
          code: FiscalErrorCode.validation,
        );
      }
      if (sale.time <= 0) {
        _logger.error(
          'FiscalService: чек $saleReceiptNo кассы $salePosId — '
          '${FiscalIdempotency.saleTimeMissing}',
        );
        return FiscalResult.failure(
          FiscalIdempotency.saleTimeMissing,
          code: FiscalErrorCode.validation,
        );
      }

      final positions = await _buildSalePositions(
        receiptNo: saleReceiptNo,
        posId: salePosId,
        settings: settings,
        bonus: bonusAmount,
        offset: offsetAmount,
        layout: offsetLayout,
        excludeCertificates: excludeCertificatePositions,
      );
      final payments = _buildPayments(cashAmount, cardAmount, mobileAmount);

      final req = FiscalSaleRequest(
        idempotencyKey: FiscalIdempotency.sale(
          saleTime: sale.time,
          receiptNo: saleReceiptNo,
          posId: salePosId,
        ),
        localOperationId: saleReceiptNo,
        positions: positions,
        payments: payments,
        totalDiscount: FiscalPositionBuilder.sumDiscounts(positions),
        totalMarkup: FiscalPositionBuilder.sumMarkups(positions),
        occurredAt: DateTime.now(),
        customer: customerBin == null
            ? null
            : FiscalCustomer(binIin: customerBin),
      );

      built = req;

      final imbalance = _imbalance(req);
      if (imbalance != null) {
        _logger.error(
          'FiscalService: конверт чека $saleReceiptNo не сводится — '
          '$imbalance. Оператору не отправлен.',
        );
        return FiscalResult.failure(
          'Конверт не сводится: $imbalance',
          code: FiscalErrorCode.validation,
        ).withDocument(req.toJson());
      }

      final result = await provider.fiscalizeSale(req);
      await _persistReceipt(
        operationId: saleReceiptNo,
        receiptNo: saleReceiptNo,
        result: result,
        kind: FiscalDocKind.sale,
      );
      _log('sale', saleReceiptNo, result);
      return result.success ? result : result.withDocument(req.toJson());
    } catch (e, st) {
      _logger.warning('FiscalService.fiscalizeSale error: $e', e, st);
      return FiscalResult.failure(
        'Ошибка фискализации: $e',
      ).withDocument(built?.toJson());
    }
  }

  @override
  Future<FiscalResult> fiscalizeRefund({
    required int refundLocalId,
    required int? originalSaleReceiptNo,
    required Decimal amount,
    required Decimal cashAmount,
    required Decimal cardAmount,
    required Decimal mobileAmount,
    required Decimal bonusAmount,
    required Decimal creditAmount,
    required Decimal offsetAmount,
    required OffsetFiscalLayout offsetLayout,
    required bool excludeCertificatePositions,
  }) async {
    try {
      final (provider, settings) = await _resolve();

      // **Долг — не оплата, а раскладка, как зачёт** (задача 26). Протокол
      // ОФД 2.0.2 исключил `PaymentType 2` «кредит» — `WebKassaProvider`
      // отказывает такому конверту до отправки, и строка оплаты «кредит»
      // сделала бы отказным каждый возврат долгового чека. Денежного расчёта
      // по доле долга нет, поэтому она ложится в позиции той же настройкой
      // оператора (`OffsetFiscalLayout`), что сертификат и аванс. Вопрос
      // бухгалтеру — в отчёте задачи 26.
      final positions = await _buildRefundPositions(
        refundLocalId: refundLocalId,
        settings: settings,
        bonus: bonusAmount,
        offset: offsetAmount + creditAmount,
        layout: offsetLayout,
        excludeCertificates: excludeCertificatePositions,
      );

      final basis = await _buildRefundBasis(
        refundLocalId: refundLocalId,
        originalSaleReceiptNo: originalSaleReceiptNo,
        settings: settings,
        fallbackTotal: amount,
      );

      // Вёдра — **что вернулось живыми деньгами и чем**. До решения
      // заказчика 2026-09-14 здесь стояла одна строка «наличные на всю
      // сумму возврата»: возврат чека, оплаченного сертификатом, выдавал
      // оператору наличный возврат денег, которых из ящика не выходило.
      final sale = FiscalSaleRequest(
        idempotencyKey: _idempotencyKey('refund', refundLocalId, 0),
        localOperationId: refundLocalId,
        positions: positions,
        payments: _buildPayments(cashAmount, cardAmount, mobileAmount),
        totalDiscount: FiscalPositionBuilder.sumDiscounts(positions),
        totalMarkup: FiscalPositionBuilder.sumMarkups(positions),
        occurredAt: DateTime.now(),
        kind: FiscalOperationKind.saleReturn,
      );

      final result = await provider.fiscalizeRefund(
        FiscalRefundRequest(sale: sale, basis: basis),
      );
      await _persistReceipt(
        operationId: refundLocalId,
        receiptNo: refundLocalId,
        result: result,
        kind: FiscalDocKind.refund,
      );
      _log('refund', refundLocalId, result);
      return result;
    } catch (e, st) {
      _logger.warning('FiscalService.fiscalizeRefund error: $e', e, st);
      return FiscalResult.failure('Ошибка фискализации возврата: $e');
    }
  }

  @override
  Future<FiscalResult> fiscalizePrepayment({
    required int operationId,
    required Decimal amount,
    required FiscalPaymentKind paymentKind,
    required String positionName,
  }) async {
    try {
      final (provider, settings) = await _resolve();

      // **НДС на чеке аванса — ноль, и это открытый вопрос бухгалтеру (A6),
      // а не решение кассы.** Оборот по НДС — день передачи товара (ст. 460
      // НК РК 2026, КГД 2019: «НДС — при передаче товара»); ставка товара на
      // чеке приёма неизвестна вовсе — аванс не привязан к позиции.
      final position = _positions.build(
        name: positionName,
        quantity: Decimal.one,
        unitPrice: amount,
        lineTotal: amount,
        settings: settings,
        productVatRate: 0,
      );

      final req = FiscalSaleRequest(
        // Своё пространство ключей: номер операции `cash_operations` не
        // пересекается с номерами чеков только по имени, а не по числу.
        idempotencyKey: _idempotencyKey('prepayment', operationId, 0),
        localOperationId: operationId,
        positions: [position],
        payments: [FiscalPayment(kind: paymentKind, amount: amount)],
        totalDiscount: Decimal.zero,
        totalMarkup: Decimal.zero,
        occurredAt: DateTime.now(),
      );

      final imbalance = _imbalance(req);
      if (imbalance != null) {
        return FiscalResult.failure(
          'Конверт не сводится: $imbalance',
          code: FiscalErrorCode.validation,
        ).withDocument(req.toJson());
      }

      final result = await provider.fiscalizeSale(req);
      // Местная запись о документе — та же дверь, что у продажи. До
      // 2026-09-19 её здесь не было вовсе; разбор трёх следствий — в
      // докстринге [_persistReceipt].
      await _persistReceipt(
        operationId: operationId,
        receiptNo: operationId,
        result: result,
        kind: FiscalDocKind.prepayment,
      );
      _log('prepayment', operationId, result);
      return result.success ? result : result.withDocument(req.toJson());
    } catch (e, st) {
      _logger.warning('FiscalService.fiscalizePrepayment error: $e', e, st);
      return FiscalResult.failure('Ошибка фискализации аванса: $e');
    }
  }

  @override
  Future<FiscalResult> fiscalizePrepaymentRefund({
    required int operationId,
    required int? intakeOperationId,
    required Decimal amount,
    required FiscalPaymentKind paymentKind,
    required String positionName,
  }) async {
    try {
      final (provider, settings) = await _resolve();

      // Позиция собирается **тем же вызовом с теми же доводами**, что у
      // приёма, и ноль НДС здесь по той же причине (ст. 460 НК РК 2026).
      // Возврат, посчитанный иначе, чем приём, развёл бы у оператора две
      // половины одного расчёта.
      final position = _positions.build(
        name: positionName,
        quantity: Decimal.one,
        unitPrice: amount,
        lineTotal: amount,
        settings: settings,
        productVatRate: 0,
      );

      final req = FiscalSaleRequest(
        // **Третьего вида ключей не заводится.** Выдача аванса — такая же
        // проводка `cash_operations`, как приём, и её номер из той же
        // последовательности; значит хватает того же пространства
        // `prepayment-<номер проводки>-0`. Отдельная голова («возврат
        // аванса») дала бы два формата на одни деньги, и совпасть им было
        // бы негде: номера всё равно разные.
        idempotencyKey: _idempotencyKey('prepayment', operationId, 0),
        localOperationId: operationId,
        positions: [position],
        payments: [FiscalPayment(kind: paymentKind, amount: amount)],
        totalDiscount: Decimal.zero,
        totalMarkup: Decimal.zero,
        occurredAt: DateTime.now(),
        kind: FiscalOperationKind.saleReturn,
      );

      final imbalance = _imbalance(req);
      if (imbalance != null) {
        return FiscalResult.failure(
          'Конверт не сводится: $imbalance',
          code: FiscalErrorCode.validation,
        ).withDocument(req.toJson());
      }

      final result = await provider.fiscalizeRefund(
        FiscalRefundRequest(
          sale: req,
          basis: await _prepaymentRefundBasis(
            intakeOperationId: intakeOperationId,
            settings: settings,
            fallbackTotal: amount,
          ),
        ),
      );
      await _persistReceipt(
        operationId: operationId,
        receiptNo: operationId,
        result: result,
        kind: FiscalDocKind.prepaymentRefund,
      );
      _log('prepaymentRefund', operationId, result);
      return result.success ? result : result.withDocument(req.toJson());
    } catch (e, st) {
      _logger.warning(
        'FiscalService.fiscalizePrepaymentRefund error: $e',
        e,
        st,
      );
      return FiscalResult.failure('Ошибка фискализации возврата аванса: $e');
    }
  }

  /// Основание возврата аванса — **чек того приёма, который называет
  /// вызывающий**, и ничей больше.
  ///
  /// # Почему приём не разыскивается здесь
  ///
  /// Соблазн есть: строки приёмов лежат рядом, и «взять последний чек
  /// аванса этого покупателя» пишется одной строкой. Но аванс — **пул**:
  /// тысяча могла прийти тремя взносами, и признак последнего из них не
  /// является основанием для возврата всей суммы. Документ, сославшийся на
  /// чужой чек, выглядит правильным у оператора и врёт о том, какие
  /// деньги возвращаются.
  ///
  /// Поэтому здесь ровно два исхода, и оба названы: приём назван — берём
  /// его признак; не назван — признак пуст, и это **возврат без чека
  /// основания**, та же форма, что у `_buildRefundBasis` с пустым номером
  /// чека.
  ///
  /// # Чего это НЕ доказывает
  ///
  /// Пустое основание не означает, что чека приёма не было: оно означает,
  /// что его не назвали. Кто и каким экраном будет называть — открыто
  /// (отчёт дорожки, 2026-09-19).
  Future<FiscalRefundBasis> _prepaymentRefundBasis({
    required int? intakeOperationId,
    required FiscalSettings settings,
    required Decimal fallbackTotal,
  }) async {
    var sign = '';
    var wasOffline = false;
    var when = DateTime.now();

    if (intakeOperationId != null) {
      final receipt = await _db.webkassaReceiptDao.findByKindAndOperationId(
        FiscalDocKind.prepayment,
        intakeOperationId,
      );
      if (receipt != null) {
        sign = receipt.fiscalNo ?? '';
        wasOffline = receipt.wkOfflineMode ?? false;
        if (receipt.wkTime != null) {
          when = DateTime.fromMillisecondsSinceEpoch(receipt.wkTime! * 1000);
        }
      }
    }

    return FiscalRefundBasis(
      originalFiscalSign: sign,
      originalDateTime: when,
      originalRegistrationNumber: settings.registrationNumber ?? '',
      originalTotal: fallbackTotal,
      originalWasOffline: wasOffline,
      // Ключ приёма собирается **тем же выражением**, что и при приёме
      // (`_idempotencyKey('prepayment', operationId, 0)`), — и только если
      // приём назван. Не назван — ссылаться не на что, и очередь остаётся
      // осторожной: это тот же выбор, что у пустого признака выше.
      originalIdempotencyKey: intakeOperationId == null
          ? null
          : _idempotencyKey('prepayment', intakeOperationId, 0),
    );
  }

  @override
  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req) async {
    try {
      final (provider, _) = await _resolve();
      return await provider.fiscalizePurchase(req);
    } catch (e, st) {
      _logger.warning('FiscalService.fiscalizePurchase error: $e', e, st);
      return FiscalResult.failure('Ошибка фискализации покупки: $e');
    }
  }

  @override
  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req) async {
    try {
      final (provider, _) = await _resolve();
      return await provider.fiscalizePurchaseReturn(req);
    } catch (e, st) {
      _logger.warning('FiscalService.fiscalizePurchaseReturn error: $e', e, st);
      return FiscalResult.failure('Ошибка фискализации возврата покупки: $e');
    }
  }

  @override
  Future<FiscalResult> moneyIn({
    required Decimal amount,
    String? comment,
    String? idempotencyKey,
  }) async {
    try {
      final (provider, _) = await _resolve();
      return await provider.moneyIn(_moneyReq(amount, comment, idempotencyKey));
    } catch (e, st) {
      _logger.warning('FiscalService.moneyIn error: $e', e, st);
      return FiscalResult.failure('Ошибка фискализации внесения: $e');
    }
  }

  @override
  Future<FiscalResult> moneyOut({
    required Decimal amount,
    String? comment,
    String? idempotencyKey,
  }) async {
    try {
      final (provider, _) = await _resolve();
      return await provider.moneyOut(
        _moneyReq(amount, comment, idempotencyKey),
      );
    } catch (e, st) {
      _logger.warning('FiscalService.moneyOut error: $e', e, st);
      return FiscalResult.failure('Ошибка фискализации изъятия: $e');
    }
  }

  @override
  Future<FiscalResult> openShift() async {
    try {
      final (provider, _) = await _resolve();
      return await provider.openShift(const FiscalShiftRequest());
    } catch (e, st) {
      _logger.warning('FiscalService.openShift error: $e', e, st);
      return FiscalResult.failure('Ошибка открытия смены: $e');
    }
  }

  @override
  Future<FiscalReportResult> closeShift() async {
    try {
      final (provider, _) = await _resolve();
      final report = await provider.closeShift(const FiscalShiftRequest());
      _log('closeShift(Z)', report.shiftNumber ?? 0, report.result);
      return report;
    } catch (e, st) {
      _logger.warning('FiscalService.closeShift error: $e', e, st);
      return FiscalReportResult.failure('Ошибка Z-отчёта: $e');
    }
  }

  @override
  Future<FiscalReportResult> xReport() async {
    try {
      final (provider, _) = await _resolve();
      return await provider.xReport(const FiscalShiftRequest());
    } catch (e, st) {
      _logger.warning('FiscalService.xReport error: $e', e, st);
      return FiscalReportResult.failure('Ошибка X-отчёта: $e');
    }
  }

  @override
  Future<FiscalResult> correction(FiscalCorrectionRequest req) async {
    try {
      final (provider, _) = await _resolve();
      return await provider.correctionReceipt(req);
    } catch (e, st) {
      _logger.warning('FiscalService.correction error: $e', e, st);
      return FiscalResult.failure('Ошибка чека коррекции: $e');
    }
  }

  @override
  Future<FiscalStatus> status() async {
    try {
      final (provider, _) = await _resolve();
      return await provider.getStatus();
    } catch (e, st) {
      _logger.warning('FiscalService.status error: $e', e, st);
      return FiscalStatus.notConfigured();
    }
  }

  /// Сумма позиций **как её насчитает оператор** минус сумма оплат.
  ///
  /// `null`, если сошлось. Иначе — текст с обоими числами.
  ///
  /// # Зачем это стоит здесь, а не только в эмуляторе
  ///
  /// Оба дефекта задач 6 и 7 — потерянная скидка и не учтённый бонус —
  /// прошли мимо 4362 зелёных проб ровно потому, что **сама касса ни разу
  /// не складывала конверт, который отправляет**. Отказ приходил от
  /// оператора кодом 9, то есть уже после того, как деньги взяты, и на
  /// боевой кассе выглядел бы как «документа нет» без всякого объяснения.
  ///
  /// Формула снята с `WebKassaProvider._positionToJson` и совпадает с
  /// пересчётом эмулятора (`lib/emulators/webkassa/state.dart`): строка
  /// это `round2(Count) × round2(Price)`, округлённое до копейки, минус
  /// `Discount`, плюс `Markup`. Допуск нулевой — тот же, что у
  /// оператора.
  ///
  /// **Чего эта проверка НЕ делает: она не отменяет денег.** Деньги к
  /// этому моменту уже записаны (`LocalPaymentService.complete` зовёт
  /// `_sale.perform` раньше `_fiscalize`), и переносить проверку туда —
  /// отдельная работа со своей спекой: она меняет исход продажи, а не
  /// только конверт. Здесь она стоит **перед отправкой** и делает ровно
  /// две вещи: не даёт кассе отправить заведомо несводимый документ и
  /// называет причину числом в журнале кассы, а не кодом 9 из чужого
  /// ответа.
  String? _imbalance(FiscalSaleRequest req) {
    var positionsTotal = Decimal.zero;
    for (final p in req.positions) {
      final gross =
          (p.quantity.round(scale: FiscalPositionBuilder.quantityScale) *
                  p.unitPrice.round(scale: FiscalPositionBuilder.moneyScale))
              .round(scale: FiscalPositionBuilder.moneyScale);
      positionsTotal += gross - p.discountOr + p.markupOr;
    }
    final paymentsTotal = req.payments.fold(
      Decimal.zero,
      (Decimal s, p) =>
          s + p.amount.round(scale: FiscalPositionBuilder.moneyScale),
    );
    if (positionsTotal == paymentsTotal) return null;
    return 'сумма позиций $positionsTotal, сумма оплат $paymentsTotal, '
        'разность ${positionsTotal - paymentsTotal}';
  }

  /// Позиции продажи — и **раскладка списанного бонуса и зачёта по ним**.
  ///
  /// [bonus] уменьшает платёж покупателя, но не трогает ни цену строки,
  /// ни её сумму в базе: он ушёл с бонусного счёта. Поэтому он входит
  /// **слагаемым** в поле `Discount` каждой строки
  /// (`FiscalPositionBuilder.lineDiscount`, довод `extraDiscount`), доля
  /// считается один раз общим правилом
  /// (`FiscalPositionBuilder.distributeBonus`), и второго числа скидки у
  /// чека не заводится.
  ///
  /// [offset] (сертификат, аванс) делится **тем же правилом** и ложится по
  /// [layout] — разбор у [_layOut].
  ///
  /// [excludeCertificates] — строки товара рода
  /// [ProductType.giftCertificate] в документ не идут вовсе, и в раскладке
  /// не участвуют: их деньги вызывающий уже вычел из вёдер.
  Future<List<FiscalPosition>> _buildSalePositions({
    required int receiptNo,
    required int posId,
    required FiscalSettings settings,
    required Decimal bonus,
    required Decimal offset,
    required OffsetFiscalLayout layout,
    required bool excludeCertificates,
  }) async {
    final all = await _db.saleProductDao.findBySale(receiptNo, posId);
    final lines = <(SaleProduct, ProductInfo?)>[];
    for (final sp in all) {
      final product = await _db.productInfoDao.findByUcode(sp.ucode);
      if (excludeCertificates &&
          product?.type == ProductType.giftCertificate.index) {
        continue;
      }
      lines.add((sp, product));
    }

    // Раскладка идёт по **уже известным** суммам всех строк: доля первой
    // строки зависит от суммы последней, и посчитать её внутри цикла
    // сборки нечем.
    final lineTotals = [for (final (sp, _) in lines) sp.quantity * sp.price];
    final bonusShares = FiscalPositionBuilder.distributeBonus(
      bonus: bonus,
      lineTotals: lineTotals,
    );
    final offsetShares = FiscalPositionBuilder.distributeBonus(
      bonus: offset,
      lineTotals: lineTotals,
    );

    final positions = <FiscalPosition>[];
    for (var i = 0; i < lines.length; i++) {
      final (sp, product) = lines[i];
      final laid = _layOut(
        quantity: sp.quantity,
        // Цена ДО скидки. Уценённая цена в этом поле означала для
        // оператора чек без скидки, только дешевле, — а разница между
        // двумя масштабами хранения цены разводила сумму позиций с
        // суммой оплат на копейку. Скидку выводит сам билдер, см. его
        // докстринг.
        priceBefore: sp.priceBefore,
        lineTotal: lineTotals[i],
        bonusShare: bonusShares[i],
        offsetShare: offsetShares[i],
        layout: layout,
      );

      final isMarkable = product?.isMarkable ?? false;
      var markCodes = const <String>[];
      if (isMarkable) {
        final marks = await _db.saleProductDao.findMarksBySaleProduct(sp.id);
        markCodes = marks
            .map((m) => m.mark)
            .whereType<String>()
            .where((m) => m.isNotEmpty)
            .toList();
      }

      positions.add(
        _positions.build(
          name: product?.name ?? 'Товар ${sp.ucode}',
          quantity: sp.quantity,
          unitPrice: laid.unitPrice,
          lineTotal: laid.lineTotal,
          settings: settings,
          productVatRate: product?.vatRate,
          ntin: product?.ntin,
          barcode: sp.barcode?.toString() ?? product?.barcode.toString(),
          isMarkable: isMarkable,
          markCodes: markCodes,
          // Слагаемое, а не второе поле. Ноль здесь — «бонуса не было»,
          // и билдер тогда не трогает ни цену, ни скидку строки.
          extraDiscount: laid.extraDiscount,
        ),
      );
    }
    return positions;
  }

  /// Доля зачёта в строке — **по выбранной оператором раскладке**.
  ///
  /// * [OffsetFiscalLayout.discount] — доля входит слагаемым скидки, как
  ///   бонус: цена полная, `Discount` вырос на долю. База НДС — доплата.
  /// * [OffsetFiscalLayout.surchargeOnly] — доля **уменьшает цену и сумму
  ///   строки**: документ выписан только на доплату, поля скидки под
  ///   зачёт нет. Ручная скидка кассира остаётся своим полем — её билдер
  ///   выводит, как и прежде, из разницы цены до скидки и суммы строки.
  ///   Копейка от деления доли на количество ложится туда же и сводится
  ///   тождеством билдера.
  ///
  /// `switch` исчерпывающий: третья раскладка сломает сборку здесь.
  ({Decimal unitPrice, Decimal lineTotal, Decimal extraDiscount}) _layOut({
    required Decimal quantity,
    required Decimal priceBefore,
    required Decimal lineTotal,
    required Decimal bonusShare,
    required Decimal offsetShare,
    required OffsetFiscalLayout layout,
  }) {
    switch (layout) {
      case OffsetFiscalLayout.discount:
        return (
          unitPrice: priceBefore,
          lineTotal: lineTotal,
          extraDiscount: bonusShare + offsetShare,
        );
      case OffsetFiscalLayout.surchargeOnly:
        if (offsetShare == Decimal.zero || quantity == Decimal.zero) {
          return (
            unitPrice: priceBefore,
            lineTotal: lineTotal,
            extraDiscount: bonusShare,
          );
        }
        final perUnit = (offsetShare / quantity).toDecimal(
          scaleOnInfinitePrecision: 10,
        );
        return (
          unitPrice: priceBefore - perUnit,
          lineTotal: lineTotal - offsetShare,
          extraDiscount: bonusShare,
        );
    }
  }

  /// Позиции возврата — зеркало [_buildSalePositions] (задача 26).
  ///
  /// [bonus] ложится слагаемым скидки тем же правилом
  /// (`FiscalPositionBuilder.distributeBonus`), что у продажи: до задачи 26
  /// здесь стоял ноль, а доля бонуса уезжала оператору наличными.
  /// [excludeCertificates] — строки проданных сертификатов в документ не
  /// идут и в раскладке не участвуют.
  Future<List<FiscalPosition>> _buildRefundPositions({
    required int refundLocalId,
    required FiscalSettings settings,
    required Decimal bonus,
    required Decimal offset,
    required OffsetFiscalLayout layout,
    required bool excludeCertificates,
  }) async {
    final all = await _db.refundDao.findProductsByRefund(refundLocalId);
    final lines = <(RefundProduct, ProductInfo?)>[];
    for (final rp in all) {
      final product = await _db.productInfoDao.findByUcode(rp.ucode);
      if (excludeCertificates &&
          product?.type == ProductType.giftCertificate.index) {
        continue;
      }
      lines.add((rp, product));
    }
    final lineTotals = [for (final (rp, _) in lines) rp.quantity * rp.price];
    final bonusShares = FiscalPositionBuilder.distributeBonus(
      bonus: bonus,
      lineTotals: lineTotals,
    );
    final offsetShares = FiscalPositionBuilder.distributeBonus(
      bonus: offset,
      lineTotals: lineTotals,
    );

    final positions = <FiscalPosition>[];
    for (var i = 0; i < lines.length; i++) {
      final (rp, product) = lines[i];
      final laid = _layOut(
        quantity: rp.quantity,
        priceBefore: _refundPriceBefore(rp),
        lineTotal: lineTotals[i],
        bonusShare: bonusShares[i],
        offsetShare: offsetShares[i],
        layout: layout,
      );

      final isMarkable = product?.isMarkable ?? false;
      var markCodes = const <String>[];
      if (isMarkable) {
        final marks = await _db.refundDao.findMarksByRefundProduct(rp.id);
        markCodes = marks
            .map((m) => m.mark)
            .whereType<String>()
            .where((m) => m.isNotEmpty)
            .toList();
      }

      positions.add(
        _positions.build(
          name: product?.name ?? 'Товар ${rp.ucode}',
          quantity: rp.quantity,
          unitPrice: laid.unitPrice,
          lineTotal: laid.lineTotal,
          settings: settings,
          productVatRate: product?.vatRate,
          ntin: product?.ntin,
          barcode: product?.barcode.toString(),
          isMarkable: isMarkable,
          markCodes: markCodes,
          extraDiscount: laid.extraDiscount,
        ),
      );
    }
    return positions;
  }

  /// Основание возврата: признак продажи, её время, сумма — **и её ключ**.
  ///
  /// # Зачем здесь ключ продажи (2026-09-19)
  ///
  /// Чтобы очередь автономной фискализации могла отличить «моя продажа
  /// застряла» от «застряла чужая». До этой правки отличить было нечем, и
  /// очередь держала **все** возвраты, пока в ней лежала **любая** строка:
  /// у заказчика это выглядело как остановленная фискализация посторонних
  /// документов. Разбор правила — `FiscalQueueDependency`.
  ///
  /// Ключ собирается **тем же строителем**, что и ключ самой продажи
  /// (`FiscalIdempotency.sale`), из тех же трёх чисел: время чека, номер,
  /// касса. Собрать его иначе значило бы сверять ссылку с ключом по
  /// совпадению формата, а не по происхождению.
  ///
  /// Касса берётся из строки возврата (`Refunds.salePosId`), а не
  /// подставляется своей: возврат по чеку **чужой** кассы — обычное дело,
  /// и его основание живёт под ключом той кассы.
  ///
  /// # Чего это НЕ доказывает
  ///
  /// Что основание вообще лежало в очереди. Пусто здесь означает «назвать
  /// нечем»: возврат без чека, продажа, которой нет в базе, или чек, не
  /// завершённый по времени (`time = 0` — тот же случай, на котором
  /// отказывает `fiscalizeSale`). На пустом значении очередь остаётся
  /// осторожной, а не становится смелой.
  Future<FiscalRefundBasis> _buildRefundBasis({
    required int refundLocalId,
    required int? originalSaleReceiptNo,
    required FiscalSettings settings,
    required Decimal fallbackTotal,
  }) async {
    var originalSign = '';
    var originalWasOffline = false;
    var originalDateTime = DateTime.now();
    var originalTotal = fallbackTotal;
    String? originalKey;

    final refundRow = await _db.refundDao.findById(refundLocalId);
    final basisReceiptNo = refundRow?.saleReceiptNo ?? originalSaleReceiptNo;
    final basisPosId = refundRow?.salePosId;
    if (basisReceiptNo != null && basisPosId != null) {
      final basisSale = await _db.saleDao.findByKey(basisReceiptNo, basisPosId);
      if (basisSale != null && basisSale.time > 0) {
        originalKey = FiscalIdempotency.sale(
          saleTime: basisSale.time,
          receiptNo: basisReceiptNo,
          posId: basisPosId,
        );
      }
    }

    if (originalSaleReceiptNo != null) {
      final receipt = await _db.webkassaReceiptDao.findByKindAndOperationId(
        FiscalDocKind.sale,
        originalSaleReceiptNo,
      );
      if (receipt != null) {
        originalSign = receipt.fiscalNo ?? '';
        originalWasOffline = receipt.wkOfflineMode ?? false;
        if (receipt.wkTime != null) {
          originalDateTime = DateTime.fromMillisecondsSinceEpoch(
            receipt.wkTime! * 1000,
          );
        }
      }
      final sale = await _db.saleDao.findBySaleId(originalSaleReceiptNo);
      if (sale != null) {
        originalTotal = sale.amount;
      }
    }

    return FiscalRefundBasis(
      originalFiscalSign: originalSign,
      originalDateTime: originalDateTime,
      originalRegistrationNumber: settings.registrationNumber ?? '',
      originalTotal: originalTotal,
      originalWasOffline: originalWasOffline,
      originalIdempotencyKey: originalKey,
    );
  }

  /// Цена единицы **до** скидки для строки возврата.
  ///
  /// У `RefundProducts` нет колонки `priceBefore`: цену до скидки несёт
  /// `inSalePriceBefore` — «какой она была в той продаже». Возврат по чеку
  /// её заполняет (`RefundReceiptProductServiceImpl` кладёт туда
  /// `SaleProducts.priceBefore`), возврат без чека — нет.
  ///
  /// Запасной ход именованный: пусто означает **«скидки не было»**, а не
  /// «не знаем». Иначе скидка возврата была бы выдумана из воздуха, а
  /// сумма позиций разошлась бы с суммой возвращённых денег.
  Decimal _refundPriceBefore(RefundProduct rp) =>
      rp.inSalePriceBefore ?? rp.price;

  /// Строки оплаты конверта — **по одной на ведро живых денег**.
  ///
  /// Мобильный (QR/СБП) — своё ведро с задачи C плана 2026-09-14: до него
  /// оплата телефоном уезжала оператору картой (`PaymentType 1` вместо 4).
  List<FiscalPayment> _buildPayments(
    Decimal cash,
    Decimal card,
    Decimal mobile,
  ) {
    final payments = <FiscalPayment>[];
    if (cash > Decimal.zero) {
      payments.add(FiscalPayment(kind: FiscalPaymentKind.cash, amount: cash));
    }
    if (card > Decimal.zero) {
      payments.add(FiscalPayment(kind: FiscalPaymentKind.card, amount: card));
    }
    if (mobile > Decimal.zero) {
      payments.add(
        FiscalPayment(kind: FiscalPaymentKind.mobile, amount: mobile),
      );
    }
    if (payments.isEmpty) {
      payments.add(
        FiscalPayment(kind: FiscalPaymentKind.cash, amount: Decimal.zero),
      );
    }
    return payments;
  }

  FiscalMoneyRequest _moneyReq(Decimal amount, String? comment, String? key) =>
      FiscalMoneyRequest(
        idempotencyKey: key ?? 'money-${DateTime.now().microsecondsSinceEpoch}',
        amount: amount,
        occurredAt: DateTime.now(),
        comment: comment,
      );

  /// Ключ **возврата и аванса**. Продажа сюда больше не ходит — её ключ
  /// строит [FiscalIdempotency.sale], и там же разбор, почему.
  ///
  /// Эти два остались на прежнем формате не по недосмотру, а потому что
  /// их номера не перезапускаются: `refundLocalId` — автоинкремент
  /// `Refunds`, `operationId` аванса — автоинкремент своей таблицы, и
  /// `OldSaleCleanupService` не трогает ни ту, ни другую (он знает ровно
  /// три таблицы: `Sales`, `SaleProducts`, `Payments`). Уборка, которая
  /// однажды до них доберётся, вернёт им ровно этот дефект — и тогда им
  /// понадобится своя эпоха, а не общий доверчивый формат.
  String _idempotencyKey(String op, int id1, int id2) => '$op-$id1-$id2';

  /// Местная запись о документе — **одна дверь на все четыре рода**.
  ///
  /// # Почему аванс ходит сюда, а не заводит свою запись
  ///
  /// До 2026-09-19 [fiscalizePrepayment] не писала сюда вовсе (замер:
  /// после успешной фискализации аванса в `webkassa_receipts` ноль строк).
  /// Следствий три, и ни одно не видно кассиру в момент приёма: чек
  /// аванса, уехавший в автономном режиме, никогда не переспрашивался
  /// (`WebKassaServiceImpl.syncOfflineReceipts` ходит по этой таблице),
  /// его фискальный признак нечем напечатать (`receipt_requisites.dart`),
  /// и у выдачи аванса нет основания — возврат опирается на признак чека
  /// приёма.
  ///
  /// Вторая запись рядом закрыла бы первое следствие и разошлась бы с
  /// продажей в первую же правку — поэтому дверь одна.
  ///
  /// [kind] обязателен, потому что он **половина ключа строки** (v50):
  /// номера у четырёх родов из четырёх разных последовательностей, и на
  /// новой кассе все начинаются с единицы. Разбор — в докстринге
  /// [FiscalDocKind]; `isSale` выводится родом, а не приходит вторым
  /// доводом, чтобы два поля об одном не разошлись.
  ///
  /// # Чего это НЕ доказывает
  ///
  /// Строки здесь нет, если документ не уехал или уехал без признака
  /// (`hasFiscalSign`): эта таблица — память о принятом документе, а не
  /// очередь. Неуехавшее держит `FiscalQueueEntries`, и именно её читает
  /// экран нефискализованных чеков.
  Future<void> _persistReceipt({
    required int operationId,
    required int receiptNo,
    required FiscalResult result,
    required FiscalDocKind kind,
  }) async {
    if (!result.success || !result.hasFiscalSign) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _db.webkassaReceiptDao.insertReceipt(
        WebkassaReceiptsCompanion(
          operationId: Value(operationId),
          receiptNo: Value(receiptNo),
          fiscalNo: Value(result.fiscalSign),
          wkReceiptNo: Value(result.documentNumber?.toString()),
          wkTime: Value(now),
          wkOfflineMode: Value(result.offlineMode),
          ticketUrl: Value(result.ticketUrl),
          isSale: Value(kind.isSale),
          docKind: Value(kind.index),
        ),
      );
    } catch (e, st) {
      _logger.warning('FiscalService: persist receipt failed: $e', e, st);
    }
  }

  void _log(String op, int id, FiscalResult r) {
    if (r.success) {
      if (r.queued) {
        _logger.info('Fiscal $op #$id queued offline');
      } else {
        _logger.info('Fiscal $op #$id ok: sign=${r.fiscalSign}');
      }
    } else {
      _logger.warning(
        'Fiscal $op #$id failed: ${r.errorMessage} '
        '(${r.errorCode})',
      );
    }
  }
}
