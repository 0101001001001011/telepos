enum TransportType {
  telegram,

  rest,

  both,

  none;

  static TransportType fromName(String name) {
    return switch (name.toLowerCase()) {
      'telegram' => TransportType.telegram,
      'rest' => TransportType.rest,
      'both' => TransportType.both,
      _ => TransportType.none,
    };
  }

  String get displayName => switch (this) {
    TransportType.telegram => 'Telegram',
    TransportType.rest => 'REST API',
    TransportType.both => 'Telegram + REST',
    TransportType.none => 'None',
  };
}
