/// Проба эмулятора WebKassa: шесть денежных сценариев и все ветки разбора
/// кода ошибки — через **настоящий** `WebKassaProvider` по настоящему HTTP.
///
/// # Что здесь проверяется, а что нет
///
/// Проба поднимает эмулятор в своём же процессе и направляет на него
/// **продуктовый** `WebKassaProvider` с **продуктовым** `WebKassaApiClient`.
/// Ни один класс продукта не подменён: конверт собирает
/// `buildCheckPayload`, ответ разбирает `_checkResult`, код отображает
/// `_mapError`, очередь ведёт `OfflineQueueingProvider`. Точка подстановки —
/// сеть, и только она.
///
/// **Чего проба не доказывает — и это важнее того, что она доказывает:**
///
/// 1. Она не доказывает, что настоящая WebKassa отвечает так же. См.
///    докстринг `emulator.dart`.
/// 2. **Позиции в денежных сценариях собраны руками, а не
///    `FiscalServiceImpl._buildSalePositions`.** Это ровно та ловушка, о
///    которой предупреждает соседний чертёж: собранные руками позиции
///    проверяют арифметику самой пробы. Здесь она принята сознательно и с
///    названной причиной: `_buildSalePositions` читает `drift`-базу, а файл
///    под `dart run` не имеет права тянуть `package:flutter`. Проба поэтому
///    закрывает **конвейер** (конверт → сеть → пересчёт → карта кодов) и
///    **не закрывает** раскладку скидки по позициям. Раскладку обязан
///    закрыть набор кассы над настоящей базой — и до тех пор эта дыра
///    названа, а не подразумевается закрытой.
/// 3. Сегодня `FiscalServiceImpl._buildSalePositions` **не передаёт**
///    `discount` вовсе (измерено 2026-09-07), поэтому поле `Discount` в
///    конверте не появляется ни разу. Сценарии со скидкой описывают то, что
///    будет отправлено, когда раскладку напишут, — и потому проверяют
///    эмулятор как прибор, а не кассу как продукт.
///
/// # Шестой сценарий обязан покраснеть, и это не дефект правки
///
/// Сценарий «чек с бонусом» **предсказанно красный**. Бонус списывается с
/// бонусного счёта покупателя (`Agents.cashbackAccountId`), а
/// `LocalPaymentService._fiscalize` раскладывает оплаты по типу счёта:
/// `AccountType.pos` → наличные, `AccountType.customBank` → карта. Бонусный
/// счёт не попадает никуда. Позиции при этом строятся на полную сумму, а
/// `totalDiscount` конверту не отправляется вовсе. Итог: сумма позиций
/// больше суммы оплат ровно на бонус, и пересчёт с нулевым допуском обязан
/// отказать кодом 9.
///
/// **Это дефект продукта, а не эмулятора.** Он объявлен здесь заранее именно
/// для того, чтобы, когда сценарий загорится, никто не пошёл чинить
/// пересчёт.
///
/// # Запуск
///
/// ```
/// dart run test/emulators/webkassa/probe.dart          # всё
/// dart run test/emulators/webkassa/probe.dart --journal # плюс журнал целиком
/// ```
///
/// Возврат 0 — все случаи ответили ожидаемым; 1 — хоть один разошёлся.
library;

import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/datasources/remote/webkassa_api_client.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';
import 'package:telepos/data/fiscal/webkassa_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

import 'emulator.dart';
import 'faults.dart';
import 'state.dart';

const String _cashbox = 'SWK00000001';
const String _regNumber = '000000000001';
const String _login = 'emul';
const String _password = 'emul';

Decimal _d(String s) => Decimal.parse(s);

class _Outcome {
  _Outcome(
    this.name,
    this.expected,
    this.actual, {
    this.note,
    this.defect = false,
  });

  final String name;
  final String expected;
  final String actual;
  final String? note;

  /// Случай закрепляет **найденный дефект продукта**, а не верное поведение.
  ///
  /// Такой случай сходится, пока дефект жив, и **разойдётся в тот день, когда
  /// его починят**, — тогда его надо переписать на верное поведение. Без этого
  /// флага дефект пришлось бы либо чинить в `lib/` (чего этому ярусу нельзя),
  /// либо держать пробу вечно красной, и тогда все остальные её ответы
  /// перестали бы читаться.
  final bool defect;

  bool get ok => expected == actual;
}

final List<_Outcome> _results = [];

void _check(
  String name,
  String expected,
  String actual, {
  String? note,
  bool defect = false,
}) {
  final outcome = _Outcome(name, expected, actual, note: note, defect: defect);
  _results.add(outcome);
  final mark = outcome.ok ? (defect ? 'НАХОДКА' : 'ok  ') : 'РАЗОШЛОСЬ';
  stdout.writeln('  $mark $name');
  if (!outcome.ok) {
    stdout.writeln('        ждали:  $expected');
    stdout.writeln('        пришло: $actual');
  }
  if (note != null) stdout.writeln('        $note');
}

// --------------------------------------------------------------- оснастка

class _Rig {
  _Rig(this.emulator, this.provider, this.state, this.settings);

  final WebKassaEmulator emulator;
  final WebKassaProvider provider;
  final EmulatorState state;
  final FiscalSettings settings;

  /// Взять токен заранее.
  ///
  /// Нужно там, где меряется отказ **на самой операции**: `_withReauthRetry`
  /// первым делом зовёт `_ensureToken`, и без прогретого токена отказ
  /// приходится на `/api/v4/Authorize`, а не на `/api/v4/check`. Разница
  /// видна в ответе: у отказа авторизации `rawErrorCode` теряется —
  /// `_withReauthRetry` строит `FiscalResult.failure(auth.error, code: …)`
  /// без него.
  Future<void> warm() async {
    await provider.authorize(settings);
  }

  Future<void> console(
    String path, [
    Map<String, Object?> body = const {},
  ]) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(emulator.baseUri.replace(path: path));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
      final resp = await req.close();
      await resp.drain<void>();
    } finally {
      client.close(force: true);
    }
  }

  Future<void> stop() async {
    provider.dispose();
    await emulator.stop();
  }
}

Future<_Rig> _rig({
  Duration tokenTtl = const Duration(hours: 1),
  VatMode vat = VatMode.off,
  Duration clientTimeout = const Duration(seconds: 30),
  String cashboxInSettings = _cashbox,
  String loginInSettings = _login,
  String passwordInSettings = _password,
}) async {
  final state = EmulatorState(
    cashboxes: {
      _cashbox: EmulatedCashbox(
        uniqueNumber: _cashbox,
        registrationNumber: _regNumber,
        now: DateTime.now(),
      ),
    },
    login: _login,
    password: _password,
    tokenTtl: tokenTtl,
    vat: vat,
  );
  final emulator = WebKassaEmulator(state: state, echo: false);
  await emulator.start('127.0.0.1', 0);

  final settings = FiscalSettings(
    operatorType: FiscalOperatorType.webkassa,
    testMode: true,
    baseUrl: emulator.baseUri.toString(),
    login: loginInSettings,
    password: passwordInSettings,
    apiKey: 'emulated-integrator-key',
    cashboxUniqueNumber: cashboxInSettings,
    registrationNumber: _regNumber,
  );
  final logger = Talker(settings: TalkerSettings(enabled: false));
  final provider = WebKassaProvider(
    settings: settings,
    logger: logger,
    client: WebKassaApiClient(
      baseUrl: settings.baseUrl!,
      apiKey: settings.apiKey,
      logger: logger,
      timeout: clientTimeout,
    ),
  );
  return _Rig(emulator, provider, state, settings);
}

FiscalPosition _pos({
  required String name,
  required String qty,
  required String price,
  String? discount,
  String? vatPercent,
  String? vatAmount,
}) => FiscalPosition(
  name: name,
  quantity: _d(qty),
  unitPrice: _d(price),
  lineTotal: (_d(qty) * _d(price)).round(scale: 2) - _d(discount ?? '0'),
  tax: vatPercent == null
      ? FiscalTax.none()
      : FiscalTax(
          mode: FiscalTaxMode.vat,
          ratePercent: _d(vatPercent),
          amount: _d(vatAmount ?? '0'),
        ),
  discount: discount == null ? null : _d(discount),
);

FiscalSaleRequest _sale({
  required String key,
  required List<FiscalPosition> positions,
  required List<FiscalPayment> payments,
}) => FiscalSaleRequest(
  idempotencyKey: key,
  localOperationId: key.hashCode.abs() % 100000,
  positions: positions,
  payments: payments,
  totalDiscount: Decimal.zero,
  totalMarkup: Decimal.zero,
  occurredAt: DateTime.now(),
);

String _verdict(FiscalResult r) => r.success
    ? (r.queued ? 'queued' : 'ok:${r.fiscalSign}')
    : '${r.errorCode.name}:${r.rawErrorCode ?? '-'}';

/// Текст отказа целиком — в примечание, чтобы «разошлось» не приходилось
/// разбирать вслепую.
String _why(FiscalResult r) => r.success ? '' : 'причина: ${r.errorMessage}';

// ------------------------------- находка, ради которой прибор и понадобился

/// Кириллица в теле запроса доезжает до сервера — **починено 2026-09-13**.
///
/// # Что было
///
/// `_defaultSend` писал тело `request.write(body)` под заголовком без
/// `charset`; `HttpClientRequest` кодировал latin1 и бросал `Contains
/// invalid characters` на первой русской букве. `-3` → `network` → «в
/// очереди», `success: true`. Ни один чек с кириллицей до оператора не
/// дошёл за всю жизнь кассы.
///
/// # Урок, ради которого этот раздел оставлен
///
/// Этот случай шесть дней **сходился**: он ждал `network:-3` с пометкой
/// `defect: true`. Проба, закрепившая дефект, зелена ровно пока дефект жив,
/// а соседние пробы по настоящему сокету (`live_till_test.dart`,
/// `unfiscalized_row_test.dart`) взяли названия латиницей, чтобы его
/// обойти. Обход прижился, починку никто не взял, и живая приёмка нашла
/// дефект заново. Закреплённый дефект — долг с владельцем и сроком, а не
/// состояние прибора.
///
/// Теперь случай утверждает верное поведение. Постоянные пробы в наборе —
/// `test/data/datasources/webkassa_api_client_utf8_test.dart` (побайтно,
/// через отвод) и `test/data/fiscal/cyrillic_receipt_fiscalized_test.dart`
/// (вся цепочка кассы); запрет `write` строкой —
/// `test/architecture/http_body_is_bytes_test.dart`.
Future<void> _encodingFinding() async {
  stdout.writeln('\n=== Кодировка тела запроса\n');
  final rig = await _rig();
  try {
    final latin = await rig.provider.fiscalizeSale(
      _sale(
        key: 'encoding-latin',
        positions: [_pos(name: 'Bread', qty: '1', price: '100')],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('100')),
        ],
      ),
    );
    _check(
      'латиница в PositionName доезжает',
      'ok',
      latin.success ? 'ok' : _verdict(latin),
      note: _why(latin),
    );

    final cyrillic = await rig.provider.fiscalizeSale(
      _sale(
        key: 'encoding-cyrillic',
        positions: [_pos(name: 'Хлеб', qty: '1', price: '100')],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('100')),
        ],
      ),
    );
    _check(
      'кириллица в PositionName доезжает',
      'ok',
      cyrillic.success && !cyrillic.queued ? 'ok' : _verdict(cyrillic),
      note: _why(cyrillic),
    );
    final names = [
      for (final e in rig.state.journal.where((e) => e.path == '/api/v4/check'))
        for (final p in (e.request['Positions'] as List).cast<Map>())
          p['PositionName'],
    ];
    _check(
      'до эмулятора дошли оба чека, русское название — тем же текстом',
      'Bread|Хлеб',
      names.join('|'),
      note: 'эмулятор декодирует тело строгим utf8 — битый UTF-8 он не принял бы',
    );
  } finally {
    await rig.stop();
  }
}

// ------------------------------------------------- шесть денежных сценариев

Future<void> _moneyScenarios() async {
  stdout.writeln(
    '\n=== Шесть денежных сценариев (пересчёт с нулевым допуском)\n',
  );
  stdout.writeln(
    '  Названия товаров здесь латинские — намеренно: кириллица до '
    'сервера\n  не доезжает вовсе (см. раздел «Кодировка тела запроса»), и '
    'русское\n  название закрыло бы собой всю арифметику.\n',
  );
  final rig = await _rig();
  try {
    // 1. Скидка 100 на чек, разложенная по трём строкам как 33.33+33.33+33.34
    //    была бы точной. Здесь она разложена по 33.33 на каждую — так, как
    //    ляжет целочисленное деление без остатка: 99.99 вместо 100.
    //    Копейка остаётся у кассы, и это ровно измеренный случай 200.01/200.00.
    final one = await rig.provider.fiscalizeSale(
      _sale(
        key: 'money-1-lost-kopeck',
        positions: [
          for (var i = 0; i < 3; i++)
            _pos(
              name: 'Item ${i + 1}',
              qty: '1',
              price: '100',
              discount: '33.33',
            ),
        ],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('200.00')),
        ],
      ),
    );
    _check(
      '1. потерянная копейка скидки (200.01 против 200.00)',
      'validation:9',
      _verdict(one),
      note: 'разность 0.01 — то, ради чего пересчёт вообще написан',
    );

    // 2. Тот же чек без скидки. Проверяется не только «сошлось», но и что
    //    поля `Discount` в конверте нет вовсе: `_positionToJson` кладёт его
    //    только при `discountOr > 0`, и правка раскладки не должна этого
    //    менять.
    final two = await rig.provider.fiscalizeSale(
      _sale(
        key: 'money-2-no-discount',
        positions: [
          for (var i = 0; i < 3; i++)
            _pos(name: 'Item ${i + 1}', qty: '1', price: '100'),
        ],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('300')),
        ],
      ),
    );
    _check(
      '2. бесскидочный чек 3 × 100',
      'ok',
      two.success ? 'ok' : _verdict(two),
    );
    final checks = rig.state.journal
        .where((e) => e.path == '/api/v4/check')
        .toList();
    final firstPosition = checks.isEmpty
        ? const <String, Object?>{}
        : (((checks.last.request['Positions'] as List?) ?? const []).first
                  as Map)
              .cast<String, Object?>();
    _check(
      '2а. поля Discount в конверте нет',
      'нет',
      checks.isEmpty
          ? 'конверт до эмулятора не дошёл'
          : (firstPosition.containsKey('Discount') ? 'есть' : 'нет'),
    );

    // 3. Масштаб количества 3 против масштаба денег 2.
    //    0.333 × 1500 = 499.50, скидка 10 % = 49.95, к оплате 449.55.
    final three = await rig.provider.fiscalizeSale(
      _sale(
        key: 'money-3-weight',
        positions: [
          _pos(name: 'Cheese', qty: '0.333', price: '1500', discount: '49.95'),
        ],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('449.55')),
        ],
      ),
    );
    _check(
      '3. 0.333 кг × 1500 со скидкой 10 %',
      'ok',
      three.success ? 'ok' : _verdict(three),
      note:
          'количество масштаба 3, деньги масштаба 2 — прибор не должен краснеть',
    );

    // 4. Период в делении, худший случай: 33 % от 10.10 = 3.333, к оплате
    //    по 6.77 за штуку, три штуки — 20.31.
    final four = await rig.provider.fiscalizeSale(
      _sale(
        key: 'money-4-period',
        positions: [
          for (var i = 0; i < 3; i++)
            _pos(
              name: 'Small ${i + 1}',
              qty: '1',
              price: '10.10',
              discount: '3.33',
            ),
        ],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('20.31')),
        ],
      ),
    );
    _check(
      '4. скидка 33 % на три штуки по 10.10',
      'ok',
      four.success ? 'ok' : _verdict(four),
      note: 'округление скидки вниз, оплата равна сумме позиций — сходится',
    );

    // 5. Скидка на чек 500, разложенная пропорционально на 1000/700/300:
    //    250.00 + 175.00 + 75.00 = ровно 500, четвёртой копейки не возникает.
    final five = await rig.provider.fiscalizeSale(
      _sale(
        key: 'money-5-spread',
        positions: [
          _pos(name: 'Large', qty: '1', price: '1000', discount: '250.00'),
          _pos(name: 'Medium', qty: '1', price: '700', discount: '175.00'),
          _pos(name: 'Tiny', qty: '1', price: '300', discount: '75.00'),
        ],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('1500')),
        ],
      ),
    );
    _check(
      '5. скидка на чек 500 по трём строкам',
      'ok',
      five.success ? 'ok' : _verdict(five),
    );

    // 6. ЧЕК С БОНУСОМ — предсказанно красный. См. докстринг файла.
    final six = await rig.provider.fiscalizeSale(
      _sale(
        key: 'money-6-bonus',
        positions: [_pos(name: 'Item', qty: '1', price: '1000')],
        // Бонус 300 списан со счёта покупателя. В оплаты он не попадает:
        // `_fiscalize` знает только AccountType.pos и AccountType.customBank.
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('700')),
        ],
      ),
    );
    _check(
      '6. чек с бонусом 300 из 1000',
      'validation:9',
      _verdict(six),
      note:
          'ПРЕДСКАЗАННЫЙ КРАСНЫЙ И ДЕФЕКТ ПРОДУКТА, А НЕ ПРИБОРА: бонусный счёт '
          'не попадает ни в наличные, ни в карту, позиции строятся на полную '
          'сумму, totalDiscount конверту не отправляется. Чинить пересчёт нельзя.',
    );
  } finally {
    await rig.stop();
  }
}

// ------------------------------------------------------ ветки разбора кода

Future<void> _refusals() async {
  stdout.writeln('\n=== Вызываемые отказы: каждая ветка _mapError\n');

  // 1 — badCredentials: пароль в настройках не тот, что знает эмулятор.
  {
    // Пароль латиницей — наследие дефекта кодировки (до 2026-09-13 русский
    // неверный пароль дал бы -3 вместо кода 1). Сегодня годился бы любой.
    final rig = await _rig(passwordInSettings: 'wrong-password');
    final auth = await rig.provider.authorize(rig.settings);
    _check(
      'код 1 → badCredentials',
      'badCredentials',
      auth.errorCode.name,
      note: auth.error,
    );
    await rig.stop();
  }

  // 2 — токен, которого эмулятор не выдавал. Достигается тем, что провайдер
  // авторизовался, а эмулятор перезапустил состояние: токен исчез.
  {
    final rig = await _rig();
    await rig.warm();
    await rig.console('/_emul/reset');
    // Токен у провайдера остался, у эмулятора — нет. Повтор по коду 2
    // перевыпустит его и операция пройдёт: это и есть _withReauthRetry.
    final r = await rig.provider.fiscalizeSale(
      _sale(
        key: 'refusal-2-unknown-token',
        positions: [_pos(name: 'Item', qty: '1', price: '100')],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('100')),
        ],
      ),
    );
    final refusedOnce = rig.state.journal.any((e) => e.outcome == 'refused:2');
    _check(
      'код 2 → tokenExpired, отказ виден в журнале',
      'да',
      refusedOnce ? 'да' : 'нет',
    );
    _check(
      'код 2 → _withReauthRetry перевыпустил токен и повторил',
      'ok',
      r.success ? 'ok' : _verdict(r),
    );
    await rig.stop();
  }

  // 3 — истёкший токен, естественным путём: TTL 1 секунда.
  {
    final rig = await _rig(tokenTtl: const Duration(seconds: 1));
    await rig.warm();
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final r = await rig.provider.fiscalizeSale(
      _sale(
        key: 'refusal-3-expired',
        positions: [_pos(name: 'Item', qty: '1', price: '100')],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('100')),
        ],
      ),
    );
    final saw3 = rig.state.journal.any((e) => e.outcome == 'refused:3');
    _check('код 3 → tokenExpired по истечении TTL', 'да', saw3 ? 'да' : 'нет');
    _check(
      'код 3 → повтор после перевыпуска прошёл',
      'ok',
      r.success ? 'ok' : _verdict(r),
      note:
          'вся ветка _withReauthRetry пройдена естественным путём, не пультом',
    );
    await rig.stop();
  }

  // 6 — чужой заводской номер кассы.
  {
    final rig = await _rig(cashboxInSettings: 'SWK99999999');
    final r = await rig.provider.fiscalizeSale(
      _sale(
        key: 'refusal-6-cashbox',
        positions: [_pos(name: 'Item', qty: '1', price: '100')],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('100')),
        ],
      ),
    );
    _check('код 6 → cashboxNotFound', 'cashboxNotFound:6', _verdict(r));
    await rig.stop();
  }

  // 7 — касса заблокирована (пульт).
  {
    final rig = await _rig();
    await rig.console('/_emul/block', {'on': true});
    final r = await rig.provider.fiscalizeSale(
      _sale(
        key: 'refusal-7-blocked',
        positions: [_pos(name: 'Item', qty: '1', price: '100')],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('100')),
        ],
      ),
    );
    _check('код 7 → cashboxBlocked', 'cashboxBlocked:7', _verdict(r));
    await rig.stop();
  }

  // 8 — изъятие больше остатка в ящике.
  {
    final rig = await _rig();
    final r = await rig.provider.moneyOut(
      FiscalMoneyRequest(
        idempotencyKey: 'refusal-8-money-out',
        amount: _d('5000'),
        occurredAt: DateTime.now(),
        comment: 'cash-out over the drawer',
      ),
    );
    _check('код 8 → notEnoughMoney', 'notEnoughMoney:8', _verdict(r));
    await rig.stop();
  }

  // 9 — расхождение сумм. Уже пройдено сценариями 1 и 6, здесь — ради полноты
  // таблицы и ради того, чтобы отказ читался в журнале с обеими суммами.
  {
    final rig = await _rig();
    final r = await rig.provider.fiscalizeSale(
      _sale(
        key: 'refusal-9-validation',
        positions: [_pos(name: 'Item', qty: '2', price: '100')],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('199')),
        ],
      ),
    );
    _check('код 9 → validation', 'validation:9', _verdict(r));
    _check(
      'код 9: журнал называет обе суммы',
      'да',
      (r.errorMessage ?? '').contains('200') &&
              (r.errorMessage ?? '').contains('199')
          ? 'да'
          : 'нет',
      note: 'текст отказа: ${r.errorMessage}',
    );
    await rig.stop();
  }

  // 11, 12 — смена заперта / просрочена (пульт).
  {
    final rig = await _rig();
    await rig.console('/_emul/shift', {'locked': true});
    final locked = await rig.provider.fiscalizeSale(
      _sale(
        key: 'refusal-11-shift-locked',
        positions: [_pos(name: 'Item', qty: '1', price: '100')],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('100')),
        ],
      ),
    );
    _check('код 11 → shiftError', 'shiftError:11', _verdict(locked));

    await rig.console('/_emul/shift', {'locked': false, 'stale': true});
    final stale = await rig.provider.fiscalizeSale(
      _sale(
        key: 'refusal-12-shift-stale',
        positions: [_pos(name: 'Item', qty: '1', price: '100')],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('100')),
        ],
      ),
    );
    _check('код 12 → shiftError', 'shiftError:12', _verdict(stale));
    await rig.stop();
  }

  // 13, 15 — Z- и X-отчёт по закрытой смене.
  {
    final rig = await _rig();
    final z = await rig.provider.closeShift(const FiscalShiftRequest());
    _check(
      'код 13 → shiftError на Z-отчёте',
      'shiftError',
      z.result.errorCode.name,
    );
    final x = await rig.provider.xReport(const FiscalShiftRequest());
    _check(
      'код 15 → shiftError на X-отчёте',
      'shiftError',
      x.result.errorCode.name,
    );
    await rig.stop();
  }

  // 14 — повтор ключа. Две ветки: _checkResult и replay.
  {
    final rig = await _rig();
    final req = _sale(
      key: 'refusal-14-duplicate',
      positions: [_pos(name: 'Item', qty: '1', price: '100')],
      payments: [
        FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('100')),
      ],
    );
    final first = await rig.provider.fiscalizeSale(req);
    _check(
      'код 14: первая отправка прошла',
      'ok',
      first.success ? 'ok' : _verdict(first),
    );
    final second = await rig.provider.fiscalizeSale(req);
    _check(
      'код 14 → _checkResult отвечает ОТКАЗОМ duplicate, не пустым признаком',
      'success=false code=duplicate raw=14 sign=""',
      'success=${second.success} code=${second.errorCode.name} '
      'raw=${second.rawErrorCode} sign="${second.fiscalSign ?? ''}"',
      note:
          'НАХОДКА №1 закрыта 2026-09-18. Было: success=true sign="" — кассир '
          'видел «фискализовано», чек печатался без признака, строки в '
          'WebkassaReceipts не появлялось (FiscalServiceImpl._persistReceipt '
          'выходит по !result.hasFiscalSign). Признак исходного документа '
          'дозапросить нечем: ни один из девяти путей /api/v4/* не отдаёт '
          'документ по ExternalCheckNumber — разбор в докстринге _checkResult.',
    );

    // Та же ситуация глазами очереди: строка с уже отвеченным ключом обязана
    // остаться **следом для человека**, а не исчезнуть.
    final store = InMemoryFiscalQueueStore();
    final queued = OfflineQueueingProvider(
      inner: rig.provider,
      store: store,
      isReachable: () async => true,
    );
    await store.enqueue(
      FiscalQueueEntry(
        idempotencyKey: 'refusal-14-duplicate',
        opType: FiscalQueueOp.sale,
        payload: req.toJson(),
        occurredAt: DateTime.now(),
      ),
    );
    final report = await queued.replay();
    final left = await store.failed();
    _check(
      'код 14 → replay: строка ждёт человека, а не исчезает',
      'remaining=0 duplicates=1 fiscalized=0 failed-строк=1 '
      'причина=fiscal(duplicate#14)',
      'remaining=${report.remaining} duplicates=${report.duplicates} '
      'fiscalized=${report.fiscalized} failed-строк=${left.length} '
      'причина=${left.isEmpty ? 'строки нет' : left.single.lastError}',
      note:
          'НАХОДКА №2 закрыта 2026-09-19. До 2026-09-18 дедуп уходил в '
          'fiscalized (_checkResult отвечал success раньше, чем replay '
          'успевал увидеть duplicate); с 2026-09-18 по 2026-09-19 строка '
          'убиралась как deduped — у оператора документ, у кассы ни '
          'признака, ни записи в WebkassaReceipts, и след исчезал вовсе',
    );
    await rig.stop();
  }

  // 18 — превышен лимит автономных документов.
  {
    final rig = await _rig();
    await rig.console('/_emul/offline', {'on': true, 'limit': 1});
    await rig.provider.fiscalizeSale(
      _sale(
        key: 'refusal-18-first',
        positions: [_pos(name: 'Item', qty: '1', price: '100')],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('100')),
        ],
      ),
    );
    final over = await rig.provider.fiscalizeSale(
      _sale(
        key: 'refusal-18-second',
        positions: [_pos(name: 'Item', qty: '1', price: '100')],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('100')),
        ],
      ),
    );
    _check(
      'код 18 → offlineLimitExceeded',
      'offlineLimitExceeded:18',
      _verdict(over),
    );
    await rig.stop();
  }

  // 1013 — автономный режим не разрешён кассе.
  {
    final rig = await _rig();
    await rig.console('/_emul/offline', {'on': true, 'supported': false});
    final r = await rig.provider.fiscalizeSale(
      _sale(
        key: 'refusal-1013',
        positions: [_pos(name: 'Item', qty: '1', price: '100')],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('100')),
        ],
      ),
    );
    _check(
      'код 1013 → offlineNotSupported',
      'offlineNotSupported:1013',
      _verdict(r),
    );
    await rig.stop();
  }

  // 999 — четырнадцатая ветка _mapError: default → unknown.
  {
    final rig = await _rig();
    await rig.console('/_emul/fault', {
      'path': '/api/v4/check',
      'code': 999,
      'text': 'Неизвестная ошибка оператора',
    });
    final r = await rig.provider.fiscalizeSale(
      _sale(
        key: 'refusal-999',
        positions: [_pos(name: 'Item', qty: '1', price: '100')],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('100')),
        ],
      ),
    );
    _check('код 999 → default → unknown', 'unknown:999', _verdict(r));
    await rig.stop();
  }

  // −1 — сокет закрыт без ответа. Единственный вход в очередь через
  // недоступность, и вместе с ним — весь _enqueue.
  {
    final rig = await _rig();
    final store = InMemoryFiscalQueueStore();
    final queued = OfflineQueueingProvider(
      inner: rig.provider,
      store: store,
      isReachable: () async => true,
    );
    await rig.warm();
    await rig.console('/_emul/kill', {'count': 1});
    final r = await queued.fiscalizeSale(
      _sale(
        key: 'refusal-minus1-kill',
        positions: [_pos(name: 'Item', qty: '1', price: '100')],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('100')),
        ],
      ),
    );
    _check(
      'код −1 → network → очередь',
      'queued',
      r.queued ? 'queued' : _verdict(r),
    );
    _check('код −1 → строка в очереди', '1', '${await store.pendingCount()}');

    // Та же строка после восстановления связи уезжает сама.
    final report = await queued.replay();
    _check(
      'код −1 → replay после восстановления',
      'fiscalized=1 remaining=0',
      'fiscalized=${report.fiscalized} remaining=${report.remaining}',
    );
    await rig.stop();
  }

  // −2 — молчание дольше тайм-аута клиента. Тайм-аут укорочен с 30 с до 2 с
  // ради времени прогона; ветка та же — `request.close().timeout(timeout)`.
  {
    final rig = await _rig(clientTimeout: const Duration(seconds: 2));
    await rig.warm();
    await rig.console('/_emul/latency', {'ms': 3000});
    final r = await rig.provider.fiscalizeSale(
      _sale(
        key: 'refusal-minus2-timeout',
        positions: [_pos(name: 'Item', qty: '1', price: '100')],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('100')),
        ],
      ),
    );
    _check(
      'код −2 → network по тайм-ауту',
      'network:-2',
      _verdict(r),
      note: 'тайм-аут клиента укорочен до 2 с; в продукте 30 с, ветка та же',
    );
    await rig.console('/_emul/latency', {'ms': 0});
    await rig.stop();
  }

  // −3 — ответ не JSON при HTTP 200.
  {
    final rig = await _rig();
    await rig.warm();
    await rig.console('/_emul/malformed', {'count': 1});
    final r = await rig.provider.fiscalizeSale(
      _sale(
        key: 'refusal-minus3-garbage',
        positions: [_pos(name: 'Item', qty: '1', price: '100')],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('100')),
        ],
      ),
    );
    _check('код −3 → network на неразборном ответе', 'network:-3', _verdict(r));
    await rig.stop();
  }
}

// ------------------------------------------------- остальные пути и журнал

Future<void> _happyPaths({required bool showJournal}) async {
  stdout.writeln('\n=== Девять путей: успешный проход\n');
  final rig = await _rig();
  try {
    final sale = await rig.provider.fiscalizeSale(
      _sale(
        key: 'happy-sale',
        positions: [
          _pos(name: 'Bread', qty: '2', price: '250'),
          _pos(name: 'Milk', qty: '1', price: '500'),
        ],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: _d('1000')),
        ],
      ),
    );
    _check(
      '/api/v4/check — продажа',
      'ok',
      sale.success ? 'ok' : _verdict(sale),
      note:
          '${_why(sale)} признак ${sale.fiscalSign}, смена ${sale.shiftNumber}, '
          'документ ${sale.documentNumber}, рег. ${sale.registrationNumber}',
    );

    final moneyIn = await rig.provider.moneyIn(
      FiscalMoneyRequest(
        idempotencyKey: 'happy-money-in',
        amount: _d('5000'),
        occurredAt: DateTime.now(),
      ),
    );
    _check(
      '/api/v4/MoneyOperation — внесение',
      'ok',
      moneyIn.success ? 'ok' : _verdict(moneyIn),
    );

    final moneyOut = await rig.provider.moneyOut(
      FiscalMoneyRequest(
        idempotencyKey: 'happy-money-out',
        amount: _d('2000'),
        occurredAt: DateTime.now(),
      ),
    );
    _check(
      '/api/v4/MoneyOperation — изъятие',
      'ok',
      moneyOut.success ? 'ok' : _verdict(moneyOut),
    );

    final status = await rig.provider.getStatus();
    _check(
      '/api/v4/Cashboxes — состояние',
      'online',
      status.online ? 'online' : 'offline',
    );

    final x = await rig.provider.xReport(const FiscalShiftRequest());
    _check(
      '/api/v4/XReport',
      'ok',
      x.success ? 'ok' : x.result.errorCode.name,
      note: 'в ящике ${x.cashInDrawer}, документов ${x.documentCount}',
    );

    final z = await rig.provider.closeShift(const FiscalShiftRequest());
    _check(
      '/api/v4/ZReport',
      'ok',
      z.success ? 'ok' : z.result.errorCode.name,
      note:
          'смена ${z.shiftNumber}, внесено ${z.cashIn}, изъято ${z.cashOut}, '
          'в ящике ${z.cashInDrawer}, закрыта ${z.closedAt}',
    );

    // Три пути соседних подсистем ходят тем же транспортом и тем же адресом.
    // Провайдеров ЭСФ/СНТ/ИС МПТ здесь не строим — они тянут свои модели;
    // проверяется, что путь отвечает конвертом, а не 404.
    for (final path in ['/api/v4/Esf', '/api/v4/Snt', '/api/v4/MarkCheck']) {
      final client = HttpClient();
      try {
        final token = rig.state.tokens.keys.first;
        final req = await client.postUrl(
          rig.emulator.baseUri.replace(path: path),
        );
        req.headers.contentType = ContentType.json;
        req.write(
          jsonEncode({
            'Token': token,
            'CashboxUniqueNumber': _cashbox,
            'IdempotencyKey': 'happy-$path',
            'Codes': ['0104870000000000215x!"%'],
          }),
        );
        final resp = await req.close();
        final body = await utf8.decoder.bind(resp).join();
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        _check(
          '$path — конверт',
          'Data',
          decoded.containsKey('Data') ? 'Data' : 'Errors',
        );
      } finally {
        client.close(force: true);
      }
    }

    // Пульт стоит там, где настоящая WebKassa ответит 404.
    _check(
      'пути пульта не пересекаются с девятью боевыми',
      'нет пересечений',
      kConsolePaths.any(kApiPaths.contains) ? 'ЕСТЬ' : 'нет пересечений',
    );

    if (showJournal) {
      stdout.writeln(
        '\n--- Журнал эмулятора (${rig.state.journal.length} записей)\n',
      );
      for (final e in rig.state.journal) {
        stdout.writeln(e.line);
      }
    }
  } finally {
    await rig.stop();
  }
}

Future<void> main(List<String> argv) async {
  final showJournal = argv.contains('--journal');

  stdout.writeln(
    'Проба эмулятора WebKassa. Продуктовый провайдер, настоящий HTTP.',
  );
  stdout.writeln(
    'Эмулятор умеет произвести коды: '
    '${(kEmulatedCodes.toList()..sort()).join(', ')}',
  );

  await _happyPaths(showJournal: showJournal);
  await _encodingFinding();
  await _moneyScenarios();
  await _refusals();

  final failed = _results.where((r) => !r.ok).toList();
  final defects = _results.where((r) => r.defect).toList();
  stdout.writeln(
    '\n=== Итог: ${_results.length - failed.length} из ${_results.length} сошлось',
  );
  for (final f in failed) {
    stdout.writeln(
      '  РАЗОШЛОСЬ: ${f.name} — ждали ${f.expected}, пришло ${f.actual}',
    );
  }
  if (defects.isNotEmpty) {
    stdout.writeln(
      '\n=== Дефекты продукта, закреплённые пробой (${defects.length}). '
      'Прибор их НАШЁЛ, а не создал;\n    каждый разойдётся в день починки и '
      'потребует переписать случай на верное поведение.',
    );
    for (final d in defects) {
      stdout.writeln('  * ${d.name}');
    }
  }
  exit(failed.isEmpty ? 0 : 1);
}
