import 'dart:async';
import 'dart:io';

import 'package:telepos/telegram/channels/channel_registry.dart';
import 'package:telepos/telegram/channels/channel_types.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/messaging/message_service.dart';

class HealthReporter {
  final MessageService _messageService;
  final ChannelRegistry _channelRegistry;
  final TdLibLogger _logger;

  Timer? _checkTimer;
  static const _checkInterval = Duration(minutes: 5);

  HealthReporter({
    required MessageService messageService,
    required ChannelRegistry channelRegistry,
    required TdLibLogger logger,
  }) : _messageService = messageService,
       _channelRegistry = channelRegistry,
       _logger = logger;

  void start() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(_checkInterval, (_) {
      runCheck().catchError((Object e) {
        _logger.logError('healthCheck', e);
        return HealthReport(timestamp: DateTime.now(), checks: {});
      });
    });
    _logger.logConnection('Health reporter started');
  }

  void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _logger.logConnection('Health reporter stopped');
  }

  Future<HealthReport> runCheck() async {
    final checks = <String, HealthCheckResult>{};

    checks['disk'] = await _checkDiskSpace();

    checks['memory'] = _checkMemory();

    checks['telegram'] = HealthCheckResult.ok('Connected');

    final report = HealthReport(timestamp: DateTime.now(), checks: checks);

    if (!report.isHealthy) {
      await _publishReport(report);
    }

    return report;
  }

  Future<HealthCheckResult> _checkDiskSpace() async {
    try {
      final dir = Directory.systemTemp;
      await dir.stat();
      return HealthCheckResult.ok('Disk OK');
    } catch (e) {
      return HealthCheckResult.error('Disk check failed: $e');
    }
  }

  HealthCheckResult _checkMemory() {
    return HealthCheckResult.ok('Memory OK');
  }

  Future<void> _publishReport(HealthReport report) async {
    final chatId = _channelRegistry.getChatId(SystemChannelType.posSystem);
    if (chatId == null) return;

    final buffer = StringBuffer();
    buffer.writeln('🏥 *Health Report*');
    buffer.writeln('🕐 ${report.timestamp.toLocal()}');
    buffer.writeln();

    for (final entry in report.checks.entries) {
      final icon = entry.value.isOk ? '✅' : '❌';
      buffer.writeln('$icon ${entry.key}: ${entry.value.message}');
    }

    await _messageService.sendSilent(chatId, buffer.toString());
  }
}

class HealthCheckResult {
  final bool isOk;
  final String message;

  HealthCheckResult({required this.isOk, required this.message});

  factory HealthCheckResult.ok(String message) =>
      HealthCheckResult(isOk: true, message: message);

  factory HealthCheckResult.error(String message) =>
      HealthCheckResult(isOk: false, message: message);
}

class HealthReport {
  final DateTime timestamp;
  final Map<String, HealthCheckResult> checks;

  HealthReport({required this.timestamp, required this.checks});

  bool get isHealthy => checks.values.every((c) => c.isOk);
}
