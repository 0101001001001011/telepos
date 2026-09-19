/// Возврат оплаты по QR — **касса целиком, провайдер по сети** (задача 26).
///
/// Настоящая база, настоящий `RefundUseCaseImpl`, настоящий
/// `LocalRefundTenderGateway`, настоящая стойка `QrPaymentDesk` с адресом
/// провайдера из `qr_provider_configs`, настоящий `HttpQrPaymentProvider` и
/// **эмулятор провайдера на сокете**. Намерение заведено через тот же
/// провод и оплачено пультом эмулятора — возврат ищет то, что провайдер
/// действительно подтвердил.
///
/// Порты 18860–18899 (правило машины: эмуляторы — 18800–18899).
library;

import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/payment/http_qr_payment_provider.dart';
import 'package:telepos/data/payment/qr_payment_desk.dart';
import 'package:telepos/data/refund/local_refund_tender_gateway.dart';
import 'package:telepos/data/usecases/refund/refund_product_service_impl.dart';
import 'package:telepos/data/usecases/refund/refund_use_case_impl.dart';
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/payment/qr_provider_settings.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import 'package:telepos/domain/usecases/refund/refund_use_case.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

import 'emulator.dart';

const _posAccount = 11;
const _bankAccount = 12;

Future<SbpEmulator> _startInRange() async {
  for (var port = 18860; port <= 18899; port++) {
    final emulator = SbpEmulator(echo: false);
    try {
      await emulator.start('127.0.0.1', port);
      return emulator;
    } on SocketException {
      continue;
    }
  }
  throw StateError('на портах 18860–18899 нет свободного');
}

void main() {
  late AppDatabase db;
  late Talker logger;
  late SbpEmulator emulator;
  late QrPaymentDesk desk;

  Decimal d(String v) => Decimal.parse(v);

  /// Чек на 1000, оплаченный по QR: намерение заведено по проводу и
  /// оплачено покупателем (пульт эмулятора).
  Future<String> qrSale(int receiptNo) async {
    final provider = HttpQrPaymentProvider(
      baseUrl: emulator.baseUrl,
      code: 'sbp_emul',
      apiKey: 'test-key',
    );
    final created = await provider.create(
      intentKey: 'sale-$receiptNo',
      amount: d('1000'),
    );
    provider.close();
    final id = created.value!.providerIntentId;
    emulator.confirm(emulator.byId[id]!);

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
            kindId: const Value(SystemPaymentKindIds.qr),
            reference: Value('sale-$receiptNo'),
            providerCode: const Value('sbp_emul'),
            terminalTransactionId: Value(id),
          ),
        );
    return id;
  }

  Future<int> refund(int receiptNo, String amount) async {
    await db
        .into(db.refunds)
        .insert(RefundsCompanion.insert(userId: 4, time: 2000));
    final id = (await db.select(db.refunds).get()).last.localId;
    await RefundUseCaseImpl(
      db: db,
      logger: logger,
      // Меряется возврат по QR, а не фискализация: отказывающий узел говорит
      // это вслух. Заглушка-«успех» соврала бы, что документ ушёл.
      fiscal: const RefusingFiscalService(),
      tenders: LocalRefundTenderGateway(db: db, logger: logger, qr: desk),
    ).perform(
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

  Future<void> configure() => db.qrProviderConfigDao.save(
    QrProviderSettings(
      baseUrl: emulator.baseUrl,
      code: 'sbp_emul',
      apiKey: 'test-key',
      patience: QrProviderSettings.defaultPatience,
    ),
    at: DateTime.now(),
  );

  setUp(() async {
    emulator = await _startInRange();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    logger = Talker();
    desk = QrPaymentDesk(db: db, logger: logger);
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
    await db.paymentKindDao.put(
      SystemPaymentKinds.byId(SystemPaymentKindIds.qr).copyWith(isActive: true),
    );
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

  test('частичный возврат уходит через провайдера, остаток — ещё раз', () async {
    await configure();
    final id = await qrSale(1);

    final first = await refund(1, '300');
    expect(emulator.byId[id]!.refundedMillis, 300000);
    expect(emulator.byId[id]!.status, kPaid, reason: 'возвращено не всё');
    final row = (await db.paymentDao.findByRefund(first)).single;
    expect(row.kindId, SystemPaymentKindIds.qr);
    expect(row.amount, d('-300'));
    expect(row.providerCode, 'sbp_emul');
    expect((await db.accountDao.findById(_posAccount))!.value, d('5000'));
  });

  test('полный возврат переводит намерение в «возвращено»', () async {
    await configure();
    final id = await qrSale(2);

    await refund(2, '1000');

    expect(emulator.byId[id]!.status, kReversed);
    expect(emulator.byId[id]!.refundedMillis, 1000000);
  });

  test('провайдер не настроен — названный отказ, деньги не записаны', () async {
    // Намерение заводим через провод, а настройку кассе не даём.
    final id = await qrSale(3);

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
    expect(emulator.byId[id]!.refundedMillis, 0);
    final refundId = (await db.select(db.refunds).get()).last.localId;
    expect(await db.paymentDao.findByRefund(refundId), isEmpty);
  });

  test('отказ провайдера доезжает кассиру названным, а не молчанием', () async {
    await configure();
    final id = await qrSale(4);
    emulator
      ..fault = 'reverseUnsupported'
      ..faultsLeft = 1;

    await expectLater(
      refund(4, '1000'),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          'refund_cashless_refused',
        ),
      ),
    );
    expect(emulator.byId[id]!.refundedMillis, 0);
  });
}
