library;

import 'dart:convert';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/core/locale/app_locale.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
      currencySymbol: r'$',
      languageCode: 'en',
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

    // Валюта и язык — часть провода, а не догадка окна: у второго движка нет
    // ни базы кассы, ни настроек, и потеряй их провод — покупатель увидел бы
    // чужую валюту.
    expect(back.currencySymbol, r'$');
    expect(back.languageCode, 'en');
    expect(back.money(Decimal.fromInt(600)), r'600 $');

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
      // Словари даются НАСТОЯЩИЕ: экран покупателя требует их так же, как
      // всякий другой, и проба без них проверяла бы не тот экран.
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: AppLocale.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
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
    await t.pumpWidget(_app(const Locale('ru'), CustomerDisplayData(), 'X'));
    await t.pump();

    expect(find.text('Добро пожаловать!'), findsOneWidget);
    expect(find.text('ИТОГО'), findsNothing);
  });

  testWidgets('деньги покупателя — в валюте кассы, а не в тенге', (t) async {
    // Дефект, ради которого проба заведена: экран покупателя печатал `₸`
    // пятью зашитыми местами — на кассе любой страны. Знак теперь приезжает
    // вместе с деньгами, и проба смотрит НАРИСОВАННОЕ.
    final data = CustomerDisplayData(
      lines: [
        CustomerDisplayLine(
          name: 'Coffee',
          quantity: Decimal.one,
          total: Decimal.fromInt(7),
          discount: Decimal.fromInt(2),
        ),
      ],
      subtotal: Decimal.fromInt(9),
      totalDiscount: Decimal.fromInt(2),
      total: Decimal.fromInt(7),
      currencySymbol: r'$',
      languageCode: 'en',
    );

    await t.pumpWidget(_app(const Locale('en'), data, 'Corner Store'));
    await t.pump();

    expect(find.textContaining('₸'), findsNothing);
    expect(find.text(r'7 $'), findsWidgets);
    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.text('Product'), findsOneWidget);
  });

  testWidgets('валюты касса не назвала — число без знака, а не тенге', (
    t,
  ) async {
    // Выдуманный знак валюты на экране покупателя — заявление о цене.
    final data = CustomerDisplayData(
      subtotal: Decimal.fromInt(5),
      total: Decimal.fromInt(5),
      lines: [
        CustomerDisplayLine(
          name: 'X',
          quantity: Decimal.one,
          total: Decimal.fromInt(5),
          discount: Decimal.zero,
        ),
      ],
    );

    await t.pumpWidget(_app(const Locale('en'), data, 'S'));
    await t.pump();

    expect(find.textContaining('₸'), findsNothing);
    expect(find.text('5'), findsWidgets);
  });
}

/// Окно покупателя со НАСТОЯЩИМИ словарями.
///
/// Проба без них проверяла бы не тот экран: `AppLocalizations.of` вернул бы
/// `null`, и всякое слово из словаря уронило бы кадр. Именно так 2026-09-22
/// и вскрылось, что окно покупателя локализовать было нельзя вовсе.
Widget _app(Locale locale, CustomerDisplayData data, String storeName) =>
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocale.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: CustomerDisplayView(data: data, storeName: storeName),
    );
