import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:talker/talker.dart';

import '../../domain/repositories/transport_repository.dart' as domain;
import '../../transport/transport_exports.dart' as transport;

class TransportRepositoryImpl implements domain.TransportRepository {
  final transport.TransportCoordinator _coordinator;
  final transport.OfflineQueue _queue;
  final Talker _logger;

  final _connectionStatusController =
      StreamController<domain.TransportConnectionStatus>.broadcast();
  final _updatesController =
      StreamController<domain.TransportUpdate>.broadcast();
  final _commandsController =
      StreamController<domain.RemoteCommand>.broadcast();

  domain.TransportConnectionStatus _currentStatus =
      domain.TransportConnectionStatus.disconnected();

  StreamSubscription<Map<transport.TransportType, transport.TransportStatus>>?
  _statusSubscription;

  TransportRepositoryImpl({
    required transport.TransportCoordinator coordinator,
    required transport.OfflineQueue queue,
    required Talker logger,
  }) : _coordinator = coordinator,
       _queue = queue,
       _logger = logger {
    _statusSubscription = _coordinator.statusStream.listen(_onStatusChanged);
  }

  void _onStatusChanged(
    Map<transport.TransportType, transport.TransportStatus> statuses,
  ) {
    final isConnected = statuses.values.any((s) => s.isConnected);
    final isConnecting = statuses.values.any((s) => s.isConnecting);

    _currentStatus = domain.TransportConnectionStatus(
      isConnected: isConnected,
      isSyncing: isConnecting,
    );
    _connectionStatusController.add(_currentStatus);
  }

  @override
  Future<Either<domain.TransportFailure, void>> uploadSales(
    List<Map<String, dynamic>> sales,
  ) async {
    return _executeUpload(transport.TransportOperation.uploadSales, {
      'sales': sales,
    });
  }

  @override
  Future<Either<domain.TransportFailure, void>> uploadRefunds(
    List<Map<String, dynamic>> refunds,
  ) async {
    return _executeUpload(transport.TransportOperation.uploadRefunds, {
      'refunds': refunds,
    });
  }

  @override
  Future<Either<domain.TransportFailure, void>> uploadShifts(
    List<Map<String, dynamic>> shifts,
  ) async {
    return _executeUpload(transport.TransportOperation.uploadShifts, {
      'shifts': shifts,
    });
  }

  @override
  Future<Either<domain.TransportFailure, void>> uploadCashOperations(
    List<Map<String, dynamic>> operations,
  ) async {
    return _executeUpload(transport.TransportOperation.uploadCashOperations, {
      'operations': operations,
    });
  }

  @override
  Future<Either<domain.TransportFailure, void>> uploadSupplies(
    List<Map<String, dynamic>> supplies,
  ) async {
    return _executeUpload(transport.TransportOperation.uploadSupplies, {
      'supplies': supplies,
    });
  }

  @override
  Future<Either<domain.TransportFailure, List<Map<String, dynamic>>>>
  downloadProducts({DateTime? since}) async {
    return _executeDownload(
      transport.TransportOperation.downloadProducts,
      (t) => t.downloadProducts(since: since),
    );
  }

  @override
  Future<Either<domain.TransportFailure, List<Map<String, dynamic>>>>
  downloadPrices({DateTime? since}) async {
    return _executeDownload(
      transport.TransportOperation.downloadPrices,
      (t) => t.downloadPrices(since: since),
    );
  }

  @override
  Future<Either<domain.TransportFailure, List<Map<String, dynamic>>>>
  downloadCategories({DateTime? since}) async {
    return _executeDownload(
      transport.TransportOperation.downloadCategories,
      (t) => t.downloadCategories(since: since),
    );
  }

  @override
  Future<Either<domain.TransportFailure, List<Map<String, dynamic>>>>
  downloadAgents({DateTime? since}) async {
    return _executeDownload(
      transport.TransportOperation.downloadAgents,
      (t) => t.downloadAgents(since: since),
    );
  }

  @override
  Future<Either<domain.TransportFailure, Map<String, dynamic>>>
  downloadConfig() async {
    final result = await _coordinator.execute<Map<String, dynamic>>(
      transport.TransportOperation.downloadConfig,
      (t) => t.downloadConfig(),
    );
    return _mapResult(result);
  }

  @override
  Future<Either<domain.TransportFailure, List<Map<String, dynamic>>>>
  downloadUsers() async {
    final result = await _coordinator.execute<List<Map<String, dynamic>>>(
      transport.TransportOperation.downloadUsers,
      (t) => t.downloadUsers(),
    );
    return _mapResult(result);
  }

  @override
  Future<Either<domain.TransportFailure, List<Map<String, dynamic>>>>
  downloadStock() async {
    return const Right([]);
  }

  @override
  Future<Either<domain.TransportFailure, String>> uploadBackup({
    required String filePath,
    required Map<String, dynamic> metadata,
  }) async {
    final result = await _coordinator.execute<String>(
      transport.TransportOperation.uploadBackup,
      (t) => t.uploadBackup(filePath: filePath, metadata: metadata),
    );
    return _mapResult(result);
  }

  @override
  Future<Either<domain.TransportFailure, List<Map<String, dynamic>>>>
  listBackups() async {
    final result = await _coordinator.execute<List<Map<String, dynamic>>>(
      transport.TransportOperation.listBackups,
      (t) => t.listBackups(),
    );
    return _mapResult(result);
  }

  @override
  Future<Either<domain.TransportFailure, String>> downloadBackup(
    String backupId,
  ) async {
    final result = await _coordinator.execute<String>(
      transport.TransportOperation.downloadBackup,
      (t) => t.downloadBackup(backupId),
    );
    return _mapResult(result);
  }

  @override
  Future<Either<domain.TransportFailure, void>> sendNotification({
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final result = await _coordinator.execute<void>(
      _getNotificationOperation(type),
      (t) =>
          t.sendNotification(type: type, title: title, body: body, data: data),
    );
    return _mapResult(result);
  }

  transport.TransportOperation _getNotificationOperation(String type) {
    switch (type) {
      case 'shift_open':
        return transport.TransportOperation.notifyShiftOpen;
      case 'shift_close':
        return transport.TransportOperation.notifyShiftClose;
      case 'large_sale':
        return transport.TransportOperation.notifyLargeSale;
      case 'refund':
        return transport.TransportOperation.notifyRefund;
      case 'error':
        return transport.TransportOperation.notifyError;
      case 'low_stock':
        return transport.TransportOperation.notifyLowStock;
      case 'fiscal_error':
        return transport.TransportOperation.notifyFiscalError;
      default:
        return transport.TransportOperation.notifyError;
    }
  }

  @override
  Future<Either<domain.TransportFailure, void>> sendReport({
    required String type,
    required Map<String, dynamic> data,
    String? filePath,
  }) async {
    final result = await _coordinator.execute<void>(
      _getReportOperation(type),
      (t) => t.sendReport(type: type, data: data, filePath: filePath),
    );
    return _mapResult(result);
  }

  transport.TransportOperation _getReportOperation(String type) {
    switch (type) {
      case 'z_report':
        return transport.TransportOperation.sendZReport;
      case 'daily':
        return transport.TransportOperation.sendDailyReport;
      case 'weekly':
        return transport.TransportOperation.sendWeeklyReport;
      case 'inventory':
        return transport.TransportOperation.sendInventoryReport;
      default:
        return transport.TransportOperation.sendDailyReport;
    }
  }

  @override
  Future<Either<domain.TransportFailure, void>> subscribeToUpdates(
    List<String> channels,
  ) async {
    final stopwatch = Stopwatch()..start();
    final result = await _coordinator.execute<void>(
      transport.TransportOperation.subscribePriceUpdates,
      (t) async {
        await t.subscribeToUpdates(channels);
        return transport.TransportResult<void>.success(
          data: null,
          usedTransport: transport.TransportType.rest,
          duration: stopwatch.elapsed,
        );
      },
    );
    return _mapResult(result);
  }

  @override
  Future<Either<domain.TransportFailure, void>> unsubscribeFromUpdates() async {
    final stopwatch = Stopwatch()..start();
    final result = await _coordinator.execute<void>(
      transport.TransportOperation.subscribePriceUpdates,
      (t) async {
        await t.unsubscribeFromUpdates();
        return transport.TransportResult<void>.success(
          data: null,
          usedTransport: transport.TransportType.rest,
          duration: stopwatch.elapsed,
        );
      },
    );
    return _mapResult(result);
  }

  @override
  Stream<domain.TransportUpdate> get updatesStream => _updatesController.stream;

  @override
  Stream<domain.RemoteCommand> get commandsStream => _commandsController.stream;

  @override
  domain.TransportConnectionStatus get connectionStatus => _currentStatus;

  @override
  Stream<domain.TransportConnectionStatus> get connectionStatusStream =>
      _connectionStatusController.stream;

  @override
  bool get isConnected => _currentStatus.isConnected;

  @override
  domain.TransportModeInfo get currentMode {
    final config = _coordinator.config;
    switch (config.mode) {
      case transport.TransportMode.telegramOnly:
        return domain.TransportModeInfo.telegramOnly();
      case transport.TransportMode.restOnly:
        return domain.TransportModeInfo.restOnly();
      case transport.TransportMode.hybrid:
        return domain.TransportModeInfo.hybrid();
    }
  }

  @override
  Future<int> get queuedOperationsCount async {
    final stats = await _queue.getStatistics();
    return stats.pending + stats.retrying;
  }

  @override
  Future<int> get failedOperationsCount async {
    final stats = await _queue.getStatistics();
    return stats.failed;
  }

  @override
  Future<void> processQueue() => _queue.processQueue();

  @override
  Future<void> retryFailedOperations() async {
    await _queue.retryAllFailed();
  }

  @override
  Future<void> initialize() async {
    _logger.debug('[TransportRepositoryImpl] Initializing...');

    _queue.eventStream.listen((event) {
      if (event is transport.OperationCompleted ||
          event is transport.OperationFailed) {
        _updateQueueStatus();
      }
    });

    _logger.debug('[TransportRepositoryImpl] Initialized');
  }

  @override
  Future<void> dispose() async {
    await _statusSubscription?.cancel();
    await _connectionStatusController.close();
    await _updatesController.close();
    await _commandsController.close();
  }

  Future<Either<domain.TransportFailure, void>> _executeUpload(
    transport.TransportOperation operation,
    Map<String, dynamic> data,
  ) async {
    await _queue.enqueue(operation: operation, data: data);

    _logger.debug('[TransportRepositoryImpl] Operation queued: $operation');

    _queue.processQueue();

    return const Right(null);
  }

  Future<Either<domain.TransportFailure, List<Map<String, dynamic>>>>
  _executeDownload(
    transport.TransportOperation operation,
    Future<transport.TransportResult<List<Map<String, dynamic>>>> Function(
      transport.TransportInterface,
    )
    executor,
  ) async {
    final result = await _coordinator.execute<List<Map<String, dynamic>>>(
      operation,
      executor,
    );
    return _mapResult(result);
  }

  Either<domain.TransportFailure, T> _mapResult<T>(
    transport.TransportResult<T> result,
  ) {
    if (result.isSuccess) {
      return Right(result.dataOrNull as T);
    } else {
      return Left(_mapError(result.errorOrNull!));
    }
  }

  domain.TransportFailure _mapError(transport.TransportError error) {
    return domain.TransportFailure(
      message: error.message,
      code: error.code,
      isRetryable: error.isRetryable,
    );
  }

  Future<void> _updateQueueStatus() async {
    final stats = await _queue.getStatistics();
    _logger.debug(
      '[TransportRepositoryImpl] Queue status: '
      'pending=${stats.pending}, failed=${stats.failed}',
    );
  }
}
