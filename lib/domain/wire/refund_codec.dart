/// Кодеки возврата: тела запросов и снимки, идущие по проводу, и обратно —
/// задача 19 плана «Продажа с браузерного терминала» (спека 2026-09-06).
///
/// Пары, а не одиночные функции, и это не стиль: `RefundOps.decode`
/// (`refund_ops.dart`) зовёт терминальную половину, обработчик кассы
/// (`lib/backend/till_operations.dart`) — кассовую. Пока половины лежат
/// рядом, форма живёт в одном месте; разведи их — и она станет двумя
/// расходящимися описаниями одного и того же, каким до 2026-08-04 была
/// строка пути URL.
///
/// **Тело ответа собирается парой, а не литералом.** В файле обработчиков
/// лежит соблазн: ответ `sale.ping` собран литералом руками
/// (`till_operations.dart`), и это признано пределом ещё в круге 2 задачи 9
/// («промах по имени конверта стал дороже, а не невозможен»). Повторить его
/// здесь значило бы завести шесть мест, где опечатка в имени поля даёт
/// ответ, неотличимый от честного: `RefundView` с нулевой версией и пустым
/// списком строк — это законный снимок «черновика нет», а не признак
/// поломки.
///
/// # Деньги
///
/// Каждое денежное поле кладётся через единственную дверь [wireMoney]
/// (`wire_money.dart`) и читается через `Decimal.parse` — инвариант I159.
/// Сторож `test/architecture/money_over_wire_test.dart` обходит весь
/// `lib/domain/wire/`, значит и этот файл.
///
/// **Измеренный предел: `maxQuantity` под охрану сторожа не попадает.**
/// Шаблон ключа якорится кавычками с обеих сторон
/// (`(["'])(price|total|amount|discount|quantity|…)\1\s*:`), поэтому
/// `'maxQuantity'` не совпадает с `quantity` — ровно тот же механизм, из-за
/// которого круг правки 1 задачи 9 нашёл слепоту сторожа к `totalDiscount`.
/// Проверено, а не предположено: `moneyFieldsNotUsingWireMoney` на тексте
/// этого файла с `'maxQuantity': line.maxQuantity!.toDouble()` не находит
/// ничего (проба «сторож не видит `maxQuantity` — измеренный предел» в
/// `test/domain/wire/refund_codec_test.dart`). Здесь оно всё равно едет
/// через дверь — правило соблюдено рукой, а не механизмом; закрывается
/// одним именем в списке сторожа, и это одна правка в чужом сейчас файле
/// (ветвь каталога продажи правит тот же список), поэтому названо пределом,
/// а не сделано молча.
///
/// # Почему номер чека продажи едет под именем `saleReceiptNo`
///
/// [CartCommandMeta.receiptNo] в возврате несёт **номер черновика**
/// ([RefundView.draftNo], докстринг `RefundService`), а метка едет плоско,
/// в том же теле. Положи номер возвращаемого чека тем же именем — и одно
/// затрёт другое на месте, смотря по порядку слияния карт. Та же ловушка и
/// то же лечение, что у `deferredReceiptNo` в каталоге продажи (задача 9,
/// решение 1): различие закрыто именем, а не комментарием.
library;

import 'package:decimal/decimal.dart';
import 'package:telepos/domain/refund/refund_allocation.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/wire/wire_money.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

// ── метка команды ───────────────────────────────────────────────────────

/// Метка команды в теле кадра — плоско, а не вложенным объектом.
///
/// Тем же приёмом и по тому же доводу, что и в каталоге продажи (задача 9,
/// решение 3): тело разбирает обработчик кассы, и плоская форма даёт ему
/// прочесть метку одним вызовом независимо от команды. `receiptNo` и здесь
/// кладётся **всегда**, в том числе значением `null`: пустое значение —
/// утверждение «черновика у меня нет», а не «поле забыли».
///
/// # Почему имя не `cartCommandMetaToWireJson`
///
/// Ветвь каталога продажи (задача 9) заводит пару с этим именем в
/// `cart_codec.dart` — своём файле, идущем сейчас параллельно. Два публичных
/// символа с одним именем, импортированные в один обработчик, — это не
/// конфликт слияния, а ошибка сборки после него. Имя здесь другое нарочно;
/// **при слиянии ветвей эту пару следует снять и звать пару из
/// `cart_codec.dart`** — форма у них одна и та же, и второй читатель формы
/// не нужен ни одной.
Map<String, Object?> refundCommandMetaToWireJson(CartCommandMeta meta) => {
  'key': meta.key,
  'baseVersion': meta.baseVersion,
  'receiptNo': meta.receiptNo,
};

/// Разбор метки команды — **строгий**, круг правки 1.
///
/// Прежняя редакция подставляла умолчания (`key` пустой строкой,
/// `baseVersion` нулём), оправдываясь тем, что «касса всё равно отвергнет».
/// Неверно: ноль — законная базовая версия свежего черновика, а пустой ключ
/// — законный ключ повтора, который совпадёт со следующим таким же. Кадр с
/// испорченной меткой превращался не в отказ, а в **другую законную
/// команду**.
///
/// [CartCommandMeta.receiptNo] остаётся необязательным, и это не
/// послабление: `null` там — утверждение «черновика у меня нет», а не «поле
/// забыли» ([refundCommandMetaToWireJson] кладёт ключ всегда).
CartCommandMeta refundCommandMetaFromWireJson(Map<String, Object?> json) =>
    CartCommandMeta(
      key: _string(json, 'key'),
      baseVersion: _int(json, 'baseVersion'),
      receiptNo: _optionalInt(json, 'receiptNo'),
    );

// ── тела запросов ───────────────────────────────────────────────────────

/// Тело `refund.loadReceipt`.
///
/// `saleReceiptNo`/`salePosId`, а не `receiptNo`/`posId` — см. докстринг
/// файла про столкновение с `receiptNo` метки.
Map<String, Object?> receiptKeyToWireJson(ReceiptKey request) => {
  'saleReceiptNo': request.receiptNo,
  'salePosId': request.posId,
  ...refundCommandMetaToWireJson(request.meta),
};

ReceiptKey receiptKeyFromWireJson(Map<String, Object?> json) => ReceiptKey(
  receiptNo: _int(json, 'saleReceiptNo'),
  posId: _int(json, 'salePosId'),
  meta: refundCommandMetaFromWireJson(json),
);

/// Тело `refund.addProduct`.
Map<String, Object?> refundLineRequestToWireJson(RefundLineRequest request) => {
  'productId': request.productId,
  'quantity': wireMoney(request.quantity),
  ...refundCommandMetaToWireJson(request.meta),
};

RefundLineRequest refundLineRequestFromWireJson(Map<String, Object?> json) =>
    RefundLineRequest(
      productId: _int(json, 'productId'),
      quantity: _money(json, 'quantity'),
      meta: refundCommandMetaFromWireJson(json),
    );

/// Тело `refund.setLine` — операции, которой не было в наброске задачи 19.
///
/// Без неё выделение строк не доезжает с терминала до кассы вовсе:
/// `RefundService.addProduct` в возврате по чеку отказывает всегда (круг
/// правки 1 задачи 18), и адресовать строку чека нечем, кроме её `lineId`.
Map<String, Object?> refundLineQuantityToWireJson(RefundLineQuantity request) =>
    {
      'lineId': request.lineId,
      'quantity': wireMoney(request.quantity),
      ...refundCommandMetaToWireJson(request.meta),
    };

RefundLineQuantity refundLineQuantityFromWireJson(Map<String, Object?> json) =>
    RefundLineQuantity(
      lineId: _string(json, 'lineId'),
      quantity: _money(json, 'quantity'),
      meta: refundCommandMetaFromWireJson(json),
    );

// ── снимок черновика ────────────────────────────────────────────────────

Map<String, Object?> refundViewToWireJson(RefundView view) => {
  'posId': view.posId,
  'terminalId': view.terminalId,
  'version': view.version,
  'draftNo': view.draftNo,
  'saleReceiptNo': view.saleReceiptNo,
  'salePosId': view.salePosId,
  'lines': view.lines.map(refundLineToWireJson).toList(),
  'total': wireMoney(view.total),
  'destinations': view.destinations.map(refundDestinationToWireJson).toList(),
};

/// Разбор снимка.
///
/// `total` обратно не читается — это производный геттер [RefundView], а не
/// независимое состояние; на проводе он едет только затем, чтобы терминал
/// показал итог, не пересчитывая его по строкам. Тот же довод и та же форма,
/// что у `cartViewFromWireJson`.
RefundView refundViewFromWireJson(Map<String, Object?> json) => RefundView(
  posId: _int(json, 'posId'),
  terminalId: _int(json, 'terminalId'),
  version: _int(json, 'version'),
  draftNo: _optionalInt(json, 'draftNo'),
  saleReceiptNo: _optionalInt(json, 'saleReceiptNo'),
  salePosId: _optionalInt(json, 'salePosId'),
  lines: _objects(json, 'lines').map(refundLineFromWireJson).toList(),
  // Пропуск — значение (касса этого не сказала: пустой список, и экран
  // просто не показывает строк), мусор — отказ. Правило файла для
  // необязательного, тем же доводом, что у `maxQuantity`: пустота здесь не
  // утверждает ничего о деньгах, а терминал новее кассы не ломается.
  destinations: json['destinations'] == null
      ? const []
      : _objects(
          json,
          'destinations',
        ).map(refundDestinationFromWireJson).toList(),
);

/// Строка «куда уйдут деньги» — задача 26.
///
/// Получатель едет **кодом** (`RefundRoute.code`), сумма — через дверь
/// [wireMoney]. Незнакомый код — отказ, а не «наличные по умолчанию»: касса
/// новее терминала обязана быть видна, а не выдана за ящик.
Map<String, Object?> refundDestinationToWireJson(RefundDestination d) => {
  'route': d.route.code,
  'amount': wireMoney(d.amount),
  'kindId': d.kindId,
  'kindName': d.kindName,
  'detail': d.detail,
};

RefundDestination refundDestinationFromWireJson(Map<String, Object?> json) =>
    RefundDestination(
      route:
          RefundRoute.byCode(_string(json, 'route')) ??
          _bad('route', 'известный получатель возврата'),
      amount: _money(json, 'amount'),
      kindId: _optionalInt(json, 'kindId'),
      kindName: _optionalString(json, 'kindName'),
      detail: _optionalString(json, 'detail'),
    );

Map<String, Object?> refundLineToWireJson(RefundLine line) => {
  'id': line.id,
  'productId': line.productId,
  'name': line.name,
  'quantity': wireMoney(line.quantity),
  'price': wireMoney(line.price),
  // Условный ключ, а не тернарный выбор под ключом: вторая форма красна для
  // сторожа денег нарочно (докстринг `money_over_wire_test.dart`), и обходить
  // его пришлось бы обёрткой, в которую он не заглядывает. `null` и
  // отсутствие ключа здесь значат одно и то же — «потолка нет, это возврат
  // без чека», — в отличие от `receiptNo` метки, где `null` есть
  // утверждение. Тот же приём, что у `stock` в каталоге продажи.
  if (line.maxQuantity case final maxQuantity?)
    'maxQuantity': wireMoney(maxQuantity),
  'barcode': line.barcode,
  'total': wireMoney(line.total),
};

RefundLine refundLineFromWireJson(Map<String, Object?> json) => RefundLine(
  id: _string(json, 'id'),
  productId: _int(json, 'productId'),
  name: _string(json, 'name'),
  quantity: _money(json, 'quantity'),
  price: _money(json, 'price'),
  // Пусто (ключа нет или под ним `null`) — потолка нет, возврат без чека.
  // Мусор под ключом — отказ. Одно правило на весь файл: пропуск —
  // значение, мусор — отказ; до круга правки 2 здесь стояло `containsKey`,
  // и явный `'maxQuantity': null` читался отказом, тогда как явный
  // `'receiptNo': null` рядом читался значением — одно правило, два
  // прочтения.
  maxQuantity: _optionalMoney(json, 'maxQuantity'),
  // Штрихкод — тем же правилом. До круга правки 2 он оставался на сыром
  // `as String?`: число под ним доезжало до терминала именем типа
  // (`handler_failed`), а не названным отказом, — ровно тот механизм,
  // взамен которого весь строгий разбор и делался.
  barcode: _optionalString(json, 'barcode'),
  // `total` — геттер `RefundLine`, читать его обратно значило бы завести
  // второй источник истины для того же числа.
);

// ── исход ───────────────────────────────────────────────────────────────

Map<String, Object?> refundOutcomeToWireJson(RefundOutcome outcome) => {
  'refundLocalId': outcome.refundLocalId,
  'amount': wireMoney(outcome.amount),
  'lineCount': outcome.lineCount,
  'paymentCount': outcome.paymentCount,
  'saleReceiptNo': outcome.saleReceiptNo,
  'salePosId': outcome.salePosId,
};

RefundOutcome refundOutcomeFromWireJson(Map<String, Object?> json) =>
    RefundOutcome(
      refundLocalId: _int(json, 'refundLocalId'),
      amount: _money(json, 'amount'),
      lineCount: _int(json, 'lineCount'),
      paymentCount: _int(json, 'paymentCount'),
      saleReceiptNo: _optionalInt(json, 'saleReceiptNo'),
      salePosId: _optionalInt(json, 'salePosId'),
    );

// ── строгий разбор ──────────────────────────────────────────────────────
//
// Круг правки 1. Прежняя редакция читала мусор нулём и пустой строкой,
// оправдываясь тем, что «ноль касса отвергнет своим кодом». Для двух команд
// это прямо неверно: у `refund.addProduct` и `refund.setLine` **ноль — сам
// по себе законная команда «снять строку»**. То есть нечитаемое количество
// превращалось не в отказ, а в другую законную команду, и терминал узнал бы
// об этом только по исчезнувшей строке. Плюс шапка файла обещала строгость,
// а код разбирал мягко, и соседний кодек того же провода
// (`cart_codec.dart`) читает деньги громко — два кодека жили по двум
// правилам.
//
// Теперь ошибка типа уезжает **отказом значением** (`bad_request`, I144), а
// не тихой правкой: отказ строго лучше молчаливого удаления строки.
//
// **Строго — значит целиком, включая необязательные поля.** Круг правки 2
// нашёл два места, где «переведён на строгий целиком» было обещанием, а не
// правдой: штрихкод оставался на сыром `as String?` (число под ним доезжало
// именем типа, а не названным отказом — тем самым механизмом, взамен
// которого правка делалась), а правило «пропуск — значение, мусор — отказ»
// читалось в одном файле двумя способами (явный `null` под `maxQuantity` —
// отказ, под `receiptNo` — значение). Оба приведены к одному правилу
// парами `_optional*`.

Never _bad(String field, String expected) =>
    throw WireRefusal('bad_request', 'ожидалось $expected: $field');

int _int(Map<String, Object?> json, String field) {
  final value = json[field];
  return value is int ? value : _bad(field, 'целое');
}

/// Необязательное целое: ключа нет или под ним `null` — это **значение**
/// («черновика нет», «чек не назван»); а вот не-целое под ключом — отказ.
int? _optionalInt(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value == null) return null;
  return value is int ? value : _bad(field, 'целое или пусто');
}

/// Список объектов под ключом — **строго**, круг правки 3.
///
/// Здесь остались последние сырые приведения файла: `json['lines'] as List?`
/// глотал не-список пустотой (снимок без строк — законный снимок, значит
/// испорченный кадр читался бы как «черновик пуст»), а `raw as Map` ронял
/// `TypeError` с именем типа. Ставка на стороне терминала ниже, чем у
/// входящей команды, — но обещание в шапке было про весь файл.
List<Map<String, Object?>> _objects(Map<String, Object?> json, String field) {
  final raw = json[field];
  if (raw is! List) return _bad(field, 'список');
  return [
    for (final item in raw)
      if (item is Map)
        item.cast<String, Object?>()
      else
        _bad(field, 'список объектов'),
  ];
}

String _string(Map<String, Object?> json, String field) {
  final value = json[field];
  return value is String ? value : _bad(field, 'строка');
}

/// Необязательная строка — тем же правилом, что [_optionalInt].
String? _optionalString(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value == null) return null;
  return value is String ? value : _bad(field, 'строка или пусто');
}

/// Деньги с провода — **строкой, никогда числом** (I159).
///
/// Числом не читаются принципиально: `5.1`, приехавшее `double`, потеряло
/// бы точность ещё до этой строки, и принять его значило бы узаконить
/// потерю. Неразбираемая строка — тоже отказ, разбор над этим разделом.
Decimal _money(Map<String, Object?> json, String field) {
  final raw = json[field];
  if (raw is! String) return _bad(field, 'строка десятичного числа');
  return Decimal.tryParse(raw) ?? _bad(field, 'разбираемое десятичное число');
}

/// Необязательные деньги — тем же правилом, что [_optionalInt]: пусто —
/// значение («потолка нет»), мусор под ключом — отказ.
Decimal? _optionalMoney(Map<String, Object?> json, String field) =>
    json[field] == null ? null : _money(json, field);
