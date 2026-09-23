/// Разборщик потока принтера этикеток: ZPL, EPL и TSPL — три языка, которые
/// умеет наш `LabelPrinterService`.
///
/// Разбирается **то, что продукт действительно шлёт**, а не язык целиком:
/// команды сняты с `_buildZplTemplate` / `_buildEplTemplate` /
/// `_buildTsplTemplate`. Незнакомая команда показывается как незнакомая, а не
/// пропускается: разборщик, молча съедающий чужое, выглядит рабочим на любых
/// данных.
///
/// # Чего он НЕ доказывает
///
/// * **Что этикетка напечатана и встала по месту.** Растр не считается,
///   бумаги нет, калибровки зазора нет.
/// * **Что штрихкод читается сканером.** Строка вынимается из `^FD`, символы
///   контрольной цифры не проверяются.
/// * **Что размер в точках верен для этой модели.** `dpi` берётся из
///   настроек продукта, и модель с другим разрешением напечатает не то.
library;

import 'dart:convert';

import 'package:telepos/hardware/paper_charset.dart';

/// Одна разобранная команда этикеточного потока.
class LabelEvent {
  LabelEvent(this.kind, this.text);

  /// `start`, `end`, `size`, `text`, `barcode`, `copies`, `unknown`.
  final String kind;
  final String text;

  @override
  String toString() => '$kind: $text';
}

/// Поток этикетки как текст — **кодовой страницей, которую поток объявил**.
///
/// # Почему не UTF-8 всегда
///
/// Первая редакция разборщика декодировала UTF-8 любой поток и была
/// снисходительнее принтера: Zebra без `^CI28` читает байты в своей
/// однобайтовой странице (`^CI0`), TSC без `CODEPAGE UTF-8` — тоже, и
/// UTF-8-байты «Молоко» печатаются мусором. Продукт, приславший UTF-8 без
/// объявления, прошёл бы здесь зелёным и напечатал бы крокозябры на кассе.
///
/// * ZPL — UTF-8 только при `^CI28`, иначе latin1;
/// * TSPL — UTF-8 только при `CODEPAGE UTF-8`, иначе latin1;
/// * EPL — Windows-1251 только при `I8,C,…`, иначе latin1. UTF-8 у EPL2
///   нет вовсе.
String decodeLabelStream(List<int> bytes) {
  // Команды всех трёх языков — ASCII, и latin1 их читает без потерь.
  final raw = latin1.decode(bytes);
  if (raw.contains('^XA')) {
    return raw.contains('^CI28')
        ? utf8.decode(bytes, allowMalformed: true)
        : raw;
  }
  if (RegExp(r'^\s*SIZE\s', multiLine: true).hasMatch(raw)) {
    return RegExp(r'^\s*CODEPAGE\s+UTF-8\s*$', multiLine: true).hasMatch(raw)
        ? utf8.decode(bytes, allowMalformed: true)
        : raw;
  }
  return RegExp(r'^\s*I8,C,', multiLine: true).hasMatch(raw)
      ? _windows1251(bytes)
      : raw;
}

/// Windows-1251 → текст **той же таблицей, какой продукт кодирует**
/// (`hardware/paper_charset.dart`).
///
/// Своя таблица здесь была шестой в дереве и знала только А-я, Ё, ё и №:
/// «ёлочки» и `і`, которые страница содержит, она читала как `?`, то есть
/// объявляла дефектом верно напечатанную этикетку.
String _windows1251(List<int> bytes) =>
    decodePaper(bytes, PaperCharset.windows1251);

List<LabelEvent> parseLabels(List<int> bytes) {
  final source = decodeLabelStream(bytes);
  if (source.contains('^XA')) return _parseZpl(source);
  if (RegExp(r'^\s*SIZE\s', multiLine: true).hasMatch(source)) {
    return _parseTspl(source);
  }
  return _parseEpl(source);
}

List<LabelEvent> _parseZpl(String source) {
  final out = <LabelEvent>[];
  // ^FO x,y … ^FD значение ^FS — координаты запоминаются, чтобы значение
  // показывалось там же, где встанет на этикетке.
  String? pendingAt;
  var isBarcode = false;

  for (final raw in source.split(RegExp(r'\^'))) {
    final cmd = raw.trim();
    if (cmd.isEmpty) continue;
    if (cmd.startsWith('XA')) {
      out.add(LabelEvent('start', 'начало этикетки (ZPL)'));
    } else if (cmd.startsWith('XZ')) {
      out.add(LabelEvent('end', 'конец этикетки'));
    } else if (cmd.startsWith('PW')) {
      out.add(LabelEvent('size', 'ширина ${cmd.substring(2)} точек'));
    } else if (cmd.startsWith('LL')) {
      out.add(LabelEvent('size', 'высота ${cmd.substring(2)} точек'));
    } else if (cmd.startsWith('FO')) {
      pendingAt = cmd.substring(2);
    } else if (cmd.startsWith('BC') || cmd.startsWith('BY')) {
      isBarcode = true;
    } else if (cmd.startsWith('CF')) {
      out.add(LabelEvent('font', 'шрифт ${cmd.substring(2)}'));
    } else if (cmd.startsWith('CI')) {
      out.add(
        LabelEvent('codepage', 'кодовая страница ^CI${cmd.substring(2)}'),
      );
    } else if (cmd.startsWith('FD')) {
      final value = cmd.substring(2).replaceAll(RegExp(r'FS$'), '').trim();
      out.add(
        LabelEvent(
          isBarcode ? 'barcode' : 'text',
          pendingAt == null ? value : '($pendingAt) $value',
        ),
      );
      pendingAt = null;
      isBarcode = false;
    } else if (cmd.startsWith('PQ')) {
      out.add(LabelEvent('copies', '${cmd.substring(2)} экз.'));
    } else if (cmd.startsWith('FS')) {
      // Закрывающая — сама по себе ничего не значит.
    } else {
      out.add(LabelEvent('unknown', '^$cmd'));
    }
  }
  return out;
}

List<LabelEvent> _parseEpl(String source) {
  final out = <LabelEvent>[LabelEvent('start', 'начало этикетки (EPL)')];
  for (final line in source.split(RegExp(r'\r?\n'))) {
    final l = line.trim();
    if (l.isEmpty) continue;
    if (l == 'N') {
      out.add(LabelEvent('size', 'очистка буфера'));
    } else if (l.startsWith('I8,')) {
      out.add(LabelEvent('codepage', l));
    } else if (l.startsWith('A')) {
      out.add(LabelEvent('text', _quoted(l) ?? l));
    } else if (l.startsWith('B')) {
      out.add(LabelEvent('barcode', _quoted(l) ?? l));
    } else if (l.startsWith('P')) {
      out.add(LabelEvent('copies', '${l.substring(1)} экз.'));
    } else {
      out.add(LabelEvent('unknown', l));
    }
  }
  out.add(LabelEvent('end', 'конец этикетки'));
  return out;
}

List<LabelEvent> _parseTspl(String source) {
  final out = <LabelEvent>[LabelEvent('start', 'начало этикетки (TSPL)')];
  for (final line in source.split(RegExp(r'\r?\n'))) {
    final l = line.trim();
    if (l.isEmpty) continue;
    if (l.startsWith('SIZE')) {
      out.add(LabelEvent('size', l));
    } else if (l.startsWith('TEXT')) {
      out.add(LabelEvent('text', _quoted(l) ?? l));
    } else if (l.startsWith('BARCODE')) {
      out.add(LabelEvent('barcode', _quoted(l) ?? l));
    } else if (l.startsWith('PRINT')) {
      out.add(LabelEvent('copies', '${l.substring(5).trim()} экз.'));
    } else if (l == 'CLS' || l.startsWith('GAP')) {
      out.add(LabelEvent('size', l));
    } else if (l.startsWith('CODEPAGE')) {
      out.add(LabelEvent('codepage', l));
    } else {
      out.add(LabelEvent('unknown', l));
    }
  }
  out.add(LabelEvent('end', 'конец этикетки'));
  return out;
}

/// Последняя строка в кавычках — там, где эти три языка держат значение.
String? _quoted(String line) {
  final matches = RegExp(r'"([^"]*)"').allMatches(line).toList();
  if (matches.isEmpty) return null;
  return matches.last.group(1);
}

/// Этикетка, какой её увидел бы глаз.
String renderLabels(List<int> bytes) {
  final events = parseLabels(bytes);
  final buffer = StringBuffer()..writeln('┌── этикетка ──────────────────┐');
  for (final e in events) {
    buffer.writeln('  [${e.kind}] ${e.text}');
  }
  buffer.writeln('└──────────────────────────────┘');
  return buffer.toString();
}
