import 'dart:async';

import 'package:telepos/telegram/channels/channel_registry.dart';
import 'package:telepos/telegram/channels/channel_types.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/messaging/message_formatter.dart';
import 'package:telepos/telegram/messaging/message_service.dart';
import 'package:telepos/telegram/monitoring/metrics_collector.dart';

class DashboardFeed {
  final MessageService _messageService;
  final MetricsCollector _metricsCollector;
  final ChannelRegistry _channelRegistry;
  final MessageFormatter _formatter;
  final TdLibLogger _logger;

  Timer? _feedTimer;

  DashboardFeed({
    required MessageService messageService,
    required MetricsCollector metricsCollector,
    required ChannelRegistry channelRegistry,
    required TdLibLogger logger,
    MessageFormatter? formatter,
  }) : _messageService = messageService,
       _metricsCollector = metricsCollector,
       _channelRegistry = channelRegistry,
       _formatter = formatter ?? const MessageFormatter(),
       _logger = logger;

  Future<void> publishDailySummary({
    required String storeName,
    required num totalRevenue,
    required int totalSales,
    required int totalRefunds,
    required num averageCheck,
    required String currency,
    required int activePosCount,
  }) async {
    final chatId = _channelRegistry.getChatId(SystemChannelType.posReports);
    if (chatId == null) return;

    final text =
        '📊 ${_formatter.bold("Дневная сводка — $storeName")}\n'
        '${_formatter.separator}'
        '💰 Выручка: ${_formatter.bold(_formatter.money(totalRevenue, currency))}\n'
        '🧾 Продаж: $totalSales\n'
        '🔄 Возвратов: $totalRefunds\n'
        '📊 Средний чек: ${_formatter.money(averageCheck, currency)}\n'
        '🖥️ Активных POS: $activePosCount\n'
        '${_formatter.separator}'
        '🕐 ${_formatter.dateTime(DateTime.now())}';

    await _messageService.sendText(chatId, text);
    _logger.logConnection('Dashboard daily summary published');
  }

  Future<void> publishMetrics() async {
    final chatId = _channelRegistry.getChatId(SystemChannelType.posSystem);
    if (chatId == null) return;

    final snapshot = _metricsCollector.snapshot();
    final counters = snapshot['counters'] as Map<String, num>;
    final gauges = snapshot['gauges'] as Map<String, num>;

    final buffer = StringBuffer();
    buffer.writeln('📈 ${_formatter.bold("POS Метрики")}');
    buffer.writeln();

    if (counters.isNotEmpty) {
      buffer.writeln('📊 Счётчики:');
      for (final entry in counters.entries) {
        buffer.writeln('  ${entry.key}: ${entry.value}');
      }
      buffer.writeln();
    }

    if (gauges.isNotEmpty) {
      buffer.writeln('📉 Показатели:');
      for (final entry in gauges.entries) {
        buffer.writeln('  ${entry.key}: ${entry.value}');
      }
    }

    buffer.writeln();
    buffer.writeln('🕐 ${_formatter.dateTime(DateTime.now())}');

    await _messageService.sendSilent(chatId, buffer.toString());
  }

  void startPeriodicFeed(Duration interval) {
    _feedTimer?.cancel();
    _feedTimer = Timer.periodic(interval, (_) {
      publishMetrics().catchError((e) {
        _logger.logError('dashboardFeed', e);
      });
    });
  }

  void stop() {
    _feedTimer?.cancel();
    _feedTimer = null;
  }
}
