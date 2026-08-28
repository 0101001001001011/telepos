import 'dart:typed_data';

import 'package:telepos/domain/usecases/fiscal/fiscal_requisites.dart';
import 'package:telepos/domain/usecases/fiscal/vat_calculator.dart';
import 'package:telepos/hardware/printer/receipt/receipt_builder.dart';

class FiscalReceiptSectionBuilder {
  FiscalReceiptSectionBuilder({required this.requisites, this.charWidth = 32});

  final FiscalRequisites requisites;

  final int charWidth;

  final List<int> _buffer = [];

  Uint8List build() {
    _buffer.clear();

    _addDivider();

    _addLine(requisites.formattedBin);

    if (requisites.taxpayerName != null) {
      _addLine(requisites.taxpayerName!);
    }

    if (requisites.address != null) {
      _addLine(requisites.address!);
    }

    _addLine(requisites.formattedKkmInfo);

    if (requisites.kgdKkm != null) {
      _addLine('ККМ КГД: ${requisites.kgdKkm}');
    }

    _addLine('');

    _addCenteredBold('ФН: ${requisites.fiscalNo}');

    if (requisites.fiscalSign != null) {
      _addCenteredLine('ФП: ${requisites.fiscalSign}');
    }

    if (requisites.receiptDateTime != null) {
      final dt = requisites.receiptDateTime!;
      final formatted =
          '${_pad2(dt.day)}.${_pad2(dt.month)}.${dt.year} ${_pad2(dt.hour)}:${_pad2(dt.minute)}:${_pad2(dt.second)}';
      _addCenteredLine(formatted);
    }

    if (requisites.offlineMode) {
      _addLine('');
      _addCenteredBold('*** ОФФЛАЙН РЕЖИМ ***');
    }

    if (requisites.isVatPayer) {
      _addLine('');
      _addLine('Свидетельство НДС:');
      _addLine('${requisites.ndsSerial} ${requisites.ndsNumber}');

      if (requisites.vatAmount != null) {
        _addLine(VatCalculator.formatVatLine(requisites.vatAmount!));
      }
    }

    if (requisites.ofdName != null) {
      _addLine('');
      _addLine('OFD: ${requisites.ofdName}');
    }

    if (requisites.ticketUrl != null) {
      _addLine('');
      _addLine('Проверить чек:');
      _addLine(requisites.ticketUrl!);
    }

    _addDivider();

    return Uint8List.fromList(_buffer);
  }

  void _addDivider() {
    _addCommand(EscPosCommands.alignLeft);
    final divider = '-' * charWidth;
    _addText(divider);
    _addCommand(EscPosCommands.newLine);
  }

  void _addLine(String text) {
    _addCommand(EscPosCommands.alignLeft);
    _addText(text);
    _addCommand(EscPosCommands.newLine);
  }

  void _addCenteredLine(String text) {
    _addCommand(EscPosCommands.alignCenter);
    _addText(text);
    _addCommand(EscPosCommands.newLine);
    _addCommand(EscPosCommands.alignLeft);
  }

  void _addCenteredBold(String text) {
    _addCommand(EscPosCommands.alignCenter);
    _addCommand(EscPosCommands.boldOn);
    _addText(text);
    _addCommand(EscPosCommands.boldOff);
    _addCommand(EscPosCommands.newLine);
    _addCommand(EscPosCommands.alignLeft);
  }

  void _addCommand(List<int> command) {
    _buffer.addAll(command);
  }

  void _addText(String text) {
    _buffer.addAll(Cp866Encoder.encode(text));
  }

  String _pad2(int value) => value.toString().padLeft(2, '0');
}

class FiscalReceiptFormatter {
  FiscalReceiptFormatter._();

  static Uint8List format32(FiscalRequisites requisites) {
    return FiscalReceiptSectionBuilder(
      requisites: requisites,
      charWidth: 32,
    ).build();
  }

  static Uint8List format42(FiscalRequisites requisites) {
    return FiscalReceiptSectionBuilder(
      requisites: requisites,
      charWidth: 42,
    ).build();
  }

  static Uint8List format48(FiscalRequisites requisites) {
    return FiscalReceiptSectionBuilder(
      requisites: requisites,
      charWidth: 48,
    ).build();
  }

  static String formatItemVat(VatBreakdown breakdown) {
    return '[${breakdown.vatRatePercent}%: ${breakdown.vatAmount.toStringAsFixed(2)}]';
  }

  static String formatTotalVatLine(VatBreakdown breakdown, {int width = 32}) {
    final label = 'в т.ч. НДС ${breakdown.vatRatePercent}%:';
    final amount = breakdown.vatAmount.toStringAsFixed(2);
    final padding = width - label.length - amount.length;
    return '$label${' ' * (padding > 0 ? padding : 1)}$amount';
  }
}

class FiscalRequisitesValidation {
  const FiscalRequisitesValidation({
    required this.isValid,
    this.errors = const [],
  });

  final bool isValid;
  final List<String> errors;

  factory FiscalRequisitesValidation.validate(FiscalRequisites requisites) {
    final errors = <String>[];

    if (requisites.binOrg.length != 12) {
      errors.add('БИН должен содержать 12 цифр');
    }
    if (!RegExp(r'^\d{12}$').hasMatch(requisites.binOrg)) {
      errors.add('БИН должен содержать только цифры');
    }

    if (requisites.fiscalNo.isEmpty) {
      errors.add('Фискальный номер обязателен');
    }

    if (requisites.rnk.isEmpty) {
      errors.add('РНК обязателен');
    }

    if (requisites.znk.isEmpty) {
      errors.add('ЗНК обязателен');
    }

    if (requisites.isVatPayer) {
      if (requisites.ndsSerial!.isEmpty) {
        errors.add('Серия свидетельства НДС обязательна');
      }
      if (requisites.ndsNumber!.isEmpty) {
        errors.add('Номер свидетельства НДС обязателен');
      }
    }

    return FiscalRequisitesValidation(isValid: errors.isEmpty, errors: errors);
  }
}
