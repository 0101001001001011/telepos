import 'dart:convert';
import 'dart:typed_data';

import 'package:telepos/hardware/printer/printer_manager.dart';

class ReceiptBuilder {
  ReceiptBuilder({this.charWidth = 32, this.encoding = 'cp866'});

  final int charWidth;

  final String encoding;

  final List<int> _buffer = [];

  ReceiptBuilder init() {
    _buffer.addAll(EscPosCommands.init);
    return this;
  }

  ReceiptBuilder addCentered(
    String text, {
    bool bold = false,
    bool doubleSize = false,
  }) {
    _buffer.addAll(EscPosCommands.alignCenter);
    if (bold) _buffer.addAll(EscPosCommands.boldOn);
    if (doubleSize) _buffer.addAll(EscPosCommands.sizeDouble);

    _addText(_truncate(text, charWidth));
    _buffer.addAll(EscPosCommands.newLine);

    if (doubleSize) _buffer.addAll(EscPosCommands.sizeNormal);
    if (bold) _buffer.addAll(EscPosCommands.boldOff);
    _buffer.addAll(EscPosCommands.alignLeft);

    return this;
  }

  ReceiptBuilder addLeft(String text, {bool bold = false}) {
    _buffer.addAll(EscPosCommands.alignLeft);
    if (bold) _buffer.addAll(EscPosCommands.boldOn);

    _addText(_truncate(text, charWidth));
    _buffer.addAll(EscPosCommands.newLine);

    if (bold) _buffer.addAll(EscPosCommands.boldOff);

    return this;
  }

  ReceiptBuilder addRight(String text, {bool bold = false}) {
    _buffer.addAll(EscPosCommands.alignRight);
    if (bold) _buffer.addAll(EscPosCommands.boldOn);

    _addText(_truncate(text, charWidth));
    _buffer.addAll(EscPosCommands.newLine);

    if (bold) _buffer.addAll(EscPosCommands.boldOff);
    _buffer.addAll(EscPosCommands.alignLeft);

    return this;
  }

  ReceiptBuilder addRow(String left, String right, {bool bold = false}) {
    if (bold) _buffer.addAll(EscPosCommands.boldOn);

    final maxLeftLen = charWidth - right.length - 1;
    final leftTruncated = _truncate(left, maxLeftLen);
    final padding = charWidth - leftTruncated.length - right.length;

    final line = leftTruncated + ' ' * padding + right;
    _addText(line);
    _buffer.addAll(EscPosCommands.newLine);

    if (bold) _buffer.addAll(EscPosCommands.boldOff);

    return this;
  }

  ReceiptBuilder addRow3(
    String left,
    String center,
    String right, {
    bool bold = false,
  }) {
    if (bold) _buffer.addAll(EscPosCommands.boldOn);

    final totalLen = left.length + center.length + right.length;
    if (totalLen >= charWidth) {
      return addRow(left, right, bold: bold);
    }

    final leftPadding = (charWidth - totalLen) ~/ 2;
    final rightPadding =
        charWidth - left.length - center.length - right.length - leftPadding;

    final line = left + ' ' * leftPadding + center + ' ' * rightPadding + right;
    _addText(line);
    _buffer.addAll(EscPosCommands.newLine);

    if (bold) _buffer.addAll(EscPosCommands.boldOff);

    return this;
  }

  ReceiptBuilder addLine({String char = '-'}) {
    _addText(char * charWidth);
    _buffer.addAll(EscPosCommands.newLine);
    return this;
  }

  ReceiptBuilder addDoubleLine() {
    return addLine(char: '=');
  }

  ReceiptBuilder addNewLines(int count) {
    _buffer.addAll(EscPosCommands.feedLines(count));
    return this;
  }

  ReceiptBuilder addEmptyLine() {
    _buffer.addAll(EscPosCommands.newLine);
    return this;
  }

  ReceiptBuilder qr(String data, {int moduleSize = 6}) {
    if (data.isEmpty) return this;
    _buffer.addAll(EscPosCommands.alignCenter);
    _buffer.addAll(EscPosCommands.qrCode(data, moduleSize: moduleSize));
    _buffer.addAll(EscPosCommands.alignLeft);
    return this;
  }

  ReceiptBuilder cut() {
    _buffer.addAll(EscPosCommands.cutPaperPartialEscI);
    return this;
  }

  ReceiptBuilder cutPartial() {
    _buffer.addAll(EscPosCommands.cutPaper);
    return this;
  }

  ReceiptBuilder openDrawer() {
    _buffer.addAll(EscPosCommands.openDrawer);
    return this;
  }

  ReceiptBuilder beep() {
    _buffer.addAll(EscPosCommands.beep);
    return this;
  }

  Uint8List build() {
    return Uint8List.fromList(_buffer);
  }

  void _addText(String text) {
    _buffer.addAll(_encodeText(text));
  }

  List<int> _encodeText(String text) {
    if (encoding == 'cp866') {
      return _encodeCp866(text);
    }
    return utf8.encode(text);
  }

  List<int> _encodeCp866(String text) {
    final result = <int>[];

    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);

      if (code < 128) {
        result.add(code);
        continue;
      }

      if (code >= 0x410 && code <= 0x43F) {
        if (code <= 0x42F) {
          result.add(code - 0x410 + 0x80);
        } else {
          result.add(code - 0x430 + 0xA0);
        }
        continue;
      }

      if (code >= 0x440 && code <= 0x44F) {
        result.add(code - 0x440 + 0xE0);
        continue;
      }

      if (code == 0x401) {
        result.add(0xF0);
        continue;
      }
      if (code == 0x451) {
        result.add(0xF1);
        continue;
      }

      if (code == 0x2116) {
        result.add(0xFC);
        continue;
      }

      result.add(0x3F);
    }

    return result;
  }

  String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return text.substring(0, maxLen);
  }
}
