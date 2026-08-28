import 'package:talker/talker.dart';
import 'package:telepos/data/datasources/remote/webkassa_api_client.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/snt/snt_models.dart';
import 'package:telepos/domain/snt/snt_provider.dart';
import 'package:telepos/domain/snt/snt_settings.dart';

class WebKassaSntProvider implements SntProvider {
  WebKassaSntProvider({
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
  String get id => 'webkassa';

  @override
  SntCapabilities get capabilities => const SntCapabilities(
    canSubmit: true,
    canConfirmInbound: true,
    canRevoke: true,
  );

  @override
  String? validateConfig(SntSettings config) {
    if (fiscalSettings.apiKey == null || fiscalSettings.apiKey!.isEmpty) {
      return 'Не указан X-API-Key WebKassa для СНТ';
    }
    if (fiscalSettings.login == null || fiscalSettings.login!.isEmpty) {
      return 'Не указан логин WebKassa для СНТ';
    }
    if (fiscalSettings.password == null || fiscalSettings.password!.isEmpty) {
      return 'Не указан пароль WebKassa для СНТ';
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
      return 'Не указаны логин/пароль WebKassa для СНТ';
    }
    final resp = await _api.authorize(login: login, password: password);
    if (resp.success && resp.token != null) {
      _token = resp.token;
      return null;
    }
    return resp.errorMessage ?? 'Ошибка авторизации WebKassa';
  }

  @override
  Future<SntResult> authorize(SntSettings config) async {
    final invalid = validateConfig(config);
    if (invalid != null) {
      return SntResult.failure(invalid, code: SntErrorCode.notConfigured);
    }
    final authError = await _ensureToken();
    if (authError != null) {
      return SntResult.failure(authError, code: SntErrorCode.authFailed);
    }
    return SntResult.ok();
  }

  @override
  Future<SntResult> submit(SntDocument doc) async {
    return _call(
      {..._submitBody(doc), 'Operation': 'submit'},
      onSuccess: (d) {
        final number =
            (d['RegistrationNumber'] ??
                    d['SntNumber'] ??
                    d['registrationNumber'])
                ?.toString();
        return SntResult.ok(
          status: SntStatus.registered,
          registrationNumber: number,
        );
      },
    );
  }

  @override
  Future<SntResult> confirmInbound(SntDocument doc) async {
    final number = doc.registrationNumber;
    if (number == null || number.isEmpty) {
      return SntResult.failure(
        'Нельзя подтвердить СНТ без регистрационного номера',
        code: SntErrorCode.validation,
      );
    }
    return _call({
      'Operation': 'confirm',
      'RegistrationNumber': number,
      'RecipientBin': doc.recipient.bin,
    }, onSuccess: (_) => SntResult.ok(status: SntStatus.confirmed));
  }

  @override
  Future<SntResult> rejectInbound(SntDocument doc, {String? reason}) async {
    final number = doc.registrationNumber;
    if (number == null || number.isEmpty) {
      return SntResult.failure(
        'Нельзя отклонить СНТ без регистрационного номера',
        code: SntErrorCode.validation,
      );
    }
    return _call({
      'Operation': 'reject',
      'RegistrationNumber': number,
      'RecipientBin': doc.recipient.bin,
      if (reason != null) 'Reason': reason,
    }, onSuccess: (_) => SntResult.ok(status: SntStatus.rejected));
  }

  @override
  Future<SntResult> revoke(SntDocument doc, {String? reason}) async {
    final number = doc.registrationNumber;
    if (number == null || number.isEmpty) {
      return SntResult.failure(
        'Нельзя отозвать СНТ без регистрационного номера',
        code: SntErrorCode.validation,
      );
    }
    return _call({
      'Operation': 'revoke',
      'RegistrationNumber': number,
      'SenderBin': doc.sender.bin,
      if (reason != null) 'Reason': reason,
    }, onSuccess: (_) => SntResult.ok(status: SntStatus.revoked));
  }

  Map<String, dynamic> _submitBody(SntDocument doc) => {
    'IdempotencyKey': doc.idempotencyKey,
    'CashboxUniqueNumber': fiscalSettings.cashboxUniqueNumber ?? '',
    'Direction': doc.direction.name,
    'OperationType': doc.operationType.name,
    'SenderBin': doc.sender.bin,
    'SenderWarehouse': doc.sender.warehouseCode,
    'RecipientBin': doc.recipient.bin,
    'RecipientWarehouse': doc.recipient.warehouseCode,
    'WithTransport': doc.withTransport,
    'OccurredAt': doc.occurredAt.toIso8601String(),
    if (doc.comment != null) 'Comment': doc.comment,
    'Positions': doc.lines
        .map(
          (l) => {
            'Name': l.name,
            'Quantity': l.quantity.toString(),
            'UnitCode': l.unitCode,
            if (l.price != null) 'Price': l.price!.toString(),
            if (l.amount != null) 'Amount': l.amount!.toString(),
            if (l.vat != null) 'Vat': l.vat!.toString(),
            if (l.gtin != null) 'Gtin': l.gtin,
            if (l.ntin != null) 'Ntin': l.ntin,
            if (l.tnved != null) 'Tnved': l.tnved,
            'IsTraceable': l.isTraceable,
            if (l.markCodes.isNotEmpty) 'MarkCodes': l.markCodes,
            if (l.originCountry != null) 'OriginCountry': l.originCountry,
          },
        )
        .toList(),
  };

  Future<SntResult> _call(
    Map<String, dynamic> body, {
    required SntResult Function(Map<String, dynamic> data) onSuccess,
  }) async {
    final authError = await _ensureToken();
    if (authError != null) {
      return SntResult.failure(authError, code: SntErrorCode.network);
    }
    var resp = await _api.snt({'Token': _token ?? '', ...body});
    if (!resp.success && (resp.errorCode == 2 || resp.errorCode == 3)) {
      _token = null;
      final retryAuth = await _ensureToken();
      if (retryAuth == null) {
        resp = await _api.snt({'Token': _token ?? '', ...body});
      }
    }
    if (resp.success) {
      return onSuccess(resp.data ?? const {});
    }
    return SntResult.failure(
      resp.errorMessage ?? 'Ошибка СНТ WebKassa',
      code: _mapError(resp.errorCode),
    );
  }

  SntErrorCode _mapError(int? code) {
    switch (code) {
      case -1:
      case -2:
      case -3:
        return SntErrorCode.network;
      case 2:
      case 3:
        return SntErrorCode.authFailed;
      case 9:
        return SntErrorCode.validation;
      case 14:
        return SntErrorCode.duplicate;
      case null:
        return SntErrorCode.unknown;
      default:
        return SntErrorCode.validation;
    }
  }

  void dispose() {
    _client?.dispose();
    _client = null;
  }
}
