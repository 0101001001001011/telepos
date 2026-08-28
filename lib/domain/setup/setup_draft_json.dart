import 'setup_draft.dart';

/// The wire format of a [SetupDraft].
///
/// It lives beside the contract rather than inside either binding, because both
/// ends have to agree on it: the browser writes it, the backend reads it, and a
/// disagreement means a till configured with someone else's answers.
///
/// Enums travel by name, never by index — an index changes meaning the moment
/// a case is inserted, and this payload decides whether a till is fiscalised.
/// No field here carries money; if one ever does, it goes as a string, because
/// a JSON number is a double. See docs/ARCHITECTURE.md.
extension SetupDraftJson on SetupDraft {
  Map<String, Object?> toJson() => {
    'countryIndex': countryIndex,
    'operatingModeIndex': operatingModeIndex,
    'organization': {
      'companyName': organization.companyName,
      'legalName': organization.legalName,
      'taxId': organization.taxId,
      'legalAddress': organization.legalAddress,
      'actualAddress': organization.actualAddress,
      'phone': organization.phone,
      'email': organization.email,
      'contactName': organization.contactName,
      'description': organization.description,
      'isVatPayer': organization.isVatPayer,
    },
    'posConfig': {
      'cashBoxName': posConfig.cashBoxName,
      'posId': posConfig.posId,
      'printerEnabled': posConfig.printerEnabled,
      'paperWidth': posConfig.paperWidth,
      'printerHeader': posConfig.printerHeader,
      'printerFooter': posConfig.printerFooter,
    },
    'fiscalConfig': {
      'fiscalType': fiscalConfig.fiscalType.name,
      'enabled': fiscalConfig.enabled,
      'wkAccountId': fiscalConfig.wkAccountId,
      'wkAccountToken': fiscalConfig.wkAccountToken,
      'wkPosId': fiscalConfig.wkPosId,
      'wkPosToken': fiscalConfig.wkPosToken,
      'wkPosFactoryNo': fiscalConfig.wkPosFactoryNo,
      'ofdInn': fiscalConfig.ofdInn,
      'ofdKktRegNo': fiscalConfig.ofdKktRegNo,
      'ofdFnNo': fiscalConfig.ofdFnNo,
      'ofdUrl': fiscalConfig.ofdUrl,
    },
    'businessRules': {
      'discountsRoundType': businessRules.discountsRoundType,
      'weightProductRoundType': businessRules.weightProductRoundType,
      'cashbackEnabled': businessRules.cashbackEnabled,
      'cashbackRate': businessRules.cashbackRate,
      'allowBigAmount': businessRules.allowBigAmount,
      'cashWithdrawalLimit': businessRules.cashWithdrawalLimit,
      'allowDiscounts': businessRules.allowDiscounts,
      'allowDebtSales': businessRules.allowDebtSales,
      'allowPriceEdit': businessRules.allowPriceEdit,
      'allowProductEdit': businessRules.allowProductEdit,
      'allowCashInOut': businessRules.allowCashInOut,
      'allowUniversalProduct': businessRules.allowUniversalProduct,
      'blockPriceDecrease': businessRules.blockPriceDecrease,
    },
    'equipment': {
      'printerEnabled': equipment.printerEnabled,
      'printerConnectionType': equipment.printerConnectionType.name,
      'printerAddress': equipment.printerAddress,
      'printerName': equipment.printerName,
      'scannerEnabled': equipment.scannerEnabled,
      'scannerConnectionType': equipment.scannerConnectionType.name,
      'scannerAddress': equipment.scannerAddress,
      'scaleEnabled': equipment.scaleEnabled,
      'scaleType': equipment.scaleType.name,
      'scalePort': equipment.scalePort,
      'scaleBaudRate': equipment.scaleBaudRate,
      'cashDrawerEnabled': equipment.cashDrawerEnabled,
      'cashDrawerConnectedToPrinter': equipment.cashDrawerConnectedToPrinter,
      'customerDisplayEnabled': equipment.customerDisplayEnabled,
      'customerDisplayPort': equipment.customerDisplayPort,
    },
    'paymentTerminal': {
      'kaspiEnabled': paymentTerminal.kaspiEnabled,
      'kaspiTerminalIp': paymentTerminal.kaspiTerminalIp,
      'kaspiTerminalPort': paymentTerminal.kaspiTerminalPort,
    },
    'employees': employees.map(_employeeToJson).toList(),
    'firstUser': _employeeToJson(firstUser),
    'secondUser': secondUser == null ? null : _employeeToJson(secondUser!),
  };

  static Map<String, Object?> _employeeToJson(EmployeeInfo e) => {
    'name': e.name,
    'position': e.position,
    'pin': e.pin,
    'phone': e.phone,
  };
}

/// Reads back what [SetupDraftJson.toJson] wrote.
///
/// Missing keys fall back to the same defaults the wizard starts from, so an
/// older frontend talking to a newer backend configures a till conservatively
/// instead of failing to configure one at all.
SetupDraft setupDraftFromJson(Map<String, dynamic> json) {
  Map<String, dynamic> section(String key) {
    final raw = json[key];
    return raw is Map<String, dynamic> ? raw : const {};
  }

  final org = section('organization');
  final pos = section('posConfig');
  final fiscal = section('fiscalConfig');
  final rules = section('businessRules');
  final equip = section('equipment');
  final term = section('paymentTerminal');

  T byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
      values.firstWhere((v) => v.name == name, orElse: () => fallback);

  final employeesRaw = json['employees'];

  return SetupDraft(
    countryIndex: json['countryIndex'] as int? ?? 0,
    operatingModeIndex: json['operatingModeIndex'] as int? ?? 0,
    organization: OrganizationInfo(
      companyName: org['companyName'] as String?,
      legalName: org['legalName'] as String?,
      taxId: org['taxId'] as String?,
      legalAddress: org['legalAddress'] as String?,
      actualAddress: org['actualAddress'] as String?,
      phone: org['phone'] as String?,
      email: org['email'] as String?,
      contactName: org['contactName'] as String?,
      description: org['description'] as String?,
      isVatPayer: org['isVatPayer'] as bool? ?? true,
    ),
    posConfig: PosConfigInfo(
      cashBoxName: pos['cashBoxName'] as String?,
      posId: pos['posId'] as String?,
      printerEnabled: pos['printerEnabled'] as bool? ?? true,
      paperWidth: pos['paperWidth'] as int? ?? 48,
      printerHeader: pos['printerHeader'] as String?,
      printerFooter: pos['printerFooter'] as String?,
    ),
    fiscalConfig: FiscalConfigInfo(
      fiscalType: byName(
        FiscalType.values,
        fiscal['fiscalType'],
        FiscalType.none,
      ),
      enabled: fiscal['enabled'] as bool? ?? false,
      wkAccountId: fiscal['wkAccountId'] as String?,
      wkAccountToken: fiscal['wkAccountToken'] as String?,
      wkPosId: fiscal['wkPosId'] as String?,
      wkPosToken: fiscal['wkPosToken'] as String?,
      wkPosFactoryNo: fiscal['wkPosFactoryNo'] as String?,
      ofdInn: fiscal['ofdInn'] as String?,
      ofdKktRegNo: fiscal['ofdKktRegNo'] as String?,
      ofdFnNo: fiscal['ofdFnNo'] as String?,
      ofdUrl: fiscal['ofdUrl'] as String?,
    ),
    businessRules: BusinessRulesConfigInfo(
      discountsRoundType: rules['discountsRoundType'] as int? ?? 0,
      weightProductRoundType: rules['weightProductRoundType'] as int? ?? 0,
      cashbackEnabled: rules['cashbackEnabled'] as bool? ?? false,
      cashbackRate: rules['cashbackRate'] as int? ?? 0,
      allowBigAmount: rules['allowBigAmount'] as bool? ?? false,
      cashWithdrawalLimit: rules['cashWithdrawalLimit'] as String?,
      allowDiscounts: rules['allowDiscounts'] as bool? ?? true,
      allowDebtSales: rules['allowDebtSales'] as bool? ?? false,
      allowPriceEdit: rules['allowPriceEdit'] as bool? ?? false,
      allowProductEdit: rules['allowProductEdit'] as bool? ?? false,
      allowCashInOut: rules['allowCashInOut'] as bool? ?? true,
      allowUniversalProduct: rules['allowUniversalProduct'] as bool? ?? false,
      blockPriceDecrease: rules['blockPriceDecrease'] as bool? ?? false,
    ),
    equipment: EquipmentConfigInfo(
      printerEnabled: equip['printerEnabled'] as bool? ?? false,
      printerConnectionType: byName(
        PrinterConnectionType.values,
        equip['printerConnectionType'],
        PrinterConnectionType.none,
      ),
      printerAddress: equip['printerAddress'] as String?,
      printerName: equip['printerName'] as String?,
      scannerEnabled: equip['scannerEnabled'] as bool? ?? false,
      scannerConnectionType: byName(
        ScannerConnectionType.values,
        equip['scannerConnectionType'],
        ScannerConnectionType.camera,
      ),
      scannerAddress: equip['scannerAddress'] as String?,
      scaleEnabled: equip['scaleEnabled'] as bool? ?? false,
      scaleType: byName(ScaleType.values, equip['scaleType'], ScaleType.none),
      scalePort: equip['scalePort'] as String?,
      scaleBaudRate: equip['scaleBaudRate'] as int? ?? 9600,
      cashDrawerEnabled: equip['cashDrawerEnabled'] as bool? ?? false,
      cashDrawerConnectedToPrinter:
          equip['cashDrawerConnectedToPrinter'] as bool? ?? true,
      customerDisplayEnabled: equip['customerDisplayEnabled'] as bool? ?? false,
      customerDisplayPort: equip['customerDisplayPort'] as String?,
    ),
    paymentTerminal: PaymentTerminalConfigInfo(
      kaspiEnabled: term['kaspiEnabled'] as bool? ?? false,
      kaspiTerminalIp: term['kaspiTerminalIp'] as String?,
      kaspiTerminalPort: term['kaspiTerminalPort'] as int? ?? 9999,
    ),
    employees: employeesRaw is List
        ? employeesRaw
              .whereType<Map<String, dynamic>>()
              .map(_employeeFromJson)
              .toList()
        : const [],
    firstUser: _employeeFromJson(section('firstUser')),
    secondUser: json['secondUser'] is Map<String, dynamic>
        ? _employeeFromJson(json['secondUser'] as Map<String, dynamic>)
        : null,
  );
}

EmployeeInfo _employeeFromJson(Map<String, dynamic> json) => EmployeeInfo(
  name: json['name'] as String?,
  position: json['position'] as String? ?? 'cashier',
  pin: json['pin'] as String?,
  phone: json['phone'] as String?,
);
