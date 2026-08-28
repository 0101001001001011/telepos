import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/app/services/data_exchange_service.dart';
import 'package:telepos/app/services/old_sale_cleanup_service.dart';
import 'package:telepos/core/constants/app_constants.dart';
import 'package:telepos/core/services/update/updater_service.dart';
import 'package:telepos/core/services/update/update_state.dart';
import 'package:telepos/domain/usecases/fiscal/fisc_errors_service.dart';

class BackgroundTaskManager {
  BackgroundTaskManager({required Talker logger}) : _logger = logger;

  static bool disabledForTests = false;

  final Talker _logger;

  final List<Timer> _timers = [];
  bool _isRunning = false;

  final StreamController<List<UnfiscalizedOperation>> _fiscErrorsController =
      StreamController<List<UnfiscalizedOperation>>.broadcast();

  Stream<List<UnfiscalizedOperation>> get fiscErrorsStream =>
      _fiscErrorsController.stream;

  List<UnfiscalizedOperation> _lastFiscErrors = const [];
  List<UnfiscalizedOperation> get lastFiscErrors => _lastFiscErrors;

  DataExchangeService? _dataExchangeService;

  OldSaleCleanupService? _cleanupService;

  UpdaterService? _updaterService;

  FiscErrorsService? _fiscErrorsService;

  DateTime? _lastFiscErrorsCheckDate;

  bool get isRunning => _isRunning;

  SyncResult? get lastSyncResult => _dataExchangeService?.lastSyncResult;

  CleanupResult? get lastCleanupResult => _cleanupService?.lastResult;

  OldSaleCleanupService? get cleanupService => _cleanupService;

  UpdaterService? get updaterService => _updaterService;

  FiscErrorsService? get fiscErrorsService => _fiscErrorsService;

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
    _startFiscErrorsTask();
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

    try {
      if (GetIt.I.isRegistered<FiscErrorsService>()) {
        _fiscErrorsService = GetIt.I<FiscErrorsService>();
        _logger.info(
          'FiscErrorsService initialized: '
          'nextCheck=${_fiscErrorsService!.getNextCheckTime()}',
        );
      } else {
        _logger.warning('FiscErrorsService not registered in DI');
      }
    } catch (e) {
      _logger.warning('Failed to initialize FiscErrorsService: $e');
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
    if (!_fiscErrorsController.isClosed) {
      _fiscErrorsController.close();
    }
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

  void _startFiscErrorsTask() {
    final timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _onFiscErrorsTick(),
    );
    _timers.add(timer);
    _logger.info('FiscErrors task started (daily at 12:00 Asia/Almaty)');
  }

  Future<void> _onFiscErrorsTick() async {
    if (_fiscErrorsService == null) {
      _logger.debug('FiscErrors tick — service not initialized');
      return;
    }

    if (!FiscErrorsSchedule.isCheckTimeNow()) {
      return;
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    if (_lastFiscErrorsCheckDate == todayDate) {
      return;
    }

    _lastFiscErrorsCheckDate = todayDate;
    _logger.info('FiscErrors tick — checking for unfiscalized operations');

    try {
      final errors = await _fiscErrorsService!.checkErrors();

      if (errors.isEmpty) {
        _logger.debug('FiscErrors: no unfiscalized operations');
      } else {
        _logger.warning(
          'FiscErrors: found ${errors.length} unfiscalized operations',
        );
        for (final error in errors) {
          _logger.warning(
            '  ${error.typeText} #${error.receiptNo}: ${error.lastError ?? "pending"}',
          );
        }

        _lastFiscErrors = List.unmodifiable(errors);
        if (!_fiscErrorsController.isClosed) {
          _fiscErrorsController.add(_lastFiscErrors);
        }
      }
    } catch (e, st) {
      _logger.handle(e, st, 'FiscErrors tick failed');
    }
  }
}
