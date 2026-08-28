import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/app/config/background_task_manager.dart';
import 'package:telepos/app/config/initialization_task.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/services/currency_service.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';

class DatabaseInitializationException implements Exception {
  const DatabaseInitializationException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'DatabaseInitializationException: $message';
}

/// The local implementation of [AppBootstrap]: opens the database, loads the
/// configuration, runs the initialization task and starts the background jobs
/// in this process. The binding a desktop till or the appliance uses.
class AppDomainDelegate implements AppBootstrap {
  AppDomainDelegate({required Talker logger})
    : _logger = logger,
      _initializationTask = InitializationTask(logger: logger),
      _backgroundTasks = BackgroundTaskManager(logger: logger);

  final Talker _logger;
  final InitializationTask _initializationTask;
  final BackgroundTaskManager _backgroundTasks;

  AppInitStatus? _status;
  AppInitStatus? get status => _status;

  String _currency = 'KZT';
  String get currency => _currency;

  BackgroundTaskManager get backgroundTasks => _backgroundTasks;

  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async {
    _logger.info('AppDomainDelegate: starting domain initialization');

    try {
      onProgress(0.1, 'Проверка ключа POS...');
      final hasKey = await _checkPosKey();
      if (!hasKey) {
        _status = AppInitStatus.noKey;
        _logger.warning('AppDomainDelegate: POS key not found');
        return _status!;
      }

      onProgress(0.25, 'Загрузка конфигурации...');
      await _setCurrency();

      onProgress(0.4, 'Инициализация базы данных...');
      await _initializeDatabase();

      onProgress(0.6, 'Загрузка данных POS...');
      final initResult = await _runInitializationTask(onProgress);
      if (initResult != AppInitStatus.success) {
        _status = initResult;
        return _status!;
      }

      onProgress(0.85, 'Проверка лицензии...');
      await _checkLicense();

      onProgress(0.95, 'Запуск фоновых задач...');
      await _backgroundTasks.startAll();

      onProgress(1.0, 'Готово');
      _status = AppInitStatus.success;
      _logger.info('AppDomainDelegate: initialization completed successfully');

      return _status!;
    } on DatabaseInitializationException catch (e, st) {
      _logger.handle(
        e,
        st,
        'AppDomainDelegate: database initialization failed',
      );
      _status = AppInitStatus.databaseFailure;
      return _status!;
    } catch (e, st) {
      _logger.handle(e, st, 'AppDomainDelegate: initialization failed');
      _status = AppInitStatus.absentMandatoryData;
      return _status!;
    }
  }

  void dispose() {
    _backgroundTasks.dispose();
    _logger.info('AppDomainDelegate: disposed');
  }

  Future<bool> _checkPosKey() async {
    _logger.info('POS key check: offline ALLOW (standalone mode permitted)');
    return true;
  }

  Future<void> _setCurrency() async {
    try {
      if (GetIt.I.isRegistered<CurrencyService>()) {
        final currencyService = GetIt.I<CurrencyService>();
        await currencyService.load();
        _currency = currencyService.code;
        _logger.info(
          'Currency loaded: ${currencyService.code} (${currencyService.symbol}), '
          'country: ${currencyService.country.countryName}',
        );
      } else {
        _currency = 'KZT';
        _logger.warning(
          'CurrencyService not registered, using default: $_currency',
        );
      }
    } catch (e) {
      _currency = 'KZT';
      _logger.error('Failed to load currency, using default: $_currency', e);
    }
  }

  Future<void> _initializeDatabase() async {
    try {
      if (!GetIt.I.isRegistered<AppDatabase>()) {
        throw StateError('AppDatabase not registered in DI');
      }

      final db = GetIt.I<AppDatabase>();

      final result = await db.customSelect('SELECT 1 AS test').getSingle();
      if (result.data['test'] != 1) {
        throw StateError('Database connection test failed');
      }

      final schemaVersion = db.schemaVersion;
      _logger.info(
        'Database initialized successfully: '
        'schema v$schemaVersion, '
        'tables: ${db.allTables.length}',
      );

      await _checkDatabaseIntegrity(db);
    } catch (e, st) {
      _logger.handle(e, st, 'Database initialization failed');
      throw DatabaseInitializationException(
        'Failed to initialize database: ${e.runtimeType}',
        e,
      );
    }
  }

  Future<void> _checkDatabaseIntegrity(AppDatabase db) async {
    try {
      final result = await db.customSelect('PRAGMA integrity_check').get();
      if (result.isEmpty) {
        _logger.warning('Database integrity check returned empty result');
        return;
      }

      final firstRow = result.first.data;
      final status = firstRow['integrity_check'] as String?;

      if (status == 'ok') {
        _logger.info('Database integrity check: OK');
      } else {
        _logger.error('Database integrity issue detected: $status');
      }
    } catch (e) {
      _logger.warning('Could not perform integrity check: $e');
    }
  }

  Future<AppInitStatus> _runInitializationTask(
    void Function(double progress, String message) onProgress,
  ) async {
    return _initializationTask.run(
      onProgress: (taskProgress, message) {
        final mappedProgress = 0.4 + (taskProgress * 0.4);
        onProgress(mappedProgress, message);
      },
    );
  }

  Future<void> _checkLicense() async {
    final licenseStatus = await _validateLicenseOffline();

    switch (licenseStatus) {
      case LicenseStatus.valid:
        _logger.info('License: valid (offline mode)');
      case LicenseStatus.trial:
        _logger.info('License: trial mode (offline)');
      case LicenseStatus.expired:
        _logger.warning('License: expired (offline — continuing anyway)');
      case LicenseStatus.invalid:
        _logger.warning('License: invalid (offline — continuing anyway)');
    }
  }

  Future<LicenseStatus> _validateLicenseOffline() async {
    return LicenseStatus.valid;
  }
}

enum LicenseStatus { valid, trial, expired, invalid }
