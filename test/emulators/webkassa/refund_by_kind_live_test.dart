/// Фискальный возврат по видам — **касса целиком, оператор по сокету**
/// (задача 26).
///
/// Настоящая база, настоящий `RefundUseCaseImpl`, настоящий
/// `FiscalServiceImpl` и настоящий `WebKassaProvider` против эмулятора
/// WebKassa на сокете. Утверждается конверт, **который получил оператор**:
/// типы оплат, скидки позиций и то, что эмулятор пересчитал документ без
/// жалоб (`recountCheck`) — тот же пересчёт, которым отказывает оператор
/// кодом 9.
///
/// Порты 18830–18859 (правило машины: эмуляторы — 18800–18899).
library;

import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/usecases/fiscal/fiscal_service_impl.dart';
import 'package:telepos/data/usecases/refund/refund_product_service_impl.dart';
import 'package:telepos/data/usecases/refund/refund_use_case_impl.dart';
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import 'package:telepos/domain/usecases/refund/refund_use_case.dart';

import 'emulator.dart';
import 'offset_fiscal_live_test.dart' as live;
import 'state.dart';

const _posAccount = 11;
const _bonusAccount = 13;
const _customerAccount = 14;
const _customer = 5;

Future<WebKassaEmulator> _startInRange(EmulatorState state) async {
  for (var port = 18830; port <= 18859; port++) {
    final emulator = WebKassaEmulator(state: state, echo: false);
    try {
      await emulator.start('127.0.0.1', port);
      return emulator;
    } on SocketException {
      continue;
    }
  }
  throw StateError('на портах 18830–18859 нет свободного');
}

void main() {
  late AppDatabase db;
  late Talker logger;
  late EmulatorState state;
  late WebKassaEmulator emulator;

  /// Настоящий `FiscalServiceImpl` над эмулятором — довод возврата.
  late FiscalService fiscal;

  Decimal d(String v) => Decimal.parse(v);

  Future<void> account(int id, int type) => db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          id: Value(id),
          type: type,
          value: Value(d('0')),
        ),
      );

  Future<void> receipt(
    int receiptNo,
    List<({int accountId, int kindId, String amount})> rows,
  ) async {
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
            isOfd: const Value(true),
            customerLocalId: const Value(_customer),
          ),
        );
    await db
        .into(db.saleProducts)
        .insert(
          SaleProductsCompanion.insert(
            receiptNo: Value(receiptNo),
            posId: const Value(1),
            ucode: 100,
            quantity: d('2'),
            price: d('500'),
            priceBefore: d('500'),
          ),
        );
    for (var i = 0; i < rows.length; i++) {
      await db
          .into(db.payments)
          .insert(
            PaymentsCompanion.insert(
              userId: 4,
              payeeAccountId: rows[i].accountId,
              amount: d(rows[i].amount),
              time: 1700000000,
              receiptNo: Value(receiptNo),
              posId: const Value(1),
              state: const Value(1),
              kindId: Value(rows[i].kindId),
              seq: Value(i),
            ),
          );
    }
  }

  Future<void> refundWhole(int receiptNo) async {
    await db
        .into(db.refunds)
        .insert(RefundsCompanion.insert(userId: 4, time: 2000));
    final id = (await db.select(db.refunds).get()).last.localId;
    await RefundUseCaseImpl(
      db: db,
      logger: logger,
      fiscal: fiscal,
    ).perform(
      refundLocalId: id,
      amount: d('1000'),
      userId: 4,
      saleReceiptNo: receiptNo,
      salePosId: 1,
      customerLocalId: _customer,
      products: [
        RefundProductEntry(
          ucode: 100,
          quantity: d('2'),
          price: d('500'),
          inSalePrice: d('500'),
          inSaleQuantity: d('2'),
          inSalePriceBefore: d('500'),
        ),
      ],
    );
  }

  JournalEntry refundCheck() => state.journal
      .where((e) => e.path == '/api/v4/check')
      .singleWhere((e) => e.request['OperationType'] == 3);

  Map<int, Decimal> paymentsByType(JournalEntry check) => {
    for (final p in (check.request['Payments'] as List)
        .cast<Map<String, Object?>>())
      (p['PaymentType'] as num).toInt(): live.money(p['Sum']),
  };

  Decimal discounts(JournalEntry check) => [
    for (final p in (check.request['Positions'] as List)
        .cast<Map<String, Object?>>())
      live.money(p['Discount'] ?? '0'),
  ].fold(Decimal.zero, (a, b) => a + b);

  setUp(() async {
    state = live.emulatorState();
    emulator = await _startInRange(state);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    logger = Talker();
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            accountId: Value(_posAccount),
            cashBoxName: Value('Касса 1'),
            companyName: Value('ТОО Ромашка'),
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
    await account(_posAccount, AccountType.pos);
    await account(_bonusAccount, AccountType.agentCashback);
    await account(_customerAccount, AccountType.agentMain);
    await db
        .into(db.agents)
        .insert(
          const AgentsCompanion(
            localId: Value(_customer),
            name: Value('Покупатель'),
            cashbackAccountId: Value(_bonusAccount),
            mainAccountId: Value(_customerAccount),
          ),
        );

    // Настоящий узел над эмулятором — **переменной, а не записью в GetIt**:
    // возврат получает его доводом конструктора (`fiscal:` у
    // `RefundUseCaseImpl` ниже). Регистрации больше нет, потому что читать
    // её стало некому, а запись, которую никто не читает, зелена по
    // построению.
    fiscal = FiscalServiceImpl(
      db: db,
      registry: live.emulatorRegistry(logger),
      settingsSource: live.FixedFiscalSettings(
        live.emulatorSettings(emulator.baseUri),
      ),
      logger: logger,
    );
    GetIt.I.registerSingleton<RefundProductService>(
      RefundProductServiceImpl(db: db, logger: logger),
    );
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
    await emulator.stop();
  });

  test('чек 300 бонусами + 700 наличными: оператору наличные 700, бонус — '
      'скидка позиций, документ сводится', () async {
    await receipt(1, [
      (
        accountId: _bonusAccount,
        kindId: SystemPaymentKindIds.bonus,
        amount: '300',
      ),
      (accountId: _posAccount, kindId: SystemPaymentKindIds.cash, amount: '700'),
    ]);

    await refundWhole(1);

    final check = refundCheck();
    expect(check.outcome, 'ok');
    expect(paymentsByType(check), {0: d('700')});
    expect(discounts(check), d('300'));
    expect(recountCheck(check.request, VatMode.off).complaint, isNull);
  });

  test('чек 400 наличными + 600 в долг: оператору наличные 400, долг — не '
      'оплата «кредит» (исключена ОФД 2.0.2), документ сводится', () async {
    await receipt(2, [
      (accountId: _posAccount, kindId: SystemPaymentKindIds.cash, amount: '400'),
      (
        accountId: _customerAccount,
        kindId: SystemPaymentKindIds.debt,
        amount: '600',
      ),
    ]);

    await refundWhole(2);

    final check = refundCheck();
    expect(check.outcome, 'ok');
    expect(paymentsByType(check), {0: d('400')});
    expect(recountCheck(check.request, VatMode.off).complaint, isNull);
  });

  test('возврат целиком в погашение долга документа не даёт', () async {
    await receipt(3, [
      (
        accountId: _customerAccount,
        kindId: SystemPaymentKindIds.debt,
        amount: '1000',
      ),
    ]);

    await refundWhole(3);

    expect(
      state.journal.where((e) => e.path == '/api/v4/check'),
      isEmpty,
      reason: 'денег не вышло — фискального возврата денег нет',
    );
  });
}
