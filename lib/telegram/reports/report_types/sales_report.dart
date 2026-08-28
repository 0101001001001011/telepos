import 'package:telepos/telegram/reports/report_generator.dart';

class SalesReportData {
  static Map<String, dynamic> build({
    required String period,
    required int totalSales,
    required String totalRevenue,
    required String averageCheck,
    List<String>? topProducts,
  }) {
    return {
      'period': period,
      'totalSales': totalSales,
      'totalRevenue': totalRevenue,
      'averageCheck': averageCheck,
      'topProducts': topProducts ?? [],
    };
  }

  static ReportType get type => ReportType.sales;
}
