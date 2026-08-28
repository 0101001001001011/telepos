import 'dart:async';

abstract class RestInterceptor {
  Future<RestRequest> onRequest(RestRequest request);

  Future<RestResponse> onResponse(RestResponse response);

  Future<RestResponse?> onError(RestError error);
}

class RestRequest {
  final String method;
  final String path;
  final Map<String, String> headers;
  final dynamic data;
  final Map<String, dynamic>? queryParameters;

  RestRequest({
    required this.method,
    required this.path,
    this.headers = const {},
    this.data,
    this.queryParameters,
  });

  RestRequest copyWith({
    String? method,
    String? path,
    Map<String, String>? headers,
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return RestRequest(
      method: method ?? this.method,
      path: path ?? this.path,
      headers: headers ?? this.headers,
      data: data ?? this.data,
      queryParameters: queryParameters ?? this.queryParameters,
    );
  }
}

class RestResponse {
  final int statusCode;
  final Map<String, String> headers;
  final dynamic data;
  final RestRequest request;

  const RestResponse({
    required this.statusCode,
    required this.headers,
    required this.data,
    required this.request,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

class RestError {
  final String message;
  final int? statusCode;
  final RestRequest request;
  final RestResponse? response;
  final Object? originalError;

  const RestError({
    required this.message,
    this.statusCode,
    required this.request,
    this.response,
    this.originalError,
  });
}

class AuthInterceptor implements RestInterceptor {
  String? _accessToken;
  String? _refreshToken;
  final Future<String?> Function()? onRefreshToken;

  AuthInterceptor({
    String? accessToken,
    String? refreshToken,
    this.onRefreshToken,
  }) : _accessToken = accessToken,
       _refreshToken = refreshToken;

  void setTokens({String? accessToken, String? refreshToken}) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  @override
  Future<RestRequest> onRequest(RestRequest request) async {
    if (_accessToken != null) {
      final headers = Map<String, String>.from(request.headers);
      headers['Authorization'] = 'Bearer $_accessToken';
      return request.copyWith(headers: headers);
    }
    return request;
  }

  @override
  Future<RestResponse> onResponse(RestResponse response) async {
    return response;
  }

  @override
  Future<RestResponse?> onError(RestError error) async {
    if (error.statusCode == 401 &&
        _refreshToken != null &&
        onRefreshToken != null) {
      final newToken = await onRefreshToken!();
      if (newToken != null) {
        _accessToken = newToken;
        return null;
      }
    }
    return null;
  }
}

class LoggingInterceptor implements RestInterceptor {
  final void Function(String message)? logger;

  const LoggingInterceptor({this.logger});

  void _log(String message) {
    if (logger != null) {
      logger!(message);
    }
  }

  @override
  Future<RestRequest> onRequest(RestRequest request) async {
    _log('[REST] --> ${request.method} ${request.path}');
    return request;
  }

  @override
  Future<RestResponse> onResponse(RestResponse response) async {
    _log('[REST] <-- ${response.statusCode} ${response.request.path}');
    return response;
  }

  @override
  Future<RestResponse?> onError(RestError error) async {
    _log('[REST] ERROR ${error.statusCode}: ${error.message}');
    return null;
  }
}

class RetryInterceptor implements RestInterceptor {
  final int maxRetries;
  final Duration baseDelay;
  final bool Function(int statusCode)? shouldRetry;

  const RetryInterceptor({
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 500),
    this.shouldRetry,
  });

  bool _defaultShouldRetry(int statusCode) {
    return statusCode >= 500 || statusCode == 408 || statusCode == 429;
  }

  @override
  Future<RestRequest> onRequest(RestRequest request) async => request;

  @override
  Future<RestResponse> onResponse(RestResponse response) async => response;

  @override
  Future<RestResponse?> onError(RestError error) async {
    final statusCode = error.statusCode;
    if (statusCode == null) return null;

    final shouldRetryFn = shouldRetry ?? _defaultShouldRetry;
    if (!shouldRetryFn(statusCode)) return null;

    return null;
  }
}

class HeadersInterceptor implements RestInterceptor {
  final Map<String, String> headers;

  const HeadersInterceptor(this.headers);

  factory HeadersInterceptor.defaults({
    String? userAgent,
    String? posId,
    String? appVersion,
  }) {
    return HeadersInterceptor({
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (userAgent != null) 'User-Agent': userAgent,
      if (posId != null) 'X-POS-ID': posId,
      if (appVersion != null) 'X-App-Version': appVersion,
    });
  }

  @override
  Future<RestRequest> onRequest(RestRequest request) async {
    final mergedHeaders = {...headers, ...request.headers};
    return request.copyWith(headers: mergedHeaders);
  }

  @override
  Future<RestResponse> onResponse(RestResponse response) async => response;

  @override
  Future<RestResponse?> onError(RestError error) async => null;
}
