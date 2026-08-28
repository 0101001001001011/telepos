import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';

class CleanupResult {
  final int deletedSales;

  final int deletedSaleProducts;

  final int deletedPayments;

  final DateTime cutoffDate;

  final Duration duration;

  final String? error;

  const CleanupResult({
    required this.deletedSales,
    required this.deletedSaleProducts,
    required this.deletedPayments,
    required this.cutoffDate,
    required this.duration,
    this.error,
  });

  bool get isSuccess => error == null;

  int get totalDeleted => deletedSales + deletedSaleProducts + deletedPayments;

  @override
  String toString() =>
      'CleanupResult(sales=$deletedSales, products=$deletedSaleProducts, '
      'payments=$deletedPayments, cutoff=$cutoffDate)';
}

class CleanupPreview {
  final int salesToDelete;

  final int saleProductsToDelete;

  final int paymentsToDelete;

  final DateTime cutoffDate;

  final int retentionDays;

  const CleanupPreview({
    required this.salesToDelete,
    required this.saleProductsToDelete,
    required this.paymentsToDelete,
    required this.cutoffDate,
    required this.retentionDays,
  });

  bool get hasDataToDelete => salesToDelete > 0;

  int get totalToDelete =>
      salesToDelete + saleProductsToDelete + paymentsToDelete;

  @override
  String toString() =>
      'CleanupPreview(sales=$salesToDelete, products=$saleProductsToDelete, '
      'payments=$paymentsToDelete, cutoff=$cutoffDate)';
}

class CleanupSettings {
  final int retentionDays;

  final bool onlySynced;

  final bool includeWithCustomer;

  final int minimumRetentionDays;

  const CleanupSettings({
    this.retentionDays = 90,
    this.onlySynced = true,
    this.includeWithCustomer = false,
    this.minimumRetentionDays = 30,
  });

  static const autonomousMode = CleanupSettings(
    retentionDays: 90,
    onlySynced: true,
    includeWithCustomer: false,
  );

  static const onlineMode = CleanupSettings(
    retentionDays: 7,
    onlySynced: true,
    includeWithCustomer: false,
  );

  CleanupSettings copyWith({
    int? retentionDays,
    bool? onlySynced,
    bool? includeWithCustomer,
    int? minimumRetentionDays,
  }) {
    return CleanupSettings(
      retentionDays: retentionDays ?? this.retentionDays,
      onlySynced: onlySynced ?? this.onlySynced,
      includeWithCustomer: includeWithCustomer ?? this.includeWithCustomer,
      minimumRetentionDays: minimumRetentionDays ?? this.minimumRetentionDays,
    );
  }
}

class OldSaleCleanupService {
  final Talker _logger;
  final AppDatabase _db;

  CleanupSettings _settings;

  CleanupResult? _lastResult;

  OldSaleCleanupService({
    required Talker logger,
    required AppDatabase db,
    CleanupSettings? settings,
  }) : _logger = logger,
       _db = db,
       _settings = settings ?? CleanupSettings.autonomousMode;

  CleanupSettings get settings => _settings;

  CleanupResult? get lastResult => _lastResult;

  void updateSettings(CleanupSettings settings) {
    _settings = settings;
    _logger.info(
      'CleanupSettings updated: retentionDays=${settings.retentionDays}',
    );
  }

  Future<CleanupPreview> preview({int? days}) async {
    final retentionDays = days ?? _settings.retentionDays;
    final cutoffDate = _calculateCutoffDate(retentionDays);
    final cutoffTimestamp = cutoffDate.millisecondsSinceEpoch ~/ 1000;

    _logger.debug(
      'Cleanup preview: retentionDays=$retentionDays, cutoff=$cutoffDate',
    );

    try {
      final salesToDelete = await _findSalesToDelete(cutoffTimestamp);
      final salesCount = salesToDelete.length;

      if (salesCount == 0) {
        return CleanupPreview(
          salesToDelete: 0,
          saleProductsToDelete: 0,
          paymentsToDelete: 0,
          cutoffDate: cutoffDate,
          retentionDays: retentionDays,
        );
      }

      final saleKeys = salesToDelete
          .map((s) => (receiptNo: s.receiptNo, posId: s.posId))
          .toList();

      final productsCount = await _countRelatedProducts(saleKeys);
      final paymentsCount = await _countRelatedPayments(saleKeys);

      return CleanupPreview(
        salesToDelete: salesCount,
        saleProductsToDelete: productsCount,
        paymentsToDelete: paymentsCount,
        cutoffDate: cutoffDate,
        retentionDays: retentionDays,
      );
    } catch (e) {
      _logger.error('Cleanup preview failed: $e');
      rethrow;
    }
  }

  Future<CleanupResult> cleanup() async {
    return _executeCleanup(_settings.retentionDays, isManual: false);
  }

  Future<CleanupResult> manualCleanup({required int days}) async {
    if (days < _settings.minimumRetentionDays) {
      final error =
          'Retention days must be >= ${_settings.minimumRetentionDays}';
      _logger.warning(error);
      return CleanupResult(
        deletedSales: 0,
        deletedSaleProducts: 0,
        deletedPayments: 0,
        cutoffDate: DateTime.now(),
        duration: Duration.zero,
        error: error,
      );
    }

    return _executeCleanup(days, isManual: true);
  }

  Future<CleanupResult> _executeCleanup(
    int retentionDays, {
    required bool isManual,
  }) async {
    final stopwatch = Stopwatch()..start();
    final cutoffDate = _calculateCutoffDate(retentionDays);
    final cutoffTimestamp = cutoffDate.millisecondsSinceEpoch ~/ 1000;

    _logger.info(
      'Starting ${isManual ? "manual" : "automatic"} cleanup: '
      'retentionDays=$retentionDays, cutoff=$cutoffDate',
    );

    try {
      final salesToDelete = await _findSalesToDelete(cutoffTimestamp);

      if (salesToDelete.isEmpty) {
        _logger.info('No old sales to delete');
        final result = CleanupResult(
          deletedSales: 0,
          deletedSaleProducts: 0,
          deletedPayments: 0,
          cutoffDate: cutoffDate,
          duration: stopwatch.elapsed,
        );
        _lastResult = result;
        return result;
      }

      final saleKeys = salesToDelete
          .map((s) => (receiptNo: s.receiptNo, posId: s.posId))
          .toList();

      int deletedProducts = 0;
      int deletedPayments = 0;
      int deletedSales = 0;

      await _db.transaction(() async {
        deletedProducts = await _deleteRelatedProducts(saleKeys);

        deletedPayments = await _deleteRelatedPayments(saleKeys);

        deletedSales = await _deleteSales(saleKeys);
      });

      stopwatch.stop();

      final result = CleanupResult(
        deletedSales: deletedSales,
        deletedSaleProducts: deletedProducts,
        deletedPayments: deletedPayments,
        cutoffDate: cutoffDate,
        duration: stopwatch.elapsed,
      );

      _lastResult = result;

      _logger.info(
        'Cleanup completed: deleted $deletedSales sales, '
        '$deletedProducts products, $deletedPayments payments '
        '(${stopwatch.elapsed.inMilliseconds}ms)',
      );

      return result;
    } catch (e, st) {
      stopwatch.stop();
      _logger.handle(e, st, 'Cleanup failed');

      final result = CleanupResult(
        deletedSales: 0,
        deletedSaleProducts: 0,
        deletedPayments: 0,
        cutoffDate: cutoffDate,
        duration: stopwatch.elapsed,
        error: e.toString(),
      );
      _lastResult = result;
      return result;
    }
  }

  DateTime _calculateCutoffDate(int retentionDays) {
    return DateTime.now().subtract(Duration(days: retentionDays));
  }

  Future<List<Sale>> _findSalesToDelete(int cutoffTimestamp) async {
    if (_settings.includeWithCustomer) {
      return _db.saleDao.findOldSyncedSales(cutoffTimestamp);
    } else {
      return _db.saleDao.findSalesToDelete(cutoffTimestamp);
    }
  }

  Future<int> _countRelatedProducts(
    List<({int receiptNo, int posId})> saleKeys,
  ) async {
    int count = 0;
    for (final key in saleKeys) {
      count += await _db.saleProductDao.countBySale(key.receiptNo, key.posId);
    }
    return count;
  }

  Future<int> _countRelatedPayments(
    List<({int receiptNo, int posId})> saleKeys,
  ) async {
    int count = 0;
    for (final key in saleKeys) {
      count += await _db.paymentDao.countBySale(key.receiptNo, key.posId);
    }
    return count;
  }

  Future<int> _deleteRelatedProducts(
    List<({int receiptNo, int posId})> saleKeys,
  ) async {
    int deleted = 0;
    for (final key in saleKeys) {
      deleted += await _db.saleProductDao.deleteBySale(
        key.receiptNo,
        key.posId,
      );
    }
    return deleted;
  }

  Future<int> _deleteRelatedPayments(
    List<({int receiptNo, int posId})> saleKeys,
  ) async {
    int deleted = 0;
    for (final key in saleKeys) {
      deleted += await _db.paymentDao.deleteBySale(key.receiptNo, key.posId);
    }
    return deleted;
  }

  Future<int> _deleteSales(List<({int receiptNo, int posId})> saleKeys) async {
    int deleted = 0;
    for (final key in saleKeys) {
      deleted += await _db.saleDao.deleteSale(key.receiptNo, key.posId);
    }
    return deleted;
  }
}
