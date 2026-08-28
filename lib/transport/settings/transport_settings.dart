import '../coordinator/transport_config.dart';

class TransportSettings {
  final TransportConfig transportConfig;

  final RetrySettings retrySettings;

  final QueueSettings queueSettings;

  final SyncSettings syncSettings;

  final NotificationSettings notificationSettings;

  final bool allowHotSwitch;

  final bool autoFallback;

  final bool showTransportIndicator;

  const TransportSettings({
    required this.transportConfig,
    this.retrySettings = const RetrySettings(),
    this.queueSettings = const QueueSettings(),
    this.syncSettings = const SyncSettings(),
    this.notificationSettings = const NotificationSettings(),
    this.allowHotSwitch = true,
    this.autoFallback = true,
    this.showTransportIndicator = true,
  });

  factory TransportSettings.restDefault({
    required String baseUrl,
    String? authToken,
  }) {
    return TransportSettings(
      transportConfig: TransportConfig.restOnly(
        RestTransportConfig(baseUrl: baseUrl, authToken: authToken),
      ),
    );
  }

  factory TransportSettings.telegramDefault({
    required int apiId,
    required String apiHash,
  }) {
    return TransportSettings(
      transportConfig: TransportConfig.telegramOnly(
        TelegramTransportConfig(apiId: apiId, apiHash: apiHash),
      ),
    );
  }

  factory TransportSettings.hybridDefault({
    required int apiId,
    required String apiHash,
    required String baseUrl,
    String? authToken,
  }) {
    return TransportSettings(
      transportConfig: TransportConfig.hybrid(
        telegram: TelegramTransportConfig(apiId: apiId, apiHash: apiHash),
        rest: RestTransportConfig(baseUrl: baseUrl, authToken: authToken),
      ),
    );
  }

  TransportSettings copyWith({
    TransportConfig? transportConfig,
    RetrySettings? retrySettings,
    QueueSettings? queueSettings,
    SyncSettings? syncSettings,
    NotificationSettings? notificationSettings,
    bool? allowHotSwitch,
    bool? autoFallback,
    bool? showTransportIndicator,
  }) {
    return TransportSettings(
      transportConfig: transportConfig ?? this.transportConfig,
      retrySettings: retrySettings ?? this.retrySettings,
      queueSettings: queueSettings ?? this.queueSettings,
      syncSettings: syncSettings ?? this.syncSettings,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      allowHotSwitch: allowHotSwitch ?? this.allowHotSwitch,
      autoFallback: autoFallback ?? this.autoFallback,
      showTransportIndicator:
          showTransportIndicator ?? this.showTransportIndicator,
    );
  }

  Map<String, dynamic> toJson() => {
    'transportConfig': transportConfig.toJson(),
    'retrySettings': retrySettings.toJson(),
    'queueSettings': queueSettings.toJson(),
    'syncSettings': syncSettings.toJson(),
    'notificationSettings': notificationSettings.toJson(),
    'allowHotSwitch': allowHotSwitch,
    'autoFallback': autoFallback,
    'showTransportIndicator': showTransportIndicator,
  };

  factory TransportSettings.fromJson(Map<String, dynamic> json) {
    return TransportSettings(
      transportConfig: TransportConfig.fromJson(
        json['transportConfig'] as Map<String, dynamic>,
      ),
      retrySettings: json['retrySettings'] != null
          ? RetrySettings.fromJson(
              json['retrySettings'] as Map<String, dynamic>,
            )
          : const RetrySettings(),
      queueSettings: json['queueSettings'] != null
          ? QueueSettings.fromJson(
              json['queueSettings'] as Map<String, dynamic>,
            )
          : const QueueSettings(),
      syncSettings: json['syncSettings'] != null
          ? SyncSettings.fromJson(json['syncSettings'] as Map<String, dynamic>)
          : const SyncSettings(),
      notificationSettings: json['notificationSettings'] != null
          ? NotificationSettings.fromJson(
              json['notificationSettings'] as Map<String, dynamic>,
            )
          : const NotificationSettings(),
      allowHotSwitch: json['allowHotSwitch'] as bool? ?? true,
      autoFallback: json['autoFallback'] as bool? ?? true,
      showTransportIndicator: json['showTransportIndicator'] as bool? ?? true,
    );
  }
}

class RetrySettings {
  final int maxRetries;

  final int maxCriticalRetries;

  final Duration baseDelay;

  final Duration maxDelay;

  final double backoffMultiplier;

  final bool useJitter;

  const RetrySettings({
    this.maxRetries = 3,
    this.maxCriticalRetries = 10,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(minutes: 10),
    this.backoffMultiplier = 2.0,
    this.useJitter = true,
  });

  Duration getDelayForAttempt(int attempt) {
    final delayMs =
        baseDelay.inMilliseconds *
        (backoffMultiplier * attempt).clamp(
          1,
          maxDelay.inMilliseconds / baseDelay.inMilliseconds,
        );
    return Duration(milliseconds: delayMs.toInt());
  }

  Map<String, dynamic> toJson() => {
    'maxRetries': maxRetries,
    'maxCriticalRetries': maxCriticalRetries,
    'baseDelay': baseDelay.inMilliseconds,
    'maxDelay': maxDelay.inMilliseconds,
    'backoffMultiplier': backoffMultiplier,
    'useJitter': useJitter,
  };

  factory RetrySettings.fromJson(Map<String, dynamic> json) {
    return RetrySettings(
      maxRetries: json['maxRetries'] as int? ?? 3,
      maxCriticalRetries: json['maxCriticalRetries'] as int? ?? 10,
      baseDelay: Duration(milliseconds: json['baseDelay'] as int? ?? 1000),
      maxDelay: Duration(milliseconds: json['maxDelay'] as int? ?? 600000),
      backoffMultiplier: (json['backoffMultiplier'] as num?)?.toDouble() ?? 2.0,
      useJitter: json['useJitter'] as bool? ?? true,
    );
  }
}

class QueueSettings {
  final bool enabled;

  final int maxQueueSize;

  final int maxConcurrency;

  final Duration checkInterval;

  final bool autoCleanup;

  final Duration cleanupAge;

  const QueueSettings({
    this.enabled = true,
    this.maxQueueSize = 1000,
    this.maxConcurrency = 3,
    this.checkInterval = const Duration(seconds: 30),
    this.autoCleanup = true,
    this.cleanupAge = const Duration(days: 7),
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'maxQueueSize': maxQueueSize,
    'maxConcurrency': maxConcurrency,
    'checkInterval': checkInterval.inSeconds,
    'autoCleanup': autoCleanup,
    'cleanupAge': cleanupAge.inDays,
  };

  factory QueueSettings.fromJson(Map<String, dynamic> json) {
    return QueueSettings(
      enabled: json['enabled'] as bool? ?? true,
      maxQueueSize: json['maxQueueSize'] as int? ?? 1000,
      maxConcurrency: json['maxConcurrency'] as int? ?? 3,
      checkInterval: Duration(seconds: json['checkInterval'] as int? ?? 30),
      autoCleanup: json['autoCleanup'] as bool? ?? true,
      cleanupAge: Duration(days: json['cleanupAge'] as int? ?? 7),
    );
  }
}

class SyncSettings {
  final Duration syncInterval;

  final bool syncOnStartup;

  final bool syncOnConnectivity;

  final Duration minSyncInterval;

  final Set<SyncCategory> enabledCategories;

  const SyncSettings({
    this.syncInterval = const Duration(minutes: 5),
    this.syncOnStartup = true,
    this.syncOnConnectivity = true,
    this.minSyncInterval = const Duration(minutes: 1),
    this.enabledCategories = const {
      SyncCategory.sales,
      SyncCategory.refunds,
      SyncCategory.shifts,
      SyncCategory.products,
      SyncCategory.prices,
      SyncCategory.agents,
    },
  });

  Map<String, dynamic> toJson() => {
    'syncInterval': syncInterval.inSeconds,
    'syncOnStartup': syncOnStartup,
    'syncOnConnectivity': syncOnConnectivity,
    'minSyncInterval': minSyncInterval.inSeconds,
    'enabledCategories': enabledCategories.map((c) => c.name).toList(),
  };

  factory SyncSettings.fromJson(Map<String, dynamic> json) {
    return SyncSettings(
      syncInterval: Duration(seconds: json['syncInterval'] as int? ?? 300),
      syncOnStartup: json['syncOnStartup'] as bool? ?? true,
      syncOnConnectivity: json['syncOnConnectivity'] as bool? ?? true,
      minSyncInterval: Duration(seconds: json['minSyncInterval'] as int? ?? 60),
      enabledCategories:
          (json['enabledCategories'] as List<dynamic>?)
              ?.map((name) => SyncCategory.values.byName(name as String))
              .toSet() ??
          SyncCategory.values.toSet(),
    );
  }
}

enum SyncCategory {
  sales,
  refunds,
  shifts,
  cashOperations,
  supplies,
  products,
  prices,
  categories,
  agents,
  config,
  users,
  stock,
}

class NotificationSettings {
  final bool notifyOnTransportChange;

  final bool notifyOnSyncError;

  final bool notifyOnOffline;

  final bool notifyOnOnline;

  final bool notifyOnQueueFull;

  const NotificationSettings({
    this.notifyOnTransportChange = true,
    this.notifyOnSyncError = true,
    this.notifyOnOffline = true,
    this.notifyOnOnline = true,
    this.notifyOnQueueFull = true,
  });

  Map<String, dynamic> toJson() => {
    'notifyOnTransportChange': notifyOnTransportChange,
    'notifyOnSyncError': notifyOnSyncError,
    'notifyOnOffline': notifyOnOffline,
    'notifyOnOnline': notifyOnOnline,
    'notifyOnQueueFull': notifyOnQueueFull,
  };

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      notifyOnTransportChange: json['notifyOnTransportChange'] as bool? ?? true,
      notifyOnSyncError: json['notifyOnSyncError'] as bool? ?? true,
      notifyOnOffline: json['notifyOnOffline'] as bool? ?? true,
      notifyOnOnline: json['notifyOnOnline'] as bool? ?? true,
      notifyOnQueueFull: json['notifyOnQueueFull'] as bool? ?? true,
    );
  }
}
