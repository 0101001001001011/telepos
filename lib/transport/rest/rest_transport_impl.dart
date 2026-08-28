import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../interface/transport_interface_exports.dart';
import 'rest_client.dart';
import 'rest_interceptors.dart';
import 'rest_transport.dart';

class RestTransportImpl implements RestTransport {
  final RestClient _client;

  TransportStatus _status = TransportStatus.disconnected;
  String? _accessToken;
  String? _refreshToken;
  bool _wsConnected = false;

  final _statusController = StreamController<TransportStatus>.broadcast();
  final _updatesController = StreamController<TransportUpdate>.broadcast();

  RestTransportImpl({required RestClient client}) : _client = client;

  factory RestTransportImpl.withConfig({
    required String baseUrl,
    String? accessToken,
    String? refreshToken,
    Duration timeout = const Duration(seconds: 30),
  }) {
    final authInterceptor = AuthInterceptor(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    final client = RestClient(
      baseUrl: baseUrl,
      timeout: timeout,
      interceptors: [
        HeadersInterceptor.defaults(),
        authInterceptor,
        const LoggingInterceptor(),
        const RetryInterceptor(),
      ],
    );

    final transport = RestTransportImpl(client: client);
    transport._accessToken = accessToken;
    transport._refreshToken = refreshToken;

    return transport;
  }

  @override
  String get name => 'rest';

  @override
  TransportStatus get currentStatus => _status;

  @override
  Stream<TransportStatus> get statusStream => _statusController.stream;

  @override
  Stream<TransportUpdate> get updates => _updatesController.stream;

  @override
  Future<bool> isAvailable() async {
    if (_status != TransportStatus.connected) return false;

    try {
      return await _client.isHealthy();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> initialize() async {
    _updateStatus(TransportStatus.connecting);

    try {
      final healthy = await _client.isHealthy();
      if (healthy) {
        _updateStatus(TransportStatus.connected);
      } else {
        _updateStatus(TransportStatus.error);
      }
    } catch (e) {
      _updateStatus(TransportStatus.error);
    }
  }

  @override
  Future<void> dispose() async {
    await disconnectWebSocket();
    await _statusController.close();
    await _updatesController.close();
  }

  @override
  Future<TransportResult<void>> uploadSales(
    List<Map<String, dynamic>> sales,
  ) async {
    return _executePost(_client.endpoints.uploadSales, sales);
  }

  @override
  Future<TransportResult<void>> uploadRefunds(
    List<Map<String, dynamic>> refunds,
  ) async {
    return _executePost(_client.endpoints.uploadRefunds, refunds);
  }

  @override
  Future<TransportResult<void>> uploadShifts(
    List<Map<String, dynamic>> shifts,
  ) async {
    return _executePost(_client.endpoints.uploadShifts, shifts);
  }

  @override
  Future<TransportResult<void>> uploadCashOperations(
    List<Map<String, dynamic>> operations,
  ) async {
    return _executePost(_client.endpoints.uploadCashOperations, operations);
  }

  Future<TransportResult<void>> _executePost(
    String endpoint,
    dynamic data,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _client.post(endpoint, data: data);

      if (response.isSuccess) {
        return TransportResult.success(
          data: null,
          usedTransport: TransportType.rest,
          duration: stopwatch.elapsed,
        );
      }

      return _handleErrorResponse(response, stopwatch);
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.rest,
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<TransportResult<List<Map<String, dynamic>>>> downloadProducts({
    DateTime? since,
  }) async {
    return _executeGet<List<Map<String, dynamic>>>(
      _client.endpoints.downloadProducts,
      (data) => _parseList(data),
      since: since,
    );
  }

  @override
  Future<TransportResult<List<Map<String, dynamic>>>> downloadPrices({
    DateTime? since,
  }) async {
    return _executeGet<List<Map<String, dynamic>>>(
      _client.endpoints.downloadPrices,
      (data) => _parseList(data),
      since: since,
    );
  }

  @override
  Future<TransportResult<List<Map<String, dynamic>>>> downloadAgents({
    DateTime? since,
  }) async {
    return _executeGet<List<Map<String, dynamic>>>(
      _client.endpoints.downloadAgents,
      (data) => _parseList(data),
      since: since,
    );
  }

  @override
  Future<TransportResult<List<Map<String, dynamic>>>> downloadCategories({
    DateTime? since,
  }) async {
    return _executeGet<List<Map<String, dynamic>>>(
      _client.endpoints.downloadCategories,
      (data) => _parseList(data),
      since: since,
    );
  }

  @override
  Future<TransportResult<Map<String, dynamic>>> downloadConfig() async {
    return _executeGet<Map<String, dynamic>>(
      _client.endpoints.downloadPosConfig,
      (data) => data as Map<String, dynamic>,
    );
  }

  @override
  Future<TransportResult<List<Map<String, dynamic>>>> downloadUsers() async {
    return _executeGet<List<Map<String, dynamic>>>(
      '${_client.endpoints.baseUrl}/api/v1/users',
      (data) => _parseList(data),
    );
  }

  Future<TransportResult<T>> _executeGet<T>(
    String endpoint,
    T Function(dynamic) parser, {
    DateTime? since,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final queryParams = since != null
          ? {'since': since.toIso8601String()}
          : null;

      final response = await _client.get(
        endpoint,
        queryParameters: queryParams,
      );

      if (response.isSuccess) {
        final data = parser(response.data);
        return TransportResult.success(
          data: data,
          usedTransport: TransportType.rest,
          duration: stopwatch.elapsed,
        );
      }

      return _handleErrorResponse<T>(response, stopwatch);
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.rest,
        duration: stopwatch.elapsed,
      );
    }
  }

  List<Map<String, dynamic>> _parseList(dynamic data) {
    if (data is List) {
      return data.map((e) => e as Map<String, dynamic>).toList();
    }
    return [];
  }

  @override
  Future<TransportResult<String>> uploadBackup({
    required String filePath,
    required Map<String, dynamic> metadata,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _client.uploadFile(
        _client.endpoints.uploadBackup,
        filePath,
        fields: metadata.map((k, v) => MapEntry(k, v.toString())),
      );

      if (response.isSuccess) {
        final data = response.data as Map<String, dynamic>;
        final backupId =
            data['id']?.toString() ??
            'backup_${DateTime.now().millisecondsSinceEpoch}';

        return TransportResult.success(
          data: backupId,
          usedTransport: TransportType.rest,
          duration: stopwatch.elapsed,
        );
      }

      return _handleErrorResponse<String>(response, stopwatch);
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.rest,
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<TransportResult<String>> downloadBackup(String backupId) async {
    final stopwatch = Stopwatch()..start();

    try {
      final directory = await _getBackupDirectory();
      final savePath =
          '${directory.path}${Platform.pathSeparator}backup_$backupId.db';

      await _client.downloadFile(
        _client.endpoints.downloadBackup(backupId),
        savePath,
      );

      return TransportResult.success(
        data: savePath,
        usedTransport: TransportType.rest,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.rest,
        duration: stopwatch.elapsed,
      );
    }
  }

  Future<Directory> _getBackupDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(
      '${appDir.path}${Platform.pathSeparator}backups',
    );
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  @override
  Future<TransportResult<List<Map<String, dynamic>>>> listBackups() async {
    return _executeGet<List<Map<String, dynamic>>>(
      _client.endpoints.listBackups,
      (data) => _parseList(data),
    );
  }

  @override
  Future<TransportResult<void>> deleteBackup(String backupId) async {
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _client.delete(
        _client.endpoints.downloadBackup(backupId),
      );

      if (response.isSuccess) {
        return TransportResult.success(
          data: null,
          usedTransport: TransportType.rest,
          duration: stopwatch.elapsed,
        );
      }

      return _handleErrorResponse(response, stopwatch);
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.rest,
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<TransportResult<void>> sendNotification({
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    return _executePost(_client.endpoints.sendNotification, {
      'type': type,
      'title': title,
      'body': body,
      if (data != null) 'data': data,
    });
  }

  @override
  Future<TransportResult<void>> sendReport({
    required String type,
    required Map<String, dynamic> data,
    String? filePath,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      RestResponse response;

      if (filePath != null) {
        response = await _client.uploadFile(
          _client.endpoints.sendReport,
          filePath,
          fields: {'type': type, 'data': data.toString()},
        );
      } else {
        response = await _client.post(
          _client.endpoints.sendReport,
          data: {'type': type, 'data': data},
        );
      }

      if (response.isSuccess) {
        return TransportResult.success(
          data: null,
          usedTransport: TransportType.rest,
          duration: stopwatch.elapsed,
        );
      }

      return _handleErrorResponse(response, stopwatch);
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.rest,
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<void> subscribeToUpdates(List<String> types) async {}

  @override
  Future<void> unsubscribeFromUpdates() async {}

  @override
  String? get accessToken => _accessToken;

  @override
  set accessToken(String? token) {
    _accessToken = token;
  }

  @override
  String? get refreshToken => _refreshToken;

  @override
  set refreshToken(String? token) {
    _refreshToken = token;
  }

  @override
  Future<bool> isTokenValid() async {
    if (_accessToken == null) return false;

    return true;
  }

  @override
  Future<TransportResult<String>> refreshAccessToken() async {
    final stopwatch = Stopwatch()..start();

    if (_refreshToken == null) {
      return TransportResult.failure(
        error: const TransportError.unauthorized(),
        attemptedTransport: TransportType.rest,
        duration: stopwatch.elapsed,
      );
    }

    try {
      final response = await _client.post(
        _client.endpoints.refreshToken,
        data: {'refreshToken': _refreshToken},
      );

      if (response.isSuccess) {
        final data = response.data as Map<String, dynamic>;
        _accessToken = data['accessToken'] as String?;
        _refreshToken = data['refreshToken'] as String? ?? _refreshToken;

        return TransportResult.success(
          data: _accessToken!,
          usedTransport: TransportType.rest,
          duration: stopwatch.elapsed,
        );
      }

      return _handleErrorResponse<String>(response, stopwatch);
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.rest,
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<TransportResult<Map<String, dynamic>>> registerPos(
    Map<String, dynamic> posInfo,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _client.post(
        _client.endpoints.registerPos,
        data: posInfo,
      );

      if (response.isSuccess) {
        final data = response.data as Map<String, dynamic>;
        _accessToken = data['accessToken'] as String?;
        _refreshToken = data['refreshToken'] as String?;

        return TransportResult.success(
          data: data,
          usedTransport: TransportType.rest,
          duration: stopwatch.elapsed,
        );
      }

      return _handleErrorResponse<Map<String, dynamic>>(response, stopwatch);
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.rest,
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<TransportResult<Map<String, dynamic>>> loginByCredentials(
    String email,
    String password,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _client.post(
        _client.endpoints.login,
        data: {'email': email, 'password': password},
      );

      if (response.isSuccess) {
        final data = response.data as Map<String, dynamic>;
        _accessToken = data['accessToken'] as String?;
        _refreshToken = data['refreshToken'] as String?;

        return TransportResult.success(
          data: data,
          usedTransport: TransportType.rest,
          duration: stopwatch.elapsed,
        );
      }

      return _handleErrorResponse<Map<String, dynamic>>(response, stopwatch);
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.rest,
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<TransportResult<Map<String, dynamic>>> loginByPin(
    String pin,
    String posId,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _client.post(
        _client.endpoints.loginByPin,
        data: {'pin': pin, 'posId': posId},
      );

      if (response.isSuccess) {
        return TransportResult.success(
          data: response.data as Map<String, dynamic>,
          usedTransport: TransportType.rest,
          duration: stopwatch.elapsed,
        );
      }

      return _handleErrorResponse<Map<String, dynamic>>(response, stopwatch);
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.rest,
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  bool get isWebSocketConnected => _wsConnected;

  @override
  Future<TransportResult<void>> connectWebSocket() async {
    final stopwatch = Stopwatch()..start();

    try {
      _wsConnected = true;

      return TransportResult.success(
        data: null,
        usedTransport: TransportType.rest,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      _wsConnected = false;
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.rest,
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<void> disconnectWebSocket() async {
    _wsConnected = false;
  }

  void _updateStatus(TransportStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
    }
  }

  TransportResult<T> _handleErrorResponse<T>(
    RestResponse response,
    Stopwatch stopwatch,
  ) {
    final statusCode = response.statusCode;

    TransportError error;
    if (statusCode == 401) {
      error = const TransportError.unauthorized();
    } else if (statusCode >= 500) {
      final message = _extractErrorMessage(response.data);
      error = TransportError.server(statusCode, message);
    } else if (statusCode >= 400) {
      final message = _extractErrorMessage(response.data);
      error = TransportError.client(statusCode, message);
    } else {
      error = TransportError.unknown('Status: $statusCode');
    }

    return TransportResult.failure(
      error: error,
      attemptedTransport: TransportType.rest,
      duration: stopwatch.elapsed,
    );
  }

  String _extractErrorMessage(dynamic data) {
    if (data is Map) {
      return data['message']?.toString() ??
          data['error']?.toString() ??
          'Unknown error';
    }
    return data?.toString() ?? 'Unknown error';
  }
}
