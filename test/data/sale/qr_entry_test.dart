/// Вход в оплату по QR — **касса целиком, провайдер по сети**.
///
/// # Что стоит под пробой
///
/// Настоящий `LocalPaymentService` над настоящей базой drift, настоящая
/// стойка `QrPaymentDesk`, читающая адрес провайдера из
/// `qr_provider_configs`, настоящий `HttpQrPaymentProvider` и **эмулятор
/// провайдера на сокете**. Подставлен ровно адрес — эмулируется
/// зависимость, а не наш адаптер.
///
/// # Что утверждается
///
/// Не «суммы сошлись», а поля: `kindId`, `reference`, `providerCode`,
/// `terminalTransactionId`, `seq` строки оплаты; `abandonedAt`,
/// `settledReceiptNo`, `confirmations` намерения; состояние намерения **на
/// стороне провайдера**. Каждая группа — один из вопросов, которые обязан
/// решить вход: кто сдаётся, что при отмене, что при оплате после отмены,
/// чьё намерение.
library;

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/payment/qr_payment_desk.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/sale/local_payment_service.dart';
import 'package:telepos/data/sale/local_sale_checkout_service.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_use_case_impl.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/payment/payment_intent.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/payment/qr_payment_provider.dart';
import 'package:telepos/domain/payment/qr_provider_settings.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

import '../../emulators/sbp/emulator.dart';
import '../../helpers/cash_drawer.dart';

const _barcode = '4870001234567';
const _terminal = 7;

void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late LocalPaymentService payments;
  late SbpEmulator emulator;

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta m(String key, int base, {int? receiptNo}) =>
      CartCommandMeta(key: key, baseVersion: base, receiptNo: receiptNo);

  CartCommandMeta mv(CartView v, String key) =>
      CartCommandMeta(key: key, baseVersion: v.version, receiptNo: v.receiptNo);

  Future<void> configure({
    Duration patience = QrProviderSettings.defaultPatience,
  }) => db.qrProviderConfigDao.save(
    QrProviderSettings(
      baseUrl: emulator.baseUrl,
      code: 'sbp_emul',
      apiKey: 'test-key',
      patience: patience,
    ),
    at: DateTime.now(),
  );

  Future<void> enableQr() => db.paymentKindDao.put(
    SystemPaymentKinds.byId(SystemPaymentKindIds.qr).copyWith(isActive: true),
  );

  /// Чек на 1000 (две штуки по 500) на рабочем месте [terminalId].
  Future<CartView> receipt({int terminalId = _terminal}) async {
    var view = await cart.start(
      terminalId: terminalId,
      wholesale: false,
      meta: m('t$terminalId-1', 0),
    );
    view = await cart.addByBarcode(
      terminalId,
      _barcode,
      mv(view, 't$terminalId-2'),
    );
    return cart.setQuantity(
      terminalId,
      view.lines.single.id,
      d('2'),
      mv(view, 't$terminalId-3'),
    );
  }

  Matcher refusedWith(String code) =>
      throwsA(isA<WireRefusal>().having((r) => r.code, 'code', code));

  setUp(() async {
    emulator = SbpEmulator(echo: false);
    await emulator.start('127.0.0.1', 0);
    await emulator.startControl('127.0.0.1', 0);

    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(id: Value(1), accountId: Value(11)),
        );
    await db
        .into(db.users)
        .insert(const UsersCompanion(id: Value(4), name: Value('Айгуль')));
    await db
        .into(db.shifts)
        .insert(
          ShiftsCompanion(
            userId: Value(4),
            openTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
            isOpened: Value(true),
            isSynced: Value(false),
          ),
        );
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(100),
            barcode: int.parse(_barcode),
            name: 'Товар',
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
            barcode: int.parse(_barcode),
            sellingPrice: Value(d('500')),
          ),
        );
    for (final (id, type) in [
      (11, AccountType.pos),
      (12, AccountType.customBank),
    ]) {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: Value(id),
              type: type,
              name: Value('Счёт $id'),
              value: Value(Decimal.zero),
              visibleToPos: const Value(true),
            ),
          );
    }

    final logger = Talker();
    cart = LocalCartService(
      db: db,
      logger: logger,
      initiation: SaleInitiationUseCaseImpl(db: db, logger: logger),
      deferred: DeferredSaleServiceImpl(db: db, logger: logger),
      rounding: SaleRoundOptionUseCaseImpl(),
      findByBarcode: FindByBarcodeUseCaseImpl(db: db, logger: logger),
      searchProducts: SearchProductInfoUseCaseImpl(db: db, logger: logger),
    );
    payments = LocalPaymentService(
      db: db,
      checkout: LocalSaleCheckoutService(db: db, cart: cart, logger: logger),
      sale: SaleUseCaseImpl(db: db, logger: logger),
      logger: logger,
      cardTerminal: (_, {required amountTiyn, required receiptNo}) async =>
          const CardCharge(outcome: CardChargeOutcome.notConfigured),
      fiscal: const RefusingFiscalService(),
      qr: QrPaymentDesk(
        db: db,
        logger: logger,
        timeout: const Duration(milliseconds: 700),
        pollEvery: const Duration(milliseconds: 20),
      ),
      drawer: drawerOpens,
    );
  });

  tearDown(() async {
    await db.close();
    await emulator.stop();
  });

  group('вход закрыт, пока касса не готова', () {
    test(
      'провайдер не настроен — названный отказ, провайдера не зовут',
      () async {
        await enableQr();
        final view = await receipt();

        await expectLater(
          payments.startQr(_terminal, d('1000'), mv(view, 'a1')),
          refusedWith(qrNotConfiguredCode),
        );
        expect(await db.select(db.paymentIntents).get(), isEmpty);
        expect(emulator.byId, isEmpty);
      },
    );

    test('вид выключен — отказ кассы раньше провайдера', () async {
      await configure();
      final view = await receipt();

      await expectLater(
        payments.startQr(_terminal, d('1000'), mv(view, 'a1')),
        refusedWith(payKindInactiveCode),
      );
      expect(emulator.byId, isEmpty);
    });

    // Пункт 9 C (2026-09-15): тот же ответ, что дал бы `startQr`, — до
    // нажатия и без чека.
    test(
      'готовность QR называет ту же беду, что startQr, и не зовёт провайдера',
      () async {
        expect(await payments.qrUnavailableReason(), payKindInactiveCode);
        await enableQr();
        expect(await payments.qrUnavailableReason(), qrNotConfiguredCode);
        await configure();
        expect(await payments.qrUnavailableReason(), isNull);
        expect(emulator.byId, isEmpty);
      },
    );

    test('сумма больше чека — отказ, кода нет', () async {
      await configure();
      await enableQr();
      final view = await receipt();

      await expectLater(
        payments.startQr(_terminal, d('1000.01'), mv(view, 'a1')),
        refusedWith(payAmountExceedsReceiptCode),
      );
      expect(emulator.byId, isEmpty);
    });
  });

  group('код показан, покупатель заплатил, деньги легли в чек', () {
    test('поля строки оплаты и намерения — не только сумма', () async {
      await configure();
      await enableQr();
      final view = await receipt();

      final shown = await payments.startQr(
        _terminal,
        d('1000'),
        mv(view, 'a1'),
      );
      expect(shown.phase, QrTenderPhase.waiting);
      expect(shown.qrPayload, contains('qr.emul.local'));
      expect(shown.secondsLeft, inInclusiveRange(170, 180));
      expect(shown.receiptNo, view.receiptNo);

      final onProvider = emulator.byKey[shown.intentKey]!;
      expect(onProvider.status, kPending);

      // Ожидание — ещё не деньги: закрыть чек ключом нельзя.
      await expectLater(
        payments.complete(
          _terminal,
          PaymentRequest(type: PaymentType.cash, qrIntentKey: shown.intentKey),
          mv(view, 'pay0'),
        ),
        refusedWith(payQrNotPaidCode),
      );

      emulator.confirm(onProvider);
      final paid = await payments.pollQr(_terminal, shown.intentKey);
      expect(paid.phase, QrTenderPhase.paid);
      expect(paid.paidAmount, d('1000'));
      expect(paid.qrPayload, isNull, reason: 'оплаченный код не показывают');

      final outcome = await payments.complete(
        _terminal,
        PaymentRequest(type: PaymentType.cash, qrIntentKey: shown.intentKey),
        mv(view, 'pay1'),
      );
      expect(outcome.paid, d('1000'));

      final rows = await db.paymentDao.findBySale(view.receiptNo!, view.posId);
      final qrRows = rows
          .where((p) => p.kindId == SystemPaymentKindIds.qr)
          .toList();
      expect(qrRows, hasLength(1));
      final row = qrRows.single;
      expect(row.amount, d('1000'));
      expect(row.reference, shown.intentKey);
      expect(row.providerCode, 'sbp_emul');
      expect(row.terminalTransactionId, onProvider.id);
      expect(row.seq, 0);
      expect(row.payeeAccountId, 12, reason: 'банковский счёт, не ящик');
      expect(
        rows.where((p) => p.kindId != SystemPaymentKindIds.qr),
        isEmpty,
        reason: 'наличных в этом чеке не было',
      );

      final intent = (await db.paymentIntentDao.byKey(shown.intentKey))!;
      expect(intent.settledReceiptNo, view.receiptNo);
      expect(intent.abandonedAt, isNull);
      expect(intent.confirmations, 1);
      expect(intent.terminalId, _terminal);
    });

    test('повтор той же попытки не заводит второго кода', () async {
      await configure();
      await enableQr();
      final view = await receipt();

      final first = await payments.startQr(
        _terminal,
        d('1000'),
        mv(view, 'a1'),
      );
      final again = await payments.startQr(
        _terminal,
        d('1000'),
        mv(view, 'a1'),
      );

      expect(again.intentKey, first.intentKey);
      expect(emulator.byId, hasLength(1));
      expect(await db.select(db.paymentIntents).get(), hasLength(1));
    });

    test('на чеке уже ждёт код — второй не показывается', () async {
      await configure();
      await enableQr();
      final view = await receipt();

      await payments.startQr(_terminal, d('1000'), mv(view, 'a1'));
      await expectLater(
        payments.startQr(_terminal, d('500'), mv(view, 'a2')),
        refusedWith(payQrIntentLiveCode),
      );
      expect(emulator.byId, hasLength(1));
    });
  });

  group('кассир прервал ожидание', () {
    test(
      'отмена подтверждена — фаза, отметка и состояние у провайдера',
      () async {
        await configure();
        await enableQr();
        final view = await receipt();

        final shown = await payments.startQr(
          _terminal,
          d('1000'),
          mv(view, 'a1'),
        );
        final after = await payments.cancelQr(_terminal, shown.intentKey);

        expect(after.phase, QrTenderPhase.cashierCancelled);
        final intent = (await db.paymentIntentDao.byKey(shown.intentKey))!;
        expect(intent.abandonedAt, isNotNull);
        expect(intent.status, QrIntentStatus.cancelled);
        expect(emulator.byKey[shown.intentKey]!.status, kCancelled);

        await expectLater(
          payments.complete(
            _terminal,
            PaymentRequest(
              type: PaymentType.cash,
              qrIntentKey: shown.intentKey,
            ),
            mv(view, 'pay1'),
          ),
          refusedWith(payQrNotPaidCode),
        );

        // Отменённый код больше не живой — новый показывается.
        final next = await payments.startQr(
          _terminal,
          d('1000'),
          mv(view, 'a2'),
        );
        expect(next.phase, QrTenderPhase.waiting);
      },
    );

    test(
      'покупатель заплатил раньше, чем дошла отмена — деньги идут в чек',
      () async {
        await configure();
        await enableQr();
        final view = await receipt();

        final shown = await payments.startQr(
          _terminal,
          d('1000'),
          mv(view, 'a1'),
        );
        // Оплата случилась между последним опросом и нажатием «Отменить».
        emulator.confirm(emulator.byKey[shown.intentKey]!);

        final after = await payments.cancelQr(_terminal, shown.intentKey);
        expect(after.phase, QrTenderPhase.paidAfterGiveUp);
        expect(after.usable, isTrue);

        final beforeSettle = (await db.paymentIntentDao.byKey(
          shown.intentKey,
        ))!;
        expect(beforeSettle.abandonedAt, isNotNull);
        expect(beforeSettle.isPaidAfterGiveUp, isTrue);

        await payments.complete(
          _terminal,
          PaymentRequest(type: PaymentType.cash, qrIntentKey: shown.intentKey),
          mv(view, 'pay1'),
        );
        final row = (await db.paymentDao.findBySale(
          view.receiptNo!,
          view.posId,
        )).singleWhere((p) => p.kindId == SystemPaymentKindIds.qr);
        expect(row.reference, shown.intentKey);
        expect(row.amount, d('1000'));
        final settled = (await db.paymentIntentDao.byKey(shown.intentKey))!;
        expect(settled.settledReceiptNo, view.receiptNo);
        expect(settled.isOrphanMoney, isFalse);
      },
    );

    test('отмена не дошла — «не подтверждена»; повторная проверка отменяет, '
        'не сдвигая отметку', () async {
      await configure();
      await enableQr();
      final view = await receipt();

      final shown = await payments.startQr(
        _terminal,
        d('1000'),
        mv(view, 'a1'),
      );
      emulator
        ..fault = 'kill'
        ..faultsLeft = 1;

      final unconfirmed = await payments.cancelQr(_terminal, shown.intentKey);
      expect(unconfirmed.phase, QrTenderPhase.cancelUnconfirmed);
      expect(unconfirmed.phase.blocksCompletion, isTrue);
      final first = (await db.paymentIntentDao.byKey(shown.intentKey))!;
      expect(first.status, QrIntentStatus.pending);
      expect(first.abandonedAt, isNotNull);
      expect(emulator.byKey[shown.intentKey]!.status, kPending);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      final rechecked = await payments.pollQr(_terminal, shown.intentKey);
      expect(rechecked.phase, QrTenderPhase.cashierCancelled);
      final second = (await db.paymentIntentDao.byKey(shown.intentKey))!;
      expect(
        second.abandonedAt,
        first.abandonedAt,
        reason: 'отметка — когда касса сдалась впервые, а не последняя попытка',
      );
      expect(emulator.byKey[shown.intentKey]!.status, kCancelled);
    });
  });

  group('сдаётся касса, а не вкладка', () {
    test('круг после срока терпения отменяет код сам', () async {
      await configure(patience: const Duration(seconds: 1));
      await enableQr();
      final view = await receipt();

      final shown = await payments.startQr(
        _terminal,
        d('1000'),
        mv(view, 'a1'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      final after = await payments.pollQr(_terminal, shown.intentKey);
      expect(after.phase, QrTenderPhase.patienceSpent);
      final intent = (await db.paymentIntentDao.byKey(shown.intentKey))!;
      expect(
        intent.abandonedAt!.difference(intent.createdAt),
        greaterThanOrEqualTo(const Duration(seconds: 1)),
      );
      expect(emulator.byKey[shown.intentKey]!.status, kCancelled);
    });

    test(
      'брошенный код отменяется перед новым, даже если никто не спрашивал',
      () async {
        await configure(patience: const Duration(seconds: 1));
        await enableQr();
        final view = await receipt();

        final abandoned = await payments.startQr(
          _terminal,
          d('1000'),
          mv(view, 'a1'),
        );
        // Вкладка закрыта — опросов нет.
        await Future<void>.delayed(const Duration(milliseconds: 1100));

        final next = await payments.startQr(
          _terminal,
          d('1000'),
          mv(view, 'a2'),
        );
        expect(next.phase, QrTenderPhase.waiting);
        final old = (await db.paymentIntentDao.byKey(abandoned.intentKey))!;
        expect(old.abandonedAt, isNotNull);
        expect(emulator.byKey[abandoned.intentKey]!.status, kCancelled);
      },
    );
  });

  group('намерение принадлежит рабочему месту', () {
    test(
      'чужая вкладка не опросит, не отменит и не закроет им свой чек',
      () async {
        await configure();
        await enableQr();
        final mine = await receipt();
        final theirs = await receipt(terminalId: 8);

        final shown = await payments.startQr(
          _terminal,
          d('1000'),
          mv(mine, 'a1'),
        );

        await expectLater(
          payments.pollQr(8, shown.intentKey),
          refusedWith(payQrIntentUnknownCode),
        );
        await expectLater(
          payments.cancelQr(8, shown.intentKey),
          refusedWith(payQrIntentUnknownCode),
        );
        expect(emulator.byKey[shown.intentKey]!.status, kPending);

        emulator.confirm(emulator.byKey[shown.intentKey]!);
        expect(
          (await payments.pollQr(_terminal, shown.intentKey)).phase,
          QrTenderPhase.paid,
        );

        await expectLater(
          payments.complete(
            8,
            PaymentRequest(
              type: PaymentType.cash,
              qrIntentKey: shown.intentKey,
            ),
            mv(theirs, 'pay8'),
          ),
          refusedWith(payQrIntentUnknownCode),
        );
        final intent = (await db.paymentIntentDao.byKey(shown.intentKey))!;
        expect(intent.settledAt, isNull, reason: 'деньги не ушли в чужой чек');
      },
    );

    // Пункт 10 C (2026-09-15): проверка владельца стояла только у намерений
    // с `terminalId` — намерение без рабочего места опрашивал, отменял и
    // закрывал своим чеком **любой** терминал, знающий ключ. Такое намерение
    // `startQr` не заводит (место всегда из сеанса), но строка без места
    // достижима: засев стенда `stand/seed-qr-intent`, ручная правка базы,
    // будущий путь, забывший довод `claim`. Оплаченные деньги без места —
    // «деньги без чека» (`orphanMoney`), их разбирает человек, а не первая
    // вкладка, угадавшая ключ.
    test('намерение без рабочего места не принадлежит никому', () async {
      await configure();
      await enableQr();
      final view = await receipt();
      final (row, _) = await db.paymentIntentDao.claim(
        intentKey: 'ничьё',
        providerCode: 'sbp_emul',
        amount: d('1000'),
        createdAt: DateTime.now(),
      );
      await db.paymentIntentDao.applyState(
        id: row.id,
        status: QrIntentStatus.paid,
        paidAmount: d('1000'),
        confirmedAt: DateTime.now(),
        countConfirmation: true,
      );

      await expectLater(
        payments.pollQr(_terminal, 'ничьё'),
        refusedWith(payQrIntentUnknownCode),
      );
      await expectLater(
        payments.cancelQr(_terminal, 'ничьё'),
        refusedWith(payQrIntentUnknownCode),
      );
      await expectLater(
        payments.complete(
          _terminal,
          PaymentRequest(type: PaymentType.cash, qrIntentKey: 'ничьё'),
          mv(view, 'pay-orphan'),
        ),
        refusedWith(payQrIntentUnknownCode),
      );
      final after = (await db.paymentIntentDao.byKey('ничьё'))!;
      expect(after.settledAt, isNull, reason: 'деньги без чека не ушли в чек');
    });
  });
}
