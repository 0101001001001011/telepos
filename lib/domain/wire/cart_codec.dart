/// Кодеки продажи: снимок корзины (`CartView`), метка команды
/// (`CartCommandMeta`), карточка отложенного чека (`DeferredCart`) и строка
/// выдачи поиска (`ProductSearchResult`) — в форму, идущую по проводу, и
/// обратно.
///
/// Снимок и строка корзины заведены задачей 6; остальные три пары добавила
/// задача 9 вместе с каталогом `SaleOps` — по одной причине на каждую: у
/// операции провода `decode` обязан звать **готовую половину пары**, а не
/// писать разбор заново. Иначе каталог операций стал бы ровно тем вторым
/// читателем формы, ради устранения которого пары и сводились
/// (`till_ops.dart`, «Разбор ответа не пишется здесь заново»).
///
/// **Деньги — строкой, никогда числом (инвариант I159).** Каждое денежное
/// поле кладётся через единственную разрешённую дверь — [wireMoney]
/// (`wire_money.dart`, круг правки 2 задачи 6) — и читается через
/// `Decimal.parse`. Сторож (`test/architecture/money_over_wire_test.dart`)
/// проверяет не «значение не похоже на число» (два предыдущих круга этой
/// задачи показали, что таким текстовым эвристикам всегда есть форма,
/// которая пройдёт мимо — `roundToDouble()`, голая переменная, выражение,
/// целый литерал, склейка/цепочка вызовов после двери), а **что значение —
/// буквально вызов `wireMoney(...)`, и ничто иное**: правило денег на
/// проводе нигде в проекте раньше не действовало (`ProgressFrame.value`,
/// `wire_frame.dart`, едет `double`, но это доля выполнения, не деньги) —
/// сторож рядом вводит его впервые.
library;

import 'package:decimal/decimal.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/product_search_result.dart';
import 'package:telepos/core/constants/enums/tax_treatment.dart';
import 'package:telepos/domain/wire/wire_money.dart';

Map<String, Object?> cartViewToWireJson(CartView view) => {
  'posId': view.posId,
  'terminalId': view.terminalId,
  'version': view.version,
  'wholesale': view.wholesale,
  'receiptNo': view.receiptNo,
  'agentId': view.agentId,
  // Уклад едет по проводу, а не выводится на той стороне из страны:
  // последнее слово о нём за настройкой кассы, а терминал её не видит.
  // Без него браузерный терминал посчитал бы итог без налога сверху и
  // показал покупателю сумму меньше той, что возьмёт касса.
  'taxTreatment': view.taxTreatment.index,
  'lines': view.lines.map(_lineToWireJson).toList(),
  'subtotal': wireMoney(view.subtotal),
  'totalDiscount': wireMoney(view.totalDiscount),
  'taxOnTop': wireMoney(view.taxOnTop),
  'total': wireMoney(view.total),
};

CartView cartViewFromWireJson(Map<String, Object?> json) => CartView(
  posId: json['posId']! as int,
  terminalId: json['terminalId']! as int,
  version: json['version']! as int,
  wholesale: json['wholesale']! as bool,
  receiptNo: json['receiptNo'] as int?,
  agentId: json['agentId'] as int?,
  // Умолчание — «налог включён в цену»: так считали все кассы до этой
  // правки, и кадр от старой стороны обязан читаться так же.
  taxTreatment: TaxTreatment.values[(json['taxTreatment'] as int?) ?? 0],
  lines: (json['lines']! as List)
      .map((e) => _lineFromWireJson(e! as Map<String, Object?>))
      .toList(),
  // subtotal/totalDiscount/total не читаются обратно — это производные
  // геттеры CartView, а не независимое состояние; на проводе они едут
  // только для того, чтобы терминал мог показать итог, не пересчитывая
  // сумму по всем строкам сам.
);

Map<String, Object?> _lineToWireJson(CartLine line) => {
  'id': line.id,
  'productId': line.productId,
  'name': line.name,
  'quantity': wireMoney(line.quantity),
  'price': wireMoney(line.price),
  // `discount` едет **и суммой, и разложением**, и это не дубль по
  // недосмотру. Сумма — то, что читает вкладка прежней сборки: снимок
  // обязан оставаться понятным терминалу, который про происхождение ещё
  // не знает. Разложение — то, ради чего задача 13 и делалась: экран
  // обязан показать «скидка кассира 50 / подарок акции 100» раздельно.
  // Обратно читается **только разложение** — иначе у одного числа
  // появилось бы два источника истины.
  'discount': wireMoney(line.discount),
  'discounts': [
    for (final d in line.discounts)
      {
        'origin': d.origin,
        'amount': wireMoney(d.amount),
        if (d.sourceId != null) 'sourceId': d.sourceId,
      },
  ],
  'barcode': line.barcode,
  'mark': line.mark,
  // Ключ ОТСУТСТВУЕТ, когда ставки нет, а не едет с `null`.
  //
  // Так требует сторож денег на проводе: значение денежного ключа обязано
  // начинаться с `wireMoney(`, иначе условная форма однажды провезёт
  // `double`. Отсутствие ключа и читается как «налог не настроен» — тот же
  // смысл, что у `null`, только выразимый.
  if (line.taxRatePercent != null)
    'taxRatePercent': wireMoney(line.taxRatePercent!),
  'isTaxExempt': line.isTaxExempt,
  'subtotal': wireMoney(line.subtotal),
  'total': wireMoney(line.total),
};

/// Метка команды корзины — задача 9.
///
/// **Едет плоско, рядом с доводами команды, а не вложенным объектом.** Это
/// не украшение: тело команды разбирает обработчик кассы (задача 10), и
/// плоская форма позволяет ему прочитать метку одним вызовом независимо от
/// того, какая это команда, — вложенный объект заставил бы каждый
/// обработчик сначала достать его и проверить, что он вообще пришёл
/// объектом.
///
/// `receiptNo` кладётся **всегда**, в том числе значением `null`. Пустое
/// значение здесь — это утверждение «чека у меня нет», а не «поле забыли»
/// (докстринг [CartCommandMeta]); отличать одно от другого по отсутствию
/// ключа — ровно тот молчаливый путь, которого контракт корзины требует
/// избегать.
Map<String, Object?> cartCommandMetaToWireJson(CartCommandMeta meta) => {
  'key': meta.key,
  'baseVersion': meta.baseVersion,
  'receiptNo': meta.receiptNo,
};

/// Обратная половина пары.
///
/// **Пропущенные ключи читаются, а не роняют разбор**, и это разные виды
/// снисходительности: `receiptNo` отсутствует законно (тело, собранное без
/// чека в работе), а `key`/`baseVersion` отсутствовать не должны — но
/// уронить разбор исключением значило бы отдать на провод имя типа вместо
/// названного отказа (I144). Пустой ключ повтора и нулевая версия дальше
/// отвергаются самой кассой: пустой ключ не совпадёт ни с одним
/// запомненным, а версия сверяется с текущей.
CartCommandMeta cartCommandMetaFromWireJson(Map<String, Object?> json) =>
    CartCommandMeta(
      key: json['key'] as String? ?? '',
      baseVersion: json['baseVersion'] as int? ?? 0,
      receiptNo: json['receiptNo'] as int?,
    );

/// Имя конверта, в котором едет список отложенных чеков
/// (`sale.deferredList`).
///
/// **Константа, а не литерал в двух местах — круг правки 1.** Кассовая
/// половина (обработчик задачи 10) и терминальная ([deferredListFromWireJson])
/// обязаны назвать конверт одинаково, и цена расхождения тут молчаливая:
/// `decode` не находит ключа и отдаёт **пустой список**, неотличимый от
/// честного «пул пуст». Измерено разбором: `deferredList.decode({
/// 'deferredCarts': …})` → `[]`, без единого слова. Ровно тот молчаливый
/// путь, которого требует избегать контракт корзины.
const deferredListKey = 'deferred';

/// То же для выдачи поиска (`sale.search`): опечатка в имени конверта даёт
/// «ничего не найдено» вместо отказа.
const searchResultsKey = 'results';

/// Весь список отложенных в конверте — половина пары, которую зовёт касса.
///
/// Пара, а не константа с ручной сборкой на каждой стороне: имя конверта и
/// форма карточки тогда живут в одном месте, и обработчику нечего написать
/// руками.
Map<String, Object?> deferredListToWireJson(List<DeferredCart> carts) => {
  deferredListKey: carts.map(deferredCartToWireJson).toList(),
};

/// Обратная половина: не-список и отсутствие ключа дают пустой список — тем
/// же приёмом, что `TillOps._objectList`. Отказ называет кадр, а не разбор.
List<DeferredCart> deferredListFromWireJson(Map<String, Object?> body) =>
    _objectList(body[deferredListKey]).map(deferredCartFromWireJson).toList();

/// Вся выдача поиска в конверте — половина пары, которую зовёт касса.
Map<String, Object?> searchResultsToWireJson(List<ProductSearchResult> items) =>
    {searchResultsKey: items.map(productSearchResultToWireJson).toList()};

/// Обратная половина.
List<ProductSearchResult> searchResultsFromWireJson(
  Map<String, Object?> body,
) => _objectList(
  body[searchResultsKey],
).map(productSearchResultFromWireJson).toList();

/// Список объектов из того, что пришло на его месте.
List<Map<String, Object?>> _objectList(Object? raw) => raw is List
    ? raw
          .whereType<Map<String, dynamic>>()
          .map((e) => e.cast<String, Object?>())
          .toList()
    : const [];

/// Карточка отложенного чека — задача 9, под подписку `sale.deferredList`.
Map<String, Object?> deferredCartToWireJson(DeferredCart cart) => {
  'receiptNo': cart.receiptNo,
  'posId': cart.posId,
  'total': wireMoney(cart.total),
  'lineCount': cart.lineCount,
  'userId': cart.userId,
  'userName': cart.userName,
  'firstLineName': cart.firstLineName,
  // Чужая корзина помечается кассой, а не планшетом: своего номера
  // кассы планшет не знает.
  'foreign': cart.foreign,
};

DeferredCart deferredCartFromWireJson(Map<String, Object?> json) =>
    DeferredCart(
      receiptNo: json['receiptNo']! as int,
      posId: json['posId']! as int,
      total: Decimal.parse(json['total']! as String),
      lineCount: json['lineCount']! as int,
      userId: json['userId']! as int,
      userName: json['userName'] as String?,
      firstLineName: json['firstLineName'] as String?,
      foreign: json['foreign'] as bool? ?? false,
    );

/// Строка выдачи поиска — задача 9, под `sale.search`.
///
/// **`stock` кладётся только когда он известен, и это круг правки 1.** До
/// него он ехал тернарным выбором (`stock == null ? null : wireMoney(...)`)
/// — форма, которую сторож денег признаёт красной нарочно, — и оставался
/// вне его списка имён вовсе. Круг правки 1 дописал `stock` в список, а
/// форму свёл к условному ключу: значение под ключом теперь **буквально**
/// вызов двери, и сторож его проверяет наравне с ценой.
///
/// Пропущенный ключ и `null` под ключом здесь значат одно и то же —
/// «остаток неизвестен», — поэтому условный ключ ничего не прячет. Это
/// отличает `stock` от `agentId`/`receiptNo` в командах, где `null` —
/// утверждение («агента снять», «чека у меня нет») и потому кладётся всегда.
Map<String, Object?> productSearchResultToWireJson(ProductSearchResult item) =>
    {
      'id': item.id,
      'name': item.name,
      'price': wireMoney(item.price),
      'barcode': item.barcode,
      if (item.stock case final stock?) 'stock': wireMoney(stock),
      'measure': item.measure,
      'isDeleted': item.isDeleted,
    };

/// Обратная половина пары.
///
/// **`stock` остаётся `null`, если его не прислали.** Ноль значит «нет на
/// складе» и красит строку в выдаче; «остаток неизвестен» — не то же самое,
/// и подставлять за него ноль значило бы соврать кассиру о товаре, который
/// на полке есть.
ProductSearchResult productSearchResultFromWireJson(
  Map<String, Object?> json,
) => ProductSearchResult(
  id: json['id']! as int,
  name: json['name']! as String,
  price: Decimal.parse(json['price']! as String),
  barcode: json['barcode'] as String?,
  stock: json['stock'] == null ? null : Decimal.parse(json['stock']! as String),
  measure: json['measure'] as int? ?? 0,
  isDeleted: json['isDeleted'] as bool? ?? false,
);

CartLine _lineFromWireJson(Map<String, Object?> json) => CartLine(
  id: json['id']! as String,
  productId: json['productId']! as int,
  name: json['name']! as String,
  quantity: Decimal.parse(json['quantity']! as String),
  price: Decimal.parse(json['price']! as String),
  // Разбор — в [_discountsFromWireJson]: кадр без разложения при непустой
  // скидке там отказ, а не догадка.
  discounts: _discountsFromWireJson(json),
  barcode: json['barcode'] as String?,
  mark: json['mark'] as String?,
  // subtotal/total той же природы, что и в CartView выше — геттеры, не
  // независимое состояние; читать их обратно означало бы завести второй
  // источник истины для того же числа.
);

/// Разложение скидки строки из кадра.
///
/// **Кадр без разложения и с ненулевой скидкой — отказ, а не догадка.**
/// Такой кадр может прислать только касса другой сборки, и единственные
/// два способа его прочитать — назвать сумму ручной (то есть записать
/// подарок акции в кассира) или потерять её (то есть показать чек, который
/// не сходится сам с собой). Оба тихие. Отказ громкий, и чинится он
/// обновлением кассы, а не догадкой в кодеке.
List<CartDiscount> _discountsFromWireJson(Map<String, Object?> json) {
  final raw = json['discounts'];
  if (raw is List) {
    return [
      for (final e in raw.cast<Map<String, Object?>>())
        CartDiscount(
          origin: e['origin']! as int,
          amount: Decimal.parse(e['amount']! as String),
          sourceId: e['sourceId'] as int?,
        ),
    ];
  }
  final sum = json['discount'];
  if (sum is String && Decimal.parse(sum) > Decimal.zero) {
    throw const FormatException(
      'снимок корзины несёт скидку без разложения по происхождению — '
      'касса и терминал разных сборок',
    );
  }
  return const <CartDiscount>[];
}
