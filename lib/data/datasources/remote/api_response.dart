class ApiResponse<T> {
  const ApiResponse({
    required this.success,
    this.data,
    this.statusCode,
    this.errorCode,
    this.errorMessage,
    this.timestamp,
  });

  final bool success;

  final T? data;

  final int? statusCode;

  final String? errorCode;

  final String? errorMessage;

  final DateTime? timestamp;

  factory ApiResponse.ok(T data, {int statusCode = 200}) {
    return ApiResponse(
      success: true,
      data: data,
      statusCode: statusCode,
      timestamp: DateTime.now(),
    );
  }

  factory ApiResponse.error({
    required String message,
    String? code,
    int? statusCode,
  }) {
    return ApiResponse(
      success: false,
      errorCode: code,
      errorMessage: message,
      statusCode: statusCode,
      timestamp: DateTime.now(),
    );
  }

  factory ApiResponse.offline() {
    return ApiResponse(
      success: false,
      errorCode: 'OFFLINE',
      errorMessage: 'Network connection unavailable',
      timestamp: DateTime.now(),
    );
  }

  factory ApiResponse.notConfigured() {
    return ApiResponse(
      success: false,
      errorCode: 'NOT_CONFIGURED',
      errorMessage: 'API not configured',
      timestamp: DateTime.now(),
    );
  }

  factory ApiResponse.timeout() {
    return ApiResponse(
      success: false,
      errorCode: 'TIMEOUT',
      errorMessage: 'Request timed out',
      timestamp: DateTime.now(),
    );
  }

  factory ApiResponse.stub() {
    return ApiResponse(
      success: false,
      errorCode: 'NOT_IMPLEMENTED',
      errorMessage: 'API method is a stub (not implemented)',
      timestamp: DateTime.now(),
    );
  }

  bool get isOfflineError => errorCode == 'OFFLINE';

  bool get isTimeoutError => errorCode == 'TIMEOUT';

  bool get isStubResponse => errorCode == 'NOT_IMPLEMENTED';

  @override
  String toString() {
    if (success) {
      return 'ApiResponse.ok(data: $data, status: $statusCode)';
    }
    return 'ApiResponse.error($errorCode: $errorMessage)';
  }
}

class PaginatedApiResponse<T> extends ApiResponse<List<T>> {
  const PaginatedApiResponse({
    required super.success,
    super.data,
    super.statusCode,
    super.errorCode,
    super.errorMessage,
    super.timestamp,
    this.page,
    this.pageSize,
    this.totalItems,
    this.totalPages,
    this.hasNextPage,
  });

  final int? page;

  final int? pageSize;

  final int? totalItems;

  final int? totalPages;

  final bool? hasNextPage;

  factory PaginatedApiResponse.ok(
    List<T> data, {
    int statusCode = 200,
    int page = 1,
    int pageSize = 20,
    int? totalItems,
    int? totalPages,
    bool? hasNextPage,
  }) {
    return PaginatedApiResponse(
      success: true,
      data: data,
      statusCode: statusCode,
      timestamp: DateTime.now(),
      page: page,
      pageSize: pageSize,
      totalItems: totalItems ?? data.length,
      totalPages: totalPages,
      hasNextPage: hasNextPage ?? false,
    );
  }

  factory PaginatedApiResponse.empty({int statusCode = 200}) {
    return PaginatedApiResponse(
      success: true,
      data: [],
      statusCode: statusCode,
      timestamp: DateTime.now(),
      page: 1,
      pageSize: 20,
      totalItems: 0,
      totalPages: 0,
      hasNextPage: false,
    );
  }

  factory PaginatedApiResponse.error({
    required String message,
    String? code,
    int? statusCode,
  }) {
    return PaginatedApiResponse(
      success: false,
      errorCode: code,
      errorMessage: message,
      statusCode: statusCode,
      timestamp: DateTime.now(),
    );
  }

  factory PaginatedApiResponse.stub() {
    return PaginatedApiResponse(
      success: false,
      errorCode: 'NOT_IMPLEMENTED',
      errorMessage: 'API method is a stub (not implemented)',
      timestamp: DateTime.now(),
    );
  }
}
