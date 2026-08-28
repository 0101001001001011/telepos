enum TransportStatus {
  disconnected,

  connecting,

  connected,

  reconnecting,

  error;

  bool get isConnected => this == TransportStatus.connected;

  bool get hasIssues =>
      this == TransportStatus.error ||
      this == TransportStatus.disconnected ||
      this == TransportStatus.reconnecting;

  bool get isConnecting =>
      this == TransportStatus.connecting ||
      this == TransportStatus.reconnecting;

  String get icon => switch (this) {
    TransportStatus.connected => '✓',
    TransportStatus.connecting => '↻',
    TransportStatus.reconnecting => '⚠',
    TransportStatus.disconnected => '✗',
    TransportStatus.error => '✗',
  };

  int get colorValue => switch (this) {
    TransportStatus.connected => 0xFF4CAF50,
    TransportStatus.connecting => 0xFFFFC107,
    TransportStatus.reconnecting => 0xFFFF9800,
    TransportStatus.disconnected => 0xFF9E9E9E,
    TransportStatus.error => 0xFFF44336,
  };
}
