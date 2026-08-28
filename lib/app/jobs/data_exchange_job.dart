import 'dart:async';

import 'package:telepos/app/jobs/job_scheduler.dart';
import 'package:telepos/domain/repositories/transport_repository.dart';

typedef GetPendingSalesCallback = Future<List<Map<String, dynamic>>> Function();
typedef GetPendingRefundsCallback =
    Future<List<Map<String, dynamic>>> Function();
typedef MarkAsSyncedCallback = Future<void> Function(List<String> ids);

class DataExchangeJob extends BackgroundJob {
  final TransportRepository _transportRepository;
  final GetPendingSalesCallback? _getPendingSales;
  final GetPendingRefundsCallback? _getPendingRefunds;
  final MarkAsSyncedCallback? _markAsSynced;
  final void Function(String)? onStatusChanged;

  DataExchangeJob({
    required TransportRepository transportRepository,
    GetPendingSalesCallback? getPendingSales,
    GetPendingRefundsCallback? getPendingRefunds,
    MarkAsSyncedCallback? markAsSynced,
    this.onStatusChanged,
  }) : _transportRepository = transportRepository,
       _getPendingSales = getPendingSales,
       _getPendingRefunds = getPendingRefunds,
       _markAsSynced = markAsSynced;

  @override
  String get id => 'data_exchange';

  @override
  String get name => 'Data Exchange Sync';

  @override
  Duration get interval => const Duration(minutes: 5);

  @override
  JobPriority get priority => JobPriority.high;

  @override
  Duration get timeout => const Duration(minutes: 10);

  @override
  int get maxRetries => 5;

  @override
  Duration get retryDelay => const Duration(minutes: 1);

  @override
  bool canRunNow() {
    return _transportRepository.isConnected;
  }

  @override
  Future<void> execute() async {
    onStatusChanged?.call('Синхронизация данных...');

    try {
      await _uploadPendingSales();

      await _uploadPendingRefunds();

      await _downloadProducts();

      await _downloadPrices();

      await _downloadConfig();

      await _transportRepository.processQueue();

      onStatusChanged?.call('Синхронизация завершена');
    } catch (e) {
      onStatusChanged?.call('Ошибка синхронизации');
      rethrow;
    }
  }

  Future<void> _uploadPendingSales() async {
    if (_getPendingSales == null) return;

    final pendingSales = await _getPendingSales();
    if (pendingSales.isEmpty) return;

    final result = await _transportRepository.uploadSales(pendingSales);
    result.fold(
      (failure) {
        if (failure.code != 'QUEUED') {
          throw Exception('Sales upload failed: ${failure.message}');
        }
      },
      (_) async {
        if (_markAsSynced != null) {
          final ids = pendingSales.map((s) => s['id'] as String).toList();
          await _markAsSynced(ids);
        }
      },
    );
  }

  Future<void> _uploadPendingRefunds() async {
    if (_getPendingRefunds == null) return;

    final pendingRefunds = await _getPendingRefunds();
    if (pendingRefunds.isEmpty) return;

    final result = await _transportRepository.uploadRefunds(pendingRefunds);
    result.fold(
      (failure) {
        if (failure.code != 'QUEUED') {
          throw Exception('Refunds upload failed: ${failure.message}');
        }
      },
      (_) async {
        if (_markAsSynced != null) {
          final ids = pendingRefunds.map((r) => r['id'] as String).toList();
          await _markAsSynced(ids);
        }
      },
    );
  }

  Future<void> _downloadProducts() async {
    final result = await _transportRepository.downloadProducts();
    result.fold((failure) {}, (products) {});
  }

  Future<void> _downloadPrices() async {
    final result = await _transportRepository.downloadPrices();
    result.fold((failure) {}, (prices) {});
  }

  Future<void> _downloadConfig() async {
    final result = await _transportRepository.downloadConfig();
    result.fold((failure) {}, (config) {});
  }
}
