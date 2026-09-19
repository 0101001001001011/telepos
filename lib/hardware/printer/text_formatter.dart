import 'dart:typed_data';

import 'package:telepos/hardware/printer/printer_manager.dart';
import 'package:telepos/hardware/paper_charset.dart';
import 'package:telepos/hardware/printer/receipt/receipt_builder.dart'
    show TextAlign, TextSize;

class TextFormatter {
  TextFormatter();

  Uint8List format(String text) {
    final buffer = <int>[];

    final boldStack = <bool>[];
    final italicStack = <bool>[];
    final underlineStack = <bool>[];
    final alignStack = <TextAlign>[];
    final sizeStack = <TextSize>[];
    final inverseStack = <bool>[];

    var i = 0;
    while (i < text.length) {
      if (text[i] == '<') {
        final closeIdx = text.indexOf('>', i);
        if (closeIdx == -1) {
          buffer.addAll(_cp866(text[i]));
          i++;
          continue;
        }

        final tag = text.substring(i + 1, closeIdx).toLowerCase().trim();
        final isClosing = tag.startsWith('/');
        final tagName = isClosing ? tag.substring(1) : tag;

        switch (tagName) {
          case 'b':
          case 'bold':
            if (isClosing) {
              if (boldStack.isNotEmpty) boldStack.removeLast();
              buffer.addAll(EscPosCommands.boldOff);
            } else {
              boldStack.add(true);
              buffer.addAll(EscPosCommands.boldOn);
            }
          case 'i':
          case 'italic':
            if (isClosing) {
              if (italicStack.isNotEmpty) italicStack.removeLast();
              buffer.addAll(EscPosCommands.italicOff);
            } else {
              italicStack.add(true);
              buffer.addAll(EscPosCommands.italicOn);
            }
          case 'u':
          case 'underline':
            if (isClosing) {
              if (underlineStack.isNotEmpty) underlineStack.removeLast();
              buffer.addAll(EscPosCommands.underlineOff);
            } else {
              underlineStack.add(true);
              buffer.addAll(EscPosCommands.underlineOn);
            }
          case 'center':
            if (isClosing) {
              if (alignStack.isNotEmpty) alignStack.removeLast();
              buffer.addAll(EscPosCommands.alignLeft);
            } else {
              alignStack.add(TextAlign.center);
              buffer.addAll(EscPosCommands.alignCenter);
            }
          case 'right':
            if (isClosing) {
              if (alignStack.isNotEmpty) alignStack.removeLast();
              buffer.addAll(EscPosCommands.alignLeft);
            } else {
              alignStack.add(TextAlign.right);
              buffer.addAll(EscPosCommands.alignRight);
            }
          case 'left':
            if (isClosing) {
              if (alignStack.isNotEmpty) alignStack.removeLast();
            }
            buffer.addAll(EscPosCommands.alignLeft);
          case 'big':
          case 'large':
            if (isClosing) {
              if (sizeStack.isNotEmpty) sizeStack.removeLast();
              buffer.addAll(EscPosCommands.sizeNormal);
            } else {
              sizeStack.add(TextSize.doubleAll);
              buffer.addAll(EscPosCommands.sizeDouble);
            }
          case 'wide':
            if (isClosing) {
              if (sizeStack.isNotEmpty) sizeStack.removeLast();
              buffer.addAll(EscPosCommands.sizeNormal);
            } else {
              sizeStack.add(TextSize.doubleWidth);
              buffer.addAll(EscPosCommands.sizeDoubleWidth);
            }
          case 'tall':
            if (isClosing) {
              if (sizeStack.isNotEmpty) sizeStack.removeLast();
              buffer.addAll(EscPosCommands.sizeNormal);
            } else {
              sizeStack.add(TextSize.doubleHeight);
              buffer.addAll(EscPosCommands.sizeDoubleHeight);
            }
          case 'inv':
          case 'inverse':
            if (isClosing) {
              if (inverseStack.isNotEmpty) inverseStack.removeLast();
              buffer.addAll(EscPosCommands.inverseOff);
            } else {
              inverseStack.add(true);
              buffer.addAll(EscPosCommands.inverseOn);
            }
          case 'br':
          case 'br/':
            buffer.addAll(EscPosCommands.newLine);
          case 'hr':
          case 'hr/':
            buffer.addAll(_cp866('-' * 32));
            buffer.addAll(EscPosCommands.newLine);
          case 'cut':
          case 'cut/':
            buffer.addAll(EscPosCommands.cutPaper);
          case 'drawer':
          case 'drawer/':
            buffer.addAll(EscPosCommands.openDrawer);
          case 'beep':
          case 'beep/':
            buffer.addAll(EscPosCommands.beep);
          case 'init':
          case 'init/':
            buffer.addAll(EscPosCommands.init);
          default:
            buffer.addAll(_cp866('<$tag>'));
        }

        i = closeIdx + 1;
      } else if (text[i] == '\n') {
        buffer.addAll(EscPosCommands.newLine);
        i++;
      } else {
        buffer.addAll(_cp866(text[i]));
        i++;
      }
    }

    return Uint8List.fromList(buffer);
  }

  Uint8List formatPlain(String text) {
    return _cp866(text);
  }

  static Uint8List bold(String text) {
    return Uint8List.fromList([
      ...EscPosCommands.boldOn,
      ..._cp866(text),
      ...EscPosCommands.boldOff,
    ]);
  }

  static Uint8List centered(String text) {
    return Uint8List.fromList([
      ...EscPosCommands.alignCenter,
      ..._cp866(text),
      ...EscPosCommands.newLine,
      ...EscPosCommands.alignLeft,
    ]);
  }

  static Uint8List large(String text) {
    return Uint8List.fromList([
      ...EscPosCommands.sizeDouble,
      ..._cp866(text),
      ...EscPosCommands.sizeNormal,
    ]);
  }

  static Uint8List row(String label, String value, {int width = 32}) {
    final padding = width - label.length - value.length;
    final spaces = padding > 0 ? ' ' * padding : ' ';
    return Uint8List.fromList([
      ..._cp866('$label$spaces$value'),
      ...EscPosCommands.newLine,
    ]);
  }

  static Uint8List divider({int width = 32, String char = '-'}) {
    return Uint8List.fromList([
      ..._cp866(char * width),
      ...EscPosCommands.newLine,
    ]);
  }

  static Uint8List emptyLine() {
    return Uint8List.fromList(EscPosCommands.newLine);
  }
}

class TextFormatBuilder {
  TextFormatBuilder();

  final _buffer = <int>[];

  TextFormatBuilder text(String text) {
    _buffer.addAll(_cp866(text));
    return this;
  }

  TextFormatBuilder bold(String text) {
    _buffer.addAll(EscPosCommands.boldOn);
    _buffer.addAll(_cp866(text));
    _buffer.addAll(EscPosCommands.boldOff);
    return this;
  }

  TextFormatBuilder underline(String text) {
    _buffer.addAll(EscPosCommands.underlineOn);
    _buffer.addAll(_cp866(text));
    _buffer.addAll(EscPosCommands.underlineOff);
    return this;
  }

  TextFormatBuilder center() {
    _buffer.addAll(EscPosCommands.alignCenter);
    return this;
  }

  TextFormatBuilder left() {
    _buffer.addAll(EscPosCommands.alignLeft);
    return this;
  }

  TextFormatBuilder right() {
    _buffer.addAll(EscPosCommands.alignRight);
    return this;
  }

  TextFormatBuilder newLine() {
    _buffer.addAll(EscPosCommands.newLine);
    return this;
  }

  TextFormatBuilder divider({int width = 32}) {
    _buffer.addAll(_cp866('-' * width));
    _buffer.addAll(EscPosCommands.newLine);
    return this;
  }

  TextFormatBuilder row(String label, String value, {int width = 32}) {
    final padding = width - label.length - value.length;
    final spaces = padding > 0 ? ' ' * padding : ' ';
    _buffer.addAll(_cp866('$label$spaces$value'));
    _buffer.addAll(EscPosCommands.newLine);
    return this;
  }

  TextFormatBuilder large() {
    _buffer.addAll(EscPosCommands.sizeDouble);
    return this;
  }

  TextFormatBuilder normal() {
    _buffer.addAll(EscPosCommands.sizeNormal);
    return this;
  }

  TextFormatBuilder cut() {
    _buffer.addAll(EscPosCommands.cutPaper);
    return this;
  }

  TextFormatBuilder openDrawer() {
    _buffer.addAll(EscPosCommands.openDrawer);
    return this;
  }

  Uint8List build() {
    return Uint8List.fromList(_buffer);
  }
}

/// Байты CP866 — общей таблицей бумаги (`hardware/paper_charset.dart`).
///
/// Своего кодировщика у форматировщика больше нет: тот, что здесь стоял,
/// подставлял вместо `₸` латинскую `T`.
Uint8List _cp866(String text) => encodePaper(text, PaperCharset.cp866);
