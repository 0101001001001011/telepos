import 'dart:async';
import 'dart:collection';

import '../platform/platform_info.dart';
import 'analytics_event.dart';
import 'analytics_manager.dart';

class AmplitudeManager implements AnalyticsManager {
  AmplitudeManager({AnalyticsConfig? config})
    : _config = config ?? const AnalyticsConfig();

  final AnalyticsConfig _config;

  String? _userId;
  String? _sessionId;
  AnalyticsUserProperties? _userProperties;

  final Queue<AnalyticsEvent> _eventQueue = Queue<AnalyticsEvent>();
  Timer? _flushTimer;

  int _dailyEventCount = 0;
  DateTime? _dailyCountResetDate;

  bool _isInitialized = false;
  bool _isEnabled = true;

  @override
  bool get isEnabled => _isEnabled && _config.enabled;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;
    _sessionId = _generateSessionId();

    _startFlushTimer();

    if (_config.trackAppLifecycle) {
      logEvent(
        AnalyticsEvent(
          type: AnalyticsEventType.appStart,
          properties: _getDeviceProperties(),
        ),
      );
    }

    _log('Amplitude initialized (STUB)', AnalyticsLogLevel.info);
  }

  @override
  void setUserId(String? userId) {
    _userId = userId;
    _log('User ID set: $userId', AnalyticsLogLevel.debug);
  }

  @override
  void setUserProperties(AnalyticsUserProperties properties) {
    _userProperties = properties;
    _log('User properties updated', AnalyticsLogLevel.debug);
  }

  @override
  void logEvent(AnalyticsEvent event) {
    if (!isEnabled) return;

    if (!_checkDailyLimit()) {
      _log('Daily event limit reached', AnalyticsLogLevel.warn);
      return;
    }

    _eventQueue.add(event);
    _dailyEventCount++;

    _log('Event logged: ${event.eventName}', AnalyticsLogLevel.debug);

    if (_eventQueue.length >= _config.batchSize) {
      flush();
    }
  }

  @override
  void logEvents(List<AnalyticsEvent> events) {
    for (final event in events) {
      logEvent(event);
    }
  }

  @override
  void trackScreen(String screenName, {Map<String, dynamic>? properties}) {
    if (!_config.trackScreenViews) return;

    logEvent(AnalyticsEvent.screenView(screenName, properties: properties));
  }

  @override
  Future<void> flush() async {
    if (_eventQueue.isEmpty) return;

    final batch = <AnalyticsEvent>[];
    while (batch.length < _config.maxBatchSize && _eventQueue.isNotEmpty) {
      batch.add(_eventQueue.removeFirst());
    }

    _log('Flushed ${batch.length} events (STUB)', AnalyticsLogLevel.info);
  }

  @override
  void reset() {
    _userId = null;
    _userProperties = null;
    _sessionId = _generateSessionId();
    _eventQueue.clear();

    _log('Analytics reset', AnalyticsLogLevel.info);
  }

  @override
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    _log('Analytics enabled: $enabled', AnalyticsLogLevel.info);
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    flush();

    _log('Amplitude disposed', AnalyticsLogLevel.info);
  }

  void _startFlushTimer() {
    _flushTimer = Timer.periodic(
      Duration(seconds: _config.flushIntervalSeconds),
      (_) => flush(),
    );
  }

  bool _checkDailyLimit() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    if (_dailyCountResetDate == null || _dailyCountResetDate != todayDate) {
      _dailyCountResetDate = todayDate;
      _dailyEventCount = 0;
    }

    return _dailyEventCount < _config.dailyEventLimit;
  }

  String _generateSessionId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  Map<String, dynamic> _getDeviceProperties() {
    return {
      'platform': PlatformInfo.name,
      'os_name': PlatformInfo.operatingSystem,
      'os_version': PlatformInfo.operatingSystemVersion,
      'device_id': _getDeviceId(),
      'language': PlatformInfo.localeName,
      'session_id': _sessionId,
      if (_userId != null) 'user_id': _userId,
      ..._userProperties?.toJson() ?? {},
    };
  }

  String _getDeviceId() {
    return 'device_${DateTime.now().millisecondsSinceEpoch}';
  }

  // ignore: unused_element
  Map<String, dynamic> _buildBatchPayload(List<AnalyticsEvent> events) {
    return {
      'api_key': _config.apiKey,
      'events': events.map((e) {
        final json = e.toJson();
        json.addAll(_getDeviceProperties());
        return json;
      }).toList(),
    };
  }

  void _log(String message, AnalyticsLogLevel level) {
    if (level.index > _config.logLevel.index) return;

    // ignore: avoid_print
    print('[Amplitude] $message');
  }
}

extension AnalyticsExtension on AnalyticsManager {
  void logSaleComplete({
    required String receiptNo,
    required double total,
    required int itemCount,
    required String paymentMethod,
  }) {
    logEvent(
      AnalyticsEvent(
        type: AnalyticsEventType.saleComplete,
        properties: {
          'receipt_no': receiptNo,
          'total': total,
          'item_count': itemCount,
          'payment_method': paymentMethod,
        },
      ),
    );
  }

  void logRefundComplete({
    required String receiptNo,
    required double total,
    required int itemCount,
  }) {
    logEvent(
      AnalyticsEvent(
        type: AnalyticsEventType.refundComplete,
        properties: {
          'receipt_no': receiptNo,
          'total': total,
          'item_count': itemCount,
        },
      ),
    );
  }

  void logShiftOpen({required String shiftNo, required String cashierId}) {
    logEvent(
      AnalyticsEvent(
        type: AnalyticsEventType.shiftOpen,
        properties: {'shift_no': shiftNo, 'cashier_id': cashierId},
      ),
    );
  }

  void logShiftClose({
    required String shiftNo,
    required double totalSales,
    required double totalRefunds,
    required int salesCount,
  }) {
    logEvent(
      AnalyticsEvent(
        type: AnalyticsEventType.shiftClose,
        properties: {
          'shift_no': shiftNo,
          'total_sales': totalSales,
          'total_refunds': totalRefunds,
          'sales_count': salesCount,
        },
      ),
    );
  }

  void logLogin({required String userId, required String role}) {
    setUserId(userId);
    logEvent(
      AnalyticsEvent(
        type: AnalyticsEventType.login,
        properties: {'user_id': userId, 'role': role},
      ),
    );
  }

  void logLogout() {
    logEvent(const AnalyticsEvent(type: AnalyticsEventType.logout));
    setUserId(null);
  }

  void logSync({
    required bool success,
    String? errorMessage,
    int? recordCount,
  }) {
    logEvent(
      AnalyticsEvent(
        type: success
            ? AnalyticsEventType.syncComplete
            : AnalyticsEventType.syncFailed,
        properties: {
          'success': success,
          if (errorMessage != null) 'error_message': errorMessage,
          if (recordCount != null) 'record_count': recordCount,
        },
      ),
    );
  }
}
