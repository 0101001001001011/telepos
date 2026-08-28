import 'package:flutter/material.dart';

import 'package:telepos/hardware/printer/canvas/drawing_actions.dart';

class TableRenderer extends DrawingAction {
  const TableRenderer({
    required this.columns,
    required this.rows,
    this.headerRow,
    this.borderStyle = TableBorderStyle.single,
    this.cellPadding = const EdgeInsets.all(2),
    this.headerStyle,
    this.cellStyle,
    this.alternateRowColor,
  });

  final List<TableColumn> columns;

  final List<List<String>> rows;

  final List<String>? headerRow;

  final TableBorderStyle borderStyle;

  final EdgeInsets cellPadding;

  final TextStyle? headerStyle;

  final TextStyle? cellStyle;

  final Color? alternateRowColor;

  static const TextStyle defaultHeaderStyle = TextStyle(
    fontFamily: 'Arial',
    fontSize: 8.4,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  static const TextStyle defaultCellStyle = TextStyle(
    fontFamily: 'Arial',
    fontSize: 8.4,
    color: Colors.black,
  );

  @override
  void draw(Canvas canvas, Rect bounds) {
    final columnWidths = _calculateColumnWidths(bounds.width);
    var currentY = bounds.top;

    if (borderStyle != TableBorderStyle.none) {
      _drawHorizontalBorder(canvas, bounds.left, bounds.right, currentY);
    }

    if (headerRow != null) {
      final headerHeight = _getRowHeight(
        headerRow!,
        columnWidths,
        headerStyle ?? defaultHeaderStyle,
      );
      _drawRow(
        canvas,
        bounds.left,
        currentY,
        columnWidths,
        headerRow!,
        headerStyle ?? defaultHeaderStyle,
        isHeader: true,
      );
      currentY += headerHeight;

      if (borderStyle != TableBorderStyle.none) {
        _drawHorizontalBorder(
          canvas,
          bounds.left,
          bounds.right,
          currentY,
          isHeaderBorder: true,
        );
      }
    }

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowHeight = _getRowHeight(
        row,
        columnWidths,
        cellStyle ?? defaultCellStyle,
      );

      if (alternateRowColor != null && i % 2 == 1) {
        final paint = Paint()
          ..color = alternateRowColor!
          ..style = PaintingStyle.fill;
        canvas.drawRect(
          Rect.fromLTWH(bounds.left, currentY, bounds.width, rowHeight),
          paint,
        );
      }

      _drawRow(
        canvas,
        bounds.left,
        currentY,
        columnWidths,
        row,
        cellStyle ?? defaultCellStyle,
      );
      currentY += rowHeight;

      if (borderStyle == TableBorderStyle.full ||
          (borderStyle == TableBorderStyle.single && i == rows.length - 1)) {
        _drawHorizontalBorder(canvas, bounds.left, bounds.right, currentY);
      }
    }

    if (borderStyle != TableBorderStyle.none) {
      _drawVerticalBorders(
        canvas,
        bounds.left,
        bounds.top,
        currentY,
        columnWidths,
      );
    }
  }

  void _drawRow(
    Canvas canvas,
    double startX,
    double startY,
    List<double> columnWidths,
    List<String> cells,
    TextStyle style, {
    bool isHeader = false,
  }) {
    var currentX = startX;

    for (var i = 0; i < cells.length && i < columnWidths.length; i++) {
      final column = columns[i];
      final cellWidth = columnWidths[i];
      final cellText = cells[i];

      final cellBounds = Rect.fromLTWH(
        currentX + cellPadding.left,
        startY + cellPadding.top,
        cellWidth - cellPadding.horizontal,
        100,
      );

      DrawString(
        text: cellText,
        style: style,
        align: column.align,
      ).draw(canvas, cellBounds);

      currentX += cellWidth;
    }
  }

  void _drawHorizontalBorder(
    Canvas canvas,
    double startX,
    double endX,
    double y, {
    bool isHeaderBorder = false,
  }) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = isHeaderBorder ? 1.5 : 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
  }

  void _drawVerticalBorders(
    Canvas canvas,
    double startX,
    double startY,
    double endY,
    List<double> columnWidths,
  ) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    var currentX = startX;

    canvas.drawLine(Offset(currentX, startY), Offset(currentX, endY), paint);

    for (final width in columnWidths) {
      currentX += width;
      canvas.drawLine(Offset(currentX, startY), Offset(currentX, endY), paint);
    }
  }

  List<double> _calculateColumnWidths(double totalWidth) {
    final widths = <double>[];
    final totalFlex = columns.fold<int>(0, (sum, col) => sum + col.flex);

    var remainingWidth = totalWidth;
    var remainingFlex = totalFlex;

    for (final column in columns) {
      if (column.width != null) {
        widths.add(column.width!);
        remainingWidth -= column.width!;
        remainingFlex -= column.flex;
      } else {
        widths.add(0);
      }
    }

    for (var i = 0; i < columns.length; i++) {
      if (columns[i].width == null) {
        final flex = columns[i].flex;
        widths[i] = remainingWidth * flex / remainingFlex;
      }
    }

    return widths;
  }

  double _getRowHeight(
    List<String> cells,
    List<double> columnWidths,
    TextStyle style,
  ) {
    var maxHeight = 0.0;

    for (var i = 0; i < cells.length && i < columnWidths.length; i++) {
      final cellWidth = columnWidths[i] - cellPadding.horizontal;
      final cellHeight = DrawString(
        text: cells[i],
        style: style,
      ).getHeight(cellWidth);

      if (cellHeight > maxHeight) {
        maxHeight = cellHeight;
      }
    }

    return maxHeight + cellPadding.vertical;
  }

  @override
  double getHeight(double width) {
    final columnWidths = _calculateColumnWidths(width);
    var totalHeight = 0.0;

    if (headerRow != null) {
      totalHeight += _getRowHeight(
        headerRow!,
        columnWidths,
        headerStyle ?? defaultHeaderStyle,
      );
    }

    for (final row in rows) {
      totalHeight += _getRowHeight(
        row,
        columnWidths,
        cellStyle ?? defaultCellStyle,
      );
    }

    if (borderStyle != TableBorderStyle.none) {
      totalHeight += 2;
    }

    return totalHeight;
  }
}

class TableColumn {
  const TableColumn({
    required this.title,
    this.width,
    this.flex = 1,
    this.align = TextAlign.left,
  });

  final String title;

  final double? width;

  final int flex;

  final TextAlign align;
}

enum TableBorderStyle { none, single, full, horizontal }

class TableBuilder {
  final List<TableColumn> _columns = [];
  final List<List<String>> _rows = [];
  List<String>? _headerRow;
  TableBorderStyle _borderStyle = TableBorderStyle.single;
  EdgeInsets _cellPadding = const EdgeInsets.all(2);
  TextStyle? _headerStyle;
  TextStyle? _cellStyle;
  Color? _alternateRowColor;

  TableBuilder column(
    String title, {
    double? width,
    int flex = 1,
    TextAlign align = TextAlign.left,
  }) {
    _columns.add(
      TableColumn(title: title, width: width, flex: flex, align: align),
    );
    return this;
  }

  TableBuilder header(List<String> headerRow) {
    _headerRow = headerRow;
    return this;
  }

  TableBuilder row(List<String> cells) {
    _rows.add(cells);
    return this;
  }

  TableBuilder rows(List<List<String>> rows) {
    _rows.addAll(rows);
    return this;
  }

  TableBuilder border(TableBorderStyle style) {
    _borderStyle = style;
    return this;
  }

  TableBuilder padding(EdgeInsets padding) {
    _cellPadding = padding;
    return this;
  }

  TableBuilder headerStyle(TextStyle style) {
    _headerStyle = style;
    return this;
  }

  TableBuilder cellStyle(TextStyle style) {
    _cellStyle = style;
    return this;
  }

  TableBuilder alternateColor(Color color) {
    _alternateRowColor = color;
    return this;
  }

  TableRenderer build() {
    return TableRenderer(
      columns: _columns,
      rows: _rows,
      headerRow: _headerRow,
      borderStyle: _borderStyle,
      cellPadding: _cellPadding,
      headerStyle: _headerStyle,
      cellStyle: _cellStyle,
      alternateRowColor: _alternateRowColor,
    );
  }
}
