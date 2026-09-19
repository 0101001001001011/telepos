import 'package:decimal/decimal.dart';

/// Бонусы покупателя.
///
/// # Чего здесь больше нет — и почему это удаление, а не потеря
///
/// **`deductBonuses`** списывала бонусы своим путём: сама проверяла остаток,
/// сама писала новый. Вызывающих в продукте у неё не было ни одного —
/// списание в кассе идёт строкой `Payments` на бонусный счёт, а потолок
/// («не больше остатка», «не больше суммы чека») стоит в
/// `LocalPaymentService._plan`, где о чеке известно. То есть это был второй
/// способ двинуть те же деньги, с собственной копией правила остатка, —
/// ровно то, что задача 13 из дерева убирает. Удалён вместе со своим
/// [BonusDeductResult].
///
/// **`cancelTransaction`** была пустым `return;` и не вызывалась ниоткуда.
/// Отмену начисления делает `BonusEntryDao.reverseForRefund` — журналом, а
/// не пересчётом по нынешней ставке.
abstract class BonusService {
  Future<BonusBalance> getBonusBalance(int phone);

  Future<BonusAccrualResult> accrualBonuses({
    required int phone,
    required Decimal saleAmount,
    required int saleReceiptNo,
  });
}

class BonusBalance {
  const BonusBalance({
    required this.phone,
    required this.balance,
    this.name,
    this.cardNumber,
  });

  final int phone;
  final Decimal balance;
  final String? name;
  final String? cardNumber;
}

class BonusAccrualResult {
  const BonusAccrualResult({
    required this.success,
    required this.transactionId,
    required this.accruedAmount,
    required this.newBalance,
    this.errorMessage,
  });

  final bool success;
  final String transactionId;
  final Decimal accruedAmount;
  final Decimal newBalance;
  final String? errorMessage;
}

class NoInternetConnectionException implements Exception {
  const NoInternetConnectionException([
    this.message = 'Нет подключения к интернету',
  ]);

  final String message;

  @override
  String toString() => 'NoInternetConnectionException: $message';
}
