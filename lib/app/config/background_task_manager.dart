import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/app/services/data_exchange_service.dart';
import 'package:telepos/app/services/old_sale_cleanup_service.dart';
import 'package:telepos/core/constants/app_constants.dart';
import 'package:telepos/core/services/update/updater_service.dart';
import 'package:telepos/core/services/update/update_state.dart';

class BackgroundTaskManager {
  BackgroundTaskManager({required Talker logger}) : _logger = logger;

  static bool disabledForTests = false;

  final Talker _logger;

  final List<Timer> _timers = [];
  bool _isRunning = false;

  DataExchangeService? _dataExchangeService;

  OldSaleCleanupService? _cleanupService;

  UpdaterService? _updaterService;

  bool get isRunning => _isRunning;

  SyncResult? get lastSyncResult => _dataExchangeService?.lastSyncResult;

  CleanupResult? get lastCleanupResult => _cleanupService?.lastResult;

  OldSaleCleanupService? get cleanupService => _cleanupService;

  UpdaterService? get updaterService => _updaterService;

  Future<void> startAll() async {
    if (disabledForTests) {
      _logger.info('BackgroundTaskManager: disabled for tests (no-op)');
      return;
    }
    if (_isRunning) return;
    _isRunning = true;

    _logger.info('BackgroundTaskManager: starting all tasks');

    await _initializeServices();

    _startDataExchangeTask();
    _startOldSaleEraserTask();
    _startUpdaterTask();
  }

  Future<void> _initializeServices() async {
    try {
      if (GetIt.I.isRegistered<DataExchangeService>()) {
        _dataExchangeService = GetIt.I<DataExchangeService>();
        await _dataExchangeService!.initialize();
        _logger.info(
          'DataExchangeService initialized: mode=${_dataExchangeService!.mode.name}',
        );
      } else {
        _logger.warning('DataExchangeService not registered in DI');
      }
    } catch (e) {
      _logger.warning('Failed to initialize DataExchangeService: $e');
    }

    try {
      if (GetIt.I.isRegistered<OldSaleCleanupService>()) {
        _cleanupService = GetIt.I<OldSaleCleanupService>();
        _logger.info(
          'OldSaleCleanupService initialized: '
          'retentionDays=${_cleanupService!.settings.retentionDays}',
        );
      } else {
        _logger.warning('OldSaleCleanupService not registered in DI');
      }
    } catch (e) {
      _logger.warning('Failed to initialize OldSaleCleanupService: $e');
    }

    try {
      if (GetIt.I.isRegistered<UpdaterService>()) {
        _updaterService = GetIt.I<UpdaterService>();
        _logger.info(
          'UpdaterService initialized: '
          'version=${_updaterService!.currentVersion}',
        );
      } else {
        _logger.warning('UpdaterService not registered in DI');
      }
    } catch (e) {
      _logger.warning('Failed to initialize UpdaterService: $e');
    }
  }

  void stopAll() {
    _logger.info('BackgroundTaskManager: stopping all tasks');
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _isRunning = false;
  }

  void dispose() {
    stopAll();
  }

  void _startDataExchangeTask() {
    final timer = Timer.periodic(
      AppConstants.syncInterval,
      (_) => _onDataExchangeTick(),
    );
    _timers.add(timer);
    _logger.info(
      'DataExchange task started (every ${AppConstants.syncInterval.inMinutes}m)',
    );
  }

  Future<void> _onDataExchangeTick() async {
    if (_dataExchangeService == null) {
      _logger.debug('DataExchange tick — service not initialized');
      return;
    }

    _logger.debug('DataExchange tick — starting sync');

    try {
      final result = await _dataExchangeService!.syncAll();

      if (result.isSuccess) {
        _logger.info(
          'DataExchange: synced ${result.totalUploaded} uploaded, '
          '${result.totalDownloaded} downloaded '
          '(${result.duration.inMilliseconds}ms)',
        );
      } else {
        _logger.warning(
          'DataExchange: completed with ${result.errors.length} errors',
        );
        for (final entry in result.errors.entries) {
          _logger.warning('  ${entry.key.name}: ${entry.value}');
        }
      }
    } catch (e, st) {
      _logger.handle(e, st, 'DataExchange tick failed');
    }
  }

  void _startOldSaleEraserTask() {
    final timer = Timer.periodic(
      const Duration(hours: 24),
      (_) => _onOldSaleEraserTick(),
    );
    _timers.add(timer);
    _logger.info('OldSaleEraser task started (every 24h)');
  }

  Future<void> _onOldSaleEraserTick() async {
    if (_cleanupService == null) {
      _logger.debug('OldSaleEraser tick — service not initialized');
      return;
    }

    _logger.debug('OldSaleEraser tick — starting cleanup');

    try {
      final result = await _cleanupService!.cleanup();

      if (result.isSuccess) {
        if (result.deletedSales > 0) {
          _logger.info(
            'OldSaleEraser: deleted ${result.deletedSales} sales, '
            '${result.deletedSaleProducts} products, '
            '${result.deletedPayments} payments '
            '(${result.duration.inMilliseconds}ms)',
          );
        } else {
          _logger.debug('OldSaleEraser: no old sales to delete');
        }
      } else {
        _logger.warning('OldSaleEraser: failed — ${result.error}');
      }
    } catch (e, st) {
      _logger.handle(e, st, 'OldSaleEraser tick failed');
    }
  }

  void _startUpdaterTask() {
    Future.delayed(const Duration(seconds: 10), () {
      if (_isRunning) _onUpdaterTick();
    });

    final timer = Timer.periodic(
      AppConstants.updateCheckInterval,
      (_) => _onUpdaterTick(),
    );
    _timers.add(timer);
    _logger.info(
      'Updater task started (every ${AppConstants.updateCheckInterval.inHours}h, '
      'initial check in 10s)',
    );
  }

  Future<void> _onUpdaterTick() async {
    if (_updaterService == null) {
      _logger.debug('Updater tick — service not initialized');
      return;
    }

    _logger.debug('Updater tick — checking for updates');

    try {
      await _updaterService!.checkForUpdates();

      final state = _updaterService!.state;

      switch (state.status) {
        case UpdateStatus.idle:
          _logger.debug('Updater: no updates available');
        case UpdateStatus.available:
          _logger.info(
            'Updater: update available v${state.updateInfo?.version} '
            '(mandatory: ${state.updateInfo?.isMandatory ?? false})',
          );
        case UpdateStatus.failed:
          _logger.warning('Updater: check failed — ${state.errorMessage}');
        default:
          _logger.debug('Updater: status=${state.status.name}');
      }
    } catch (e, st) {
      _logger.handle(e, st, 'Updater tick failed');
    }
  }
}
