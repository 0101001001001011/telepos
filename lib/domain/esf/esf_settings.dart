import 'package:decimal/decimal.dart';

enum EsfOperatorType {
  none(value: 0, label: 'Без ЭСФ', id: 'none'),

  kgdEsf(value: 1, label: 'ИС ЭСФ (КГД)', id: 'kgd_esf');

  const EsfOperatorType({
    required this.value,
    required this.label,
    required this.id,
  });

  final int value;
  final String label;
  final String id;

  static EsfOperatorType fromValue(int value) => EsfOperatorType.values
      .firstWhere((t) => t.value == value, orElse: () => EsfOperatorType.none);

  static EsfOperatorType fromId(String? id) => EsfOperatorType.values
      .firstWhere((t) => t.id == id, orElse: () => EsfOperatorType.none);
}

class EsfDefaults {
  EsfDefaults._();

  static final Decimal vatRatePercent = Decimal.fromInt(12);

  static const int civilDealMrpThreshold = 1000;
}

class EsfSettings {
  EsfSettings({
    this.operatorType = EsfOperatorType.none,
    this.enabled = false,
    this.supplierBin,
    this.supplierName,
    this.supplierVatSeries,
    this.supplierVatNumber,
    this.supplierAddress,
    this.isVatPayer = false,
    Decimal? vatRatePercent,
    this.b2bOnly = true,
  }) : vatRatePercent = vatRatePercent ?? EsfDefaults.vatRatePercent;

  final EsfOperatorType operatorType;

  final bool enabled;

  final String? supplierBin;
  final String? supplierName;

  final String? supplierVatSeries;
  final String? supplierVatNumber;
  final String? supplierAddress;

  final bool isVatPayer;

  final Decimal vatRatePercent;

  final bool b2bOnly;

  bool get isEnabled => enabled && operatorType != EsfOperatorType.none;

  bool get hasSupplierRequisites =>
      supplierBin != null && supplierBin!.isNotEmpty;

  EsfSettings copyWith({
    EsfOperatorType? operatorType,
    bool? enabled,
    String? supplierBin,
    String? supplierName,
    String? supplierVatSeries,
    String? supplierVatNumber,
    String? supplierAddress,
    bool? isVatPayer,
    Decimal? vatRatePercent,
    bool? b2bOnly,
  }) => EsfSettings(
    operatorType: operatorType ?? this.operatorType,
    enabled: enabled ?? this.enabled,
    supplierBin: supplierBin ?? this.supplierBin,
    supplierName: supplierName ?? this.supplierName,
    supplierVatSeries: supplierVatSeries ?? this.supplierVatSeries,
    supplierVatNumber: supplierVatNumber ?? this.supplierVatNumber,
    supplierAddress: supplierAddress ?? this.supplierAddress,
    isVatPayer: isVatPayer ?? this.isVatPayer,
    vatRatePercent: vatRatePercent ?? this.vatRatePercent,
    b2bOnly: b2bOnly ?? this.b2bOnly,
  );

  Map<String, dynamic> toJson() => {
    'operatorType': operatorType.value,
    'enabled': enabled,
    if (supplierBin != null) 'supplierBin': supplierBin,
    if (supplierName != null) 'supplierName': supplierName,
    if (supplierVatSeries != null) 'supplierVatSeries': supplierVatSeries,
    if (supplierVatNumber != null) 'supplierVatNumber': supplierVatNumber,
    if (supplierAddress != null) 'supplierAddress': supplierAddress,
    'isVatPayer': isVatPayer,
    'vatRatePercent': vatRatePercent.toString(),
    'b2bOnly': b2bOnly,
  };

  factory EsfSettings.fromJson(Map<String, dynamic> json) => EsfSettings(
    operatorType: EsfOperatorType.fromValue(json['operatorType'] as int? ?? 0),
    enabled: json['enabled'] as bool? ?? false,
    supplierBin: json['supplierBin'] as String?,
    supplierName: json['supplierName'] as String?,
    supplierVatSeries: json['supplierVatSeries'] as String?,
    supplierVatNumber: json['supplierVatNumber'] as String?,
    supplierAddress: json['supplierAddress'] as String?,
    isVatPayer: json['isVatPayer'] as bool? ?? false,
    vatRatePercent: json['vatRatePercent'] != null
        ? Decimal.parse(json['vatRatePercent'].toString())
        : null,
    b2bOnly: json['b2bOnly'] as bool? ?? true,
  );

  factory EsfSettings.disabled() =>
      EsfSettings(operatorType: EsfOperatorType.none, enabled: false);
}
