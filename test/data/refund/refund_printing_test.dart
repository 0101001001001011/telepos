import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/refund/local_recent_receipts.dart';
import 'package:telepos/data/refund/local_refund_service.dart';
import 'package:telepos/data/usecases/refund/refund_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/refund/refund_product_service_impl.dart';
import 'package:telepos/data/usecases/refund/refund_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/can_sale_be_refunded_use_case_impl.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/refund/refund_receipt_printer.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/sale/payment_service.dart'
    show CompletionTrouble;
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import 'package:telepos/presentation/controllers/history/history_controller.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';
import 'package:telepos/presentation/controllers/refund/refund_controller.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/presentation/controllers/app/money_ledger_revision.dart';

/// Три вещи, которые задача 20 забрала у экрана и отдала кассе, — и каждая
/// со своей пробой.
///
/// # Почему это не «покрытие», а закрытие пробела
///
/// Печать чека возврата **переехала**: экран собирал его сам, читая базу
/// (`refund_screen._printRefundReceipt`, полторы сотни строк). После переезда
/// на печать не смотрел ни один тест вовсе — то есть работу можно было
/// потерять целиком и не заметить, а «зелёный набор» это скрыл бы. Ровно
/// класс дефекта, ради которого существует проход `anti-gaps`: код есть,
/// тесты есть, связи между ними нет.
void main() {
  late AppDatabase db;
  late _RecordingPrinter printer;
  late LocalRefundService refunds;

  const posId = 1;
  const cashierId = 4;
  const cashAccountId = 77;

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta mv(RefundView v, int n) =>
      CartCommandMeta(key: 'k$n', baseVersion: v.version, receiptNo: v.draftNo);

  Future<void> seedSale(int receiptNo) async {
    final amount = d('500') * d('2');
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: receiptNo,
            posId: posId,
            userId: cashierId,
            amount: amount,
            time: 1700000000,
            state: const Value(1),
          ),
        );
    await db
        .into(db.saleProducts)
        .insert(
          SaleProductsCompanion.insert(
            receiptNo: Value(receiptNo),
            posId: Value(posId),
            ucode: 100,
            quantity: d('2'),
            price: d('500'),
            priceBefore: d('500'),
          ),
        );
    await db
        .into(db.payments)
        .insert(
          PaymentsCompanion.insert(
            userId: cashierId,
            payeeAccountId: cashAccountId,
            amount: amount,
            time: 1700000000,
            receiptNo: Value(receiptNo),
            posId: Value(posId),
            state: const Value(1),
          ),
        );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final logger = Talker();

    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(posId),
            accountId: Value(cashAccountId),
          ),
        );
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(cashAccountId),
            type: 0,
            value: Value(d('1000')),
          ),
        );
    await db
        .into(db.users)
        .insert(
          const UsersCompanion(id: Value(cashierId), name: Value('Айгуль')),
        );
    await db
        .into(db.shifts)
        .insert(
          const ShiftsCompanion(
            userId: Value(cashierId),
            openTime: Value(1000),
            isOpened: Value(true),
            isSynced: Value(false),
          ),
        );
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(100),
            barcode: 4870001234567,
            name: 'Молоко',
            type: 0,
            measure: 0,
            quantity: Value(d('100')),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            ucode: const Value(100),
            barcode: 4870001234567,
            sellingPrice: Value(d('500')),
          ),
        );

    await GetIt.I.reset();
    GetIt.I.registerSingleton<RefundProductService>(
      RefundProductServiceImpl(db: db, logger: logger),
    );

    printer = _RecordingPrinter();
    refunds = LocalRefundService(
      db: db,
      logger: logger,
      initiation: RefundInitiationUseCaseImpl(db: db, logger: logger),
      refunds: RefundUseCaseImpl(
        db: db,
        logger: logger,
        fiscal: const RefusingFiscalService(),
      ),
      canBeRefunded: CanSaleBeRefundedUseCaseImpl(db: db, logger: logger),
      drawer: () async => true,
      printer: printer,
    );
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  group('чек возврата печатает касса', () {
    test('завершение возврата отдаёт чек в печать', () async {
      await seedSale(11);

      final loaded = await refunds.loadReceipt(
        7,
        11,
        posId,
        const CartCommandMeta(key: 'k1', baseVersion: 0, receiptNo: null),
      );
      final outcome = await refunds.complete(7, mv(loaded, 2));

      // Печать **отправляется**, а не ожидается: даём ей дойти до
      // вызванного, но результата возврата это не касается.
      await Future<void>.delayed(Duration.zero);

      expect(
        printer.calls,
        hasLength(1),
        reason:
            'до задачи 20 чек возврата собирал экран; после переезда за ним '
            'не смотрел ни один тест — потерять печать целиком можно было '
            'молча',
      );
      final call = printer.calls.single;
      expect(call.outcome.refundLocalId, outcome.refundLocalId);
      expect(call.outcome.amount, d('1000'));
      expect(
        call.lines.single.name,
        'Молоко',
        reason: 'печатается то, за что отданы деньги — строки черновика',
      );
      expect(
        call.userId,
        cashierId,
        reason: 'кассир берётся из открытой смены, а не из состояния экрана',
      );
    });

    test('отказ печати не отменяет состоявшийся возврат', () async {
      // Деньги отданы, товар на остатке. Принтер, у которого кончилась
      // бумага, не имеет права это откатить — и не имеет права уронить
      // ответ терминалу.
      await seedSale(12);
      printer.explode = true;

      final loaded = await refunds.loadReceipt(
        7,
        12,
        posId,
        const CartCommandMeta(key: 'k1', baseVersion: 0, receiptNo: null),
      );
      final outcome = await refunds.complete(7, mv(loaded, 2));
      await Future<void>.delayed(Duration.zero);

      expect(outcome.amount, d('1000'));
      final stock = await db.productInfoDao.findByUcode(100);
      expect(
        stock!.quantity,
        d('102'),
        reason: 'товар вернулся на остаток, что бы ни ответил принтер',
      );
    });

    test('касса без принтера проводит возврат так же', () async {
      // `printer` необязателен: `null` — не ошибка, и это единственная
      // причина, по которой он вынесен отдельным контрактом.
      final logger = Talker();
      final withoutPrinter = LocalRefundService(
        db: db,
        logger: logger,
        initiation: RefundInitiationUseCaseImpl(db: db, logger: logger),
        refunds: RefundUseCaseImpl(
          db: db,
          logger: logger,
          fiscal: const RefusingFiscalService(),
        ),
        canBeRefunded: CanSaleBeRefundedUseCaseImpl(db: db, logger: logger),
        drawer: () async => true,
      );
      await seedSale(13);

      final loaded = await withoutPrinter.loadReceipt(
        7,
        13,
        posId,
        const CartCommandMeta(key: 'k1', baseVersion: 0, receiptNo: null),
      );
      final outcome = await withoutPrinter.complete(7, mv(loaded, 2));

      expect(outcome.amount, d('1000'));
      expect(printer.calls, isEmpty);
    });
  });

  group('подсказка «последние чеки»', () {
    test('отдаёт совершённые чеки номером, временем и суммой', () async {
      await seedSale(21);
      await seedSale(22);

      final recent = await LocalRecentReceipts(db).recent(limit: 30);

      expect(recent.map((r) => r.receiptNo), containsAll([21, 22]));
      final one = recent.firstWhere((r) => r.receiptNo == 21);
      expect(one.posId, posId);
      expect(
        one.amount,
        d('1000'),
        reason: 'сумма — Decimal, а не double: это деньги (И159)',
      );
      expect(one.time, 1700000000);
    });

    test('чек в работе в подсказку не попадает', () async {
      // Возвращать можно только совершённое. Строка `state = 0` — корзина
      // на кассе прямо сейчас, и предлагать её к возврату нечем.
      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: 31,
              posId: posId,
              userId: cashierId,
              amount: d('100'),
              time: 1700000000,
              state: const Value(0),
            ),
          );

      final recent = await LocalRecentReceipts(db).recent(limit: 30);

      expect(recent.map((r) => r.receiptNo), isNot(contains(31)));
    });
  });

  group('«деньги изменились» доходит числом', () {
    // **Проба переписана кругом правки, и вот чем была плоха прежняя.**
    //
    // Она читала исходник и требовала строку `ref.watch(
    // moneyLedgerRevisionProvider)`. Разбор сломал её во все три стороны:
    //
    // | слом | подписка | прежняя проба |
    // | --- | --- | --- |
    // | перенос аргумента на свою строку (`dart format`) | цела | **красная** |
    // | вызов в комментарии `// TODO` | мертва | зелёная |
    // | вызов за `if (DateTime.now().year < 2000)` | мертва | зелёная |
    //
    // То есть она закрывала **написание строки**, а не подписку, и оба
    // настоящих слома проходили при `+894 All tests passed`.
    //
    // Здесь поднимается настоящий провайдер над настоящей базой и мерится
    // то, ради чего он заведён: **перечитал ли себя экран**. Базы истории
    // хватает — `HistoryNotifier.build()` берёт её лениво, микрозадачей.
    test('экран истории перечитывает себя, когда деньги изменились', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var rebuilds = 0;
      container.listen(historyControllerProvider, (_, _) => rebuilds++);
      final before = container.read(historyControllerProvider);

      container.read(moneyLedgerRevisionProvider.notifier).bump();
      final after = container.read(historyControllerProvider);

      expect(
        identical(before, after),
        isFalse,
        reason:
            'состояние истории не пересоздалось — значит build() не перечитан, '
            'и после возврата экран показывает вчерашние чеки',
      );
      expect(rebuilds, greaterThan(0));
    });

    test('экран смены перечитывает себя, когда деньги изменились', () {
      // **Половина охраны, исчезнувшая молча.** Прежняя проба читала
      // исходники **двух** файлов; я заменил её настоящей, но настоящая
      // покрывала только историю — строку из `ShiftNotifier.build()` можно
      // было удалить, и набор оставался зелёным. Собственный `reason`
      // прежней пробы гласил: «замена обязана охраняться, иначе она молча
      // исчезнет», — и исчезла бы.
      //
      // `ShiftNotifier.build()` берёт базу лениво (микрозадачей), поэтому
      // построение самого состояния поднимать её не требует — как и у
      // истории.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var rebuilds = 0;
      container.listen(shiftControllerProvider, (_, _) => rebuilds++);
      final before = container.read(shiftControllerProvider);

      container.read(moneyLedgerRevisionProvider.notifier).bump();
      final after = container.read(shiftControllerProvider);

      expect(
        identical(before, after),
        isFalse,
        reason:
            'состояние смены не пересоздалось — значит build() не перечитан, '
            'и после возврата экран показывает вчерашнюю кассу',
      );
      expect(rebuilds, greaterThan(0));
    });

    test('bump перестраивает подписанного', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var builds = 0;
      final watcher = Provider<int>((ref) {
        builds++;
        return ref.watch(moneyLedgerRevisionProvider);
      });

      expect(container.read(watcher), 0);
      expect(builds, 1);

      container.read(moneyLedgerRevisionProvider.notifier).bump();

      expect(container.read(watcher), 1);
      expect(builds, 2);
    });

    test('возврат поднимает счётчик, а не забывает про него', () async {
      // Третья часть провода: сам возврат обязан сообщить. Мерится
      // **вызовом**, а не текстом: контроллер возврата поднимается над
      // подставным контрактом, и после успешного завершения счётчик обязан
      // вырасти.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(moneyLedgerRevisionProvider), 0);

      await GetIt.I.reset();
      GetIt.I
        ..registerSingleton<TerminalIdentity>(_FixedTerminal())
        ..registerSingleton<RefundService>(_OneLineRefunds());

      final refunds = container.read(refundControllerProvider.notifier);
      for (var i = 0; i < 12; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(
        container.read(refundControllerProvider).canRefund,
        isTrue,
        reason: 'подготовка: черновик приехал подпиской',
      );

      expect(await refunds.processRefund(), isTrue);
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(
        container.read(moneyLedgerRevisionProvider),
        greaterThan(0),
        reason: 'возврат провёл деньги и никому не сказал',
      );
    });
  });
}

/// Рабочее место, известное заранее: контроллеру возврата нужно только оно.
class _FixedTerminal implements TerminalIdentity {
  @override
  Future<int?> currentId() async => 7;

  @override
  Future<void> remember(int terminalId) async {}

  @override
  Future<void> forget() async {}
}

/// Черновик из одной строки, который успешно завершается.
class _OneLineRefunds implements RefundService {
  @override
  Stream<RefundView> watch(int terminalId) => Stream.value(
    RefundView(
      posId: 1,
      terminalId: terminalId,
      version: 1,
      draftNo: 1,
      saleReceiptNo: 11,
      salePosId: 1,
      lines: [
        RefundLine(
          id: '1',
          productId: 100,
          name: 'Молоко',
          quantity: Decimal.one,
          price: Decimal.fromInt(500),
          maxQuantity: Decimal.one,
        ),
      ],
    ),
  );

  @override
  Future<RefundView> loadReceipt(
    int terminalId,
    int receiptNo,
    int posId,
    CartCommandMeta meta,
  ) async => throw UnimplementedError();

  @override
  Future<RefundView> startWithoutReceipt(
    int terminalId,
    CartCommandMeta meta,
  ) async => throw UnimplementedError();

  @override
  Future<RefundView> addProduct(
    int terminalId,
    int productId,
    Decimal quantity,
    CartCommandMeta meta,
  ) async => throw UnimplementedError();

  @override
  Future<RefundView> setLineQuantity(
    int terminalId,
    String lineId,
    Decimal quantity,
    CartCommandMeta meta,
  ) async => throw UnimplementedError();

  @override
  Future<RefundOutcome> complete(int terminalId, CartCommandMeta meta) async =>
      RefundOutcome(
        refundLocalId: 1,
        amount: Decimal.fromInt(500),
        lineCount: 1,
        paymentCount: 1,
      );

  @override
  Future<void> abandon(int terminalId) async {}

  @override
  Future<List<CompletionTrouble>> hardwareTroubles(
    int terminalId,
    int refundLocalId,
  ) async => const [];
}

class _PrintCall {
  const _PrintCall(this.outcome, this.lines, this.userId);

  final RefundOutcome outcome;
  final List<RefundLine> lines;
  final int userId;
}

class _RecordingPrinter implements RefundReceiptPrinter {
  final calls = <_PrintCall>[];
  bool explode = false;

  @override
  Future<void> printRefund({
    required RefundOutcome outcome,
    required List<RefundLine> lines,
    required int userId,
  }) async {
    calls.add(_PrintCall(outcome, lines, userId));
    if (explode) throw StateError('в принтере кончилась бумага');
  }
}
