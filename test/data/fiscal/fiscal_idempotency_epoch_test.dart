/// Ключ фискального документа **переживает уборку продаж**.
///
/// # Случай, который здесь воспроизводится
///
/// Найден разбором 2026-09-18 (чтением, не пробой). Ключ продажи был
/// `sale-<чек>-<касса>`; номер чека выдаёт `ReceiptNumbers.withNext` как
/// `max(receipt_no) + 1` **по таблице `Sales`**, а `OldSaleCleanupService`
/// эту таблицу чистит — 90 дней в автономном режиме, **7 в онлайновом**.
/// Касса, простоявшая дольше срока, теряет все строки, `max` становится
/// `null` → `0`, и нумерация чеков начинается заново с единицы. Оператор
/// при этом помнит `sale-1-1` навсегда: каждая новая продажа приходила к
/// нему с занятым ключом и получала код 14. Деньги взяты, своего документа
/// у продажи нет.
///
/// # Два полюса, и оба обязательны
///
/// * **Ключ обязан разойтись**, когда номер чека перезапустился, — иначе
///   дефект на месте;
/// * **ключ обязан совпасть**, когда отправляется тот же документ, — иначе
///   починка сломала ровно ту идемпотентность, ради которой ключ и
///   существует, и на одну продажу приехали бы два документа.
///
/// Проба, держащая только первое, зелёная у ключа из `DateTime.now()`.
/// Проба, держащая только второе, зелёная у старого формата. Поэтому оба.
///
/// # Третий полюс: переход
///
/// Утверждение «переход безопасен, потому что ключ хранится вместе со
/// строкой очереди» здесь не принимается на слово: строка старого формата
/// кладётся в настоящую очередь и повторяется настоящим
/// `OfflineQueueingProvider.replay` — и проверяется, что оператор увидел
/// **её собственный старый ключ**, а не пересобранный новый. Иначе переход
/// дал бы у оператора вторую регистрацию того же чека.
library;

import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/app/services/old_sale_cleanup_service.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/fiscal/drift_fiscal_queue_store.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart' as fq;
import 'package:telepos/data/sale/receipt_numbers.dart';
import 'package:telepos/data/usecases/fiscal/fiscal_service_impl.dart';
import 'package:telepos/domain/fiscal/fiscal_idempotency.dart';
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

  int sec(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

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
      ),
    ),
    logger: logger,
  );

  /// Продажа заводится **настоящей выдачей номера** (`ReceiptNumbers`), а
  /// не числом из пробы: именно она и перезапускается после уборки, и
  /// подставить номер руками значило бы измерить не тот случай.
  Future<int> sellAt(DateTime when) async {
    return ReceiptNumbers(db).withNext(posId, (receiptNo) async {
      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: receiptNo,
              posId: posId,
              userId: 1,
              amount: d('300'),
              time: sec(when),
              // Уборка берёт только отправленные чеки без покупателя
              // (`SaleDao.findSalesToDelete`) — иначе проба ниже удалила
              // бы ноль строк и осталась бы зелёной ни о чём.
              state: const Value(4),
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
      return receiptNo;
    });
  }

  Future<String> fiscalize(int receiptNo) async {
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
    return registry.provider.captured.last.idempotencyKey;
  }

  group('уборка продаж не возвращает оператору занятый ключ', () {
    test('чек с тем же номером после уборки едет под ДРУГИМ ключом', () async {
      final longAgo = DateTime.now().subtract(const Duration(days: 60));
      final oldReceiptNo = await sellAt(longAgo);
      final oldKey = await fiscalize(oldReceiptNo);

      // Уборка — настоящая служба с настоящими настройками онлайнового
      // режима (7 суток), а не `delete from sales` руками пробы.
      final cleanup = OldSaleCleanupService(
        logger: logger,
        db: db,
        settings: CleanupSettings.onlineMode,
      );
      final swept = await cleanup.cleanup();
      expect(
        swept.deletedSales,
        1,
        reason: 'ноль удалённых строк означал бы, что проба мерит не тот '
            'случай: нумерации не с чего перезапускаться',
      );
      expect(
        await db.saleDao.findLastReceiptNo(),
        isNull,
        reason: 'max(receipt_no) по пустой таблице — это и есть причина',
      );

      final newReceiptNo = await sellAt(DateTime.now());
      expect(
        newReceiptNo,
        oldReceiptNo,
        reason: 'нумерация обязана была перезапуститься — иначе ключи '
            'разошлись бы и без починки, и проба ничего не доказывала бы',
      );

      final newKey = await fiscalize(newReceiptNo);

      expect(
        newKey,
        isNot(oldKey),
        reason:
            'до правки оба были sale-$oldReceiptNo-$posId, и оператор '
            'отвечал на второй кодом 14: деньги взяты, документа нет',
      );
    });

    test('повторная отправка того же документа даёт ТОТ ЖЕ ключ', () async {
      // Обратный полюс. Ключ из `DateTime.now()` прошёл бы пробу выше и
      // упал бы здесь — а вместе с ним упала бы вся идемпотентность:
      // повтор после потерянного ответа завёл бы у оператора второй
      // документ на один чек.
      final receiptNo = await sellAt(DateTime.now());

      final first = await fiscalize(receiptNo);
      final second = await fiscalize(receiptNo);

      expect(second, first);
      expect(
        registry.provider.captured.map((r) => r.idempotencyKey).toSet(),
        hasLength(1),
      );
    });

    test('эпохой в ключе стоит время самого чека', () async {
      final when = DateTime.now().subtract(const Duration(days: 3));
      final receiptNo = await sellAt(when);

      // Строка ожидания собирается здесь **дословно**, а не вызовом
      // `FiscalIdempotency.sale`: проба, сверяющая строителя с самим
      // собой, зелена при любом его содержимом — измерено диверсией
      // (возврат старого формата оставил её зелёной, покраснели только
      // соседки).
      expect(
        await fiscalize(receiptNo),
        'sale-${sec(when)}-$receiptNo-$posId',
      );
    });
  });

  group('строка продажи — обязательное основание ключа', () {
    test('продажи нет в базе: отказ с названной причиной, не отправка', () async {
      final result = await service().fiscalizeSale(
        saleReceiptNo: 4242,
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

      expect(result.success, isFalse);
      expect(result.errorCode, FiscalErrorCode.validation);
      expect(result.errorMessage, FiscalIdempotency.saleRowMissing);
      expect(
        registry.provider.captured,
        isEmpty,
        reason: 'сторож стоит ПЕРЕД отправкой: документ без эпохи не имеет '
            'права уехать под именем, про которое известно, что оно может '
            'быть занято',
      );
    });

    test('чек не завершён (time = 0): тот же отказ, своей причиной', () async {
      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: 77,
              posId: posId,
              userId: 1,
              amount: d('300'),
              // Ровно то, что пишет `SaleInitiationUseCase` заводя чек.
              time: 0,
            ),
          );

      final result = await service().fiscalizeSale(
        saleReceiptNo: 77,
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

      expect(result.success, isFalse);
      expect(result.errorMessage, FiscalIdempotency.saleTimeMissing);
      expect(registry.provider.captured, isEmpty);
    });
  });

  group('переход: очередь уезжает со своими старыми ключами', () {
    test('строка старого формата повторяется под своим ключом', () async {
      final store = DriftFiscalQueueStore(db);
      final inner = _CapturingProvider();
      final queued = fq.OfflineQueueingProvider(
        inner: inner,
        store: store,
        isReachable: () async => true,
      );

      // Документ, легший в очередь ДО этой правки: старый формат ключа и
      // внутри payload, и колонкой строки.
      final legacy = FiscalSaleRequest(
        idempotencyKey: 'sale-1-1',
        localOperationId: 1,
        positions: [
          FiscalPosition(
            name: 'Кофе',
            quantity: Decimal.one,
            unitPrice: d('100'),
            lineTotal: d('100'),
            tax: FiscalTax.none(),
          ),
        ],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: d('100')),
        ],
        totalDiscount: Decimal.zero,
        totalMarkup: Decimal.zero,
        occurredAt: DateTime.now(),
      );
      await store.enqueue(
        fq.FiscalQueueEntry(
          idempotencyKey: legacy.idempotencyKey,
          opType: fq.FiscalQueueOp.sale,
          payload: legacy.toJson(),
          occurredAt: legacy.occurredAt,
        ),
      );

      final report = await queued.replay();

      expect(report.fiscalized, 1);
      expect(
        inner.captured.single.idempotencyKey,
        'sale-1-1',
        reason:
            'повтор пересобранным ключом означал бы ВТОРУЮ регистрацию того '
            'же чека у оператора — ровно то, чего переход не имеет права '
            'сделать',
      );
    });

    test('новый формат со старым не склеится ни при каком номере', () {
      // Голова ключа и число разделителей у форматов разные, поэтому
      // перебирать значения незачем — но одно совпадение по невнимательности
      // стоило бы второго документа, и сторож дешевле разбора.
      for (final receiptNo in [1, 2, 10, 1758000000]) {
        expect(
          FiscalIdempotency.sale(
            saleTime: 1758000000,
            receiptNo: receiptNo,
            posId: posId,
          ),
          isNot('sale-$receiptNo-$posId'),
        );
      }
    });
  });

  test('оба пути к оператору строят ключ одним строителем', () {
    // `FiscalServiceImpl` (первая линия) и `WebKassaServiceImpl` (путь
    // сервисного заказа и обмена) отправляют документы одной и той же
    // продажи. Пока формат жил двумя одинаковыми литералами в разных
    // файлах, их совпадение держалось на внимательности; разойдись они —
    // и дедупликация оператора не связала бы две отправки одного чека.
    for (final path in const [
      'lib/data/usecases/fiscal/fiscal_service_impl.dart',
      'lib/data/usecases/fiscal/webkassa_service_impl.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source.contains(r"'sale-$") || source.contains(r"'sale-${"),
        isFalse,
        reason: '$path собирает ключ продажи литералом; строитель один — '
            'FiscalIdempotency.sale',
      );
      expect(source.contains('FiscalIdempotency.sale('), isTrue);
    }
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
    return FiscalResult.ok(fiscalSign: 'CAP-1');
  }

  @override
  Future<FiscalResult> fiscalizeRefund(FiscalRefundRequest req) async {
    captured.add(req.sale);
    return FiscalResult.ok(fiscalSign: 'CAP-2');
  }

  @override
  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req) async {
    captured.add(req);
    return FiscalResult.ok(fiscalSign: 'CAP-3');
  }

  @override
  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req) async {
    captured.add(req.sale);
    return FiscalResult.ok(fiscalSign: 'CAP-4');
  }

  @override
  Future<FiscalResult> moneyIn(FiscalMoneyRequest req) async =>
      FiscalResult.ok(fiscalSign: 'CAP-5');

  @override
  Future<FiscalResult> moneyOut(FiscalMoneyRequest req) async =>
      FiscalResult.ok(fiscalSign: 'CAP-6');

  @override
  Future<FiscalResult> openShift(FiscalShiftRequest req) async =>
      const FiscalResult(success: true);

  @override
  Future<FiscalReportResult> closeShift(FiscalShiftRequest req) async =>
      FiscalReportResult(result: FiscalResult.ok(fiscalSign: 'Z'));

  @override
  Future<FiscalReportResult> xReport(FiscalShiftRequest req) async =>
      FiscalReportResult(result: FiscalResult.ok(fiscalSign: 'X'));

  @override
  Future<FiscalResult> correctionReceipt(FiscalCorrectionRequest req) async =>
      FiscalResult.unsupported('correctionReceipt');

  @override
  Future<FiscalStatus> getStatus() async =>
      const FiscalStatus(configured: true, active: true, online: true);
}
