/// Чек **на экране** — из тех же байтов ESC/POS, что уходят в принтер.
///
/// ## Почему не второй рендер
///
/// До этой правки предпросмотр шаблона рисовал `_PreviewTextRenderer` — вторая,
/// независимая копия раскладки чека. Копии разошлись: предпросмотр переносил
/// ссылку проверки чека, а байты её обрезали по ширине; `escpos_wire_test`
/// записал это расхождение ещё планом 2б. Экран, показывающий не то, что
/// напечатается, хуже экрана без предпросмотра.
///
/// Здесь разбирается готовый поток `ReceiptBuilder`: выравнивание `ESC a`
/// превращается в отступ, двойная ширина `GS !` — в разрядку, QR-код — в метку
/// `[ QR ]`. Жирный шрифт в тексте не виден — это ограничение моноширинного
/// предпросмотра, а не расхождение раскладки: строки и переносы те же.
library;

import 'package:telepos/hardware/paper_charset.dart';

/// Текст чека шириной [width] колонок из потока [bytes].
String renderEscPosAsText(List<int> bytes, {required int width}) {
  final out = StringBuffer();
  final line = StringBuffer();
  var align = 0;
  var doubleWidth = false;

  void writeAligned(String text, {int? visualWidth}) {
    final occupied = visualWidth ?? text.length;
    final pad = switch (align) {
      1 => (width - occupied) ~/ 2,
      2 => width - occupied,
      _ => 0,
    };
    out.writeln('${' ' * (pad > 0 ? pad : 0)}$text');
  }

  // Двойная ширина занимает на ленте вдвое больше колонок — это учитывается
  // в отступе выравнивания. Сами буквы не разрежаются: строка остаётся той
  // же строкой, которую ищут глазами и поиском.
  void endLine() {
    final raw = line.toString();
    line.clear();
    writeAligned(raw, visualWidth: doubleWidth ? raw.length * 2 : raw.length);
  }

  var i = 0;
  while (i < bytes.length) {
    final b = bytes[i];
    if (b == 0x1B) {
      final c = i + 1 < bytes.length ? bytes[i + 1] : -1;
      switch (c) {
        case 0x61: // ESC a n
          if (i + 2 < bytes.length) align = bytes[i + 2];
          i += 3;
        case 0x74 || 0x45 || 0x2D || 0x64 || 0x33: // ESC t/E/-/d/3 n
          i += 3;
        case 0x70: // ESC p m t1 t2
          i += 5;
        case 0x42: // ESC B n t
          i += 4;
        default: // ESC @, ESC i, ESC 2, неизвестная
          i += 2;
      }
      continue;
    }
    if (b == 0x1D) {
      final c = i + 1 < bytes.length ? bytes[i + 1] : -1;
      switch (c) {
        case 0x21: // GS ! n
          final n = i + 2 < bytes.length ? bytes[i + 2] : 0;
          doubleWidth = (n & 0x10) != 0;
          i += 3;
        case 0x28: // GS ( k pL pH cn fn ...
          if (i + 4 >= bytes.length) {
            i = bytes.length;
            break;
          }
          final len = bytes[i + 3] | (bytes[i + 4] << 8);
          final bodyStart = i + 5;
          if (bodyStart + 1 < bytes.length &&
              bytes[bodyStart] == 0x31 &&
              bytes[bodyStart + 1] == 0x50) {
            if (line.isNotEmpty) endLine();
            writeAligned('[ QR ]');
          }
          i = bodyStart + len;
        case 0x6B: // GS k — штрихкод до NUL
          i += 2;
          while (i < bytes.length && bytes[i] != 0x00) {
            i++;
          }
          i++;
        default: // GS V n, GS B n
          i += 3;
      }
      continue;
    }
    if (b == 0x0A) {
      endLine();
      i++;
      continue;
    }
    if (b == 0x10) {
      i += 3; // DLE EOT n
      continue;
    }
    if (b < 0x20) {
      i++;
      continue;
    }
    line.write(decodePaperByte(b, PaperCharset.cp866));
    i++;
  }
  if (line.isNotEmpty) endLine();
  return out.toString();
}
