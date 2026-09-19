/// Разборщик потока ESC/POS: байты внутрь, **чек на экран** наружу.
///
/// Отдельным файлом, потому что читателя два и они разные: сетевой эмулятор
/// (`emulator.dart`, порт 9100) и файл, который пишет эмулятор спулера
/// (`lib/emulators/emulated_spooler_printer.dart`). Один разборщик, два
/// вызывающих — не два разборщика, расходящихся через месяц.
///
/// # Чего этот разборщик НЕ доказывает
///
/// * **Что чек напечатан физически.** Бумаги здесь нет.
/// * **Что настоящий принтер нарисует то же самое.** Кодовая страница
///   выбирается командой `ESC t n`, и соответствие `n` → кодировка у каждой
///   модели своё; здесь взято то, которое ставит наш продукт (CP866, `n=17`).
///   Модель, у которой `17` значит другое, напечатает крокозябры там, где
///   этот разборщик покажет русский текст.
/// * **Что QR-код читается.** Данные `GS ( k` вынимаются и печатаются
///   текстом; растра здесь нет.
/// * **Что ширина ленты соблюдена.** Ширина здесь — параметр показа, а не
///   свойство прибора.
library;

import 'dart:convert';

import 'package:telepos/hardware/paper_charset.dart';

/// Один разобранный кусок чека.
class EscPosEvent {
  EscPosEvent(this.kind, this.text, {this.raw = const []});

  /// `text`, `cut`, `drawer`, `init`, `feed`, `qr`, `barcode`, `align`,
  /// `bold`, `size`, `codepage`, `status`, `unknown`.
  final String kind;
  final String text;
  final List<int> raw;

  @override
  String toString() => '$kind: $text';
}

/// Разбор одного потока ESC/POS.
///
/// Не потоковый разбор с состоянием между вызовами: чек уходит принтеру одной
/// записью (`BufferedPrinterManager._send` ничего не делит), поэтому и
/// разбирается он целиком. Обрывок кадра в конце буфера отдаётся как
/// `unknown`, а не молча съедается: незамеченный обрывок — это ровно тот
/// способ, которым разборщик выглядит рабочим на неполных данных.
List<EscPosEvent> parseEscPos(List<int> bytes) {
  final out = <EscPosEvent>[];
  final text = <int>[];
  var codePage = 'CP866';

  void flushText() {
    if (text.isEmpty) return;
    out.add(EscPosEvent('text', _decode(text, codePage), raw: [...text]));
    text.clear();
  }

  var i = 0;
  while (i < bytes.length) {
    final b = bytes[i];

    if (b == 0x1B) {
      // ESC ...
      if (i + 1 >= bytes.length) {
        flushText();
        out.add(EscPosEvent('unknown', 'обрыв: ESC без аргумента'));
        break;
      }
      final c = bytes[i + 1];
      switch (c) {
        case 0x40: // ESC @
          flushText();
          out.add(EscPosEvent('init', 'сброс принтера'));
          i += 2;
        case 0x74: // ESC t n
          if (i + 2 >= bytes.length) {
            flushText();
            out.add(EscPosEvent('unknown', 'обрыв: ESC t без аргумента'));
            i = bytes.length;
            break;
          }
          flushText();
          final n = bytes[i + 2];
          codePage = _codePageFor(n);
          out.add(EscPosEvent('codepage', 'ESC t $n → $codePage'));
          i += 3;
        case 0x61: // ESC a n
          if (i + 2 >= bytes.length) {
            flushText();
            out.add(EscPosEvent('unknown', 'обрыв: ESC a без аргумента'));
            i = bytes.length;
            break;
          }
          flushText();
          out.add(
            EscPosEvent('align', switch (bytes[i + 2]) {
              0 => 'по левому краю',
              1 => 'по центру',
              2 => 'по правому краю',
              final n => 'выравнивание $n',
            }),
          );
          i += 3;
        case 0x45: // ESC E n
          if (i + 2 >= bytes.length) {
            flushText();
            out.add(EscPosEvent('unknown', 'обрыв: ESC E без аргумента'));
            i = bytes.length;
            break;
          }
          flushText();
          out.add(
            EscPosEvent('bold', bytes[i + 2] == 0 ? 'жирный выкл' : 'жирный вкл'),
          );
          i += 3;
        case 0x2D: // ESC - n
          if (i + 2 >= bytes.length) {
            flushText();
            out.add(EscPosEvent('unknown', 'обрыв: ESC - без аргумента'));
            i = bytes.length;
            break;
          }
          flushText();
          out.add(
            EscPosEvent(
              'underline',
              bytes[i + 2] == 0 ? 'подчёркивание выкл' : 'подчёркивание вкл',
            ),
          );
          i += 3;
        case 0x64: // ESC d n
          if (i + 2 >= bytes.length) {
            flushText();
            out.add(EscPosEvent('unknown', 'обрыв: ESC d без аргумента'));
            i = bytes.length;
            break;
          }
          flushText();
          out.add(EscPosEvent('feed', 'протяжка ${bytes[i + 2]} строк'));
          i += 3;
        case 0x70: // ESC p m t1 t2 — денежный ящик
          if (i + 4 >= bytes.length) {
            flushText();
            out.add(EscPosEvent('unknown', 'обрыв: ESC p без аргументов'));
            i = bytes.length;
            break;
          }
          flushText();
          out.add(
            EscPosEvent(
              'drawer',
              'ЯЩИК ОТКРЫТ: контакт ${bytes[i + 2]}, импульс '
              '${bytes[i + 3]}/${bytes[i + 4]}',
            ),
          );
          i += 5;
        case 0x69: // ESC i — частичный рез
          flushText();
          out.add(EscPosEvent('cut', 'рез бумаги (ESC i, частичный)'));
          i += 2;
        case 0x42: // ESC B n t
          flushText();
          out.add(EscPosEvent('beep', 'звуковой сигнал'));
          i += 4;
        case 0x33: // ESC 3 n
          flushText();
          out.add(EscPosEvent('spacing', 'межстрочный интервал'));
          i += 3;
        case 0x32: // ESC 2
          flushText();
          out.add(EscPosEvent('spacing', 'межстрочный интервал по умолчанию'));
          i += 2;
        default:
          flushText();
          out.add(EscPosEvent('unknown', 'ESC 0x${c.toRadixString(16)}'));
          i += 2;
      }
      continue;
    }

    if (b == 0x1D) {
      // GS ...
      if (i + 1 >= bytes.length) {
        flushText();
        out.add(EscPosEvent('unknown', 'обрыв: GS без аргумента'));
        break;
      }
      final c = bytes[i + 1];
      switch (c) {
        case 0x21: // GS ! n
          flushText();
          final n = i + 2 < bytes.length ? bytes[i + 2] : 0;
          out.add(
            EscPosEvent('size', switch (n) {
              0x00 => 'обычный размер',
              0x10 => 'двойная ширина',
              0x01 => 'двойная высота',
              0x11 => 'двойной размер',
              _ => 'размер 0x${n.toRadixString(16)}',
            }),
          );
          i += 3;
        case 0x42: // GS B n
          flushText();
          out.add(EscPosEvent('inverse', 'инверсия'));
          i += 3;
        case 0x56: // GS V n
          flushText();
          final n = i + 2 < bytes.length ? bytes[i + 2] : 0;
          out.add(
            EscPosEvent(
              'cut',
              n == 0 ? 'рез бумаги (GS V 0, полный)' : 'рез бумаги (GS V $n)',
            ),
          );
          i += 3;
        case 0x28: // GS ( k — QR
          if (i + 4 >= bytes.length) {
            flushText();
            out.add(EscPosEvent('unknown', 'обрыв: GS ( без длины'));
            i = bytes.length;
            break;
          }
          final len = bytes[i + 3] | (bytes[i + 4] << 8);
          final end = i + 5 + len;
          if (end > bytes.length) {
            flushText();
            out.add(
              EscPosEvent(
                'unknown',
                'обрыв: GS ( k объявил $len байт, в потоке '
                '${bytes.length - i - 5}',
              ),
            );
            i = bytes.length;
            break;
          }
          final body = bytes.sublist(i + 5, end);
          // Функция 180 (`1P0`): данные QR-кода.
          if (body.length >= 3 && body[0] == 0x31 && body[1] == 0x50) {
            flushText();
            out.add(
              EscPosEvent('qr', _decode(body.sublist(3), codePage)),
            );
          }
          i = end;
        case 0x6B: // GS k — линейный штрихкод
          flushText();
          out.add(EscPosEvent('barcode', 'штрихкод'));
          i += 2;
          while (i < bytes.length && bytes[i] != 0x00) {
            i++;
          }
          if (i < bytes.length) i++;
        default:
          flushText();
          out.add(EscPosEvent('unknown', 'GS 0x${c.toRadixString(16)}'));
          i += 2;
      }
      continue;
    }

    if (b == 0x10 && i + 2 < bytes.length && bytes[i + 1] == 0x04) {
      // DLE EOT n — опрос состояния в реальном времени. В потоке печати его
      // быть не должно; отмечается, а не проглатывается.
      flushText();
      out.add(EscPosEvent('status', 'опрос DLE EOT ${bytes[i + 2]}'));
      i += 3;
      continue;
    }

    if (b == 0x0A) {
      flushText();
      out.add(EscPosEvent('newline', ''));
      i += 1;
      continue;
    }

    text.add(b);
    i++;
  }
  flushText();
  return out;
}

/// Чек, каким его увидел бы глаз на бумаге.
///
/// Команды показываются в квадратных скобках, текст — как есть. Показывать
/// только текст было бы удобнее и **хуже**: рез, открытие ящика и смена
/// кодовой страницы — как раз то, из-за чего чек выходит не таким.
String renderReceipt(List<int> bytes, {int width = 42}) {
  final events = parseEscPos(bytes);
  final buffer = StringBuffer();
  final line = StringBuffer();

  void endLine() {
    buffer.writeln(line.toString());
    line.clear();
  }

  buffer.writeln('┌${'─' * width}┐');
  for (final e in events) {
    switch (e.kind) {
      case 'text':
        line.write(e.text);
      case 'newline':
        endLine();
      case 'qr':
        if (line.isNotEmpty) endLine();
        buffer.writeln('[QR] ${e.text}');
      default:
        if (line.isNotEmpty) endLine();
        buffer.writeln('[${e.kind}] ${e.text}');
    }
  }
  if (line.isNotEmpty) endLine();
  buffer.writeln('└${'─' * width}┘');
  return buffer.toString();
}

String _codePageFor(int n) => switch (n) {
  0 => 'CP437',
  17 => 'CP866',
  16 => 'CP1252',
  46 => 'CP1251',
  255 => 'UTF-8',
  _ => 'кодовая страница $n',
};

/// Декодирование текста чека.
///
/// **Не `String.fromCharCodes`.** Продукт шлёт CP866, и разборщик, читающий
/// его как latin1, покажет крокозябры на исправном чеке — то есть покрасит
/// живую проверку на верном коде. Это ровно тот класс ошибки, который
/// эмулятор WebKassa уже ловил у себя (сложение `double` из `jsonDecode`).
String _decode(List<int> bytes, String codePage) {
  switch (codePage) {
    case 'CP866':
      return decodePaper(bytes, PaperCharset.cp866);
    case 'UTF-8':
      return utf8.decode(bytes, allowMalformed: true);
    default:
      return String.fromCharCodes(bytes);
  }
}
