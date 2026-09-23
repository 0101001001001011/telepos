import 'package:decimal/decimal.dart';

abstract class CashInOutController {
  Future<CashOperationResult> createInvestment({
    required Decimal amount,
    required int accountId,
    String? note,
  });

  Future<CashOperationResult> createExpense({
    required Decimal amount,
    required int accountId,
    required ExpenseType expenseType,
    String? note,
    int? customFieldItemId,
  });

  Future<CashOperationResult> createDividend({
    required Decimal amount,
    required int accountId,
    String? note,
  });

  Future<CashOperationResult> createInkassaciya({
    required Decimal amount,
    required int fromAccountId,
    int? toAccountId,
    String? note,
  });

  Future<List<CashOperationInfo>> getOperationsForShift(int shiftId);

  Future<CashOperationValidation> validateAmount(Decimal amount);

  Future<int> getPosAccountId();

  // Печати здесь нет намеренно. `printReceipt` жил и тут, и в
  // `CashOperationReceiptService` — двумя почти одинаковыми телами, каждое из
  // которых писало в `PrinterManager` напрямую. Две копии одного правила
  // расходятся молча, а прямая запись — это второй писатель в один принтер
  // (И29) и потерянная квитанция на недоступном принтере. Осталась одна
  // дорога: `CashOperationReceiptService.printReceipt`, и она идёт через
  // очередь.

  /// Здесь лежал ВТОРОЙ потолок суммы, зашитый тем же миллионом, что и
  /// потолок чека. Два числа для одного правила разошлись бы на первой же
  /// правке одного из них; с 2026-09-22 потолок один и он настраивается —
  /// `this_pos_entries.big_amount_limit`, см. `bigAmountLimitOf`.
}

enum CashInOutType { investment, expense, dividend }

enum ExpenseType {
  other,

  smallPurchases,

  salary,

  utilities,

  collection,

  custom,
}

/// Итог кассовой операции.
///
/// # Почему отказ здесь — код, а не текст
///
/// Прежде отказ вёз русскую фразу, собранную в слое данных. Экран её даже
/// не показывал: при `success == false` он просто закрывался
/// (`_close(result)`), и кассир видел ровно то же, что при успехе.
/// Внесение выше потолка **исчезало молча** — измерено 2026-09-22.
class CashOperationResult {
  const CashOperationResult({
    required this.success,
    this.operationId,
    this.refusal,
    this.limit,
    this.errorDetail,
  });

  final bool success;
  final int? operationId;

  /// Причина отказа кодом; `null` — операция прошла.
  final CashAmountRefusal? refusal;

  /// Потолок со знаком валюты, когда отказ именно в нём.
  final String? limit;

  /// Подробность для журнала, когда отказ не про сумму.
  final String? errorDetail;

  factory CashOperationResult.created(int id) =>
      CashOperationResult(success: true, operationId: id);

  factory CashOperationResult.refused(
    CashAmountRefusal refusal, {
    String? limit,
  }) => CashOperationResult(success: false, refusal: refusal, limit: limit);

  factory CashOperationResult.failed(String detail) =>
      CashOperationResult(success: false, errorDetail: detail);
}

class CashOperationInfo {
  const CashOperationInfo({
    required this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    this.note,
    required this.docTime,
    this.expenseType,
    this.customFieldItemId,
  });

  final int id;
  final CashInOutType type;
  final Decimal amount;
  final int accountId;
  final String? note;
  final DateTime docTime;
  final ExpenseType? expenseType;
  final int? customFieldItemId;
}

/// Отказ ввода суммы кассовой операции.
///
/// # Почему код, а не фраза
///
/// До 2026-09-22 здесь лежал готовый русский текст («Сумма должна быть
/// больше 0», «Сумма не может превышать 1000000»), и экран мог только
/// показать его как есть. Кассир с английским интерфейсом прочёл бы
/// русское предложение — если бы экран вообще звал проверку: он её не
/// звал, и верхнего предела у кассовых операций не было вовсе.
///
/// Теперь отказ называется кодом, а слова подбирает экран. Потолок
/// приезжает вместе с кодом — со знаком валюты, собранным кассой.
enum CashAmountRefusal {
  /// Сумма нулевая или отрицательная.
  notPositive,

  /// Сумма выше потолка кассы (`this_pos_entries.big_amount_limit`).
  aboveCeiling,
}

class CashOperationValidation {
  const CashOperationValidation({
    required this.isValid,
    this.refusal,
    this.limit,
  });

  final bool isValid;

  /// Причина отказа — кодом; `null`, когда сумма принята.
  final CashAmountRefusal? refusal;

  /// Потолок со знаком валюты, когда отказ именно в нём.
  final String? limit;

  factory CashOperationValidation.valid() =>
      const CashOperationValidation(isValid: true);

  factory CashOperationValidation.invalid(
    CashAmountRefusal refusal, {
    String? limit,
  }) => CashOperationValidation(isValid: false, refusal: refusal, limit: limit);
}

extension CashInOutTypeExtension on CashInOutType {
  int get index => CashInOutType.values.indexOf(this);

  static CashInOutType fromIndex(int index) {
    if (index < 0 || index >= CashInOutType.values.length) {
      return CashInOutType.investment;
    }
    return CashInOutType.values[index];
  }
}

extension ExpenseTypeExtension on ExpenseType {
  int get index => ExpenseType.values.indexOf(this);

  static ExpenseType fromIndex(int index) {
    if (index < 0 || index >= ExpenseType.values.length) {
      return ExpenseType.other;
    }
    return ExpenseType.values[index];
  }

  // `displayName` здесь БЫЛ и возвращал русские слова. Он шёл двумя
  // дорогами сразу: в выпадающий список формы расхода (на английской кассе
  // кассир выбирал «Зарплату») и в `cash_operations.note`, склеенный с
  // комментарием человека, — то есть в историю, откуда слово уже не
  // перевести. Слово переехало в `presentation/common/utils/
  // cash_operation_label.dart`, род хранится числом (схема v58).

  bool get requiresNote => this == ExpenseType.other;
}
