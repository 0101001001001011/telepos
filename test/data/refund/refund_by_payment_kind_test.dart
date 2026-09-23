/// Возврат уходит **тем видом, каким пришли деньги** — задача 26.
///
/// # Что здесь меряется
///
/// Настоящая база drift, настоящий `RefundUseCaseImpl` и настоящий
/// `LocalRefundReceiptPrinter`. Чек и его строки оплаты посеяны прямо в
/// таблицы — с видом (`kindId`), документом (`reference`) и транзакцией
/// (`terminalTransactionId`), ровно так, как их пишет `LocalPaymentService`:
/// раскладка возврата читает **строки**, а не то, как они появились.
///
/// Подставлены только два порта кассы, которых у пробы нет: фискальный узел
/// и очередь печати — оба шпионами через `noSuchMethod`, то есть **без
/// повторения подписи**, чтобы проба не менялась от того, что меряет.
///
/// # Правило частичного возврата, которое здесь проверяется
///
/// Разбор решения — в докстринге `RefundAllocation`
/// (`lib/domain/refund/refund_allocation.dart`). Коротко: **долг → бонус →
/// сертификат → аванс → безнал (QR, карта) → наличные**. Живые деньги из
/// ящика — последними.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/core/constants/enums/product_type.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/refund/local_refund_receipt_printer.dart';
import 'package:telepos/data/refund/local_refund_service.dart';
import 'package:telepos/data/usecases/refund/refund_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/refund/refund_product_service_impl.dart';
import 'package:telepos/data/usecases/refund/refund_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/can_sale_be_refunded_use_case_impl.dart';
import 'package:telepos/domain/refund/refund_allocation.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart'
    show CompletionTroubleKind;
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import 'package:telepos/domain/usecases/refund/refund_use_case.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

const _posId = 1;
const _cashier = 4;
const _customer = 5;

const _posAccount = 11;
const _bankAccount = 12;
const _bonusAccount = 13;
const _customerAccount = 14;
const _liabilityAccount = 15;

/// Фискальный узел, записывающий доводы `fiscalizeRefund` **по имени** —
/// без повторения подписи.
class _FiscalSpy implements FiscalService {
  final refunds = <Map<Symbol, Object?>>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #fiscalizeRefund) {
      refunds.add(Map.of(invocation.namedArguments));
      return Future<FiscalResult>.value(FiscalResult.queued());
    }
    return super.noSuchMethod(invocation);
  }
}

/// Очередь печати, записывающая чек возврата.
class _PrintSpy implements ReceiptPrintService {
  final receipts = <RefundReceiptData>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #printRefundReceipt) {
      receipts.add(invocation.positionalArguments.single as RefundReceiptData);
      return Future<PrintSubmitOutcome>.value(
        PrintSubmitOutcome.accepted('p1'),
      );
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  late AppDatabase db;
  late Talker logger;

  /// Фискальный узел, которым собирается `RefundUseCaseImpl` в этом файле.
  ///
  /// Переменная, а не выражение по месту, потому что групп здесь две разной
  /// природы: большинству проб фискализация безразлична, и у них стоит
  /// **отказывающий** узел — не заглушка-«успех», которая соврала бы, что
  /// документ ушёл. Группа «фискальный возврат по видам» подменяет его
  /// шпионом в своём `setUp` (он бежит после общего).
  ///
  /// До этой правки узел доставался из `GetIt` внутри возврата, и здесь его
  /// регистрировали там же; теперь он — довод конструктора, и подмена видна
  /// в сборке.
  late FiscalService fiscal;

  Decimal d(String v) => Decimal.parse(v);

  Future<void> account(int id, int type, [String value = '0']) => db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          id: Value(id),
          type: type,
          name: Value('Счёт $id'),
          value: Value(d(value)),
          visibleToPos: const Value(true),
        ),
      );

  /// Чек на 1000 — две штуки по 500 — и его строки оплаты.
  Future<void> receipt(
    int receiptNo,
    List<
      ({
        int accountId,
        int kindId,
        String amount,
        String? reference,
        String? transactionId,
      })
    >
    rows, {
    bool isOfd = false,
  }) async {
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: receiptNo,
            posId: _posId,
            userId: _cashier,
            amount: d('1000'),
            time: 1700000000,
            state: const Value(1),
            isOfd: Value(isOfd),
            customerLocalId: const Value(_customer),
          ),
        );
    await db
        .into(db.saleProducts)
        .insert(
          SaleProductsCompanion.insert(
            receiptNo: Value(receiptNo),
            posId: const Value(_posId),
            ucode: 100,
            quantity: d('2'),
            price: d('500'),
            priceBefore: d('500'),
          ),
        );
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      await db
          .into(db.payments)
          .insert(
            PaymentsCompanion.insert(
              userId: _cashier,
              payeeAccountId: row.accountId,
              amount: d(row.amount),
              time: 1700000000,
              receiptNo: Value(receiptNo),
              posId: const Value(_posId),
              state: const Value(1),
              kindId: Value(row.kindId),
              seq: Value(i),
              reference: Value(row.reference),
              terminalTransactionId: Value(row.transactionId),
            ),
          );
    }
  }

  Future<int> refund(
    int receiptNo,
    String amount, {
    String quantity = '2',
  }) async {
    await db
        .into(db.refunds)
        .insert(RefundsCompanion.insert(userId: _cashier, time: 2000));
    final refundId = (await db.select(db.refunds).get()).last.localId;
    await RefundUseCaseImpl(db: db, logger: logger, fiscal: fiscal).perform(
      refundLocalId: refundId,
      amount: d(amount),
      userId: _cashier,
      saleReceiptNo: receiptNo,
      salePosId: _posId,
      customerLocalId: _customer,
      products: [
        RefundProductEntry(
          ucode: 100,
          quantity: d(quantity),
          price: d('500'),
          inSalePrice: d('500'),
          inSaleQuantity: d('2'),
        ),
      ],
    );
    return refundId;
  }

  Future<Decimal> balanceOf(int id) async =>
      (await db.accountDao.findById(id))!.value ?? Decimal.zero;

  /// Строки сторно возврата: вид → сумма (положительная — сколько ушло).
  Future<Map<int?, Decimal>> reversalByKind(int refundId) async => {
    for (final p in await db.paymentDao.findByRefund(refundId))
      p.kindId: -p.amount,
  };

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    logger = Talker();
    fiscal = const RefusingFiscalService();
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(_posId),
            accountId: Value(_posAccount),
          ),
        );
    await db
        .into(db.users)
        .insert(
          const UsersCompanion(id: Value(_cashier), name: Value('Айгуль')),
        );
    await db
        .into(db.shifts)
        .insert(
          const ShiftsCompanion(
            userId: Value(_cashier),
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
            name: 'Кофе',
            type: 0,
            measure: 0,
            quantity: Value(d('100')),
          ),
        );
    await account(_posAccount, AccountType.pos, '5000');
    await account(_bankAccount, AccountType.customBank, '5000');
    await account(_bonusAccount, AccountType.agentCashback, '0');
    await account(_customerAccount, AccountType.agentMain, '-600');
    await account(_liabilityAccount, AccountType.certificateLiability, '0');
    await db
        .into(db.agents)
        .insert(
          AgentsCompanion.insert(
            localId: const Value(_customer),
            name: const Value('Айгүл Дүйсенова'),
            cashbackAccountId: const Value(_bonusAccount),
            mainAccountId: const Value(_customerAccount),
          ),
        );
    for (final id in [
      SystemPaymentKindIds.certificate,
      SystemPaymentKindIds.qr,
      SystemPaymentKindIds.prepayment,
    ]) {
      await db.paymentKindDao.put(
        SystemPaymentKinds.byId(id).copyWith(isActive: true),
      );
    }

    await GetIt.I.reset();
    GetIt.I.registerSingleton<RefundProductService>(
      RefundProductServiceImpl(db: db, logger: logger),
    );
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  group('частичный возврат: живые деньги из ящика — последними', () {
    test('чек 400 наличными + 600 в долг, возврат 500: гасится долг, ящик '
        'не отдаёт ничего', () async {
      await receipt(1, [
        (
          accountId: _posAccount,
          kindId: SystemPaymentKindIds.cash,
          amount: '400',
          reference: null,
          transactionId: null,
        ),
        (
          accountId: _customerAccount,
          kindId: SystemPaymentKindIds.debt,
          amount: '600',
          reference: null,
          transactionId: null,
        ),
      ]);

      final refundId = await refund(1, '500', quantity: '1');

      expect(
        await reversalByKind(refundId),
        {SystemPaymentKindIds.debt: d('500')},
        reason:
            'покупатель вернул товар, за который ещё не заплатил: возврат '
            'уменьшает долг, а не вынимает наличные (пропорция отдала бы '
            'из ящика 200 при живом долге 300)',
      );
      expect(await balanceOf(_posAccount), d('5000'));
    });

    test('чек 500 сертификатом + 500 наличными, возврат 500: всё на '
        'сертификат, ящик не отдаёт ничего', () async {
      await db.certificateDao.insertCertificate(
        number: 'C-500',
        nominal: d('500'),
        issuedAt: 1000,
        status: CertificateStatus.redeemed,
        liabilityAccountId: _liabilityAccount,
      );
      await db.customUpdate(
        "UPDATE gift_certificates SET balance_millis = 0 WHERE number = 'C-500'",
      );
      await receipt(2, [
        (
          accountId: _liabilityAccount,
          kindId: SystemPaymentKindIds.certificate,
          amount: '500',
          reference: 'C-500',
          transactionId: null,
        ),
        (
          accountId: _posAccount,
          kindId: SystemPaymentKindIds.cash,
          amount: '500',
          reference: null,
          transactionId: null,
        ),
      ]);

      final refundId = await refund(2, '500', quantity: '1');

      expect(await reversalByKind(refundId), {
        SystemPaymentKindIds.certificate: d('500'),
      }, reason: 'пропорция выдала бы 250 наличными — обнал сертификата');
      // Решение заказчика 2026-09-16, пункт 2: на ту же бумажку деньги не
      // возвращаются никогда. Старая остаётся погашенной, покупатель
      // получает **новую** на закрытую ею сумму — ожившая бумажка
      // неотличима от непогашенной, и её предъявляют второй раз.
      expect(
        (await db.certificateDao.byNumber('C-500'))!.balance,
        Decimal.zero,
      );
      expect(
        (await db.certificateDao.byNumber('C-500-R$refundId'))!.balance,
        d('500'),
        reason: 'сертификатная доля ушла новой бумажкой, а не в ящик',
      );
      expect(await balanceOf(_posAccount), d('5000'));
    });
  });

  group('безнал возвращается безналом', () {
    test('карта, проведённая через терминал, при недоступном терминале — '
        'названный отказ, а не молчаливая запись', () async {
      await receipt(3, [
        (
          accountId: _bankAccount,
          kindId: SystemPaymentKindIds.card,
          amount: '1000',
          reference: null,
          transactionId: 'KP0000000001',
        ),
      ]);

      await expectLater(
        refund(3, '1000'),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            'refund_cashless_unavailable',
          ),
        ),
      );
      final written = await db.paymentDao.findByRefund(
        (await db.select(db.refunds).get()).last.localId,
      );
      expect(written, isEmpty, reason: 'деньги не вернулись — и строки нет');
      expect(await balanceOf(_bankAccount), d('5000'));
    });

    test(
      'вид с запретом возврата — названный отказ до единой записи',
      () async {
        await db.paymentKindDao.put(
          SystemPaymentKinds.byId(
            SystemPaymentKindIds.card,
          ).copyWith(refundAllowed: false),
        );
        await receipt(9, [
          (
            accountId: _bankAccount,
            kindId: SystemPaymentKindIds.card,
            amount: '1000',
            reference: null,
            transactionId: null,
          ),
        ]);

        await expectLater(
          refund(9, '1000'),
          throwsA(
            isA<WireRefusal>().having(
              (r) => r.code,
              'code',
              'refund_kind_not_refundable',
            ),
          ),
        );
        final refundId = (await db.select(db.refunds).get()).last.localId;
        expect(await db.paymentDao.findByRefund(refundId), isEmpty);
        expect(await balanceOf(_bankAccount), d('5000'));
        expect(
          (await db.productInfoDao.findByUcode(100))!.quantity,
          d('100'),
          reason: 'товар на остаток не лёг — отказ стоит раньше транзакции',
        );
      },
    );
  });

  group('фискальный возврат по видам', () {
    late _FiscalSpy spy;

    // Шпион подставляется **доводом конструктора** — через переменную
    // `fiscal` внешней области, которой собирается `RefundUseCaseImpl`.
    // Раньше он регистрировался в `GetIt`, потому что возврат искал узел
    // там; поиска больше нет, и регистрация стала бы записью, которую никто
    // не читает, — то есть зелёной по построению.
    setUp(() {
      spy = _FiscalSpy();
      fiscal = spy;
    });

    test('чек 300 бонусами + 700 наличными: наличных в документе 700, '
        'бонус — не деньги', () async {
      await receipt(4, [
        (
          accountId: _bonusAccount,
          kindId: SystemPaymentKindIds.bonus,
          amount: '300',
          reference: null,
          transactionId: null,
        ),
        (
          accountId: _posAccount,
          kindId: SystemPaymentKindIds.cash,
          amount: '700',
          reference: null,
          transactionId: null,
        ),
      ], isOfd: true);

      await refund(4, '1000');

      final args = spy.refunds.single;
      expect(args[#cashAmount], d('700'));
    });

    test('чек 400 наличными + 600 в долг: наличных в документе 400', () async {
      await receipt(5, [
        (
          accountId: _posAccount,
          kindId: SystemPaymentKindIds.cash,
          amount: '400',
          reference: null,
          transactionId: null,
        ),
        (
          accountId: _customerAccount,
          kindId: SystemPaymentKindIds.debt,
          amount: '600',
          reference: null,
          transactionId: null,
        ),
      ], isOfd: true);

      await refund(5, '1000');

      final args = spy.refunds.single;
      expect(
        args[#cashAmount],
        d('400'),
        reason:
            'долг остатком уезжал оператору наличными: 1000 при 400 из ящика',
      );
    });

    test('проданный сертификат в документ возврата не идёт — зеркало '
        'продажи (A1)', () async {
      await db
          .into(db.productInfos)
          .insert(
            ProductInfosCompanion.insert(
              ucode: const Value(900),
              barcode: 4870009990001,
              name: 'Подарочный сертификат 500',
              type: ProductType.giftCertificate.index,
              measure: 0,
              quantity: Value(d('10')),
            ),
          );
      await receipt(8, [
        (
          accountId: _posAccount,
          kindId: SystemPaymentKindIds.cash,
          amount: '1000',
          reference: null,
          transactionId: null,
        ),
      ], isOfd: true);
      await db
          .into(db.refunds)
          .insert(RefundsCompanion.insert(userId: _cashier, time: 2000));
      final refundId = (await db.select(db.refunds).get()).last.localId;

      await RefundUseCaseImpl(db: db, logger: logger, fiscal: fiscal).perform(
        refundLocalId: refundId,
        amount: d('1000'),
        userId: _cashier,
        saleReceiptNo: 8,
        salePosId: _posId,
        products: [
          RefundProductEntry(
            ucode: 100,
            quantity: d('1'),
            price: d('500'),
            inSalePrice: d('500'),
            inSaleQuantity: d('2'),
          ),
          RefundProductEntry(
            ucode: 900,
            quantity: d('1'),
            price: d('500'),
            inSalePrice: d('500'),
            inSaleQuantity: d('1'),
          ),
        ],
      );

      final args = spy.refunds.single;
      expect(args[#excludeCertificatePositions], isTrue);
      expect(
        args[#cashAmount],
        d('500'),
        reason:
            'продажа сертификата по умолчанию не фискализуется: по документу '
            'его не продавали — и возвращать по документу нечего',
      );
    });
  });

  // ── Денежный ящик после проведённого возврата ────────────────────────────
  //
  // Живая приёмка 2026-09-17: возврат чека «сертификат 3000 + наличные 200»
  // называл кассиру маршрут «Наличными из ящика — 200», проводил фискальный
  // возврат и печатал документ, а ящик **не открывался** — ни один путь
  // возврата его не звал. Пробы ниже идут через `LocalRefundService` целиком,
  // над настоящим `RefundUseCaseImpl`: решение «открывать или нет» обязано
  // приниматься по той раскладке, по которой сделаны проводки, и проба на
  // подставном юзкейсе проверяла бы только то, что ему велели ответить.
  group('денежный ящик после возврата', () {
    const terminal = 7;

    /// Чек 1000: сертификат 500 + наличные 500 — раскладка гасит сертификат
    /// первым, поэтому возврат одной штуки не трогает ящик, а двух — трогает.
    Future<void> certificateAndCash(int receiptNo) async {
      await db.certificateDao.insertCertificate(
        number: 'C-D$receiptNo',
        nominal: d('500'),
        issuedAt: 1000,
        status: CertificateStatus.redeemed,
        liabilityAccountId: _liabilityAccount,
      );
      await db.customUpdate(
        "UPDATE gift_certificates SET balance_millis = 0 "
        "WHERE number = 'C-D$receiptNo'",
      );
      await receipt(receiptNo, [
        (
          accountId: _liabilityAccount,
          kindId: SystemPaymentKindIds.certificate,
          amount: '500',
          reference: 'C-D$receiptNo',
          transactionId: null,
        ),
        (
          accountId: _posAccount,
          kindId: SystemPaymentKindIds.cash,
          amount: '500',
          reference: null,
          transactionId: null,
        ),
      ]);
    }

    LocalRefundService serviceWith(Future<bool> Function() drawer) =>
        LocalRefundService(
          db: db,
          logger: logger,
          initiation: RefundInitiationUseCaseImpl(db: db, logger: logger),
          refunds: RefundUseCaseImpl(db: db, logger: logger, fiscal: fiscal),
          canBeRefunded: CanSaleBeRefundedUseCaseImpl(db: db, logger: logger),
          drawer: drawer,
        );

    /// Загрузить чек, оставить [quantity] штук и завершить. Возвращает исход
    /// и ключ завершения — для пробы повтора.
    Future<(RefundOutcome, CartCommandMeta)> refundVia(
      LocalRefundService service,
      int receiptNo,
      String quantity,
    ) async {
      var view = await service.loadReceipt(
        terminal,
        receiptNo,
        _posId,
        const CartCommandMeta(key: 'd1', baseVersion: 0, receiptNo: null),
      );
      if (view.lines.single.quantity != d(quantity)) {
        view = await service.setLineQuantity(
          terminal,
          view.lines.single.id,
          d(quantity),
          CartCommandMeta(
            key: 'd2',
            baseVersion: view.version,
            receiptNo: view.draftNo,
          ),
        );
      }
      final meta = CartCommandMeta(
        key: 'd3',
        baseVersion: view.version,
        receiptNo: view.draftNo,
      );
      return (await service.complete(terminal, meta), meta);
    }

    test('возврат с наличной частью открывает ящик ровно один раз — и повтор '
        'той же команды его не открывает', () async {
      await certificateAndCash(21);
      var opened = 0;
      final service = serviceWith(() async {
        opened++;
        return true;
      });

      final (outcome, meta) = await refundVia(service, 21, '2');
      // Ящик отправляется, а не ожидается: дождаться его можно только через
      // чтение бед — оно ждёт отправленное.
      expect(
        await service.hardwareTroubles(terminal, outcome.refundLocalId),
        isEmpty,
      );
      expect(
        await reversalByKind(outcome.refundLocalId),
        containsPair(SystemPaymentKindIds.cash, d('500')),
        reason: 'предпосылка: наличная часть действительно ушла из ящика',
      );
      expect(opened, 1, reason: 'из ящика выданы 500 — ящик обязан открыться');

      // Повтор после обрыва приходит с тем же ключом и получает прежний
      // исход — второй раз ящик открываться не должен: денег второй раз не
      // выдавали.
      final again = await service.complete(terminal, meta);
      expect(again, outcome);
      await Future<void>.delayed(Duration.zero);
      expect(opened, 1, reason: 'повтор не выдаёт денег и ящика не открывает');
    });

    test('возврат без наличной части ящик не открывает', () async {
      await certificateAndCash(22);
      var opened = 0;
      final service = serviceWith(() async {
        opened++;
        return true;
      });

      final (outcome, _) = await refundVia(service, 22, '1');
      await Future<void>.delayed(Duration.zero);

      expect(await reversalByKind(outcome.refundLocalId), {
        SystemPaymentKindIds.certificate: d('500'),
      }, reason: 'предпосылка: всё ушло на сертификат, из ящика — ничего');
      expect(
        opened,
        0,
        reason:
            'открыть ящик, из которого по книгам не выдавали денег, — позвать '
            'кассира отдать то, чего возврат не отдавал',
      );
      expect(
        await service.hardwareTroubles(terminal, outcome.refundLocalId),
        isEmpty,
      );
    });

    // Третьим членом — ОЖИДАЕМАЯ подпись беды. Два случая говорят разное, и
    // до 2026-09-22 это различие было стёрто: чистый отказ вёз дословный
    // повтор словарного заголовка по-русски, и на английской кассе выходило
    // «Cash drawer did not open: денежный ящик не открылся».
    for (final (label, drawer, detail)
        in <(String, Future<bool> Function(), Matcher)>[
          // Ящик отказал чисто: сверх заголовка сказать нечего.
          ('ответил «не открылся»', () async => false, isEmpty),
          // Ящик бросил: подпись НЕСЁТ причину, и она кассиру нужна.
          (
            'бросил',
            () async => throw StateError('COM3: порт занят'),
            isNotEmpty,
          ),
        ]) {
      test('ящик $label: возврат состоялся, беда названа тому месту, которое '
          'возвращало, и только один раз', () async {
        await certificateAndCash(23);
        final service = serviceWith(drawer);

        final (outcome, _) = await refundVia(service, 23, '2');

        expect(outcome.amount, d('1000'));
        final row = await (db.select(
          db.refunds,
        )..where((r) => r.localId.equals(outcome.refundLocalId))).getSingle();
        expect(
          row.state,
          isNot(0),
          reason: 'отказ ящика не имеет права откатить проведённый возврат',
        );
        expect(
          await balanceOf(_posAccount),
          d('4500'),
          reason: 'наличные по книгам выданы — ящик тут ни при чём',
        );

        expect(
          await service.hardwareTroubles(terminal + 1, outcome.refundLocalId),
          isEmpty,
          reason: 'чужое рабочее место беду не видит и не съедает',
        );
        final troubles = await service.hardwareTroubles(
          terminal,
          outcome.refundLocalId,
        );
        expect(
          troubles,
          hasLength(1),
          reason: 'беда ящика обязана быть названа',
        );
        expect(troubles.single.kind, CompletionTroubleKind.drawer);
        expect(troubles.single.receiptNo, outcome.refundLocalId);
        expect(troubles.single.message, detail);
        expect(
          await service.hardwareTroubles(terminal, outcome.refundLocalId),
          isEmpty,
          reason: 'чтение разрушающее — как у продажи',
        );
      });
    }
  });

  test(
    'снимок черновика говорит, куда уйдут деньги, до подтверждения',
    () async {
      await db.certificateDao.insertCertificate(
        number: 'C-V',
        nominal: d('500'),
        issuedAt: 1000,
        status: CertificateStatus.redeemed,
        liabilityAccountId: _liabilityAccount,
      );
      await receipt(7, [
        (
          accountId: _liabilityAccount,
          kindId: SystemPaymentKindIds.certificate,
          amount: '500',
          reference: 'C-V',
          transactionId: null,
        ),
        (
          accountId: _posAccount,
          kindId: SystemPaymentKindIds.cash,
          amount: '500',
          reference: null,
          transactionId: null,
        ),
      ]);
      final service = LocalRefundService(
        db: db,
        logger: logger,
        initiation: RefundInitiationUseCaseImpl(db: db, logger: logger),
        refunds: RefundUseCaseImpl(db: db, logger: logger, fiscal: fiscal),
        canBeRefunded: CanSaleBeRefundedUseCaseImpl(db: db, logger: logger),
        drawer: () async => true,
      );

      final whole = await service.loadReceipt(
        7,
        7,
        _posId,
        const CartCommandMeta(key: 'v1', baseVersion: 0, receiptNo: null),
      );
      Map<RefundRoute, Decimal> shown(RefundView v) => {
        for (final x in v.destinations) x.route: x.amount,
      };
      expect(shown(whole), {
        RefundRoute.certificate: d('500'),
        RefundRoute.drawer: d('500'),
      });
      expect(
        whole.destinations.first.detail,
        'C-V',
        reason: 'кассир видит, на какой именно сертификат',
      );

      final half = await service.setLineQuantity(
        7,
        whole.lines.single.id,
        d('1'),
        CartCommandMeta(
          key: 'v2',
          baseVersion: whole.version,
          receiptNo: whole.draftNo,
        ),
      );
      expect(shown(half), {
        RefundRoute.certificate: d('500'),
      }, reason: 'снимок считает тем же правилом, что проведение');
    },
  );

  test(
    'чек возврата печатает то, чем вернулось, а не пропорцию чека',
    () async {
      final printer = _PrintSpy();
      GetIt.I.registerSingleton<ReceiptPrintService>(printer);
      await db.certificateDao.insertCertificate(
        number: 'C-P',
        nominal: d('500'),
        issuedAt: 1000,
        status: CertificateStatus.redeemed,
        liabilityAccountId: _liabilityAccount,
      );
      await db.customUpdate(
        "UPDATE gift_certificates SET balance_millis = 0 WHERE number = 'C-P'",
      );
      await receipt(6, [
        (
          accountId: _liabilityAccount,
          kindId: SystemPaymentKindIds.certificate,
          amount: '500',
          reference: 'C-P',
          transactionId: null,
        ),
        (
          accountId: _posAccount,
          kindId: SystemPaymentKindIds.cash,
          amount: '500',
          reference: null,
          transactionId: null,
        ),
      ]);
      final refundId = await refund(6, '500', quantity: '1');

      await LocalRefundReceiptPrinter(db: db, logger: logger).printRefund(
        outcome: RefundOutcome(
          refundLocalId: refundId,
          amount: d('500'),
          lineCount: 1,
          paymentCount: 1,
          saleReceiptNo: 6,
          salePosId: _posId,
        ),
        lines: [
          RefundLine(
            id: '1',
            productId: 100,
            name: 'Кофе',
            quantity: d('1'),
            price: d('500'),
          ),
        ],
        userId: _cashier,
      );

      final lines = printer.receipts.single.payments;
      expect(
        [for (final l in lines) (l.amount, l.isCash)],
        [(d('500'), false)],
        reason: 'чек обязан говорить то же, что строки сторно',
      );
    },
  );
}
