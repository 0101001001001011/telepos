enum RoutingStrategy {
  telegramOnly,

  restOnly,

  telegramPriority,

  restPriority,

  parallel;

  bool get hasFallback =>
      this == RoutingStrategy.telegramPriority ||
      this == RoutingStrategy.restPriority;

  String? get primaryTransport => switch (this) {
    RoutingStrategy.telegramOnly => 'telegram',
    RoutingStrategy.telegramPriority => 'telegram',
    RoutingStrategy.restOnly => 'rest',
    RoutingStrategy.restPriority => 'rest',
    RoutingStrategy.parallel => null,
  };

  String? get fallbackTransport => switch (this) {
    RoutingStrategy.telegramPriority => 'rest',
    RoutingStrategy.restPriority => 'telegram',
    _ => null,
  };
}
