import 'dart:async';

import '../interface/transport_interface_exports.dart';
import 'result_merger.dart';

class ParallelExecutor {
  final TransportInterface? telegram;
  final TransportInterface? rest;
  final ResultMerger merger;
  final Duration timeout;
  final void Function(String message)? logger;

  ParallelExecutor({
    this.telegram,
    this.rest,
    ResultMerger? merger,
    this.timeout = const Duration(seconds: 30),
    this.logger,
  }) : merger = merger ?? const ResultMerger();

  Future<TransportResult<T>> execute<T>({
    required Future<TransportResult<T>> Function() telegramExecutor,
    required Future<TransportResult<T>> Function() restExecutor,
    MergeStrategy strategy = MergeStrategy.preferRest,
    bool onlyAvailable = true,
  }) async {
    final stopwatch = Stopwatch()..start();

    final telegramAvailable =
        !onlyAvailable || (telegram != null && await telegram!.isAvailable());
    final restAvailable =
        !onlyAvailable || (rest != null && await rest!.isAvailable());

    _log('Parallel execute: telegram=$telegramAvailable, rest=$restAvailable');

    if (!telegramAvailable && !restAvailable) {
      return TransportResult.failure(
        error: const TransportError.notAvailable('all'),
        attemptedTransport: TransportType.none,
        duration: stopwatch.elapsed,
      );
    }

    final futures = <String, Future<TransportResult<T>>>{};

    if (telegramAvailable) {
      futures['telegram'] = _executeWithTimeout(telegramExecutor);
    }
    if (restAvailable) {
      futures['rest'] = _executeWithTimeout(restExecutor);
    }

    final results = await Future.wait(futures.values, eagerError: false);

    stopwatch.stop();

    TransportResult<T>? telegramResult;
    TransportResult<T>? restResult;

    var i = 0;
    for (final key in futures.keys) {
      if (key == 'telegram') {
        telegramResult = results[i];
      } else {
        restResult = results[i];
      }
      i++;
    }

    _log(
      'Parallel complete: '
      'telegram=${telegramResult?.isSuccess}, '
      'rest=${restResult?.isSuccess}, '
      'total=${stopwatch.elapsedMilliseconds}ms',
    );

    final parallel = ParallelResult<T>(
      telegramResult: telegramResult,
      restResult: restResult,
      totalDuration: stopwatch.elapsed,
    );

    return merger.merge(parallel, strategy: strategy);
  }

  Future<TransportResult<T>> executeRace<T>({
    required Future<TransportResult<T>> Function() telegramExecutor,
    required Future<TransportResult<T>> Function() restExecutor,
    bool onlyAvailable = true,
  }) async {
    final stopwatch = Stopwatch()..start();

    final telegramAvailable =
        !onlyAvailable || (telegram != null && await telegram!.isAvailable());
    final restAvailable =
        !onlyAvailable || (rest != null && await rest!.isAvailable());

    if (!telegramAvailable && !restAvailable) {
      return TransportResult.failure(
        error: const TransportError.notAvailable('all'),
        attemptedTransport: TransportType.none,
        duration: stopwatch.elapsed,
      );
    }

    final completer = Completer<TransportResult<T>>();
    var completed = false;
    final errors = <TransportError>[];

    void handleResult(TransportResult<T> result, String transport) {
      if (completed) return;

      if (result.isSuccess) {
        completed = true;
        _log('Race won by $transport in ${stopwatch.elapsedMilliseconds}ms');
        completer.complete(result);
      } else {
        if (result case TransportFailure(:final error)) {
          errors.add(error);
        }

        if (errors.length ==
            (telegramAvailable ? 1 : 0) + (restAvailable ? 1 : 0)) {
          completed = true;
          completer.complete(
            TransportResult.failure(
              error: TransportError.allFailed(errors),
              attemptedTransport: TransportType.both,
              duration: stopwatch.elapsed,
            ),
          );
        }
      }
    }

    if (telegramAvailable) {
      _executeWithTimeout(
        telegramExecutor,
      ).then((r) => handleResult(r, 'telegram'));
    }

    if (restAvailable) {
      _executeWithTimeout(restExecutor).then((r) => handleResult(r, 'rest'));
    }

    return completer.future;
  }

  Future<TransportResult<T>> executeConfirmed<T>({
    required Future<TransportResult<T>> Function() telegramExecutor,
    required Future<TransportResult<T>> Function() restExecutor,
  }) async {
    final stopwatch = Stopwatch()..start();

    final telegramAvailable = telegram != null && await telegram!.isAvailable();
    final restAvailable = rest != null && await rest!.isAvailable();

    if (!telegramAvailable || !restAvailable) {
      return TransportResult.failure(
        error: TransportError.notAvailable(
          !telegramAvailable ? 'telegram' : 'rest',
        ),
        attemptedTransport: TransportType.both,
        duration: stopwatch.elapsed,
      );
    }

    final results = await Future.wait([
      _executeWithTimeout(telegramExecutor),
      _executeWithTimeout(restExecutor),
    ]);

    final telegramResult = results[0];
    final restResult = results[1];

    stopwatch.stop();

    if (telegramResult.isSuccess && restResult.isSuccess) {
      _log('Confirmed execution successful on both transports');
      return TransportResult.success(
        data: restResult.dataOrNull as T,
        usedTransport: TransportType.both,
        duration: stopwatch.elapsed,
      );
    }

    final errors = <TransportError>[];
    if (telegramResult case TransportFailure(:final error)) {
      errors.add(error);
    }
    if (restResult case TransportFailure(:final error)) {
      errors.add(error);
    }

    _log('Confirmed execution failed: ${errors.map((e) => e.code)}');

    return TransportResult.failure(
      error: errors.length == 1
          ? errors.first
          : TransportError.allFailed(errors),
      attemptedTransport: TransportType.both,
      duration: stopwatch.elapsed,
    );
  }

  Future<TransportResult<T>> _executeWithTimeout<T>(
    Future<TransportResult<T>> Function() executor,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      return await executor().timeout(
        timeout,
        onTimeout: () => TransportResult.failure(
          error: TransportError.timeout(timeout),
          attemptedTransport: TransportType.both,
          duration: stopwatch.elapsed,
        ),
      );
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.both,
        duration: stopwatch.elapsed,
      );
    }
  }

  void _log(String message) {
    logger?.call('[ParallelExecutor] $message');
  }
}
