import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:telepos/domain/entities/cash_operation/cash_operation_receipt_data.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';
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
    sb.writeln(_centerText('КВИТАНЦИЯ #${data.receiptNumber}'));
    sb.writeln('-' * paperWidth);
    sb.writeln('Тип: ${_getTypeText(data.type)}');
    sb.writeln('Дата: ${_formatDateTime(data.docTime)}');
    if (data.cashierName != null) {
      sb.writeln('Кассир: ${data.cashierName}');
    }
    sb.writeln('-' * paperWidth);
    sb.writeln(_formatAmountLine());
    sb.writeln('-' * paperWidth);
    if (data.note != null && data.note!.isNotEmpty) {
      sb.writeln('Комментарий: ${data.note}');
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
    _printLine('КВИТАНЦИЯ #${data.receiptNumber}');
    _addCommand(EscPosCommands.sizeNormal);
  }

  void _printSeparator() {
    _addCommand(EscPosCommands.alignLeft);
    _printLine('-' * paperWidth);
  }

  void _printOperationType() {
    _addCommand(EscPosCommands.alignLeft);
    _printLine('Тип: ${_getTypeText(data.type)}');
  }

  void _printDateTime() {
    _addCommand(EscPosCommands.alignLeft);
    _printLine('Дата: ${_formatDateTime(data.docTime)}');
  }

  void _printCashier() {
    _addCommand(EscPosCommands.alignLeft);
    _printLine('Кассир: ${data.cashierName}');
  }

  void _printAmount() {
    _addCommand(EscPosCommands.alignLeft);
    _addCommand(EscPosCommands.boldOn);
    _printLine(_formatAmountLine());
    _addCommand(EscPosCommands.boldOff);
  }

  void _printNote() {
    _addCommand(EscPosCommands.alignLeft);
    _printLine('Комментарий: ${data.note}');
  }

  void _printFooter() {
    _addCommand(EscPosCommands.alignCenter);
    _printLine('=' * paperWidth);
  }

  void _printLine(String text) {
    _buffer.addAll(Cp866Encoder.encode(text));
    _addCommand(EscPosCommands.newLine);
  }

  void _addCommand(List<int> command) {
    _buffer.addAll(command);
  }

  String _getTypeText(CashInOutType type) {
    switch (type) {
      case CashInOutType.investment:
        return 'ВНЕСЕНИЕ';
      case CashInOutType.expense:
        return 'РАСХОД';
      case CashInOutType.dividend:
        return 'ИЗЪЯТИЕ';
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

  String _formatAmountLine() {
    final label = 'Сумма:';
    final amount = _formatAmount(data.amount);
    final value = '$amount ${data.currencySymbol}';
    final padding = paperWidth - label.length - value.length;
    return '$label${' ' * padding}$value';
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
