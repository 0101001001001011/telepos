import 'dart:async';

import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/reports/report_generator.dart';
import 'package:telepos/telegram/reports/report_sender.dart';

class ReportScheduleEntry {
  final ReportType reportType;
  final Duration interval;
  final bool isActive;

  final Future<Map<String, dynamic>> Function() dataProvider;

  ReportScheduleEntry({
    required this.reportType,
    required this.interval,
    required this.dataProvider,
    this.isActive = true,
  });
}

class ReportScheduler {
  final ReportGenerator _generator;
  final ReportSender _sender;
  final TdLibLogger _logger;

  final Map<ReportType, Timer> _timers = {};
  final Map<ReportType, ReportScheduleEntry> _schedules = {};

  ReportScheduler({
    required ReportGenerator generator,
    required ReportSender sender,
    required TdLibLogger logger,
  }) : _generator = generator,
       _sender = sender,
       _logger = logger;

  void schedule(ReportScheduleEntry entry) {
    _schedules[entry.reportType] = entry;
    _logger.logConnection(
      'Report scheduled: ${entry.reportType.name} '
      'every ${entry.interval.inMinutes} min',
    );
  }

  void startAll() {
    for (final entry in _schedules.values) {
      if (entry.isActive) {
        _startSchedule(entry);
      }
    }
    _logger.logConnection(
      'Report scheduler started (${_timers.length} active)',
    );
  }

  void stopAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _logger.logConnection('Report scheduler stopped');
  }

  void start(ReportType type) {
    final entry = _schedules[type];
    if (entry == null) return;
    _startSchedule(entry);
  }

  void stop(ReportType type) {
    _timers[type]?.cancel();
    _timers.remove(type);
  }

  Future<void> generateNow(ReportType type) async {
    final entry = _schedules[type];
    if (entry == null) {
      _logger.logError('generateNow', 'No schedule for ${type.name}');
      return;
    }

    await _generateAndSend(entry);
  }

  List<ReportType> get activeSchedules => _timers.keys.toList();

  void _startSchedule(ReportScheduleEntry entry) {
    _timers[entry.reportType]?.cancel();

    _timers[entry.reportType] = Timer.periodic(entry.interval, (_) {
      _generateAndSend(entry).catchError((e, st) {
        _logger.logError('reportSchedule:${entry.reportType.name}', e, st);
      });
    });
  }

  Future<void> _generateAndSend(ReportScheduleEntry entry) async {
    _logger.logConnection(
      'Generating scheduled report: ${entry.reportType.name}',
    );

    try {
      final data = await entry.dataProvider();
      final report = _generator.generate(entry.reportType, data);
      await _sender.broadcast(report);

      _logger.logConnection('Scheduled report sent: ${entry.reportType.name}');
    } catch (e, st) {
      _logger.logError('_generateAndSend:${entry.reportType.name}', e, st);
    }
  }
}
