enum EsutdErrorCode { notConfigured, auth, network, server, unknown }

class EsutdResult<T> {
  const EsutdResult._({
    required this.success,
    this.data,
    this.errorCode,
    this.errorMessage,
  });

  factory EsutdResult.ok(T data) => EsutdResult._(success: true, data: data);

  factory EsutdResult.failure(EsutdErrorCode code, String message) =>
      EsutdResult._(success: false, errorCode: code, errorMessage: message);

  final bool success;
  final T? data;
  final EsutdErrorCode? errorCode;
  final String? errorMessage;
}

typedef EsutdLoginResult = EsutdResult<void>;

class EsutdOrganization {
  const EsutdOrganization({
    required this.id,
    required this.name,
    required this.bin,
    this.executive,
    this.address,
    this.phone,
    this.carrierTypes = const [],
    this.transportTypes = const [],
  });

  final String id;
  final String name;
  final String bin;
  final String? executive;
  final String? address;
  final String? phone;
  final List<String> carrierTypes;
  final List<String> transportTypes;

  factory EsutdOrganization.fromJson(Map<String, dynamic> json) {
    List<String> strList(dynamic v) =>
        v is List ? v.map((e) => e.toString()).toList() : const [];
    return EsutdOrganization(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      bin: (json['bin'] ?? '').toString(),
      executive: json['executive']?.toString(),
      address: json['address']?.toString(),
      phone: json['phone']?.toString(),
      carrierTypes: strList(json['carrierType']),
      transportTypes: strList(json['carrierTransportType']),
    );
  }
}

class EsutdWaybill {
  const EsutdWaybill({
    required this.id,
    required this.documentNumber,
    required this.status,
    this.createdDateTime,
    this.createdOrganizationName,
    this.carrierOrganizationName,
    this.carrierBin,
    this.regionName,
    this.cargoCount = 0,
  });

  final String id;
  final String documentNumber;
  final String status;
  final String? createdDateTime;
  final String? createdOrganizationName;
  final String? carrierOrganizationName;
  final String? carrierBin;
  final String? regionName;
  final int cargoCount;

  factory EsutdWaybill.fromJson(Map<String, dynamic> json) {
    final cargo = json['cargoDataList'];
    return EsutdWaybill(
      id: (json['id'] ?? '').toString(),
      documentNumber: (json['documentNumber'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      createdDateTime: json['createdDateTime']?.toString(),
      createdOrganizationName: json['createdOrganizationName']?.toString(),
      carrierOrganizationName: json['carrierOrganizationName']?.toString(),
      carrierBin: json['carrierBin']?.toString(),
      regionName: json['regionName']?.toString(),
      cargoCount: cargo is List ? cargo.length : 0,
    );
  }
}

enum EsutdWaybillDirection { inbound, outbound }
