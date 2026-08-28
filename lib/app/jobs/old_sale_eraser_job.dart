import 'dart:async';

import 'package:telepos/app/jobs/job_scheduler.dart';

typedef DeleteOldSalesCallback = Future<int> Function(DateTime olderThan);

class OldSaleEraserJob extends BackgroundJob {
  final DeleteOldSalesCallback _deleteOldSales;
  final Duration _retentionPeriod;
  final void Function(int deletedCount)? onCompleted;

  OldSaleEraserJob({
    required DeleteOldSalesCallback deleteOldSales,
    Duration retentionPeriod = const Duration(days: 7),
    this.onCompleted,
  }) : _deleteOldSales = deleteOldSales,
       _retentionPeriod = retentionPeriod;

  @override
  String get id => 'old_sale_eraser';

  @override
  String get name => 'Old Sale Eraser';

  @override
  Duration get interval => const Duration(days: 1);

  @override
  JobPriority get priority => JobPriority.low;

  @override
  Duration get timeout => const Duration(minutes: 30);

  @override
  int get maxRetries => 2;

  @override
  bool canRunNow() {
    final hour = DateTime.now().hour;
    return hour >= 2 && hour < 5;
  }

  @override
  Future<void> execute() async {
    final cutoffDate = DateTime.now().subtract(_retentionPeriod);

    final deletedCount = await _deleteOldSales(cutoffDate);

    onCompleted?.call(deletedCount);
  }
}
