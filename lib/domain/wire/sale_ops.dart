/// Каталог операций продажи с браузерного терминала.
///
/// Двадцать три описания (двадцать второе и двадцать третье —
/// [SaleOps.quickCategories] и [SaleOps.quickItems], задача 45: быстрые
/// товары; двадцать первое — [SaleOps.editTerms], задача 44:
/// условия правки строки до ввода скидки). Задача 1 плана «Продажа с браузерного терминала»
/// (спека 2026-09-06) завела здесь ровно одно — [SaleOps.salePing],
/// наименьший возможный обмен по проводу: штрихкод туда, товар обратно, без
/// единого побочного действия. Цель была не в самом ответе, а в измерении:
/// прежде чем строить остальные операции, нужно было число — сколько стоит
/// один круг по проводу.
///
/// Задача 9 (фаза 3) доводит каталог до двадцати: девятнадцать операций
/// самой продажи — по одной на каждый метод контракта `CartService`
/// (`lib/domain/sale/cart_service.dart`: 16 команд, две подписки, поиск).
/// Все входят в `TillOps.all` одной строкой (`...SaleOps.all`), той же
/// формой, что и остальной каталог: единый список не имеет права знать о
/// делении на файлы, иначе сторож провода (`wire_guard.dart`) видел бы
/// только часть операций.
///
/// # Право объявляется здесь, а не в обработчике
///
/// Это главное, что делает эта задача. Три ключа `op.*` —
/// [PermissionKeys.opSellDiscount], [PermissionKeys.opEditPrice],
/// [PermissionKeys.opDeferSale] — до неё были объявлены, показаны в форме
/// прав, розданы ролям и **не читались ни одной строкой `lib/`**: докстринг
/// `PermissionKeys.opEditPrice` называет это прямо — «владелец, снявший
/// кассиру право, получает ровно ничего». Здесь они впервые становятся
/// доводом операции, то есть тем, что сторож (`WireGuard.check`, ветка
/// [SessionAccess]) проверяет **до** вызова обработчика.
///
/// Требование доводом, а не таблицей на кассе, — тот же приём, которым
/// живёт весь каталог (`wire_access.dart`): таблицу можно забыть, и новая
/// операция оказалась бы открытой; операция без `access` не компилируется
/// вовсе. Раскладка закреплена закрытой таблицей в
/// `test/domain/wire/sale_ops_access_test.dart` — операция, унаследовавшая
/// право соседки копипастой, красит именно свою строку.
///
/// Раскладка: шестнадцать под `nav.sale` (с задачи 44 — и чтение условий
/// правки строки [editTerms], с задачи 45 — два чтения быстрых товаров), две под `op.sellDiscount`
/// ([setDiscountPercent], [setDiscountAmount]), две под `op.editPrice`
/// ([updatePrice], [setWholesale]) и три под `op.deferSale` ([defer],
/// [loadDeferred], [deferredList]).
///
/// **Круг правки 1 передвинул две операции против брифа задачи 9**, и обе
/// правки об одном: право, закрытое наполовину, — не право.
/// [setWholesale] была единственной переоценивающей чек операцией с общим
/// правом, а [deferredList] отдавала весь пул кассы — включая имена
/// кассиров — тому, кому откладывать запрещено. Доводы — в докстрингах
/// самих операций, чтобы следующий не переставил обратно.
///
/// **Восьмой ключ `op.*` — `opCashInOut` — этой работой не подключается и
/// остаётся плацебо.** Он про внесение и изъятие денег из ящика; ни одной
/// операции продажи это не касается, и выдумывать ему читателя здесь
/// значило бы приписать праву смысл, которого у него нет.
///
/// # Чего в теле команды нет: `terminalId`
///
/// Ни одна операция не кладёт в тело имя рабочего места. Его берёт из
/// **сеанса** обработчик кассы (задача 10), а контракт корзины прямо
/// требует **отвергать** кадр, в котором оно названо (`CartService`,
/// правило 1): иначе «назови чужое место — получи его корзину» становится
/// рабочим приёмом. По той же причине ни у одной операции продажи нет
/// [SessionAccess.ownTerminal]: сверять в теле нечего, а потребовав
/// `terminalId`, сторож отказал бы каждой команде.
///
/// # Почему у команд не один общий вход
///
/// Одна операция `sale.command` с полем «какая» была бы короче на
/// восемнадцать объявлений — и стоила бы ровно того, ради чего заведён весь
/// каталог: право проверяется **по имени операции**, до обработчика. Свести
/// команды в одну значит либо дать всем им право самой слабой (скидка без
/// права), либо самой сильной (продажа только тому, кто умеет править
/// цену), либо вернуть проверку внутрь обработчика — туда, где её можно
/// забыть.
library;

import 'package:decimal/decimal.dart';

import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/product_probe.dart';
import 'package:telepos/domain/sale/product_search_result.dart';
import 'package:telepos/domain/sale/quick_product_catalog.dart';
import 'package:telepos/domain/sale/sale_edit_terms.dart';
import 'package:telepos/domain/wire/cart_codec.dart';
import 'package:telepos/domain/wire/quick_products_codec.dart';
import 'package:telepos/domain/wire/sale_terms_codec.dart';
import 'package:telepos/domain/wire/wire_access.dart';
import 'package:telepos/domain/wire/wire_money.dart';
import 'package:telepos/domain/wire/wire_op.dart';

/// Переключить режим отпуска — розница или опт.
///
/// **Единственный читатель с круга правки 1 задачи 10.** До неё эта же
/// форма служила и [SaleOps.start], и разводить их двумя typedef было
/// нельзя иначе как формально (записи в Dart структурны). Довод опта у
/// `start` снят как обход права — см. её докстринг, — и форма осталась у
/// той операции, которой она по смыслу и принадлежит.
typedef CartWholesaleRequest = ({bool wholesale, CartCommandMeta meta});

/// Добавить товар сканированием.
typedef CartBarcodeRequest = ({String barcode, CartCommandMeta meta});

/// Добавить товар из каталога заданным количеством (выбор из выдачи поиска,
/// весовой товар с весов).
typedef CartAddProductRequest = ({
  int productId,
  Decimal quantity,
  CartCommandMeta meta,
});

/// Команда, адресованная одной строке и не несущая своего числа:
/// «плюс», «минус», «удалить».
typedef CartLineRequest = ({String lineId, CartCommandMeta meta});

/// Назначить строке количество.
typedef CartQuantityRequest = ({
  String lineId,
  Decimal quantity,
  CartCommandMeta meta,
});

/// Скидка строке процентом.
typedef CartPercentRequest = ({
  String lineId,
  Decimal percent,
  CartCommandMeta meta,
});

/// Скидка строке суммой.
typedef CartAmountRequest = ({
  String lineId,
  Decimal amount,
  CartCommandMeta meta,
});

/// Правка цены единицы в строке.
typedef CartPriceRequest = ({
  String lineId,
  Decimal price,
  CartCommandMeta meta,
});

/// Код маркировки (Data Matrix) строке.
typedef CartMarkRequest = ({String lineId, String mark, CartCommandMeta meta});

/// Поднять отложенный чек себе.
///
/// `receiptNo` здесь — номер **поднимаемого** чека, а `meta.receiptNo` —
/// номер того, что у рабочего места уже есть. Это не одно и то же, и
/// перепутать их значит получить отказ `cart_wrong_receipt` (ловушка
/// названа в докстринге `CartService.loadDeferred`).
typedef CartLoadDeferredRequest = ({int receiptNo, CartCommandMeta meta});

/// Назначить или снять агента продажи.
typedef CartAgentRequest = ({int? agentId, CartCommandMeta meta});

abstract final class SaleOps {
  /// Наименьший возможный обмен: штрихкод туда, товар обратно.
  ///
  /// Заведена ради замера круга (задача 1) и остаётся в каталоге навсегда —
  /// живая проверка провода без единого побочного действия: не открывает
  /// чек, не пишет строку, не двигает остаток.
  ///
  /// **Задача 9 сузила её право с «любого сеанса» до
  /// [PermissionKeys.navSale].** Прежний докстринг обещал «тем же правом,
  /// каким пользуется сканирование в самой продаже» — но объявлено было
  /// `SessionAccess()` без `needs`, то есть правом любого вошедшего, включая
  /// того, кому продажа закрыта вовсе. Здесь обещание и объявление сведены.
  static const salePing = Ask<String, ProductProbe>(
    'sale.ping',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _encodeBarcode,
    decode: _decodeProbe,
  );

  /// Начать чек — или продолжить уже начатый этим рабочим местом.
  ///
  /// Отдельной операцией, а не побочным действием первой команды: вторая
  /// вкладка того же терминала и вкладка, переподключившаяся до первого
  /// кадра подписки, зовут её первым делом и номера своего чека не знают —
  /// это единственная команда, которой разрешено звать себя «с холода»
  /// (`CartService.start`).
  ///
  /// # Признака опта у неё больше нет — круг правки 1 задачи 10
  ///
  /// До этой правки операция несла **обязательный** довод `wholesale`, и
  /// это был обход права, измеренный на настоящих кадрах: `setWholesale`
  /// требует [PermissionKeys.opEditPrice], `start` — только
  /// [PermissionKeys.navSale], а результат один и тот же
  /// (`start(wholesale: true)` → `view.wholesale == true`). Право, которое
  /// задача 9 поставила на переключение опта, было декоративным: тот же
  /// эффект давала соседняя операция под обычным правом продажи.
  ///
  /// Хуже того, расчёт режима точки (`PointModePermissions.effective`)
  /// **отбирает** правку цены у самообслуживания и беспилотного режима и
  /// **оставляет** право продажи — то есть покупатель у экрана
  /// самообслуживания открывал бы себе оптовый чек сам.
  ///
  /// Закрыто **снятием довода**, а не условной проверкой по телу: обход,
  /// которого нет, нельзя забыть проверить. Оптовый чек открывается двумя
  /// кадрами — `sale.start`, затем [setWholesale] со своим правом; лишний
  /// круг платится только за оптовый чек и только один раз на чек, а
  /// разницы в результате нет: у только что начатого чека строк ещё нет, а
  /// режим действует на строки, добавленные после него.
  ///
  /// Тело с ключом `wholesale` касса **отвергает** (`till_operations.dart`)
  /// — тем же правилом, что и названное рабочее место: молча
  /// проигнорированный признак опта означал бы «я просил опт, получил
  /// розницу и не узнал об этом». Отвергается **форма, а не значение**:
  /// `wholesale: false` отказывает наравне с `wholesale: true`, иначе
  /// клиент старой формы жил бы дальше и ломался бы ровно в тот день, когда
  /// кассир впервые попросит опт.
  ///
  /// # Требования к задаче 12 — щель между двумя кадрами
  ///
  /// Щель стоит дороже, чем видно с первого взгляда, и вот замер: начало
  /// чека — это **ещё и возобновление**, а значит между двумя кадрами может
  /// лечь строка (вторая вкладка того же места, быстрый скан). Строка,
  /// набранная до переключения, остаётся по рознице, чек становится
  /// оптовым, и снимок смеси **не помечает** — у `CartView` нет признака «в
  /// чеке две цены», так что показать это экран не может ничем.
  ///
  /// Отсюда четыре требования к `WtCartService`, и они не пожелания:
  ///
  /// 1. **`start(wholesale: true)` — это два кадра**, `sale.start` и
  ///    [setWholesale], а не один;
  /// 2. **отказ второго кадра выносится наверх**, а не глотается: для
  ///    самообслуживания и беспилотного режима отказ по `op.editPrice` —
  ///    законный исход, а не сбой;
  /// 3. **режим рисуется по снимку, никогда по намерению.** Экран, который
  ///    покажет «опт» потому, что его просили, соврёт ровно в том случае,
  ///    ради которого пункт 2 и существует;
  /// 4. **при отказе второго кадра повторяется переключение, а не начало.**
  ///    Повтор начала завёл бы второй чек или молча вернул бы первый; чинить
  ///    надо то, что не удалось.
  static const start = Ask<CartCommandMeta, CartView>(
    'sale.start',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: cartCommandMetaToWireJson,
    decode: _decodeCart,
  );

  /// Корзина этого рабочего места сейчас и при каждом её изменении.
  ///
  /// **Подписка, и в этом вся цель смены транспорта.** Корзина меняется не
  /// только своими командами: соседняя вкладка того же рабочего места,
  /// подъём отложенного чека, завершение продажи на кассе — каждое обязано
  /// доехать в момент события, а не при следующем вопросе. Вопрос здесь
  /// означал бы опрос корзины по таймеру — то самое, ради ухода от чего
  /// менялся транспорт.
  ///
  /// Довода нет: чьё рабочее место — знает сеанс, а не тело кадра.
  static const cart = Watch<void, CartView>(
    'sale.cart',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _nothing,
    decode: _decodeCart,
  );

  /// Общий пул отложенных чеков этой кассы.
  ///
  /// **Подписка по причине сильнее, чем у корзины: пул общий** (решение 3
  /// спеки). Чек, отложенный соседним рабочим местом, обязан появиться в
  /// списке сразу, а поднятый соседом — исчезнуть: иначе двое поднимают
  /// один чек, и второй узнаёт об этом отказом посреди работы, а не пустым
  /// местом в списке.
  ///
  /// **Право [PermissionKeys.opDeferSale], а не [PermissionKeys.navSale] —
  /// находка круга правки 1, идущая против брифа задачи 9.** Бриф относил
  /// список к «остальным пятнадцати» с обычным правом. Это оставляло
  /// открытой **читающую половину** возможности: кассир, которому владелец
  /// снял право откладывать, всё равно видел весь пул кассы — номера,
  /// суммы, число строк и **имя кассира**, отложившего каждый чек
  /// (`DeferredCart.userName`). Право, снятое наполовину, — не право.
  /// Писать и читать здесь одна возможность, и ключ у них один.
  static const deferredList = Watch<void, List<DeferredCart>>(
    'sale.deferredList',
    access: SessionAccess(needs: PermissionKeys.opDeferSale),
    encode: _nothing,
    decode: deferredListFromWireJson,
  );

  /// Поиск товара по имени или штрихкоду.
  ///
  /// **Вопрос, а не подписка, и не команда.** Выдача — не состояние кассы, а
  /// ответ на то, что кассир печатает прямо сейчас; следить за ней нечем.
  /// Метки команды у неё нет по той же причине: поиск ничего не меняет,
  /// значит ни повторять его безопасно нечего, ни сверять версию не с чем.
  static const search = Ask<String, List<ProductSearchResult>>(
    'sale.search',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _encodeQuery,
    decode: searchResultsFromWireJson,
  );

  /// Добавить товар сканированием штрихкода.
  ///
  /// Отдельно от [addProduct]: касса ищет товар сама по штрихкоду и сама
  /// решает, слить ли новые единицы с существующей строкой. Терминалу для
  /// этого пришлось бы сначала спросить товар, потом добавить его —
  /// два круга по проводу на каждый скан вместо одного, и гонка между ними.
  static const addByBarcode = Ask<CartBarcodeRequest, CartView>(
    'sale.addByBarcode',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _encodeBarcodeCommand,
    decode: _decodeCart,
  );

  /// Добавить товар из каталога заданным количеством.
  ///
  /// Отдельно от [addByBarcode]: у товара, выбранного из выдачи поиска,
  /// штрихкода может не быть вовсе, а количество задаётся сразу — весовой
  /// товар кладут килограммами, а не по одной единице [increment].
  static const addProduct = Ask<CartAddProductRequest, CartView>(
    'sale.addProduct',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _encodeAddProduct,
    decode: _decodeCart,
  );

  /// Назначить строке количество.
  ///
  /// Отдельно от [increment]/[decrement]: ввод «12» с клавиатуры — это одно
  /// изменение, а не двенадцать команд по проводу, и результат его не
  /// зависит от того, сколько в строке было.
  static const setQuantity = Ask<CartQuantityRequest, CartView>(
    'sale.setQuantity',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _encodeSetQuantity,
    decode: _decodeCart,
  );

  /// Прибавить единицу к строке.
  ///
  /// Отдельно от [setQuantity], хотя выглядит его частным случаем: кнопка
  /// «плюс» нажимается вслепую, не читая текущего количества, и посчитать
  /// «было плюс один» обязана касса. Терминал, считающий это сам,
  /// промахнулся бы на каждом изменении, доехавшем подпиской между нажатием
  /// и отправкой.
  static const increment = Ask<CartLineRequest, CartView>(
    'sale.increment',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _encodeLine,
    decode: _decodeCart,
  );

  /// Убавить единицу в строке. Отдельно от [increment] по той же причине,
  /// по которой они не одна операция со знаком: знак — довод, который можно
  /// перепутать, а две операции перепутать нечем.
  static const decrement = Ask<CartLineRequest, CartView>(
    'sale.decrement',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _encodeLine,
    decode: _decodeCart,
  );

  /// Скидка на строку процентом.
  ///
  /// **Право [PermissionKeys.opSellDiscount].** Отдельная операция от
  /// [setDiscountAmount] не ради формы довода — ради того, чтобы касса
  /// считала процент от суммы строки сама: терминал, посчитавший его,
  /// прислал бы сумму, посчитанную от снимка, который мог устареть.
  static const setDiscountPercent = Ask<CartPercentRequest, CartView>(
    'sale.setDiscountPercent',
    access: SessionAccess(needs: PermissionKeys.opSellDiscount),
    encode: _encodeSetDiscountPercent,
    decode: _decodeCart,
  );

  /// Скидка на строку суммой. **Право [PermissionKeys.opSellDiscount]** — то
  /// же самое действие с точки зрения кассира и та же ответственность за
  /// деньги, что и у процента.
  static const setDiscountAmount = Ask<CartAmountRequest, CartView>(
    'sale.setDiscountAmount',
    access: SessionAccess(needs: PermissionKeys.opSellDiscount),
    encode: _encodeSetDiscountAmount,
    decode: _decodeCart,
  );

  /// Условия правки строки — задача 44: настройки кассы, предел скидки
  /// вошедшего и символ валюты, **до** ввода.
  ///
  /// До неё экран продажи браузера скидку не давал вовсе: кнопка
  /// «Редактировать» пряталась, потому что прочесть эти условия было нечем
  /// (`SaleEditTermsReader`).
  ///
  /// **Право — [PermissionKeys.navSale], а не `op.sellDiscount`.** Это чтение,
  /// а не уступка: кассир без права скидки видит предел «0 %» или получает
  /// отказ на самой команде ([setDiscountPercent]/[setDiscountAmount]) —
  /// словами. Закрыть чтение правом скидки значило бы сделать отказ первым,
  /// что он узнаёт, — ровно тот порядок, от которого уходила задача 18.
  ///
  /// Тела нет: полномочия, по которым читается предел, касса берёт из сеанса.
  static const editTerms = Ask<void, SaleEditTerms>(
    'sale.editTerms',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _nothing,
    decode: saleEditTermsFromWireJson,
  );

  /// Категории сетки быстрых товаров — задача 45.
  ///
  /// **Касса владеет каталогом**: сетка терминала читает ту же таблицу
  /// `QuickProducts`, что и сетка кассы. До задачи 45 проводной реализации не
  /// было, и кнопка «Быстрые товары» в браузере пряталась.
  ///
  /// Право — [PermissionKeys.navSale]: это чтение того, что кассир и так
  /// продаёт поиском; цена на кнопке розничная, как у [search].
  static const quickCategories = Ask<void, List<QuickProductCategory>>(
    'sale.quickCategories',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _nothing,
    decode: quickCategoriesFromWireJson,
  );

  /// Товары категории сетки; `null` — лежащие в корне. Задача 45, тем же
  /// правом и тем же доводом, что [quickCategories].
  static const quickItems = Ask<int?, List<QuickProductItem>>(
    'sale.quickItems',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: quickItemsRequestToWireJson,
    decode: quickItemsFromWireJson,
  );

  /// Поставить строке цену единицы.
  ///
  /// **Право [PermissionKeys.opEditPrice], отдельное от скидки.** Это не
  /// придирка: скидку видно в чеке отдельной суммой, а правленая цена
  /// выглядит как обычная — то есть право на неё сильнее, и роль, которой
  /// разрешили скидку, не получает вместе с ней права переписывать
  /// прайс-лист.
  ///
  /// Строка может **исчезнуть** из ответного снимка: после правки она
  /// сливается с более ранней строкой того же товара по той же видимой цене
  /// (`CartService.updatePrice`). Терминал обязан пережить пропажу
  /// выбранной строки, а не показать пустоту.
  static const updatePrice = Ask<CartPriceRequest, CartView>(
    'sale.updatePrice',
    access: SessionAccess(needs: PermissionKeys.opEditPrice),
    encode: _encodeUpdatePrice,
    decode: _decodeCart,
  );

  /// Прикрепить строке код маркировки (Data Matrix).
  ///
  /// Отдельная операция, а не поле при добавлении: марка приходит вторым
  /// сканированием — сначала штрихкод товара, потом код с упаковки, — и
  /// строка к этому моменту в чеке уже лежит.
  static const setMark = Ask<CartMarkRequest, CartView>(
    'sale.setMark',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _encodeSetMark,
    decode: _decodeCart,
  );

  /// Убрать строку из чека.
  static const removeLine = Ask<CartLineRequest, CartView>(
    'sale.removeLine',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _encodeLine,
    decode: _decodeCart,
  );

  /// Очистить чек целиком, оставив его в работе.
  ///
  /// Отдельно от [removeLine] по строке: очистка — одно изменение и один
  /// ключ повтора, а перебор строк по одной оставил бы чек наполовину
  /// очищенным при обрыве провода.
  static const clear = Ask<CartCommandMeta, CartView>(
    'sale.clear',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: cartCommandMetaToWireJson,
    decode: _decodeCart,
  );

  /// Отложить чек в общий пул кассы.
  ///
  /// **Право [PermissionKeys.opDeferSale].** Возвращает **пустую** корзину:
  /// у рабочего места после откладывания чека в работе нет.
  static const defer = Ask<CartCommandMeta, CartView>(
    'sale.defer',
    access: SessionAccess(needs: PermissionKeys.opDeferSale),
    encode: cartCommandMetaToWireJson,
    decode: _decodeCart,
  );

  /// Поднять отложенный чек себе.
  ///
  /// **Право [PermissionKeys.opDeferSale]** — то же, что и у [defer]: это
  /// две половины одной операционной возможности, и роль, которой запретили
  /// откладывать, не должна поднимать отложенное соседом.
  static const loadDeferred = Ask<CartLoadDeferredRequest, CartView>(
    'sale.loadDeferred',
    access: SessionAccess(needs: PermissionKeys.opDeferSale),
    encode: _encodeLoadDeferred,
    decode: _decodeCart,
  );

  /// Назначить или снять агента продажи.
  static const setAgent = Ask<CartAgentRequest, CartView>(
    'sale.setAgent',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _encodeSetAgent,
    decode: _decodeCart,
  );

  /// Переключить чек между розницей и оптом.
  ///
  /// **Право [PermissionKeys.opEditPrice] — решение заказчика, круг правки
  /// 1.** Первая версия ставила сюда обычное [PermissionKeys.navSale] на том
  /// основании, что отдельного ключа «оптовый отпуск» в `PermissionKeys` нет
  /// (это по-прежнему так: `grep -n wholesale permission_keys.dart` — пусто).
  /// Разбор показал, что вывод из этого был неверный, и вот почему:
  ///
  /// - **опт — это выбор ценовой колонки, то есть та же правка цены.**
  ///   Заводить под него новый ключ значило бы тащить миграцию ради одной
  ///   операции; заимствовать `opEditPrice` — не второй смысл права, а его
  ///   прямой смысл;
  /// - `sale.setWholesale` была **единственной операцией, переоценивающей
  ///   чек, без своего права**. Соседки по последствиям —
  ///   [setDiscountPercent], [setDiscountAmount], [updatePrice] — все под
  ///   ключами `op.*`;
  /// - расчёт режима точки (`PointModePermissions.effective`) **отбирает**
  ///   у самообслуживания и беспилотного режима скидку и правку цены и
  ///   **оставлял** опт. То есть механизм, которому уже поручено сужать
  ///   права по режиму, эту операцию не видел;
  /// - цена ошибки названа ниже и она денежная: нулевая оптовая цена
  ///   раздаёт товар бесплатно, а ноль стоит у всех товаров без закупочной
  ///   цены после обычного импорта каталога.
  ///
  /// Не переставлять обратно на `navSale`: «отдельного ключа нет» — не
  /// довод за общее право, а вопрос «какое из существующих прав это по
  /// смыслу», и ответ на него — правка цены.
  ///
  /// Режим действует на строки, добавленные **после** него: уже набранные
  /// не переоцениваются (`CartService.setWholesale`).
  ///
  /// **Нулевая оптовая цена раздаёт товар бесплатно** — предел, названный
  /// задачей 7 и не закрытый: опт применяется по признаку «оптовая цена
  /// задана», а не «задана и осмысленна», и ноль попадает в
  /// `ProductPrices.wholesalePrice` штатным импортом каталога.
  static const setWholesale = Ask<CartWholesaleRequest, CartView>(
    'sale.setWholesale',
    access: SessionAccess(needs: PermissionKeys.opEditPrice),
    encode: _encodeWholesale,
    decode: _decodeCart,
  );

  /// Все операции продажи. Список ведётся руками, тем же приёмом и по той же
  /// причине, что и `TillOps.all` — в Dart нет способа перечислить
  /// объявленные константы класса без зеркал, а зеркала запрещены в сборке
  /// под браузер.
  static const all = <WireOp<Object?, Object?>>[
    salePing,
    start,
    cart,
    deferredList,
    search,
    addByBarcode,
    addProduct,
    setQuantity,
    increment,
    decrement,
    setDiscountPercent,
    setDiscountAmount,
    editTerms,
    quickCategories,
    quickItems,
    updatePrice,
    setMark,
    removeLine,
    clear,
    defer,
    loadDeferred,
    setAgent,
    setWholesale,
  ];
}

// --- Кодирование запросов ------------------------------------------------

/// Обмен без доводов. Пустое тело, а не отсутствие тела — тем же приёмом,
/// что и `TillOps`: кадр обязан быть разбираемым одинаково независимо от
/// того, есть ли в нём что сказать.
Map<String, Object?> _nothing(void _) => const {};

Map<String, Object?> _encodeBarcode(String barcode) => {'barcode': barcode};

Map<String, Object?> _encodeQuery(String query) => {'query': query};

Map<String, Object?> _encodeWholesale(CartWholesaleRequest request) => {
  'wholesale': request.wholesale,
  ...cartCommandMetaToWireJson(request.meta),
};

Map<String, Object?> _encodeBarcodeCommand(CartBarcodeRequest request) => {
  'barcode': request.barcode,
  ...cartCommandMetaToWireJson(request.meta),
};

Map<String, Object?> _encodeAddProduct(CartAddProductRequest request) => {
  'productId': request.productId,
  'quantity': wireMoney(request.quantity),
  ...cartCommandMetaToWireJson(request.meta),
};

Map<String, Object?> _encodeLine(CartLineRequest request) => {
  'lineId': request.lineId,
  ...cartCommandMetaToWireJson(request.meta),
};

Map<String, Object?> _encodeSetQuantity(CartQuantityRequest request) => {
  'lineId': request.lineId,
  'quantity': wireMoney(request.quantity),
  ...cartCommandMetaToWireJson(request.meta),
};

Map<String, Object?> _encodeSetDiscountPercent(CartPercentRequest request) => {
  'lineId': request.lineId,
  'percent': wireMoney(request.percent),
  ...cartCommandMetaToWireJson(request.meta),
};

Map<String, Object?> _encodeSetDiscountAmount(CartAmountRequest request) => {
  'lineId': request.lineId,
  'amount': wireMoney(request.amount),
  ...cartCommandMetaToWireJson(request.meta),
};

Map<String, Object?> _encodeUpdatePrice(CartPriceRequest request) => {
  'lineId': request.lineId,
  'price': wireMoney(request.price),
  ...cartCommandMetaToWireJson(request.meta),
};

Map<String, Object?> _encodeSetMark(CartMarkRequest request) => {
  'lineId': request.lineId,
  'mark': request.mark,
  ...cartCommandMetaToWireJson(request.meta),
};

Map<String, Object?> _encodeLoadDeferred(CartLoadDeferredRequest request) => {
  // Номер ПОДНИМАЕМОГО чека — не тот, что в метке (докстринг
  // [CartLoadDeferredRequest]). Ключ поэтому свой, а не `receiptNo`:
  // положи его тем же именем, и метка команды затёрла бы его на месте.
  'deferredReceiptNo': request.receiptNo,
  ...cartCommandMetaToWireJson(request.meta),
};

Map<String, Object?> _encodeSetAgent(CartAgentRequest request) => {
  // Ключ кладётся всегда, в том числе с `null`: снятие агента — команда, а
  // не пропущенное поле.
  'agentId': request.agentId,
  ...cartCommandMetaToWireJson(request.meta),
};

// --- Разбор ответов -------------------------------------------------------

ProductProbe _decodeProbe(Map<String, Object?> body) => ProductProbe(
  found: body['found'] as bool? ?? false,
  name: body['name'] as String?,
  price: body['price'] as String?,
);

CartView _decodeCart(Map<String, Object?> body) => cartViewFromWireJson(body);
