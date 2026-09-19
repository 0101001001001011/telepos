import 'dart:async';

import 'package:drift/drift.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/app/config/background_task_manager.dart'
    show BackgroundTaskManager;
import 'package:telepos/app/config/local_properties.dart';
import 'package:telepos/app/di/print_module.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/services/global_product_import_service.dart';
import 'package:telepos/domain/usecases/sale/last_sale_receipt_no_use_case.dart';

class InitializationTask {
  InitializationTask({required Talker logger}) : _logger = logger;

  final Talker _logger;

  AppDatabase get _db => GetIt.I<AppDatabase>();

  Future<AppInitStatus> run({
    required void Function(double progress, String message) onProgress,
  }) async {
    _logger.info('InitializationTask: starting');

    try {
      onProgress(0.0, 'Загрузка конфигурации...');
      await _loadPosConfiguration();

      onProgress(0.15, 'Загрузка контрагентов...');
      await _loadAgents();

      onProgress(0.30, 'Загрузка счетов...');
      await _loadAccounts();

      onProgress(0.45, 'Загрузка кассиров...');
      await _loadUsers();

      onProgress(0.60, 'Загрузка товаров...');
      await _loadProducts();

      onProgress(0.75, 'Проверка нумерации чеков...');
      await _loadLastReceiptNo();

      onProgress(0.85, 'Проверка отчётов...');
      await _loadLastReport();

      onProgress(0.95, 'Завершение инициализации...');
      await _setIsSyncedOnce();
      _schedulePrintQueueStart();

      onProgress(1.0, 'Данные загружены');
      _logger.info('InitializationTask: completed successfully');

      return AppInitStatus.success;
    } catch (e, st) {
      _logger.handle(e, st, 'InitializationTask: failed');
      return AppInitStatus.absentMandatoryData;
    }
  }

  Future<void> _loadPosConfiguration() async {
    final thisPos = await _db.thisPosDao.get();
    if (thisPos == null) {
      _logger.debug('POS configuration: not configured yet (first run)');
      return;
    }

    if (thisPos.id == null) {
      _logger.info('POS configuration: id is null, assigning local id=1');
      await _db.thisPosDao.upsert(const ThisPosEntriesCompanion(id: Value(1)));
    }

    _logger.debug('POS configuration: checked (id=${thisPos.id ?? 1})');
  }

  Future<void> _loadAgents() async {
    final totalCount = await _db.agentDao.count();
    final supplierCount = await _db.agentDao.countSuppliers();
    final customerCount = await _db.agentDao.countCustomers();

    _logger.info(
      'Agents in DB: total=$totalCount '
      '(suppliers=$supplierCount, customers=$customerCount)',
    );

    if (totalCount == 0) {
      _logger.debug('No agents found — first run or clean DB');
    }
  }

  Future<void> _loadAccounts() async {
    final stats = await _db.accountDao.getStats();
    _logger.info('Accounts in DB: $stats');

    if (stats.posAccounts == 0) {
      _logger.warning(
        'No POS account found — may indicate incomplete initial setup',
      );
    }

    if (stats.teleposMainAccounts == 0) {
      _logger.debug(
        'No TelePOS main account — Telegram transport not configured',
      );
    }
  }

  Future<void> _loadUsers() async {
    final stats = await _db.userDao.getStats();
    _logger.info('Users in DB: $stats');

    if (stats.owners == 0) {
      _logger.warning('No owner found — may indicate incomplete initial setup');
    }

    if (stats.active == 0) {
      _logger.warning('No active users found');
    } else if (stats.active < stats.total) {
      _logger.debug('${stats.total - stats.active} inactive/blocked users');
    }
  }

  Future<void> _loadProducts() async {
    final productStats = await _db.productInfoDao.getStats();
    _logger.info('Local products in DB: $productStats');

    final priceCount = await _db.productPriceDao.count();
    _logger.info('Product prices in DB: $priceCount');

    final globalCount = await _db.globalProductDao.count();
    _logger.info('Global products catalog: $globalCount');

    if (globalCount < 100000 || priceCount < 100000) {
      _logger.info(
        'Catalog incomplete (global: $globalCount, prices: $priceCount) '
        '— initiating background import',
      );
      _scheduleGlobalProductImport();
    }

    final quickCount = await _db.quickProductDao.count();
    if (quickCount > 0) {
      _logger.debug('Quick products: $quickCount');
    }
  }

  /// Будит очередь печати после запуска программы.
  ///
  /// Задание, застигнутое перезапуском на середине записи в принтер, само из
  /// состояния `printing` не выйдет, а задание, просто оставшееся в очереди со
  /// вчерашнего дня, дождалось бы только следующей продажи: деньги взяты
  /// вчера, принтер починили утром, а чек стоит, потому что никто не печатал.
  /// `PrintQueueLocal.start()` разбирает оба случая.
  ///
  /// Отключается в тестах тем же флагом, что и остальные фоновые задачи:
  /// очередь заводит таймер пробуждения, как только у неё появляется активное
  /// задание, а таймер, оставшийся к концу виджет-теста, роняет его
  /// («A Timer is still pending…») — причём в тестах, которые печати вообще не
  /// касаются.
  void _schedulePrintQueueStart() {
    if (BackgroundTaskManager.disabledForTests) return;
    unawaited(startPrintQueue(GetIt.I, logger: _logger));
  }

  void _scheduleGlobalProductImport() {
    if (BackgroundTaskManager.disabledForTests) return;
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        if (!GetIt.I.isRegistered<GlobalProductImportService>()) {
          _logger.warning('GlobalProductImportService not registered');
          return;
        }

        final importService = GetIt.I<GlobalProductImportService>();

        if (!await importService.needsImport()) {
          _logger.debug('Global catalog already imported');
          return;
        }

        _logger.info('Starting global product catalog import...');

        final imported = await importService.import(
          onProgress: (progress, message) {
            if (progress == 0.0 ||
                progress == 0.5 ||
                progress == 1.0 ||
                progress >= 0.99) {
              _logger.debug(
                'Global import: ${(progress * 100).toInt()}% — $message',
              );
            }
          },
        );

        _logger.info('Global product catalog imported: $imported products');
      } catch (e, st) {
        _logger.handle(e, st, 'Failed to import global product catalog');
      }
    });
  }

  Future<void> _loadLastReceiptNo() async {
    final lastReceiptNo = await _db.saleDao.findLastReceiptNo() ?? 0;
    final nextReceiptNo = lastReceiptNo + 1;

    _logger.info('Receipt numbers: last=$lastReceiptNo, next=$nextReceiptNo');

    try {
      if (GetIt.I.isRegistered<LastSaleReceiptNoUseCase>()) {
        final useCase = GetIt.I<LastSaleReceiptNoUseCase>();
        await useCase.perform();
        _logger.debug('LastSaleReceiptNoUseCase executed');
      }
    } catch (e) {
      _logger.warning('LastSaleReceiptNoUseCase failed: $e');
    }

    // `findInProgress()` берёт довод — чек **своего** рабочего места
    // (v37, задача 3 плана «продажа с браузерного терминала»). Здесь же
    // ничего не решается, только пишется журнал старта кассы, а с v37
    // рабочих мест на одной кассе может быть больше одного одновременно —
    // логировать нужно каждый чек в работе, а не первый попавшийся:
    // первый попавшийся молча показал бы одну корзину из двух и соврал бы
    // при разборе живых случаев.
    final inProgressSales = await _db.saleDao.findByState(0);
    for (final sale in inProgressSales) {
      _logger.debug(
        'Found in-progress sale: receiptNo=${sale.receiptNo}, '
        'terminalId=${sale.terminalId}',
      );
    }

    await _logSaleStats();
  }

  Future<void> _logSaleStats() async {
    final inProgress = await _db.saleDao.countWithState(0);
    final pendingSync = await _db.saleDao.countWithState(1);
    final beingSent = await _db.saleDao.countWithState(2);
    final deferred = await _db.saleDao.countWithState(3);
    final synced = await _db.saleDao.countWithState(4);

    final total = inProgress + pendingSync + beingSent + deferred + synced;

    if (total > 0) {
      _logger.debug(
        'Sales stats: total=$total '
        '(inProgress=$inProgress, pendingSync=$pendingSync, '
        'beingSent=$beingSent, deferred=$deferred, synced=$synced)',
      );
    } else {
      _logger.debug('No sales in database');
    }
  }

  Future<void> _loadLastReport() async {
    final stats = await _db.shiftDao.getStats();
    _logger.info('Shifts in DB: $stats');

    final openedShift = await _db.shiftDao.findOpenedShift();
    if (openedShift != null) {
      _logger.info(
        'Found open shift: id=${openedShift.id}, '
        'userId=${openedShift.userId}, '
        'openTime=${_formatTimestamp(openedShift.openTime)}',
      );
    }

    if (stats.total == 0) {
      _logger.debug('No shifts in database — first run');
      return;
    }

    final lastClosed = await _db.shiftDao.findLastClosed();
    if (lastClosed != null) {
      _logger.debug(
        'Last closed shift: id=${lastClosed.id}, '
        'closeTime=${_formatTimestamp(lastClosed.closeTime)}, '
        'synced=${lastClosed.isSynced}',
      );
    }

    if (stats.unsynced > 0) {
      _logger.warning(
        '${stats.unsynced} unsynced shift reports pending upload',
      );
    }
  }

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null) return 'null';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _setIsSyncedOnce() async {
    try {
      if (GetIt.I.isRegistered<LocalProperties>()) {
        final localProperties = GetIt.I<LocalProperties>();

        final wasAlreadySynced = localProperties.isSyncedOnce;

        if (!wasAlreadySynced) {
          localProperties.isSyncedOnce = true;
          _logger.info(
            'IsSyncedOnce flag: set to true (first successful init)',
          );
        } else {
          _logger.debug('IsSyncedOnce flag: already true (subsequent launch)');
        }
      } else {
        _logger.warning('LocalProperties not registered in DI');
      }
    } catch (e) {
      _logger.warning('Failed to set isSyncedOnce flag: $e');
    }
  }

  static Future<bool> wasAlreadyInitialized() async {
    try {
      if (GetIt.I.isRegistered<LocalProperties>()) {
        return GetIt.I<LocalProperties>().isSyncedOnce;
      }
    } catch (_) {}
    return false;
  }
}
