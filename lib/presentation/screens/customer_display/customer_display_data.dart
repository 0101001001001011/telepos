import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomerDisplayLine {
  const CustomerDisplayLine({
    required this.name,
    required this.quantity,
    required this.total,
    required this.discount,
  });

  final String name;
  final Decimal quantity;
  final Decimal total;
  final Decimal discount;

  bool get isFree => discount > Decimal.zero && total == Decimal.zero;

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity.toString(),
    'total': total.toString(),
    'discount': discount.toString(),
  };

  factory CustomerDisplayLine.fromJson(Map<String, dynamic> j) =>
      CustomerDisplayLine(
        name: j['name'] as String? ?? '',
        quantity: Decimal.tryParse('${j['quantity']}') ?? Decimal.zero,
        total: Decimal.tryParse('${j['total']}') ?? Decimal.zero,
        discount: Decimal.tryParse('${j['discount']}') ?? Decimal.zero,
      );
}

/// Что видит покупатель: строки чека, деньги, **валюта этих денег** и язык.
///
/// # Почему валюта и язык едут ЗДЕСЬ, а не берутся на месте
///
/// Окно покупателя — отдельный движок (`desktop_multi_window`). У него нет
/// ни базы кассы, ни настроек: `sharedPreferencesProvider` там не подменён и
/// бросает, `GetIt` пуст. Всё, что окно знает о мире, оно получает проводом.
///
/// До 2026-09-22 валюты в этом проводе не было, и экран, который читает
/// ПОКУПАТЕЛЬ, печатал `₸` пятью зашитыми местами — на любой кассе любой
/// страны. Язык был той же природы: словарей у окна не было вовсе.
///
/// Валюта едет вместе с деньгами намеренно: сумма и её знак — одно значение,
/// разнесённое по двум путям оно однажды разойдётся.
class CustomerDisplayData {
  CustomerDisplayData({
    this.lines = const [],
    Decimal? subtotal,
    Decimal? totalDiscount,
    Decimal? total,
    this.currencySymbol = '',
    this.languageCode = '',
  }) : subtotal = subtotal ?? Decimal.zero,
       totalDiscount = totalDiscount ?? Decimal.zero,
       total = total ?? Decimal.zero;

  final List<CustomerDisplayLine> lines;
  final Decimal subtotal;
  final Decimal totalDiscount;
  final Decimal total;

  /// Знак валюты кассы. Пусто — значит касса его не назвала; тогда окно
  /// покажет **голое число**. Это честнее выдуманного знака: неверная валюта
  /// на экране покупателя — заявление о цене, а не оплошность вёрстки.
  final String currencySymbol;

  /// Язык кассы, кодом (`ru`, `en`, …). Пусто — язык системы.
  final String languageCode;

  bool get isEmpty => lines.isEmpty;

  /// Сумма со знаком валюты — одним местом на всё окно.
  String money(Decimal amount) =>
      currencySymbol.isEmpty ? '$amount' : '$amount $currencySymbol';

  Map<String, dynamic> toJson() => {
    'lines': lines.map((l) => l.toJson()).toList(),
    'subtotal': subtotal.toString(),
    'totalDiscount': totalDiscount.toString(),
    'total': total.toString(),
    'currencySymbol': currencySymbol,
    'languageCode': languageCode,
  };

  factory CustomerDisplayData.fromJson(
    Map<String, dynamic> j,
  ) => CustomerDisplayData(
    lines: ((j['lines'] as List?) ?? const [])
        .map(
          (e) =>
              CustomerDisplayLine.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList(),
    subtotal: Decimal.tryParse('${j['subtotal']}') ?? Decimal.zero,
    totalDiscount: Decimal.tryParse('${j['totalDiscount']}') ?? Decimal.zero,
    total: Decimal.tryParse('${j['total']}') ?? Decimal.zero,
    currencySymbol: j['currencySymbol'] as String? ?? '',
    languageCode: j['languageCode'] as String? ?? '',
  );
}

class CustomerDisplayDataNotifier extends Notifier<CustomerDisplayData> {
  @override
  CustomerDisplayData build() => CustomerDisplayData();

  void set(CustomerDisplayData data) => state = data;
}

final customerDisplayDataProvider =
    NotifierProvider<CustomerDisplayDataNotifier, CustomerDisplayData>(
      CustomerDisplayDataNotifier.new,
    );
