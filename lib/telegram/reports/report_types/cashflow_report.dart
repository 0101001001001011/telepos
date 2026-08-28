import 'package:telepos/telegram/reports/report_generator.dart';

class CashflowReportData {
  static Map<String, dynamic> build({
    required String openingBalance,
    required String cashSales,
    required String investments,
    required String expenses,
    required String dividends,
    required String closingBalance,
  }) {
    return {
      'openingBalance': openingBalance,
      'cashSales': cashSales,
      'investments': investments,
      'expenses': expenses,
      'dividends': dividends,
      'closingBalance': closingBalance,
    };
  }

  static ReportType get type => ReportType.cashflow;
}
