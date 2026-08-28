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

  static final Decimal maxAmount = Decimal.fromInt(1000000);
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

class CashOperationResult {
  const CashOperationResult({
    required this.success,
    this.operationId,
    this.errorMessage,
  });

  final bool success;
  final int? operationId;
  final String? errorMessage;

  factory CashOperationResult.created(int id) =>
      CashOperationResult(success: true, operationId: id);

  factory CashOperationResult.failed(String message) =>
      CashOperationResult(success: false, errorMessage: message);
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

class CashOperationValidation {
  const CashOperationValidation({required this.isValid, this.errorMessage});

  final bool isValid;
  final String? errorMessage;

  factory CashOperationValidation.valid() =>
      const CashOperationValidation(isValid: true);

  factory CashOperationValidation.invalid(String message) =>
      CashOperationValidation(isValid: false, errorMessage: message);
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

  String get displayName {
    switch (this) {
      case ExpenseType.other:
        return 'Другое';
      case ExpenseType.smallPurchases:
        return 'Закуп мелочей';
      case ExpenseType.salary:
        return 'Зарплата';
      case ExpenseType.utilities:
        return 'Коммунальные';
      case ExpenseType.collection:
        return 'Инкассация';
      case ExpenseType.custom:
        return 'Кастомный';
    }
  }

  bool get requiresNote => this == ExpenseType.other;
}
