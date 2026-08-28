import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/datasources/remote/webkassa_api_client.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

class WebKassaProvider implements FiscalProvider {
  WebKassaProvider({
    required this.settings,
    required Talker logger,
    WebKassaApiClient? client,
  }) : _logger = logger,
       _client = client;

  final FiscalSettings settings;
  final Talker _logger;

  WebKassaApiClient? _client;
  String? _token;

  static const int _opPurchase = 0;
  static const int _opPurchaseReturn = 1;
  static const int _opSale = 2;
  static const int _opSaleReturn = 3;

  static const int _taxTypeNone = 0;
  static const int _taxTypeVat = 100;

  static const int _roundTypePositions = 2;

  static const int _moneyIn = 0;
  static const int _moneyOut = 1;

  @override
  String get id => 'webkassa';

  @override
  FiscalCapabilities get capabilities => const FiscalCapabilities(
    implicitShift: true,
    supportsCorrection: false,
    supportsMarking: true,
    supportsLocalModule: true,
    supportsPurchase: true,
  );

  String get _baseUrl => settings.hasLocalModule
      ? settings.localModuleUrl!
      : (settings.resolvedBaseUrl ?? '');

  WebKassaApiClient get _api {
    _client ??= WebKassaApiClient(
      baseUrl: _baseUrl,
      apiKey: settings.apiKey,
      logger: _logger,
    );
    return _client!;
  }

  String get _cashbox => settings.cashboxUniqueNumber ?? '';

  @override
  String? validateConfig(FiscalSettings config) {
    if (config.apiKey == null || config.apiKey!.isEmpty) {
      return 'Не указан X-API-Key (интеграторский ключ WebKassa)';
    }
    if (config.login == null || config.login!.isEmpty) {
      return 'Не указан логин WebKassa';
    }
    if (config.password == null || config.password!.isEmpty) {
      return 'Не указан пароль WebKassa';
    }
    if (config.cashboxUniqueNumber == null ||
        config.cashboxUniqueNumber!.isEmpty) {
      return 'Не указан заводской номер кассы (CashboxUniqueNumber)';
    }
    if (_baseUrl.isEmpty) {
      return 'Не определён адрес сервера WebKassa';
    }
    return null;
  }

  @override
  Future<FiscalAuthResult> authorize(FiscalSettings config) async {
    final invalid = validateConfig(config);
    if (invalid != null) {
      return FiscalAuthResult.failure(
        invalid,
        code: FiscalErrorCode.notConfigured,
      );
    }
    final resp = await _api.authorize(
      login: config.login!,
      password: config.password!,
    );
    if (resp.success && resp.token != null) {
      _token = resp.token;
      return FiscalAuthResult.ok(
        token: _token,
        expiresAt: DateTime.now().add(config.tokenTtl),
      );
    }
    return FiscalAuthResult.failure(
      resp.errorMessage ?? 'Ошибка авторизации WebKassa',
      code: _mapError(resp.errorCode),
    );
  }

  Future<FiscalAuthResult> _ensureToken() async {
    if (_token != null && _token!.isNotEmpty) {
      return FiscalAuthResult.ok(token: _token);
    }
    return authorize(settings);
  }

  @override
  Future<FiscalResult> fiscalizeSale(FiscalSaleRequest req) =>
      _sendCheck(req, _opSale);

  @override
  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req) =>
      _sendCheck(req, _opPurchase);

  @override
  Future<FiscalResult> fiscalizeRefund(FiscalRefundRequest req) =>
      _sendCheck(req.sale, _opSaleReturn, basis: req.basis);

  @override
  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req) =>
      _sendCheck(req.sale, _opPurchaseReturn, basis: req.basis);

  Future<FiscalResult> _sendCheck(
    FiscalSaleRequest req,
    int operationType, {
    FiscalRefundBasis? basis,
  }) async {
    final invalid = validateConfig(settings);
    if (invalid != null) return FiscalResult.notConfigured();

    return _withReauthRetry(() async {
      final body = buildCheckPayload(
        req,
        operationType,
        token: _token ?? '',
        basis: basis,
      );
      final resp = await _api.check(body);
      return _checkResult(resp);
    });
  }

  Map<String, dynamic> buildCheckPayload(
    FiscalSaleRequest req,
    int operationType, {
    required String token,
    FiscalRefundBasis? basis,
  }) {
    final positions = req.positions.map(_positionToJson).toList();
    final payments = _aggregatePayments(req.payments);

    final body = <String, dynamic>{
      'Token': token,
      'CashboxUniqueNumber': _cashbox,
      'OperationType': operationType,
      'Positions': positions,
      'Payments': payments,
      'RoundType': _roundTypePositions,
      'ExternalCheckNumber': req.idempotencyKey,
    };

    final customer = req.customer;
    if (customer != null) {
      if (customer.email != null) body['CustomerEmail'] = customer.email;
      if (customer.phone != null) body['CustomerPhone'] = customer.phone;
      if (customer.binIin != null) body['CustomerXin'] = customer.binIin;
    }

    if (basis != null) {
      body['ReturnBasisDetails'] = {
        'CheckNumber': basis.originalFiscalSign,
        'DateTime': basis.originalDateTime.toUtc().toIso8601String(),
        'RegistrationNumber': basis.originalRegistrationNumber,
        'Total': _money(basis.originalTotal),
        'IsOffline': basis.originalWasOffline,
      };
    }

    return body;
  }

  Map<String, dynamic> _positionToJson(FiscalPosition p) {
    final isVat = p.tax.mode == FiscalTaxMode.vat;
    final json = <String, dynamic>{
      'Count': _qty(p.quantity),
      'Price': _money(p.unitPrice),
      'TaxType': isVat ? _taxTypeVat : _taxTypeNone,
      'PositionName': p.name,
    };

    if (isVat) {
      json['TaxPercent'] = _money(p.tax.ratePercent);
      json['Tax'] = _money(p.tax.amount);
    }

    if (p.discountOr > Decimal.zero) json['Discount'] = _money(p.discountOr);
    if (p.markupOr > Decimal.zero) json['Markup'] = _money(p.markupOr);
    if (p.unitCode != null) json['UnitCode'] = p.unitCode;
    if (p.sectionCode != null) json['SectionCode'] = p.sectionCode;
    if (p.barcode != null) json['GTIN'] = p.barcode;
    if (p.ntin != null) json['NTIN'] = p.ntin;

    if (p.markCodes.length == 1) {
      json['Mark'] = p.markCodes.first;
    } else if (p.markCodes.length > 1) {
      json['MarkList'] = p.markCodes;
    }

    if (p.virtualWarehouse) {
      json['WarehouseType'] = 1;
      if (p.warehouseProductId != null) {
        json['ProductId'] = p.warehouseProductId;
      }
    }

    return json;
  }

  List<Map<String, dynamic>> _aggregatePayments(List<FiscalPayment> payments) {
    final byType = <int, Decimal>{};
    for (final p in payments) {
      final type = _paymentType(p.kind);
      byType[type] = (byType[type] ?? Decimal.zero) + p.amount;
    }
    return byType.entries
        .map((e) => {'Sum': _money(e.value), 'PaymentType': e.key})
        .toList();
  }

  int _paymentType(FiscalPaymentKind kind) {
    switch (kind) {
      case FiscalPaymentKind.cash:
        return 0;
      case FiscalPaymentKind.card:
        return 1;
      case FiscalPaymentKind.credit:
        return 2;
      case FiscalPaymentKind.tare:
        return 3;
      case FiscalPaymentKind.mobile:
        return 4;
    }
  }

  FiscalResult _checkResult(WebKassaResponse resp) {
    if (resp.success) {
      final d = resp.data ?? const {};
      return FiscalResult.ok(
        fiscalSign: (d['CheckNumber'] ?? '').toString(),
        registrationNumber: _regNumber(d),
        ticketUrl: d['TicketUrl'] as String?,
        shiftNumber: (d['ShiftNumber'] as num?)?.toInt(),
        documentNumber: (d['CheckOrderNumber'] as num?)?.toInt(),
        fiscalizedAt: _parseDate(d['DateTime'] ?? d['DateTimeUTC']),
        offlineMode: d['OfflineMode'] as bool? ?? false,
      );
    }
    if (resp.errorCode == 14) {
      return FiscalResult.ok(fiscalSign: '', offlineMode: false);
    }
    return _failure(resp);
  }

  String? _regNumber(Map<String, dynamic> d) {
    final cashbox = d['Cashbox'];
    if (cashbox is Map) {
      return cashbox['RegistrationNumber'] as String?;
    }
    return null;
  }

  @override
  Future<FiscalResult> moneyIn(FiscalMoneyRequest req) =>
      _moneyOp(req, _moneyIn);

  @override
  Future<FiscalResult> moneyOut(FiscalMoneyRequest req) =>
      _moneyOp(req, _moneyOut);

  Future<FiscalResult> _moneyOp(FiscalMoneyRequest req, int direction) async {
    final invalid = validateConfig(settings);
    if (invalid != null) return FiscalResult.notConfigured();

    return _withReauthRetry(() async {
      final resp = await _api.moneyOperation({
        'Token': _token ?? '',
        'CashboxUniqueNumber': _cashbox,
        'OperationType': direction,
        'Sum': _money(req.amount),
        'ExternalCheckNumber': req.idempotencyKey,
        if (req.comment != null) 'Comment': req.comment,
      });
      if (resp.success) {
        final d = resp.data ?? const {};
        return FiscalResult.ok(
          fiscalSign: (d['CheckNumber'] ?? '').toString(),
          fiscalizedAt: _parseDate(d['DateTime']),
          offlineMode: d['OfflineMode'] as bool? ?? false,
        );
      }
      if (resp.errorCode == 14) return FiscalResult.ok(fiscalSign: '');
      return _failure(resp);
    });
  }

  @override
  Future<FiscalResult> openShift(FiscalShiftRequest req) async =>
      const FiscalResult(success: true);

  @override
  Future<FiscalReportResult> closeShift(FiscalShiftRequest req) =>
      _report(zReport: true);

  @override
  Future<FiscalReportResult> xReport(FiscalShiftRequest req) =>
      _report(zReport: false);

  Future<FiscalReportResult> _report({required bool zReport}) async {
    final invalid = validateConfig(settings);
    if (invalid != null) {
      return FiscalReportResult.failure(
        'Фискализация не настроена',
        code: FiscalErrorCode.notConfigured,
      );
    }
    final auth = await _ensureToken();
    if (!auth.success) {
      return FiscalReportResult.failure(
        auth.error ?? 'Ошибка авторизации',
        code: auth.errorCode,
      );
    }
    final body = {'Token': _token ?? '', 'cashboxUniqueNumber': _cashbox};
    final resp = zReport ? await _api.zReport(body) : await _api.xReport(body);

    if (!resp.success) {
      if (resp.errorCode == 2 || resp.errorCode == 3) {
        final re = await authorize(settings);
        if (re.success) {
          final retry = zReport
              ? await _api.zReport({
                  'Token': _token ?? '',
                  'cashboxUniqueNumber': _cashbox,
                })
              : await _api.xReport({
                  'Token': _token ?? '',
                  'cashboxUniqueNumber': _cashbox,
                });
          if (retry.success) return _reportResult(retry);
          return FiscalReportResult.failure(
            retry.errorMessage ?? 'Ошибка отчёта',
            code: _mapError(retry.errorCode),
          );
        }
      }
      return FiscalReportResult.failure(
        resp.errorMessage ?? 'Ошибка отчёта',
        code: _mapError(resp.errorCode),
      );
    }
    return _reportResult(resp);
  }

  FiscalReportResult _reportResult(WebKassaResponse resp) {
    final d = resp.data ?? const {};
    return FiscalReportResult(
      result: FiscalResult.ok(fiscalSign: (d['ReportNumber'] ?? '').toString()),
      shiftNumber: (d['ShiftNumber'] as num?)?.toInt(),
      documentCount: (d['DocumentCount'] as num?)?.toInt() ?? 0,
      cashIn: _decOrNull(d['PutMoneySum']),
      cashOut: _decOrNull(d['TakeMoneySum']),
      cashInDrawer: _decOrNull(d['SumInCashbox']),
      controlSum: d['ControlSum']?.toString(),
      startedAt: _parseDate(d['StartOn']),
      closedAt: _parseDate(d['CloseOn']),
    );
  }

  @override
  Future<FiscalResult> correctionReceipt(FiscalCorrectionRequest req) async =>
      FiscalResult.unsupported('correctionReceipt');

  @override
  Future<FiscalStatus> getStatus() async {
    final invalid = validateConfig(settings);
    if (invalid != null) return FiscalStatus.notConfigured();
    final auth = await _ensureToken();
    if (!auth.success) {
      return FiscalStatus(
        configured: true,
        active: false,
        online: false,
        lastError: auth.error,
        lastErrorAt: DateTime.now(),
      );
    }
    final resp = await _api.cashboxes({'Token': _token ?? ''});
    return FiscalStatus(
      configured: true,
      active: true,
      online: resp.success,
      lastError: resp.success ? null : resp.errorMessage,
      lastErrorAt: resp.success ? null : DateTime.now(),
    );
  }

  Future<FiscalResult> _withReauthRetry(
    Future<FiscalResult> Function() op,
  ) async {
    final auth = await _ensureToken();
    if (!auth.success) {
      return FiscalResult.failure(
        auth.error ?? 'Ошибка авторизации',
        code: auth.errorCode,
      );
    }
    final first = await op();
    if (first.success) return first;
    if (first.errorCode == FiscalErrorCode.tokenExpired) {
      final re = await authorize(settings);
      if (re.success) return op();
      return FiscalResult.failure(
        re.error ?? 'Ошибка авторизации',
        code: re.errorCode,
      );
    }
    return first;
  }

  FiscalResult _failure(WebKassaResponse resp) => FiscalResult.failure(
    resp.errorMessage ?? 'Ошибка WebKassa',
    code: _mapError(resp.errorCode),
    rawErrorCode: resp.errorCode,
  );

  FiscalErrorCode _mapError(int? code) {
    switch (code) {
      case null:
        return FiscalErrorCode.unknown;
      case 1:
        return FiscalErrorCode.badCredentials;
      case 2:
      case 3:
        return FiscalErrorCode.tokenExpired;
      case 6:
        return FiscalErrorCode.cashboxNotFound;
      case 7:
        return FiscalErrorCode.cashboxBlocked;
      case 8:
        return FiscalErrorCode.notEnoughMoney;
      case 9:
        return FiscalErrorCode.validation;
      case 11:
      case 12:
      case 13:
      case 15:
        return FiscalErrorCode.shiftError;
      case 14:
        return FiscalErrorCode.duplicate;
      case 18:
        return FiscalErrorCode.offlineLimitExceeded;
      case 1013:
        return FiscalErrorCode.offlineNotSupported;
      case -1:
        return FiscalErrorCode.network;
      case -2:
      case -3:
        return FiscalErrorCode.network;
      default:
        return FiscalErrorCode.unknown;
    }
  }

  num _money(Decimal value) {
    final rounded = value.round(scale: 2);
    return rounded.isInteger ? rounded.toBigInt().toInt() : rounded.toDouble();
  }

  num _qty(Decimal value) {
    final rounded = value.round(scale: 3);
    return rounded.isInteger ? rounded.toBigInt().toInt() : rounded.toDouble();
  }

  Decimal? _decOrNull(Object? v) =>
      v == null ? null : Decimal.tryParse(v.toString());

  DateTime? _parseDate(Object? raw) {
    if (raw == null) return null;
    final s = raw.toString();
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    final m = RegExp(
      r'^(\d{2})\.(\d{2})\.(\d{4})[ T](\d{2}):(\d{2}):(\d{2})',
    ).firstMatch(s);
    if (m != null) {
      return DateTime(
        int.parse(m.group(3)!),
        int.parse(m.group(2)!),
        int.parse(m.group(1)!),
        int.parse(m.group(4)!),
        int.parse(m.group(5)!),
        int.parse(m.group(6)!),
      );
    }
    return null;
  }

  void dispose() {
    _client?.dispose();
    _client = null;
  }
}
