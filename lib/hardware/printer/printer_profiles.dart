class PrinterProfiles {
  PrinterProfiles._();

  static const List<PrinterProfile> profiles = [
    posiflexPP7600,
    posiflexPP8000,

    epsonTM20,
    epsonTM88,

    starTSP100,
    starTSP650,

    generic58mm,
    generic80mm,
  ];

  static const PrinterProfile posiflexPP7600 = PrinterProfile(
    model: 'Posiflex PP7600',
    manufacturer: 'Posiflex',
    paperWidthMm: 80,
    dotsPerLine: 576,
    charsPerLine: 48,
    printWidthPx: 207,
    supportsCutter: true,
    supportsDrawer: true,
    defaultDpi: 203,
    notes: 'Ширина печати 207px при 203 DPI',
  );

  static const PrinterProfile posiflexPP8000 = PrinterProfile(
    model: 'Posiflex PP8000',
    manufacturer: 'Posiflex',
    paperWidthMm: 80,
    dotsPerLine: 576,
    charsPerLine: 48,
    printWidthPx: 576,
    supportsCutter: true,
    supportsDrawer: true,
    defaultDpi: 203,
  );

  static const PrinterProfile epsonTM20 = PrinterProfile(
    model: 'Epson TM-T20',
    manufacturer: 'Epson',
    paperWidthMm: 80,
    dotsPerLine: 512,
    charsPerLine: 42,
    printWidthPx: 512,
    supportsCutter: true,
    supportsDrawer: true,
    defaultDpi: 180,
  );

  static const PrinterProfile epsonTM88 = PrinterProfile(
    model: 'Epson TM-T88',
    manufacturer: 'Epson',
    paperWidthMm: 80,
    dotsPerLine: 576,
    charsPerLine: 48,
    printWidthPx: 576,
    supportsCutter: true,
    supportsDrawer: true,
    defaultDpi: 203,
  );

  static const PrinterProfile starTSP100 = PrinterProfile(
    model: 'Star TSP100',
    manufacturer: 'Star Micronics',
    paperWidthMm: 80,
    dotsPerLine: 576,
    charsPerLine: 48,
    printWidthPx: 576,
    supportsCutter: true,
    supportsDrawer: true,
    defaultDpi: 203,
  );

  static const PrinterProfile starTSP650 = PrinterProfile(
    model: 'Star TSP650',
    manufacturer: 'Star Micronics',
    paperWidthMm: 80,
    dotsPerLine: 576,
    charsPerLine: 48,
    printWidthPx: 576,
    supportsCutter: true,
    supportsDrawer: true,
    defaultDpi: 203,
  );

  static const PrinterProfile generic58mm = PrinterProfile(
    model: 'Generic 58mm',
    manufacturer: 'Generic',
    paperWidthMm: 58,
    dotsPerLine: 384,
    charsPerLine: 32,
    printWidthPx: 384,
    supportsCutter: false,
    supportsDrawer: false,
    defaultDpi: 203,
    notes: 'Стандартный мобильный/портативный принтер',
  );

  static const PrinterProfile generic80mm = PrinterProfile(
    model: 'Generic 80mm',
    manufacturer: 'Generic',
    paperWidthMm: 80,
    dotsPerLine: 576,
    charsPerLine: 48,
    printWidthPx: 576,
    supportsCutter: true,
    supportsDrawer: true,
    defaultDpi: 203,
    notes: 'Стандартный настольный принтер',
  );

  static PrinterProfile? findByModel(String modelName) {
    final lowerName = modelName.toLowerCase();
    for (final profile in profiles) {
      if (profile.model.toLowerCase().contains(lowerName) ||
          lowerName.contains(profile.model.toLowerCase())) {
        return profile;
      }
    }
    return null;
  }

  static PrinterProfile getByPaperWidth(int widthMm) {
    if (widthMm <= 58) return generic58mm;
    return generic80mm;
  }

  static PrinterProfile? findByVidPid(int vendorId, int productId) {
    if (vendorId == 0x0D28) {
      return posiflexPP7600;
    } else if (vendorId == 0x04B8) {
      return epsonTM88;
    } else if (vendorId == 0x0519) {
      return starTSP100;
    }

    return null;
  }
}

class PrinterProfile {
  const PrinterProfile({
    required this.model,
    required this.manufacturer,
    required this.paperWidthMm,
    required this.dotsPerLine,
    required this.charsPerLine,
    required this.printWidthPx,
    required this.supportsCutter,
    required this.supportsDrawer,
    required this.defaultDpi,
    this.notes,
  });

  final String model;

  final String manufacturer;

  final int paperWidthMm;

  final int dotsPerLine;

  final int charsPerLine;

  final int printWidthPx;

  final bool supportsCutter;

  final bool supportsDrawer;

  final int defaultDpi;

  final String? notes;

  String get fullName => '$manufacturer $model';

  int get optimalQrSize {
    return (printWidthPx * 0.5).round();
  }

  int get maxLogoWidth => printWidthPx;

  @override
  String toString() => 'PrinterProfile($fullName, ${paperWidthMm}mm)';
}

class PrintSettings {
  const PrintSettings({
    required this.profile,
    this.autoCut = true,
    this.openDrawer = false,
    this.beepOnPrint = false,
    this.feedLinesBefore = 0,
    this.feedLinesAfter = 3,
    this.printLogo = false,
    this.printQrCode = true,
  });

  final PrinterProfile profile;

  final bool autoCut;

  final bool openDrawer;

  final bool beepOnPrint;

  final int feedLinesBefore;

  final int feedLinesAfter;

  final bool printLogo;

  final bool printQrCode;

  int get charWidth => profile.charsPerLine;

  int get pixelWidth => profile.printWidthPx;

  PrintSettings copyWith({
    PrinterProfile? profile,
    bool? autoCut,
    bool? openDrawer,
    bool? beepOnPrint,
    int? feedLinesBefore,
    int? feedLinesAfter,
    bool? printLogo,
    bool? printQrCode,
  }) {
    return PrintSettings(
      profile: profile ?? this.profile,
      autoCut: autoCut ?? this.autoCut,
      openDrawer: openDrawer ?? this.openDrawer,
      beepOnPrint: beepOnPrint ?? this.beepOnPrint,
      feedLinesBefore: feedLinesBefore ?? this.feedLinesBefore,
      feedLinesAfter: feedLinesAfter ?? this.feedLinesAfter,
      printLogo: printLogo ?? this.printLogo,
      printQrCode: printQrCode ?? this.printQrCode,
    );
  }
}
