import 'package:telepos/telegram/reports/report_generator.dart';

class DailyReportData {
  static Map<String, dynamic> build({
    required String date,
    required String revenue,
    required int salesCount,
    required String averageCheck,
    required int refundsCount,
    required int shiftsCount,
  }) {
    return {
      'date': date,
      'revenue': revenue,
      'salesCount': salesCount,
      'averageCheck': averageCheck,
      'refundsCount': refundsCount,
      'shiftsCount': shiftsCount,
    };
  }

  static ReportType get type => ReportType.daily;
}
