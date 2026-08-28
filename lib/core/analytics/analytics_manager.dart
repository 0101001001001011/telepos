import 'analytics_event.dart';

abstract class AnalyticsManager {
  Future<void> initialize();

  void setUserId(String? userId);

  void setUserProperties(AnalyticsUserProperties properties);

  void logEvent(AnalyticsEvent event);

  void logEvents(List<AnalyticsEvent> events);

  void trackScreen(String screenName, {Map<String, dynamic>? properties});

  Future<void> flush();

  void reset();

  void setEnabled(bool enabled);

  bool get isEnabled;

  void dispose();
}

class AnalyticsConfig {
  const AnalyticsConfig({
    this.apiKey,
    this.enabled = true,
    this.logLevel = AnalyticsLogLevel.warn,
    this.flushIntervalSeconds = 30,
    this.batchSize = 30,
    this.maxBatchSize = 5000,
    this.dailyEventLimit = 100000,
    this.trackScreenViews = true,
    this.trackAppLifecycle = true,
    this.trackUserProperties = true,
  });

  final String? apiKey;

  final bool enabled;

  final AnalyticsLogLevel logLevel;

  final int flushIntervalSeconds;

  final int batchSize;

  final int maxBatchSize;

  final int dailyEventLimit;

  final bool trackScreenViews;

  final bool trackAppLifecycle;

  final bool trackUserProperties;
}

enum AnalyticsLogLevel { none, error, warn, info, debug }
