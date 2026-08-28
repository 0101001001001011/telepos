class KaspiPosConfig {
  const KaspiPosConfig({
    this.host = defaultHost,
    this.port = defaultPort,
    this.timeoutMs = defaultTimeoutMs,
    this.enabled = false,
  });

  static const String defaultHost = '192.168.1.100';

  static const int defaultPort = 2000;

  static const int defaultTimeoutMs = 5000;

  final String host;

  final int port;

  final int timeoutMs;

  final bool enabled;

  KaspiPosConfig copyWith({
    String? host,
    int? port,
    int? timeoutMs,
    bool? enabled,
  }) {
    return KaspiPosConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      timeoutMs: timeoutMs ?? this.timeoutMs,
      enabled: enabled ?? this.enabled,
    );
  }

  static bool isValidIpAddress(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;

    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }

    return true;
  }

  static bool isValidPort(int port) {
    return port > 0 && port <= 65535;
  }

  bool get isValid {
    return isValidIpAddress(host) && isValidPort(port) && timeoutMs > 0;
  }

  String get address => '$host:$port';

  Map<String, dynamic> toJson() {
    return {
      'host': host,
      'port': port,
      'timeoutMs': timeoutMs,
      'enabled': enabled,
    };
  }

  factory KaspiPosConfig.fromJson(Map<String, dynamic> json) {
    return KaspiPosConfig(
      host: json['host'] as String? ?? defaultHost,
      port: json['port'] as int? ?? defaultPort,
      timeoutMs: json['timeoutMs'] as int? ?? defaultTimeoutMs,
      enabled: json['enabled'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'KaspiPosConfig(host: $host, port: $port, enabled: $enabled)';
  }
}

enum KaspiPosStatus { disconnected, connecting, connected, error }

class KaspiPosTestResult {
  const KaspiPosTestResult({
    required this.success,
    this.latencyMs,
    this.errorMessage,
    this.terminalInfo,
  });

  final bool success;

  final int? latencyMs;

  final String? errorMessage;

  final String? terminalInfo;

  factory KaspiPosTestResult.success({int? latencyMs, String? terminalInfo}) {
    return KaspiPosTestResult(
      success: true,
      latencyMs: latencyMs,
      terminalInfo: terminalInfo,
    );
  }

  factory KaspiPosTestResult.failure(String errorMessage) {
    return KaspiPosTestResult(success: false, errorMessage: errorMessage);
  }

  @override
  String toString() {
    if (success) {
      return 'Connected (${latencyMs}ms)';
    }
    return 'Failed: $errorMessage';
  }
}
