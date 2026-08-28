import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrCodeGenerator {
  QrCodeGenerator._();

  static const int defaultSize = 90;

  static const int qrVersion = QrVersions.auto;

  static const int errorCorrectionLevel = QrErrorCorrectLevel.M;

  static Future<ui.Image> generateImage(
    String data, {
    int size = defaultSize,
    Color foregroundColor = Colors.black,
  }) async {
    final qrPainter = QrPainter(
      data: data,
      version: qrVersion,
      errorCorrectionLevel: errorCorrectionLevel,
      eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: foregroundColor),
      dataModuleStyle: QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: foregroundColor,
      ),
    );

    final image = await qrPainter.toImage(size.toDouble());
    return image;
  }

  static Future<Uint8List> generatePng(
    String data, {
    int size = defaultSize,
  }) async {
    final qrPainter = QrPainter(
      data: data,
      version: qrVersion,
      errorCorrectionLevel: errorCorrectionLevel,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    );

    final imageData = await qrPainter.toImageData(size.toDouble());
    if (imageData == null) {
      throw QrGenerationException('Не удалось сгенерировать QR-код');
    }

    return imageData.buffer.asUint8List();
  }

  static Future<Uint8List> generateEscPosBitmap(
    String data, {
    int size = defaultSize,
  }) async {
    final image = await generateImage(data, size: size);
    return _imageToEscPosBitmap(image);
  }

  static Future<Uint8List> generateEscPosCommand(
    String data, {
    int size = defaultSize,
    bool centerAlign = true,
  }) async {
    final image = await generateImage(data, size: size);
    return _imageToEscPosCommand(image, centerAlign: centerAlign);
  }

  static Future<Uint8List> _imageToEscPosBitmap(ui.Image image) async {
    final width = image.width;
    final height = image.height;

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw QrGenerationException('Не удалось получить данные изображения');
    }

    final pixels = byteData.buffer.asUint8List();

    final bytesPerLine = (width + 7) ~/ 8;
    final bitmapData = <int>[];

    for (var y = 0; y < height; y++) {
      for (var byteIndex = 0; byteIndex < bytesPerLine; byteIndex++) {
        var byte = 0;
        for (var bit = 0; bit < 8; bit++) {
          final x = byteIndex * 8 + bit;
          if (x < width) {
            final pixelIndex = (y * width + x) * 4;
            final r = pixels[pixelIndex];
            final g = pixels[pixelIndex + 1];
            final b = pixels[pixelIndex + 2];

            final brightness = (r + g + b) ~/ 3;
            if (brightness < 128) {
              byte |= (0x80 >> bit);
            }
          }
        }
        bitmapData.add(byte);
      }
    }

    return Uint8List.fromList(bitmapData);
  }

  static Future<Uint8List> _imageToEscPosCommand(
    ui.Image image, {
    bool centerAlign = true,
  }) async {
    final width = image.width;
    final height = image.height;

    final bytesPerLine = (width + 7) ~/ 8;
    final bitmapData = await _imageToEscPosBitmap(image);

    final command = <int>[];

    if (centerAlign) {
      command.addAll([0x1B, 0x61, 0x01]);
    }

    command.addAll([
      0x1D,
      0x76,
      0x30,
      0x00,
      bytesPerLine & 0xFF,
      (bytesPerLine >> 8) & 0xFF,
      height & 0xFF,
      (height >> 8) & 0xFF,
    ]);

    command.addAll(bitmapData);

    if (centerAlign) {
      command.addAll([0x1B, 0x61, 0x00]);
    }

    command.add(0x0A);

    return Uint8List.fromList(command);
  }

  static Future<Uint8List> generateForReceipt(
    String ticketUrl, {
    int size = defaultSize,
  }) async {
    if (ticketUrl.isEmpty) {
      throw QrGenerationException('URL чека не может быть пустым');
    }

    return generateEscPosCommand(ticketUrl, size: size);
  }

  static bool isValidTicketUrl(String url) {
    if (url.isEmpty) return false;

    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && uri.hasAuthority;
    } catch (_) {
      return false;
    }
  }
}

class QrGenerationException implements Exception {
  QrGenerationException(this.message);
  final String message;

  @override
  String toString() => 'QrGenerationException: $message';
}

class QrCodeBuilder {
  QrCodeBuilder(this.data);

  final String data;

  int _size = QrCodeGenerator.defaultSize;
  bool _centerAlign = true;

  QrCodeBuilder size(int size) {
    _size = size;
    return this;
  }

  QrCodeBuilder centered([bool centered = true]) {
    _centerAlign = centered;
    return this;
  }

  Future<Uint8List> toPng() => QrCodeGenerator.generatePng(data, size: _size);

  Future<Uint8List> toEscPos() => QrCodeGenerator.generateEscPosCommand(
    data,
    size: _size,
    centerAlign: _centerAlign,
  );

  Future<ui.Image> toImage() =>
      QrCodeGenerator.generateImage(data, size: _size);
}

extension QrCodeExtension on String {
  QrCodeBuilder toQrCode() => QrCodeBuilder(this);
}
