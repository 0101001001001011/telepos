import 'package:dio/dio.dart';

import 'package:telepos/data/esutd/esutd_settings_store.dart';
import 'package:telepos/domain/esutd/esutd_models.dart';
import 'package:telepos/domain/esutd/esutd_settings.dart';

class EsutdService {
  EsutdService({required EsutdSettingsStore store, Dio? dio})
    : _store = store,
      _dio = dio ?? _createDio();

  final EsutdSettingsStore _store;
  final Dio _dio;

  static Dio _createDio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      validateStatus: (s) => s != null && s < 500,
    ),
  );

  EsutdSettings get _settings => _store.load();

  Future<EsutdLoginResult> login({String? email, String? password}) async {
    final s = _settings;
    final useEmail = email ?? s.email;
    final usePassword = password ?? s.password;
    if (useEmail == null ||
        useEmail.isEmpty ||
        usePassword == null ||
        usePassword.isEmpty) {
      return EsutdResult.failure(
        EsutdErrorCode.notConfigured,
        'Не указаны email/пароль ЕСУТД',
      );
    }

    try {
      final resp = await _dio.post(
        '${s.resolvedApiUrl}/public-auth/sign-in',
        data: {
          'email': useEmail,
          'password': usePassword,
          'rememberMe': '',
          'isReadWarning': true,
        },
      );

      if (resp.statusCode == null || resp.statusCode! >= 400) {
        return EsutdResult.failure(
          EsutdErrorCode.auth,
          _extractMessage(resp.data) ?? 'Ошибка входа (${resp.statusCode})',
        );
      }

      final cookies = _extractCookies(resp);
      if (cookies == null || cookies.isEmpty) {
        return EsutdResult.failure(
          EsutdErrorCode.auth,
          'Сервер не вернул сессионную cookie',
        );
      }

      await _store.save(
        s.copyWith(
          email: useEmail,
          password: usePassword,
          authCookies: cookies,
          authObtainedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      return EsutdResult.ok(null);
    } on DioException catch (e) {
      return EsutdResult.failure(EsutdErrorCode.network, _dioMessage(e));
    } catch (e) {
      return EsutdResult.failure(EsutdErrorCode.unknown, e.toString());
    }
  }

  Future<String?> _ensureSession() async {
    final s = _settings;
    if (s.hasValidSession) return s.authCookies;
    final r = await login();
    if (!r.success) return null;
    return _settings.authCookies;
  }

  Future<EsutdResult<dynamic>> _request(
    String path, {
    String method = 'GET',
    Object? body,
  }) async {
    if (!_settings.isActive) {
      return EsutdResult.failure(
        EsutdErrorCode.notConfigured,
        'ЕСУТД не настроена',
      );
    }

    var cookie = await _ensureSession();
    if (cookie == null) {
      return EsutdResult.failure(
        EsutdErrorCode.auth,
        'Не удалось авторизоваться в ЕСУТД',
      );
    }

    Future<Response<dynamic>> send(String c) => _dio.request(
      '${_settings.resolvedApiUrl}$path',
      data: body,
      options: Options(method: method, headers: {'Cookie': c}),
    );

    try {
      var resp = await send(cookie);

      if (resp.statusCode == 401 || resp.statusCode == 403) {
        final r = await login();
        if (!r.success) {
          return EsutdResult.failure(
            EsutdErrorCode.auth,
            r.errorMessage ?? 'Повторный вход не удался',
          );
        }
        cookie = _settings.authCookies!;
        resp = await send(cookie);
      }

      final code = resp.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        return EsutdResult.ok(resp.data);
      }
      if (code == 401 || code == 403) {
        return EsutdResult.failure(
          EsutdErrorCode.auth,
          'Доступ запрещён ($code)',
        );
      }
      return EsutdResult.failure(
        EsutdErrorCode.server,
        _extractMessage(resp.data) ?? 'Ошибка запроса ($code)',
      );
    } on DioException catch (e) {
      return EsutdResult.failure(EsutdErrorCode.network, _dioMessage(e));
    } catch (e) {
      return EsutdResult.failure(EsutdErrorCode.unknown, e.toString());
    }
  }

  Future<EsutdResult<EsutdOrganization>> getOrganization() async {
    final r = await _request('/organizations/my-organization');
    if (!r.success) {
      return EsutdResult.failure(r.errorCode!, r.errorMessage!);
    }
    try {
      final data = r.data;
      if (data is Map) {
        return EsutdResult.ok(
          EsutdOrganization.fromJson(Map<String, dynamic>.from(data)),
        );
      }
      return EsutdResult.failure(
        EsutdErrorCode.unknown,
        'Неожиданный ответ организации',
      );
    } catch (e) {
      return EsutdResult.failure(EsutdErrorCode.unknown, e.toString());
    }
  }

  Future<EsutdResult<List<EsutdWaybill>>> listWaybills({
    EsutdWaybillDirection direction = EsutdWaybillDirection.inbound,
    int page = 0,
    int size = 50,
    Map<String, dynamic> extraFilters = const {},
  }) async {
    final filters = <String, dynamic>{
      'page': page,
      'size': size,
      'direction': direction == EsutdWaybillDirection.inbound
          ? 'INBOUND'
          : 'OUTBOUND',
      ...extraFilters,
    };
    final r = await _request(
      '/shipping-document/search',
      method: 'POST',
      body: filters,
    );
    if (!r.success) {
      return EsutdResult.failure(r.errorCode!, r.errorMessage!);
    }
    try {
      return EsutdResult.ok(_parseWaybillList(r.data));
    } catch (e) {
      return EsutdResult.failure(EsutdErrorCode.unknown, e.toString());
    }
  }

  Future<EsutdResult<Map<String, dynamic>>> getWaybillInfo(String id) async {
    final r = await _request('/shipping-document/info/$id');
    if (!r.success) {
      return EsutdResult.failure(r.errorCode!, r.errorMessage!);
    }
    final data = r.data;
    if (data is Map) {
      return EsutdResult.ok(Map<String, dynamic>.from(data));
    }
    return EsutdResult.failure(
      EsutdErrorCode.unknown,
      'Неожиданный ответ документа',
    );
  }

  Future<EsutdResult<Map<String, dynamic>>> createWaybill(
    Map<String, dynamic> documentData,
  ) async {
    final r = await _request(
      '/shipping-document/',
      method: 'POST',
      body: documentData,
    );
    if (!r.success) {
      return EsutdResult.failure(r.errorCode!, r.errorMessage!);
    }
    final data = r.data;
    return EsutdResult.ok(
      data is Map ? Map<String, dynamic>.from(data) : {'raw': data},
    );
  }

  Future<EsutdResult<dynamic>> launchForApproval(
    Map<String, dynamic> documentData,
  ) => _request(
    '/shipping-document/launch-for-approval',
    method: 'POST',
    body: documentData,
  );

  Future<EsutdResult<dynamic>> revokeWaybill(String id) =>
      _request('/shipping-document/$id/revoke', method: 'POST');

  List<EsutdWaybill> _parseWaybillList(dynamic data) {
    final List items;
    if (data is Map && data['content'] is List) {
      items = data['content'] as List;
    } else if (data is List) {
      items = data;
    } else {
      items = const [];
    }
    return items
        .whereType<Map>()
        .map((e) => EsutdWaybill.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  String? _extractCookies(Response<dynamic> resp) {
    final raw = resp.headers.map['set-cookie'];
    if (raw == null || raw.isEmpty) return null;
    final pairs = <String>[];
    for (final line in raw) {
      final first = line.split(';').first.trim();
      if (first.isNotEmpty && first.contains('=')) pairs.add(first);
    }
    return pairs.isEmpty ? null : pairs.join('; ');
  }

  String? _extractMessage(dynamic data) {
    if (data is Map) {
      final m = data['message'] ?? data['error'] ?? data['detail'];
      if (m != null) return m.toString();
    }
    return null;
  }

  String _dioMessage(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Нет связи с ЕСУТД (${e.type.name})';
    }
    return e.message ?? 'Ошибка сети ЕСУТД';
  }
}
