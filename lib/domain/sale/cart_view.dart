import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';
import 'package:telepos/domain/discount/discount_origin.dart';

/// Сведения о команде, применённой к корзине — задача 6 плана «Продажа с
/// браузерного терминала».
///
/// [key] — ключ повтора: тот же ключ от того же терминала обязан дать тот же
/// результат и не изменить корзину дважды (терминал может повторить запрос,
/// не дождавшись ответа — обрыв провода, перезагрузка вкладки). [baseVersion]
/// — версия снимка [CartView], от которой посчитана сама команда: касса
/// сверяет её с текущей версией корзины и отказывает, если снимок терминала
/// устарел, вместо того чтобы применить команду поверх чужого изменения
/// вслепую.
/// [receiptNo] — **какой именно чек** терминал видел, когда считал команду.
/// Заведён кругом правки 2 задачи 7, и вот проба, которая его потребовала:
/// команда, посчитанная от чека №1 версии 0, задержалась в проводе; чек №1
/// успели отложить, начать чек №2 — у него версия тоже 0, — и запоздавшая
/// команда **молча легла в чужой чек**. Одной версии для опознания мало по
/// построению: она считает «сколько изменений было у текущего чека», и у
/// каждого нового чека счёт начинается с нуля, поэтому у двух разных чеков
/// версии совпадают постоянно. `null` означает «чека у меня нет» — так
/// команду помечает рабочее место, начинающее первый чек ([CartService
/// .start]) или поднимающее отложенный поверх пустоты.
@immutable
class CartCommandMeta {
  const CartCommandMeta({
    required this.key,
    required this.baseVersion,
    required this.receiptNo,
  });

  /// Ключ повтора: тот же ключ — тот же результат, корзина не меняется дважды.
  final String key;

  /// Версия снимка, от которой посчитана команда.
  final int baseVersion;

  /// Номер чека, от которого посчитана команда; `null` — чека не было.
  final int? receiptNo;

  @override
  bool operator ==(Object other) =>
      other is CartCommandMeta &&
      other.key == key &&
      other.baseVersion == baseVersion &&
      other.receiptNo == receiptNo;

  @override
  int get hashCode => Object.hash(key, baseVersion, receiptNo);
}

/// Одна строка корзины в работе.
///
/// Деньги — `Decimal` P18,S3, никогда `double` (инвариант I159,
/// `global-constraints.md`): [price], [quantity], [discount] и производные от
/// них теряли бы точность молча, будь они `double`.
@immutable
class CartLine {
  const CartLine({
    required this.id,
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
    required this.discounts,
    this.barcode,
    this.mark,
  });

  /// Строка с единственной ручной скидкой — самый частый случай и вся
  /// форма, которая была до задачи 13.
  CartLine.manualDiscount({
    required String id,
    required int productId,
    required String name,
    required Decimal quantity,
    required Decimal price,
    required Decimal discount,
    String? barcode,
    String? mark,
  }) : this(
         id: id,
         productId: productId,
         name: name,
         quantity: quantity,
         price: price,
         discounts: discount > Decimal.zero
             ? [CartDiscount.manual(discount)]
             : const <CartDiscount>[],
         barcode: barcode,
         mark: mark,
       );

  /// Идентификатор строки внутри корзины — не идентификатор товара:
  /// один и тот же товар может лежать в корзине двумя строками (разная
  /// маркировка, разная партия).
  final String id;

  final int productId;

  final String name;

  final Decimal quantity;

  final Decimal price;

  /// Скидки строки **по происхождению** — задача 13, шаг 4.
  ///
  /// Список, а не число: подарок акции и уступка кассира — разные деньги с
  /// разной судьбой в отчёте, и сложенные в одну разность они перестают
  /// различаться навсегда. Браузерный экран обязан показывать «скидка
  /// кассира 50 / подарок акции 100» раздельно, а проданный чек — помнить
  /// это и после закрытия смены (`SaleDiscounts`).
  ///
  /// Пустой список означает «скидки нет». Не `null`: отсутствие списка и
  /// пустой список отвечали бы на один вопрос двумя способами.
  final List<CartDiscount> discounts;

  /// Скидка на строку целиком, не на единицу — **сумма всех источников**.
  ///
  /// Геттер, а не поле: старый читатель, которому происхождение не нужно,
  /// не тронут этой правкой ни одной строкой.
  Decimal get discount =>
      discounts.fold(Decimal.zero, (sum, d) => sum + d.amount);

  final String? barcode;

  /// Код маркировки (Data Matrix), если товар маркируемый. `null` иначе.
  final String? mark;

  Decimal get subtotal => price * quantity;

  Decimal get total => subtotal - discount;

  /// Сравнение по значению — тем же приёмом, что [CartCommandMeta].
  ///
  /// Круг правки 1 задачи 6 (2026-09-06): без него задачи 7 и 12 сравнивали
  /// бы снимки (`Stream<CartView>` в подписке, ожидание в тесте) по ссылке
  /// — два одинаковых по содержимому снимка, собранных двумя разными
  /// вызовами кодека, никогда не совпали бы, и `expect(view, expectedView)`
  /// красил бы тест, у которого на самом деле всё верно.
  @override
  bool operator ==(Object other) =>
      other is CartLine &&
      other.id == id &&
      other.productId == productId &&
      other.name == name &&
      other.quantity == quantity &&
      other.price == price &&
      // По списку, а не по сумме: две строки со скидкой 100 — одна
      // ручной, другая акционной — **не одинаковы**, и снимок, который
      // счёл бы их равными, не обновил бы экран после смены
      // происхождения.
      _sameDiscounts(other.discounts, discounts) &&
      other.barcode == barcode &&
      other.mark == mark;

  static bool _sameDiscounts(List<CartDiscount> a, List<CartDiscount> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    productId,
    name,
    quantity,
    price,
    Object.hashAll(discounts),
    barcode,
    mark,
  );
}

/// Одна скидка строки: сколько и **откуда**.
@immutable
final class CartDiscount {
  const CartDiscount({
    required this.origin,
    required this.amount,
    this.sourceId,
  });

  /// Уступка кассира: происхождение известно, источника у неё нет.
  const CartDiscount.manual(Decimal amount)
    : this(origin: DiscountOrigin.manual, amount: amount);

  /// Подарок акции: источник — строка `Promotions`.
  const CartDiscount.promotion({
    required Decimal amount,
    required int promotionId,
  }) : this(
         origin: DiscountOrigin.promotion,
         amount: amount,
         sourceId: promotionId,
       );

  /// [DiscountOrigin].
  final int origin;

  /// Сколько снято со строки целиком, не с единицы. Деньги P18,S3 (I159).
  final Decimal amount;

  /// Что именно её дало: акция, правило, программа. `null` у ручной —
  /// у неё источника нет, и подставлять ноль значило бы указать на
  /// несуществующую строку справочника.
  final int? sourceId;

  @override
  bool operator ==(Object other) =>
      other is CartDiscount &&
      other.origin == origin &&
      other.amount == amount &&
      other.sourceId == sourceId;

  @override
  int get hashCode => Object.hash(origin, amount, sourceId);

  @override
  String toString() =>
      '${DiscountOrigin.nameOf(origin)} $amount'
      '${sourceId == null ? '' : ' (#$sourceId)'}';
}

/// Снимок корзины в работе — то, что касса отдаёт браузерному терминалу и
/// принимает обратно вместе с [CartCommandMeta].
///
/// [version] — версия снимка. Растёт на каждое применённое к корзине
/// изменение; это то самое поле, с которым сверяется [CartCommandMeta
/// .baseVersion] — задача 5 (`Sales.cartVersion`).
@immutable
class CartView {
  const CartView({
    required this.posId,
    required this.terminalId,
    required this.version,
    required this.lines,
    required this.wholesale,
    this.receiptNo,
    this.agentId,
  });

  final int posId;

  /// Владелец чека в работе — терминал, который его ведёт (задача 3,
  /// `Sales.terminalId`). Только этому терминалу касса разрешает менять
  /// корзину; чужой терминал получает отказ, а не чужую корзину.
  final int terminalId;

  final int version;

  final List<CartLine> lines;

  /// Отпуск оптом — влияет на то, какая цена товара берётся строкой.
  final bool wholesale;

  /// `null`, пока чек не закреплён номером (`ReceiptNumbers.withNext`).
  final int? receiptNo;

  /// Агент (представитель поставщика), если продажа оформлена на него.
  final int? agentId;

  Decimal get subtotal => lines.fold(Decimal.zero, (s, l) => s + l.subtotal);

  Decimal get totalDiscount =>
      lines.fold(Decimal.zero, (s, l) => s + l.discount);

  Decimal get total => subtotal - totalDiscount;

  /// Сравнение по значению, включая строки — вручную, поэлементно: список
  /// `==` в Dart сравнивает по ссылке, а не по содержимому (круг правки 1
  /// задачи 6, тот же повод, что у сравнения [CartLine]).
  @override
  bool operator ==(Object other) {
    if (other is! CartView) return false;
    if (other.posId != posId ||
        other.terminalId != terminalId ||
        other.version != version ||
        other.wholesale != wholesale ||
        other.receiptNo != receiptNo ||
        other.agentId != agentId ||
        other.lines.length != lines.length) {
      return false;
    }
    for (var i = 0; i < lines.length; i++) {
      if (other.lines[i] != lines[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    posId,
    terminalId,
    version,
    wholesale,
    receiptNo,
    agentId,
    Object.hashAll(lines),
  );
}

/// Отложенный чек в общем пуле — карточка для списка, не полный снимок.
///
/// Заведён задачей 6 под контракт задачи 7 (`Stream<List<DeferredCart>>
/// watchDeferred()`); **состав полей — решение задачи 7**, принятое здесь
/// вместе с реализацией списка, и вот из чего оно сделано.
///
/// # Что решает кассир этим списком
///
/// Один вопрос: **«который из них мой»**. Общий пул (решение 3 спеки) —
/// это чеки нескольких рабочих мест вперемешку; кассир пришёл забрать
/// свой, отложенный три минуты назад, а не выбрать чек вообще.
///
/// Сегодня в дереве живой диалог отложенных чеков показывает **номер и
/// сумму** (`deferred_sales_dialog.dart`), а мёртвый (никем не
/// вызываемый) — ещё имя клиента и комментарий. Ни того, ни другого не
/// хватает: два чека на одну сумму в общем пуле неразличимы, а клиент и
/// комментарий в рознице обычно пусты.
///
/// # Что вошло и почему
///
/// - [receiptNo], [posId] — ключ чека, им его и поднимают.
/// - [total] — сумма, `Decimal` P18,S3 (никогда `double`).
/// - [lineCount] — сколько строк; «мой был на три позиции».
/// - [userId] + [userName] — **кассир, начавший чек** (`Sales.userId`).
///   Главный различитель в общем пуле: свой чек узнаётся по себе, а не
///   по сумме. Имя приходит готовым, чтобы список не ходил в `Users` за
///   каждой карточкой на экране.
/// - [firstLineName] — имя первой строки чека («тот, что с молоком»).
///   Второй по силе различитель, и единственный, работающий, когда чеки
///   отложены одним кассиром.
///
/// # Чего в карточке нет и почему — время
///
/// **Прежнее обоснование было неверным, и это переписано кругом правки 2.**
/// Оно говорило, что настоящее время у отложенного чека утекло бы в
/// денежные итоги, потому что те суммируют по времени без фильтра по
/// состоянию. Первая половина была верна ровно до тех пор, пока тот же
/// круг правки её не починил (`SaleDao.amountOfShift`,
/// `sumAmountByCustomerLocalId` теперь исключают состояния 0 и 3); вторая
/// была неверна изначально — отчётные выборки (`report_dao.dart`:
/// `getTotalRevenue`, `getRevenueByDay`, `getIncomeForPeriod`) несут
/// `state <> 3` и отложенный чек не считали никогда. Обоснование от
/// дефекта отпало вместе с дефектом, и состав обоснован заново — от
/// продукта.
///
/// **Время не возвращается, потому что его негде взять честно.**
/// `Sales.time` значит «когда продажа совершена». У отложенного чека
/// такого момента нет: он не совершён, и завершение перепишет колонку
/// своим временем. Положить туда момент откладывания — дать колонке
/// второй смысл, о котором ни один её читатель не знает; понадобится
/// время в списке — правильный ход это своя колонка `deferredAt`,
/// отдельной миграцией, а не второй смысл у чужой.
///
/// А для самого вопроса «который из них мой» время и не нужно: в пуле из
/// трёх-пяти чеков «14:32» различает хуже, чем имя кассира и первый
/// товар. Хронологию даёт [receiptNo] — он растёт последовательно, и
/// список отсортирован по нему.
@immutable
class DeferredCart {
  const DeferredCart({
    required this.receiptNo,
    required this.posId,
    required this.total,
    required this.lineCount,
    required this.userId,
    this.userName,
    this.firstLineName,
  });

  final int receiptNo;

  final int posId;

  final Decimal total;

  final int lineCount;

  /// Кассир, начавший чек (`Sales.userId`).
  final int userId;

  /// Его имя, если оно известно (`Users.name` допускает пустоту).
  final String? userName;

  /// Имя первой строки чека — `null`, если чек отложен пустым или товар
  /// исчез из каталога.
  final String? firstLineName;

  /// Сравнение по значению — тем же приёмом, что [CartCommandMeta] и
  /// [CartLine] (круг правки 1 задачи 6).
  @override
  bool operator ==(Object other) =>
      other is DeferredCart &&
      other.receiptNo == receiptNo &&
      other.posId == posId &&
      other.total == total &&
      other.lineCount == lineCount &&
      other.userId == userId &&
      other.userName == userName &&
      other.firstLineName == firstLineName;

  @override
  int get hashCode => Object.hash(
    receiptNo,
    posId,
    total,
    lineCount,
    userId,
    userName,
    firstLineName,
  );
}
