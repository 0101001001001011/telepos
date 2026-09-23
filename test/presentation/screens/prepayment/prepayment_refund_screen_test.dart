import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/payment/prepayment_intake.dart';
import 'package:telepos/domain/usecases/payment/customer_payment_use_case.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/screens/prepayment/prepayment_refund_screen.dart';

import '../../../helpers/mock_providers.dart';

/// Экран выдачи аванса — **дыра 2 ревизии 2026-09-19**.
///
/// # Что именно утверждается
///
/// Всё — о **вызове выдачи**: состоялся ли он, с какой суммой и каким
/// типом, чем выдано, и не состоялся ли там, где права нет. Юзкейс
/// `CustomerPaymentUseCase.refundPrepayment` был написан целиком за день до
/// этого экрана и не звался ни одной строкой продукта; проба, проверяющая
/// только отрисовку, оставила бы ровно эту дыру открытой второй раз.
///
/// # Чем каждая проба краснеет (диверсии проведены)
///
/// - «без права выдача не зовётся» — снять проверку права в `_submit()`:
///   выдача проходит, отказа на экране нет.
/// - «сумма едет `Decimal`» — разобрать сумму `double`: тип довода
///   перестаёт быть `Decimal`, третий знак теряется.
/// - «отказ кассы показан словами» — проглотить `errorMessage`: текст
///   причины на экране не находится.
/// - «беда фискализации не выдаётся за неудачу» — показать `fiscalError`
///   как ошибку: ключ успеха исчезает, и кассир выдаёт деньги второй раз.
/// - «остаток спрашивается у кассы» — брать остаток параметром экрана:
///   `balances` пуст.
///
/// # Чего эти пробы НЕ доказывают
///
/// - **Что счёт покупателя уменьшился.** Здесь поддельный юзкейс; запись,
///   условную запись и проводку проверяет `prepayment_refund_test.dart`.
/// - **Что в ящике были наличные.** Этого не знает и юзкейс.
/// - **Что выдача закрыта правом на кассе по-настоящему** — проверка живёт
///   у вызывающего, у юзкейса сеанса нет.
void main() {
  late _FakeUseCase useCase;

  setUp(() {
    installLogger(Talker());
    useCase = _FakeUseCase();
    GetIt.I.registerSingleton<CustomerPaymentUseCase>(useCase);
  });

  tearDown(GetIt.I.reset);

  Future<void> pump(
    WidgetTester tester, {
    required Set<String> permissions,
  }) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStateProvider.overrideWith(
            () => MockAppStateNotifier(
              AppState(permissions: permissions, userId: 3),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('ru')],
          locale: Locale('ru'),
          home: PrepaymentRefundScreen(agentLocalId: 5, agentName: 'Иванов'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const allowed = {PermissionKeys.navAgent, PermissionKeys.opCreditRepay};

  testWidgets(
    'без права op.creditRepay кнопка на месте, но выдача не зовётся вовсе '
    'и причина названа',
    (tester) async {
      await pump(tester, permissions: {PermissionKeys.navAgent});

      await tester.enterText(
        find.byKey(const Key('prepayment_refund_amount')),
        '300',
      );
      await tester.tap(find.byKey(const Key('prepayment_refund_submit')));
      await tester.pumpAndSettle();

      expect(
        useCase.refunds,
        isEmpty,
        reason:
            'выдача выпускает деньги из кассы; открытая кнопка права на это '
            'не даёт (I162)',
      );
      expect(find.byKey(const Key('prepayment_refund_error')), findsOneWidget);
    },
  );

  testWidgets('остаток аванса спрашивается у кассы, а не приходит с экрана', (
    tester,
  ) async {
    await pump(tester, permissions: allowed);

    expect(
      useCase.balances,
      [5],
      reason:
          'карточка знает сальдо на момент открытия, а между открытием и '
          'выдачей стоит второй кассир',
    );
    expect(find.byKey(const Key('prepayment_refund_balance')), findsOneWidget);
  });

  testWidgets('с правом выдача зовётся, и сумма едет Decimal, а не double', (
    tester,
  ) async {
    await pump(tester, permissions: allowed);

    // Третий знак значащий (P18,S3, I159): `1200.005` в двойной точности
    // не представим точно, и подмена типа была бы видна здесь.
    await tester.enterText(
      find.byKey(const Key('prepayment_refund_amount')),
      '1200.005',
    );
    await tester.tap(find.byKey(const Key('prepayment_refund_submit')));
    await tester.pumpAndSettle();

    expect(useCase.refunds, hasLength(1));
    expect(useCase.refunds.single.agentId, 5);
    expect(useCase.refunds.single.amount, Decimal.parse('1200.005'));
    expect(
      useCase.refunds.single.tenderKindId,
      SystemPaymentKindIds.cash,
      reason: 'умолчание — наличные, тот же выбор, что у приёма',
    );
    expect(find.byKey(const Key('prepayment_refund_done')), findsOneWidget);
  });

  testWidgets('вид оплаты — тот, что выбран кассиром', (tester) async {
    await pump(tester, permissions: allowed);

    await tester.enterText(
      find.byKey(const Key('prepayment_refund_amount')),
      '100',
    );
    await tester.tap(find.text('Карта'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('prepayment_refund_submit')));
    await tester.pumpAndSettle();

    expect(
      useCase.refunds.single.tenderKindId,
      SystemPaymentKindIds.card,
      reason:
          'аванс, принятый картой и выданный наличными, разошёлся бы с '
          'ящиком и с документом оператора',
    );
  });

  testWidgets('нулевая сумма до кассы не доходит', (tester) async {
    await pump(tester, permissions: allowed);

    await tester.enterText(
      find.byKey(const Key('prepayment_refund_amount')),
      '0',
    );
    await tester.tap(find.byKey(const Key('prepayment_refund_submit')));
    await tester.pumpAndSettle();

    expect(useCase.refunds, isEmpty);
    expect(find.byKey(const Key('prepayment_refund_error')), findsOneWidget);
  });

  testWidgets('отказ кассы («аванса столько нет») показан словами', (
    tester,
  ) async {
    useCase.failWith = 'На счёте покупателя нет такой суммы аванса';
    await pump(tester, permissions: allowed);

    await tester.enterText(
      find.byKey(const Key('prepayment_refund_amount')),
      '9000',
    );
    await tester.tap(find.byKey(const Key('prepayment_refund_submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('prepayment_refund_done')), findsNothing);
    expect(
      find.textContaining('нет такой суммы аванса'),
      findsOneWidget,
      reason:
          'предел сторожит условная запись внутри транзакции, а не экран; '
          'её отказ обязан дойти до кассира словами',
    );
  });

  testWidgets(
    'беда фискализации не выдаётся за неудачу выдачи: деньги отданы, и об '
    'этом сказано отдельно',
    (tester) async {
      useCase.fiscalError = 'оператор недоступен';
      await pump(tester, permissions: allowed);

      await tester.enterText(
        find.byKey(const Key('prepayment_refund_amount')),
        '300',
      );
      await tester.tap(find.byKey(const Key('prepayment_refund_submit')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('prepayment_refund_done')),
        findsOneWidget,
        reason:
            'отказ оператора денег не отменяет — показать это неудачей '
            'значило бы предложить кассиру выдать их второй раз',
      );
      expect(
        find.byKey(const Key('prepayment_refund_fiscal_warning')),
        findsOneWidget,
      );
    },
  );
}

/// Поддельный юзкейс: помнит доводы вызовов, умеет отказать и умеет
/// ответить успехом без документа.
class _FakeUseCase implements CustomerPaymentUseCase {
  final List<({int agentId, Decimal amount, int tenderKindId})> refunds = [];
  final List<int> balances = [];

  String? failWith;
  String? fiscalError;

  @override
  Future<CustomerPaymentResult> refundPrepayment({
    required int agentId,
    required Decimal amount,
    required int tenderKindId,
    int? intakeOperationId,
    String? note,
    // Ключ повтора — довод контракта с 2026-09-18. Кассовый экран его не
    // кладёт и класть не должен: кассир стоит у ящика и видит исход глазами
    // (разбор — в докстринге `CustomerPaymentUseCase.refundPrepayment`).
    // Подделка обязана повторить подпись целиком, иначе она перестала бы
    // быть этим контрактом.
    String? refundKey,
  }) async {
    final failure = failWith;
    if (failure != null) return CustomerPaymentResult.failed(failure);
    refunds.add((agentId: agentId, amount: amount, tenderKindId: tenderKindId));
    return CustomerPaymentResult.created(
      transactionId: 1,
      newBalance: Decimal.fromInt(700),
      fiscalError: fiscalError,
    );
  }

  /// Выдача **по проводу** — не эта проба.
  ///
  /// Контракт `PrepaymentRefundService` юзкейс объявляет с 2026-09-18, и
  /// подделка обязана его закрыть. Отказ, а не тихий успех: проба, случайно
  /// задевшая провод на кассовом экране, обязана упасть с именем метода.
  @override
  Future<PrepaymentRefundOutcome> payOutPrepayment(
    PrepaymentRefundRequest ask,
  ) async => throw UnimplementedError('выдача по проводу — не эта проба');

  @override
  Future<Decimal> getCustomerBalance(int agentId) async {
    balances.add(agentId);
    return Decimal.fromInt(1000);
  }

  @override
  Future<CustomerPaymentResult> execute({
    required int agentId,
    required Decimal amount,
    required CustomerPaymentDecision decision,
    required int tenderKindId,
    String? note,
    String? intakeKey,
  }) async => CustomerPaymentResult.failed('не проверяется этой пробой');

  @override
  Future<bool> needsDecisionDialog(int agentId) async => false;

  @override
  Future<PrepaymentIntakeOutcome> acceptPrepayment(
    PrepaymentIntakeRequest ask,
  ) async => throw UnimplementedError('не проверяется этой пробой');
}
