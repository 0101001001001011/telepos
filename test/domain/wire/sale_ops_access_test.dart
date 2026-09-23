import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/product_search_result.dart';
import 'package:telepos/domain/wire/cart_codec.dart';
import 'package:telepos/domain/wire/sale_ops.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_access.dart';
import 'package:telepos/domain/wire/wire_op.dart';

/// Сторож каталога операций продажи — задача 9 плана «Продажа с браузерного
/// терминала».
///
/// **Право объявляется в каталоге, а не в обработчике.** Обработчик можно
/// забыть проверить — и это уже было: провод прожил до 2026-08-21 с сеансом,
/// которого не проверял никто (`wire_access.dart`, докстринг). Требование
/// доводом операции забыть нельзя — операция без него не компилируется, а
/// какое именно требование стоит у какой операции, закрепляет этот файл
/// **поимённо, закрытой таблицей**: новая операция продажи обязана попасть в
/// неё сознательно, а не проскользнуть с правом соседки по копипасте.
void main() {
  /// Право, объявленное операцией; падает с понятным текстом, если операция
  /// вдруг перестала быть [SessionAccess] вовсе.
  String? needs(WireOp<Object?, Object?> op) {
    final access = op.access;
    expect(access, isA<SessionAccess>(), reason: op.name);
    return (access as SessionAccess).needs;
  }

  const meta = CartCommandMeta(key: 'k1', baseVersion: 3, receiptNo: 17);

  group('права', () {
    test('операции скидки и цены требуют своих ключей op.*', () {
      // Ровно то, ради чего задача 9 существует: три ключа `op.*` из восьми,
      // которые до неё были объявлены, показаны в форме прав, розданы ролям
      // — и не читались ни одной строкой `lib/` (докстринг
      // `PermissionKeys.opEditPrice` называет это прямо).
      expect(needs(SaleOps.setDiscountPercent), PermissionKeys.opSellDiscount);
      expect(needs(SaleOps.setDiscountAmount), PermissionKeys.opSellDiscount);
      expect(needs(SaleOps.updatePrice), PermissionKeys.opEditPrice);
      expect(needs(SaleOps.defer), PermissionKeys.opDeferSale);
      expect(needs(SaleOps.loadDeferred), PermissionKeys.opDeferSale);
      // Круг правки 1: две находки против брифа, обе про половину права.
      expect(needs(SaleOps.deferredList), PermissionKeys.opDeferSale);
      expect(needs(SaleOps.setWholesale), PermissionKeys.opEditPrice);
    });

    test('ни одна операция продажи не открыта без сеанса', () {
      for (final op in SaleOps.all) {
        expect(op.access, isA<SessionAccess>(), reason: op.name);
      }
    });

    test('раскладка прав закрыта поимённо — все двадцать три', () {
      // Закрытая таблица, а не счёт: операция, унаследовавшая право соседки
      // копипастой, красит именно эту строку и называет себя. Тот же приём,
      // каким устроены раскладки в `wire_access_test.dart`.
      const expected = <String, String>{
        'sale.ping': PermissionKeys.navSale,
        'sale.start': PermissionKeys.navSale,
        'sale.cart': PermissionKeys.navSale,
        'sale.deferredList': PermissionKeys.opDeferSale,
        'sale.search': PermissionKeys.navSale,
        'sale.addByBarcode': PermissionKeys.navSale,
        'sale.addProduct': PermissionKeys.navSale,
        'sale.setQuantity': PermissionKeys.navSale,
        'sale.increment': PermissionKeys.navSale,
        'sale.decrement': PermissionKeys.navSale,
        'sale.setMark': PermissionKeys.navSale,
        'sale.removeLine': PermissionKeys.navSale,
        'sale.clear': PermissionKeys.navSale,
        'sale.setAgent': PermissionKeys.navSale,
        // Задача 44: условия правки строки. Чтение, а не уступка: право
        // скидки проверяют команды скидки, а предел показать нужно и
        // кассиру без права — чтобы отказ не был первым, что он узнал.
        'sale.editTerms': PermissionKeys.navSale,
        // Задача 45: быстрые товары — чтение того, что кассир и так продаёт
        // поиском, под тем же правом, что и поиск.
        'sale.quickCategories': PermissionKeys.navSale,
        'sale.quickItems': PermissionKeys.navSale,

        'sale.setDiscountPercent': PermissionKeys.opSellDiscount,
        'sale.setDiscountAmount': PermissionKeys.opSellDiscount,
        'sale.updatePrice': PermissionKeys.opEditPrice,
        'sale.setWholesale': PermissionKeys.opEditPrice,
        'sale.defer': PermissionKeys.opDeferSale,
        'sale.loadDeferred': PermissionKeys.opDeferSale,
      };

      expect(
        {for (final op in SaleOps.all) op.name: needs(op)},
        expected,
        reason:
            'раскладка прав продажи разошлась с закреплённой: слева — что '
            'объявлено каталогом, справа — что решено брифом задачи 9',
      );
    });

    test('ни одна операция продажи не сверяет terminalId из тела', () {
      // `terminalId` в теле команды корзины не едет вовсе — его берёт из
      // сеанса обработчик (задача 10), а контракт корзины прямо требует
      // **отвергать** кадр, в котором имя рабочего места названо
      // (`CartService`, правило 1). Значит и `ownTerminal` сторожу здесь
      // нечего сверять: он потребовал бы `terminalId` в теле и отказал бы
      // каждой команде.
      for (final op in SaleOps.all) {
        expect(
          (op.access as SessionAccess).ownTerminal,
          isNull,
          reason: op.name,
        );
      }
    });
  });

  group('каталог', () {
    test('операций ровно двадцать три, и все они sale.*', () {
      expect(SaleOps.all, hasLength(23));
      for (final op in SaleOps.all) {
        expect(op.name, startsWith('sale.'), reason: op.name);
      }
    });

    test('имена уникальны', () {
      final names = SaleOps.all.map((op) => op.name).toList();
      expect(names.toSet(), hasLength(names.length), reason: '$names');
    });

    test(
      'каждая объявленная операция входит и в SaleOps.all, и в TillOps.all',
      () {
        // Забытая в списке операция уходит от каждой проверки этого файла и —
        // хуже — от словаря доступа кассы (`ApiServer.access` строится из
        // `TillOps.all`): сторож не нашёл бы её имени и ответил `unknown_op`.
        const declared = <WireOp<Object?, Object?>>[
          SaleOps.salePing,
          SaleOps.start,
          SaleOps.cart,
          SaleOps.deferredList,
          SaleOps.search,
          SaleOps.addByBarcode,
          SaleOps.addProduct,
          SaleOps.setQuantity,
          SaleOps.increment,
          SaleOps.decrement,
          SaleOps.setDiscountPercent,
          SaleOps.setDiscountAmount,
          SaleOps.editTerms,
          SaleOps.quickCategories,
          SaleOps.quickItems,
          SaleOps.updatePrice,
          SaleOps.setMark,
          SaleOps.removeLine,
          SaleOps.clear,
          SaleOps.defer,
          SaleOps.loadDeferred,
          SaleOps.setAgent,
          SaleOps.setWholesale,
        ];

        expect(SaleOps.all.toSet(), declared.toSet());
        expect(TillOps.all.toSet(), containsAll(declared));
      },
    );

    test(
      'корзина и отложенные — подписки, остальные девятнадцать — вопросы',
      () {
        // Ровно та выгода, ради которой менялся транспорт: корзина, изменённая
        // соседней вкладкой того же рабочего места, и чек, отложенный соседом,
        // обязаны доехать в момент события. Всё прочее — действия, а не
        // состояния, за которыми следят.
        expect(SaleOps.all.whereType<Watch>().map((op) => op.name).toSet(), {
          'sale.cart',
          'sale.deferredList',
        });
        expect(SaleOps.all.whereType<Ask>(), hasLength(21));
        expect(SaleOps.all.whereType<Run>(), isEmpty);
      },
    );

    test('каждый метод контракта корзины имеет свою операцию', () {
      // `CartService` — 16 команд, две подписки и поиск. Договор, у которого
      // на проводе нет одного метода, — это биндинг, отказывающий в одном
      // месте из девятнадцати, и узнать об этом можно только нажав кнопку.
      final names = SaleOps.all.map((op) => op.name).toSet();

      expect(
        names,
        containsAll(<String>[
          'sale.cart', // CartService.watch
          'sale.deferredList', // .watchDeferred
          'sale.search', // .search
          'sale.start', // .start
          'sale.addByBarcode', // .addByBarcode
          'sale.addProduct', // .addProduct
          'sale.setQuantity', // .setQuantity
          'sale.increment', // .increment
          'sale.decrement', // .decrement
          'sale.setDiscountPercent', // .setDiscountPercent
          'sale.setDiscountAmount', // .setDiscountAmount
          'sale.updatePrice', // .updatePrice
          'sale.setMark', // .setMark
          'sale.removeLine', // .removeLine
          'sale.clear', // .clear
          'sale.defer', // .defer
          'sale.loadDeferred', // .loadDeferred
          'sale.setAgent', // .setAgent
          'sale.setWholesale', // .setWholesale
        ]),
      );
    });
  });

  group('тело запроса', () {
    test('метка команды едет с каждой изменяющей командой', () {
      // Ключ повтора, версия и номер чека — три правила контракта корзины
      // (докстринг `CartService`). Команда без метки не отличима от повтора
      // и применяется поверх чужого изменения вслепую.
      final bodies = <String, Map<String, Object?>>{
        // Круг правки 1 задачи 10: у `sale.start` больше нет признака
        // опта — он был обходом права `op.editPrice` (докстринг операции).
        // Тело её теперь одна метка.
        'sale.start': SaleOps.start.encode(meta),
        'sale.addByBarcode': SaleOps.addByBarcode.encode((
          barcode: '4870001234567',
          meta: meta,
        )),
        'sale.addProduct': SaleOps.addProduct.encode((
          productId: 42,
          quantity: Decimal.one,
          meta: meta,
        )),
        'sale.setQuantity': SaleOps.setQuantity.encode((
          lineId: 'l1',
          quantity: Decimal.fromInt(2),
          meta: meta,
        )),
        'sale.increment': SaleOps.increment.encode((lineId: 'l1', meta: meta)),
        'sale.decrement': SaleOps.decrement.encode((lineId: 'l1', meta: meta)),
        'sale.setDiscountPercent': SaleOps.setDiscountPercent.encode((
          lineId: 'l1',
          percent: Decimal.fromInt(10),
          meta: meta,
        )),
        'sale.setDiscountAmount': SaleOps.setDiscountAmount.encode((
          lineId: 'l1',
          amount: Decimal.fromInt(50),
          meta: meta,
        )),
        'sale.updatePrice': SaleOps.updatePrice.encode((
          lineId: 'l1',
          price: Decimal.fromInt(199),
          meta: meta,
        )),
        'sale.setMark': SaleOps.setMark.encode((
          lineId: 'l1',
          mark: '0104870',
          meta: meta,
        )),
        'sale.removeLine': SaleOps.removeLine.encode((
          lineId: 'l1',
          meta: meta,
        )),
        'sale.clear': SaleOps.clear.encode(meta),
        'sale.defer': SaleOps.defer.encode(meta),
        'sale.loadDeferred': SaleOps.loadDeferred.encode((
          receiptNo: 9,
          meta: meta,
          deferredPosId: null,
        )),
        'sale.setAgent': SaleOps.setAgent.encode((agentId: 3, meta: meta)),
        'sale.setWholesale': SaleOps.setWholesale.encode((
          wholesale: true,
          meta: meta,
        )),
      };

      expect(
        bodies,
        hasLength(16),
        reason: 'команд контракта ровно шестнадцать',
      );

      for (final entry in bodies.entries) {
        expect(entry.value['key'], 'k1', reason: entry.key);
        expect(entry.value['baseVersion'], 3, reason: entry.key);
        expect(entry.value['receiptNo'], 17, reason: entry.key);
        expect(
          entry.value.containsKey('terminalId'),
          isFalse,
          reason:
              '${entry.key}: имя рабочего места в теле — то, что контракт '
              'корзины требует ОТВЕРГАТЬ, а не то, что терминал шлёт сам',
        );
      }
    });

    test('деньги в теле команды едут строкой, а не числом', () {
      // Инвариант I159. Число здесь потеряло бы точность молча — и не на
      // экране, а в чеке.
      expect(
        SaleOps.setDiscountAmount.encode((
          lineId: 'l1',
          amount: Decimal.parse('1234.567'),
          meta: meta,
        ))['amount'],
        '1234.567',
      );
      expect(
        SaleOps.updatePrice.encode((
          lineId: 'l1',
          price: Decimal.parse('0.001'),
          meta: meta,
        ))['price'],
        '0.001',
      );
      expect(
        SaleOps.setQuantity.encode((
          lineId: 'l1',
          quantity: Decimal.parse('1.5'),
          meta: meta,
        ))['quantity'],
        '1.5',
      );
      expect(
        SaleOps.setDiscountPercent.encode((
          lineId: 'l1',
          percent: Decimal.parse('12.5'),
          meta: meta,
        ))['percent'],
        '12.5',
      );
    });

    test('поднимаемый чек назван своим ключом, а не ключом метки', () {
      // Ловушка контракта (`CartService.loadDeferred`): `meta.receiptNo` —
      // чек, который у рабочего места УЖЕ есть, а поднимаемый — отдельный
      // довод. Положи их одним именем — метка затёрла бы номер, и команда
      // подняла бы не тот чек (или получила бы `cart_wrong_receipt`).
      final body = SaleOps.loadDeferred.encode((receiptNo: 9, meta: meta, deferredPosId: null));

      expect(body['deferredReceiptNo'], 9);
      expect(body['receiptNo'], 17, reason: 'метка осталась своей');
    });

    test('чек без номера метится null, а не нулём', () {
      // `receiptNo == null` значит «чека у меня нет» — так метит команду
      // рабочее место, начинающее первый чек. Ноль — настоящий номер чека,
      // и подставить его вместо «нет» значит адресовать команду чужому чеку.
      const cold = CartCommandMeta(key: 'k2', baseVersion: 0, receiptNo: null);
      final body = SaleOps.start.encode(cold);

      expect(body['receiptNo'], isNull);
      expect(body.containsKey('receiptNo'), isTrue);
    });

    test('подписки и поиск шлют то, что им нужно, и ничего сверх', () {
      expect(SaleOps.cart.encode(null), isEmpty);
      expect(SaleOps.deferredList.encode(null), isEmpty);
      expect(SaleOps.search.encode('молоко'), {'query': 'молоко'});
      expect(SaleOps.salePing.encode('4870001234567'), {
        'barcode': '4870001234567',
      });
    });

    test('снятие агента едет явным null, а не пропущенным полем', () {
      // `setAgent(terminalId, null, meta)` — это команда «убрать агента», а
      // не «поле забыли». Пропущенный ключ обработчик не отличил бы от
      // первого от второго.
      final body = SaleOps.setAgent.encode((agentId: null, meta: meta));
      expect(body.containsKey('agentId'), isTrue);
      expect(body['agentId'], isNull);
    });
  });

  group('разбор ответа', () {
    test('каждая команда разбирает снимок той же парой, что его и пишет', () {
      // Операция не заводит второго читателя формы: её `decode` зовёт
      // `cartViewFromWireJson` — ту же половину пары, которой касса пишет
      // ответ (задача 6).
      final view = CartView(
        posId: 1,
        terminalId: 7,
        version: 4,
        wholesale: true,
        receiptNo: 17,
        agentId: 3,
        lines: [
          CartLine.manualDiscount(
            id: 'l1',
            productId: 42,
            name: 'Молоко',
            quantity: Decimal.parse('2'),
            price: Decimal.parse('450.5'),
            discount: Decimal.parse('50'),
            barcode: '4870001234567',
          ),
        ],
      );
      final body = cartViewToWireJson(view);

      final commands = <String, CartView Function(Map<String, Object?>)>{
        'sale.start': SaleOps.start.decode,
        'sale.cart': SaleOps.cart.decode,
        'sale.addByBarcode': SaleOps.addByBarcode.decode,
        'sale.addProduct': SaleOps.addProduct.decode,
        'sale.setQuantity': SaleOps.setQuantity.decode,
        'sale.increment': SaleOps.increment.decode,
        'sale.decrement': SaleOps.decrement.decode,
        'sale.setDiscountPercent': SaleOps.setDiscountPercent.decode,
        'sale.setDiscountAmount': SaleOps.setDiscountAmount.decode,
        'sale.updatePrice': SaleOps.updatePrice.decode,
        'sale.setMark': SaleOps.setMark.decode,
        'sale.removeLine': SaleOps.removeLine.decode,
        'sale.clear': SaleOps.clear.decode,
        'sale.defer': SaleOps.defer.decode,
        'sale.loadDeferred': SaleOps.loadDeferred.decode,
        'sale.setAgent': SaleOps.setAgent.decode,
        'sale.setWholesale': SaleOps.setWholesale.decode,
      };

      for (final entry in commands.entries) {
        expect(entry.value(body), view, reason: entry.key);
      }
    });

    test('список отложенных разбирается той же парой', () {
      final card = DeferredCart(
        receiptNo: 12,
        posId: 1,
        total: Decimal.parse('1350.75'),
        lineCount: 3,
        userId: 4,
        userName: 'Айгуль',
        firstLineName: 'Молоко',
      );

      final decoded = SaleOps.deferredList.decode(
        deferredListToWireJson([card]),
      );

      expect(decoded, [card]);
    });

    test('пустой пул отложенных — пустой список, а не отказ', () {
      // Пустой пул — обычное состояние кассы, а не беда: список отложенных
      // открывают чаще, чем откладывают.
      expect(SaleOps.deferredList.decode(const {}), isEmpty);
    });

    test('выдача поиска разбирается той же парой — объект целиком', () {
      // Круг правки 1: сверка **всего объекта**, а не пяти полей руками.
      // Прежняя форма не проверяла `measure` и `isDeleted` ничем, и
      // диверсия разбора (декодер прибит к `measure: 0`) оставляла 171 тест
      // зелёным. Ненулевая мера — весовой товар; её потеря делает весовой
      // товар штучным на терминале.
      final found = ProductSearchResult(
        id: 42,
        name: 'Молоко 3.2%',
        price: Decimal.parse('450.5'),
        barcode: '4870001234567',
        stock: Decimal.parse('12'),
        measure: 2,
        isDeleted: true,
      );

      final decoded = SaleOps.search.decode(searchResultsToWireJson([found]));

      expect(decoded, [found]);
    });

    test('весовой товар остаётся весовым — мера едет по проводу', () {
      // Отдельная проба поверх сверки объекта: она называет последствие, а
      // не только несовпадение полей.
      final weighted = ProductSearchResult(
        id: 7,
        name: 'Яблоки',
        price: Decimal.parse('890'),
        measure: 2,
      );

      final decoded = SaleOps.search.decode(
        searchResultsToWireJson([weighted]),
      );

      expect(decoded.single.measure, 2);
    });

    test('неизвестный остаток товара остаётся неизвестным, а не нулём', () {
      // Ноль в остатке значит «нет на складе» и красит строку поиска;
      // отсутствие сведений — не то же самое. Тело собрано вручную нарочно:
      // именно так его напишет обработчик кассы, если остатка нет.
      final decoded = SaleOps.search.decode({
        searchResultsKey: [
          {'id': 1, 'name': 'Пакет', 'price': '20', 'measure': 0},
        ],
      });

      expect(decoded.single.stock, isNull);
    });

    test('известный остаток переживает круг, неизвестный не выдумывается', () {
      // Круг правки 1 свёл `stock` с тернарного выбора на условный ключ —
      // ради сторожа денег. Проба закрепляет, что смысл при этом не
      // изменился: ключа нет ⇔ остаток неизвестен.
      final known = ProductSearchResult(
        id: 1,
        name: 'Пакет',
        price: Decimal.parse('20'),
        stock: Decimal.parse('4.5'),
      );
      const unknown = null;

      final body = productSearchResultToWireJson(known);
      expect(body['stock'], '4.5');
      expect(
        productSearchResultToWireJson(
          ProductSearchResult(
            id: 1,
            name: 'Пакет',
            price: Decimal.parse('20'),
            stock: unknown,
          ),
        ).containsKey('stock'),
        isFalse,
        reason: 'неизвестный остаток не едет ключом вовсе',
      );
      expect(productSearchResultFromWireJson(body), known);
    });
  });

  group('конверты списков — общие пары, а не литерал на каждой стороне', () {
    // Круг правки 1. Имя конверта, написанное рукой на кассовой стороне,
    // расходится с терминальной МОЛЧА: `decode` не находит ключа и отдаёт
    // пустой список, неотличимый от честного «пул пуст» / «ничего не
    // найдено». Измерено разбором до правки.
    test('чужое имя конверта отдаёт пустой список — вот цена расхождения', () {
      final card = DeferredCart(
        receiptNo: 12,
        posId: 1,
        total: Decimal.parse('1'),
        lineCount: 1,
        userId: 4,
      );

      expect(
        SaleOps.deferredList.decode({
          'deferredCarts': [deferredCartToWireJson(card)],
        }),
        isEmpty,
        reason:
            'разбор МОЛЧИТ при чужом имени конверта — поэтому имя обязано '
            'быть общей константой, а не литералом на каждой стороне',
      );
      expect(
        SaleOps.search.decode({
          'items': [
            {'id': 1, 'name': 'x', 'price': '1'},
          ],
        }),
        isEmpty,
      );
    });

    test('имена конвертов — те, которыми пишет кассовая половина пары', () {
      expect(deferredListToWireJson(const []).keys.single, deferredListKey);
      expect(searchResultsToWireJson(const []).keys.single, searchResultsKey);
    });

    test('пустой конверт переживает круг как пустой список', () {
      expect(
        SaleOps.deferredList.decode(deferredListToWireJson(const [])),
        isEmpty,
      );
      expect(SaleOps.search.decode(searchResultsToWireJson(const [])), isEmpty);
    });
  });

  group('метка команды — пара, а не два рукописных разбора', () {
    test('метка переживает круг по проводу без потерь', () {
      expect(
        cartCommandMetaFromWireJson(cartCommandMetaToWireJson(meta)),
        meta,
      );
    });

    test('холодная метка переживает круг тем же способом', () {
      const cold = CartCommandMeta(key: 'k2', baseVersion: 0, receiptNo: null);
      expect(
        cartCommandMetaFromWireJson(cartCommandMetaToWireJson(cold)),
        cold,
      );
    });

    test('пропущенный receiptNo читается как «чека нет»', () {
      // Тело, собранное вручную (пример брифа задачи 10 — `{'wholesale':
      // false, 'key': 'k1', 'baseVersion': 0}`), номера чека не несёт вовсе.
      final decoded = cartCommandMetaFromWireJson(const {
        'key': 'k1',
        'baseVersion': 0,
      });

      expect(decoded.receiptNo, isNull);
      expect(decoded.baseVersion, 0);
    });
  });
}
