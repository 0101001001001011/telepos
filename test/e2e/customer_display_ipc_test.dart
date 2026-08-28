library;

import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/presentation/screens/customer_display/customer_display_data.dart';
import 'package:telepos/presentation/screens/customer_display/customer_display_screen.dart';

void main() {
  test('CustomerDisplayData round-trips through JSON (IPC payload)', () {
    final data = CustomerDisplayData(
      lines: [
        CustomerDisplayLine(
          name: 'Молоко 1л',
          quantity: Decimal.fromInt(2),
          total: Decimal.fromInt(450),
          discount: Decimal.fromInt(450),
        ),
        CustomerDisplayLine(
          name: 'Хлеб белый',
          quantity: Decimal.one,
          total: Decimal.fromInt(150),
          discount: Decimal.zero,
        ),
      ],
      subtotal: Decimal.fromInt(1050),
      totalDiscount: Decimal.fromInt(450),
      total: Decimal.fromInt(600),
    );

    final wire = jsonEncode(data.toJson());
    final back = CustomerDisplayData.fromJson(
      jsonDecode(wire) as Map<String, dynamic>,
    );

    expect(back.lines.length, 2);
    expect(back.total, Decimal.fromInt(600));
    expect(back.subtotal, Decimal.fromInt(1050));
    expect(back.totalDiscount, Decimal.fromInt(450));
    expect(back.lines.first.name, 'Молоко 1л');
    expect(back.lines.first.discount, Decimal.fromInt(450));

    final gift = CustomerDisplayLine(
      name: 'Подарок',
      quantity: Decimal.one,
      total: Decimal.zero,
      discount: Decimal.fromInt(100),
    );
    final giftBack = CustomerDisplayLine.fromJson(
      jsonDecode(jsonEncode(gift.toJson())) as Map<String, dynamic>,
    );
    expect(giftBack.isFree, isTrue);
  });

  testWidgets('CustomerDisplayView shows cart + total (sub-window render)', (
    t,
  ) async {
    final data = CustomerDisplayData(
      lines: [
        CustomerDisplayLine(
          name: 'Молоко 1л',
          quantity: Decimal.fromInt(2),
          total: Decimal.fromInt(900),
          discount: Decimal.zero,
        ),
      ],
      subtotal: Decimal.fromInt(900),
      total: Decimal.fromInt(900),
    );

    await t.pumpWidget(
      MaterialApp(
        home: CustomerDisplayView(data: data, storeName: 'Мой магазин'),
      ),
    );
    await t.pump();

    expect(find.text('Мой магазин'), findsOneWidget);
    expect(find.text('Молоко 1л'), findsOneWidget);
    expect(find.text('ИТОГО'), findsOneWidget);
    expect(find.textContaining('900'), findsWidgets);
  });

  testWidgets('CustomerDisplayView shows welcome when cart is empty', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: CustomerDisplayView(data: CustomerDisplayData(), storeName: 'X'),
      ),
    );
    await t.pump();

    expect(find.text('Добро пожаловать!'), findsOneWidget);
    expect(find.text('ИТОГО'), findsNothing);
  });
}
