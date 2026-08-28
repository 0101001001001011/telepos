abstract class RequestInterceptor {
  String get name;

  int get priority => 100;

  Future<NetworkRequest?> onRequest(NetworkRequest request) async {
    return request;
  }

  Future<NetworkResponse> onResponse(NetworkResponse response) async {
    return response;
  }

  Future<NetworkError> onError(NetworkError error) async {
    return error;
  }
}

class NetworkRequest {
  NetworkRequest({
    required this.method,
    required this.path,
    this.headers = const {},
    this.body,
    this.queryParameters = const {},
    this.timeout = const Duration(seconds: 30),
    this.metadata = const {},
  });

  final String method;

  final String path;

  final Map<String, String> headers;

  final dynamic body;

  final Map<String, String> queryParameters;

  final Duration timeout;

  final Map<String, dynamic> metadata;

  NetworkRequest copyWith({
    String? method,
    String? path,
    Map<String, String>? headers,
    dynamic body,
    Map<String, String>? queryParameters,
    Duration? timeout,
    Map<String, dynamic>? metadata,
  }) {
    return NetworkRequest(
      method: method ?? this.method,
      path: path ?? this.path,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      queryParameters: queryParameters ?? this.queryParameters,
      timeout: timeout ?? this.timeout,
      metadata: metadata ?? this.metadata,
    );
  }

  NetworkRequest addHeader(String key, String value) {
    return copyWith(headers: {...headers, key: value});
  }

  NetworkRequest addHeaders(Map<String, String> newHeaders) {
    return copyWith(headers: {...headers, ...newHeaders});
  }

  @override
  String toString() {
    return 'NetworkRequest($method $path)';
  }
}

class NetworkResponse {
  const NetworkResponse({
    required this.statusCode,
    this.headers = const {},
    this.body,
    this.request,
    this.timestamp,
  });

  final int statusCode;

  final Map<String, String> headers;

  final dynamic body;

  final NetworkRequest? request;

  final DateTime? timestamp;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  bool get isClientError => statusCode >= 400 && statusCode < 500;

  bool get isServerError => statusCode >= 500;

  String? getHeader(String key) {
    final lowerKey = key.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lowerKey) {
        return entry.value;
      }
    }
    return null;
  }

  @override
  String toString() {
    return 'NetworkResponse($statusCode)';
  }
}

class NetworkError {
  const NetworkError({
    required this.type,
    required this.message,
    this.statusCode,
    this.request,
    this.originalError,
    this.stackTrace,
  });

  final NetworkErrorType type;

  final String message;

  final int? statusCode;

  final NetworkRequest? request;

  final Object? originalError;

  final StackTrace? stackTrace;

  factory NetworkError.timeout({NetworkRequest? request}) {
    return NetworkError(
      type: NetworkErrorType.timeout,
      message: 'Request timed out',
      request: request,
    );
  }

  factory NetworkError.connection({
    String message = 'Connection failed',
    NetworkRequest? request,
  }) {
    return NetworkError(
      type: NetworkErrorType.connection,
      message: message,
      request: request,
    );
  }

  factory NetworkError.server({
    required int statusCode,
    String? message,
    NetworkRequest? request,
  }) {
    return NetworkError(
      type: NetworkErrorType.server,
      message: message ?? 'Server error: $statusCode',
      statusCode: statusCode,
      request: request,
    );
  }

  factory NetworkError.unknown({
    String message = 'Unknown error',
    Object? originalError,
    StackTrace? stackTrace,
    NetworkRequest? request,
  }) {
    return NetworkError(
      type: NetworkErrorType.unknown,
      message: message,
      originalError: originalError,
      stackTrace: stackTrace,
      request: request,
    );
  }

  @override
  String toString() {
    return 'NetworkError($type: $message)';
  }
}

enum NetworkErrorType {
  timeout,

  connection,

  server,

  client,

  cancelled,

  parsing,

  unknown,
}
