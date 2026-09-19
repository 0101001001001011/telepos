/// **Выдача аванса деньгами** — путь, которого в кассе не было вовсе.
///
/// # Что измерено 2026-09-19, прежде чем писать код
///
/// Разведка по всему `lib/`: ни один экран, ни одна операция провода, ни
/// один юзкейс не уменьшал расчётный счёт покупателя ради живых денег.
/// `CustomerPaymentUseCase` умел `execute`, `acceptPrepayment`,
/// `needsDecisionDialog`, `getCustomerBalance` — и ничего про выдачу.
/// Возврат чека, закрытого зачётом, аванс **восстанавливает** и говорит об
/// этом вслух (`RefundUseCaseImpl`, `RefundRoute.advance`: «выдача аванса
/// деньгами — свой документ расчёта с контрагентом»). Документа не было.
///
/// Единственное, чем деньги могли выйти, — «Расход»
/// (`CashInOutControllerImpl.createExpense` → `FiscalService.moneyOut`).
/// Это **служебное изъятие**: счёт покупателя от него не двигается, и у
/// оператора это не возврат расчёта. По смене деньги ушли, документа нет.
///
/// # Три места денег, и каждое проверяется отдельно
///
/// Счёт покупателя, счёт кассы и проводка `cash_operations`. Проба на одно
/// только сальдо покупателя была бы зелёной на выдаче, не тронувшей ящик, —
/// ровно тот класс дефекта, который приём аванса уже ловил 2026-09-18
/// (счёт кассы двигал контроллер экрана, и провод его не звал).
///
/// # Чего эти пробы НЕ доказывают
///
/// Что до выдачи можно дойти кассиру: экрана у неё пока нет, и этого здесь
/// не измеряется (тот же класс дефекта, что `pay.certificateIssue` —
/// написана, охраняется, не вызывается ниоткуда). Названо в отчёте
/// открытым.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/usecases/payment/customer_payment_use_case_impl.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/payment/prepayment_intake.dart';
import 'package:telepos/domain/sale/payment_service.dart'
    show payCustomerUnknownCode, payPrepaymentAccountMissingCode;
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/usecases/payment/customer_payment_use_case.dart';

const _tillAccountId = 11;
const _acquiringAccountId = 12;
const _agentAccountId = 14;
const _customerId = 5;
const _customerWithoutAccountId = 6;

void main() {
  late AppDatabase db;
  late _SpyFiscal fiscal;
  late CustomerPaymentUseCaseImpl useCase;

  Decimal d(String v) => Decimal.parse(v);

  Future<Decimal> balanceOf(int accountId) async =>
      (await db.accountDao.findById(accountId))?.value ?? Decimal.zero;

  Future<void> seedAccount(int id, int type, String name, String value) => db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          id: Value(id),
          type: type,
          name: Value(name),
          value: Value(d(value)),
          visibleToPos: const Value(false),
        ),
      );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    fiscal = _SpyFiscal();

    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            accountId: Value(_tillAccountId),
            acquiringAccountId: Value(_acquiringAccountId),
            cashBoxName: Value('Касса-1'),
          ),
        );
    await seedAccount(_tillAccountId, AccountType.pos, 'Касса', '5000');
    await seedAccount(
      _acquiringAccountId,
      AccountType.customBank,
      'Эквайринг',
      '5000',
    );
    // На счёте покупателя лежит внесённый ранее аванс.
    await seedAccount(
      _agentAccountId,
      AccountType.agentMain,
      'Расчёты с Айгуль',
      '1000',
    );
    await db
        .into(db.agents)
        .insert(
          const AgentsCompanion(
            localId: Value(_customerId),
            name: Value('Айгуль'),
            phone: Value(77015550000),
            mainAccountId: Value(_agentAccountId),
          ),
        );
    await db
        .into(db.agents)
        .insert(
          const AgentsCompanion(
            localId: Value(_customerWithoutAccountId),
            name: Value('Без счёта'),
            phone: Value(77015550001),
          ),
        );
    for (final id in const [
      SystemPaymentKindIds.cash,
      SystemPaymentKindIds.card,
      SystemPaymentKindIds.bonus,
    ]) {
      await db.paymentKindDao.put(SystemPaymentKinds.byId(id));
    }

    useCase = CustomerPaymentUseCaseImpl(
      db: db,
      logger: Talker(settings: TalkerSettings(enabled: false)),
      fiscal: fiscal,
    );
  });

  tearDown(() => db.close());

  Future<CustomerPaymentResult> payOut(
    String amount, {
    int kindId = SystemPaymentKindIds.cash,
    int agentId = _customerId,
    int? intakeOperationId,
  }) => useCase.refundPrepayment(
    agentId: agentId,
    amount: d(amount),
    tenderKindId: kindId,
    intakeOperationId: intakeOperationId,
  );

  group('деньги выходят из кассы и списываются со счёта покупателя', () {
    test('выдача 400 трогает ВСЕ ТРИ места денег', () async {
      final result = await payOut('400');

      expect(result.success, isTrue, reason: result.errorMessage);
      expect(
        await balanceOf(_agentAccountId),
        d('600'),
        reason:
            'аванс, оставшийся 1000 после выдачи, значит, что касса '
            'отдала деньги и продолжает считать их за покупателем',
      );
      expect(
        await balanceOf(_tillAccountId),
        d('4600'),
        reason:
            'ящик не тронут — ровно тот дефект, который приём аванса '
            'уже ловил 2026-09-18',
      );

      final op = await db.select(db.cashOperations).getSingle();
      expect(
        op.type,
        CashInOutType.expense.index,
        reason:
            'приход со знаком минус прибавил бы смене отрицательную '
            'выручку вместо того, чтобы уменьшить её расходом',
      );
      expect(op.amount, d('400'));
      expect(op.kindId, SystemPaymentKindIds.cash);
      expect(op.accountId, _agentAccountId);
      expect(result.newBalance, d('600'));
    });

    test('выдача картой уходит со счёта эквайринга, а не из ящика', () async {
      final result = await payOut('400', kindId: SystemPaymentKindIds.card);

      expect(result.success, isTrue, reason: result.errorMessage);
      expect(await balanceOf(_acquiringAccountId), d('4600'));
      expect(
        await balanceOf(_tillAccountId),
        d('5000'),
        reason:
            'возврат на карту, вынутый из ящика, — это недостача в ящике '
            'на ту же сумму',
      );
    });
  });

  group('названные отказы, и ни один не трогает деньги', () {
    Future<void> expectMoneyUntouched() async {
      expect(await balanceOf(_agentAccountId), d('1000'));
      expect(await balanceOf(_tillAccountId), d('5000'));
      expect(await db.select(db.cashOperations).get(), isEmpty);
    }

    test('аванса меньше, чем выдают — свой код, а не «отказано»', () async {
      final result = await payOut('1500');

      expect(result.success, isFalse);
      expect(
        result.refusalCode,
        prepaymentRefundExceedsBalanceCode,
        reason:
            'это единственная беда выдачи, которую кассир исправляет '
            'сам, не сходя с экрана — убавив сумму',
      );
      await expectMoneyUntouched();
    });

    test('ровно по остатку — можно, и это обратный полюс', () async {
      // Проба выше зелена и у кассы, отказывающей всегда. Эта — граница:
      // выдать ровно то, что лежит, обязано быть можно.
      final result = await payOut('1000');
      expect(result.success, isTrue, reason: result.errorMessage);
      expect(await balanceOf(_agentAccountId), Decimal.zero);
    });

    test('бонусом аванс не выдаётся', () async {
      final result = await payOut('400', kindId: SystemPaymentKindIds.bonus);

      expect(result.success, isFalse);
      expect(result.refusalCode, prepaymentTenderInvalidCode);
      await expectMoneyUntouched();
    });

    test('сумма ноль', () async {
      final result = await payOut('0');
      expect(result.refusalCode, prepaymentAmountInvalidCode);
      await expectMoneyUntouched();
    });

    test('покупателя нет в картотеке', () async {
      final result = await payOut('400', agentId: 999);
      expect(result.refusalCode, payCustomerUnknownCode);
      await expectMoneyUntouched();
    });

    test('у покупателя нет расчётного счёта — аванса на нём не было', () async {
      final result = await payOut('400', agentId: _customerWithoutAccountId);
      expect(result.refusalCode, payPrepaymentAccountMissingCode);
      await expectMoneyUntouched();
    });

    test('у кассы нет счёта выдачи — отказ ДО первой записи', () async {
      await (db.update(db.thisPosEntries)..where((tp) => tp.rId.equals(true)))
          .write(const ThisPosEntriesCompanion(accountId: Value(null)));
      await (db.delete(
        db.accounts,
      )..where((a) => a.id.equals(_tillAccountId))).go();

      final result = await payOut('400');

      expect(result.success, isFalse);
      expect(result.refusalCode, prepaymentTillAccountMissingCode);
      expect(
        await balanceOf(_agentAccountId),
        d('1000'),
        reason: '«выдать нечем» не имеет права стать «выдано наполовину»',
      );
      expect(await db.select(db.cashOperations).get(), isEmpty);
    });
  });

  group('фискальный документ выдачи', () {
    test('уходит возвратом, тем видом оплаты, каким выданы деньги', () async {
      final result = await payOut('400', kindId: SystemPaymentKindIds.card);

      expect(result.fiscalSign, 'ВОЗВРАТ-1');
      expect(result.fiscalError, isNull);
      final call = fiscal.refunds.single;
      expect(
        call.paymentKind,
        FiscalPaymentKind.card,
        reason:
            'аванс, выданный на карту, ушедший оператору наличными, — '
            'тот же дефект, что закрыт v47 на приёме',
      );
      expect(call.amount, d('400'));
      expect(call.positionName, startsWith('Возврат аванса (предоплаты)'));
      expect(
        call.positionName,
        contains('Айгуль'),
        reason: 'оператор обязан видеть, чей аванс возвращён',
      );
      expect(fiscal.prepayments, isEmpty, reason: 'выдача — не приём');
    });

    test('настройка приёма ВЫКЛЮЧЕНА — документа нет, деньги выданы', () async {
      // Главная связка задачи: касса, где приём не фискальный, а выдача
      // фискальная, показала бы оператору возврат денег, которые к нему
      // никогда не приходили.
      await db.thisPosDao.saveOffsetFiscalSettings(
        const FiscalOffsetSettings(fiscalizePrepaymentReceipt: false),
      );

      final result = await payOut('400');

      expect(result.success, isTrue, reason: result.errorMessage);
      expect(fiscal.refunds, isEmpty);
      expect(result.fiscalSign, isNull);
      expect(await balanceOf(_agentAccountId), d('600'));
    });

    test(
      'названный приём едет основанием, неназванный — не выдумывается',
      () async {
        await payOut('100', intakeOperationId: 77);
        expect(fiscal.refunds.single.intakeOperationId, 77);

        fiscal.refunds.clear();
        await payOut('100');
        expect(
          fiscal.refunds.single.intakeOperationId,
          isNull,
          reason:
              'аванс это пул: сходить за последним чеком покупателя самому '
              'значит сослаться на чужой документ',
        );
      },
    );

    test('отказ оператора денег не отменяет', () async {
      fiscal.refuse = true;

      final result = await payOut('400');

      expect(result.success, isTrue, reason: 'деньги уже выданы из ящика');
      expect(result.fiscalSign, isNull);
      expect(
        result.fiscalError,
        isNotNull,
        reason:
            'молчание здесь означало бы «документ есть» — тот же довод, '
            'что у продажи (SaleOutcome.fiscal)',
      );
      expect(await balanceOf(_agentAccountId), d('600'));
    });
  });
}

typedef _RefundCall = ({
  int operationId,
  int? intakeOperationId,
  Decimal amount,
  FiscalPaymentKind paymentKind,
  String positionName,
});

class _SpyFiscal implements FiscalService {
  final List<_RefundCall> refunds = [];
  final List<int> prepayments = [];
  bool refuse = false;

  @override
  Future<bool> isEnabled() async => true;

  @override
  Future<FiscalSettings> currentSettings() async =>
      FiscalSettings(operatorType: FiscalOperatorType.webkassa);

  @override
  Future<FiscalResult> fiscalizePrepayment({
    required int operationId,
    required Decimal amount,
    required FiscalPaymentKind paymentKind,
    required String positionName,
  }) async {
    prepayments.add(operationId);
    return FiscalResult.ok(fiscalSign: 'ПРИЁМ-${prepayments.length}');
  }

  @override
  Future<FiscalResult> fiscalizePrepaymentRefund({
    required int operationId,
    required int? intakeOperationId,
    required Decimal amount,
    required FiscalPaymentKind paymentKind,
    required String positionName,
  }) async {
    refunds.add((
      operationId: operationId,
      intakeOperationId: intakeOperationId,
      amount: amount,
      paymentKind: paymentKind,
      positionName: positionName,
    ));
    if (refuse) return FiscalResult.failure('оператор отказал');
    return FiscalResult.ok(fiscalSign: 'ВОЗВРАТ-${refunds.length}');
  }

  @override
  Future<FiscalResult> fiscalizeSale({
    required int saleReceiptNo,
    required int salePosId,
    required Decimal amount,
    required Decimal cashAmount,
    required Decimal cardAmount,
    required Decimal mobileAmount,
    required Decimal bonusAmount,
    required Decimal offsetAmount,
    required OffsetFiscalLayout offsetLayout,
    required bool excludeCertificatePositions,
    String? customerBin,
  }) async => FiscalResult.notConfigured();

  @override
  Future<FiscalResult> fiscalizeRefund({
    required int refundLocalId,
    required int? originalSaleReceiptNo,
    required Decimal amount,
    required Decimal cashAmount,
    required Decimal cardAmount,
    required Decimal mobileAmount,
    required Decimal bonusAmount,
    required Decimal creditAmount,
    required Decimal offsetAmount,
    required OffsetFiscalLayout offsetLayout,
    required bool excludeCertificatePositions,
  }) async => FiscalResult.notConfigured();

  @override
  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req) async =>
      FiscalResult.notConfigured();

  @override
  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req) async =>
      FiscalResult.notConfigured();

  @override
  Future<FiscalResult> moneyIn({
    required Decimal amount,
    String? comment,
    String? idempotencyKey,
  }) async => FiscalResult.notConfigured();

  @override
  Future<FiscalResult> moneyOut({
    required Decimal amount,
    String? comment,
    String? idempotencyKey,
  }) async => FiscalResult.notConfigured();

  @override
  Future<FiscalResult> openShift() async => FiscalResult.notConfigured();

  @override
  Future<FiscalReportResult> closeShift() async =>
      FiscalReportResult.failure('нет');

  @override
  Future<FiscalReportResult> xReport() async =>
      FiscalReportResult.failure('нет');

  @override
  Future<FiscalResult> correction(FiscalCorrectionRequest req) async =>
      FiscalResult.notConfigured();

  @override
  Future<FiscalStatus> status() async => FiscalStatus.notConfigured();
}
