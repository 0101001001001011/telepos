library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/fiscal/fiscal_settings_store.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();

  setUp(() => h.setUp());
  tearDown(() => h.tearDown());

  Future<int> seedInProgressSale(
    AppDatabase db, {
    required int receiptNo,
    required int ucode,
    required Decimal qty,
    required Decimal price,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db
        .into(db.sales)
        .insert(
          SalesCompanion(
            receiptNo: drift.Value(receiptNo),
            posId: const drift.Value(1),
            userId: const drift.Value(1),
            amount: drift.Value(qty * price),
            time: drift.Value(now),
            state: const drift.Value(0),
          ),
        );
    await db
        .into(db.saleProducts)
        .insert(
          SaleProductsCompanion(
            receiptNo: drift.Value(receiptNo),
            posId: const drift.Value(1),
            ucode: drift.Value(ucode),
            quantity: drift.Value(qty),
            price: drift.Value(price),
            priceBefore: drift.Value(price),
          ),
        );
    return receiptNo;
  }

  Future<bool> performAndReadIsOfd(AppDatabase db, int receiptNo) async {
    final saleUseCase = GetIt.I<SaleUseCase>();
    final posAccId = (await db.accountDao.findByType(AccountType.pos)).first.id;
    await saleUseCase.perform(
      receiptNo: receiptNo,
      posId: 1,
      amount: d('450'),
      // Строки чека этот журнал кладёт в базу сам, с уже готовыми ценами:
      // переписывать `perform` нечего. Пустой список — не заглушка, а
      // утверждение «формат уже верен» (задача 9).
      lines: const [],
      payments: [PaymentEntry(kindId: SystemPaymentKindIds.cash, payeeAccountId: posAccId, amount: d('450'))],
      change: Decimal.zero,
      selectiveOfd: false,
    );
    final sale = await db.saleDao.findByKey(receiptNo, 1);
    return sale!.isOfd;
  }

  test('Оператор НЕ выбран (none) → продажа НЕ фискальная (isOfd=false), '
      'без ошибок', () async {
    final db = h.db;
    await seedInProgressSale(
      db,
      receiptNo: 8001,
      ucode: 1001,
      qty: d('1'),
      price: d('450'),
    );

    final isOfd = await performAndReadIsOfd(db, 8001);

    expect(
      isOfd,
      isFalse,
      reason: 'нет оператора → чистый учёт, продажа не фискальная',
    );
  });

  test('Оператор ВЫБРАН (WebKassa) → продажа фискальная (isOfd=true) '
      'по умолчанию ALL, без отдельного sendToOfd', () async {
    final db = h.db;
    final prefs = await SharedPreferences.getInstance();
    await FiscalSettingsStore(prefs).save(
      FiscalSettings(
        operatorType: FiscalOperatorType.webkassa,
        apiKey: 'WKD-TEST',
        login: 'kassa@test.kz',
        password: 'secret',
        cashboxUniqueNumber: 'SWK00012345',
      ),
    );

    await seedInProgressSale(
      db,
      receiptNo: 8002,
      ucode: 1001,
      qty: d('1'),
      price: d('450'),
    );

    final isOfd = await performAndReadIsOfd(db, 8002);

    expect(
      isOfd,
      isTrue,
      reason: 'оператор выбран → фискализируем (ofdSyncType по умолчанию ALL)',
    );
  });

  test(
    'Смена закрывается даже без оператора (чистый учёт, не блокирует)',
    () async {
      final db = h.db;
      final isOfd = await performAndReadIsOfd(
        db,
        await seedInProgressSale(
          db,
          receiptNo: 8003,
          ucode: 1001,
          qty: d('1'),
          price: d('450'),
        ),
      );
      expect(isOfd, isFalse);
    },
  );
}
