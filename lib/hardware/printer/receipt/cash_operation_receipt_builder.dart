import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:telepos/core/locale/till_language.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/domain/entities/cash_operation/cash_operation_receipt_data.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';
import 'package:telepos/hardware/paper_charset.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';
import 'package:telepos/hardware/printer/receipt/receipt_builder.dart';

class CashOperationReceiptBuilder implements ReceiptBuilder {
  CashOperationReceiptBuilder({required this.data, this.paperWidth = 48});

  final CashOperationReceiptData data;

  final int paperWidth;

  final _buffer = <int>[];

  @override
  Uint8List build() {
    _buffer.clear();

    _addCommand(EscPosCommands.init);

    _printHeader();

    _printReceiptNumber();

    _printSeparator();

    _printOperationType();

    _printDateTime();

    if (data.cashierName != null) {
      _printCashier();
    }

    _printSeparator();

    _printAmount();

    _printSeparator();

    if (data.note != null && data.note!.isNotEmpty) {
      _printNote();
    }

    _printFooter();

    _addCommand(EscPosCommands.feedLines(3));
    _addCommand(EscPosCommands.cutPaper);

    return Uint8List.fromList(_buffer);
  }

  @override
  String toDebugString() {
    final sb = StringBuffer();
    sb.writeln('=' * paperWidth);
    sb.writeln(_centerText(data.companyName));
    sb.writeln('=' * paperWidth);
    sb.writeln(_centerText('${_l10n.rcpSlipTitle} #${data.receiptNumber}'));
    sb.writeln('-' * paperWidth);
    sb.writeln('${_l10n.rcpType} ${_getTypeText(data.type)}');
    sb.writeln('${_l10n.rcpDate} ${_formatDateTime(data.docTime)}');
    if (data.cashierName != null) {
      sb.writeln('${_l10n.rcpCashier} ${data.cashierName}');
    }
    sb.writeln('-' * paperWidth);
    sb.writeln(_formatAmountLine());
    sb.writeln('-' * paperWidth);
    if (data.note != null && data.note!.isNotEmpty) {
      sb.writeln('${_l10n.rcpComment} ${data.note}');
    }
    sb.writeln('=' * paperWidth);
    return sb.toString();
  }

  void _printHeader() {
    _addCommand(EscPosCommands.alignCenter);
    _addCommand(EscPosCommands.boldOn);
    _printLine('=' * paperWidth);
    _printLine(data.companyName);
    _printLine('=' * paperWidth);
    _addCommand(EscPosCommands.boldOff);
  }

  void _printReceiptNumber() {
    _addCommand(EscPosCommands.alignCenter);
    _addCommand(EscPosCommands.sizeDoubleHeight);
    _printLine('${_l10n.rcpSlipTitle} #${data.receiptNumber}');
    _addCommand(EscPosCommands.sizeNormal);
  }

  void _printSeparator() {
    _addCommand(EscPosCommands.alignLeft);
    _printLine('-' * paperWidth);
  }

  void _printOperationType() {
    _addCommand(EscPosCommands.alignLeft);
    _printLine('${_l10n.rcpType} ${_getTypeText(data.type)}');
  }

  void _printDateTime() {
    _addCommand(EscPosCommands.alignLeft);
    _printLine('${_l10n.rcpDate} ${_formatDateTime(data.docTime)}');
  }

  void _printCashier() {
    _addCommand(EscPosCommands.alignLeft);
    _printLine('${_l10n.rcpCashier} ${data.cashierName}');
  }

  void _printAmount() {
    _addCommand(EscPosCommands.alignLeft);
    _addCommand(EscPosCommands.boldOn);
    _printLine(_formatAmountLine());
    _addCommand(EscPosCommands.boldOff);
  }

  void _printNote() {
    _addCommand(EscPosCommands.alignLeft);
    _printLine('${_l10n.rcpComment} ${data.note}');
  }

  void _printFooter() {
    _addCommand(EscPosCommands.alignCenter);
    _printLine('=' * paperWidth);
  }

  /// Текст, готовый к разметке: казахские буквы и `₸` уже заменены тем, что
  /// CP866 напечатает. Обоснование замен — `hardware/paper_charset.dart`.
  static String _paper(String text) => paperText(text, PaperCharset.cp866);

  void _printLine(String text) {
    _buffer.addAll(encodePaper(text, PaperCharset.cp866));
    _addCommand(EscPosCommands.newLine);
  }

  void _addCommand(List<int> command) {
    _buffer.addAll(command);
  }

  /// Словарь на языке кассы — это ПЕЧАТНЫЙ документ, его читает человек с
  /// бумаги. Все строки здесь были русскими литералами на любой кассе:
  /// «КВИТАНЦИЯ», «Тип:», «Кассир:», «Сумма:», «ВНЕСЕНИЕ». Сторож печатных
  /// документов их не видел — он собирает чек, X- и Z-отчёт, а квитанцию
  /// кассовой операции не собирал.
  AppLocalizations get _l10n =>
      lookupAppLocalizations(Locale(TillLanguage.current.languageCode));

  String _getTypeText(CashInOutType type) {
    switch (type) {
      case CashInOutType.investment:
        return _l10n.cashInvestment.toUpperCase();
      case CashInOutType.expense:
        return _l10n.cashExpense.toUpperCase();
      case CashInOutType.dividend:
        return _l10n.cashWithdrawal.toUpperCase();
    }
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y $h:$min';
  }

  /// Строка «Сумма: … 4 000.00 ₸» — **сначала замена знаков, потом отступ**.
  ///
  /// Знак тенге CP866 не содержит, и общая таблица бумаги заменяет его на
  /// «тг» — на знак длиннее. Считай отступ по исходной строке, и квитанция
  /// выйдет на колонку шире ленты: измерено пробой
  /// `receipt_paper_width_wire_test` — 33 колонки вместо 32 и 49 вместо 48.
  String _formatAmountLine() {
    final label = _l10n.rcpAmount;
    final amount = _formatAmount(data.amount);
    final value = _paper('$amount ${data.currencySymbol}');
    final padding = paperWidth - label.length - value.length;
    return '$label${' ' * (padding > 0 ? padding : 1)}$value';
  }

  String _formatAmount(Decimal amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    final buffer = StringBuffer();
    var count = 0;
    for (var i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(intPart[i]);
      count++;
    }
    final formattedInt = buffer.toString().split('').reversed.join();
    return '$formattedInt.$decPart';
  }

  String _centerText(String text) {
    if (text.length >= paperWidth) return text;
    final padding = (paperWidth - text.length) ~/ 2;
    return ' ' * padding + text;
  }
}
