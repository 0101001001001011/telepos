import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';
import 'package:telepos/hardware/paper_charset.dart';

// LabelTransport.fromConnectionTypeIndex removed (schema v27, second
// final-review round, finding raised alongside C4): its only caller,
// LabelPrinterService.fromConfig, is removed below for the same reason —
// print_price_tag_dialog.dart was the only production code that ever built
// a LabelPrinterService from a raw ThisPosEntries connection-type index,
// and C4 repointed it at the label-printer DeviceBinding instead.
enum LabelTransport { usb, network, serial }

class LabelPrinterService {
  LabelPrinterService({
    Talker? logger,
    this.host,
    this.port = 9100,
    this.transport = LabelTransport.network,
    this.devicePath,
    this.language = LabelLanguage.zpl,
    this.labelWidthMm = 58,
    this.labelHeightMm = 40,
    this.dpi = 203,
  }) : _logger = logger;

  // LabelPrinterService.fromConfig removed (schema v27, second
  // final-review round): its only caller, print_price_tag_dialog.dart, was
  // repointed at the label-printer DeviceBinding by C4 and now builds a
  // LabelPrinterService with the plain constructor above instead. Left
  // behind, this factory (and the LabelTransport.fromConnectionTypeIndex/
  // _languageFromIndex helpers it alone called) would have been new dead
  // code of the exact kind finding I1 already objected to once.

  static const String defaultUsbDevicePath = '/dev/usb/lp0';

  static const String defaultSerialDevicePath = '/dev/ttyUSB0';

  final Talker? _logger;

  final String? host;

  final int port;

  final LabelTransport transport;

  final String? devicePath;

  final LabelLanguage language;

  final int labelWidthMm;

  final int labelHeightMm;

  final int dpi;

  Socket? _socket;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String get _effectiveDevicePath {
    if (devicePath != null && devicePath!.trim().isNotEmpty) {
      return devicePath!.trim();
    }
    return transport == LabelTransport.serial
        ? defaultSerialDevicePath
        : defaultUsbDevicePath;
  }

  static Future<List<LabelDeviceCandidate>> autoDetect() async {
    final found = <LabelDeviceCandidate>[];
    if (!Platform.isLinux) return found;

    final lpRe = RegExp(r'lp[0-9]+$');
    final ttyRe = RegExp(r'tty(USB|ACM)[0-9]+$');
    final seen = <String>{};

    void probe(String path, LabelTransport transport) {
      if (seen.contains(path)) return;
      if (FileSystemEntity.typeSync(path) == FileSystemEntityType.file) return;
      seen.add(path);
      bool openable;
      try {
        File(path).openSync(mode: FileMode.writeOnlyAppend).closeSync();
        openable = true;
      } catch (_) {
        openable = false;
      }
      found.add(
        LabelDeviceCandidate(
          devicePath: path,
          transport: transport,
          openable: openable,
        ),
      );
    }

    for (final dir in const ['/dev/usb', '/dev']) {
      try {
        for (final e in Directory(dir).listSync(followLinks: false)) {
          final p = e.path;
          if (lpRe.hasMatch(p)) {
            probe(p, LabelTransport.usb);
          } else if (ttyRe.hasMatch(p)) {
            probe(p, LabelTransport.serial);
          }
        }
      } catch (_) {}
    }

    found.sort((a, b) => a.devicePath.compareTo(b.devicePath));
    return found;
  }

  Future<LabelPrintResult> connect() async {
    if (transport != LabelTransport.network) {
      _isConnected = true;
      return LabelPrintResult.success();
    }

    if (host == null || host!.isEmpty) {
      return LabelPrintResult.failure('IP-адрес не указан');
    }

    try {
      _socket = await Socket.connect(
        host!,
        port,
        timeout: const Duration(seconds: 5),
      );
      _isConnected = true;
      _logger?.info('Label printer connected: $host:$port');
      return LabelPrintResult.success();
    } catch (e) {
      _logger?.error('Label printer connection failed: $e');
      return LabelPrintResult.failure('Ошибка подключения: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;
    _isConnected = false;
  }

  /// Байты страницы — **в кодовой странице, которую страница объявила**.
  ///
  /// Было `Uint8List.fromList(page.codeUnits)`: коды UTF-16 обрезались до
  /// байта, и «Молоко» уходило управляющими символами. Штрихкод из цифр
  /// доезжал целым, поэтому дефект не был виден: сканер читал, имя — мусор.
  ///
  /// * ZPL — `^CI28` (UTF-8) в каждой этикетке, байты UTF-8. Держат прошивки
  ///   Zebra x.14 и новее; шрифт `^CF0` масштабируемый и кириллицу знает.
  /// * TSPL — `CODEPAGE UTF-8`, байты UTF-8. **Не проверено на железе:**
  ///   встроенные шрифты TSC «1»–«8» — только ASCII, кириллицу печатает шрифт
  ///   «0» или загруженный TTF; наши шаблоны берут «2»–«4». Вопрос наружу.
  /// * EPL — `I8,C,001` (Windows-1251), байты Windows-1251: UTF-8 у EPL2 нет.
  ///
  /// ## Казахские буквы и ₸ на этикетке EPL
  ///
  /// В Windows-1251 из казахских букв есть **только** `І`/`і` (0xB2/0xB3) —
  /// они и уезжают целыми. Остальные восемь пар и знак тенге страница не
  /// содержит, и до правки 2026-09-19 уходили `?`: этикетка с ценой,
  /// нечитаемая покупателем, — такой же брак, как нечитаемый чек.
  ///
  /// Теперь текст проходит через общую таблицу бумаги
  /// (`hardware/paper_charset.dart`, `PaperCharset.windows1251`): казахские
  /// буквы выходят русской основой, `₸` — сокращением `тг`. Обоснование
  /// выбора — там же; коротко: кодовой страницы с казахским алфавитом у
  /// принтеров этикеток нет, а отказ печатать ценник за товар с казахским
  /// названием хуже, чем напечатать его русской буквой.
  ///
  /// Замена длиннее одного знака (`₸` → `тг`) здесь безопасна: EPL ставит
  /// текст командой `A x,y,...`, то есть по точкам, а не по колонкам, —
  /// разметке нечему съехать. У чека это не так, там замена идёт до
  /// разметки.
  ///
  /// **ZPL и TSPL намеренно оставлены как есть.** У них UTF-8, и ограничение
  /// не в кодировке, а в шрифте принтера — измерить его нечем. Заменить
  /// букву там значило бы испортить текст, который принтер, возможно,
  /// печатает верно.
  ///
  /// ## Чего это НЕ доказывает
  ///
  /// Ни одна из трёх ветвей не видела железа. Проверено, какие байты уходят,
  /// а не что принтер нарисует.
  Uint8List _encode(String page) => switch (language) {
    LabelLanguage.zpl || LabelLanguage.tspl => utf8.encode(page),
    LabelLanguage.epl => encodePaper(page, PaperCharset.windows1251),
  };

  Future<LabelPrintResult> _send(String page) async {
    final bytes = _encode(page);
    switch (transport) {
      case LabelTransport.network:
        if (_socket == null) {
          return LabelPrintResult.failure('Нет соединения с принтером');
        }
        _socket!.add(bytes);
        await _socket!.flush();
        return LabelPrintResult.success();
      case LabelTransport.usb:
      case LabelTransport.serial:
        return _writeToDevice(bytes);
    }
  }

  Future<LabelPrintResult> _writeToDevice(Uint8List bytes) async {
    if (!Platform.isLinux) {
      _logger?.debug(
        'Label print (stub, non-Linux): ${bytes.length} bytes to '
        '$_effectiveDevicePath',
      );
      return LabelPrintResult.success();
    }
    final path = _effectiveDevicePath;
    RandomAccessFile? raf;
    try {
      raf = await File(path).open(mode: FileMode.writeOnlyAppend);
      await raf.writeFrom(bytes);
      await raf.flush();
      _logger?.debug('Label printed via $path (${bytes.length} bytes)');
      return LabelPrintResult.success();
    } catch (e) {
      _logger?.error('Label device write failed ($path): $e');
      return LabelPrintResult.failure('Ошибка записи в $path: $e');
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
  }

  Future<LabelPrintResult> printPriceLabel({
    required String productName,
    required String barcode,
    required Decimal price,
    String? currencySymbol,
    int copies = 1,
  }) async {
    if (!_isConnected) {
      final connectResult = await connect();
      if (!connectResult.success) return connectResult;
    }

    try {
      final label = switch (language) {
        LabelLanguage.zpl => _buildZplPriceLabel(
          productName,
          barcode,
          price,
          currencySymbol ?? '₸',
          copies,
        ),
        LabelLanguage.tspl => _buildTsplPriceLabel(
          productName,
          barcode,
          price,
          currencySymbol ?? '₸',
          copies,
        ),
        LabelLanguage.epl => _buildEplPriceLabel(
          productName,
          barcode,
          price,
          currencySymbol ?? '₸',
          copies,
        ),
      };

      final sendResult = await _send(label);
      if (!sendResult.success) return sendResult;

      _logger?.debug('Price label printed: $productName ($barcode)');
      return LabelPrintResult.success();
    } catch (e) {
      _logger?.error('Label print failed: $e');
      return LabelPrintResult.failure('Ошибка печати: $e');
    }
  }

  Future<LabelPrintResult> printBarcodeLabel({
    required String barcode,
    required String text,
    int copies = 1,
  }) async {
    if (!_isConnected) {
      final connectResult = await connect();
      if (!connectResult.success) return connectResult;
    }

    try {
      final label = switch (language) {
        LabelLanguage.zpl => _buildZplBarcodeLabel(barcode, text, copies),
        LabelLanguage.tspl => _buildTsplBarcodeLabel(barcode, text, copies),
        LabelLanguage.epl => _buildEplBarcodeLabel(barcode, text, copies),
      };

      final sendResult = await _send(label);
      if (!sendResult.success) return sendResult;

      _logger?.debug('Barcode label printed: $barcode');
      return LabelPrintResult.success();
    } catch (e) {
      return LabelPrintResult.failure('Ошибка печати: $e');
    }
  }

  Future<LabelPrintResult> printTestLabel() async {
    return printPriceLabel(
      productName: 'TEST PRODUCT',
      barcode: '4607001000001',
      price: Decimal.parse('999.99'),
      currencySymbol: '₸',
    );
  }

  Future<LabelPrintResult> printTemplate({
    required List<LabelField> fields,
    required LabelData data,
    int? widthMm,
    int? heightMm,
    int copies = 1,
  }) async {
    if (!_isConnected) {
      final connectResult = await connect();
      if (!connectResult.success) return connectResult;
    }

    final w = widthMm ?? labelWidthMm;
    final h = heightMm ?? labelHeightMm;

    try {
      final label = switch (language) {
        LabelLanguage.zpl => _buildZplTemplate(fields, data, w, h, copies),
        LabelLanguage.tspl => _buildTsplTemplate(fields, data, w, h, copies),
        LabelLanguage.epl => _buildEplTemplate(fields, data, w, h, copies),
      };

      final sendResult = await _send(label);
      if (!sendResult.success) return sendResult;

      _logger?.debug('Template label printed: ${data.name}');
      return LabelPrintResult.success();
    } catch (e) {
      _logger?.error('Template label print failed: $e');
      return LabelPrintResult.failure('Ошибка печати: $e');
    }
  }

  String _fieldValue(LabelField f, LabelData data) {
    return switch (f.kind) {
      LabelFieldKind.name => data.name,
      LabelFieldKind.price =>
        '${data.currencySymbol} ${data.price.toStringAsFixed(2)}',
      LabelFieldKind.barcode => data.barcode,
      LabelFieldKind.sku => data.sku ?? '',
      LabelFieldKind.date => data.date ?? '',
      LabelFieldKind.text => f.text ?? '',
    };
  }

  String _buildZplTemplate(
    List<LabelField> fields,
    LabelData data,
    int w,
    int h,
    int copies,
  ) {
    final dotsW = (w * dpi / 25.4).round();
    final dotsH = (h * dpi / 25.4).round();
    final buf = StringBuffer()
      ..writeln('^XA')
      ..writeln('^CI28')
      ..writeln('^PW$dotsW')
      ..writeln('^LL$dotsH');

    for (final f in fields) {
      if (f.kind == LabelFieldKind.barcode) {
        buf
          ..writeln('^FO${f.x},${f.y}')
          ..writeln('^BY2,2,60')
          ..writeln('^BCN,60,Y,N,N')
          ..writeln('^FD${_fieldValue(f, data)}^FS');
      } else {
        final value = _fieldValue(f, data);
        if (value.isEmpty) continue;
        final fs = f.fontSize <= 0 ? 28 : f.fontSize;
        buf
          ..writeln('^CF0,$fs')
          ..writeln('^FO${f.x},${f.y}^FD$value^FS');
      }
    }
    buf
      ..writeln('^PQ$copies')
      ..writeln('^XZ');
    return buf.toString();
  }

  String _buildTsplTemplate(
    List<LabelField> fields,
    LabelData data,
    int w,
    int h,
    int copies,
  ) {
    final buf = StringBuffer()
      ..writeln('SIZE $w mm, $h mm')
      ..writeln('GAP 3 mm, 0 mm')
      ..writeln('CODEPAGE UTF-8')
      ..writeln('CLS');

    for (final f in fields) {
      if (f.kind == LabelFieldKind.barcode) {
        buf.writeln(
          'BARCODE ${f.x},${f.y},"128",60,1,0,2,2,"${_fieldValue(f, data)}"',
        );
      } else {
        final value = _fieldValue(f, data);
        if (value.isEmpty) continue;
        final font = f.fontSize >= 40 ? '4' : (f.fontSize >= 26 ? '3' : '2');
        buf.writeln('TEXT ${f.x},${f.y},"$font",0,1,1,"$value"');
      }
    }
    buf.writeln('PRINT $copies');
    return buf.toString();
  }

  String _buildEplTemplate(
    List<LabelField> fields,
    LabelData data,
    int w,
    int h,
    int copies,
  ) {
    final buf = StringBuffer()
      ..writeln('N')
      ..writeln('I8,C,001');

    for (final f in fields) {
      if (f.kind == LabelFieldKind.barcode) {
        buf.writeln('B${f.x},${f.y},0,1,2,2,60,B,"${_fieldValue(f, data)}"');
      } else {
        final value = _fieldValue(f, data);
        if (value.isEmpty) continue;
        final font = f.fontSize >= 40 ? '4' : (f.fontSize >= 26 ? '3' : '2');
        buf.writeln('A${f.x},${f.y},0,$font,1,1,N,"$value"');
      }
    }
    buf.writeln('P$copies');
    return buf.toString();
  }

  String _buildZplPriceLabel(
    String name,
    String barcode,
    Decimal price,
    String currency,
    int copies,
  ) {
    final dotsW = (labelWidthMm * dpi / 25.4).round();
    final dotsH = (labelHeightMm * dpi / 25.4).round();
    final priceStr = '$currency ${price.toStringAsFixed(2)}';

    final nameLine1 = name.length > 24 ? name.substring(0, 24) : name;
    final nameLine2 = name.length > 24
        ? name.substring(24, name.length.clamp(0, 48))
        : '';

    return '''
^XA
^CI28
^PW$dotsW
^LL$dotsH
^CF0,28
^FO20,20^FD$nameLine1^FS
${nameLine2.isNotEmpty ? '^FO20,52^FD$nameLine2^FS' : ''}
^CF0,40
^FO20,${nameLine2.isNotEmpty ? 90 : 60}^FD$priceStr^FS
^FO20,${nameLine2.isNotEmpty ? 145 : 115}
^BY2,2,60
^BCN,60,Y,N,N
^FD$barcode^FS
^PQ$copies
^XZ
''';
  }

  String _buildZplBarcodeLabel(String barcode, String text, int copies) {
    return '''
^XA
^CI28
^CF0,24
^FO20,20^FD$text^FS
^FO20,55
^BY2,2,80
^BCN,80,Y,N,N
^FD$barcode^FS
^PQ$copies
^XZ
''';
  }

  String _buildTsplPriceLabel(
    String name,
    String barcode,
    Decimal price,
    String currency,
    int copies,
  ) {
    final priceStr = '$currency ${price.toStringAsFixed(2)}';
    final nameLine1 = name.length > 24 ? name.substring(0, 24) : name;
    final nameLine2 = name.length > 24
        ? name.substring(24, name.length.clamp(0, 48))
        : '';

    return '''
SIZE $labelWidthMm mm, $labelHeightMm mm
GAP 3 mm, 0 mm
CODEPAGE UTF-8
CLS
TEXT 20,20,"3",0,1,1,"$nameLine1"
${nameLine2.isNotEmpty ? 'TEXT 20,50,"3",0,1,1,"$nameLine2"' : ''}
TEXT 20,${nameLine2.isNotEmpty ? 85 : 55},"4",0,1,1,"$priceStr"
BARCODE 20,${nameLine2.isNotEmpty ? 130 : 100},"128",60,1,0,2,2,"$barcode"
PRINT $copies
''';
  }

  String _buildTsplBarcodeLabel(String barcode, String text, int copies) {
    return '''
SIZE $labelWidthMm mm, $labelHeightMm mm
GAP 3 mm, 0 mm
CODEPAGE UTF-8
CLS
TEXT 20,20,"3",0,1,1,"$text"
BARCODE 20,55,"128",80,1,0,2,2,"$barcode"
PRINT $copies
''';
  }

  String _buildEplPriceLabel(
    String name,
    String barcode,
    Decimal price,
    String currency,
    int copies,
  ) {
    final priceStr = '$currency ${price.toStringAsFixed(2)}';
    return '''
N
I8,C,001
A20,20,0,3,1,1,N,"$name"
A20,55,0,4,1,1,N,"$priceStr"
B20,100,0,1,2,2,60,B,"$barcode"
P$copies
''';
  }

  String _buildEplBarcodeLabel(String barcode, String text, int copies) {
    return '''
N
I8,C,001
A20,20,0,3,1,1,N,"$text"
B20,55,0,1,2,2,80,B,"$barcode"
P$copies
''';
  }

  void dispose() {
    disconnect();
  }
}

enum LabelLanguage { zpl, tspl, epl }

enum LabelFieldKind {
  name,

  price,

  barcode,

  sku,

  date,

  text;

  static LabelFieldKind fromName(String? name) {
    return LabelFieldKind.values.firstWhere(
      (k) => k.name == name,
      orElse: () => LabelFieldKind.text,
    );
  }
}

enum LabelFieldAlign {
  left,
  center,
  right;

  static LabelFieldAlign fromName(String? name) {
    return LabelFieldAlign.values.firstWhere(
      (a) => a.name == name,
      orElse: () => LabelFieldAlign.left,
    );
  }
}

class LabelField {
  const LabelField({
    required this.kind,
    required this.x,
    required this.y,
    this.fontSize = 28,
    this.bold = false,
    this.align = LabelFieldAlign.left,
    this.text,
  });

  final LabelFieldKind kind;

  final int x;

  final int y;

  final int fontSize;

  final bool bold;

  final LabelFieldAlign align;

  final String? text;

  LabelField copyWith({
    LabelFieldKind? kind,
    int? x,
    int? y,
    int? fontSize,
    bool? bold,
    LabelFieldAlign? align,
    String? text,
  }) => LabelField(
    kind: kind ?? this.kind,
    x: x ?? this.x,
    y: y ?? this.y,
    fontSize: fontSize ?? this.fontSize,
    bold: bold ?? this.bold,
    align: align ?? this.align,
    text: text ?? this.text,
  );

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'x': x,
    'y': y,
    'fontSize': fontSize,
    'bold': bold,
    'align': align.name,
    if (text != null) 'text': text,
  };

  factory LabelField.fromJson(Map<String, dynamic> json) => LabelField(
    kind: LabelFieldKind.fromName(json['kind'] as String?),
    x: (json['x'] as num?)?.toInt() ?? 0,
    y: (json['y'] as num?)?.toInt() ?? 0,
    fontSize: (json['fontSize'] as num?)?.toInt() ?? 28,
    bold: json['bold'] as bool? ?? false,
    align: LabelFieldAlign.fromName(json['align'] as String?),
    text: json['text'] as String?,
  );
}

class LabelData {
  const LabelData({
    required this.name,
    required this.barcode,
    required this.price,
    this.currencySymbol = '₸',
    this.sku,
    this.date,
  });

  final String name;
  final String barcode;
  final Decimal price;
  final String currencySymbol;
  final String? sku;
  final String? date;
}

class LabelDeviceCandidate {
  const LabelDeviceCandidate({
    required this.devicePath,
    required this.transport,
    required this.openable,
  });

  final String devicePath;

  final LabelTransport transport;

  final bool openable;

  int get connectionTypeIndex => transport == LabelTransport.serial ? 3 : 0;
}

class LabelPrintResult {
  const LabelPrintResult({required this.success, this.errorMessage});

  final bool success;
  final String? errorMessage;

  factory LabelPrintResult.success() => const LabelPrintResult(success: true);
  factory LabelPrintResult.failure(String message) =>
      LabelPrintResult(success: false, errorMessage: message);
}
