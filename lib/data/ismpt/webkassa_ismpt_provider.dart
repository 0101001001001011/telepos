import 'package:talker/talker.dart';
import 'package:telepos/data/datasources/remote/webkassa_api_client.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/ismpt/ismpt_models.dart';
import 'package:telepos/domain/ismpt/ismpt_service.dart';

class WebKassaIsMptProvider implements IsMptService {
  WebKassaIsMptProvider({
    required this.fiscalSettings,
    required Talker logger,
    WebKassaApiClient? client,
  }) : _logger = logger,
       _client = client;

  final FiscalSettings fiscalSettings;
  final Talker _logger;

  WebKassaApiClient? _client;
  String? _token;

  String get _baseUrl => fiscalSettings.hasLocalModule
      ? fiscalSettings.localModuleUrl!
      : (fiscalSettings.resolvedBaseUrl ?? '');

  WebKassaApiClient get _api {
    _client ??= WebKassaApiClient(
      baseUrl: _baseUrl,
      apiKey: fiscalSettings.apiKey,
      logger: _logger,
    );
    return _client!;
  }

  @override
  String get id => 'ismpt_webkassa';

  @override
  IsMptCapabilities get capabilities =>
      const IsMptCapabilities(supportsVerify: true, supportsWithdrawal: true);

  String? validateConfig() {
    if (fiscalSettings.apiKey == null || fiscalSettings.apiKey!.isEmpty) {
      return 'Не указан X-API-Key WebKassa для проверки маркировки';
    }
    if (fiscalSettings.login == null || fiscalSettings.login!.isEmpty) {
      return 'Не указан логин WebKassa';
    }
    if (fiscalSettings.password == null || fiscalSettings.password!.isEmpty) {
      return 'Не указан пароль WebKassa';
    }
    return null;
  }

  Future<String?> _ensureToken() async {
    if (_token != null && _token!.isNotEmpty) return null;
    final login = fiscalSettings.login;
    final password = fiscalSettings.password;
    if (login == null ||
        login.isEmpty ||
        password == null ||
        password.isEmpty) {
      return 'Не указаны логин/пароль WebKassa';
    }
    final resp = await _api.authorize(login: login, password: password);
    if (resp.success && resp.token != null) {
      _token = resp.token;
      return null;
    }
    return resp.errorMessage ?? 'Ошибка авторизации WebKassa';
  }

  @override
  Future<IsMptResult> authorize() async {
    final reason = validateConfig();
    if (reason != null) {
      return IsMptResult.failure(reason, code: IsMptErrorCode.notConfigured);
    }
    final authError = await _ensureToken();
    if (authError != null) {
      return IsMptResult.failure(authError, code: IsMptErrorCode.network);
    }
    return IsMptResult.ok();
  }

  @override
  Future<IsMptVerifyResult> verifyCodes(
    List<String> codes, {
    String? productGroup,
  }) async {
    final reason = validateConfig();
    if (reason != null) {
      return IsMptVerifyResult.failure(
        reason,
        code: IsMptErrorCode.notConfigured,
      );
    }
    final authError = await _ensureToken();
    if (authError != null) {
      return IsMptVerifyResult.failure(authError, code: IsMptErrorCode.network);
    }
    final resp = await _api.verifyMark({
      'Token': _token ?? '',
      'CashboxUniqueNumber': fiscalSettings.cashboxUniqueNumber ?? '',
      'Codes': codes,
      if (productGroup != null) 'ProductGroup': productGroup,
    });

    if (!resp.success) {
      if (resp.errorCode == 2 || resp.errorCode == 3) {
        _token = null;
        final retry = await _ensureToken();
        if (retry == null) {
          final r2 = await _api.verifyMark({
            'Token': _token ?? '',
            'CashboxUniqueNumber': fiscalSettings.cashboxUniqueNumber ?? '',
            'Codes': codes,
            if (productGroup != null) 'ProductGroup': productGroup,
          });
          if (r2.success) return _mapVerify(r2, codes);
          return IsMptVerifyResult.failure(
            r2.errorMessage ?? 'Ошибка проверки КМ',
            code: _mapError(r2.errorCode),
          );
        }
      }
      return IsMptVerifyResult.failure(
        resp.errorMessage ?? 'Ошибка проверки КМ',
        code: _mapError(resp.errorCode),
      );
    }
    return _mapVerify(resp, codes);
  }

  @override
  Future<IsMptResult> submitDocument(IsMptDocRequest req) async {
    final reason = validateConfig();
    if (reason != null) {
      return IsMptResult.failure(reason, code: IsMptErrorCode.notConfigured);
    }
    if (req.type == IsMptDocType.withdrawal) {
      return IsMptResult.ok();
    }
    return IsMptResult.queued();
  }

  @override
  Future<IsMptStatus> getStatus() async {
    final reason = validateConfig();
    if (reason != null) {
      return IsMptStatus(configured: false, online: false, lastError: reason);
    }
    final authError = await _ensureToken();
    return IsMptStatus(
      configured: true,
      online: authError == null,
      lastError: authError,
    );
  }

  IsMptVerifyResult _mapVerify(WebKassaResponse resp, List<String> codes) {
    final d = resp.data ?? const {};
    final raw = d['Results'] ?? d['results'];
    final verifications = <MarkVerification>[];
    if (raw is List) {
      for (final entry in raw) {
        if (entry is! Map) continue;
        final m = entry.cast<String, dynamic>();
        final status = _cisFromString((m['Status'] ?? m['status'])?.toString());
        verifications.add(
          MarkVerification(
            code: (m['Code'] ?? m['code'])?.toString() ?? '',
            status: status,
            valid:
                (m['Valid'] ?? m['valid']) as bool? ??
                (status == MarkCisStatus.inCirculation),
            ownerBin: (m['OwnerBin'] ?? m['ownerBin'])?.toString(),
            productGroup: (m['ProductGroup'] ?? m['productGroup'])?.toString(),
            message: (m['Message'] ?? m['message'])?.toString(),
          ),
        );
      }
    }
    return IsMptVerifyResult.ok(verifications);
  }

  IsMptErrorCode _mapError(int? code) {
    switch (code) {
      case -1:
      case -2:
      case -3:
        return IsMptErrorCode.network;
      case 2:
      case 3:
        return IsMptErrorCode.authFailed;
      case null:
        return IsMptErrorCode.unknown;
      default:
        return IsMptErrorCode.rejected;
    }
  }

  static MarkCisStatus _cisFromString(String? raw) {
    switch (raw) {
      case 'in_circulation':
      case 'inCirculation':
      case 'INTRODUCED':
        return MarkCisStatus.inCirculation;
      case 'emitted':
      case 'EMITTED':
        return MarkCisStatus.emitted;
      case 'applied':
      case 'APPLIED':
        return MarkCisStatus.applied;
      case 'retired':
      case 'written_off':
      case 'WRITTEN_OFF':
        return MarkCisStatus.retired;
      case 'aggregated':
        return MarkCisStatus.aggregated;
      case 'reserved':
        return MarkCisStatus.reserved;
      case 'blocked':
        return MarkCisStatus.blocked;
      default:
        return MarkCisStatus.unknown;
    }
  }

  void dispose() {
    _client?.dispose();
    _client = null;
  }
}
