import 'package:talker/talker.dart';
import 'package:telepos/data/datasources/remote/webkassa_api_client.dart';
import 'package:telepos/data/esf/kgd_esf_provider.dart';
import 'package:telepos/domain/esf/esf_models.dart';
import 'package:telepos/domain/esf/esf_settings.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

class WebKassaEsfTransport implements EsfSoapTransport {
  WebKassaEsfTransport({
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
  bool get canSign => true;

  Future<String?> _ensureToken() async {
    if (_token != null && _token!.isNotEmpty) return null;
    final login = fiscalSettings.login;
    final password = fiscalSettings.password;
    if (login == null ||
        login.isEmpty ||
        password == null ||
        password.isEmpty) {
      return 'Не указаны логин/пароль WebKassa для ЭСФ';
    }
    final resp = await _api.authorize(login: login, password: password);
    if (resp.success && resp.token != null) {
      _token = resp.token;
      return null;
    }
    return resp.errorMessage ?? 'Ошибка авторизации WebKassa';
  }

  @override
  Future<EsfResult> importInvoice(
    EsfInvoice invoice,
    EsfSettings settings,
  ) async {
    final authError = await _ensureToken();
    if (authError != null) {
      return EsfResult.failure(authError, code: EsfErrorCode.network);
    }
    final resp = await _api.esf(_invoiceBody(invoice, settings));
    if (!resp.success && (resp.errorCode == 2 || resp.errorCode == 3)) {
      _token = null;
      final retryAuth = await _ensureToken();
      if (retryAuth == null) {
        return _mapEsf(await _api.esf(_invoiceBody(invoice, settings)));
      }
    }
    return _mapEsf(resp);
  }

  @override
  Future<EsfResult> statusByRegistration(String registrationNumber) async {
    final authError = await _ensureToken();
    if (authError != null) {
      return EsfResult.failure(authError, code: EsfErrorCode.network);
    }
    final resp = await _api.esf({
      'Token': _token ?? '',
      'Operation': 'status',
      'RegistrationNumber': registrationNumber,
    });
    return _mapEsf(resp);
  }

  @override
  Future<EsfResult> revoke(
    EsfInvoice invoice,
    EsfSettings settings, {
    String? reason,
  }) async {
    final authError = await _ensureToken();
    if (authError != null) {
      return EsfResult.failure(authError, code: EsfErrorCode.network);
    }
    final resp = await _api.esf({
      'Token': _token ?? '',
      'Operation': 'revoke',
      'RegistrationNumber': invoice.registrationNumber ?? '',
      'IdempotencyKey': invoice.idempotencyKey,
      'SellerBin': invoice.supplier.binIin,
      if (reason != null) 'Reason': reason,
    });
    return _mapEsf(resp);
  }

  Map<String, dynamic> _invoiceBody(EsfInvoice invoice, EsfSettings settings) {
    return {
      'Token': _token ?? '',
      'CashboxUniqueNumber': fiscalSettings.cashboxUniqueNumber ?? '',
      'IdempotencyKey': invoice.idempotencyKey,
      'AccountingNumber': invoice.accountingNumber,
      'Direction': invoice.direction.name,
      'DocumentType': invoice.documentType.name,
      'Currency': invoice.currency,
      if (invoice.exchangeRate != null)
        'ExchangeRate': invoice.exchangeRate.toString(),
      'TurnoverDate': invoice.turnoverDate.toIso8601String(),
      'IssueDate': invoice.issueDate.toIso8601String(),
      'SellerBin': invoice.supplier.binIin,
      'BuyerBin': invoice.buyer.binIin,
      'Supplier': invoice.supplier.toJson(),
      'Buyer': invoice.buyer.toJson(),
      'Positions': invoice.lines.map((l) => l.toJson()).toList(),
      'VatBuckets': invoice.vatBuckets.map((b) => b.toJson()).toList(),
      'TotalTaxable': invoice.totalTaxable.toString(),
      'TotalVat': invoice.totalVat.toString(),
      'TotalWithVat': invoice.totalWithVat.toString(),
      if (settings.supplierBin != null && settings.supplierBin!.isNotEmpty)
        'SettingsSupplierBin': settings.supplierBin,
      if (invoice.registrationNumber != null)
        'RegistrationNumber': invoice.registrationNumber,
    };
  }

  EsfResult _mapEsf(WebKassaResponse resp) {
    if (resp.success) {
      final d = resp.data ?? const {};
      final reg = (d['RegistrationNumber'] ?? d['registrationNumber'])
          ?.toString();
      if (reg != null && reg.isNotEmpty) {
        return EsfResult.delivered(reg);
      }
      return const EsfResult(
        success: true,
        status: EsfStatus.submitted,
        queued: true,
      );
    }
    return EsfResult.failure(
      resp.errorMessage ?? 'Ошибка ЭСФ WebKassa',
      code: _mapError(resp.errorCode),
    );
  }

  EsfErrorCode _mapError(int? code) {
    switch (code) {
      case -1:
      case -2:
      case -3:
        return EsfErrorCode.network;
      case 2:
      case 3:
        return EsfErrorCode.network;
      case 9:
        return EsfErrorCode.validation;
      case null:
        return EsfErrorCode.unknown;
      default:
        return EsfErrorCode.rejected;
    }
  }

  void dispose() {
    _client?.dispose();
    _client = null;
  }
}
