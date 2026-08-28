import 'dart:ui' as ui;

import 'package:flutter/material.dart';

abstract class DrawingAction {
  const DrawingAction();

  void draw(Canvas canvas, Rect bounds);

  double getHeight(double width);
}

class DrawString extends DrawingAction {
  const DrawString({
    required this.text,
    this.style,
    this.align = TextAlign.left,
    this.maxLines,
  });

  final String text;

  final TextStyle? style;

  final TextAlign align;

  final int? maxLines;

  static const TextStyle defaultStyle = TextStyle(
    fontFamily: 'Arial',
    fontSize: 7.0 * 1.2,
    color: Colors.black,
    height: 1.2,
  );

  @override
  void draw(Canvas canvas, Rect bounds) {
    final textStyle = style ?? defaultStyle;

    final textSpan = TextSpan(text: text, style: textStyle);

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    );

    textPainter.layout(minWidth: 0, maxWidth: bounds.width);

    final offset = Offset(
      _calculateXOffset(bounds, textPainter.width),
      bounds.top,
    );

    textPainter.paint(canvas, offset);
  }

  double _calculateXOffset(Rect bounds, double textWidth) {
    switch (align) {
      case TextAlign.left:
      case TextAlign.start:
        return bounds.left;
      case TextAlign.right:
      case TextAlign.end:
        return bounds.right - textWidth;
      case TextAlign.center:
        return bounds.left + (bounds.width - textWidth) / 2;
      case TextAlign.justify:
        return bounds.left;
    }
  }

  @override
  double getHeight(double width) {
    final textStyle = style ?? defaultStyle;

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    );

    textPainter.layout(minWidth: 0, maxWidth: width);
    return textPainter.height;
  }
}

class DrawLine extends DrawingAction {
  const DrawLine({
    this.thickness = 1.0,
    this.color = Colors.black,
    this.style = LineStyle.solid,
    this.padding = EdgeInsets.zero,
  });

  final double thickness;

  final Color color;

  final LineStyle style;

  final EdgeInsets padding;

  @override
  void draw(Canvas canvas, Rect bounds) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;

    final y = bounds.top + padding.top + thickness / 2;
    final startX = bounds.left + padding.left;
    final endX = bounds.right - padding.right;

    switch (style) {
      case LineStyle.solid:
        canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
      case LineStyle.dashed:
        _drawDashedLine(canvas, startX, endX, y, paint);
      case LineStyle.dotted:
        _drawDottedLine(canvas, startX, endX, y, paint);
      case LineStyle.double_:
        canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
        canvas.drawLine(
          Offset(startX, y + thickness * 2),
          Offset(endX, y + thickness * 2),
          paint,
        );
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    double startX,
    double endX,
    double y,
    Paint paint,
  ) {
    const dashWidth = 5.0;
    const dashSpace = 3.0;

    var x = startX;
    while (x < endX) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dashWidth).clamp(startX, endX), y),
        paint,
      );
      x += dashWidth + dashSpace;
    }
  }

  void _drawDottedLine(
    Canvas canvas,
    double startX,
    double endX,
    double y,
    Paint paint,
  ) {
    const dotSpace = 3.0;

    var x = startX;
    while (x < endX) {
      canvas.drawCircle(
        Offset(x, y),
        thickness / 2,
        paint..style = PaintingStyle.fill,
      );
      x += dotSpace;
    }
  }

  @override
  double getHeight(double width) {
    final lineHeight = style == LineStyle.double_ ? thickness * 3 : thickness;
    return padding.top + lineHeight + padding.bottom;
  }
}

enum LineStyle { solid, dashed, dotted, double_ }

class DrawImage extends DrawingAction {
  const DrawImage({
    required this.image,
    this.width,
    this.height,
    this.align = Alignment.center,
    this.fit = BoxFit.contain,
  });

  final ui.Image image;

  final double? width;

  final double? height;

  final Alignment align;

  final BoxFit fit;

  @override
  void draw(Canvas canvas, Rect bounds) {
    final srcRect = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );

    final targetWidth = width ?? bounds.width;
    final targetHeight = height ?? _calculateHeight(targetWidth);

    final dstRect = _calculateDestRect(bounds, targetWidth, targetHeight);

    canvas.drawImageRect(image, srcRect, dstRect, Paint());
  }

  double _calculateHeight(double targetWidth) {
    final aspectRatio = image.width / image.height;
    return targetWidth / aspectRatio;
  }

  Rect _calculateDestRect(
    Rect bounds,
    double targetWidth,
    double targetHeight,
  ) {
    final x = bounds.left + (bounds.width - targetWidth) * ((align.x + 1) / 2);
    final y = bounds.top;
    return Rect.fromLTWH(x, y, targetWidth, targetHeight);
  }

  @override
  double getHeight(double width) {
    final targetWidth = this.width ?? width;
    return height ?? _calculateHeight(targetWidth);
  }
}

class DrawRect extends DrawingAction {
  const DrawRect({
    this.height = 10,
    this.color = Colors.black,
    this.fill = false,
    this.strokeWidth = 1.0,
    this.borderRadius,
  });

  final double height;

  final Color color;

  final bool fill;

  final double strokeWidth;

  final double? borderRadius;

  @override
  void draw(Canvas canvas, Rect bounds) {
    final paint = Paint()
      ..color = color
      ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rect = Rect.fromLTWH(bounds.left, bounds.top, bounds.width, height);

    if (borderRadius != null && borderRadius! > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(borderRadius!)),
        paint,
      );
    } else {
      canvas.drawRect(rect, paint);
    }
  }

  @override
  double getHeight(double width) => height;
}

class DrawSpace extends DrawingAction {
  const DrawSpace({required this.height});

  final double height;

  @override
  void draw(Canvas canvas, Rect bounds) {}

  @override
  double getHeight(double width) => height;
}

class DrawGroup extends DrawingAction {
  const DrawGroup({required this.actions, this.spacing = 0});

  final List<DrawingAction> actions;

  final double spacing;

  @override
  void draw(Canvas canvas, Rect bounds) {
    var currentY = bounds.top;

    for (final action in actions) {
      final actionHeight = action.getHeight(bounds.width);
      final actionBounds = Rect.fromLTWH(
        bounds.left,
        currentY,
        bounds.width,
        actionHeight,
      );
      action.draw(canvas, actionBounds);
      currentY += actionHeight + spacing;
    }
  }

  @override
  double getHeight(double width) {
    var totalHeight = 0.0;
    for (var i = 0; i < actions.length; i++) {
      totalHeight += actions[i].getHeight(width);
      if (i < actions.length - 1) {
        totalHeight += spacing;
      }
    }
    return totalHeight;
  }
}

class DrawRow extends DrawingAction {
  const DrawRow({
    required this.left,
    required this.right,
    this.leftStyle,
    this.rightStyle,
    this.leftFlex = 1,
    this.rightFlex = 1,
    this.spacing = 4,
  });

  final String left;

  final String right;

  final TextStyle? leftStyle;

  final TextStyle? rightStyle;

  final int leftFlex;

  final int rightFlex;

  final double spacing;

  @override
  void draw(Canvas canvas, Rect bounds) {
    final totalFlex = leftFlex + rightFlex;
    final leftWidth = (bounds.width - spacing) * leftFlex / totalFlex;
    final rightWidth = (bounds.width - spacing) * rightFlex / totalFlex;

    DrawString(
      text: left,
      style: leftStyle ?? DrawString.defaultStyle,
      align: TextAlign.left,
    ).draw(
      canvas,
      Rect.fromLTWH(bounds.left, bounds.top, leftWidth, bounds.height),
    );

    DrawString(
      text: right,
      style: rightStyle ?? DrawString.defaultStyle,
      align: TextAlign.right,
    ).draw(
      canvas,
      Rect.fromLTWH(
        bounds.left + leftWidth + spacing,
        bounds.top,
        rightWidth,
        bounds.height,
      ),
    );
  }

  @override
  double getHeight(double width) {
    final totalFlex = leftFlex + rightFlex;
    final leftWidth = (width - spacing) * leftFlex / totalFlex;
    final rightWidth = (width - spacing) * rightFlex / totalFlex;

    final leftHeight = DrawString(
      text: left,
      style: leftStyle ?? DrawString.defaultStyle,
    ).getHeight(leftWidth);

    final rightHeight = DrawString(
      text: right,
      style: rightStyle ?? DrawString.defaultStyle,
    ).getHeight(rightWidth);

    return leftHeight > rightHeight ? leftHeight : rightHeight;
  }
}
