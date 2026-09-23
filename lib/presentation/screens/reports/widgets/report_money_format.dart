import 'package:decimal/decimal.dart';
import 'package:telepos/presentation/common/utils/till_money.dart';

class ReportMoney {
  ReportMoney._();

  static String compact(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }

  static String full(Decimal amount) {
    final str = amount.round(scale: 0).toBigInt().toString();
    final negative = str.startsWith('-');
    final digits = negative ? str.substring(1) : str;
    final buffer = StringBuffer();
    var count = 0;
    for (var i = digits.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(digits[i]);
      count++;
    }
    final grouped = buffer.toString().split('').reversed.join();
    return negative ? '-$grouped' : grouped;
  }

  /// Сумма со знаком валюты ЭТОЙ кассы.
  ///
  /// Заведено 2026-09-22: знак валюты был зашит в отчётах
  /// тридцатью местами, и владелец американского магазина видел выручку в
  /// тенге. Знак берётся у кассы одним местом ([tillCurrencySymbol]).
  static String withCurrency(Decimal amount) =>
      '${full(amount)} ${tillCurrencySymbol()}';
}
