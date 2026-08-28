
/// Everything the first-launch wizard collects, as plain data.
///
/// These used to live inside the wizard's controller, next to the code that
/// wrote them to drift. Putting them here lets the wizard hand a completed
/// draft across the contract without the screen knowing whether it lands in a
/// local database or goes over the wire to a backend.
///
/// KNOWN WRONG, unchanged by this move: [EquipmentConfigInfo] describes one
/// printer for the whole installation. Devices belong to a terminal, and one
/// site can run several tills each with its own. See docs/ARCHITECTURE.md,
/// "Terminals" — that shape has to change, and it is its own piece of work.
library;

import 'package:meta/meta.dart';


@immutable
class OrganizationInfo {
  const OrganizationInfo({
    this.companyName,
    this.legalName,
    this.taxId,
    this.legalAddress,
    this.actualAddress,
    this.phone,
    this.email,
    this.contactName,
    this.description,
    this.isVatPayer = true,
  });

  final String? companyName;

  final String? legalName;

  final String? taxId;

  final String? legalAddress;

  final String? actualAddress;

  final String? phone;

  final String? email;

  final String? contactName;

  final String? description;

  final bool isVatPayer;

  bool get isComplete =>
      companyName != null &&
      companyName!.isNotEmpty &&
      taxId != null &&
      taxId!.isNotEmpty;

  OrganizationInfo copyWith({
    String? companyName,
    String? legalName,
    String? taxId,
    String? legalAddress,
    String? actualAddress,
    String? phone,
    String? email,
    String? contactName,
    String? description,
    bool? isVatPayer,
  }) {
    return OrganizationInfo(
      companyName: companyName ?? this.companyName,
      legalName: legalName ?? this.legalName,
      taxId: taxId ?? this.taxId,
      legalAddress: legalAddress ?? this.legalAddress,
      actualAddress: actualAddress ?? this.actualAddress,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      contactName: contactName ?? this.contactName,
      description: description ?? this.description,
      isVatPayer: isVatPayer ?? this.isVatPayer,
    );
  }

  Map<String, dynamic> toJson() => {
    'companyName': companyName,
    'legalName': legalName,
    'taxId': taxId,
    'legalAddress': legalAddress,
    'actualAddress': actualAddress,
    'phone': phone,
    'email': email,
    'contactName': contactName,
    'description': description,
    'isVatPayer': isVatPayer,
  };
}

@immutable
class PosConfigInfo {
  const PosConfigInfo({
    this.cashBoxName,
    this.posId,
    this.printerEnabled = true,
    this.paperWidth = 48,
    this.printerHeader,
    this.printerFooter,
  });

  final String? cashBoxName;
  final String? posId;
  final bool printerEnabled;
  final int paperWidth;
  final String? printerHeader;
  final String? printerFooter;

  bool get isComplete => cashBoxName != null && cashBoxName!.isNotEmpty;

  PosConfigInfo copyWith({
    String? cashBoxName,
    String? posId,
    bool? printerEnabled,
    int? paperWidth,
    String? printerHeader,
    String? printerFooter,
  }) {
    return PosConfigInfo(
      cashBoxName: cashBoxName ?? this.cashBoxName,
      posId: posId ?? this.posId,
      printerEnabled: printerEnabled ?? this.printerEnabled,
      paperWidth: paperWidth ?? this.paperWidth,
      printerHeader: printerHeader ?? this.printerHeader,
      printerFooter: printerFooter ?? this.printerFooter,
    );
  }
}

@immutable
class EmployeeInfo {
  const EmployeeInfo({
    this.name,
    this.position = 'cashier',
    this.pin,
    this.phone,
  });

  final String? name;

  final String position;

  final String? pin;

  final String? phone;

  bool get isComplete =>
      name != null && name!.isNotEmpty && pin != null && pin!.length >= 4;

  int get roleIndex => switch (position) {
    'admin' => 0,
    'manager' => 1,
    'cashier' => 3,
    _ => 3,
  };

  EmployeeInfo copyWith({
    String? name,
    String? position,
    String? pin,
    String? phone,
  }) {
    return EmployeeInfo(
      name: name ?? this.name,
      position: position ?? this.position,
      pin: pin ?? this.pin,
      phone: phone ?? this.phone,
    );
  }
}

typedef FirstUserInfo = EmployeeInfo;

enum FiscalType { none, webkassa, ofd }

enum WorkMode { autonomous, network }

@immutable
class FiscalConfigInfo {
  const FiscalConfigInfo({
    this.fiscalType = FiscalType.none,
    this.enabled = false,
    this.wkAccountId,
    this.wkAccountToken,
    this.wkPosId,
    this.wkPosToken,
    this.wkPosFactoryNo,
    this.ofdInn,
    this.ofdKktRegNo,
    this.ofdFnNo,
    this.ofdUrl,
  });

  final FiscalType fiscalType;
  final bool enabled;

  final String? wkAccountId;
  final String? wkAccountToken;
  final String? wkPosId;
  final String? wkPosToken;
  final String? wkPosFactoryNo;

  final String? ofdInn;
  final String? ofdKktRegNo;
  final String? ofdFnNo;
  final String? ofdUrl;

  bool get isWebKassaComplete =>
      fiscalType == FiscalType.webkassa &&
      wkAccountId != null &&
      wkAccountId!.isNotEmpty &&
      wkAccountToken != null &&
      wkAccountToken!.isNotEmpty &&
      wkPosId != null &&
      wkPosId!.isNotEmpty &&
      wkPosToken != null &&
      wkPosToken!.isNotEmpty;

  bool get isOfdComplete =>
      fiscalType == FiscalType.ofd &&
      ofdInn != null &&
      ofdInn!.isNotEmpty &&
      ofdKktRegNo != null &&
      ofdKktRegNo!.isNotEmpty &&
      ofdFnNo != null &&
      ofdFnNo!.isNotEmpty;

  bool get isComplete =>
      !enabled ||
      fiscalType == FiscalType.none ||
      isWebKassaComplete ||
      isOfdComplete;

  FiscalConfigInfo copyWith({
    FiscalType? fiscalType,
    bool? enabled,
    String? wkAccountId,
    String? wkAccountToken,
    String? wkPosId,
    String? wkPosToken,
    String? wkPosFactoryNo,
    String? ofdInn,
    String? ofdKktRegNo,
    String? ofdFnNo,
    String? ofdUrl,
  }) {
    return FiscalConfigInfo(
      fiscalType: fiscalType ?? this.fiscalType,
      enabled: enabled ?? this.enabled,
      wkAccountId: wkAccountId ?? this.wkAccountId,
      wkAccountToken: wkAccountToken ?? this.wkAccountToken,
      wkPosId: wkPosId ?? this.wkPosId,
      wkPosToken: wkPosToken ?? this.wkPosToken,
      wkPosFactoryNo: wkPosFactoryNo ?? this.wkPosFactoryNo,
      ofdInn: ofdInn ?? this.ofdInn,
      ofdKktRegNo: ofdKktRegNo ?? this.ofdKktRegNo,
      ofdFnNo: ofdFnNo ?? this.ofdFnNo,
      ofdUrl: ofdUrl ?? this.ofdUrl,
    );
  }
}

enum PrinterConnectionType { none, usb, bluetooth, wifi, serial }

enum ScannerConnectionType { none, usb, bluetooth, camera }

enum ScaleType { none, serial, usb }

@immutable
class PaymentTerminalConfigInfo {
  const PaymentTerminalConfigInfo({
    this.kaspiEnabled = false,
    this.kaspiTerminalIp,
    this.kaspiTerminalPort = 9999,
  });

  final bool kaspiEnabled;
  final String? kaspiTerminalIp;
  final int kaspiTerminalPort;

  bool get isComplete => true;

  PaymentTerminalConfigInfo copyWith({
    bool? kaspiEnabled,
    String? kaspiTerminalIp,
    int? kaspiTerminalPort,
  }) {
    return PaymentTerminalConfigInfo(
      kaspiEnabled: kaspiEnabled ?? this.kaspiEnabled,
      kaspiTerminalIp: kaspiTerminalIp ?? this.kaspiTerminalIp,
      kaspiTerminalPort: kaspiTerminalPort ?? this.kaspiTerminalPort,
    );
  }
}

@immutable
class BusinessRulesConfigInfo {
  const BusinessRulesConfigInfo({
    this.discountsRoundType = 0,
    this.weightProductRoundType = 0,
    this.cashbackEnabled = false,
    this.cashbackRate = 0,
    this.allowBigAmount = false,
    this.cashWithdrawalLimit,
    this.allowDiscounts = true,
    this.allowDebtSales = false,
    this.allowPriceEdit = false,
    this.allowProductEdit = false,
    this.allowCashInOut = true,
    this.allowUniversalProduct = false,
    this.blockPriceDecrease = false,
  });

  final int discountsRoundType;
  final int weightProductRoundType;

  final bool cashbackEnabled;
  final int cashbackRate;

  final bool allowBigAmount;
  final String? cashWithdrawalLimit;

  final bool allowDiscounts;
  final bool allowDebtSales;
  final bool allowPriceEdit;
  final bool allowProductEdit;
  final bool allowCashInOut;
  final bool allowUniversalProduct;
  final bool blockPriceDecrease;

  bool get isComplete => true;

  BusinessRulesConfigInfo copyWith({
    int? discountsRoundType,
    int? weightProductRoundType,
    bool? cashbackEnabled,
    int? cashbackRate,
    bool? allowBigAmount,
    String? cashWithdrawalLimit,
    bool? allowDiscounts,
    bool? allowDebtSales,
    bool? allowPriceEdit,
    bool? allowProductEdit,
    bool? allowCashInOut,
    bool? allowUniversalProduct,
    bool? blockPriceDecrease,
  }) {
    return BusinessRulesConfigInfo(
      discountsRoundType: discountsRoundType ?? this.discountsRoundType,
      weightProductRoundType:
          weightProductRoundType ?? this.weightProductRoundType,
      cashbackEnabled: cashbackEnabled ?? this.cashbackEnabled,
      cashbackRate: cashbackRate ?? this.cashbackRate,
      allowBigAmount: allowBigAmount ?? this.allowBigAmount,
      cashWithdrawalLimit: cashWithdrawalLimit ?? this.cashWithdrawalLimit,
      allowDiscounts: allowDiscounts ?? this.allowDiscounts,
      allowDebtSales: allowDebtSales ?? this.allowDebtSales,
      allowPriceEdit: allowPriceEdit ?? this.allowPriceEdit,
      allowProductEdit: allowProductEdit ?? this.allowProductEdit,
      allowCashInOut: allowCashInOut ?? this.allowCashInOut,
      allowUniversalProduct:
          allowUniversalProduct ?? this.allowUniversalProduct,
      blockPriceDecrease: blockPriceDecrease ?? this.blockPriceDecrease,
    );
  }
}

@immutable
class EquipmentConfigInfo {
  const EquipmentConfigInfo({
    this.printerEnabled = false,
    this.printerConnectionType = PrinterConnectionType.none,
    this.printerAddress,
    this.printerName,
    this.scannerEnabled = false,
    this.scannerConnectionType = ScannerConnectionType.camera,
    this.scannerAddress,
    this.scaleEnabled = false,
    this.scaleType = ScaleType.none,
    this.scalePort,
    this.scaleBaudRate = 9600,
    this.cashDrawerEnabled = false,
    this.cashDrawerConnectedToPrinter = true,
    this.customerDisplayEnabled = false,
    this.customerDisplayPort,
  });

  final bool printerEnabled;
  final PrinterConnectionType printerConnectionType;
  final String? printerAddress;
  final String? printerName;

  final bool scannerEnabled;
  final ScannerConnectionType scannerConnectionType;
  final String? scannerAddress;

  final bool scaleEnabled;
  final ScaleType scaleType;
  final String? scalePort;
  final int scaleBaudRate;

  final bool cashDrawerEnabled;
  final bool cashDrawerConnectedToPrinter;

  final bool customerDisplayEnabled;
  final String? customerDisplayPort;

  bool get isComplete => true;

  EquipmentConfigInfo copyWith({
    bool? printerEnabled,
    PrinterConnectionType? printerConnectionType,
    String? printerAddress,
    String? printerName,
    bool? scannerEnabled,
    ScannerConnectionType? scannerConnectionType,
    String? scannerAddress,
    bool? scaleEnabled,
    ScaleType? scaleType,
    String? scalePort,
    int? scaleBaudRate,
    bool? cashDrawerEnabled,
    bool? cashDrawerConnectedToPrinter,
    bool? customerDisplayEnabled,
    String? customerDisplayPort,
  }) {
    return EquipmentConfigInfo(
      printerEnabled: printerEnabled ?? this.printerEnabled,
      printerConnectionType:
          printerConnectionType ?? this.printerConnectionType,
      printerAddress: printerAddress ?? this.printerAddress,
      printerName: printerName ?? this.printerName,
      scannerEnabled: scannerEnabled ?? this.scannerEnabled,
      scannerConnectionType:
          scannerConnectionType ?? this.scannerConnectionType,
      scannerAddress: scannerAddress ?? this.scannerAddress,
      scaleEnabled: scaleEnabled ?? this.scaleEnabled,
      scaleType: scaleType ?? this.scaleType,
      scalePort: scalePort ?? this.scalePort,
      scaleBaudRate: scaleBaudRate ?? this.scaleBaudRate,
      cashDrawerEnabled: cashDrawerEnabled ?? this.cashDrawerEnabled,
      cashDrawerConnectedToPrinter:
          cashDrawerConnectedToPrinter ?? this.cashDrawerConnectedToPrinter,
      customerDisplayEnabled:
          customerDisplayEnabled ?? this.customerDisplayEnabled,
      customerDisplayPort: customerDisplayPort ?? this.customerDisplayPort,
    );
  }
}

/// A completed pass through the first-launch wizard, ready to be committed.
///
/// The wizard fills this in step by step and hands the whole thing over once,
/// because the commit is one transaction: accounts, the till's configuration,
/// its users and its fiscal registration either all exist afterwards or none of
/// them do. A half-configured till cannot take money.
@immutable
class SetupDraft {
  const SetupDraft({
    required this.countryIndex,
    required this.operatingModeIndex,
    required this.organization,
    required this.posConfig,
    required this.fiscalConfig,
    required this.businessRules,
    required this.equipment,
    required this.paymentTerminal,
    required this.employees,
    required this.firstUser,
    this.secondUser,
  });

  /// `CountryCode.index`. Held as an int so this file needs no import of the
  /// enum, which drags the whole constants module behind it.
  final int countryIndex;

  /// `OperatingMode.index`.
  final int operatingModeIndex;

  final OrganizationInfo organization;
  final PosConfigInfo posConfig;
  final FiscalConfigInfo fiscalConfig;
  final BusinessRulesConfigInfo businessRules;
  final EquipmentConfigInfo equipment;
  final PaymentTerminalConfigInfo paymentTerminal;

  /// The staff list, when the wizard collected one. Takes precedence over
  /// [firstUser] / [secondUser], which are the two-user short path.
  final List<EmployeeInfo> employees;

  final EmployeeInfo firstUser;
  final EmployeeInfo? secondUser;
}
