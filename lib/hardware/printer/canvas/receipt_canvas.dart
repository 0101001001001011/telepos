import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:telepos/hardware/printer/canvas/drawing_actions.dart';

class ReceiptCanvas {
  ReceiptCanvas({
    required this.width,
    this.backgroundColor = Colors.white,
    this.padding = const EdgeInsets.all(4),
  });

  final double width;

  final Color backgroundColor;

  final EdgeInsets padding;

  final List<DrawingAction> _actions = [];

  void add(DrawingAction action) {
    _actions.add(action);
  }

  void text(String text, {TextStyle? style, TextAlign align = TextAlign.left}) {
    _actions.add(DrawString(text: text, style: style, align: align));
  }

  void bold(String text, {TextAlign align = TextAlign.left}) {
    _actions.add(
      DrawString(
        text: text,
        style: DrawString.defaultStyle.copyWith(fontWeight: FontWeight.bold),
        align: align,
      ),
    );
  }

  void center(String text, {TextStyle? style}) {
    _actions.add(DrawString(text: text, style: style, align: TextAlign.center));
  }

  void row(
    String left,
    String right, {
    TextStyle? leftStyle,
    TextStyle? rightStyle,
  }) {
    _actions.add(
      DrawRow(
        left: left,
        right: right,
        leftStyle: leftStyle,
        rightStyle: rightStyle,
      ),
    );
  }

  void divider({
    double thickness = 1,
    LineStyle style = LineStyle.solid,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    _actions.add(
      DrawLine(thickness: thickness, style: style, padding: padding),
    );
  }

  void space(double height) {
    _actions.add(DrawSpace(height: height));
  }

  void image(ui.Image image, {double? width, double? height}) {
    _actions.add(DrawImage(image: image, width: width, height: height));
  }

  double calculateHeight() {
    final contentWidth = width - padding.horizontal;
    var totalHeight = padding.top;

    for (final action in _actions) {
      totalHeight += action.getHeight(contentWidth);
    }

    totalHeight += padding.bottom;
    return totalHeight;
  }

  Future<ui.Image> render() async {
    final height = calculateHeight();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

    final contentWidth = width - padding.horizontal;
    var currentY = padding.top;

    for (final action in _actions) {
      final actionHeight = action.getHeight(contentWidth);
      final bounds = Rect.fromLTWH(
        padding.left,
        currentY,
        contentWidth,
        actionHeight,
      );
      action.draw(canvas, bounds);
      currentY += actionHeight;
    }

    final picture = recorder.endRecording();
    return await picture.toImage(width.toInt(), height.toInt());
  }

  Future<Uint8List> renderToPng() async {
    final image = await render();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void clear() {
    _actions.clear();
  }
}

class ReceiptCanvasBuilder {
  ReceiptCanvasBuilder({
    required this.width,
    this.backgroundColor = Colors.white,
    this.padding = const EdgeInsets.all(4),
  }) : _canvas = ReceiptCanvas(
         width: width,
         backgroundColor: backgroundColor,
         padding: padding,
       );

  final double width;
  final Color backgroundColor;
  final EdgeInsets padding;
  final ReceiptCanvas _canvas;

  ReceiptCanvasBuilder header(String text) {
    _canvas.add(
      DrawString(
        text: text,
        style: DrawString.defaultStyle.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        align: TextAlign.center,
      ),
    );
    return this;
  }

  ReceiptCanvasBuilder subheader(String text) {
    _canvas.add(
      DrawString(
        text: text,
        style: DrawString.defaultStyle.copyWith(fontSize: 10),
        align: TextAlign.center,
      ),
    );
    return this;
  }

  ReceiptCanvasBuilder text(String text, {TextAlign align = TextAlign.left}) {
    _canvas.text(text, align: align);
    return this;
  }

  ReceiptCanvasBuilder bold(String text, {TextAlign align = TextAlign.left}) {
    _canvas.bold(text, align: align);
    return this;
  }

  ReceiptCanvasBuilder center(String text) {
    _canvas.center(text);
    return this;
  }

  ReceiptCanvasBuilder row(String left, String right) {
    _canvas.row(left, right);
    return this;
  }

  ReceiptCanvasBuilder divider({LineStyle style = LineStyle.solid}) {
    _canvas.divider(style: style);
    return this;
  }

  ReceiptCanvasBuilder dashedDivider() {
    _canvas.divider(style: LineStyle.dashed);
    return this;
  }

  ReceiptCanvasBuilder space([double height = 4]) {
    _canvas.space(height);
    return this;
  }

  ReceiptCanvasBuilder image(ui.Image image, {double? width}) {
    _canvas.image(image, width: width);
    return this;
  }

  ReceiptCanvasBuilder action(DrawingAction action) {
    _canvas.add(action);
    return this;
  }

  ReceiptCanvas build() => _canvas;

  Future<ui.Image> render() => _canvas.render();

  Future<Uint8List> renderToPng() => _canvas.renderToPng();
}
