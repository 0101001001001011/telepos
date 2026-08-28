import 'dart:async';

import 'rest_endpoints.dart';
import 'rest_interceptors.dart';

class RestClient {
  final String baseUrl;
  final List<RestInterceptor> interceptors;
  final Duration timeout;

  late final RestEndpoints endpoints;

  RestClient({
    required this.baseUrl,
    this.interceptors = const [],
    this.timeout = const Duration(seconds: 30),
  }) {
    endpoints = RestEndpoints(baseUrl);
  }

  Future<RestResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    return _execute(
      RestRequest(
        method: 'GET',
        path: path,
        queryParameters: queryParameters,
        headers: headers ?? {},
      ),
    );
  }

  Future<RestResponse> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    return _execute(
      RestRequest(
        method: 'POST',
        path: path,
        data: data,
        queryParameters: queryParameters,
        headers: headers ?? {},
      ),
    );
  }

  Future<RestResponse> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    return _execute(
      RestRequest(
        method: 'PUT',
        path: path,
        data: data,
        queryParameters: queryParameters,
        headers: headers ?? {},
      ),
    );
  }

  Future<RestResponse> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    return _execute(
      RestRequest(
        method: 'PATCH',
        path: path,
        data: data,
        queryParameters: queryParameters,
        headers: headers ?? {},
      ),
    );
  }

  Future<RestResponse> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    return _execute(
      RestRequest(
        method: 'DELETE',
        path: path,
        data: data,
        queryParameters: queryParameters,
        headers: headers ?? {},
      ),
    );
  }

  Future<RestResponse> uploadFile(
    String path,
    String filePath, {
    String fieldName = 'file',
    Map<String, String>? fields,
    Map<String, String>? headers,
  }) async {
    return _execute(
      RestRequest(
        method: 'POST',
        path: path,
        data: {'file': filePath, ...?fields},
        headers: {...?headers, 'Content-Type': 'multipart/form-data'},
      ),
    );
  }

  Future<String> downloadFile(
    String path,
    String savePath, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return savePath;
  }

  Future<bool> isHealthy() async {
    try {
      final response = await get(
        endpoints.health,
      ).timeout(const Duration(seconds: 5));
      return response.isSuccess;
    } catch (_) {
      return false;
    }
  }

  Future<RestResponse> _execute(RestRequest request) async {
    var currentRequest = request;

    for (final interceptor in interceptors) {
      currentRequest = await interceptor.onRequest(currentRequest);
    }

    try {
      await Future.delayed(const Duration(milliseconds: 50));

      var response = RestResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        data: <String, dynamic>{},
        request: currentRequest,
      );

      for (final interceptor in interceptors) {
        response = await interceptor.onResponse(response);
      }

      return response;
    } catch (e) {
      final error = RestError(
        message: e.toString(),
        request: currentRequest,
        originalError: e,
      );

      for (final interceptor in interceptors) {
        final recoveredResponse = await interceptor.onError(error);
        if (recoveredResponse != null) {
          return recoveredResponse;
        }
      }

      return RestResponse(
        statusCode: 0,
        headers: {},
        data: {'error': e.toString()},
        request: currentRequest,
      );
    }
  }
}
