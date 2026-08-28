import 'package:telepos/telegram/reports/report_generator.dart';

class InventoryReportData {
  static Map<String, dynamic> build({
    required int totalItems,
    required int inStock,
    required int outOfStock,
    required int lowStock,
  }) {
    return {
      'totalItems': totalItems,
      'inStock': inStock,
      'outOfStock': outOfStock,
      'lowStock': lowStock,
    };
  }

  static ReportType get type => ReportType.inventory;
}
