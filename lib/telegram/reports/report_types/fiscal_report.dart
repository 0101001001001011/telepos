import 'package:telepos/telegram/reports/report_generator.dart';

class FiscalReportData {
  static Map<String, dynamic> build({
    required String ofdProvider,
    required int registeredCount,
    required int pendingCount,
    required int errorCount,
    required String totalVat,
  }) {
    return {
      'ofdProvider': ofdProvider,
      'registeredCount': registeredCount,
      'pendingCount': pendingCount,
      'errorCount': errorCount,
      'totalVat': totalVat,
    };
  }

  static ReportType get type => ReportType.fiscal;
}
