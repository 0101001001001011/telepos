import 'dart:convert';

enum ReceiptPaperWidth {
  mm58(58, 32),

  mm80(80, 48);

  const ReceiptPaperWidth(this.mm, this.charWidth);

  final int mm;

  final int charWidth;

  static ReceiptPaperWidth fromMm(int? mm) =>
      mm == 80 ? ReceiptPaperWidth.mm80 : ReceiptPaperWidth.mm58;
}

class ReceiptOptions {
  const ReceiptOptions({
    this.paperWidth = ReceiptPaperWidth.mm58,
    this.showLogo = false,
    this.headerText,
    this.footerText = 'Спасибо за покупку!',
    this.extraFooterLines = const [],
    this.showBin = true,
    this.showAddress = true,
    this.showCashier = true,
    this.showQr = true,
    this.showVat = true,
    this.showItemNumbers = false,
  });

  final ReceiptPaperWidth paperWidth;

  final bool showLogo;

  final String? headerText;

  final String footerText;

  final List<String> extraFooterLines;

  final bool showBin;

  final bool showAddress;

  final bool showCashier;

  final bool showQr;

  final bool showVat;

  final bool showItemNumbers;

  ReceiptOptions copyWith({
    ReceiptPaperWidth? paperWidth,
    bool? showLogo,
    String? headerText,
    String? footerText,
    List<String>? extraFooterLines,
    bool? showBin,
    bool? showAddress,
    bool? showCashier,
    bool? showQr,
    bool? showVat,
    bool? showItemNumbers,
  }) {
    return ReceiptOptions(
      paperWidth: paperWidth ?? this.paperWidth,
      showLogo: showLogo ?? this.showLogo,
      headerText: headerText ?? this.headerText,
      footerText: footerText ?? this.footerText,
      extraFooterLines: extraFooterLines ?? this.extraFooterLines,
      showBin: showBin ?? this.showBin,
      showAddress: showAddress ?? this.showAddress,
      showCashier: showCashier ?? this.showCashier,
      showQr: showQr ?? this.showQr,
      showVat: showVat ?? this.showVat,
      showItemNumbers: showItemNumbers ?? this.showItemNumbers,
    );
  }

  Map<String, dynamic> toJson() => {
    'paperWidth': paperWidth.mm,
    'showLogo': showLogo,
    if (headerText != null) 'headerText': headerText,
    'footerText': footerText,
    'extraFooterLines': extraFooterLines,
    'showBin': showBin,
    'showAddress': showAddress,
    'showCashier': showCashier,
    'showQr': showQr,
    'showVat': showVat,
    'showItemNumbers': showItemNumbers,
  };

  factory ReceiptOptions.fromJson(Map<String, dynamic> json) {
    return ReceiptOptions(
      paperWidth: ReceiptPaperWidth.fromMm(json['paperWidth'] as int?),
      showLogo: json['showLogo'] as bool? ?? false,
      headerText: json['headerText'] as String?,
      footerText: json['footerText'] as String? ?? 'Спасибо за покупку!',
      extraFooterLines:
          (json['extraFooterLines'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      showBin: json['showBin'] as bool? ?? true,
      showAddress: json['showAddress'] as bool? ?? true,
      showCashier: json['showCashier'] as bool? ?? true,
      showQr: json['showQr'] as bool? ?? true,
      showVat: json['showVat'] as bool? ?? true,
      showItemNumbers: json['showItemNumbers'] as bool? ?? false,
    );
  }

  static ReceiptOptions decode(String optionsJson) {
    try {
      final raw = jsonDecode(optionsJson);
      if (raw is! Map) return const ReceiptOptions();
      return ReceiptOptions.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return const ReceiptOptions();
    }
  }

  String encode() => jsonEncode(toJson());

  static const ReceiptOptions kzDefault = ReceiptOptions();
}
