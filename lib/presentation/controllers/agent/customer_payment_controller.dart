import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/domain/usecases/payment/customer_payment_use_case.dart';
import 'package:telepos/presentation/controllers/agent/agent_controller.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';

@immutable
class CustomerPaymentOutcome {
  const CustomerPaymentOutcome({
    required this.success,
    this.newAgentBalance,
    this.errorMessage,
    this.fiscalError,
  });

  final bool success;

  final Decimal? newAgentBalance;

  final String? errorMessage;

  /// Почему фискального чека нет, хотя он был нужен. Деньги при этом
  /// **двинулись**: отказ оператора денег не отменяет — тот же довод, что у
  /// продажи (`SaleOutcome.fiscal`) и у приёма аванса.
  ///
  /// Появилось вместе с выдачей аванса (дыра 2 ревизии 2026-09-19): у неё
  /// исход «деньги отданы, документа нет» достижим и обязан быть назван
  /// словами, а не спрятан в успехе. Приём эту беду до сих пор показывает
  /// только в браузере, где отказ едет кодом по проводу; кассовый диалог
  /// приёма молчит — названо, не чинится этой работой.
  final String? fiscalError;
}

class CustomerPaymentController
    extends Notifier<AsyncValue<CustomerPaymentOutcome?>> {
  @override
  AsyncValue<CustomerPaymentOutcome?> build() => const AsyncData(null);

  CustomerPaymentUseCase get _useCase => GetIt.I<CustomerPaymentUseCase>();

  /// [tenderKindId] — чем приняты деньги (`SystemPaymentKindIds.cash` или
  /// `.card`). Хранится у операции и решает тип оплаты чека аванса.
  ///
  /// **Счёт кассы этот контроллер больше не двигает** (2026-09-18): шаг
  /// переехал внутрь юзкейса, к остальным деньгам приёма. Разбор — в
  /// докстринге `CustomerPaymentUseCaseImpl._creditTenderAccount`; коротко:
  /// операция провода контроллера не зовёт, и оставь шаг здесь — аванс,
  /// принятый с планшета, не попал бы в кассу вовсе.
  Future<CustomerPaymentOutcome> record({
    required int agentId,
    required Decimal amount,
    required int tenderKindId,
    CustomerPaymentDecision decision = CustomerPaymentDecision.investment,
    String? note,
  }) async {
    state = const AsyncLoading();

    final result = await _useCase.execute(
      agentId: agentId,
      amount: amount,
      decision: decision,
      tenderKindId: tenderKindId,
      note: note,
    );

    if (!result.success) {
      final outcome = CustomerPaymentOutcome(
        success: false,
        errorMessage: result.errorMessage,
      );
      state = AsyncData(outcome);
      return outcome;
    }

    ref.invalidate(shiftControllerProvider);
    ref.invalidate(agentSearchProvider);

    final outcome = CustomerPaymentOutcome(
      success: true,
      newAgentBalance: result.newBalance,
    );
    state = AsyncData(outcome);
    return outcome;
  }

  /// Выдать аванс покупателю деньгами — дыра 2 ревизии 2026-09-19.
  ///
  /// # Почему в этом контроллере, а не в своём
  ///
  /// Потому что это **та же работа**, повёрнутая другой стороной: тот же
  /// расчётный счёт покупателя, то же движение по нему, тот же юзкейс и та
  /// же настройка фискализации. Свой контроллер рядом означал бы два места,
  /// где после движения денег обновляют смену и картотеку, — и второе
  /// разошлось бы с первым молча, ровно как разошлись бы две раскладки
  /// одного возврата.
  ///
  /// Обновляются те же два провайдера и по тем же причинам: выдача
  /// уменьшает выручку смены расходной проводкой, а сальдо покупателя в
  /// картотеке после неё другое.
  ///
  /// # Чего этот метод НЕ делает
  ///
  /// Не спрашивает права: его спрашивают маршрут (`op.creditRepay` в карте
  /// `PermissionKeys`) и экран перед вызовом. Контроллер — переводчик между
  /// экраном и юзкейсом, и третья проверка здесь была бы третьим ответом на
  /// один вопрос.
  ///
  /// Не решает, хватает ли наличных в ящике: этого не знает и юзкейс
  /// (докстринг `CustomerPaymentUseCase.refundPrepayment`).
  Future<CustomerPaymentOutcome> refund({
    required int agentId,
    required Decimal amount,
    required int tenderKindId,
    int? intakeOperationId,
    String? note,
  }) async {
    state = const AsyncLoading();

    final result = await _useCase.refundPrepayment(
      agentId: agentId,
      amount: amount,
      tenderKindId: tenderKindId,
      intakeOperationId: intakeOperationId,
      note: note,
    );

    if (!result.success) {
      final outcome = CustomerPaymentOutcome(
        success: false,
        errorMessage: result.errorMessage,
      );
      state = AsyncData(outcome);
      return outcome;
    }

    ref.invalidate(shiftControllerProvider);
    ref.invalidate(agentSearchProvider);

    final outcome = CustomerPaymentOutcome(
      success: true,
      newAgentBalance: result.newBalance,
      // Беда фискализации едет **вместе с успехом**, а не вместо него:
      // деньги покупателю отданы, и назвать это неудачей значило бы
      // предложить кассиру выдать их второй раз.
      fiscalError: result.fiscalError,
    );
    state = AsyncData(outcome);
    return outcome;
  }

  /// Сколько аванса лежит на счёте покупателя.
  ///
  /// Спрашивается **у кассы**, а не приходит параметром экрана: карточка
  /// контрагента знает сальдо на момент своего открытия, а между открытием
  /// и выдачей стоит второй кассир. Число, по которому кассир принимает
  /// решение, обязано быть свежим; заслон от гонки при этом всё равно не
  /// здесь, а в условной записи внутри транзакции выдачи.
  Future<Decimal> balanceOf(int agentId) =>
      _useCase.getCustomerBalance(agentId);
}

final customerPaymentControllerProvider =
    NotifierProvider<
      CustomerPaymentController,
      AsyncValue<CustomerPaymentOutcome?>
    >(CustomerPaymentController.new);
