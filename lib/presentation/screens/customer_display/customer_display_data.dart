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

class CustomerDisplayData {
  CustomerDisplayData({
    this.lines = const [],
    Decimal? subtotal,
    Decimal? totalDiscount,
    Decimal? total,
  }) : subtotal = subtotal ?? Decimal.zero,
       totalDiscount = totalDiscount ?? Decimal.zero,
       total = total ?? Decimal.zero;

  final List<CustomerDisplayLine> lines;
  final Decimal subtotal;
  final Decimal totalDiscount;
  final Decimal total;

  bool get isEmpty => lines.isEmpty;

  Map<String, dynamic> toJson() => {
    'lines': lines.map((l) => l.toJson()).toList(),
    'subtotal': subtotal.toString(),
    'totalDiscount': totalDiscount.toString(),
    'total': total.toString(),
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
