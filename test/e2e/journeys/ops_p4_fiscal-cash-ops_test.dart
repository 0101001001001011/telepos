library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/usecases/cash_operation/cash_in_out_controller_impl.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';

import '../support/harness.dart';

class _FakeFiscalService implements FiscalService {
  _FakeFiscalService({this.throwOnCall = false});

  final bool throwOnCall;

  final List<({Decimal amount, String? comment, String? idempotencyKey})>
  moneyInCalls = [];
  final List<({Decimal amount, String? comment, String? idempotencyKey})>
  moneyOutCalls = [];

  @override
  Future<FiscalResult> moneyIn({
    required Decimal amount,
    String? comment,
    String? idempotencyKey,
  }) async {
    if (throwOnCall) throw Exception('OFD offline');
    moneyInCalls.add((
      amount: amount,
      comment: comment,
      idempotencyKey: idempotencyKey,
    ));
    return FiscalResult.queued();
  }

  @override
  Future<FiscalResult> moneyOut({
    required Decimal amount,
    String? comment,
    String? idempotencyKey,
  }) async {
    if (throwOnCall) throw Exception('OFD offline');
    moneyOutCalls.add((
      amount: amount,
      comment: comment,
      idempotencyKey: idempotencyKey,
    ));
    return FiscalResult.queued();
  }

  @override
  Future<FiscalSettings> currentSettings() async => FiscalSettings.disabled();
  @override
  Future<bool> isEnabled() async => true;
  @override
  Future<FiscalResult> fiscalizeSale({
    required int saleReceiptNo,
    required int salePosId,
    required Decimal amount,
    required Decimal cashAmount,
    required Decimal cardAmount,
    String? customerBin,
  }) => throw UnimplementedError();
  @override
  Future<FiscalResult> fiscalizeRefund({
    required int refundLocalId,
    required int? originalSaleReceiptNo,
    required Decimal amount,
  }) => throw UnimplementedError();
  @override
  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req) =>
      throw UnimplementedError();
  @override
  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req) =>
      throw UnimplementedError();
  @override
  Future<FiscalResult> openShift() => throw UnimplementedError();
  @override
  Future<FiscalReportResult> closeShift() => throw UnimplementedError();
  @override
  Future<FiscalReportResult> xReport() => throw UnimplementedError();
  @override
  Future<FiscalResult> correction(FiscalCorrectionRequest req) =>
      throw UnimplementedError();
  @override
  Future<FiscalStatus> status() async => FiscalStatus.notConfigured();
}

void main() {
  final h = E2eHarness();

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDownAll(() => h.tearDown());

  setUp(() async {
    await h.db.delete(h.db.cashOperationCustomFields).go();
    await h.db.delete(h.db.cashOperations).go();
    await h.db.delete(h.db.shifts).go();
  });

  Future<void> drainFiscal() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<int> posAccountId() async {
    final pos = await h.db.accountDao.findByType(AccountType.pos);
    expect(pos, isNotEmpty, reason: 'harness seeds a POS account');
    return pos.first.id;
  }

  Future<Decimal> balanceOf(int accId) async =>
      (await h.db.accountDao.findById(accId))?.value ?? Decimal.zero;

  test('cash-in (внесение) calls FiscalService.moneyIn with the exact Decimal '
      'amount AND the balance still updates while fiscalization is queued '
      '(offline)', () async {
    final fake = _FakeFiscalService();
    final controller = CashInOutControllerImpl(h.db, fiscalService: fake);

    final posId = await posAccountId();
    final opening = await balanceOf(posId);

    final result = await controller.createInvestment(
      amount: d('1000'),
      accountId: posId,
      note: 'Размен утром',
    );
    await drainFiscal();

    expect(result.success, isTrue, reason: 'cash-in must succeed locally');
    expect(result.operationId, isNotNull);

    final after = await balanceOf(posId);
    expect(
      after - opening,
      d('1000'),
      reason: 'внесение increases the cash balance by exactly the amount',
    );

    expect(
      fake.moneyInCalls.length,
      1,
      reason: 'внесение must be reported to ОФД via moneyIn',
    );
    expect(
      fake.moneyInCalls.single.amount,
      d('1000'),
      reason: 'fiscal amount must equal the cash-in amount (Decimal-exact)',
    );
    expect(
      fake.moneyOutCalls,
      isEmpty,
      reason: 'a cash-IN must not trigger moneyOut',
    );

    expect(
      fake.moneyInCalls.single.idempotencyKey,
      'cashop:${result.operationId}',
    );
  });

  test(
    'изъятие (dividend) calls FiscalService.moneyOut and decreases balance',
    () async {
      final fake = _FakeFiscalService();
      final controller = CashInOutControllerImpl(h.db, fiscalService: fake);

      final posId = await posAccountId();
      await h.db.accountDao.updateBalance(posId, d('5000'));
      final opening = await balanceOf(posId);

      final result = await controller.createDividend(
        amount: d('300'),
        accountId: posId,
      );
      await drainFiscal();

      expect(result.success, isTrue);
      expect(
        await balanceOf(posId) - opening,
        d('-300'),
        reason: 'изъятие decreases the cash balance by exactly the amount',
      );

      expect(
        fake.moneyOutCalls.length,
        1,
        reason: 'изъятие must be reported to ОФД via moneyOut',
      );
      expect(fake.moneyOutCalls.single.amount, d('300'));
      expect(
        fake.moneyInCalls,
        isEmpty,
        reason: 'a cash-OUT must not trigger moneyIn',
      );
    },
  );

  test('инкассация calls FiscalService.moneyOut (служебный расход) and the '
      'inter-account transfer still happens', () async {
    final fake = _FakeFiscalService();
    final controller = CashInOutControllerImpl(h.db, fiscalService: fake);

    final posId = await posAccountId();
    await h.db.accountDao.updateBalance(posId, d('10000'));
    final bank = await h.db.accountDao.findByType(AccountType.customBank);
    expect(bank, isNotEmpty, reason: 'harness seeds a bank/acquiring account');
    final bankId = bank.first.id;
    final bankOpening = await balanceOf(bankId);

    final result = await controller.createInkassaciya(
      amount: d('4000'),
      fromAccountId: posId,
      toAccountId: bankId,
    );
    await drainFiscal();

    expect(result.success, isTrue);
    expect(await balanceOf(posId), d('6000'));
    expect(await balanceOf(bankId) - bankOpening, d('4000'));

    expect(
      fake.moneyOutCalls.length,
      1,
      reason: 'инкассация is a служебный расход -> moneyOut',
    );
    expect(fake.moneyOutCalls.single.amount, d('4000'));
  });

  test('OFFLINE-SAFE: a FiscalService that THROWS never breaks the cash '
      'operation — balance still updates and the op still succeeds', () async {
    final throwing = _FakeFiscalService(throwOnCall: true);
    final controller = CashInOutControllerImpl(h.db, fiscalService: throwing);

    final posId = await posAccountId();
    final opening = await balanceOf(posId);

    final result = await controller.createInvestment(
      amount: d('750'),
      accountId: posId,
    );
    await drainFiscal();

    expect(
      result.success,
      isTrue,
      reason: 'fiscal errors must NOT fail the local cash operation',
    );
    expect(
      await balanceOf(posId) - opening,
      d('750'),
      reason: 'the balance updates even when fiscalization throws (offline)',
    );
  });
}
