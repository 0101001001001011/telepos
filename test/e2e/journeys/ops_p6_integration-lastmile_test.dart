library;

import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/esf/esf_outbox_store.dart';
import 'package:telepos/domain/esf/esf_models.dart';
import 'package:telepos/domain/esf/esf_provider.dart';
import 'package:telepos/domain/esf/esf_provider_registry.dart';
import 'package:telepos/domain/esf/esf_settings.dart';
import 'package:telepos/domain/ismpt/ismpt_service.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';

import '../support/harness.dart';

EsfSettings _esfEnabled() => EsfSettings(
  operatorType: EsfOperatorType.kgdEsf,
  enabled: true,
  supplierBin: '123456789012',
  supplierName: 'ТОО ТестПОС',
  supplierVatSeries: '12345',
  supplierVatNumber: '0000123',
  isVatPayer: true,
  vatRatePercent: Decimal.fromInt(12),
  b2bOnly: true,
);

class _CapturingEsfProvider implements EsfProvider {
  final List<EsfInvoice> submitted = [];

  @override
  String get id => 'fake_capture';

  @override
  EsfCapabilities get capabilities => EsfCapabilities.none;

  @override
  String? validateConfig(EsfSettings config) => null;

  @override
  Future<EsfResult> submit(EsfInvoice invoice) async {
    submitted.add(invoice);
    return EsfResult.queued();
  }

  @override
  Future<EsfResult> getStatus(String registrationNumber) async =>
      EsfResult.queued();

  @override
  Future<EsfResult> revoke(EsfInvoice invoice, {String? reason}) async =>
      EsfResult.queued();

  @override
  Future<EsfProviderStatus> providerStatus(EsfSettings config) async =>
      EsfProviderStatus.notConfigured();
}

void main() {
  final h = E2eHarness();

  setUpAll(() async {
    await h.setUp(prefs: {'esf_settings_v1': _esfSettingsJson()});
  });

  tearDownAll(() async => h.tearDown());

  Future<void> sell(
    AppDatabase db,
    SaleUseCase saleUseCase, {
    required int receiptNo,
    required int ucode,
    required Decimal qty,
    required Decimal price,
    required int posAccId,
    String? customerBin,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final amount = qty * price;
    await db
        .into(db.sales)
        .insert(
          SalesCompanion(
            receiptNo: drift.Value(receiptNo),
            posId: const drift.Value(1),
            userId: const drift.Value(1),
            amount: drift.Value(amount),
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
    await saleUseCase.perform(
      receiptNo: receiptNo,
      posId: 1,
      amount: amount,
      // Строки чека этот журнал кладёт в базу сам, с уже готовыми ценами:
      // переписывать `perform` нечего. Пустой список — не заглушка, а
      // утверждение «формат уже верен» (задача 9).
      lines: const [],
      payments: [PaymentEntry(kindId: SystemPaymentKindIds.cash, payeeAccountId: posAccId, amount: amount)],
      change: Decimal.zero,
      selectiveOfd: false,
      customerBin: customerBin,
    );
  }

  test('last-mile: a B2B sale enqueues an ЭСФ draft (captured via a fake '
      'provider), a non-B2B sale enqueues none, and BOTH sales complete '
      'regardless; ИС МПТ resolves from DI offline-safe', () async {
    final db = h.db;
    GetIt.I.registerSingleton<AppDatabase>(db);

    final fake = _CapturingEsfProvider();
    GetIt.I.registerSingleton<EsfProviderRegistry>(
      EsfProviderRegistry()..register(EsfOperatorType.kgdEsf, (_) => fake),
    );

    final saleUseCase = GetIt.I<SaleUseCase>();
    final posAccId = (await db.accountDao.findByType(AccountType.pos)).first.id;

    final stockBeforeB2b = (await db.productInfoDao.findByUcode(
      1001,
    ))!.quantity;

    await sell(
      db,
      saleUseCase,
      receiptNo: 5001,
      ucode: 1001,
      qty: Decimal.fromInt(2),
      price: Decimal.fromInt(450),
      posAccId: posAccId,
      customerBin: '987654321098',
    );

    final b2bSale = await db.saleDao.findByKey(5001, 1);
    expect(b2bSale, isNotNull);
    expect(b2bSale!.state, 1, reason: 'sale completed (PENDING_SYNC)');
    expect(b2bSale.customerBin, '987654321098');
    final stockAfterB2b = (await db.productInfoDao.findByUcode(1001))!.quantity;
    expect(stockAfterB2b, stockBeforeB2b! - Decimal.fromInt(2));

    expect(
      fake.submitted,
      hasLength(1),
      reason: 'B2B sale must enqueue exactly one ЭСФ draft',
    );
    final inv = fake.submitted.single;
    expect(
      inv.buyer.binIin,
      '987654321098',
      reason: 'buyer БИН taken from the sale',
    );
    expect(
      inv.supplier.binIin,
      '123456789012',
      reason: 'supplier БИН from settings',
    );
    expect(inv.sourceSaleReceiptNo, 5001);
    expect(inv.sourceSalePosId, 1);
    expect(inv.direction, EsfDirection.outgoing);

    final stockBeforeRetail = (await db.productInfoDao.findByUcode(
      1002,
    ))!.quantity;
    await sell(
      db,
      saleUseCase,
      receiptNo: 5002,
      ucode: 1002,
      qty: Decimal.fromInt(3),
      price: Decimal.fromInt(150),
      posAccId: posAccId,
    );

    final retailSale = await db.saleDao.findByKey(5002, 1);
    expect(retailSale, isNotNull);
    expect(retailSale!.state, 1, reason: 'retail sale completed too');
    final stockAfterRetail = (await db.productInfoDao.findByUcode(
      1002,
    ))!.quantity;
    expect(stockAfterRetail, stockBeforeRetail! - Decimal.fromInt(3));

    expect(
      fake.submitted,
      hasLength(1),
      reason: 'non-B2B sale must NOT enqueue an ЭСФ draft',
    );

    expect(
      GetIt.I.isRegistered<IsMptService>(),
      isTrue,
      reason: 'marking_codes_screen resolves IsMptService from DI',
    );
    final ismpt = GetIt.I<IsMptService>();
    final status = await ismpt.getStatus();
    expect(status, isNotNull);
    expect(GetIt.I.isRegistered<EsfOutboxStore>(), isTrue);
  });
}

String _esfSettingsJson() => jsonEncode(_esfEnabled().toJson());
