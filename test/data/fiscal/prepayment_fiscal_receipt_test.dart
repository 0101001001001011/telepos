/// Чек аванса — **местная запись о документе**, приём и выдача.
///
/// # Две дыры, которые здесь закрыты, и как они мерились
///
/// **Первая (замер 2026-09-19): `fiscalizePrepayment` не писала в
/// `webkassa_receipts` вовсе.** Проба до правки: после успешной
/// фискализации аванса в таблице **ноль строк**. Следствий три, и ни одно
/// не видно кассиру в момент приёма — чек, уехавший автономно, никогда не
/// переспрашивался (`syncOfflineReceipts` ходит по этой таблице), признак
/// нечем напечатать (`receipt_requisites.dart`), и у выдачи аванса нет
/// основания.
///
/// **Вторая: выдачи аванса не существовало.** `FiscalService` умел приём и
/// не умел возврат; разбор — в докстринге
/// [FiscalService.fiscalizePrepaymentRefund].
///
/// # Почему проба «строка появилась» одна ничего не доказывает
///
/// Ключом строки был **один** `operationId`, а номер аванса приходит из
/// `CashOperations` — своей последовательности. На новой кассе первый
/// аванс получает номер 1, и продажа тоже: наивная починка («позвать
/// `_persistReceipt`») на такой кассе молча теряла бы запись в `catch`.
/// Поэтому главная проба здесь — **продажа и аванс с ОДНИМ номером**, и
/// она красна на всякой починке, не расширившей ключ.
///
/// # Чего эти пробы НЕ доказывают
///
/// Ничего о самом документе у оператора: провайдер здесь поддельный, и
/// содержимое конверта мерят `fiscal_envelope_balance_test.dart` и
/// эмулятор WebKassa. Здесь мерится только память кассы о том, что
/// документ был, и его род.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/usecases/fiscal/fiscal_service_impl.dart';
import 'package:telepos/domain/fiscal/fiscal_doc_kind.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';
import 'package:telepos/domain/fiscal/fiscal_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_provider_registry.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';

void main() {
  late AppDatabase db;
  late Talker logger;
  late _CapturingRegistry registry;

  const posId = 1;

  Decimal d(String v) => Decimal.parse(v);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    logger = Talker(settings: TalkerSettings(enabled: false));
    registry = _CapturingRegistry();
  });

  tearDown(() async {
    await db.close();
  });

  FiscalServiceImpl service() => FiscalServiceImpl(
    db: db,
    registry: registry,
    settingsSource: _FixedSettings(
      FiscalSettings(
        operatorType: FiscalOperatorType.webkassa,
        apiKey: 'WKD-1',
        login: 'a@b.kz',
        cashboxUniqueNumber: 'SWK00000001',
        registrationNumber: 'РНМ-1',
      ),
    ),
    logger: logger,
  );

  /// Настоящая продажа с позицией — иначе `fiscalizeSale` отказывает
  /// «строки продажи нет», и проба про столкновение номеров измерила бы
  /// отказ, а не запись.
  Future<void> sell(int receiptNo) async {
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: receiptNo,
            posId: posId,
            userId: 1,
            amount: d('300'),
            time: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );
    await db
        .into(db.saleProducts)
        .insert(
          SaleProductsCompanion(
            receiptNo: Value(receiptNo),
            posId: const Value(posId),
            ucode: const Value(100),
            barcode: const Value(4870001234567),
            categoryId: const Value(1),
            quantity: Value(d('3')),
            price: Value(d('100')),
            priceBefore: Value(d('100')),
          ),
        );
    final result = await service().fiscalizeSale(
      saleReceiptNo: receiptNo,
      salePosId: posId,
      amount: d('300'),
      cashAmount: d('300'),
      cardAmount: Decimal.zero,
      mobileAmount: Decimal.zero,
      bonusAmount: Decimal.zero,
      offsetAmount: Decimal.zero,
      offsetLayout: OffsetFiscalLayout.discount,
      excludeCertificatePositions: false,
    );
    expect(result.success, isTrue, reason: result.errorMessage);
  }

  Future<FiscalResult> takeAdvance(int operationId, String amount) =>
      service().fiscalizePrepayment(
        operationId: operationId,
        amount: d(amount),
        paymentKind: FiscalPaymentKind.card,
        positionName: 'Аванс (предоплата) — Иванов',
      );

  group('приём аванса оставляет местную запись', () {
    test('успешный чек аванса — строка рода «приём аванса»', () async {
      final result = await takeAdvance(7, '700');
      expect(result.success, isTrue);

      final row = await db.webkassaReceiptDao.findByKindAndOperationId(
        FiscalDocKind.prepayment,
        7,
      );
      expect(
        row,
        isNotNull,
        reason:
            'до 2026-09-19 здесь был ноль строк: чек аванса уезжал '
            'оператору, а касса о нём не помнила ничего',
      );
      expect(row!.fiscalNo, 'CAP-1');
      expect(row.receiptNo, 7);
      expect(
        row.isSale,
        isTrue,
        reason:
            'приём аванса — приход, как продажа: это читают печать '
            'реквизитов и обмен',
      );
    });

    test('ПРОДАЖА №7 и АВАНС №7 — две записи, а не одна', () async {
      // Главная проба файла. Номер чека и номер проводки `cash_operations`
      // — разные последовательности, и на новой кассе обе начинаются с
      // единицы. Починка, не расширившая ключ строки, теряет вторую
      // запись молча: вставка падает `UNIQUE constraint failed`, а
      // `_persistReceipt` глотает падение строкой журнала.
      await sell(7);
      expect((await takeAdvance(7, '700')).success, isTrue);

      final sale = await db.webkassaReceiptDao.findByKindAndOperationId(
        FiscalDocKind.sale,
        7,
      );
      final advance = await db.webkassaReceiptDao.findByKindAndOperationId(
        FiscalDocKind.prepayment,
        7,
      );

      expect(sale, isNotNull, reason: 'чек продажи №7 затёрт авансом');
      expect(advance, isNotNull, reason: 'чек аванса №7 затёрт продажей');
      expect(
        (await db.select(db.webkassaReceipts).get()).length,
        2,
        reason:
            'двум документам — две строки; одна означает, что вторая '
            'потерялась в catch',
      );
    });

    test('оператор отказал — строки нет, и это не «документ есть»', () async {
      registry.provider.refuse = true;

      final result = await takeAdvance(9, '700');
      expect(result.success, isFalse);
      expect(
        await db.select(db.webkassaReceipts).get(),
        isEmpty,
        reason:
            'эта таблица — память о ПРИНЯТОМ документе; неуехавшее '
            'держит очередь фискализации, и её читает экран '
            'нефискализованных чеков',
      );
    });
  });

  group('выдача аванса деньгами — фискальный возврат', () {
    test('документ уходит возвратом продажи, а не продажей', () async {
      final result = await service().fiscalizePrepaymentRefund(
        operationId: 21,
        intakeOperationId: null,
        amount: d('700'),
        paymentKind: FiscalPaymentKind.cash,
        positionName: 'Возврат аванса — Иванов',
      );

      expect(result.success, isTrue, reason: result.errorMessage);
      final sent = registry.provider.captured.single;
      expect(
        sent.kind,
        FiscalOperationKind.saleReturn,
        reason:
            'выдача, уехавшая продажей, прибавила бы оператору выручку '
            'вместо того, чтобы её уменьшить',
      );
      expect(
        registry.provider.refundCalls,
        1,
        reason:
            'возврат обязан идти дверью возврата провайдера: у неё своё '
            'основание, а `fiscalizeSale` его не несёт вовсе',
      );
      expect(sent.payments.single.kind, FiscalPaymentKind.cash);
      expect(sent.payments.single.amount, d('700'));
      expect(sent.positions.single.lineTotal, d('700'));
    });

    test('ключ идемпотентности — того же вида, что у приёма', () async {
      // «Не заводи третий вид»: выдача — такая же проводка
      // `cash_operations`, её номер из той же последовательности, и
      // отдельная голова ключа дала бы два формата на одни деньги.
      await takeAdvance(7, '700');
      await service().fiscalizePrepaymentRefund(
        operationId: 8,
        intakeOperationId: 7,
        amount: d('700'),
        paymentKind: FiscalPaymentKind.cash,
        positionName: 'Возврат аванса',
      );

      expect(registry.provider.captured.map((r) => r.idempotencyKey).toList(), [
        'prepayment-7-0',
        'prepayment-8-0',
      ]);
    });

    test('основание — чек НАЗВАННОГО приёма, и его признак', () async {
      await takeAdvance(7, '700');
      await service().fiscalizePrepaymentRefund(
        operationId: 8,
        intakeOperationId: 7,
        amount: d('700'),
        paymentKind: FiscalPaymentKind.cash,
        positionName: 'Возврат аванса',
      );

      expect(registry.provider.bases.single.originalFiscalSign, 'CAP-1');
      expect(
        registry.provider.bases.single.originalRegistrationNumber,
        'РНМ-1',
      );
    });

    test('приём не назван — основание пустое, а не чужое', () async {
      // Аванс это пул: тысяча могла прийти тремя взносами, и признак
      // последнего из них не является основанием для возврата всей суммы.
      // Документ, сославшийся на чужой чек, у оператора выглядит
      // правильным и врёт о том, какие деньги возвращаются.
      await takeAdvance(7, '700');
      await service().fiscalizePrepaymentRefund(
        operationId: 8,
        intakeOperationId: null,
        amount: d('700'),
        paymentKind: FiscalPaymentKind.cash,
        positionName: 'Возврат аванса',
      );

      expect(
        registry.provider.bases.single.originalFiscalSign,
        '',
        reason:
            'пустое основание значит «приём не назван», а не «приёма не '
            'было»: сходить за последним чеком покупателя самому — это и '
            'есть ссылка на чужой документ',
      );
    });

    test('выдача №7 и приём №7 — две записи разного рода', () async {
      await takeAdvance(7, '700');
      await service().fiscalizePrepaymentRefund(
        operationId: 7,
        intakeOperationId: null,
        amount: d('700'),
        paymentKind: FiscalPaymentKind.cash,
        positionName: 'Возврат аванса',
      );

      final intake = await db.webkassaReceiptDao.findByKindAndOperationId(
        FiscalDocKind.prepayment,
        7,
      );
      final payout = await db.webkassaReceiptDao.findByKindAndOperationId(
        FiscalDocKind.prepaymentRefund,
        7,
      );
      expect(intake!.fiscalNo, 'CAP-1');
      expect(payout, isNotNull);
      expect(payout!.fiscalNo, 'CAP-2');
      expect(
        payout.isSale,
        isFalse,
        reason:
            'выдача — расход кассы; приход и расход с одним номером '
            'различает род, а не `is_sale`',
      );
    });
  });
}

class _FixedSettings implements FiscalSettingsSource {
  _FixedSettings(this.settings);

  final FiscalSettings settings;

  @override
  Future<FiscalSettings> load() async => settings;
}

class _CapturingRegistry extends FiscalProviderRegistry {
  final _CapturingProvider provider = _CapturingProvider();

  @override
  FiscalProvider resolve(FiscalSettings settings) => provider;
}

class _CapturingProvider implements FiscalProvider {
  final List<FiscalSaleRequest> captured = [];
  final List<FiscalRefundBasis> bases = [];
  int refundCalls = 0;
  bool refuse = false;

  @override
  String get id => 'capture';

  @override
  FiscalCapabilities get capabilities => FiscalCapabilities.none;

  @override
  Future<FiscalAuthResult> authorize(FiscalSettings config) async =>
      FiscalAuthResult.ok();

  @override
  String? validateConfig(FiscalSettings config) => null;

  @override
  Future<FiscalResult> fiscalizeSale(FiscalSaleRequest req) async {
    captured.add(req);
    if (refuse) return FiscalResult.failure('оператор отказал');
    return FiscalResult.ok(fiscalSign: 'CAP-1');
  }

  @override
  Future<FiscalResult> fiscalizeRefund(FiscalRefundRequest req) async {
    captured.add(req.sale);
    bases.add(req.basis);
    refundCalls++;
    if (refuse) return FiscalResult.failure('оператор отказал');
    return FiscalResult.ok(fiscalSign: 'CAP-2');
  }

  @override
  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req) async =>
      FiscalResult.failure('нет');

  @override
  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req) async =>
      FiscalResult.failure('нет');

  @override
  Future<FiscalResult> moneyIn(FiscalMoneyRequest req) async =>
      FiscalResult.failure('нет');

  @override
  Future<FiscalResult> moneyOut(FiscalMoneyRequest req) async =>
      FiscalResult.failure('нет');

  @override
  Future<FiscalResult> openShift(FiscalShiftRequest req) async =>
      FiscalResult.failure('нет');

  @override
  Future<FiscalReportResult> closeShift(FiscalShiftRequest req) async =>
      FiscalReportResult.failure('нет');

  @override
  Future<FiscalReportResult> xReport(FiscalShiftRequest req) async =>
      FiscalReportResult.failure('нет');

  @override
  Future<FiscalResult> correctionReceipt(FiscalCorrectionRequest req) async =>
      FiscalResult.failure('нет');

  @override
  Future<FiscalStatus> getStatus() async => FiscalStatus.notConfigured();

  @override
  void dispose() {}
}
