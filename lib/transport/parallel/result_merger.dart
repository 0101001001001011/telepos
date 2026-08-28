import '../interface/transport_interface_exports.dart';

enum MergeStrategy {
  preferRest,

  preferTelegram,

  firstSuccess,

  fastest,

  mergeData,
}

class ParallelResult<T> {
  final TransportResult<T>? telegramResult;

  final TransportResult<T>? restResult;

  final Duration totalDuration;

  const ParallelResult({
    this.telegramResult,
    this.restResult,
    required this.totalDuration,
  });

  bool get bothSuccessful =>
      telegramResult?.isSuccess == true && restResult?.isSuccess == true;

  bool get anySuccessful =>
      telegramResult?.isSuccess == true || restResult?.isSuccess == true;

  bool get bothFailed => !anySuccessful;

  TransportType? get fasterTransport {
    if (telegramResult == null && restResult == null) return null;
    if (telegramResult == null) return TransportType.rest;
    if (restResult == null) return TransportType.telegram;

    return telegramResult!.duration < restResult!.duration
        ? TransportType.telegram
        : TransportType.rest;
  }
}

class ResultMerger {
  final MergeStrategy defaultStrategy;
  final void Function(String message)? logger;

  const ResultMerger({
    this.defaultStrategy = MergeStrategy.preferRest,
    this.logger,
  });

  TransportResult<T> merge<T>(
    ParallelResult<T> parallel, {
    MergeStrategy? strategy,
  }) {
    final effectiveStrategy = strategy ?? defaultStrategy;

    _log(
      'Merging results: telegram=${parallel.telegramResult?.isSuccess}, '
      'rest=${parallel.restResult?.isSuccess}, strategy=$effectiveStrategy',
    );

    if (parallel.bothFailed) {
      return _createCombinedFailure(parallel);
    }

    if (!parallel.bothSuccessful) {
      return _returnSuccessful(parallel);
    }

    return switch (effectiveStrategy) {
      MergeStrategy.preferRest => parallel.restResult!,
      MergeStrategy.preferTelegram => parallel.telegramResult!,
      MergeStrategy.firstSuccess => parallel.telegramResult!,
      MergeStrategy.fastest => _returnFastest(parallel),
      MergeStrategy.mergeData => _mergeData(parallel),
    };
  }

  TransportResult<T> _returnSuccessful<T>(ParallelResult<T> parallel) {
    if (parallel.telegramResult?.isSuccess == true) {
      _log('Returning Telegram result (REST failed)');
      return parallel.telegramResult!;
    }
    _log('Returning REST result (Telegram failed)');
    return parallel.restResult!;
  }

  TransportResult<T> _returnFastest<T>(ParallelResult<T> parallel) {
    if (parallel.fasterTransport == TransportType.telegram) {
      _log(
        'Returning Telegram result (faster: '
        '${parallel.telegramResult!.duration.inMilliseconds}ms vs '
        '${parallel.restResult!.duration.inMilliseconds}ms)',
      );
      return parallel.telegramResult!;
    }
    _log(
      'Returning REST result (faster: '
      '${parallel.restResult!.duration.inMilliseconds}ms vs '
      '${parallel.telegramResult!.duration.inMilliseconds}ms)',
    );
    return parallel.restResult!;
  }

  TransportResult<T> _mergeData<T>(ParallelResult<T> parallel) {
    final telegramData = parallel.telegramResult!.dataOrNull;
    final restData = parallel.restResult!.dataOrNull;

    if (telegramData is List && restData is List) {
      _log(
        'Merging list data: telegram=${telegramData.length}, '
        'rest=${restData.length}',
      );

      final merged = <dynamic>{...restData, ...telegramData}.toList();

      return TransportResult.success(
        data: merged as T,
        usedTransport: TransportType.both,
        duration: parallel.totalDuration,
      );
    }

    _log('Cannot merge non-list data, returning REST');
    return parallel.restResult!;
  }

  TransportResult<T> _createCombinedFailure<T>(ParallelResult<T> parallel) {
    final errors = <TransportError>[];

    if (parallel.telegramResult case TransportFailure(:final error)) {
      errors.add(error);
    }
    if (parallel.restResult case TransportFailure(:final error)) {
      errors.add(error);
    }

    _log('Both transports failed: ${errors.map((e) => e.code).join(', ')}');

    return TransportResult.failure(
      error: TransportError.allFailed(errors),
      attemptedTransport: TransportType.both,
      duration: parallel.totalDuration,
    );
  }

  void _log(String message) {
    logger?.call('[ResultMerger] $message');
  }
}
