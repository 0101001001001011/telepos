import 'dart:typed_data';

abstract class ReceiptBuilder {
  Uint8List build();

  String toDebugString();
}

enum TextAlign { left, center, right }

enum TextSize { normal, doubleWidth, doubleHeight, doubleAll }

class EscPosCommands {
  EscPosCommands._();

  static const List<int> init = [0x1B, 0x40, 0x1B, 0x74, 17];

  static const List<int> alignLeft = [0x1B, 0x61, 0x00];

  static const List<int> alignCenter = [0x1B, 0x61, 0x01];

  static const List<int> alignRight = [0x1B, 0x61, 0x02];

  static const List<int> sizeNormal = [0x1D, 0x21, 0x00];

  static const List<int> sizeDoubleWidth = [0x1D, 0x21, 0x10];

  static const List<int> sizeDoubleHeight = [0x1D, 0x21, 0x01];

  static const List<int> sizeDouble = [0x1D, 0x21, 0x11];

  static const List<int> boldOn = [0x1B, 0x45, 0x01];

  static const List<int> boldOff = [0x1B, 0x45, 0x00];

  static const List<int> newLine = [0x0A];

  static const List<int> cutPaper = [0x1D, 0x56, 0x01];

  static List<int> feedLines(int n) => [0x1B, 0x64, n];
}

class Cp866Encoder {
  static Uint8List encode(String text) {
    final bytes = <int>[];
    for (final char in text.runes) {
      bytes.add(_charToCP866(char));
    }
    return Uint8List.fromList(bytes);
  }

  static int _charToCP866(int codePoint) {
    if (codePoint < 128) {
      return codePoint;
    }

    if (codePoint >= 0x410 && codePoint <= 0x42F) {
      return codePoint - 0x410 + 0x80;
    }

    if (codePoint >= 0x430 && codePoint <= 0x43F) {
      return codePoint - 0x430 + 0xA0;
    }

    if (codePoint >= 0x440 && codePoint <= 0x44F) {
      return codePoint - 0x440 + 0xE0;
    }

    if (codePoint == 0x401) {
      return 0xF0;
    }

    if (codePoint == 0x451) {
      return 0xF1;
    }

    if (codePoint == 0x20B8) {
      return 0x54;
    }

    if (codePoint == 0x20BD) {
      return 0x50;
    }

    return 0x3F;
  }
}
