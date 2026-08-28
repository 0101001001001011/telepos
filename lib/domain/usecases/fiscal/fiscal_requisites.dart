import 'package:decimal/decimal.dart';

class FiscalRequisites {
  const FiscalRequisites({
    required this.fiscalNo,
    required this.fiscalSign,
    required this.binOrg,
    required this.rnk,
    required this.znk,
    this.kgdKkm,
    this.ndsSerial,
    this.ndsNumber,
    this.taxpayerName,
    this.address,
    this.ofdName,
    this.ticketUrl,
    this.offlineMode = false,
    this.receiptDateTime,
    this.vatAmount,
    this.vatRate = 12,
  });

  final String fiscalNo;

  final String? fiscalSign;

  final String binOrg;

  final String rnk;

  final String znk;

  final String? kgdKkm;

  final String? ndsSerial;

  final String? ndsNumber;

  final String? taxpayerName;

  final String? address;

  final String? ofdName;

  final String? ticketUrl;

  final bool offlineMode;

  final DateTime? receiptDateTime;

  final Decimal? vatAmount;

  final int vatRate;

  bool get isVatPayer => ndsSerial != null && ndsNumber != null;

  String? get formattedNdsInfo {
    if (!isVatPayer) return null;
    return 'НДС: $ndsSerial $ndsNumber';
  }

  String get formattedKkmInfo => 'ЗНК: $znk РНК: $rnk';

  String get formattedBin => 'БИН: $binOrg';

  factory FiscalRequisites.fromWebKassa({
    required String fiscalNo,
    String? fiscalSign,
    required String binOrg,
    required String rnk,
    required String znk,
    String? kgdKkm,
    String? ndsSerial,
    String? ndsNumber,
    String? taxpayerName,
    String? address,
    String? ofdName,
    String? ticketUrl,
    bool offlineMode = false,
    DateTime? receiptDateTime,
    Decimal? vatAmount,
  }) {
    return FiscalRequisites(
      fiscalNo: fiscalNo,
      fiscalSign: fiscalSign,
      binOrg: binOrg,
      rnk: rnk,
      znk: znk,
      kgdKkm: kgdKkm,
      ndsSerial: ndsSerial,
      ndsNumber: ndsNumber,
      taxpayerName: taxpayerName,
      address: address,
      ofdName: ofdName,
      ticketUrl: ticketUrl,
      offlineMode: offlineMode,
      receiptDateTime: receiptDateTime,
      vatAmount: vatAmount,
    );
  }

  @override
  String toString() {
    return 'FiscalRequisites('
        'fiscalNo: $fiscalNo, '
        'binOrg: $binOrg, '
        'rnk: $rnk, '
        'znk: $znk, '
        'isVatPayer: $isVatPayer)';
  }
}

class FiscalRequisitesBuilder {
  String? _fiscalNo;
  String? _fiscalSign;
  String? _binOrg;
  String? _rnk;
  String? _znk;
  String? _kgdKkm;
  String? _ndsSerial;
  String? _ndsNumber;
  String? _taxpayerName;
  String? _address;
  String? _ofdName;
  String? _ticketUrl;
  bool _offlineMode = false;
  DateTime? _receiptDateTime;
  Decimal? _vatAmount;
  int _vatRate = 12;

  FiscalRequisitesBuilder fiscalNo(String value) {
    _fiscalNo = value;
    return this;
  }

  FiscalRequisitesBuilder fiscalSign(String? value) {
    _fiscalSign = value;
    return this;
  }

  FiscalRequisitesBuilder binOrg(String value) {
    _binOrg = value;
    return this;
  }

  FiscalRequisitesBuilder rnk(String value) {
    _rnk = value;
    return this;
  }

  FiscalRequisitesBuilder znk(String value) {
    _znk = value;
    return this;
  }

  FiscalRequisitesBuilder kgdKkm(String? value) {
    _kgdKkm = value;
    return this;
  }

  FiscalRequisitesBuilder nds({String? serial, String? number}) {
    _ndsSerial = serial;
    _ndsNumber = number;
    return this;
  }

  FiscalRequisitesBuilder taxpayerName(String? value) {
    _taxpayerName = value;
    return this;
  }

  FiscalRequisitesBuilder address(String? value) {
    _address = value;
    return this;
  }

  FiscalRequisitesBuilder ofdName(String? value) {
    _ofdName = value;
    return this;
  }

  FiscalRequisitesBuilder ticketUrl(String? value) {
    _ticketUrl = value;
    return this;
  }

  FiscalRequisitesBuilder offlineMode(bool value) {
    _offlineMode = value;
    return this;
  }

  FiscalRequisitesBuilder receiptDateTime(DateTime? value) {
    _receiptDateTime = value;
    return this;
  }

  FiscalRequisitesBuilder vatAmount(Decimal? value) {
    _vatAmount = value;
    return this;
  }

  FiscalRequisitesBuilder vatRate(int value) {
    _vatRate = value;
    return this;
  }

  FiscalRequisites build() {
    if (_fiscalNo == null || _fiscalNo!.isEmpty) {
      throw ArgumentError('fiscalNo is required');
    }
    if (_binOrg == null || _binOrg!.isEmpty) {
      throw ArgumentError('binOrg is required');
    }
    if (_rnk == null || _rnk!.isEmpty) {
      throw ArgumentError('rnk is required');
    }
    if (_znk == null || _znk!.isEmpty) {
      throw ArgumentError('znk is required');
    }

    return FiscalRequisites(
      fiscalNo: _fiscalNo!,
      fiscalSign: _fiscalSign,
      binOrg: _binOrg!,
      rnk: _rnk!,
      znk: _znk!,
      kgdKkm: _kgdKkm,
      ndsSerial: _ndsSerial,
      ndsNumber: _ndsNumber,
      taxpayerName: _taxpayerName,
      address: _address,
      ofdName: _ofdName,
      ticketUrl: _ticketUrl,
      offlineMode: _offlineMode,
      receiptDateTime: _receiptDateTime,
      vatAmount: _vatAmount,
      vatRate: _vatRate,
    );
  }
}
