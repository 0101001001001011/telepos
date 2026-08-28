sealed class TransportError {
  const TransportError();

  const factory TransportError.notAvailable(String transport) =
      TransportNotAvailableError;

  const factory TransportError.timeout(Duration duration) =
      TransportTimeoutError;

  const factory TransportError.network(String message) = TransportNetworkError;

  const factory TransportError.unauthorized() = TransportUnauthorizedError;

  const factory TransportError.server(int statusCode, String message) =
      TransportServerError;

  const factory TransportError.client(int statusCode, String message) =
      TransportClientError;

  const factory TransportError.parsing(String message) = TransportParsingError;

  const factory TransportError.allFailed(List<TransportError> errors) =
      TransportAllFailedError;

  const factory TransportError.cancelled() = TransportCancelledError;

  const factory TransportError.unknown(Object error) = TransportUnknownError;

  String get message;

  bool get isRetryable;

  String get code;
}

class TransportNotAvailableError extends TransportError {
  final String transport;

  const TransportNotAvailableError(this.transport);

  @override
  String get message => 'Transport $transport is not available';

  @override
  bool get isRetryable => true;

  @override
  String get code => 'TRANSPORT_NOT_AVAILABLE';
}

class TransportTimeoutError extends TransportError {
  final Duration duration;

  const TransportTimeoutError(this.duration);

  @override
  String get message => 'Operation timed out after ${duration.inSeconds}s';

  @override
  bool get isRetryable => true;

  @override
  String get code => 'TIMEOUT';
}

class TransportNetworkError extends TransportError {
  @override
  final String message;

  const TransportNetworkError(this.message);

  @override
  bool get isRetryable => true;

  @override
  String get code => 'NETWORK_ERROR';
}

class TransportUnauthorizedError extends TransportError {
  const TransportUnauthorizedError();

  @override
  String get message => 'Unauthorized - authentication required';

  @override
  bool get isRetryable => false;

  @override
  String get code => 'UNAUTHORIZED';
}

class TransportServerError extends TransportError {
  final int statusCode;
  @override
  final String message;

  const TransportServerError(this.statusCode, this.message);

  @override
  bool get isRetryable => statusCode >= 500;

  @override
  String get code => 'SERVER_ERROR_$statusCode';
}

class TransportClientError extends TransportError {
  final int statusCode;
  @override
  final String message;

  const TransportClientError(this.statusCode, this.message);

  @override
  bool get isRetryable => false;

  @override
  String get code => 'CLIENT_ERROR_$statusCode';
}

class TransportParsingError extends TransportError {
  @override
  final String message;

  const TransportParsingError(this.message);

  @override
  bool get isRetryable => false;

  @override
  String get code => 'PARSING_ERROR';
}

class TransportAllFailedError extends TransportError {
  final List<TransportError> errors;

  const TransportAllFailedError(this.errors);

  @override
  String get message =>
      'All transports failed: ${errors.map((e) => e.code).join(', ')}';

  @override
  bool get isRetryable => errors.any((e) => e.isRetryable);

  @override
  String get code => 'ALL_TRANSPORTS_FAILED';
}

class TransportCancelledError extends TransportError {
  const TransportCancelledError();

  @override
  String get message => 'Operation was cancelled';

  @override
  bool get isRetryable => false;

  @override
  String get code => 'CANCELLED';
}

class TransportUnknownError extends TransportError {
  final Object error;

  const TransportUnknownError(this.error);

  @override
  String get message => 'Unknown error: $error';

  @override
  bool get isRetryable => false;

  @override
  String get code => 'UNKNOWN';
}
