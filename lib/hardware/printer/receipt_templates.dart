import 'dart:typed_data';

import 'package:intl/intl.dart';

import 'package:telepos/domain/usecases/fiscal/vat_calculator.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';
import 'package:telepos/hardware/printer/receipt/receipt_builder.dart'
    show Cp866Encoder;
import 'package:telepos/hardware/printer/receipt_printer.dart';

abstract class ReceiptTemplate {
  ReceiptTemplate({required this.settings, required this.charWidth});

  final ReceiptSettings settings;
  final int charWidth;

  final List<int> buffer = [];

  static final DateFormat dateTimeFormat = DateFormat('dd.MM.yyyy HH:mm');
  static final DateFormat dateFormat = DateFormat('dd.MM.yyyy');
  static final DateFormat timeFormat = DateFormat('HH:mm:ss');

  Uint8List build();

  void addCommand(List<int> command) {
    buffer.addAll(command);
  }

  void addText(String text) {
    buffer.addAll(Cp866Encoder.encode(text));
  }

  void addLine(String text) {
    addText(text);
    addCommand(EscPosCommands.newLine);
  }

  void addCentered(String text) {
    addCommand(EscPosCommands.alignCenter);
    addLine(text);
    addCommand(EscPosCommands.alignLeft);
  }

  void addBold(String text) {
    addCommand(EscPosCommands.boldOn);
    addLine(text);
    addCommand(EscPosCommands.boldOff);
  }

  void addCenteredBold(String text) {
    addCommand(EscPosCommands.alignCenter);
    addCommand(EscPosCommands.boldOn);
    addLine(text);
    addCommand(EscPosCommands.boldOff);
    addCommand(EscPosCommands.alignLeft);
  }

  void addRow(String label, String value) {
    final spaces = charWidth - label.length - value.length;
    final padding = spaces > 0 ? ' ' * spaces : ' ';
    addLine('$label$padding$value');
  }

  void addDivider([String char = '-']) {
    addLine(char * charWidth);
  }

  void addEmptyLine() {
    addCommand(EscPosCommands.newLine);
  }

  void init() {
    addCommand(EscPosCommands.init);
  }

  void feedAndCut() {
    addCommand(EscPosCommands.feedLines(settings.feedLinesAfter));
    addCommand(EscPosCommands.cutPaper);
  }

  void addStoreHeader() {
    addCenteredBold(settings.storeName);

    if (settings.storeAddress != null) {
      addCentered(settings.storeAddress!);
    }

    if (settings.storeBin != null) {
      addCentered('БИН: ${settings.storeBin}');
    }

    if (settings.storePhone != null) {
      addCentered('Тел: ${settings.storePhone}');
    }
  }

  void addFooter() {
    addEmptyLine();
    addCentered(settings.footerText);
  }

  String formatAmount(dynamic amount) {
    if (amount == null) return '0.00';
    return amount.toStringAsFixed(2);
  }
}

class SaleReceiptTemplate extends ReceiptTemplate {
  SaleReceiptTemplate({
    required this.data,
    required super.settings,
    required super.charWidth,
    required this.isWide,
  });

  final SaleReceiptData data;
  final bool isWide;

  @override
  Uint8List build() {
    init();

    addStoreHeader();
    addEmptyLine();
    addDivider();

    addRow('Чек №:', '${data.receiptNo}');
    addRow('Касса:', '${data.posId}');
    addRow('Дата:', ReceiptTemplate.dateTimeFormat.format(data.dateTime));
    addRow('Кассир:', data.cashierName);

    if (data.tableName != null) {
      final tableInfo = data.zoneName != null
          ? '${data.tableName} (${data.zoneName})'
          : data.tableName!;
      addRow('Стол:', tableInfo);
    }
    if (data.waiterName != null) {
      addRow('Официант:', data.waiterName!);
    }
    if (data.guestCount != null) {
      addRow('Гостей:', '${data.guestCount}');
    }

    if (data.customerName != null) {
      addRow('Клиент:', data.customerName!);
    }

    addDivider();
    addEmptyLine();

    if (isWide) {
      _addItemsTable();
    } else {
      _addItemsList();
    }

    addEmptyLine();
    addDivider();

    if (data.discount != null && data.discount!.toDouble() > 0) {
      addRow('Подытог:', formatAmount(data.subtotal));
      addRow('Скидка:', '-${formatAmount(data.discount)}');
    }

    if (data.serviceChargeAmount != null &&
        data.serviceChargeAmount!.toDouble() > 0) {
      addRow('Сервис. сбор:', formatAmount(data.serviceChargeAmount));
    }

    addCommand(EscPosCommands.boldOn);
    addRow('ИТОГО:', formatAmount(data.total));
    addCommand(EscPosCommands.boldOff);

    if (settings.printVat) {
      addRow(
        'в т.ч. НДС ${VatCalculator.standardRatePercent}%:',
        formatAmount(data.vatAmount),
      );
    }

    addDivider();

    if (data.cashAmount != null && data.cashAmount!.toDouble() > 0) {
      addRow('Наличные:', formatAmount(data.cashAmount));
    }

    if (data.cardAmount != null && data.cardAmount!.toDouble() > 0) {
      addRow('Карта:', formatAmount(data.cardAmount));
    }

    if (data.change != null && data.change!.toDouble() > 0) {
      addRow('Сдача:', formatAmount(data.change));
    }

    if (settings.printFiscalData && data.hasFiscal) {
      addEmptyLine();
      addDivider();
      _addFiscalData();
    }

    if (settings.printQrCode && data.ticketUrl != null) {
      addEmptyLine();
      addCentered('Проверить чек:');
      addCentered(data.ticketUrl!);
    }

    addFooter();
    feedAndCut();

    return Uint8List.fromList(buffer);
  }

  void _addItemsTable() {
    final nameWidth = charWidth - 18;
    addLine('${'Наименование'.padRight(nameWidth)}Кол  Цена  Сумма');
    addDivider();

    for (final item in data.items) {
      final name = item.name.length > nameWidth
          ? item.name.substring(0, nameWidth)
          : item.name.padRight(nameWidth);
      final qty = item.quantity.toStringAsFixed(0).padLeft(3);
      final price = formatAmount(item.price).padLeft(7);
      final total = formatAmount(item.total).padLeft(6);
      addLine('$name$qty$price$total');

      if (item.discount != null && item.discount!.toDouble() > 0) {
        addLine('  Скидка: -${formatAmount(item.discount)}');
      }
    }
  }

  void _addItemsList() {
    for (final item in data.items) {
      addLine(item.name);
      final details =
          '${item.quantity} x ${formatAmount(item.price)} = ${formatAmount(item.total)}';
      addLine('  $details');

      if (item.discount != null && item.discount!.toDouble() > 0) {
        addLine('  Скидка: -${formatAmount(item.discount)}');
      }
    }
  }

  void _addFiscalData() {
    final fiscal = data.fiscalRequisites!;
    addCentered('БИН: ${fiscal.binOrg}');
    addCentered('ЗНК: ${fiscal.znk} РНК: ${fiscal.rnk}');
    addEmptyLine();
    addCenteredBold('ФН: ${fiscal.fiscalNo}');

    if (fiscal.fiscalSign != null) {
      addCentered('ФП: ${fiscal.fiscalSign}');
    }

    if (fiscal.isVatPayer) {
      addCentered('НДС: ${fiscal.ndsSerial} ${fiscal.ndsNumber}');
    }

    if (fiscal.offlineMode) {
      addCenteredBold('*** ОФФЛАЙН ***');
    }
  }
}

class RefundReceiptTemplate extends ReceiptTemplate {
  RefundReceiptTemplate({
    required this.data,
    required super.settings,
    required super.charWidth,
    required this.isWide,
  });

  final RefundReceiptData data;
  final bool isWide;

  @override
  Uint8List build() {
    init();

    addCenteredBold('*** ВОЗВРАТ ***');
    addEmptyLine();
    addStoreHeader();
    addEmptyLine();
    addDivider();

    addRow('Возврат №:', '${data.refundNo}');
    addRow('Чек №:', '${data.originalReceiptNo}');
    addRow('Дата:', ReceiptTemplate.dateTimeFormat.format(data.dateTime));
    addRow('Кассир:', data.cashierName);

    if (data.customerName != null) {
      addRow('Клиент:', data.customerName!);
    }

    if (data.reason != null) {
      addLine('Причина: ${data.reason}');
    }

    addDivider();
    addEmptyLine();

    for (final item in data.items) {
      addLine(item.name);
      addLine(
        '  ${item.quantity} x ${formatAmount(item.price)} = ${formatAmount(item.total)}',
      );
    }

    addEmptyLine();
    addDivider();

    addCommand(EscPosCommands.boldOn);
    addRow('К ВОЗВРАТУ:', formatAmount(data.total));
    addCommand(EscPosCommands.boldOff);

    if (settings.printFiscalData && data.fiscalRequisites != null) {
      addEmptyLine();
      addDivider();
      addCenteredBold('ФН: ${data.fiscalRequisites!.fiscalNo}');
    }

    addFooter();
    feedAndCut();

    return Uint8List.fromList(buffer);
  }
}

class ShiftClosingTemplate extends ReceiptTemplate {
  ShiftClosingTemplate({
    required this.data,
    required super.settings,
    required super.charWidth,
  });

  final ShiftClosingData data;

  @override
  Uint8List build() {
    init();

    addCenteredBold('Z-ОТЧЁТ');
    addCenteredBold('ЗАКРЫТИЕ СМЕНЫ');
    addEmptyLine();
    addCentered(settings.storeName);
    addEmptyLine();
    addDivider();

    addRow('Смена №:', '${data.shiftNo}');
    addRow('Открыта:', ReceiptTemplate.dateTimeFormat.format(data.openTime));
    addRow('Закрыта:', ReceiptTemplate.dateTimeFormat.format(data.closeTime));
    addRow('Кассир:', data.cashierName);

    addDivider();
    addEmptyLine();

    addBold('ПРОДАЖИ');
    addRow('Количество:', '${data.salesCount}');
    addRow('Наличные:', formatAmount(data.salesCash));
    addRow('Карта:', formatAmount(data.salesCard));
    addRow('Итого:', formatAmount(data.salesTotal));

    addEmptyLine();

    addBold('ВОЗВРАТЫ');
    addRow('Количество:', '${data.refundsCount}');
    addRow('Сумма:', formatAmount(data.refundsTotal));

    addEmptyLine();

    if (data.investmentsTotal != null || data.expensesTotal != null) {
      addBold('КАССОВЫЕ ОПЕРАЦИИ');
      if (data.investmentsTotal != null) {
        addRow('Внесения:', formatAmount(data.investmentsTotal));
      }
      if (data.expensesTotal != null) {
        addRow('Выплаты:', formatAmount(data.expensesTotal));
      }
      addEmptyLine();
    }

    addDivider();

    addCommand(EscPosCommands.boldOn);
    addRow('ВЫРУЧКА:', formatAmount(data.revenue));
    addRow('В КАССЕ:', formatAmount(data.cashInDrawer));
    addCommand(EscPosCommands.boldOff);

    addDivider();
    addCentered(ReceiptTemplate.dateTimeFormat.format(DateTime.now()));

    feedAndCut();

    return Uint8List.fromList(buffer);
  }
}

class XReportTemplate extends ReceiptTemplate {
  XReportTemplate({
    required this.data,
    required super.settings,
    required super.charWidth,
  });

  final ShiftClosingData data;

  @override
  Uint8List build() {
    init();

    addCenteredBold('X-ОТЧЁТ');
    addEmptyLine();
    addCentered(settings.storeName);
    addEmptyLine();
    addDivider();

    addRow('Смена №:', '${data.shiftNo}');
    addRow('Открыта:', ReceiptTemplate.dateTimeFormat.format(data.openTime));
    addRow('Кассир:', data.cashierName);

    addDivider();
    addEmptyLine();

    addBold('ПРОДАЖИ');
    addRow('Количество:', '${data.salesCount}');
    addRow('Наличные:', formatAmount(data.salesCash));
    addRow('Карта:', formatAmount(data.salesCard));
    addRow('Итого:', formatAmount(data.salesTotal));

    addEmptyLine();

    addBold('ВОЗВРАТЫ');
    addRow('Количество:', '${data.refundsCount}');
    addRow('Сумма:', formatAmount(data.refundsTotal));

    addEmptyLine();
    addDivider();

    addCommand(EscPosCommands.boldOn);
    addRow('В КАССЕ:', formatAmount(data.cashInDrawer));
    addCommand(EscPosCommands.boldOff);

    addDivider();
    addCentered(ReceiptTemplate.dateTimeFormat.format(DateTime.now()));

    feedAndCut();

    return Uint8List.fromList(buffer);
  }
}

class CashOperationTemplate extends ReceiptTemplate {
  CashOperationTemplate({
    required this.data,
    required super.settings,
    required super.charWidth,
  });

  final CashOperationReceiptData data;

  @override
  Uint8List build() {
    init();

    addCenteredBold(data.operationType.label.toUpperCase());
    addEmptyLine();
    addCentered(settings.storeName);
    addEmptyLine();
    addDivider();

    addRow('Дата:', ReceiptTemplate.dateTimeFormat.format(data.dateTime));
    addRow('Кассир:', data.cashierName);

    if (data.expenseType != null) {
      addRow('Тип:', data.expenseType!);
    }

    if (data.description != null) {
      addLine('Описание: ${data.description}');
    }

    addDivider();

    addCommand(EscPosCommands.boldOn);
    addCommand(EscPosCommands.sizeDoubleHeight);
    addRow('СУММА:', formatAmount(data.amount));
    addCommand(EscPosCommands.sizeNormal);
    addCommand(EscPosCommands.boldOff);

    addDivider();
    feedAndCut();

    return Uint8List.fromList(buffer);
  }
}

class DebtPaymentTemplate extends ReceiptTemplate {
  DebtPaymentTemplate({
    required this.data,
    required super.settings,
    required super.charWidth,
  });

  final DebtPaymentReceiptData data;

  @override
  Uint8List build() {
    init();

    addCenteredBold('ПОГАШЕНИЕ ДОЛГА');
    addEmptyLine();
    addCentered(settings.storeName);
    addEmptyLine();
    addDivider();

    addRow('Дата:', ReceiptTemplate.dateTimeFormat.format(data.dateTime));
    addRow('Кассир:', data.cashierName);
    addRow('Клиент:', data.customerName);

    addDivider();

    if (data.previousDebt != null) {
      addRow('Долг был:', formatAmount(data.previousDebt));
    }

    addCommand(EscPosCommands.boldOn);
    addRow('ОПЛАЧЕНО:', formatAmount(data.amount));
    addCommand(EscPosCommands.boldOff);

    if (data.remainingDebt != null) {
      addRow('Остаток:', formatAmount(data.remainingDebt));
    }

    addDivider();
    addFooter();
    feedAndCut();

    return Uint8List.fromList(buffer);
  }
}

class TestReceiptTemplate extends ReceiptTemplate {
  TestReceiptTemplate({required super.charWidth, this.customText})
    : super(settings: const ReceiptSettings());

  final String? customText;

  @override
  Uint8List build() {
    init();

    addCenteredBold('TEST PRINT');
    addDivider();

    addRow('Date:', ReceiptTemplate.dateTimeFormat.format(DateTime.now()));
    addRow('Width:', '$charWidth chars');

    addDivider();

    addLine('Тест кириллицы:');
    addLine('АБВГДЕЁЖЗИЙКЛМНОП');
    addLine('РСТУФХЦЧШЩЪЫЬЭЮЯ');
    addLine('абвгдеёжзийклмноп');
    addLine('рстуфхцчшщъыьэюя');

    addDivider();

    addCentered('Центр');
    addCommand(EscPosCommands.alignRight);
    addLine('Справа');
    addCommand(EscPosCommands.alignLeft);
    addLine('Слева');

    addDivider();

    addBold('Жирный текст');
    addCommand(EscPosCommands.sizeDoubleHeight);
    addLine('Крупный');
    addCommand(EscPosCommands.sizeNormal);

    if (customText != null) {
      addDivider();
      addLine(customText!);
    }

    addDivider();
    addCentered('TelePOS');
    feedAndCut();

    return Uint8List.fromList(buffer);
  }
}
