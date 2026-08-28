import 'package:decimal/decimal.dart';

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
}
