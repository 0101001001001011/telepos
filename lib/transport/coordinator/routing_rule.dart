import 'routing_strategy.dart';

class RoutingRule {
  final RoutingStrategy telegramOnlyStrategy;

  final RoutingStrategy restOnlyStrategy;

  final RoutingStrategy hybridStrategy;

  final int maxRetries;

  final Duration timeout;

  final bool canQueue;

  final int queuePriority;

  const RoutingRule({
    required this.telegramOnlyStrategy,
    required this.restOnlyStrategy,
    required this.hybridStrategy,
    this.maxRetries = 3,
    this.timeout = const Duration(seconds: 30),
    this.canQueue = true,
    this.queuePriority = 50,
  });

  RoutingStrategy getStrategy(TransportMode mode) => switch (mode) {
    TransportMode.telegramOnly => telegramOnlyStrategy,
    TransportMode.restOnly => restOnlyStrategy,
    TransportMode.hybrid => hybridStrategy,
  };

  RoutingRule copyWith({
    RoutingStrategy? telegramOnlyStrategy,
    RoutingStrategy? restOnlyStrategy,
    RoutingStrategy? hybridStrategy,
    int? maxRetries,
    Duration? timeout,
    bool? canQueue,
    int? queuePriority,
  }) {
    return RoutingRule(
      telegramOnlyStrategy: telegramOnlyStrategy ?? this.telegramOnlyStrategy,
      restOnlyStrategy: restOnlyStrategy ?? this.restOnlyStrategy,
      hybridStrategy: hybridStrategy ?? this.hybridStrategy,
      maxRetries: maxRetries ?? this.maxRetries,
      timeout: timeout ?? this.timeout,
      canQueue: canQueue ?? this.canQueue,
      queuePriority: queuePriority ?? this.queuePriority,
    );
  }
}

enum TransportMode {
  telegramOnly,

  restOnly,

  hybrid;

  String get displayName => switch (this) {
    TransportMode.telegramOnly => 'Telegram',
    TransportMode.restOnly => 'REST API',
    TransportMode.hybrid => 'Hybrid',
  };

  String get icon => switch (this) {
    TransportMode.telegramOnly => '📱',
    TransportMode.restOnly => '🌐',
    TransportMode.hybrid => '🔄',
  };
}
