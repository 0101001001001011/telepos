enum FallbackStrategy {
  immediate,

  retryThenFallback,

  noFallback,

  waitForPrimary,
}

class FallbackConfig {
  final FallbackStrategy strategy;

  final int maxRetries;

  final Duration retryDelay;

  final Duration waitTimeout;

  final bool useExponentialBackoff;

  final Duration maxBackoffDelay;

  const FallbackConfig({
    this.strategy = FallbackStrategy.retryThenFallback,
    this.maxRetries = 3,
    this.retryDelay = const Duration(milliseconds: 500),
    this.waitTimeout = const Duration(seconds: 30),
    this.useExponentialBackoff = true,
    this.maxBackoffDelay = const Duration(seconds: 10),
  });

  static const FallbackConfig immediate = FallbackConfig(
    strategy: FallbackStrategy.immediate,
    maxRetries: 0,
  );

  static const FallbackConfig noFallback = FallbackConfig(
    strategy: FallbackStrategy.noFallback,
    maxRetries: 3,
  );

  static const FallbackConfig critical = FallbackConfig(
    strategy: FallbackStrategy.retryThenFallback,
    maxRetries: 5,
    retryDelay: Duration(seconds: 1),
    maxBackoffDelay: Duration(seconds: 30),
  );

  Duration getDelayForAttempt(int attempt) {
    if (!useExponentialBackoff) {
      return retryDelay;
    }

    var delay = retryDelay * (1 << attempt);
    if (delay > maxBackoffDelay) {
      delay = maxBackoffDelay;
    }
    return delay;
  }
}
