import 'dart:async';

import '../interface/transport_interface_exports.dart';
import 'fallback_strategy.dart';

class FallbackEvent {
  final DateTime timestamp;

  final TransportType primary;

  final TransportType fallback;

  final TransportError? reason;

  final int attemptNumber;

  final bool primaryRecovered;

  const FallbackEvent({
    required this.timestamp,
    required this.primary,
    required this.fallback,
    this.reason,
    required this.attemptNumber,
    this.primaryRecovered = false,
  });

  @override
  String toString() =>
      'FallbackEvent($primary->$fallback, attempt=$attemptNumber, '
      'reason=${reason?.code})';
}

class FallbackHandler {
  final void Function(FallbackEvent event)? onEvent;
  final void Function(String message)? logger;

  final _eventController = StreamController<FallbackEvent>.broadcast();

  FallbackHandler({this.onEvent, this.logger});

  Stream<FallbackEvent> get eventStream => _eventController.stream;

  Future<TransportResult<T>> execute<T>({
    required TransportInterface? primary,
    required TransportInterface? fallback,
    required TransportType primaryType,
    required TransportType fallbackType,
    required Future<TransportResult<T>> Function(TransportInterface) executor,
    FallbackConfig config = const FallbackConfig(),
  }) async {
    final stopwatch = Stopwatch()..start();

    final primaryTransport = primary;
    final primaryAvailable =
        primaryTransport != null && await primaryTransport.isAvailable();

    if (!primaryAvailable) {
      _log('Primary $primaryType not available');

      if (config.strategy == FallbackStrategy.noFallback) {
        return TransportResult.failure(
          error: TransportError.notAvailable(primaryType.name),
          attemptedTransport: primaryType,
          duration: stopwatch.elapsed,
        );
      }

      if (config.strategy == FallbackStrategy.waitForPrimary) {
        final recovered = await _waitForRecovery(
          primary!,
          timeout: config.waitTimeout,
        );

        if (recovered) {
          _log('Primary $primaryType recovered, executing');
          return _executeWithRetry(
            transport: primary,
            transportType: primaryType,
            executor: executor,
            config: config,
          );
        }
      }

      return _executeOnFallback(
        fallback: fallback,
        fallbackType: fallbackType,
        executor: executor,
        config: config,
        primaryType: primaryType,
        reason: TransportError.notAvailable(primaryType.name),
        attemptNumber: 0,
        stopwatch: stopwatch,
      );
    }

    final result = await _executeWithRetry(
      transport: primaryTransport,
      transportType: primaryType,
      executor: executor,
      config: config,
    );

    if (result.isSuccess) {
      return result;
    }

    _log('Primary $primaryType failed: ${result.errorOrNull?.code}');

    if (config.strategy == FallbackStrategy.noFallback) {
      return result;
    }

    return _executeOnFallback(
      fallback: fallback,
      fallbackType: fallbackType,
      executor: executor,
      config: config,
      primaryType: primaryType,
      reason: result.errorOrNull,
      attemptNumber: config.maxRetries,
      stopwatch: stopwatch,
    );
  }

  Future<TransportResult<T>> _executeWithRetry<T>({
    required TransportInterface transport,
    required TransportType transportType,
    required Future<TransportResult<T>> Function(TransportInterface) executor,
    required FallbackConfig config,
  }) async {
    final stopwatch = Stopwatch()..start();
    TransportResult<T>? lastResult;

    for (var attempt = 0; attempt <= config.maxRetries; attempt++) {
      if (attempt > 0) {
        final delay = config.getDelayForAttempt(attempt - 1);
        _log('Retry attempt $attempt after ${delay.inMilliseconds}ms');
        await Future.delayed(delay);

        if (!await transport.isAvailable()) {
          _log('Transport $transportType became unavailable during retry');
          break;
        }
      }

      try {
        lastResult = await executor(transport);

        if (lastResult.isSuccess) {
          return lastResult;
        }

        if (lastResult case TransportFailure(:final error)) {
          if (!error.isRetryable) {
            _log('Error ${error.code} is not retryable, stopping');
            break;
          }
        }
      } catch (e) {
        lastResult = TransportResult.failure(
          error: TransportError.unknown(e),
          attemptedTransport: transportType,
          duration: stopwatch.elapsed,
        );
      }
    }

    return lastResult ??
        TransportResult.failure(
          error: const TransportError.notAvailable('unknown'),
          attemptedTransport: transportType,
          duration: stopwatch.elapsed,
        );
  }

  Future<TransportResult<T>> _executeOnFallback<T>({
    required TransportInterface? fallback,
    required TransportType fallbackType,
    required Future<TransportResult<T>> Function(TransportInterface) executor,
    required FallbackConfig config,
    required TransportType primaryType,
    required TransportError? reason,
    required int attemptNumber,
    required Stopwatch stopwatch,
  }) async {
    final event = FallbackEvent(
      timestamp: DateTime.now(),
      primary: primaryType,
      fallback: fallbackType,
      reason: reason,
      attemptNumber: attemptNumber,
    );
    _emitEvent(event);

    if (fallback == null || !await fallback.isAvailable()) {
      _log('Fallback $fallbackType not available');
      return TransportResult.failure(
        error: const TransportError.notAvailable('all'),
        attemptedTransport: TransportType.none,
        duration: stopwatch.elapsed,
      );
    }

    _log('Switching to fallback $fallbackType');

    return _executeWithRetry(
      transport: fallback,
      transportType: fallbackType,
      executor: executor,
      config: config,
    );
  }

  Future<bool> _waitForRecovery(
    TransportInterface transport, {
    required Duration timeout,
  }) async {
    final deadline = DateTime.now().add(timeout);
    const checkInterval = Duration(seconds: 1);

    while (DateTime.now().isBefore(deadline)) {
      if (await transport.isAvailable()) {
        return true;
      }
      await Future.delayed(checkInterval);
    }

    return false;
  }

  void _emitEvent(FallbackEvent event) {
    _eventController.add(event);
    onEvent?.call(event);
  }

  void _log(String message) {
    logger?.call('[FallbackHandler] $message');
  }

  Future<void> dispose() async {
    await _eventController.close();
  }
}
