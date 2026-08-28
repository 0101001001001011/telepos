import 'dart:async';
import 'dart:collection';

import 'package:talker/talker.dart';

enum AnalyticsEventType {
  screenView,

  userAction,

  businessEvent,

  error,

  performance,
}

class AnalyticsEvent {
  final String name;
  final AnalyticsEventType type;
  final Map<String, dynamic> properties;
  final DateTime timestamp;
  final String? userId;
  final String? sessionId;

  AnalyticsEvent({
    required this.name,
    required this.type,
    Map<String, dynamic>? properties,
    DateTime? timestamp,
    this.userId,
    this.sessionId,
  }) : properties = properties ?? {},
       timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type.name,
    'properties': properties,
    'timestamp': timestamp.toIso8601String(),
    'userId': userId,
    'sessionId': sessionId,
  };
}

class AnalyticsService {
  final Talker _logger;
  final Queue<AnalyticsEvent> _eventQueue = Queue();
  final int _maxQueueSize;
  final Duration _flushInterval;

  Timer? _flushTimer;
  String? _userId;
  String? _sessionId;
  bool _isEnabled = true;

  final Map<String, dynamic> _globalProperties = {};

  AnalyticsService({
    int maxQueueSize = 100,
    Duration flushInterval = const Duration(minutes: 1),
    Talker? logger,
  }) : _maxQueueSize = maxQueueSize,
       _flushInterval = flushInterval,
       _logger = logger ?? Talker();

  bool get isEnabled => _isEnabled;

  int get queueSize => _eventQueue.length;

  void initialize({String? userId, String? posId, String? storeId}) {
    _userId = userId;
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();

    if (posId != null) _globalProperties['posId'] = posId;
    if (storeId != null) _globalProperties['storeId'] = storeId;

    _flushTimer = Timer.periodic(_flushInterval, (_) => flush());

    _logger.info('Analytics initialized for user: $userId');
  }

  void enable() {
    _isEnabled = true;
    _logger.info('Analytics enabled');
  }

  void disable() {
    _isEnabled = false;
    _logger.info('Analytics disabled');
  }

  void setUserId(String? userId) {
    _userId = userId;
    if (userId != null) {
      _globalProperties['userId'] = userId;
    }
  }

  void setGlobalProperty(String key, dynamic value) {
    _globalProperties[key] = value;
  }

  void trackScreen(String screenName, {Map<String, dynamic>? properties}) {
    track(
      'screen_view',
      type: AnalyticsEventType.screenView,
      properties: {'screen_name': screenName, ...?properties},
    );
  }

  void trackAction(String action, {Map<String, dynamic>? properties}) {
    track(action, type: AnalyticsEventType.userAction, properties: properties);
  }

  void trackBusiness(String event, {Map<String, dynamic>? properties}) {
    track(
      event,
      type: AnalyticsEventType.businessEvent,
      properties: properties,
    );
  }

  void trackError(
    String error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? properties,
  }) {
    track(
      'error',
      type: AnalyticsEventType.error,
      properties: {
        'error_message': error,
        'stack_trace': stackTrace?.toString(),
        ...?properties,
      },
    );
  }

  void trackPerformance(
    String metric,
    Duration duration, {
    Map<String, dynamic>? properties,
  }) {
    track(
      'performance',
      type: AnalyticsEventType.performance,
      properties: {
        'metric_name': metric,
        'duration_ms': duration.inMilliseconds,
        ...?properties,
      },
    );
  }

  void track(
    String name, {
    AnalyticsEventType type = AnalyticsEventType.userAction,
    Map<String, dynamic>? properties,
  }) {
    if (!_isEnabled) return;

    final event = AnalyticsEvent(
      name: name,
      type: type,
      properties: {..._globalProperties, ...?properties},
      userId: _userId,
      sessionId: _sessionId,
    );

    _eventQueue.add(event);
    _logger.debug('Analytics event: $name');

    if (_eventQueue.length >= _maxQueueSize) {
      flush();
    }
  }

  Future<void> flush() async {
    if (_eventQueue.isEmpty) return;

    final events = _eventQueue.toList();
    _eventQueue.clear();

    _logger.debug('Flushing ${events.length} analytics events');

    try {
      for (final event in events) {
        _logger.debug('  ${event.name}: ${event.properties}');
      }
    } catch (e, st) {
      _logger.error('Failed to flush analytics', e, st);
      for (final event in events) {
        if (_eventQueue.length < _maxQueueSize) {
          _eventQueue.add(event);
        }
      }
    }
  }

  Future<void> dispose() async {
    _flushTimer?.cancel();
    await flush();
  }
}
