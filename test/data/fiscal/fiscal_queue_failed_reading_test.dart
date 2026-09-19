library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/data/database/app_database.dart' hide FiscalQueueEntry;
import 'package:telepos/data/fiscal/drift_fiscal_queue_store.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

/// Третье **чтение** очереди и списание рукой — задача 11, шаги 4 и 5.
///
/// # Почему это отдельный файл от `unfiscalized_row_test.dart`
///
/// Тот доказывает, что строка **ложится** правильной — и делает это через
/// эмулятор, потому что свидетель ключа только оператор. Здесь другое:
/// как строка **читается** и **разбирается**. Свидетель тут не нужен,
/// нужны все шесть родов операции и обе реализации хранилища — то, чего
/// продажа через эмулятор не покрывает никогда.
///
/// # Что здесь ловится
///
/// `carriesDocument` — единственный предохранитель от повтора чужим
/// ключом. Он не «payload непустой»: строка, у которой ключ свой, а
/// документ чужой, при повторе дала бы **второй фискальный документ на
/// одну продажу**. У возврата ключ лежит на уровень глубже (`sale.
/// idempotencyKey`), у денежных операций позиций нет вовсе — три разных
/// формы, и ошибка в любой открыла бы кнопку «Повторить» там, где
/// повторять нечем.
void main() {
  late AppDatabase db;
  late DriftFiscalQueueStore drift;

  FiscalQueueEntry entry({
    required String key,
    required FiscalQueueOp op,
    required Map<String, dynamic> payload,
    FiscalQueueStatus status = FiscalQueueStatus.failed,
    DateTime? at,
  }) => FiscalQueueEntry(
    idempotencyKey: key,
    opType: op,
    payload: payload,
    occurredAt: at ?? DateTime.now(),
    status: status,
  );

  Map<String, dynamic> saleDoc(String key) => {
    'idempotencyKey': key,
    'localOperationId': 4242,
    'positions': [
      {'name': 'Хлеб'},
    ],
  };

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    drift = DriftFiscalQueueStore(db);
  });

  tearDown(() => db.close());

  group('carriesDocument — предохранитель от повтора чужим ключом', () {
    test('продажа: свой ключ и непустые позиции — можно', () {
      expect(
        entry(
          key: 'sale-4242-1',
          op: FiscalQueueOp.sale,
          payload: saleDoc('sale-4242-1'),
        ).carriesDocument,
        isTrue,
      );
    });

    test('продажа: ключ строки НЕ равен ключу документа — нельзя', () {
      expect(
        entry(
          key: 'sale-unfiscalized:1-4242',
          op: FiscalQueueOp.sale,
          payload: saleDoc('sale-4242-1'),
        ).carriesDocument,
        isFalse,
        reason:
            'повтор пошёл бы ключом документа, а строка живёт под своим — '
            'дедупликация оператора их не свяжет',
      );
    });

    test('продажа: записка вместо документа — нельзя', () {
      expect(
        entry(
          key: 'sale-unfiscalized:1-4242',
          op: FiscalQueueOp.sale,
          payload: {'receiptNo': 4242, 'posId': 1, 'amount': '500'},
        ).carriesDocument,
        isFalse,
      );
    });

    test('продажа: документ с пустыми позициями — нельзя', () {
      expect(
        entry(
          key: 'sale-4242-1',
          op: FiscalQueueOp.sale,
          payload: {'idempotencyKey': 'sale-4242-1', 'positions': []},
        ).carriesDocument,
        isFalse,
        reason: 'чек без позиций оператор отвергнет так же, как отверг в первый раз',
      );
    });

    test('возврат: ключ лежит на уровень глубже — и читается оттуда', () {
      final refund = entry(
        key: 'refund-77-0',
        op: FiscalQueueOp.refund,
        payload: {
          'sale': saleDoc('refund-77-0'),
          'basis': {'originalFiscalSign': '123'},
        },
      );
      expect(refund.documentKey, 'refund-77-0');
      expect(refund.carriesDocument, isTrue);
    });

    test('возврат: ключ верхнего уровня возврату не годится', () {
      expect(
        entry(
          key: 'refund-77-0',
          op: FiscalQueueOp.refund,
          payload: {'idempotencyKey': 'refund-77-0'},
        ).carriesDocument,
        isFalse,
        reason:
            'у возврата документ лежит под `sale`; плоский ключ значит, что '
            'документа нет',
      );
    });

    test('денежная операция: позиций нет и не должно быть', () {
      expect(
        entry(
          key: 'money-in-9',
          op: FiscalQueueOp.moneyIn,
          payload: {'idempotencyKey': 'money-in-9', 'amount': '1000'},
        ).carriesDocument,
        isTrue,
        reason:
            'требовать позиций у внесения денег значило бы запретить повтор '
            'операции, у которой позиций не бывает',
      );
    });
  });

  group('failed() и failedCount() — оба хранилища отвечают одинаково', () {
    for (final (name, make) in <(String, FiscalQueueStore Function())>[
      ('InMemory', InMemoryFiscalQueueStore.new),
      ('Drift', () => DriftFiscalQueueStore(AppDatabase.forTesting(NativeDatabase.memory()))),
    ]) {
      test('$name: failed() берёт только failed и не берёт pending', () async {
        final store = name == 'Drift' ? drift : make();
        await store.enqueue(
          entry(
            key: 'sale-1-1',
            op: FiscalQueueOp.sale,
            payload: saleDoc('sale-1-1'),
            status: FiscalQueueStatus.pending,
          ),
        );
        await store.enqueue(
          entry(
            key: 'sale-2-1',
            op: FiscalQueueOp.sale,
            payload: saleDoc('sale-2-1'),
          ),
        );

        final failed = await store.failed();
        expect(failed.map((e) => e.idempotencyKey), ['sale-2-1']);
        expect(await store.failedCount(), 1);
        expect(await store.pendingCount(), 1);
      });

      test('$name: failed() отдаёт от старой к новой', () async {
        final store = name == 'Drift' ? drift : make();
        await store.enqueue(
          entry(
            key: 'sale-new-1',
            op: FiscalQueueOp.sale,
            payload: saleDoc('sale-new-1'),
            at: DateTime(2026, 9, 8, 12),
          ),
        );
        await store.enqueue(
          entry(
            key: 'sale-old-1',
            op: FiscalQueueOp.sale,
            payload: saleDoc('sale-old-1'),
            at: DateTime(2026, 9, 5, 12),
          ),
        );

        expect((await store.failed()).map((e) => e.idempotencyKey), [
          'sale-old-1',
          'sale-new-1',
        ], reason: 'первой разбирают ту, у которой скорее вышло окно 72 часа');
      });

      test('$name: списанная строка остаётся, но в счёт не входит', () async {
        final store = name == 'Drift' ? drift : make();
        final row = entry(
          key: 'sale-3-1',
          op: FiscalQueueOp.sale,
          payload: saleDoc('sale-3-1'),
        );
        await store.enqueue(row);

        final provider = OfflineQueueingProvider(
          inner: const _SilentProvider(),
          store: store,
          isReachable: () async => true,
        );
        await provider.writeOffFailed(
          row,
          by: 'Айгуль',
          reason: 'проведён вручную по бумажному чеку',
        );

        final after = await store.failed();
        expect(after, hasLength(1), reason: 'тихой чистки у очереди нет');
        expect(after.single.writeOff!.by, 'Айгуль');
        expect(
          after.single.writeOff!.reason,
          'проведён вручную по бумажному чеку',
        );
        expect(await store.failedCount(), 0);
        expect(
          after.single.carriesDocument,
          isTrue,
          reason: 'отметка о списании кладётся РЯДОМ с документом, не вместо',
        );
      });
    }
  });

  group('списание требует имени и причины', () {
    late OfflineQueueingProvider provider;
    late InMemoryFiscalQueueStore store;
    late FiscalQueueEntry row;

    setUp(() async {
      store = InMemoryFiscalQueueStore();
      row = entry(
        key: 'sale-5-1',
        op: FiscalQueueOp.sale,
        payload: saleDoc('sale-5-1'),
      );
      await store.enqueue(row);
      provider = OfflineQueueingProvider(
        inner: const _SilentProvider(),
        store: store,
        isReachable: () async => true,
      );
    });

    test('пустая причина отвергается', () {
      expect(
        () => provider.writeOffFailed(row, by: 'Айгуль', reason: ''),
        throwsArgumentError,
      );
    });

    test('пробелы причиной не считаются', () {
      expect(
        () => provider.writeOffFailed(row, by: 'Айгуль', reason: '   '),
        throwsArgumentError,
      );
    });

    test('безымянное списание отвергается', () {
      expect(
        () => provider.writeOffFailed(row, by: '  ', reason: 'так вышло'),
        throwsArgumentError,
      );
    });
  });

  test('повторить строку без документа нельзя — отказ значением, не броском', () async {
    final store = InMemoryFiscalQueueStore();
    final row = entry(
      key: 'sale-unfiscalized:1-777',
      op: FiscalQueueOp.sale,
      payload: {'receiptNo': 777, 'posId': 1, 'amount': '500'},
    );
    await store.enqueue(row);
    final provider = OfflineQueueingProvider(
      inner: const _SilentProvider(),
      store: store,
      isReachable: () async => true,
    );

    final result = await provider.retryFailed(row);

    expect(result.success, isFalse);
    expect(result.errorMessage, contains('повторять нечем'));
    expect(
      await store.failedCount(),
      1,
      reason: 'отказ повтора строку не съедает',
    );
  });
}

/// Провайдер, который **не должен быть позван** ни одной пробой этого
/// файла: списание к оператору не ходит, а повтор строки без документа
/// обязан остановиться раньше. Каждый метод бросает — молчаливый успех
/// здесь означал бы, что предохранитель не сработал.
class _SilentProvider implements FiscalProvider {
  const _SilentProvider();

  Never _never() => throw StateError('оператора звать не должны были');

  @override
  String get id => 'silent';

  @override
  FiscalCapabilities get capabilities => const FiscalCapabilities();

  @override
  String? validateConfig(FiscalSettings config) => null;

  @override
  Future<FiscalAuthResult> authorize(FiscalSettings config) async => _never();

  @override
  Future<FiscalResult> fiscalizeSale(FiscalSaleRequest req) async => _never();

  @override
  Future<FiscalResult> fiscalizeRefund(FiscalRefundRequest req) async =>
      _never();

  @override
  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req) async =>
      _never();

  @override
  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req) async =>
      _never();

  @override
  Future<FiscalResult> moneyIn(FiscalMoneyRequest req) async => _never();

  @override
  Future<FiscalResult> moneyOut(FiscalMoneyRequest req) async => _never();

  @override
  Future<FiscalResult> openShift(FiscalShiftRequest req) async => _never();

  @override
  Future<FiscalReportResult> closeShift(FiscalShiftRequest req) async =>
      _never();

  @override
  Future<FiscalReportResult> xReport(FiscalShiftRequest req) async => _never();

  @override
  Future<FiscalResult> correctionReceipt(FiscalCorrectionRequest req) async =>
      _never();

  @override
  Future<FiscalStatus> getStatus() async => _never();
}
