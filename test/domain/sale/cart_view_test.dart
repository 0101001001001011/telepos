import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/wire/cart_codec.dart';

/// Снимок корзины (`CartView`), его строки (`CartLine`) и кодек в форму
/// провода — задача 6 плана «Продажа с браузерного терминала».
///
/// Главное утверждение файла — из брифа задачи дословно: третий знак после
/// запятой обязан пережить дорогу туда и обратно. Это не украшение —
/// деньги здесь `Decimal` P18,S3, и `double` потерял бы его молча
/// (`Decimal.parse('1990.125').toDouble()` печатает `1990.125`, но это
/// печать, не хранение — операции над `double` копят ошибку в третьем
/// знаке уже на второй-третьей строке корзины, а тест на одну строку этого
/// не покажет; `money_over_wire_test.dart` рядом стережёт само назначение
/// поля, а не то, что здесь видно на глаз).
void main() {
  test('деньги уезжают строкой и возвращаются тем же числом', () {
    final view = CartView(
      posId: 1,
      terminalId: 7,
      version: 3,
      wholesale: false,
      receiptNo: 42,
      lines: [
        CartLine.manualDiscount(
          id: 'l1',
          productId: 100,
          name: 'Кофе',
          quantity: Decimal.parse('2.5'),
          price: Decimal.parse('1990.125'),
          discount: Decimal.parse('0.005'),
        ),
      ],
    );

    final json = cartViewToWireJson(view);
    final line = (json['lines'] as List).single as Map<String, Object?>;

    expect(line['price'], '1990.125');
    expect(line['price'], isA<String>(), reason: 'double потерял бы третий знак');

    final back = cartViewFromWireJson(json);
    expect(back.lines.single.price, Decimal.parse('1990.125'));
    expect(back.total, view.total);
  });

  test('каждое денежное поле строки едет строкой, а не только price', () {
    final view = CartView(
      posId: 1,
      terminalId: 7,
      version: 1,
      wholesale: false,
      lines: [
        CartLine.manualDiscount(
          id: 'l1',
          productId: 100,
          name: 'Кофе',
          quantity: Decimal.parse('2.5'),
          price: Decimal.parse('1990.125'),
          discount: Decimal.parse('0.005'),
        ),
      ],
    );

    final json = cartViewToWireJson(view);
    final line = (json['lines'] as List).single as Map<String, Object?>;

    expect(line['quantity'], isA<String>());
    expect(line['discount'], isA<String>());
    expect(line['subtotal'], isA<String>());
    expect(line['total'], isA<String>());
    expect(json['subtotal'], isA<String>());
    expect(json['totalDiscount'], isA<String>());
    expect(json['total'], isA<String>());
  });

  test('пустая корзина — итог ноль, а не отказ и не null', () {
    const view = CartView(
      posId: 1,
      terminalId: 7,
      version: 0,
      wholesale: false,
      lines: [],
    );

    expect(view.subtotal, Decimal.zero);
    expect(view.totalDiscount, Decimal.zero);
    expect(view.total, Decimal.zero);

    final back = cartViewFromWireJson(cartViewToWireJson(view));
    expect(back.lines, isEmpty);
    expect(back.total, Decimal.zero);
  });

  test('несколько строк — итог складывается по всем, включая скидку', () {
    final view = CartView(
      posId: 1,
      terminalId: 7,
      version: 5,
      wholesale: true,
      receiptNo: 10,
      agentId: 99,
      lines: [
        CartLine.manualDiscount(
          id: 'l1',
          productId: 1,
          name: 'Товар 1',
          quantity: Decimal.fromInt(2),
          price: Decimal.parse('100.500'),
          discount: Decimal.parse('1.000'),
        ),
        CartLine.manualDiscount(
          id: 'l2',
          productId: 2,
          name: 'Товар 2',
          quantity: Decimal.parse('0.750'),
          price: Decimal.parse('40.000'),
          discount: Decimal.zero,
          barcode: '4600000000001',
          mark: '0104600000000001215RVoAv/OK03',
        ),
      ],
    );

    // 2 * 100.500 - 1.000 = 200.000; 0.750 * 40.000 - 0 = 30.000
    expect(view.subtotal, Decimal.parse('231.000'));
    expect(view.totalDiscount, Decimal.parse('1.000'));
    expect(view.total, Decimal.parse('230.000'));

    final back = cartViewFromWireJson(cartViewToWireJson(view));
    expect(back.lines.length, 2);
    expect(back.lines[1].barcode, '4600000000001');
    expect(back.lines[1].mark, '0104600000000001215RVoAv/OK03');
    expect(back.total, view.total);
    expect(back.wholesale, isTrue);
    expect(back.agentId, 99);
    expect(back.receiptNo, 10);
  });

  test('receiptNo и agentId отсутствуют — переживают круг как null', () {
    const view = CartView(
      posId: 1,
      terminalId: 7,
      version: 0,
      wholesale: false,
      lines: [],
    );

    final back = cartViewFromWireJson(cartViewToWireJson(view));
    expect(back.receiptNo, isNull);
    expect(back.agentId, isNull);
  });

  test('barcode и mark отсутствуют у строки — переживают круг как null', () {
    final view = CartView(
      posId: 1,
      terminalId: 7,
      version: 0,
      wholesale: false,
      lines: [
        CartLine.manualDiscount(
          id: 'l1',
          productId: 1,
          name: 'Товар без штрихкода',
          quantity: Decimal.one,
          price: Decimal.fromInt(10),
          discount: Decimal.zero,
        ),
      ],
    );

    final back = cartViewFromWireJson(cartViewToWireJson(view));
    expect(back.lines.single.barcode, isNull);
    expect(back.lines.single.mark, isNull);
  });

  // Сравнение по значению CartCommandMeta/CartLine/CartView/DeferredCart —
  // покрыто по каждому полю таблицей в `cart_view_equality_test.dart`
  // (круг правки 2 задачи 6). Здесь остаётся только то, что специфично
  // кодеку: круг «собрано из кодека — совпадает с оригиналом».
  test('CartView, прошедший через кодек туда-обратно, равен оригиналу', () {
    final original = CartView(
      posId: 1,
      terminalId: 7,
      version: 2,
      wholesale: false,
      receiptNo: 5,
      lines: [
        CartLine.manualDiscount(
          id: 'l1',
          productId: 1,
          name: 'Товар',
          quantity: Decimal.one,
          price: Decimal.fromInt(10),
          discount: Decimal.zero,
        ),
      ],
    );

    final roundTripped = cartViewFromWireJson(cartViewToWireJson(original));
    expect(roundTripped, equals(original));
  });
}
