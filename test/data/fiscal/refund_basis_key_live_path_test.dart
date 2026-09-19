/// Точная зависимость возврата — **на боевом пути**, а не только в
/// правиле очереди.
///
/// # Зачем эта проба отдельно от правила
///
/// `refund_holds_only_its_own_basis_test` меряет правило на строках,
/// собранных самой пробой: ключ основания в них проставлен рукой. Пройди
/// правило и там, и там, а `FiscalServiceImpl` ключа не проставь — правило
/// осталось бы верным, а касса вела бы себя по-прежнему: каждый возврат
/// падал бы в осторожную ветвь «основание не названо», и застрявшая чужая
/// продажа держала бы его так же, как до правки.
///
/// Поэтому здесь всё настоящее снизу доверху: база, `FiscalServiceImpl`,
/// очередь, `WebKassaProvider`, сокет эмулятора. Подставлен только реестр
/// провайдеров — он отдаёт очередь поверх настоящего провайдера, и это
/// ровно то, что делает сборка кассы.
///
/// # Что доказывается
///
/// Что «своя продажа» на боевом пути определяется **по происхождению, а не
/// по совпадению формата**: ключ основания сверяется с тем ключом, под
/// которым продажа уехала оператору, — он читается из журнала эмулятора.
///
/// # Чего это НЕ доказывает
///
/// Что настоящая WebKassa примет отпущенный возврат: основание она сверяет
/// своим реестром, которого у эмулятора нет. Это открытый вопрос живого
/// прогона.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart' hide FiscalQueueEntry;
import 'package:telepos/data/fiscal/drift_fiscal_queue_store.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';
import 'package:telepos/data/usecases/fiscal/fiscal_service_impl.dart';
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';
import 'package:telepos/domain/fiscal/fiscal_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_provider_registry.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';

import 'support/webkassa_rig.dart';

void main() {
  late WebKassaRig rig;
  late AppDatabase db;
  late DriftFiscalQueueStore store;
  late OfflineQueueingProvider queued;
  late FiscalServiceImpl service;

  const posId = 1;
  const receiptNo = 1;

  Decimal d(String v) => Decimal.parse(v);
  final saleTime = DateTime.now().subtract(const Duration(hours: 2));
  final saleTimeSec = saleTime.millisecondsSinceEpoch ~/ 1000;

  setUp(() async {
    rig = await startWebKassaRig();
    await rig.warm();

    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = DriftFiscalQueueStore(db);
    queued = OfflineQueueingProvider(
      inner: rig.provider,
      store: store,
      isReachable: () async => true,
    );
    final logger = Talker(settings: TalkerSettings(enabled: false));
    service = FiscalServiceImpl(
      db: db,
      registry: _QueuedRegistry(queued),
      settingsSource: _FixedSettings(rig.settings),
      logger: logger,
    );

    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: receiptNo,
            posId: posId,
            userId: 1,
            amount: d('300'),
            time: saleTimeSec,
          ),
        );
    await db
        .into(db.saleProducts)
        .insert(
          SaleProductsCompanion(
            receiptNo: const Value(receiptNo),
            posId: const Value(posId),
            ucode: const Value(100),
            barcode: const Value(4870001234567),
            categoryId: const Value(1),
            quantity: Value(d('3')),
            price: Value(d('100')),
            priceBefore: Value(d('100')),
          ),
        );
  });

  tearDown(() async {
    await db.close();
    await rig.stop();
  });

  Future<void> sell() => service.fiscalizeSale(
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

  /// Строка возврата того же вида, какую пишет `RefundUseCaseImpl`:
  /// возврат по чеку несёт пару «номер чека, касса», возврат без чека — нет.
  Future<int> seedRefund({required bool byReceipt}) async {
    final localId = await db
        .into(db.refunds)
        .insert(
          RefundsCompanion.insert(
            userId: 1,
            time: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            saleReceiptNo: Value(byReceipt ? receiptNo : null),
            salePosId: Value(byReceipt ? posId : null),
            amount: Value(d('300')),
          ),
        );
    await db
        .into(db.refundProducts)
        .insert(
          RefundProductsCompanion.insert(
            ucode: 100,
            price: d('100'),
            quantity: d('3'),
            refundLocalId: Value(localId),
          ),
        );
    return localId;
  }

  Future<void> refund(int localId, {required bool byReceipt}) =>
      service.fiscalizeRefund(
        refundLocalId: localId,
        originalSaleReceiptNo: byReceipt ? receiptNo : null,
        amount: d('300'),
        cashAmount: d('300'),
        cardAmount: Decimal.zero,
        mobileAmount: Decimal.zero,
        bonusAmount: Decimal.zero,
        creditAmount: Decimal.zero,
        offsetAmount: Decimal.zero,
        offsetLayout: OffsetFiscalLayout.discount,
        excludeCertificatePositions: false,
      );

  test('ключ основания — ТОТ ЖЕ, под которым продажа уехала оператору', () async {
    await sell();
    final saleKey = rig.acceptedKeys().single;

    final localId = await seedRefund(byReceipt: true);
    // Чужая продажа застряла в очереди — та самая, что прежде держала
    // возврат по постороннему чеку.
    await store.enqueue(rigSaleRow(rigSale('sale-alien')));

    await refund(localId, byReceipt: true);

    // ignore: avoid_print
    print('уехало оператору: ${rig.acceptedKeys()}; ключ продажи $saleKey');
    expect(
      rig.acceptedKeys(),
      [saleKey, 'refund-$localId-0'],
      reason: 'чужая застрявшая продажа больше не держит возврат',
    );
    expect(
      (await store.pending()).map((e) => e.idempotencyKey),
      ['sale-alien'],
      reason: 'в очередь возврат не лёг',
    );
  });

  test('своя продажа в очереди — возврат встаёт за ней, ключ назван', () async {
    // Продажа не доехала: связь оборвалась на ней самой.
    await rig.console('/_emul/kill', {'count': 1});
    await sell();
    final pendingSale = (await store.pending()).single;

    final localId = await seedRefund(byReceipt: true);
    rig.state.journal.clear();
    await refund(localId, byReceipt: true);

    expect(
      rig.sentKeys(),
      isEmpty,
      reason: 'основания у оператора нет — возврат ехать не имеет права',
    );
    final rows = await store.pending();
    expect(rows.map((e) => e.idempotencyKey), [
      pendingSale.idempotencyKey,
      'refund-$localId-0',
    ]);
    final refundRow = rows.last;
    expect(
      refundRow.basisDocumentKey,
      pendingSale.idempotencyKey,
      reason:
          'ключ основания сверяется с ключом самой продажи, а не с форматом: '
          'совпадение формата доказывало бы только то, что обе строки '
          'написаны одинаково',
    );

    // Связь вернулась — проход везёт оба и в прежнем порядке.
    final report = await queued.replay();
    expect(report.fiscalized, 2);
    expect(rig.acceptedKeys(), [
      pendingSale.idempotencyKey,
      'refund-$localId-0',
    ]);
  });

  test('возврат без чека: основания нет, и очередь остаётся осторожной', () async {
    await store.enqueue(rigSaleRow(rigSale('sale-alien')));
    final localId = await seedRefund(byReceipt: false);

    await refund(localId, byReceipt: false);

    final rows = await store.pending();
    expect(
      rows.map((e) => e.idempotencyKey),
      ['sale-alien', 'refund-$localId-0'],
      reason: '«не знаем, чьё основание» не то же самое, что «ничьё»',
    );
    expect(rows.last.basisDocumentKey, isNull);
  });
}

class _FixedSettings implements FiscalSettingsSource {
  _FixedSettings(this.settings);

  final FiscalSettings settings;

  @override
  Future<FiscalSettings> load() async => settings;
}

/// Реестр, отдающий **очередь поверх настоящего провайдера** — ровно то,
/// что собирает `service_locator.dart` на кассе.
class _QueuedRegistry extends FiscalProviderRegistry {
  _QueuedRegistry(this.queued);

  final OfflineQueueingProvider queued;

  @override
  FiscalProvider resolve(FiscalSettings settings) => queued;
}
