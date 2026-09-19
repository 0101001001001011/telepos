import 'dart:typed_data';

import 'package:telepos/domain/entities/receipt/receipt_text_block.dart';
import 'package:telepos/hardware/paper_charset.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';
import 'package:telepos/hardware/printer/receipt_text_wrap.dart';

/// Поток ESC/POS одного чека.
///
/// ## Знаки на ленте
///
/// Страница одна и объявлена самим потоком: `EscPosCommands.init` шлёт
/// `ESC t 17` (CP866), и байты собираются той же таблицей
/// (`hardware/paper_charset.dart`), которой их читают предпросмотр и эмулятор.
/// Выбора кодировки у вызывающего **нет**, и это правка, а не упущение: поле
/// `encoding` принимало `'utf8'`, но `init` всё равно переключал принтер на
/// CP866 — «выбранная» UTF-8 напечаталась бы крокозябрами. Ни один вызывающий
/// его не задавал (измерено: ни одного `encoding:` в `lib/` и `test/`).
///
/// **Замены знаков делаются на входе каждого метода, до измерения строки.**
/// Ширина колонок считается по `String.length` ([_truncate], [addRow],
/// перенос по словам), а замена бывает длиннее знака (`₸` → `тг`). Сделай её
/// внутри кодировщика — и колонка суммы уехала бы вправо молча.
class ReceiptBuilder {
  /// [charWidth] обязателен: умолчание `32` здесь было четвёртым местом,
  /// помнившим ширину ленты, и X/Z-отчёты печатались узкими при любом выборе.
  /// Ширину даёт `ReceiptPaperWidthSource`.
  ReceiptBuilder({required this.charWidth});

  final int charWidth;

  final List<int> _buffer = [];

  /// Текст, готовый к разметке: казахские буквы, `₸`, «ёлочки» и длинные тире
  /// уже заменены тем, что CP866 умеет напечатать.
  static String _paper(String text) => paperText(text, PaperCharset.cp866);

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

    _addText(_truncate(_paper(text), charWidth));
    _buffer.addAll(EscPosCommands.newLine);

    if (doubleSize) _buffer.addAll(EscPosCommands.sizeNormal);
    if (bold) _buffer.addAll(EscPosCommands.boldOff);
    _buffer.addAll(EscPosCommands.alignLeft);

    return this;
  }

  /// По центру, **с переносом по словам** вместо обрезки.
  ///
  /// Для обязательных строк, длина которых не зависит от кассы: название
  /// продавца, адрес, ссылка проверки чека. Ссылка `consumer.oofd.kz` длиннее
  /// 32 колонок, и до этой правки на ленте 58 мм она печаталась обрезанной —
  /// покупатель переписывал с чека неработающий адрес.
  ReceiptBuilder addCenteredWrapped(String text, {bool bold = false}) {
    _buffer.addAll(EscPosCommands.alignCenter);
    if (bold) _buffer.addAll(EscPosCommands.boldOn);
    for (final piece in wrapReceiptLine(_paper(text), charWidth)) {
      _addText(piece);
      _buffer.addAll(EscPosCommands.newLine);
    }
    if (bold) _buffer.addAll(EscPosCommands.boldOff);
    _buffer.addAll(EscPosCommands.alignLeft);
    return this;
  }

  /// Блок свободного текста шаблона — шапка или подвал.
  ///
  /// * Пустой блок не даёт **ни одного** байта: ни пустой строки, ни команды.
  /// * Каждая строка переносится по словам под ширину ленты; при двойном
  ///   размере колонок вдвое меньше.
  /// * Оформление блока снимается **безусловно** после последней строки —
  ///   обычный размер, жирный выключен, выравнивание влево, — чтобы следующая
  ///   за блоком обязательная строка не унаследовала ни крупный шрифт, ни
  ///   правый край.
  ReceiptBuilder addTextBlock(ReceiptTextBlock block) {
    final lines = block.lines;
    if (lines.isEmpty) return this;

    final columns = block.doubleSize ? charWidth ~/ 2 : charWidth;
    _buffer.addAll(switch (block.align) {
      ReceiptTextAlign.left => EscPosCommands.alignLeft,
      ReceiptTextAlign.center => EscPosCommands.alignCenter,
      ReceiptTextAlign.right => EscPosCommands.alignRight,
    });
    if (block.bold) _buffer.addAll(EscPosCommands.boldOn);
    if (block.doubleSize) _buffer.addAll(EscPosCommands.sizeDouble);

    for (final line in lines) {
      for (final piece in wrapReceiptLine(_paper(line), columns)) {
        _addText(piece);
        _buffer.addAll(EscPosCommands.newLine);
      }
    }

    _buffer
      ..addAll(EscPosCommands.sizeNormal)
      ..addAll(EscPosCommands.boldOff)
      ..addAll(EscPosCommands.alignLeft);
    return this;
  }

  ReceiptBuilder addLeft(String text, {bool bold = false}) {
    _buffer.addAll(EscPosCommands.alignLeft);
    if (bold) _buffer.addAll(EscPosCommands.boldOn);

    _addText(_truncate(_paper(text), charWidth));
    _buffer.addAll(EscPosCommands.newLine);

    if (bold) _buffer.addAll(EscPosCommands.boldOff);

    return this;
  }

  ReceiptBuilder addRight(String text, {bool bold = false}) {
    _buffer.addAll(EscPosCommands.alignRight);
    if (bold) _buffer.addAll(EscPosCommands.boldOn);

    _addText(_truncate(_paper(text), charWidth));
    _buffer.addAll(EscPosCommands.newLine);

    if (bold) _buffer.addAll(EscPosCommands.boldOff);
    _buffer.addAll(EscPosCommands.alignLeft);

    return this;
  }

  ReceiptBuilder addRow(String rawLeft, String rawRight, {bool bold = false}) {
    if (bold) _buffer.addAll(EscPosCommands.boldOn);

    final left = _paper(rawLeft);
    final right = _paper(rawRight);
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
    String rawLeft,
    String rawCenter,
    String rawRight, {
    bool bold = false,
  }) {
    if (bold) _buffer.addAll(EscPosCommands.boldOn);

    final left = _paper(rawLeft);
    final center = _paper(rawCenter);
    final right = _paper(rawRight);
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
    _addText(_paper(char) * charWidth);
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

  /// Кладёт **уже размеченный** текст в поток.
  ///
  /// Замены здесь уже сделаны методами-входами; [encodePaper] повторит их
  /// вхолостую (они идемпотентны) и останется только таблица.
  void _addText(String text) {
    _buffer.addAll(encodePaper(text, PaperCharset.cp866));
  }

  String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return text.substring(0, maxLen);
  }
}
