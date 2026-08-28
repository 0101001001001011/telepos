import 'transport_error.dart';
import 'transport_type.dart';

sealed class TransportResult<T> {
  const TransportResult();

  const factory TransportResult.success({
    required T data,
    required TransportType usedTransport,
    required Duration duration,
  }) = TransportSuccess<T>;

  const factory TransportResult.failure({
    required TransportError error,
    required TransportType attemptedTransport,
    required Duration duration,
  }) = TransportFailure<T>;

  bool get isSuccess => this is TransportSuccess<T>;

  bool get isFailure => this is TransportFailure<T>;

  T? get dataOrNull => switch (this) {
    TransportSuccess<T>(:final data) => data,
    TransportFailure<T>() => null,
  };

  TransportError? get errorOrNull => switch (this) {
    TransportSuccess<T>() => null,
    TransportFailure<T>(:final error) => error,
  };

  TransportType get transport => switch (this) {
    TransportSuccess<T>(:final usedTransport) => usedTransport,
    TransportFailure<T>(:final attemptedTransport) => attemptedTransport,
  };

  Duration get duration => switch (this) {
    TransportSuccess<T>(:final duration) => duration,
    TransportFailure<T>(:final duration) => duration,
  };

  TransportResult<R> map<R>(R Function(T data) mapper) => switch (this) {
    TransportSuccess<T>(:final data, :final usedTransport, :final duration) =>
      TransportResult.success(
        data: mapper(data),
        usedTransport: usedTransport,
        duration: duration,
      ),
    TransportFailure<T>(
      :final error,
      :final attemptedTransport,
      :final duration,
    ) =>
      TransportResult.failure(
        error: error,
        attemptedTransport: attemptedTransport,
        duration: duration,
      ),
  };

  TransportResult<T> onSuccess(void Function(T data) action) {
    if (this case TransportSuccess<T>(:final data)) {
      action(data);
    }
    return this;
  }

  TransportResult<T> onFailure(void Function(TransportError error) action) {
    if (this case TransportFailure<T>(:final error)) {
      action(error);
    }
    return this;
  }

  T getOrThrow() => switch (this) {
    TransportSuccess<T>(:final data) => data,
    TransportFailure<T>(:final error) => throw TransportException(error),
  };

  T getOrElse(T defaultValue) => switch (this) {
    TransportSuccess<T>(:final data) => data,
    TransportFailure<T>() => defaultValue,
  };
}

class TransportSuccess<T> extends TransportResult<T> {
  final T data;
  final TransportType usedTransport;
  @override
  final Duration duration;

  const TransportSuccess({
    required this.data,
    required this.usedTransport,
    required this.duration,
  });

  @override
  String toString() =>
      'TransportSuccess(data: $data, transport: $usedTransport, '
      'duration: ${duration.inMilliseconds}ms)';
}

class TransportFailure<T> extends TransportResult<T> {
  final TransportError error;
  final TransportType attemptedTransport;
  @override
  final Duration duration;

  const TransportFailure({
    required this.error,
    required this.attemptedTransport,
    required this.duration,
  });

  @override
  String toString() =>
      'TransportFailure(error: ${error.code}, transport: $attemptedTransport, '
      'duration: ${duration.inMilliseconds}ms)';
}

class TransportException implements Exception {
  final TransportError error;

  const TransportException(this.error);

  @override
  String toString() => 'TransportException: ${error.message}';
}
