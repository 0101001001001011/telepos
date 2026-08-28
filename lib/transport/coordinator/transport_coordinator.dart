import 'dart:async';

import '../interface/transport_interface_exports.dart';
import 'routing_rule.dart';
import 'routing_strategy.dart';
import 'routing_table.dart';
import 'transport_config.dart';

class TransportCoordinator {
  final TransportConfig _config;
  final TransportInterface? _telegram;
  final TransportInterface? _rest;
  final RoutingTable _routingTable;
  final Logger _logger;

  final _statusController =
      StreamController<Map<TransportType, TransportStatus>>.broadcast();

  TransportCoordinator({
    required TransportConfig config,
    TransportInterface? telegram,
    TransportInterface? rest,
    RoutingTable? routingTable,
    Logger? logger,
  }) : _config = config,
       _telegram = telegram,
       _rest = rest,
       _routingTable = routingTable ?? RoutingTable.defaults(),
       _logger = logger ?? Logger.noop();

  TransportMode get mode => _config.mode;

  TransportConfig get config => _config;

  Stream<Map<TransportType, TransportStatus>> get statusStream =>
      _statusController.stream;

  Future<Map<TransportType, TransportStatus>> getStatus() async {
    final telegram = _telegram;
    final rest = _rest;
    return {
      TransportType.telegram:
          telegram?.currentStatus ?? TransportStatus.disconnected,
      TransportType.rest: rest?.currentStatus ?? TransportStatus.disconnected,
    };
  }

  Future<TransportResult<T>> execute<T>(
    TransportOperation operation,
    Future<TransportResult<T>> Function(TransportInterface transport) executor,
  ) async {
    final strategy = _routingTable.getStrategy(operation, _config.mode);
    final rule = _routingTable.getRule(operation);

    _logger.debug(
      'Routing [$operation]: mode=${_config.mode.name}, '
      'strategy=${strategy.name}',
    );

    return switch (strategy) {
      RoutingStrategy.telegramOnly => _executeSingle(
        transport: _telegram,
        transportType: TransportType.telegram,
        executor: executor,
        rule: rule,
      ),
      RoutingStrategy.restOnly => _executeSingle(
        transport: _rest,
        transportType: TransportType.rest,
        executor: executor,
        rule: rule,
      ),
      RoutingStrategy.telegramPriority => _executeWithFallback(
        primary: _telegram,
        primaryType: TransportType.telegram,
        fallback: _rest,
        fallbackType: TransportType.rest,
        executor: executor,
        rule: rule,
      ),
      RoutingStrategy.restPriority => _executeWithFallback(
        primary: _rest,
        primaryType: TransportType.rest,
        fallback: _telegram,
        fallbackType: TransportType.telegram,
        executor: executor,
        rule: rule,
      ),
      RoutingStrategy.parallel => _executeParallel(
        executor: executor,
        rule: rule,
      ),
    };
  }

  Future<TransportResult<T>> _executeSingle<T>({
    required TransportInterface? transport,
    required TransportType transportType,
    required Future<TransportResult<T>> Function(TransportInterface) executor,
    required RoutingRule rule,
  }) async {
    final stopwatch = Stopwatch()..start();

    if (transport == null) {
      return TransportResult.failure(
        error: TransportError.notAvailable(transportType.name),
        attemptedTransport: transportType,
        duration: stopwatch.elapsed,
      );
    }

    if (!await transport.isAvailable()) {
      return TransportResult.failure(
        error: TransportError.notAvailable(transportType.name),
        attemptedTransport: transportType,
        duration: stopwatch.elapsed,
      );
    }

    try {
      return await _executeWithRetry(
        transport: transport,
        executor: executor,
        maxRetries: rule.maxRetries,
        timeout: rule.timeout,
      );
    } catch (e) {
      _logger.error('Transport ${transport.name} error', e);
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: transportType,
        duration: stopwatch.elapsed,
      );
    }
  }

  Future<TransportResult<T>> _executeWithFallback<T>({
    required TransportInterface? primary,
    required TransportType primaryType,
    required TransportInterface? fallback,
    required TransportType fallbackType,
    required Future<TransportResult<T>> Function(TransportInterface) executor,
    required RoutingRule rule,
  }) async {
    if (primary != null && await primary.isAvailable()) {
      final result = await _executeSingle(
        transport: primary,
        transportType: primaryType,
        executor: executor,
        rule: rule,
      );

      if (result.isSuccess) return result;

      _logger.warning(
        'Primary [$primaryType] failed, trying fallback [$fallbackType]',
      );
    }

    if (fallback != null && await fallback.isAvailable()) {
      return _executeSingle(
        transport: fallback,
        transportType: fallbackType,
        executor: executor,
        rule: rule,
      );
    }

    return TransportResult.failure(
      error: const TransportError.notAvailable('all'),
      attemptedTransport: TransportType.none,
      duration: Duration.zero,
    );
  }

  Future<TransportResult<T>> _executeParallel<T>({
    required Future<TransportResult<T>> Function(TransportInterface) executor,
    required RoutingRule rule,
  }) async {
    final futures = <Future<TransportResult<T>>>[];
    final telegram = _telegram;
    final rest = _rest;

    if (telegram != null && await telegram.isAvailable()) {
      futures.add(
        _executeSingle(
          transport: telegram,
          transportType: TransportType.telegram,
          executor: executor,
          rule: rule,
        ),
      );
    }

    if (rest != null && await rest.isAvailable()) {
      futures.add(
        _executeSingle(
          transport: rest,
          transportType: TransportType.rest,
          executor: executor,
          rule: rule,
        ),
      );
    }

    if (futures.isEmpty) {
      return TransportResult.failure(
        error: const TransportError.notAvailable('all'),
        attemptedTransport: TransportType.none,
        duration: Duration.zero,
      );
    }

    final results = await Future.wait(futures);

    final successful = results.where((r) => r.isSuccess).toList();
    if (successful.isNotEmpty) {
      return successful.firstWhere(
        (r) => r.transport == TransportType.rest,
        orElse: () => successful.first,
      );
    }

    final errors = results
        .whereType<TransportFailure<T>>()
        .map((f) => f.error)
        .toList();

    return TransportResult.failure(
      error: TransportError.allFailed(errors),
      attemptedTransport: TransportType.both,
      duration: Duration.zero,
    );
  }

  Future<TransportResult<T>> _executeWithRetry<T>({
    required TransportInterface transport,
    required Future<TransportResult<T>> Function(TransportInterface) executor,
    required int maxRetries,
    required Duration timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    TransportResult<T>? lastResult;

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      if (attempt > 0) {
        final delay = Duration(milliseconds: 100 * (1 << attempt));
        await Future.delayed(delay);
        _logger.debug('Retry attempt $attempt after ${delay.inMilliseconds}ms');
      }

      try {
        lastResult = await executor(transport).timeout(
          timeout,
          onTimeout: () => TransportResult.failure(
            error: TransportError.timeout(timeout),
            attemptedTransport: TransportType.fromName(transport.name),
            duration: stopwatch.elapsed,
          ),
        );

        if (lastResult.isSuccess) return lastResult;

        if (lastResult case TransportFailure(:final error)) {
          if (!error.isRetryable) break;
        }
      } catch (e) {
        lastResult = TransportResult.failure(
          error: TransportError.unknown(e),
          attemptedTransport: TransportType.fromName(transport.name),
          duration: stopwatch.elapsed,
        );
      }
    }

    return lastResult!;
  }

  Future<void> dispose() async {
    await _statusController.close();
  }
}

abstract class Logger {
  void debug(String message);
  void warning(String message);
  void error(String message, [Object? error]);

  factory Logger.noop() = _NoopLogger;
  factory Logger.console() = _ConsoleLogger;
}

class _NoopLogger implements Logger {
  @override
  void debug(String message) {}
  @override
  void warning(String message) {}
  @override
  void error(String message, [Object? error]) {}
}

class _ConsoleLogger implements Logger {
  @override
  void debug(String message) {
    // ignore: avoid_print
    print('[DEBUG] $message');
  }

  @override
  void warning(String message) {
    // ignore: avoid_print
    print('[WARN] $message');
  }

  @override
  void error(String message, [Object? error]) {
    // ignore: avoid_print
    print('[ERROR] $message${error != null ? ': $error' : ''}');
  }
}
