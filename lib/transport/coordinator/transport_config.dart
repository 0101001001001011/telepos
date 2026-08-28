import '../interface/transport_operation.dart';
import 'routing_rule.dart';
import 'routing_table.dart';

class TransportConfig {
  final TransportMode mode;

  final TelegramTransportConfig? telegram;

  final RestTransportConfig? rest;

  final RoutingOverrides overrides;

  const TransportConfig({
    required this.mode,
    this.telegram,
    this.rest,
    this.overrides = RoutingOverrides.empty,
  });

  factory TransportConfig.telegramOnly(TelegramTransportConfig telegram) {
    return TransportConfig(
      mode: TransportMode.telegramOnly,
      telegram: telegram,
    );
  }

  factory TransportConfig.restOnly(RestTransportConfig rest) {
    return TransportConfig(mode: TransportMode.restOnly, rest: rest);
  }

  factory TransportConfig.hybrid({
    required TelegramTransportConfig telegram,
    required RestTransportConfig rest,
    RoutingOverrides overrides = RoutingOverrides.empty,
  }) {
    return TransportConfig(
      mode: TransportMode.hybrid,
      telegram: telegram,
      rest: rest,
      overrides: overrides,
    );
  }

  bool get isValid {
    switch (mode) {
      case TransportMode.telegramOnly:
        return telegram != null;
      case TransportMode.restOnly:
        return rest != null;
      case TransportMode.hybrid:
        return telegram != null && rest != null;
    }
  }

  bool get hasTelegram =>
      mode == TransportMode.telegramOnly || mode == TransportMode.hybrid;

  bool get hasRest =>
      mode == TransportMode.restOnly || mode == TransportMode.hybrid;

  TransportConfig copyWith({
    TransportMode? mode,
    TelegramTransportConfig? telegram,
    RestTransportConfig? rest,
    RoutingOverrides? overrides,
  }) {
    return TransportConfig(
      mode: mode ?? this.mode,
      telegram: telegram ?? this.telegram,
      rest: rest ?? this.rest,
      overrides: overrides ?? this.overrides,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.name,
      if (telegram != null) 'telegram': telegram!.toJson(),
      if (rest != null) 'rest': rest!.toJson(),
      'overrides': {
        'forceTelegram': overrides.forceTelegram.map((e) => e.name).toList(),
        'forceRest': overrides.forceRest.map((e) => e.name).toList(),
        'forceBoth': overrides.forceBoth.map((e) => e.name).toList(),
        'noFallback': overrides.noFallback.map((e) => e.name).toList(),
      },
    };
  }

  factory TransportConfig.fromJson(Map<String, dynamic> json) {
    return TransportConfig(
      mode: TransportMode.values.byName(json['mode'] as String),
      telegram: json['telegram'] != null
          ? TelegramTransportConfig.fromJson(
              json['telegram'] as Map<String, dynamic>,
            )
          : null,
      rest: json['rest'] != null
          ? RestTransportConfig.fromJson(json['rest'] as Map<String, dynamic>)
          : null,
      overrides: _parseOverrides(json['overrides'] as Map<String, dynamic>?),
    );
  }

  static RoutingOverrides _parseOverrides(Map<String, dynamic>? json) {
    if (json == null) return RoutingOverrides.empty;

    return RoutingOverrides(
      forceTelegram: _parseOperationSet(json['forceTelegram']),
      forceRest: _parseOperationSet(json['forceRest']),
      forceBoth: _parseOperationSet(json['forceBoth']),
      noFallback: _parseOperationSet(json['noFallback']),
    );
  }

  static Set<TransportOperation> _parseOperationSet(dynamic list) {
    if (list == null || list is! List) return {};
    return list
        .map((name) {
          try {
            return TransportOperation.values.byName(name as String);
          } catch (_) {
            return null;
          }
        })
        .whereType<TransportOperation>()
        .toSet();
  }
}

class TelegramTransportConfig {
  final int apiId;

  final String apiHash;

  final String? phoneNumber;

  final String databaseDirectory;

  final String filesDirectory;

  final bool useTestDc;

  const TelegramTransportConfig({
    required this.apiId,
    required this.apiHash,
    this.phoneNumber,
    this.databaseDirectory = 'tdlib',
    this.filesDirectory = 'tdlib_files',
    this.useTestDc = false,
  });

  Map<String, dynamic> toJson() => {
    'apiId': apiId,
    'apiHash': apiHash,
    if (phoneNumber != null) 'phoneNumber': phoneNumber,
    'databaseDirectory': databaseDirectory,
    'filesDirectory': filesDirectory,
    'useTestDc': useTestDc,
  };

  factory TelegramTransportConfig.fromJson(Map<String, dynamic> json) {
    return TelegramTransportConfig(
      apiId: json['apiId'] as int,
      apiHash: json['apiHash'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      databaseDirectory: json['databaseDirectory'] as String? ?? 'tdlib',
      filesDirectory: json['filesDirectory'] as String? ?? 'tdlib_files',
      useTestDc: json['useTestDc'] as bool? ?? false,
    );
  }
}

class RestTransportConfig {
  final String baseUrl;

  final String? authToken;

  final String? refreshToken;

  final Duration timeout;

  final int maxRetries;

  final String? websocketUrl;

  const RestTransportConfig({
    required this.baseUrl,
    this.authToken,
    this.refreshToken,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.websocketUrl,
  });

  String get effectiveWebsocketUrl {
    if (websocketUrl != null) return websocketUrl!;

    final uri = Uri.parse(baseUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return uri.replace(scheme: wsScheme, path: '/ws').toString();
  }

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    if (authToken != null) 'authToken': authToken,
    if (refreshToken != null) 'refreshToken': refreshToken,
    'timeout': timeout.inMilliseconds,
    'maxRetries': maxRetries,
    if (websocketUrl != null) 'websocketUrl': websocketUrl,
  };

  factory RestTransportConfig.fromJson(Map<String, dynamic> json) {
    return RestTransportConfig(
      baseUrl: json['baseUrl'] as String,
      authToken: json['authToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      timeout: Duration(milliseconds: json['timeout'] as int? ?? 30000),
      maxRetries: json['maxRetries'] as int? ?? 3,
      websocketUrl: json['websocketUrl'] as String?,
    );
  }

  RestTransportConfig copyWith({
    String? baseUrl,
    String? authToken,
    String? refreshToken,
    Duration? timeout,
    int? maxRetries,
    String? websocketUrl,
  }) {
    return RestTransportConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      authToken: authToken ?? this.authToken,
      refreshToken: refreshToken ?? this.refreshToken,
      timeout: timeout ?? this.timeout,
      maxRetries: maxRetries ?? this.maxRetries,
      websocketUrl: websocketUrl ?? this.websocketUrl,
    );
  }
}
