import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:telepos/hardware/printer/canvas/receipt_canvas.dart';
import 'package:telepos/hardware/printer/canvas/table_renderer.dart';
import 'package:telepos/hardware/printer/printer_profiles.dart';

class CanvasPrinter {
  CanvasPrinter({PrinterProfile? profile, this.dpi = 203})
    : profile = profile ?? PrinterProfiles.generic58mm;

  final PrinterProfile profile;

  final int dpi;

  double get widthPx => profile.printWidthPx.toDouble();

  TextStyle get defaultTextStyle => TextStyle(
    fontFamily: 'Roboto',
    fontSize: 7.0 * 1.2 * (dpi / 72),
    color: Colors.black,
    height: 1.2,
  );

  TextStyle get headerStyle => defaultTextStyle.copyWith(
    fontSize: 10.0 * 1.2 * (dpi / 72),
    fontWeight: FontWeight.bold,
  );

  TextStyle get boldStyle =>
      defaultTextStyle.copyWith(fontWeight: FontWeight.bold);

  ReceiptCanvas createCanvas() {
    return ReceiptCanvas(width: widthPx, padding: const EdgeInsets.all(4));
  }

  ReceiptCanvasBuilder createBuilder() {
    return ReceiptCanvasBuilder(
      width: widthPx,
      padding: const EdgeInsets.all(4),
    );
  }

  Future<Uint8List> renderSaleReceipt(SaleReceiptData data) async {
    final builder = createBuilder()
      ..header(data.storeName)
      ..space(2);

    if (data.storeAddress != null) {
      builder.center(data.storeAddress!);
    }

    if (data.storeBin != null) {
      builder.center('БИН: ${data.storeBin}');
    }

    builder
      ..space(4)
      ..divider()
      ..space(2)
      ..row('Чек №:', '${data.receiptNo}')
      ..row('Дата:', data.dateTime)
      ..row('Кассир:', data.cashierName);

    if (data.tableName != null) {
      final tableInfo = data.zoneName != null
          ? '${data.tableName} (${data.zoneName})'
          : data.tableName!;
      builder.row('Стол:', tableInfo);
    }
    if (data.waiterName != null) {
      builder.row('Официант:', data.waiterName!);
    }
    if (data.guestCount != null) {
      builder.row('Гостей:', '${data.guestCount}');
    }

    builder
      ..space(2)
      ..divider()
      ..space(4);

    for (final item in data.items) {
      builder
        ..text(item.name)
        ..row('${item.quantity} x ${item.price}', item.total);

      if (item.discount != null && item.discount!.isNotEmpty) {
        builder.text('  Скидка: ${item.discount}');
      }
    }

    builder
      ..space(4)
      ..divider()
      ..space(2);

    if (data.subtotal != null) {
      builder.row('Подытог:', data.subtotal!);
    }

    if (data.discount != null) {
      builder.row('Скидка:', data.discount!);
    }

    if (data.serviceCharge != null && data.serviceCharge!.isNotEmpty) {
      builder.row('Сервис. сбор:', data.serviceCharge!);
    }

    builder
      ..bold('ИТОГО: ${data.total}', align: TextAlign.right)
      ..space(4)
      ..divider()
      ..space(2);

    if (data.cashAmount != null) {
      builder.row('Наличные:', data.cashAmount!);
    }

    if (data.cardAmount != null) {
      builder.row('Карта:', data.cardAmount!);
    }

    if (data.change != null) {
      builder.row('Сдача:', data.change!);
    }

    if (data.fiscalNo != null) {
      builder
        ..space(4)
        ..divider()
        ..space(2)
        ..center('ФН: ${data.fiscalNo}');

      if (data.fiscalSign != null) {
        builder.center('ФП: ${data.fiscalSign}');
      }
    }

    builder
      ..space(8)
      ..center('Спасибо за покупку!')
      ..space(4);

    return builder.renderToPng();
  }

  Future<Uint8List> renderItemsTable(List<SaleItemData> items) async {
    final canvas = createCanvas();

    final table = TableBuilder()
        .column('Наименование', flex: 3)
        .column('Кол-во', flex: 1, align: TextAlign.center)
        .column('Цена', flex: 1, align: TextAlign.right)
        .column('Сумма', flex: 1, align: TextAlign.right)
        .header(['Наименование', 'Кол-во', 'Цена', 'Сумма'])
        .rows(items.map((i) => [i.name, i.quantity, i.price, i.total]).toList())
        .border(TableBorderStyle.full)
        .alternateColor(Colors.grey.shade100)
        .build();

    canvas.add(table);

    return canvas.renderToPng();
  }

  Future<Uint8List> renderXReport(ShiftReportData data) async {
    final builder = createBuilder()
      ..header('X-ОТЧЁТ')
      ..space(4)
      ..center(data.storeName)
      ..space(2)
      ..row('Смена №:', '${data.shiftNo}')
      ..row('Открыта:', data.openTime)
      ..row('Кассир:', data.cashierName)
      ..space(4)
      ..divider()
      ..space(4)
      ..bold('ПРОДАЖИ')
      ..row('Количество:', '${data.salesCount}')
      ..row('Наличные:', data.cashSales)
      ..row('Карта:', data.cardSales)
      ..row('Итого:', data.totalSales)
      ..space(4)
      ..bold('ВОЗВРАТЫ')
      ..row('Количество:', '${data.refundsCount}')
      ..row('Сумма:', data.totalRefunds)
      ..space(4)
      ..divider()
      ..space(2)
      ..bold('В КАССЕ: ${data.cashInDrawer}')
      ..space(4)
      ..center(data.dateTime)
      ..space(4);

    return builder.renderToPng();
  }

  Future<Uint8List> renderZReport(ShiftReportData data) async {
    final builder = createBuilder()
      ..header('Z-ОТЧЁТ')
      ..header('ЗАКРЫТИЕ СМЕНЫ')
      ..space(4)
      ..center(data.storeName)
      ..space(2)
      ..row('Смена №:', '${data.shiftNo}')
      ..row('Открыта:', data.openTime)
      ..row('Закрыта:', data.closeTime ?? data.dateTime)
      ..row('Кассир:', data.cashierName)
      ..space(4)
      ..divider()
      ..space(4)
      ..bold('ПРОДАЖИ')
      ..row('Количество:', '${data.salesCount}')
      ..row('Наличные:', data.cashSales)
      ..row('Карта:', data.cardSales)
      ..row('Итого:', data.totalSales)
      ..space(4)
      ..bold('ВОЗВРАТЫ')
      ..row('Количество:', '${data.refundsCount}')
      ..row('Сумма:', data.totalRefunds)
      ..space(4)
      ..bold('КАССОВЫЕ ОПЕРАЦИИ')
      ..row('Внесения:', data.investments ?? '0.00')
      ..row('Выплаты:', data.expenses ?? '0.00')
      ..space(4)
      ..divider()
      ..space(2)
      ..bold('ВЫРУЧКА: ${data.revenue}')
      ..bold('В КАССЕ: ${data.cashInDrawer}')
      ..space(4)
      ..divider()
      ..center(data.dateTime)
      ..space(4);

    return builder.renderToPng();
  }

  Future<Uint8List> imageToEscPosBitmap(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw Exception('Failed to get image byte data');
    }

    final pixels = byteData.buffer.asUint8List();
    final width = image.width;
    final height = image.height;

    final bytesPerRow = (width + 7) ~/ 8;
    final bitmapData = Uint8List(bytesPerRow * height);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixelIndex = (y * width + x) * 4;
        final r = pixels[pixelIndex];
        final g = pixels[pixelIndex + 1];
        final b = pixels[pixelIndex + 2];

        final gray = (r * 0.299 + g * 0.587 + b * 0.114).round();
        final isBlack = gray < 128;

        if (isBlack) {
          final byteIndex = y * bytesPerRow + (x ~/ 8);
          final bitIndex = 7 - (x % 8);
          bitmapData[byteIndex] |= (1 << bitIndex);
        }
      }
    }

    final escPosData = <int>[];

    escPosData.addAll([0x1D, 0x76, 0x30, 0x00]);
    escPosData.addAll([
      bytesPerRow & 0xFF,
      (bytesPerRow >> 8) & 0xFF,
      height & 0xFF,
      (height >> 8) & 0xFF,
    ]);
    escPosData.addAll(bitmapData);

    return Uint8List.fromList(escPosData);
  }
}

class SaleReceiptData {
  const SaleReceiptData({
    required this.storeName,
    this.storeAddress,
    this.storeBin,
    required this.receiptNo,
    required this.dateTime,
    required this.cashierName,
    required this.items,
    this.subtotal,
    this.discount,
    required this.total,
    this.cashAmount,
    this.cardAmount,
    this.change,
    this.fiscalNo,
    this.fiscalSign,
    this.tableName,
    this.zoneName,
    this.guestCount,
    this.waiterName,
    this.serviceCharge,
  });

  final String storeName;
  final String? storeAddress;
  final String? storeBin;
  final int receiptNo;
  final String dateTime;
  final String cashierName;
  final List<SaleItemData> items;
  final String? subtotal;
  final String? discount;
  final String total;
  final String? cashAmount;
  final String? cardAmount;
  final String? change;
  final String? fiscalNo;
  final String? fiscalSign;

  final String? tableName;
  final String? zoneName;
  final int? guestCount;
  final String? waiterName;
  final String? serviceCharge;
}

class SaleItemData {
  const SaleItemData({
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
    this.discount,
  });

  final String name;
  final String quantity;
  final String price;
  final String total;
  final String? discount;
}

class ShiftReportData {
  const ShiftReportData({
    required this.storeName,
    required this.shiftNo,
    required this.openTime,
    this.closeTime,
    required this.cashierName,
    required this.dateTime,
    required this.salesCount,
    required this.cashSales,
    required this.cardSales,
    required this.totalSales,
    required this.refundsCount,
    required this.totalRefunds,
    this.investments,
    this.expenses,
    required this.revenue,
    required this.cashInDrawer,
  });

  final String storeName;
  final int shiftNo;
  final String openTime;
  final String? closeTime;
  final String cashierName;
  final String dateTime;
  final int salesCount;
  final String cashSales;
  final String cardSales;
  final String totalSales;
  final int refundsCount;
  final String totalRefunds;
  final String? investments;
  final String? expenses;
  final String revenue;
  final String cashInDrawer;
}
