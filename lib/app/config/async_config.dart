class AsyncConfig {
  const AsyncConfig({
    this.schedulerPoolSize = 10,
    this.computePoolCoreSize = 2,
    this.computePoolMaxSize = 5,
    this.syncInterval = const Duration(minutes: 5),
    this.syncRandomDelay = const Duration(seconds: 60),
    this.oldSaleCheckInterval = const Duration(days: 7),
    this.updateCheckInterval = const Duration(hours: 3),
    this.versionCheckInterval = const Duration(minutes: 1),
    this.oldSaleRetentionMonths = 3,
  });

  factory AsyncConfig.fromEnvironment() {
    const schedulerPool = int.fromEnvironment(
      'SCHEDULER_POOL_SIZE',
      defaultValue: 10,
    );
    const computeCore = int.fromEnvironment(
      'COMPUTE_POOL_CORE',
      defaultValue: 2,
    );
    const computeMax = int.fromEnvironment('COMPUTE_POOL_MAX', defaultValue: 5);

    return AsyncConfig(
      schedulerPoolSize: schedulerPool,
      computePoolCoreSize: computeCore,
      computePoolMaxSize: computeMax,
    );
  }

  final int schedulerPoolSize;

  final int computePoolCoreSize;

  final int computePoolMaxSize;

  final Duration syncInterval;

  final Duration syncRandomDelay;

  final Duration oldSaleCheckInterval;

  final Duration updateCheckInterval;

  final Duration versionCheckInterval;

  final int oldSaleRetentionMonths;
}
