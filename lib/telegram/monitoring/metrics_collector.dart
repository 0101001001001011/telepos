import 'package:telepos/telegram/core/tdlib_logger.dart';

class PosMetric {
  final String name;
  final num value;
  final String unit;
  final DateTime timestamp;

  PosMetric({
    required this.name,
    required this.value,
    this.unit = '',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class MetricsCollector {
  final TdLibLogger _logger;

  final Map<String, num> _counters = {};

  final Map<String, num> _gauges = {};

  final Map<String, List<PosMetric>> _history = {};

  static const _maxHistorySize = 1000;

  MetricsCollector({required TdLibLogger logger}) : _logger = logger;

  void increment(String name, [num amount = 1]) {
    _counters[name] = (_counters[name] ?? 0) + amount;
    _addToHistory(name, _counters[name]!, 'count');
  }

  void setGauge(String name, num value, [String unit = '']) {
    _gauges[name] = value;
    _addToHistory(name, value, unit);
  }

  void record(PosMetric metric) {
    _addToHistory(metric.name, metric.value, metric.unit);
  }

  num getCounter(String name) => _counters[name] ?? 0;

  num? getGauge(String name) => _gauges[name];

  List<PosMetric> getHistory(String name) =>
      List.unmodifiable(_history[name] ?? []);

  Map<String, num> getAllCounters() => Map.unmodifiable(_counters);
  Map<String, num> getAllGauges() => Map.unmodifiable(_gauges);

  Map<String, dynamic> snapshot() {
    return {
      'counters': Map.from(_counters),
      'gauges': Map.from(_gauges),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  void resetCounters() {
    _counters.clear();
    _logger.logConnection('Metrics counters reset');
  }

  void resetAll() {
    _counters.clear();
    _gauges.clear();
    _history.clear();
    _logger.logConnection('All metrics reset');
  }

  void _addToHistory(String name, num value, String unit) {
    final list = _history.putIfAbsent(name, () => []);
    list.add(PosMetric(name: name, value: value, unit: unit));

    if (list.length > _maxHistorySize) {
      list.removeRange(0, list.length - _maxHistorySize);
    }
  }
}
