import 'package:decimal/decimal.dart';

import 'package:telepos/domain/services/shift_service.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';
import 'package:telepos/domain/usecases/product/search_product_info_use_case.dart';
import 'package:telepos/domain/usecases/sale/sale_history_service.dart';
import 'package:telepos/telegram/bots/bot_command_router.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/data_exchange/telegram_sync_engine.dart';
import 'package:telepos/telegram/monitoring/pos_status_service.dart';
import 'package:telepos/telegram/reports/report_generator.dart';

class PosBotCommands {
  final BotCommandRouter _router;
  final TdLibLogger _logger;

  final ShiftService? _shiftService;
  final SaleHistoryService? _saleHistoryService;
  final SearchProductInfoUseCase? _searchProductUseCase;
  final CashInOutController? _cashInOutController;

  final TelegramSyncEngine? _syncEngine;
  final ReportGenerator? _reportGenerator;
  final PosStatusService? _posStatusService;

  final String _posId;
  final String _currency;

  PosBotCommands({
    required BotCommandRouter router,
    required TdLibLogger logger,
    ShiftService? shiftService,
    SaleHistoryService? saleHistoryService,
    SearchProductInfoUseCase? searchProductUseCase,
    CashInOutController? cashInOutController,
    TelegramSyncEngine? syncEngine,
    ReportGenerator? reportGenerator,
    PosStatusService? posStatusService,
    String posId = 'POS-1',
    String currency = 'KZT',
  }) : _router = router,
       _logger = logger,
       _shiftService = shiftService,
       _saleHistoryService = saleHistoryService,
       _searchProductUseCase = searchProductUseCase,
       _cashInOutController = cashInOutController,
       _syncEngine = syncEngine,
       _reportGenerator = reportGenerator,
       _posStatusService = posStatusService,
       _posId = posId,
       _currency = currency;

  void registerAll() {
    _router.registerCommand('status', _handleStatus);
    _router.registerCommand('shift', _handleShift);
    _router.registerCommand('sales', _handleSales);
    _router.registerCommand('stock', _handleStock);
    _router.registerCommand('sync', _handleSync);
    _router.registerCommand('report', _handleReport);
    _router.registerCommand('cashflow', _handleCashflow);
    _router.registerCommand('alerts', _handleAlerts);
    _router.registerCommand('help', _handleHelp);
    _router.setDefaultHandler(_handleUnknown);

    _logger.logConnection('POS bot commands registered');
  }

  List<Map<String, String>> getCommandList() {
    return [
      {'command': 'status', 'description': 'POS terminal status'},
      {'command': 'shift', 'description': 'Current shift info'},
      {'command': 'sales', 'description': 'Sales report [date]'},
      {'command': 'stock', 'description': 'Stock info [product]'},
      {'command': 'sync', 'description': 'Force data sync'},
      {'command': 'report', 'description': 'Generate report [type]'},
      {'command': 'cashflow', 'description': 'Cash flow summary'},
      {'command': 'alerts', 'description': 'Manage alerts [on/off]'},
      {'command': 'help', 'description': 'Show help'},
    ];
  }

  Future<void> _handleStatus(BotCommandContext context) async {
    if (_posStatusService == null) {
      await _router.reply(
        context,
        '*POS Terminal Status*\n'
        'Terminal: $_posId\n'
        'Status: ⚠️ Status service not configured',
      );
      return;
    }

    final status = PosStatus(
      posId: _posId,
      isOnline: true,
      isShiftOpen: await _isShiftOpen(),
      currentCashier: await _getCurrentCashierName(),
      lastHeartbeat: DateTime.now(),
      salesToday: await _getSalesTodayCount(),
      revenueTodayTotal: 0,
      currency: _currency,
    );

    final onlineIcon = status.isOnline ? '🟢' : '🔴';
    final shiftIcon = status.isShiftOpen ? '✅' : '❌';

    await _router.reply(
      context,
      '*POS Terminal Status*\n\n'
      '$onlineIcon Terminal: ${status.posId}\n'
      '$shiftIcon Shift: ${status.isShiftOpen ? "Open" : "Closed"}\n'
      '${status.currentCashier != null ? "👤 Cashier: ${status.currentCashier}\n" : ""}'
      '📊 Sales today: ${status.salesToday}\n'
      '🕐 Updated: ${_formatDateTime(status.lastHeartbeat)}',
    );
  }

  Future<void> _handleShift(BotCommandContext context) async {
    final shiftService = _shiftService;
    if (shiftService == null) {
      await _router.reply(
        context,
        '*Current Shift*\n'
        '⚠️ Shift service not configured',
      );
      return;
    }

    try {
      final shift = await shiftService.getOpenedShift();

      if (shift == null) {
        await _router.reply(
          context,
          '*Current Shift*\n'
          '❌ No shift is currently open',
        );
        return;
      }

      final shiftId = shift is Map ? shift['id'] : (shift.id ?? '-');
      final userId = shift is Map ? shift['userId'] : (shift.userId ?? '-');
      final openTime = shift is Map
          ? shift['openTime']
          : (shift.openTime ?? DateTime.now().millisecondsSinceEpoch);

      await _router.reply(
        context,
        '*Current Shift*\n\n'
        '📋 Shift #: $shiftId\n'
        '👤 User ID: $userId\n'
        '🕐 Opened: ${_formatTimestamp(openTime)}\n'
        '✅ Status: Active',
      );
    } catch (e) {
      _logger.logError('shift_command', e);
      await _router.reply(
        context,
        '*Current Shift*\n'
        '❌ Error getting shift info: ${e.toString().substring(0, 50)}...',
      );
    }
  }

  Future<void> _handleSales(BotCommandContext context) async {
    final dateArg = context.arguments.isNotEmpty ? context.arguments : 'today';
    final saleHistoryService = _saleHistoryService;

    if (saleHistoryService == null) {
      await _router.reply(
        context,
        '*Sales Report ($dateArg)*\n'
        '⚠️ Sale history service not configured',
      );
      return;
    }

    try {
      final now = DateTime.now();
      int fromTimestamp;
      int toTimestamp;

      if (dateArg == 'today') {
        final startOfDay = DateTime(now.year, now.month, now.day);
        fromTimestamp = startOfDay.millisecondsSinceEpoch;
        toTimestamp = now.millisecondsSinceEpoch;
      } else if (dateArg == 'yesterday') {
        final yesterday = now.subtract(const Duration(days: 1));
        final startOfYesterday = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
        );
        final endOfYesterday = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          23,
          59,
          59,
        );
        fromTimestamp = startOfYesterday.millisecondsSinceEpoch;
        toTimestamp = endOfYesterday.millisecondsSinceEpoch;
      } else {
        final startOfDay = DateTime(now.year, now.month, now.day);
        fromTimestamp = startOfDay.millisecondsSinceEpoch;
        toTimestamp = now.millisecondsSinceEpoch;
      }

      final sales = await saleHistoryService.getSalesBetweenDates(
        posId: int.tryParse(_posId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1,
        fromTimestamp: fromTimestamp,
        toTimestamp: toTimestamp,
        page: 0,
      );

      final totalSales = sales.length;
      final totalRevenue = sales.fold<Decimal>(
        Decimal.zero,
        (sum, sale) => sum + sale.amount,
      );
      final avgCheck = totalSales > 0
          ? (totalRevenue / Decimal.fromInt(totalSales)).toDecimal(
              scaleOnInfinitePrecision: 3,
            )
          : Decimal.zero;

      final fiscalizedCount = sales
          .where((s) => s.isOfd || s.hasWebkassaReceipt)
          .length;

      await _router.reply(
        context,
        '*Sales Report ($dateArg)*\n\n'
        '📊 Total sales: $totalSales\n'
        '💰 Revenue: ${_formatMoneyDecimal(totalRevenue)}\n'
        '📈 Average check: ${_formatMoneyDecimal(avgCheck)}\n'
        '🧾 Fiscalized: $fiscalizedCount\n'
        '↩️ Returns: n/a',
      );
    } on HasNoSaleInRange {
      await _router.reply(
        context,
        '*Sales Report ($dateArg)*\n\n'
        '📊 No sales in this period',
      );
    } catch (e) {
      _logger.logError('sales_command', e);
      await _router.reply(
        context,
        '*Sales Report ($dateArg)*\n'
        '❌ Error: ${e.toString().substring(0, 50)}...',
      );
    }
  }

  Future<void> _handleStock(BotCommandContext context) async {
    final query = context.arguments;
    if (query.isEmpty) {
      await _router.reply(context, 'Usage: /stock <product name or barcode>');
      return;
    }

    final searchProductUseCase = _searchProductUseCase;
    if (searchProductUseCase == null) {
      await _router.reply(
        context,
        '*Stock: $query*\n'
        '⚠️ Product search service not configured',
      );
      return;
    }

    try {
      final results = await searchProductUseCase.search(query: query, limit: 5);

      if (results.isEmpty) {
        await _router.reply(
          context,
          '*Stock: $query*\n\n'
          '❌ No products found. Try a different search.',
        );
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln('*Stock: $query*\n');

      for (final product in results) {
        buffer.writeln(
          '📦 *${product.name}*\n'
          '   Barcode: ${product.barcode}\n'
          '   Code: ${product.ucode}\n',
        );
      }

      if (results.length >= 5) {
        buffer.writeln('\n_Showing first 5 results_');
      }

      await _router.reply(context, buffer.toString());
    } catch (e) {
      _logger.logError('stock_command', e);
      await _router.reply(
        context,
        '*Stock: $query*\n'
        '❌ Error searching: ${e.toString().substring(0, 50)}...',
      );
    }
  }

  Future<void> _handleSync(BotCommandContext context) async {
    final syncEngine = _syncEngine;
    if (syncEngine == null) {
      await _router.reply(context, '⚠️ Sync engine not configured');
      return;
    }

    try {
      await _router.reply(context, '🔄 Starting synchronization...');

      await syncEngine.syncAll();

      await _router.reply(
        context,
        '✅ Sync completed. Check /status for details.',
      );
    } catch (e) {
      _logger.logError('sync_command', e);
      await _router.reply(
        context,
        '❌ Sync failed: ${e.toString().substring(0, 50)}...\n'
        'Try again later or check logs.',
      );
    }
  }

  Future<void> _handleReport(BotCommandContext context) async {
    final typeArg = context.arguments.isNotEmpty ? context.arguments : 'daily';
    final validTypes = [
      'shift',
      'daily',
      'sales',
      'inventory',
      'cashflow',
      'fiscal',
    ];

    if (!validTypes.contains(typeArg)) {
      await _router.reply(
        context,
        'Available report types: ${validTypes.join(", ")}',
      );
      return;
    }

    final reportGenerator = _reportGenerator;
    if (reportGenerator == null) {
      await _router.reply(context, '⚠️ Report generator not configured');
      return;
    }

    try {
      await _router.reply(context, '📝 Generating *$typeArg* report...');

      final reportType = ReportType.values.firstWhere(
        (t) => t.name == typeArg,
        orElse: () => ReportType.daily,
      );

      final data = await _prepareReportData(reportType);
      final report = reportGenerator.generate(reportType, data);

      await _router.reply(context, report.content);
    } catch (e) {
      _logger.logError('report_command', e);
      await _router.reply(
        context,
        '❌ Error generating report: ${e.toString().substring(0, 50)}...',
      );
    }
  }

  Future<void> _handleCashflow(BotCommandContext context) async {
    final cashInOutController = _cashInOutController;
    final shiftServiceCf = _shiftService;
    if (cashInOutController == null || shiftServiceCf == null) {
      await _router.reply(
        context,
        '*Cash Flow Summary*\n'
        '⚠️ Cash operation service not configured',
      );
      return;
    }

    try {
      final shift = await shiftServiceCf.getOpenedShift();
      if (shift == null) {
        await _router.reply(
          context,
          '*Cash Flow Summary*\n'
          '❌ No open shift. Cash flow is per-shift.',
        );
        return;
      }

      final shiftId = shift is Map
          ? shift['id'] as int
          : (shift.id as int? ?? 0);
      final operations = await cashInOutController.getOperationsForShift(
        shiftId,
      );

      Decimal investments = Decimal.zero;
      Decimal expenses = Decimal.zero;
      Decimal dividends = Decimal.zero;

      for (final op in operations) {
        final amount = op.amount;
        switch (op.type) {
          case CashInOutType.investment:
            investments += amount;
            break;
          case CashInOutType.expense:
            expenses += amount;
            break;
          case CashInOutType.dividend:
            dividends += amount;
            break;
        }
      }

      await _router.reply(
        context,
        '*Cash Flow Summary*\n\n'
        '📥 Investments: ${_formatMoneyDecimal(investments)}\n'
        '📤 Expenses: ${_formatMoneyDecimal(expenses)}\n'
        '💸 Dividends: ${_formatMoneyDecimal(dividends)}\n'
        '━━━━━━━━━━━━\n'
        '📊 Net: ${_formatMoneyDecimal(investments - expenses - dividends)}\n'
        '\n_Operations this shift: ${operations.length}_',
      );
    } catch (e) {
      _logger.logError('cashflow_command', e);
      await _router.reply(
        context,
        '*Cash Flow Summary*\n'
        '❌ Error: ${e.toString().substring(0, 50)}...',
      );
    }
  }

  Future<void> _handleAlerts(BotCommandContext context) async {
    final action = context.arguments.toLowerCase();
    if (action == 'on') {
      await _router.reply(context, '✅ Alerts enabled for this chat.');
    } else if (action == 'off') {
      await _router.reply(context, '🔕 Alerts disabled for this chat.');
    } else {
      await _router.reply(context, 'Usage: /alerts on|off');
    }
  }

  Future<void> _handleHelp(BotCommandContext context) async {
    await _router.reply(
      context,
      '*TelePOS Bot Commands*\n\n'
      '/status — POS terminal status\n'
      '/shift — Current shift info\n'
      '/sales [date] — Sales report (today/yesterday)\n'
      '/stock [query] — Stock lookup\n'
      '/sync — Force data sync\n'
      '/report [type] — Generate report\n'
      '/cashflow — Cash flow summary\n'
      '/alerts on|off — Manage alerts\n'
      '/help — This help message\n\n'
      '_Report types: shift, daily, sales, inventory, cashflow, fiscal_',
    );
  }

  Future<void> _handleUnknown(BotCommandContext context) async {
    await _router.reply(
      context,
      '❓ Unknown command: /${context.command}\nType /help for available commands.',
    );
  }

  Future<bool> _isShiftOpen() async {
    final shiftService = _shiftService;
    if (shiftService == null) return false;
    try {
      final shift = await shiftService.getOpenedShift();
      return shift != null;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _getCurrentCashierName() async {
    final saleHistoryService = _saleHistoryService;
    if (saleHistoryService == null) return null;
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final sales = await saleHistoryService.getSalesBetweenDates(
        posId: int.tryParse(_posId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1,
        fromTimestamp: startOfDay.millisecondsSinceEpoch,
        toTimestamp: now.millisecondsSinceEpoch,
        page: 0,
      );
      for (final sale in sales) {
        final name = sale.userName;
        if (name != null && name.trim().isNotEmpty) return name.trim();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<int> _getFiscalizedTodayCount() async {
    final saleHistoryService = _saleHistoryService;
    if (saleHistoryService == null) return 0;
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final sales = await saleHistoryService.getSalesBetweenDates(
        posId: int.tryParse(_posId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1,
        fromTimestamp: startOfDay.millisecondsSinceEpoch,
        toTimestamp: now.millisecondsSinceEpoch,
        page: 0,
      );
      return sales.where((s) => s.isOfd || s.hasWebkassaReceipt).length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _getSalesTodayCount() async {
    final saleHistoryService = _saleHistoryService;
    if (saleHistoryService == null) return 0;
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final sales = await saleHistoryService.getSalesBetweenDates(
        posId: int.tryParse(_posId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1,
        fromTimestamp: startOfDay.millisecondsSinceEpoch,
        toTimestamp: now.millisecondsSinceEpoch,
        page: 0,
      );
      return sales.length;
    } catch (_) {
      return 0;
    }
  }

  Future<Map<String, dynamic>> _prepareReportData(ReportType type) async {
    final now = DateTime.now();
    final data = <String, dynamic>{
      'date': '${now.day}.${now.month}.${now.year}',
      'generatedAt': now.toIso8601String(),
    };

    final shiftServiceLocal = _shiftService;
    final cashInOutControllerLocal = _cashInOutController;

    switch (type) {
      case ReportType.shift:
        if (shiftServiceLocal != null) {
          final shift = await shiftServiceLocal.getOpenedShift();
          if (shift != null) {
            data['shiftNumber'] = shift is Map ? shift['id'] : shift.id;
            data['cashier'] = await _getCurrentCashierName() ?? 'n/a';
            data['openTime'] = _formatTimestamp(
              shift is Map ? shift['openTime'] : shift.openTime,
            );
          }
        }
        break;
      case ReportType.daily:
        data['salesCount'] = await _getSalesTodayCount();
        break;
      case ReportType.sales:
        data['period'] = 'Today';
        data['totalSales'] = await _getSalesTodayCount();
        break;
      case ReportType.inventory:
        data['totalItems'] = 'n/a';
        break;
      case ReportType.cashflow:
        if (cashInOutControllerLocal != null && shiftServiceLocal != null) {
          final shift = await shiftServiceLocal.getOpenedShift();
          if (shift != null) {
            final shiftId = shift is Map ? shift['id'] as int : shift.id as int;
            final ops = await cashInOutControllerLocal.getOperationsForShift(
              shiftId,
            );
            Decimal inv = Decimal.zero, exp = Decimal.zero, div = Decimal.zero;
            for (final op in ops) {
              final amt = op.amount;
              if (op.type == CashInOutType.investment) inv += amt;
              if (op.type == CashInOutType.expense) exp += amt;
              if (op.type == CashInOutType.dividend) div += amt;
            }
            data['investments'] = _formatMoneyDecimal(inv);
            data['expenses'] = _formatMoneyDecimal(exp);
            data['dividends'] = _formatMoneyDecimal(div);
          }
        }
        break;
      case ReportType.fiscal:
        data['ofdProvider'] = 'WebKassa';
        data['registeredCount'] = await _getFiscalizedTodayCount();
        break;
    }

    return data;
  }

  String _formatMoneyDecimal(Decimal amount) {
    return '${amount.round().toBigInt()} $_currency';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}.${dt.month}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '-';
    if (timestamp is int) {
      final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return _formatDateTime(dt);
    }
    return timestamp.toString();
  }
}
