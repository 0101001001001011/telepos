import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/sale/cart_view.dart';

/// Покрытие `operator ==` **и** `hashCode` по каждому полю
/// `CartCommandMeta`, `CartLine`, `CartView`, `DeferredCart` — таблицей, не
/// написанными руками тестами по одному на поле (круг правки 2 задачи 6,
/// расширено кругом правки 3, 2026-09-06).
///
/// **Почему таблицей, и почему на оба.** Переразбор круга 2 снял поле
/// `mark` из `CartLine.==`, оставив его в `hashCode` — то есть развёл `==` и
/// `hashCode` по составу полей, — и **весь набор остался зелёным**: из
/// примерно двадцати полей четырёх типов негативным тестом (два экземпляра,
/// различающихся ровно одним полем, обязаны быть неравны) было покрыто
/// шесть. Круг правки 3 переразобрал уже эту таблицу и нашёл ту же дыру в
/// другую сторону: таблица проверяла только `==`, и переразбор снял поле
/// `barcode` из `hashCode`, оставив его в `==` — все тесты снова остались
/// зелёными, потому что `_expectFieldMatters` не смотрела на `hashCode`
/// вовсе. Это тот же класс дефекта, ради которого таблица заводилась:
/// расхождение `==`/`hashCode` не роняет тест напрямую, оно тихо ломает
/// `HashSet`/`HashMap`/дедупликацию в подписках (два «равных» объекта в
/// разных корзинах хеш-таблицы никогда не встретятся друг с другом).
///
/// [_expectFieldMatters] теперь прогоняет **две** проверки по каждой записи
/// таблицы [variants]: экземпляр, отличающийся от [base] ровно одним полем,
/// обязан быть **не равен** [base] **и** иметь **другой** `hashCode`.
/// Забытое хоть в `==`, хоть в `hashCode` поле красит ровно ту запись
/// таблицы, что его называет — по имени поля в имени теста, а не «где-то в
/// наборе из двадцати».
void _expectFieldMatters<T>(String typeName, T base, Map<String, T> variants) {
  group('$typeName: изменение любого поля меняет == и hashCode', () {
    for (final entry in variants.entries) {
      test(entry.key, () {
        expect(
          base == entry.value,
          isFalse,
          reason:
              'два экземпляра $typeName, различающихся только полем '
              '"${entry.key}", оказались равны — поле забыто в operator==',
        );
        expect(
          base.hashCode == entry.value.hashCode,
          isFalse,
          reason:
              'два экземпляра $typeName, различающихся только полем '
              '"${entry.key}", дали одинаковый hashCode — поле забыто в '
              'hashCode (при этом == может быть верным — ровно так круг '
              'правки 3 нашёл barcode, выпавший из hashCode, а не из ==)',
        );
      });
    }
  });
}

void main() {
  // `receiptNo` добавлен кругом правки 2 задачи 7: одной версии для
  // опознания чека не хватает (у каждого нового чека счёт начинается с
  // нуля). Поле обязано участвовать в сравнении наравне с остальными —
  // иначе две команды, адресованные **разным** чекам, оказались бы
  // равными между собой.
  _expectFieldMatters<CartCommandMeta>(
    'CartCommandMeta',
    const CartCommandMeta(key: 'k1', baseVersion: 1, receiptNo: 5),
    {
      'key': const CartCommandMeta(key: 'k2', baseVersion: 1, receiptNo: 5),
      'baseVersion': const CartCommandMeta(
        key: 'k1',
        baseVersion: 2,
        receiptNo: 5,
      ),
      'receiptNo': const CartCommandMeta(
        key: 'k1',
        baseVersion: 1,
        receiptNo: 6,
      ),
      'receiptNo (пустой)': const CartCommandMeta(
        key: 'k1',
        baseVersion: 1,
        receiptNo: null,
      ),
    },
  );

  final baseLine = CartLine.manualDiscount(
    id: 'l1',
    productId: 1,
    name: 'Товар',
    quantity: Decimal.one,
    price: Decimal.fromInt(10),
    discount: Decimal.zero,
    barcode: '123',
    mark: 'm1',
  );

  _expectFieldMatters<CartLine>('CartLine', baseLine, {
    'id': CartLine.manualDiscount(
      id: 'l2',
      productId: baseLine.productId,
      name: baseLine.name,
      quantity: baseLine.quantity,
      price: baseLine.price,
      discount: baseLine.discount,
      barcode: baseLine.barcode,
      mark: baseLine.mark,
    ),
    'productId': CartLine.manualDiscount(
      id: baseLine.id,
      productId: 2,
      name: baseLine.name,
      quantity: baseLine.quantity,
      price: baseLine.price,
      discount: baseLine.discount,
      barcode: baseLine.barcode,
      mark: baseLine.mark,
    ),
    'name': CartLine.manualDiscount(
      id: baseLine.id,
      productId: baseLine.productId,
      name: 'Другой товар',
      quantity: baseLine.quantity,
      price: baseLine.price,
      discount: baseLine.discount,
      barcode: baseLine.barcode,
      mark: baseLine.mark,
    ),
    'quantity': CartLine.manualDiscount(
      id: baseLine.id,
      productId: baseLine.productId,
      name: baseLine.name,
      quantity: Decimal.fromInt(2),
      price: baseLine.price,
      discount: baseLine.discount,
      barcode: baseLine.barcode,
      mark: baseLine.mark,
    ),
    'price': CartLine.manualDiscount(
      id: baseLine.id,
      productId: baseLine.productId,
      name: baseLine.name,
      quantity: baseLine.quantity,
      price: Decimal.fromInt(20),
      discount: baseLine.discount,
      barcode: baseLine.barcode,
      mark: baseLine.mark,
    ),
    'discount': CartLine.manualDiscount(
      id: baseLine.id,
      productId: baseLine.productId,
      name: baseLine.name,
      quantity: baseLine.quantity,
      price: baseLine.price,
      discount: Decimal.one,
      barcode: baseLine.barcode,
      mark: baseLine.mark,
    ),
    'barcode': CartLine.manualDiscount(
      id: baseLine.id,
      productId: baseLine.productId,
      name: baseLine.name,
      quantity: baseLine.quantity,
      price: baseLine.price,
      discount: baseLine.discount,
      barcode: '456',
      mark: baseLine.mark,
    ),
    // Ровно то поле, что переразбор круга 2 нашёл выброшенным из ==.
    'mark': CartLine.manualDiscount(
      id: baseLine.id,
      productId: baseLine.productId,
      name: baseLine.name,
      quantity: baseLine.quantity,
      price: baseLine.price,
      discount: baseLine.discount,
      barcode: baseLine.barcode,
      mark: 'm2',
    ),
  });

  test('CartLine: barcode/mark — null не равно значению', () {
    final withNulls = CartLine.manualDiscount(
      id: baseLine.id,
      productId: baseLine.productId,
      name: baseLine.name,
      quantity: baseLine.quantity,
      price: baseLine.price,
      discount: baseLine.discount,
    );
    expect(baseLine == withNulls, isFalse);
  });

  final baseView = CartView(
    posId: 1,
    terminalId: 7,
    version: 2,
    wholesale: false,
    receiptNo: 5,
    agentId: 9,
    lines: [baseLine],
  );

  _expectFieldMatters<CartView>('CartView', baseView, {
    'posId': CartView(
      posId: 2,
      terminalId: baseView.terminalId,
      version: baseView.version,
      wholesale: baseView.wholesale,
      receiptNo: baseView.receiptNo,
      agentId: baseView.agentId,
      lines: baseView.lines,
    ),
    'terminalId': CartView(
      posId: baseView.posId,
      terminalId: 8,
      version: baseView.version,
      wholesale: baseView.wholesale,
      receiptNo: baseView.receiptNo,
      agentId: baseView.agentId,
      lines: baseView.lines,
    ),
    'version': CartView(
      posId: baseView.posId,
      terminalId: baseView.terminalId,
      version: 3,
      wholesale: baseView.wholesale,
      receiptNo: baseView.receiptNo,
      agentId: baseView.agentId,
      lines: baseView.lines,
    ),
    'wholesale': CartView(
      posId: baseView.posId,
      terminalId: baseView.terminalId,
      version: baseView.version,
      wholesale: true,
      receiptNo: baseView.receiptNo,
      agentId: baseView.agentId,
      lines: baseView.lines,
    ),
    'receiptNo': CartView(
      posId: baseView.posId,
      terminalId: baseView.terminalId,
      version: baseView.version,
      wholesale: baseView.wholesale,
      receiptNo: 6,
      agentId: baseView.agentId,
      lines: baseView.lines,
    ),
    'agentId': CartView(
      posId: baseView.posId,
      terminalId: baseView.terminalId,
      version: baseView.version,
      wholesale: baseView.wholesale,
      receiptNo: baseView.receiptNo,
      agentId: 10,
      lines: baseView.lines,
    ),
    // Список в Dart сравнивается по ссылке, а не по содержимому — ровно
    // повод, по которому CartView.== написан вручную, поэлементно.
    'lines (другое содержимое той же длины)': CartView(
      posId: baseView.posId,
      terminalId: baseView.terminalId,
      version: baseView.version,
      wholesale: baseView.wholesale,
      receiptNo: baseView.receiptNo,
      agentId: baseView.agentId,
      lines: [
        CartLine.manualDiscount(
          id: baseLine.id,
          productId: baseLine.productId,
          name: baseLine.name,
          quantity: baseLine.quantity,
          price: Decimal.fromInt(999), // единственное отличие — внутри строки
          discount: baseLine.discount,
          barcode: baseLine.barcode,
          mark: baseLine.mark,
        ),
      ],
    ),
    'lines (другая длина)': CartView(
      posId: baseView.posId,
      terminalId: baseView.terminalId,
      version: baseView.version,
      wholesale: baseView.wholesale,
      receiptNo: baseView.receiptNo,
      agentId: baseView.agentId,
      lines: [baseLine, baseLine],
    ),
  });

  test('CartView: receiptNo/agentId — null не равно значению', () {
    final withNulls = CartView(
      posId: baseView.posId,
      terminalId: baseView.terminalId,
      version: baseView.version,
      wholesale: baseView.wholesale,
      lines: baseView.lines,
    );
    expect(baseView == withNulls, isFalse);
  });

  test('CartView: две раздельно собранные, но одинаковые корзины равны', () {
    CartView build() => CartView(
      posId: 1,
      terminalId: 7,
      version: 2,
      wholesale: false,
      receiptNo: 5,
      agentId: 9,
      lines: [
        CartLine.manualDiscount(
          id: 'l1',
          productId: 1,
          name: 'Товар',
          quantity: Decimal.one,
          price: Decimal.fromInt(10),
          discount: Decimal.zero,
          barcode: '123',
          mark: 'm1',
        ),
      ],
    );

    expect(build(), equals(build()));
    expect(build().hashCode, build().hashCode);
  });

  // Состав `DeferredCart` пересмотрен задачей 7 (см. докстринг класса):
  // `time` ушёл (у незавершённого чека он ноль, а проставить настоящий —
  // денежный дефект в `SaleDao.amountOfShift`), взамен пришли кассир и
  // первая строка — то, чем кассир на самом деле находит свой чек в общем
  // пуле.
  final baseCard = DeferredCart(
    receiptNo: 10,
    posId: 1,
    total: Decimal.zero,
    lineCount: 3,
    userId: 4,
    userName: 'Айгуль',
    firstLineName: 'Молоко',
  );

  _expectFieldMatters<DeferredCart>('DeferredCart', baseCard, {
    'receiptNo': DeferredCart(
      receiptNo: 11,
      posId: 1,
      total: Decimal.zero,
      lineCount: 3,
      userId: 4,
      userName: 'Айгуль',
      firstLineName: 'Молоко',
    ),
    'posId': DeferredCart(
      receiptNo: 10,
      posId: 2,
      total: Decimal.zero,
      lineCount: 3,
      userId: 4,
      userName: 'Айгуль',
      firstLineName: 'Молоко',
    ),
    'total': DeferredCart(
      receiptNo: 10,
      posId: 1,
      total: Decimal.one,
      lineCount: 3,
      userId: 4,
      userName: 'Айгуль',
      firstLineName: 'Молоко',
    ),
    'lineCount': DeferredCart(
      receiptNo: 10,
      posId: 1,
      total: Decimal.zero,
      lineCount: 4,
      userId: 4,
      userName: 'Айгуль',
      firstLineName: 'Молоко',
    ),
    'userId': DeferredCart(
      receiptNo: 10,
      posId: 1,
      total: Decimal.zero,
      lineCount: 3,
      userId: 5,
      userName: 'Айгуль',
      firstLineName: 'Молоко',
    ),
    'userName': DeferredCart(
      receiptNo: 10,
      posId: 1,
      total: Decimal.zero,
      lineCount: 3,
      userId: 4,
      userName: 'Данияр',
      firstLineName: 'Молоко',
    ),
    'firstLineName': DeferredCart(
      receiptNo: 10,
      posId: 1,
      total: Decimal.zero,
      lineCount: 3,
      userId: 4,
      userName: 'Айгуль',
      firstLineName: 'Хлеб',
    ),
  });
}
