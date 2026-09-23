import 'package:decimal/decimal.dart';

import 'package:telepos/domain/payment/prepayment_intake.dart';

/// Приём денег от покупателя на его счёт.
///
/// # Почему он же и [PrepaymentIntakeService]
///
/// Требование заказчика 2026-09-18: приём аванса обязан работать и в
/// браузерном терминале. Операция провода не имеет права заводить **второй**
/// путь к деньгам — значит её обработчик обязан звать ровно то, что зовёт
/// кассовый диалог, то есть этот юзкейс.
///
/// Наследование контракта, а не отдельный переходник рядом, выбрано затем,
/// чтобы `GetIt.I<CustomerPaymentUseCase>()` **был** [PrepaymentIntakeService]
/// без приведения типов: `lib/main.dart` отдаёт кассе тот же синглтон, что
/// стоит под экраном, и никакой строки регистрации сверх уже имеющейся не
/// нужно. Переходник рядом отличался бы от этого только тем, что его можно
/// забыть зарегистрировать.
///
/// # И он же [PrepaymentRefundService] — решение заказчика 2026-09-18
///
/// «В браузере должно работать то же, что в приложении». Выдача аванса
/// деньгами жила только кассовым экраном; операция провода
/// `pay.prepaymentRefund` обязана звать **ровно то же**, что зовёт он, —
/// иначе у денег, выходящих из кассы, стало бы два пути с разными
/// правилами. Тем же наследованием и по тому же доводу, что у приёма.
abstract class CustomerPaymentUseCase
    implements PrepaymentIntakeService, PrepaymentRefundService {
  /// Принять деньги от покупателя на его счёт.
  ///
  /// [tenderKindId] — **чем приняты деньги**: вид оплаты рода
  /// `PaymentSettlement.tender` (наличные, карта, QR). Обязателен: до v47
  /// приём не хранил вида, и аванс, принятый картой, уезжал оператору
  /// наличными (решение заказчика 2026-09-14, п.4).
  ///
  /// [intakeKey] — ключ заявки, по которому касса узнаёт **повтор** той же
  /// заявки (`PrepaymentIntakeRequest.key`). Необязателен, и это не
  /// поблажка: у кассового диалога заявки нет вовсе — кассир стоит перед
  /// ящиком, видит исход своими глазами и повторить «вслепую» не может.
  /// Ключ рождается там, где между кассиром и деньгами лежит провод,
  /// способный проглотить ответ; там он и обязателен
  /// ([PrepaymentIntakeService.acceptPrepayment] без него отказывает).
  Future<CustomerPaymentResult> execute({
    required int agentId,
    required Decimal amount,
    required CustomerPaymentDecision decision,
    required int tenderKindId,
    String? note,
    String? intakeKey,
  });

  /// **Выдать аванс обратно деньгами** — дыра, найденная ревизией
  /// 2026-09-19.
  ///
  /// # Что измерено, и почему метод новый, а не починка старого
  ///
  /// Пути выдачи в кассе не было **вовсе**. Разведка 2026-09-19 по всему
  /// `lib/`: ни один экран, ни одна операция провода, ни один юзкейс не
  /// уменьшал расчётный счёт покупателя ради живых денег. Возврат чека,
  /// закрытого зачётом, аванс **восстанавливает**, а не выдаёт, и говорит
  /// об этом вслух (`RefundUseCaseImpl`, `RefundRoute.advance`: «выдача
  /// аванса деньгами — свой документ расчёта с контрагентом»). Этого
  /// документа не существовало.
  ///
  /// Единственное, чем деньги могли выйти из кассы, — «Расход»
  /// (`CashInOutController.createExpense`). Это **служебное изъятие**:
  /// оператору оно уезжает `moneyOut`, выручку смены не уменьшает,
  /// возвратом расчёта не является, и счёт покупателя от него не
  /// двигается — аванс остаётся числиться за кассой. Отсюда и слова
  /// заказчика: по смене деньги ушли, у оператора документа нет.
  ///
  /// # Что делает этот метод
  ///
  /// Ровно зеркало [execute], одной транзакцией: уменьшает расчётный счёт
  /// покупателя **условной записью** (`AccountDao.claimCredit` — между
  /// чтением остатка и выдачей помещается второй кассир), пишет проводку
  /// `cash_operations` рода «расход» с видом оплаты, снимает деньги со
  /// счёта кассы и просит фискальный **возврат**
  /// (`FiscalService.fiscalizePrepaymentRefund`).
  ///
  /// [intakeOperationId] — проводка приёма, чей чек станет основанием
  /// возврата, если кассир её назвал. `null` значит «не назван», а не «не
  /// было»: аванс это пул, и сходить за последним чеком покупателя самому
  /// значило бы сослаться на чужой документ.
  ///
  /// # Настройка одна на приём и на выдачу
  ///
  /// `FiscalOffsetSettings.fiscalizePrepaymentReceipt`. Касса, где приём
  /// не фискальный, а выдача фискальная, показала бы оператору возврат
  /// денег, которые к нему никогда не приходили.
  ///
  /// [refundKey] — ключ заявки, по которому касса узнаёт **повтор** той же
  /// выдачи (`PrepaymentRefundRequest.key`). Необязателен ровно тем же
  /// доводом, что [intakeKey] у [execute]: у кассового экрана заявки нет
  /// вовсе — кассир стоит перед ящиком и видит исход глазами. Ключ нужен
  /// там, где между кассиром и деньгами лежит провод, способный проглотить
  /// ответ, — и там он обязателен
  /// ([PrepaymentRefundService.payOutPrepayment] без него отказывает).
  ///
  /// До 2026-09-18 этого довода здесь не было, и его отсутствие было
  /// названо открытым вопросом словами «появится провод — понадобится
  /// ключ». Провод появился, ключ заведён **до** того, как операция
  /// поехала.
  ///
  /// # Чего этот метод НЕ делает
  ///
  /// Не спрашивает, хватает ли **наличных в ящике**: он знает сальдо
  /// счёта приёма, а не содержимое ящика, и сторожа на это в кассе нет ни
  /// у одной выдачи денег.
  Future<CustomerPaymentResult> refundPrepayment({
    required int agentId,
    required Decimal amount,
    required int tenderKindId,
    int? intakeOperationId,
    String? note,
    String? refundKey,
  });

  Future<bool> needsDecisionDialog(int agentId);

  Future<Decimal> getCustomerBalance(int agentId);
}

enum CustomerPaymentDecision { investment, deposit }

class CustomerPaymentResult {
  const CustomerPaymentResult({
    required this.success,
    this.transactionId,
    this.newBalance,
    this.errorMessage,
    this.refusalCode,
    this.fiscalSign,
    this.fiscalError,
  });

  final bool success;
  final int? transactionId;
  final Decimal? newBalance;
  final String? errorMessage;

  /// Код отказа — для тех, кому нужна **причина**, а не фраза.
  ///
  /// [errorMessage] написан по-русски внутри кассы и годится журналу и
  /// кассовому диалогу (тот всё равно показывает свою фразу из словаря).
  /// Браузерному терминалу нужен код: отказ уезжает к нему по проводу
  /// значением (I144), и фразу на своём языке он берёт словарём по коду.
  /// Коды объявлены в `lib/domain/payment/prepayment_intake.dart`.
  ///
  /// `null` при неудаче значит «причина не названа» — вызывающий подставит
  /// [prepaymentIntakeFailedCode]. Отдельный код на каждый случай не
  /// заводится потому, что не каждый случай кассир может исправить.
  final String? refusalCode;

  /// Фискальный признак чека приёма аванса; `null` — чека не было.
  final String? fiscalSign;

  /// Почему чек приёма аванса не выписан, хотя был нужен. Деньги при этом
  /// приняты: отказ оператора денег не отменяет — тот же довод, что у
  /// продажи (`SaleOutcome.fiscal`).
  final String? fiscalError;

  factory CustomerPaymentResult.created({
    required int transactionId,
    required Decimal newBalance,
    String? fiscalSign,
    String? fiscalError,
  }) => CustomerPaymentResult(
    success: true,
    transactionId: transactionId,
    newBalance: newBalance,
    fiscalSign: fiscalSign,
    fiscalError: fiscalError,
  );

  factory CustomerPaymentResult.failed(String message, {String? code}) =>
      CustomerPaymentResult(
        success: false,
        errorMessage: message,
        refusalCode: code,
      );
}

extension CustomerPaymentDecisionExtension on CustomerPaymentDecision {
  // `displayName` и `description` здесь БЫЛИ и возвращали русские
  // слова. `description` не спрашивал никто; `displayName` уезжал в
  // `cash_operations.note` — то есть слово для человека писалось в
  // историю. Род операции виден по самой строке (счёт покупателя,
  // вид оплаты), а слово, если понадобится, выбирается при показе.

}
