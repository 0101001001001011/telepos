import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/wire/sale_ops.dart';
import 'package:telepos/domain/wire/till_ops.dart';

void main() {
  test('salePing объявлен и входит в общий каталог', () {
    expect(SaleOps.salePing.name, 'sale.ping');
    expect(TillOps.all.map((op) => op.name), contains('sale.ping'));
  });
}
