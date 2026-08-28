import 'dart:typed_data';

import 'package:decimal/decimal.dart';

import 'package:telepos/domain/usecases/fiscal/fiscal_requisites.dart';
import 'package:telepos/domain/usecases/fiscal/vat_calculator.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';
import 'package:telepos/hardware/printer/printer_profiles.dart';
import 'package:telepos/hardware/printer/receipt_templates.dart';

class ReceiptPrinter {
  ReceiptPrinter({
    required PrinterManager printer,
    PrinterProfile? profile,
    ReceiptSettings? settings,
  }) : _printer = printer,
       _profile = profile ?? PrinterProfiles.generic58mm,
       _settings = settings ?? const ReceiptSettings();

  final PrinterManager _printer;
  final PrinterProfile _profile;
  final ReceiptSettings _settings;

  int get charWidth => _profile.charsPerLine;

  bool get isWide => _profile.paperWidthMm >= 80;

  Future<PrintResult> printSale(SaleReceiptData data) async {
    final template = SaleReceiptTemplate(
      data: data,
      settings: _settings,
      charWidth: charWidth,
      isWide: isWide,
    );

    return _print(template.build());
  }

  Future<PrintResult> printRefund(RefundReceiptData data) async {
    final template = RefundReceiptTemplate(
      data: data,
      settings: _settings,
      charWidth: charWidth,
      isWide: isWide,
    );

    return _print(template.build());
  }

  Future<PrintResult> printShiftClosingSummary(ShiftClosingData data) async {
    final template = ShiftClosingTemplate(
      data: data,
      settings: _settings,
      charWidth: charWidth,
    );

    return _print(template.build());
  }

  Future<PrintResult> printXReport(ShiftClosingData data) async {
    final template = XReportTemplate(
      data: data,
      settings: _settings,
      charWidth: charWidth,
    );

    return _print(template.build());
  }

  Future<PrintResult> cashInOutPrint(CashOperationReceiptData data) async {
    final template = CashOperationTemplate(
      data: data,
      settings: _settings,
      charWidth: charWidth,
    );

    return _print(template.build());
  }

  Future<PrintResult> printDebtPayment(DebtPaymentReceiptData data) async {
    final template = DebtPaymentTemplate(
      data: data,
      settings: _settings,
      charWidth: charWidth,
    );

    return _print(template.build());
  }

  Future<void> openCash() async {
    if (_profile.supportsDrawer) {
      await _printer.openCashDrawer();
    }
  }

  Future<PrintResult> printTest({String? customText}) async {
    final template = TestReceiptTemplate(
      charWidth: charWidth,
      customText: customText,
    );

    return _print(template.build());
  }

  Future<PrintResult> _print(Uint8List data) async {
    if (!_printer.isConnected) {
      final result = await _printer.connect();
      if (!result.success) {
        return PrintResult.error(
          'Не удалось подключиться: ${result.errorMessage}',
        );
      }
    }

    final result = await _printer.printReceipt(data);

    if (_settings.autoCut && _profile.supportsCutter) {
      await _printer.cutPaper();
    }

    if (_settings.openDrawerOnSale && _profile.supportsDrawer) {
      await _printer.openCashDrawer();
    }

    return result;
  }
}

class ReceiptSettings {
  const ReceiptSettings({
    this.storeName = 'Магазин',
    this.storeAddress,
    this.storeBin,
    this.storePhone,
    this.footerText = 'Спасибо за покупку!',
    this.printLogo = false,
    this.printQrCode = true,
    this.printFiscalData = true,
    this.printVat = true,
    this.autoCut = true,
    this.openDrawerOnSale = false,
    this.feedLinesBefore = 0,
    this.feedLinesAfter = 3,
  });

  final String storeName;

  final String? storeAddress;

  final String? storeBin;

  final String? storePhone;

  final String footerText;

  final bool printLogo;

  final bool printQrCode;

  final bool printFiscalData;

  final bool printVat;

  final bool autoCut;

  final bool openDrawerOnSale;

  final int feedLinesBefore;

  final int feedLinesAfter;

  ReceiptSettings copyWith({
    String? storeName,
    String? storeAddress,
    String? storeBin,
    String? storePhone,
    String? footerText,
    bool? printLogo,
    bool? printQrCode,
    bool? printFiscalData,
    bool? printVat,
    bool? autoCut,
    bool? openDrawerOnSale,
    int? feedLinesBefore,
    int? feedLinesAfter,
  }) {
    return ReceiptSettings(
      storeName: storeName ?? this.storeName,
      storeAddress: storeAddress ?? this.storeAddress,
      storeBin: storeBin ?? this.storeBin,
      storePhone: storePhone ?? this.storePhone,
      footerText: footerText ?? this.footerText,
      printLogo: printLogo ?? this.printLogo,
      printQrCode: printQrCode ?? this.printQrCode,
      printFiscalData: printFiscalData ?? this.printFiscalData,
      printVat: printVat ?? this.printVat,
      autoCut: autoCut ?? this.autoCut,
      openDrawerOnSale: openDrawerOnSale ?? this.openDrawerOnSale,
      feedLinesBefore: feedLinesBefore ?? this.feedLinesBefore,
      feedLinesAfter: feedLinesAfter ?? this.feedLinesAfter,
    );
  }
}

class SaleReceiptData {
  const SaleReceiptData({
    required this.receiptNo,
    required this.posId,
    required this.dateTime,
    required this.cashierName,
    required this.items,
    required this.subtotal,
    this.discount,
    required this.total,
    this.cashAmount,
    this.cardAmount,
    this.change,
    this.customerName,
    this.customerPhone,
    this.fiscalRequisites,
    this.ticketUrl,
    this.tableName,
    this.zoneName,
    this.guestCount,
    this.waiterName,
    this.serviceChargeAmount,
  });

  final int receiptNo;
  final int posId;
  final DateTime dateTime;
  final String cashierName;
  final List<SaleItemData> items;
  final Decimal subtotal;
  final Decimal? discount;
  final Decimal total;
  final Decimal? cashAmount;
  final Decimal? cardAmount;
  final Decimal? change;
  final String? customerName;
  final String? customerPhone;
  final FiscalRequisites? fiscalRequisites;
  final String? ticketUrl;

  final String? tableName;
  final String? zoneName;
  final int? guestCount;
  final String? waiterName;
  final Decimal? serviceChargeAmount;

  Decimal get vatAmount => VatCalculator.extractVatFromGross(total);

  bool get hasFiscal => fiscalRequisites != null;
}

class SaleItemData {
  const SaleItemData({
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
    this.discount,
    this.barcode,
  });

  final String name;
  final Decimal quantity;
  final Decimal price;
  final Decimal total;
  final Decimal? discount;
  final String? barcode;
}

class RefundReceiptData {
  const RefundReceiptData({
    required this.refundNo,
    required this.originalReceiptNo,
    required this.dateTime,
    required this.cashierName,
    required this.items,
    required this.total,
    this.reason,
    this.customerName,
    this.fiscalRequisites,
  });

  final int refundNo;
  final int originalReceiptNo;
  final DateTime dateTime;
  final String cashierName;
  final List<SaleItemData> items;
  final Decimal total;
  final String? reason;
  final String? customerName;
  final FiscalRequisites? fiscalRequisites;
}

class ShiftClosingData {
  const ShiftClosingData({
    required this.shiftNo,
    required this.openTime,
    required this.closeTime,
    required this.cashierName,
    required this.salesCount,
    required this.salesCash,
    required this.salesCard,
    required this.salesTotal,
    required this.refundsCount,
    required this.refundsTotal,
    this.investmentsTotal,
    this.expensesTotal,
    required this.revenue,
    required this.cashInDrawer,
  });

  final int shiftNo;
  final DateTime openTime;
  final DateTime closeTime;
  final String cashierName;
  final int salesCount;
  final Decimal salesCash;
  final Decimal salesCard;
  final Decimal salesTotal;
  final int refundsCount;
  final Decimal refundsTotal;
  final Decimal? investmentsTotal;
  final Decimal? expensesTotal;
  final Decimal revenue;
  final Decimal cashInDrawer;
}

class CashOperationReceiptData {
  const CashOperationReceiptData({
    required this.operationType,
    required this.amount,
    required this.dateTime,
    required this.cashierName,
    this.description,
    this.expenseType,
  });

  final CashOperationType operationType;
  final Decimal amount;
  final DateTime dateTime;
  final String cashierName;
  final String? description;
  final String? expenseType;
}

enum CashOperationType {
  investment('Внесение'),
  expense('Выплата'),
  dividend('Инкассация');

  const CashOperationType(this.label);
  final String label;
}

class DebtPaymentReceiptData {
  const DebtPaymentReceiptData({
    required this.customerName,
    required this.amount,
    required this.dateTime,
    required this.cashierName,
    this.previousDebt,
    this.remainingDebt,
  });

  final String customerName;
  final Decimal amount;
  final DateTime dateTime;
  final String cashierName;
  final Decimal? previousDebt;
  final Decimal? remainingDebt;
}
