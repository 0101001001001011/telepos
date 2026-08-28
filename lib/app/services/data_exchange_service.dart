import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/fiscal/webkassa_service.dart';
import 'package:telepos/telegram/data_exchange/sync_state_tracker.dart';
import 'package:telepos/telegram/data_exchange/telegram_sync_engine.dart';
import 'package:telepos/domain/entities/telegram/sync_packet.dart';
import 'package:telepos/transport/rest/rest_transport.dart';
import 'package:telepos/transport/telegram/telegram_transport.dart';

enum DataExchangeMode { telegramOnly, hybrid, restOnly }

class SyncResult {
  final Map<ExchangeType, int> uploaded;

  final Map<ExchangeType, int> downloaded;

  final Map<ExchangeType, String> errors;

  final Duration duration;

  final bool telegramSuccess;

  final bool? restSuccess;

  const SyncResult({
    required this.uploaded,
    required this.downloaded,
    required this.errors,
    required this.duration,
    required this.telegramSuccess,
    this.restSuccess,
  });

  bool get isSuccess => errors.isEmpty && telegramSuccess;

  int get totalUploaded => uploaded.values.fold(0, (a, b) => a + b);
  int get totalDownloaded => downloaded.values.fold(0, (a, b) => a + b);

  @override
  String toString() =>
      'SyncResult(uploaded=$totalUploaded, downloaded=$totalDownloaded, '
      'telegram=$telegramSuccess, rest=$restSuccess, errors=${errors.length})';
}

class DataExchangeService {
  final Talker _logger;
  final AppDatabase _db;

  TelegramTransport? _telegramTransport;

  RestTransport? _restTransport;

  TelegramSyncEngine? _telegramSyncEngine;

  SyncStateTracker? _stateTracker;

  DataExchangeMode _mode = DataExchangeMode.telegramOnly;

  String? _restBaseUrl;

  SyncResult? _lastSyncResult;

  final _syncStatusController = StreamController<SyncResult>.broadcast();

  DataExchangeService({required Talker logger, required AppDatabase db})
    : _logger = logger,
      _db = db;

  Future<void> initialize() async {
    _logger.info('DataExchangeService: initializing');

    if (GetIt.I.isRegistered<TelegramTransport>()) {
      _telegramTransport = GetIt.I<TelegramTransport>();
      _logger.debug('Telegram transport: available');
    }

    if (GetIt.I.isRegistered<TelegramSyncEngine>()) {
      _telegramSyncEngine = GetIt.I<TelegramSyncEngine>();
      _stateTracker = _telegramSyncEngine?.stateTracker;
      _logger.debug('TelegramSyncEngine: available');
    }

    if (GetIt.I.isRegistered<RestTransport>()) {
      _restTransport = GetIt.I<RestTransport>();
      _logger.debug('REST transport: available');
    }

    await _determineMode();

    _logger.info('DataExchangeService: mode=${_mode.name}');
  }

  Future<void> _determineMode() async {
    try {
      final thisPos = await _db.thisPosDao.get();
      if (thisPos == null) {
        _mode = DataExchangeMode.telegramOnly;
        return;
      }

      _restBaseUrl = null;

      if (_restBaseUrl != null && _restBaseUrl!.isNotEmpty) {
        _mode = DataExchangeMode.hybrid;
      } else {
        _mode = DataExchangeMode.telegramOnly;
      }
    } catch (e) {
      _logger.warning('Failed to determine mode: $e');
      _mode = DataExchangeMode.telegramOnly;
    }
  }

  DataExchangeMode get mode => _mode;

  SyncResult? get lastSyncResult => _lastSyncResult;

  Stream<SyncResult> get syncStatus => _syncStatusController.stream;

  Future<bool> get isTelegramAvailable async {
    return _telegramTransport != null &&
        await _telegramTransport!.isAvailable();
  }

  Future<bool> get isRestAvailable async {
    if (_restTransport == null) return false;
    if (_mode == DataExchangeMode.telegramOnly) return false;
    return await _restTransport!.isAvailable();
  }

  Future<SyncResult> syncAll() async {
    final stopwatch = Stopwatch()..start();
    _logger.info('DataExchangeService: starting full sync');

    final uploaded = <ExchangeType, int>{};
    final downloaded = <ExchangeType, int>{};
    final errors = <ExchangeType, String>{};

    var telegramSuccess = false;
    bool? restSuccess;

    try {
      if (_telegramSyncEngine != null) {
        try {
          await _telegramSyncEngine!.syncAll();
          telegramSuccess = true;

          final syncState = _telegramSyncEngine!.syncState;
          _logger.info(
            'Telegram sync: processed=${syncState.processedPackets}',
          );
        } catch (e) {
          _logger.error('Telegram sync failed: $e');
          errors[ExchangeType.config] = 'Telegram: $e';
        }
      } else if (_telegramTransport != null) {
        try {
          await _syncViaTelegramTransport(uploaded, downloaded, errors);
          telegramSuccess = errors.isEmpty;
        } catch (e) {
          _logger.error('Telegram transport sync failed: $e');
        }
      }

      if (_mode == DataExchangeMode.hybrid && _restTransport != null) {
        try {
          await _syncViaRestTransport(uploaded, downloaded, errors);
          restSuccess = true;
        } catch (e) {
          _logger.error('REST sync failed: $e');
          restSuccess = false;
          errors[ExchangeType.config] = 'REST: $e';
        }
      }

      if (telegramSuccess || restSuccess == true) {
        await _syncWebkassaOfflineReceipts(errors);
      }
    } catch (e, st) {
      _logger.handle(e, st, 'DataExchangeService.syncAll');
    }

    stopwatch.stop();

    final result = SyncResult(
      uploaded: uploaded,
      downloaded: downloaded,
      errors: errors,
      duration: stopwatch.elapsed,
      telegramSuccess: telegramSuccess,
      restSuccess: restSuccess,
    );

    _lastSyncResult = result;
    _syncStatusController.add(result);

    _logger.info('DataExchangeService: sync completed in ${stopwatch.elapsed}');
    _logger.info('  Result: $result');

    return result;
  }

  Future<void> _syncViaTelegramTransport(
    Map<ExchangeType, int> uploaded,
    Map<ExchangeType, int> downloaded,
    Map<ExchangeType, String> errors,
  ) async {
    final transport = _telegramTransport!;

    try {
      final pendingSales = await _getPendingSales();
      if (pendingSales.isNotEmpty) {
        final result = await transport.uploadSales(pendingSales);
        if (result.isSuccess) {
          uploaded[ExchangeType.sale] = pendingSales.length;
          await _markSalesAsSynced(pendingSales);
        } else {
          errors[ExchangeType.sale] =
              result.errorOrNull?.message ?? 'Unknown error';
        }
      }
    } catch (e) {
      errors[ExchangeType.sale] = e.toString();
    }

    try {
      final pendingShifts = await _getPendingShifts();
      if (pendingShifts.isNotEmpty) {
        final result = await transport.uploadShifts(pendingShifts);
        if (result.isSuccess) {
          uploaded[ExchangeType.shift] = pendingShifts.length;
          await _markShiftsAsSynced(pendingShifts);
        } else {
          errors[ExchangeType.shift] =
              result.errorOrNull?.message ?? 'Unknown error';
        }
      }
    } catch (e) {
      errors[ExchangeType.shift] = e.toString();
    }

    try {
      final lastSync = _stateTracker?.getLastSync(ExchangeType.product);
      final since = lastSync != null && lastSync > 0
          ? DateTime.fromMillisecondsSinceEpoch(lastSync * 1000)
          : null;

      final result = await transport.downloadProducts(since: since);
      final products = result.dataOrNull;
      if (result.isSuccess && products != null) {
        downloaded[ExchangeType.product] = products.length;
        await _stateTracker?.markSynced(ExchangeType.product);
      }
    } catch (e) {
      errors[ExchangeType.product] = e.toString();
    }
  }

  Future<void> _syncViaRestTransport(
    Map<ExchangeType, int> uploaded,
    Map<ExchangeType, int> downloaded,
    Map<ExchangeType, String> errors,
  ) async {
    final transport = _restTransport!;

    try {
      final pendingSales = await _getPendingSales();
      if (pendingSales.isNotEmpty) {
        final result = await transport.uploadSales(pendingSales);
        if (result.isSuccess) {
          uploaded[ExchangeType.sale] =
              (uploaded[ExchangeType.sale] ?? 0) + pendingSales.length;
        }
      }
    } catch (e) {
      _logger.warning('REST upload sales failed: $e');
    }

    try {
      final result = await transport.downloadProducts();
      final products = result.dataOrNull;
      if (result.isSuccess && products != null) {
        downloaded[ExchangeType.product] =
            (downloaded[ExchangeType.product] ?? 0) + products.length;
      }
    } catch (e) {
      _logger.warning('REST download products failed: $e');
    }
  }

  Future<void> syncType(ExchangeType type) async {
    _logger.info('DataExchangeService: syncing type=${type.name}');

    if (_telegramSyncEngine != null) {
      await _telegramSyncEngine!.syncType(type);
    }
  }

  Future<SyncResult> forceSyncAll() async {
    _logger.info('DataExchangeService: force sync (resetting lastSync)');

    if (_telegramSyncEngine != null) {
      await _telegramSyncEngine!.forceSyncAll();
    }

    return syncAll();
  }

  Future<List<Map<String, dynamic>>> _getPendingSales() async {
    final sales = await _db.saleDao.findByState(1);
    return sales
        .map(
          (s) => {
            'receiptNo': s.receiptNo,
            'posId': s.posId,
            'userId': s.userId,
            'time': s.time,
            'amount': s.amount.toString(),
            'state': s.state,
          },
        )
        .toList();
  }

  Future<void> _markSalesAsSynced(List<Map<String, dynamic>> sales) async {
    for (final sale in sales) {
      final receiptNo = sale['receiptNo'] as int;
      final posId = sale['posId'] as int;
      await _db.saleDao.updateState(receiptNo, posId, 4);
    }
  }

  Future<List<Map<String, dynamic>>> _getPendingShifts() async {
    final shifts = await _db.shiftDao.findAllNonSync();
    return shifts
        .map(
          (s) => {
            'id': s.id,
            'userId': s.userId,
            'openTime': s.openTime,
            'closeTime': s.closeTime,
            'cashInPosOnShiftClose': s.cashInPosOnShiftClose?.toString(),
            'isOpened': s.isOpened,
          },
        )
        .toList();
  }

  Future<void> _markShiftsAsSynced(List<Map<String, dynamic>> shifts) async {
    for (final shift in shifts) {
      final id = shift['id'] as int;
      await _db.shiftDao.markAsSynced(id);
    }
  }

  void setMode(DataExchangeMode mode) {
    _mode = mode;
    _logger.info('DataExchangeService: mode changed to ${mode.name}');
  }

  void setRestApiUrl(String? url) {
    _restBaseUrl = url;
    if (url != null && url.isNotEmpty) {
      if (_mode == DataExchangeMode.telegramOnly) {
        _mode = DataExchangeMode.hybrid;
      }
    }
    _logger.info('DataExchangeService: REST URL set to $url');
  }

  Future<void> _syncWebkassaOfflineReceipts(
    Map<ExchangeType, String> errors,
  ) async {
    try {
      if (!GetIt.I.isRegistered<WebKassaService>()) {
        _logger.debug('WebKassaService not registered, skipping offline sync');
        return;
      }

      final webkassaService = GetIt.I<WebKassaService>();

      final offlineCount = await webkassaService.getOfflineReceiptCount();
      if (offlineCount == 0) {
        return;
      }

      _logger.info('Syncing $offlineCount offline WebKassa receipts...');

      final result = await webkassaService.syncOfflineReceipts();

      if (result.syncedCount > 0) {
        _logger.info(
          'WebKassa offline sync: ${result.syncedCount}/${result.totalCount} synced',
        );
      }

      if (result.hasErrors) {
        _logger.warning('WebKassa offline sync: ${result.failedCount} failed');
        for (final error in result.errors) {
          _logger.warning('  $error');
        }
        errors[ExchangeType.fiscal] =
            'WebKassa: ${result.failedCount} чеков не синхронизировано';
      }
    } catch (e) {
      _logger.warning('WebKassa offline sync failed: $e');
      errors[ExchangeType.fiscal] = 'WebKassa: $e';
    }
  }

  Future<void> dispose() async {
    await _syncStatusController.close();
  }
}
