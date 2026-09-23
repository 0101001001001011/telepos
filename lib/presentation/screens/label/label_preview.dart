import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/hardware/label_printer/label_printer_service.dart';
import 'package:telepos/l10n/app_localizations.dart';

class LabelPreview extends StatelessWidget {
  const LabelPreview({
    required this.fields,
    required this.widthMm,
    required this.heightMm,
    required this.data,
    super.key,
  });

  final List<LabelField> fields;
  final int widthMm;
  final int heightMm;
  final LabelData data;

  static const double _dpi = 203;

  String _value(LabelField f) {
    return switch (f.kind) {
      LabelFieldKind.name => data.name,
      LabelFieldKind.price =>
        '${data.currencySymbol} ${data.price.toStringAsFixed(2)}',
      LabelFieldKind.barcode => data.barcode,
      LabelFieldKind.sku => data.sku ?? '',
      LabelFieldKind.date => data.date ?? '',
      LabelFieldKind.text => f.text ?? '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final dotsW = (widthMm * _dpi / 25.4);
    final dotsH = (heightMm * _dpi / 25.4);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.clamp(120.0, 360.0);
        final scale = maxW / dotsW;
        final h = dotsH * scale;

        return Center(
          child: Container(
            width: maxW,
            height: h,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: fields.map((f) => _buildField(f, scale)).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildField(LabelField f, double scale) {
    final value = _value(f);
    if (f.kind == LabelFieldKind.barcode) {
      return Positioned(
        left: f.x * scale,
        top: f.y * scale,
        child: _BarcodeGlyph(text: value, scale: scale),
      );
    }
    final fontSize = (f.fontSize <= 0 ? 28 : f.fontSize) * scale;
    return Positioned(
      left: f.x * scale,
      top: f.y * scale,
      child: Text(
        value,
        style: TextStyle(
          fontSize: fontSize.clamp(6.0, 64.0),
          fontWeight: f.bold ? FontWeight.bold : FontWeight.normal,
          color: Colors.black,
          height: 1.0,
        ),
      ),
    );
  }
}

class _BarcodeGlyph extends StatelessWidget {
  const _BarcodeGlyph({required this.text, required this.scale});

  final String text;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final barsH = 40 * scale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: barsH.clamp(12.0, 60.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(text.isEmpty ? 12 : text.length, (i) {
              final wide =
                  (text.codeUnitAt(i % text.length.clamp(1, 9999)) + i) % 3 ==
                  0;
              return Container(
                width: (wide ? 2.4 : 1.2),
                margin: const EdgeInsets.only(right: 1.2),
                color: Colors.black,
              );
            }),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          text,
          style: TextStyle(
            fontSize: (14 * scale).clamp(6.0, 14.0),
            color: Colors.black,
            fontFamily: 'TeleposMono',
          ),
        ),
      ],
    );
  }
}

/// Образец для предпросмотра ценника.
///
/// Словарь — доводом: это `lib/presentation`, но функция верхнего уровня, и
/// брать язык ей неоткуда. Пусть вызывающий, у которого контекст есть,
/// назовёт его явно.
LabelData sampleLabelData(AppLocalizations l10n) => LabelData(
  name: l10n.labelSampleProduct,
  barcode: '4607001000001',
  price: Decimal.parse('1290.00'),
  sku: 'ART-001',
  date: '15.06.2026',
);
