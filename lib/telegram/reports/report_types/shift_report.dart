import 'package:telepos/telegram/reports/report_generator.dart';

class ShiftReportData {
  static Map<String, dynamic> build({
    required int shiftNumber,
    required String cashier,
    required String openTime,
    required String closeTime,
    required int salesCount,
    required String salesTotal,
    required int refundsCount,
    required String refundsTotal,
    required String cashPayments,
    required String cardPayments,
    required String cashInRegister,
    required String investments,
    required String dividends,
    required String expenses,
  }) {
    return {
      'shiftNumber': shiftNumber,
      'cashier': cashier,
      'openTime': openTime,
      'closeTime': closeTime,
      'salesCount': salesCount,
      'salesTotal': salesTotal,
      'refundsCount': refundsCount,
      'refundsTotal': refundsTotal,
      'cashPayments': cashPayments,
      'cardPayments': cardPayments,
      'cashInRegister': cashInRegister,
      'investments': investments,
      'dividends': dividends,
      'expenses': expenses,
    };
  }

  static ReportType get type => ReportType.shift;
}
