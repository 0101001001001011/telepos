/// Возврат на карту — **касса целиком, терминал по сокету** (задача 26).
///
/// # Что стоит под пробой
///
/// Настоящая база, настоящий `RefundUseCaseImpl`, настоящий
/// `LocalRefundTenderGateway`, настоящий `KaspiPosService` и **эмулятор
/// терминала на сокете**. Подставлен ровно адрес прибора (как у оплаты —
/// привязкой к рабочему месту); отправка кадра, ответ и разбор — настоящие.
///
/// Покупка проводится **через тот же сокет** настоящим
/// `KaspiPosService.requestPayment`, и номер операции в строку оплаты кладётся
/// из ответа — возврат ищет то, что терминал действительно провёл.
///
/// # Порты
///
/// 18800–18829 (правило машины: эмуляторы — 18800–18899; WebKassa возврата
/// — 18830–18859, СБП — 18860–18899, чтобы пробы не толкались).
library;

import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/refund/local_refund_tender_gateway.dart';
import 'package:telepos/data/usecases/refund/refund_product_service_impl.dart';
import 'package:telepos/data/usecases/refund/refund_use_case_impl.dart';
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import 'package:telepos/domain/usecases/refund/refund_use_case.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/hardware/kaspi_pos/kaspi_pos_config.dart';
import 'package:telepos/hardware/kaspi_pos/kaspi_pos_service.dart';

import 'emulator.dart';

const _posAccount = 11;
const _bankAccount = 12;

Future<KaspiEmulator> _startInRange() async {
  for (var port = 18800; port <= 18829; port++) {
    final emulator = KaspiEmulator(echo: false);
    try {
      await emulator.start('127.0.0.1', port);
      return emulator;
    } on SocketException {
      continue;
    }
  }
  throw StateError('на портах 18800–18829 нет свободного');
}

void main() {
  late AppDatabase db;
  late Talker logger;
  late KaspiEmulator emulator;
  late KaspiPosConfig terminal;

  Decimal d(String v) => Decimal.parse(v);

  RefundUseCaseImpl useCase({bool bound = true}) => RefundUseCaseImpl(
    db: db,
    logger: logger,
    // Меряется возврат на терминал, а не фискализация: отказывающий узел
    // говорит это вслух. Заглушка-«успех» соврала бы, что документ ушёл.
    fiscal: const RefusingFiscalService(),
    tenders: LocalRefundTenderGateway(
      db: db,
      logger: logger,
      terminalConfig: (terminalId) async =>
          bound && terminalId == 7 ? terminal : null,
    ),
  );

  /// Покупка на 1000 через настоящий терминал и чек с её строкой карты.
  Future<String> cardSale(int receiptNo) async {
    final service = KaspiPosService(config: terminal);
    final charge = await service.requestPayment(
      amountKopeiki: 100000,
      receiptNo: '$receiptNo',
    );
    await service.disconnect();
    expect(charge.success, isTrue, reason: 'подготовка: покупка одобрена');

    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: receiptNo,
            posId: 1,
            userId: 4,
            amount: d('1000'),
            time: 1700000000,
            state: const Value(1),
          ),
        );
    await db
        .into(db.payments)
        .insert(
          PaymentsCompanion.insert(
            userId: 4,
            payeeAccountId: _bankAccount,
            amount: d('1000'),
            time: 1700000000,
            receiptNo: Value(receiptNo),
            posId: const Value(1),
            state: const Value(1),
            kindId: const Value(SystemPaymentKindIds.card),
            approvalCode: Value(charge.approvalCode),
            cardMask: Value(charge.cardMask),
            terminalTransactionId: Value(charge.transactionId),
          ),
        );
    return charge.transactionId!;
  }

  Future<int> refund(
    int receiptNo,
    String amount, {
    int? refundId,
    RefundUseCaseImpl? with_,
  }) async {
    var id = refundId;
    if (id == null) {
      await db
          .into(db.refunds)
          .insert(RefundsCompanion.insert(userId: 4, time: 2000));
      id = (await db.select(db.refunds).get()).last.localId;
    }
    await (with_ ?? useCase()).perform(
      refundLocalId: id,
      amount: d(amount),
      userId: 4,
      saleReceiptNo: receiptNo,
      salePosId: 1,
      terminalId: 7,
      products: const <RefundProductEntry>[],
    );
    return id;
  }

  setUp(() async {
    emulator = await _startInRange();
    terminal = KaspiPosConfig(
      host: '127.0.0.1',
      port: emulator.port,
      enabled: true,
    );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    logger = Talker();
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            accountId: Value(_posAccount),
          ),
        );
    for (final (id, type) in [
      (_posAccount, AccountType.pos),
      (_bankAccount, AccountType.customBank),
    ]) {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: Value(id),
              type: type,
              value: Value(d('5000')),
            ),
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
    await emulator.stop();
  });

  test('возврат уходит на карту по той операции, которую терминал провёл', () async {
    final txn = await cardSale(1);

    final refundId = await refund(1, '1000');

    expect(
      emulator.transactions[txn]!.refunded,
      100000,
      reason: 'терминал вернул 1000 по операции покупки',
    );
    final row = (await db.paymentDao.findByRefund(refundId)).single;
    expect(row.kindId, SystemPaymentKindIds.card);
    expect(row.amount, d('-1000'));
    expect(
      row.terminalTransactionId,
      startsWith('KR'),
      reason: 'строка сторно несёт номер операции ВОЗВРАТА, по нему сверяют',
    );
    expect(
      (await db.accountDao.findById(_posAccount))!.value,
      d('5000'),
      reason: 'из ящика не вышло ничего',
    );
  });

  test('повтор того же возврата не возвращает деньги второй раз', () async {
    final txn = await cardSale(2);
    await db
        .into(db.refunds)
        .insert(RefundsCompanion.insert(userId: 4, time: 2000));
    final refundId = (await db.select(db.refunds).get()).last.localId;

    // Первая попытка: терминал вернул, а запись в базу сорвалась снаружи —
    // моделируется тем, что ту же долю зовут через шлюз второй раз с тем же
    // ключом, как это сделает повтор `perform` над той же строкой `Refunds`.
    final gateway = LocalRefundTenderGateway(
      db: db,
      logger: logger,
      terminalConfig: (_) async => terminal,
    );
    final first = await gateway.returnCard(
      terminalId: 7,
      transactionId: txn,
      amount: d('400'),
      refundKey: 'refund:$refundId:0',
    );
    final second = await gateway.returnCard(
      terminalId: 7,
      transactionId: txn,
      amount: d('400'),
      refundKey: 'refund:$refundId:0',
    );

    expect(first.ok && second.ok, isTrue);
    expect(second.transactionId, first.transactionId);
    expect(emulator.transactions[txn]!.refunded, 40000);
  });

  test('больше оплаченного терминал не возвращает — отказ, строки нет', () async {
    final txn = await cardSale(3);
    // Чек «испорчен» вручную: строка карты утверждает 1500 при проведённых
    // 1000 — касса обязана услышать отказ терминала, а не записать возврат.
    await (db.update(db.payments)..where((p) => p.receiptNo.equals(3))).write(
      PaymentsCompanion(amount: Value(d('1500'))),
    );

    await expectLater(
      refund(3, '1500'),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          'refund_cashless_refused',
        ),
      ),
    );
    expect(emulator.transactions[txn]!.refunded, 0);
    final refundId = (await db.select(db.refunds).get()).last.localId;
    expect(await db.paymentDao.findByRefund(refundId), isEmpty);
  });

  test('терминал не привязан к рабочему месту — названный отказ', () async {
    final txn = await cardSale(4);

    await expectLater(
      refund(4, '1000', with_: useCase(bound: false)),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          'refund_cashless_unavailable',
        ),
      ),
    );
    expect(emulator.transactions[txn]!.refunded, 0);
  });
}
