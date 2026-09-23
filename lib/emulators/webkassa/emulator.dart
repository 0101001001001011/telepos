/// Эмулятор фискального оператора WebKassa — измерительный прибор, а не
/// заглушка.
///
/// # Чего этот эмулятор НЕ доказывает
///
/// **Он не доказывает, что настоящая WebKassa ведёт себя так же.** Своего
/// верного числа у него нет ни одного: девять путей, форма конверта и карта
/// кодов сняты с **нашего** клиента (`webkassa_api_client.dart`) и **нашего**
/// разбора (`webkassa_provider.dart._mapError`), то есть с нашего понимания
/// чужого протокола. Расхождение этого понимания с действительностью ловится
/// только прогоном по `devkkm.webkassa.kz`, и та задача остаётся отдельной и
/// обязательной.
///
/// Кроме того он не доказывает:
///
/// * что чек **напечатан** — принтера здесь нет;
/// * что документ принят **настоящим** оператором — оператора здесь нет;
/// * что суммы в документе верны **для покупателя**: пересчёт сверяет сумму
///   позиций с суммой оплат внутри одного и того же конверта, и обе половины
///   пришли от кассы. Числа, показанного на экране, в конверте нет, сверять
///   не с чем. Эта проверка принадлежит набору кассы, а не эмулятору;
/// * поведение настоящей WebKassa под нагрузкой, её недокументированные поля
///   и её собственные тайм-ауты;
/// * `correctionReceipt` — наш провайдер отвечает `unsupported` не спрашивая
///   сервер, эмулировать нечего.
///
/// Он доказывает ровно одно: **касса собрала конверт, который сама же считает
/// согласованным, дошла им до сети и разобрала ответ по верной ветке.**
///
/// # Механизм подстановки: **адресом**, а не подставленным `FiscalProvider`
///
/// Эмулируется зависимость, а не наш адаптер. Подстановка класса вместо
/// `WebKassaProvider` сняла бы с проверки как раз то, что вероятнее всего
/// сломано, — сборку конверта, карту кодов, повтор по истёкшему токену,
/// очередь. Точка подстановки поэтому самая дальняя, до какой можно
/// дотянуться: **сеть**. Ни один класс продукта не подменяется; адрес
/// вписывается в поле «Адрес сервера» на экране фискальных настроек, которое
/// уже есть.
///
/// # Почему этот класс живёт в `lib/`, а не в `test/`
///
/// Решение заказчика 2026-09-19: эмулятор обязан быть встроен в приложение,
/// чтобы для диагностики и проверки шаблона чека ничего не доставляли. Отсюда
/// же `BuiltinEmulatorHost` поднимает его на петле по решению оператора.
///
/// Правило раздела эмуляторов при этом не нарушено: отдельный процесс был
/// **способом** держать точку подстановки в сети, а не целью. Сокет,
/// открытый внутри приложения, держит её ровно там же — касса идёт к нему
/// своим `WebKassaApiClient`, своим конвертом, своим разбором ответа.
///
/// Запуск отдельным процессом никуда не делся: тонкая обёртка с `main()`
/// осталась в `test/emulators/webkassa/emulator.dart`, и команды живых
/// прогонов не изменились ни строкой. **Одна реализация, два вызывающих.**
///
/// # Дверь остановки
///
/// `POST /_emul/stop` и `Ctrl-C`. Дверь заведена при переезде в `lib/` и не
/// украшение: встроенный эмулятор гасится по щелчку выключателя, а запущенный
/// процессом — руками, и без двери его глушат по номеру процесса. У стенда
/// печати двери не было, и за сутки это дало три висящих процесса.
///
/// # Ограничение, а не пожелание
///
/// Файл запускается и `dart run` (через обёртку), а не только под
/// `flutter_tester`, поэтому **`package:flutter` здесь запрещён**.
/// `bin/telepos_backend.dart` под `dart run` уже не собирается именно потому,
/// что через `LocalProperties` притянул `dart:ui`. Сторож на это — в
/// `test/emulators/webkassa/emulator_test.dart`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';

import 'package:telepos/emulators/webkassa/faults.dart';
import 'package:telepos/emulators/webkassa/state.dart';

const List<String> kApiPaths = [
  '/api/v4/Authorize',
  '/api/v4/check',
  '/api/v4/MoneyOperation',
  '/api/v4/ZReport',
  '/api/v4/XReport',
  '/api/v4/Cashboxes',
  '/api/v4/Esf',
  '/api/v4/Snt',
  '/api/v4/MarkCheck',
];

/// Пути пульта. Настоящая WebKassa на них ответит 404 — и это не украшение:
/// проба, случайно нацеленная на боевой сервер, падает громко, а не проходит
/// молча.
const List<String> kConsolePaths = [
  '/_emul/fault',
  '/_emul/offline',
  '/_emul/latency',
  '/_emul/kill',
  '/_emul/malformed',
  '/_emul/http',
  '/_emul/shift',
  '/_emul/block',
  '/_emul/mark',
  '/_emul/reset',
  '/_emul/state',
  '/_emul/journal',
  '/_emul/stop',
];

class WebKassaEmulator {
  WebKassaEmulator({
    required this.state,
    this.echo = true,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final EmulatorState state;

  /// Печатать ли каждую запись журнала в консоль. Пробы читают журнал
  /// возвратом, а человек на живой проверке — глазами.
  final bool echo;

  final DateTime Function() _now;

  HttpServer? _server;

  final List<PendingFault> _faults = [];
  int _killsLeft = 0;
  int _malformedLeft = 0;

  /// Пульт `/_emul/http`: сколько ответов подряд отдать **чужим статусом с
  /// телом не-JSON** — так отвечает балансировщик перед оператором (502,
  /// 503, 504 со страницей HTML), а не сам оператор.
  int _httpLeft = 0;
  int _httpStatus = 503;
  String _httpBody = '<html><body>503 Service Unavailable</body></html>';

  Duration _latency = Duration.zero;

  /// Коды маркировки, которым пульт назначил чужой статус.
  final Map<String, String> _markStatus = {};

  Uri get baseUri =>
      Uri.parse('http://${_server!.address.address}:${_server!.port}');

  Future<void> start(String host, int port) async {
    _server = await HttpServer.bind(host, port);
    unawaited(_serve());
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _serve() async {
    final server = _server;
    if (server == null) return;
    await for (final request in server) {
      try {
        await _handle(request);
      } catch (e, st) {
        stderr.writeln(
          'эмулятор: необработанный сбой на ${request.uri.path}: $e\n$st',
        );
        try {
          await request.response.close();
        } catch (_) {}
      }
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final raw = await utf8.decoder.bind(request).join();
    Map<String, Object?> body;
    try {
      final decoded = raw.isEmpty ? <String, Object?>{} : jsonDecode(raw);
      body = decoded is Map
          ? decoded.cast<String, Object?>()
          : <String, Object?>{'_raw': raw};
    } catch (_) {
      body = <String, Object?>{'_raw': raw};
    }

    if (path.startsWith('/_emul/')) {
      await _console(request, path, body);
      return;
    }

    if (!kApiPaths.contains(path)) {
      _log(
        path,
        body,
        {'Errors': _errors(404, 'Неизвестный путь')},
        [
          'путь $path эмулятору неизвестен; настоящая WebKassa знает только девять',
        ],
        'refused:404',
      );
      await _write(request, 404, {
        'Errors': _errors(404, 'Неизвестный путь: $path'),
      });
      return;
    }

    // --- три отказа, которым нужен не ответ, а его отсутствие ------------

    if (_killsLeft > 0) {
      _killsLeft -= 1;
      _log(path, body, const {}, [
        'пульт: сокет закрыт без ответа (осталось $_killsLeft)',
        'у клиента это SocketException → errorCode -1 → FiscalErrorCode.network',
      ], 'killed');
      final socket = await request.response.detachSocket(writeHeaders: false);
      socket.destroy();
      return;
    }

    if (_latency > Duration.zero) {
      _log(path, body, const {}, [
        'пульт: задержка ${_latency.inMilliseconds} мс перед ответом',
        'если она больше 30 с, у клиента это TimeoutException → -2 → network',
      ], 'delayed');
      await Future<void>.delayed(_latency);
    }

    if (_httpLeft > 0) {
      _httpLeft -= 1;
      _log(
        path,
        body,
        {'_raw': _httpBody},
        [
          'пульт: HTTP $_httpStatus с телом не-JSON (осталось $_httpLeft)',
          'так отвечает не оператор, а то, что стоит перед ним; кода '
              'оператора в ответе нет',
        ],
        'http:$_httpStatus',
      );
      request.response
        ..statusCode = _httpStatus
        ..headers.contentType = ContentType.html
        ..write(_httpBody);
      await request.response.close();
      return;
    }

    if (_malformedLeft > 0) {
      _malformedLeft -= 1;
      _log(
        path,
        body,
        const {'_raw': 'not json at all'},
        [
          'пульт: ответ не JSON при HTTP 200 (осталось $_malformedLeft)',
          'WebKassaResponse.parse: json == null и статус < 400 → errorCode -3 → network',
        ],
        'malformed',
      );
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.text
        ..write('not json at all');
      await request.response.close();
      return;
    }

    // --- отказ, поставленный пультом на этот путь ------------------------

    final planted = _takeFault(path);
    if (planted != null) {
      final resp = {'Errors': _errors(planted.code, planted.text)};
      _log(path, body, resp, [
        'пульт: подставлен отказ ${planted.code} на $path',
        'осталось повторов: ${planted.count}',
      ], 'refused:${planted.code}');
      await _write(request, 200, resp);
      return;
    }

    // --- обычный разбор --------------------------------------------------

    final answer = _dispatch(path, body);
    _log(path, body, answer.payload, answer.reasons, answer.outcome);
    await _write(request, 200, answer.payload);
  }

  _Answer _dispatch(String path, Map<String, Object?> body) {
    switch (path) {
      case '/api/v4/Authorize':
        return _authorize(body);
      case '/api/v4/check':
        return _check(body);
      case '/api/v4/MoneyOperation':
        return _moneyOperation(body);
      case '/api/v4/ZReport':
        return _report(body, zReport: true);
      case '/api/v4/XReport':
        return _report(body, zReport: false);
      case '/api/v4/Cashboxes':
        return _cashboxes(body);
      case '/api/v4/Esf':
        return _esf(body);
      case '/api/v4/Snt':
        return _snt(body);
      case '/api/v4/MarkCheck':
        return _markCheck(body);
    }
    return _Answer.refuse(999, 'Путь не разобран', const []);
  }

  // ---------------------------------------------------------------- пути

  _Answer _authorize(Map<String, Object?> body) {
    final login = body['Login']?.toString() ?? '';
    final password = body['Password']?.toString() ?? '';
    if (login != state.login || password != state.password) {
      return _Answer.refuse(1, 'Неверный логин или пароль', [
        'пришёл логин «$login»; эмулятор знает «${state.login}»',
        'код 1 → badCredentials: нетранзиентный, очередь его не берёт',
      ]);
    }
    final token = state.issue(_now());
    return _Answer.ok(
      {'Token': token.value},
      [
        'токен ${token.value} выдан на ${state.tokenTtl.inSeconds} с',
        'через ${state.tokenTtl.inSeconds} с любой путь ответит кодом 3 → tokenExpired',
      ],
    );
  }

  _Answer _check(Map<String, Object?> body) {
    final reasons = <String>[];
    final tokenFault = _checkToken(body, reasons);
    if (tokenFault != null) return tokenFault;

    final box = _cashbox(body);
    if (box == null) {
      return _Answer.refuse(6, 'Касса с таким заводским номером не найдена', [
        ...reasons,
        'пришёл CashboxUniqueNumber «${body['CashboxUniqueNumber']}»; '
            'эмулятор знает ${state.cashboxes.keys.toList()}',
      ]);
    }
    if (box.blocked) {
      return _Answer.refuse(7, 'Касса заблокирована', [
        ...reasons,
        'пульт: касса ${box.uniqueNumber} заблокирована',
      ]);
    }
    if (box.offlineMode && !box.offlineSupported) {
      return _Answer.refuse(1013, 'Автономный режим не разрешён этой кассе', [
        ...reasons,
        'пульт: offline on, supported false',
      ]);
    }
    if (box.shiftLocked) {
      return _Answer.refuse(11, 'Смена не может быть открыта', [
        ...reasons,
        'пульт: смена заперта',
      ]);
    }
    if (box.shiftStale) {
      return _Answer.refuse(12, 'Смена открыта более 24 часов', [
        ...reasons,
        'пульт: смена помечена просроченной',
      ]);
    }

    final key = body['ExternalCheckNumber']?.toString() ?? '';
    if (key.isEmpty) {
      return _Answer.refuse(9, 'Не указан ExternalCheckNumber', [
        ...reasons,
        'без ключа идемпотентности повтор неотличим от новой продажи',
      ]);
    }
    final already = state.answered[key];
    if (already != null) {
      return _Answer.refuse(
        14,
        'Документ с ExternalCheckNumber «$key» уже зарегистрирован',
        [
          ...reasons,
          'ключ $key уже отвечен: CheckNumber ${already['CheckNumber']}',
          // Признак исходного документа эмулятор знает (вот он, рядом), а в
          // ответ его НЕ кладёт — и это верность протоколу, а не скупость:
          // настоящая WebKassa на код 14 отдаёт только текст с ключом. Отдай
          // мы тут CheckNumber — касса научилась бы его читать, проба бы
          // зеленела, а на живом операторе признака бы не было.
          'признак в ответ не кладётся: настоящий оператор его тут не даёт',
          'у нас это _checkResult → _failure → duplicate: чек помечается '
              'непрофискализованным с названной причиной',
        ],
      );
    }

    final recount = recountCheck(body, state.vat);
    reasons.addAll(recount.reasons);
    if (!recount.agreed) {
      return _Answer.refuse(9, recount.complaint!, [
        ...reasons,
        'допуск нулевой: эмулятор обязан быть строже сервиса, а не мягче',
      ]);
    }

    if (!box.shiftOpen) {
      box.openShiftImplicitly(_now());
      reasons.add('смена открыта неявно, номер ${box.shiftNumber}');
    }

    if (box.offlineMode) {
      box.offlineSince ??= _now();
      box.offlineDocs += 1;
      if (box.offlineLimit > 0 && box.offlineDocs > box.offlineLimit) {
        return _Answer.refuse(18, 'Превышен лимит автономных документов', [
          ...reasons,
          'автономных документов ${box.offlineDocs} при лимите ${box.offlineLimit}',
        ]);
      }
    }

    final operationType = (body['OperationType'] as num?)?.toInt() ?? 2;
    box.checkOrderNumber += 1;
    box.fiscalSignSeq += 1;
    final sign = _sign(box.fiscalSignSeq);

    // Наличные в ящике двигаются только наличной частью оплаты.
    final cash = _cashPart(body);
    switch (operationType) {
      case 2: // продажа
        box.sellCount += 1;
        box.sellTotal += recount.positionsTotal;
        box.sellVat += recount.vatTotal;
        box.cashInDrawer += cash;
      case 3: // возврат продажи
        box.returnCount += 1;
        box.returnTotal += recount.positionsTotal;
        box.cashInDrawer -= cash;
      default:
        break;
    }
    reasons.add(
      'ящик: наличная часть $cash, в ящике теперь ${box.cashInDrawer}',
    );

    final data = <String, Object?>{
      'CheckNumber': sign,
      'Cashbox': {'RegistrationNumber': box.registrationNumber},
      'TicketUrl': 'http://emulated.webkassa.local/ticket/$sign',
      'ShiftNumber': box.shiftNumber,
      'CheckOrderNumber': box.checkOrderNumber,
      'DateTime': _now().toIso8601String(),
      'OfflineMode': box.offlineMode,
    };
    state.answered[key] = data;
    reasons.add('ключ $key запомнен: повтор ответит кодом 14');
    return _Answer.ok(data, reasons);
  }

  _Answer _moneyOperation(Map<String, Object?> body) {
    final reasons = <String>[];
    final tokenFault = _checkToken(body, reasons);
    if (tokenFault != null) return tokenFault;

    final box = _cashbox(body);
    if (box == null) {
      return _Answer.refuse(6, 'Касса не найдена', reasons);
    }
    if (box.blocked) {
      return _Answer.refuse(7, 'Касса заблокирована', reasons);
    }

    final key = body['ExternalCheckNumber']?.toString() ?? '';
    if (key.isNotEmpty && state.answered.containsKey(key)) {
      return _Answer.refuse(14, 'Операция с ключом «$key» уже проведена', [
        ...reasons,
        'у нас это _failure → duplicate в _moneyOp',
      ]);
    }

    final direction = (body['OperationType'] as num?)?.toInt() ?? 0;
    final sum = money(body['Sum']);
    reasons.add(
      'операция ${direction == 0 ? 'внесение' : 'изъятие'} на $sum, '
      'в ящике ${box.cashInDrawer}',
    );

    if (direction == 1 && sum > box.cashInDrawer) {
      return _Answer.refuse(8, 'Недостаточно денег в ящике', [
        ...reasons,
        'изъятие $sum больше остатка ${box.cashInDrawer}',
      ]);
    }

    if (!box.shiftOpen) {
      box.openShiftImplicitly(_now());
      reasons.add('смена открыта неявно, номер ${box.shiftNumber}');
    }

    if (direction == 0) {
      box.cashInDrawer += sum;
      box.putMoneySum += sum;
    } else {
      box.cashInDrawer -= sum;
      box.takeMoneySum += sum;
    }
    box.fiscalSignSeq += 1;
    box.checkOrderNumber += 1;

    final data = <String, Object?>{
      'CheckNumber': _sign(box.fiscalSignSeq),
      'DateTime': _now().toIso8601String(),
      'OfflineMode': box.offlineMode,
    };
    if (key.isNotEmpty) state.answered[key] = data;
    reasons.add('в ящике теперь ${box.cashInDrawer}');
    return _Answer.ok(data, reasons);
  }

  _Answer _report(Map<String, Object?> body, {required bool zReport}) {
    final reasons = <String>[];
    final tokenFault = _checkToken(body, reasons);
    if (tokenFault != null) return tokenFault;

    final box = _cashbox(body);
    if (box == null) {
      return _Answer.refuse(6, 'Касса не найдена', reasons);
    }
    if (!box.shiftOpen) {
      return zReport
          ? _Answer.refuse(13, 'Нет открытой смены', [
              ...reasons,
              'Z-отчёт по закрытой смене — код 13 → shiftError',
            ])
          : _Answer.refuse(15, 'Нет открытой смены для X-отчёта', [
              ...reasons,
              'X-отчёт по закрытой смене — код 15 → shiftError',
            ]);
    }

    final data = <String, Object?>{
      'ReportNumber': '${zReport ? 'Z' : 'X'}${box.shiftNumber}',
      'ShiftNumber': box.shiftNumber,
      'DocumentCount': box.checkOrderNumber,
      'PutMoneySum': box.putMoneySum.toString(),
      'TakeMoneySum': box.takeMoneySum.toString(),
      'SumInCashbox': box.cashInDrawer.toString(),
      'ControlSum': box.sellTotal.toString(),
      'StartOn': box.startedAt.toIso8601String(),
      if (zReport) 'CloseOn': _now().toIso8601String(),
    };
    reasons.add(
      'смена ${box.shiftNumber}: документов ${box.checkOrderNumber}, '
      'продаж ${box.sellCount} на ${box.sellTotal}, в ящике ${box.cashInDrawer}',
    );
    if (zReport) {
      box.shiftOpen = false;
      box.checkOrderNumber = 0;
      box.putMoneySum = Decimal.zero;
      box.takeMoneySum = Decimal.zero;
      box.sellCount = 0;
      box.sellTotal = Decimal.zero;
      box.sellVat = Decimal.zero;
      box.returnCount = 0;
      box.returnTotal = Decimal.zero;
      box.offlineDocs = 0;
      box.offlineSince = null;
      reasons.add(
        'смена закрыта; деньги в ящике не тронуты — их изымают отдельно',
      );
    }
    return _Answer.ok(data, reasons);
  }

  _Answer _cashboxes(Map<String, Object?> body) {
    final reasons = <String>[];
    final tokenFault = _checkToken(body, reasons);
    if (tokenFault != null) return tokenFault;
    return _Answer.ok(
      {
        'Cashboxes': [
          for (final box in state.cashboxes.values)
            {
              'UniqueNumber': box.uniqueNumber,
              'RegistrationNumber': box.registrationNumber,
              'ShiftOpen': box.shiftOpen,
              'ShiftNumber': box.shiftNumber,
              'Blocked': box.blocked,
            },
        ],
      },
      [...reasons, 'касс в эмуляторе: ${state.cashboxes.length}'],
    );
  }

  _Answer _esf(Map<String, Object?> body) {
    final reasons = <String>[];
    final tokenFault = _checkToken(body, reasons);
    if (tokenFault != null) return tokenFault;
    final operation = body['Operation']?.toString() ?? 'import';
    final key = body['IdempotencyKey']?.toString() ?? '';
    final reg = body['RegistrationNumber']?.toString();
    reasons.add('ЭСФ: операция $operation, ключ «$key»');
    return _Answer.ok({
      'RegistrationNumber': reg ?? 'ESF-${key.hashCode.abs()}',
      'Status': operation == 'revoke' ? 'revoked' : 'delivered',
    }, reasons);
  }

  _Answer _snt(Map<String, Object?> body) {
    final reasons = <String>[];
    final tokenFault = _checkToken(body, reasons);
    if (tokenFault != null) return tokenFault;
    final operation = body['Operation']?.toString() ?? 'submit';
    final key = body['IdempotencyKey']?.toString() ?? '';
    final reg = body['RegistrationNumber']?.toString();
    reasons.add('СНТ: операция $operation, ключ «$key»');
    return _Answer.ok({
      'RegistrationNumber': reg ?? 'SNT-${key.hashCode.abs()}',
      'Status': operation,
    }, reasons);
  }

  _Answer _markCheck(Map<String, Object?> body) {
    final reasons = <String>[];
    final tokenFault = _checkToken(body, reasons);
    if (tokenFault != null) return tokenFault;
    final codes = (body['Codes'] as List?) ?? const [];
    final results = <Map<String, Object?>>[];
    for (final raw in codes) {
      final code = raw.toString();
      final status = _markStatus[code] ?? 'in_circulation';
      results.add({
        'Code': code,
        'Status': status,
        'Valid': status == 'in_circulation',
        'OwnerBin': '123456789012',
        'ProductGroup': body['ProductGroup']?.toString() ?? 'milk',
      });
      reasons.add('КМ «$code» → $status');
    }
    return _Answer.ok({'Results': results}, reasons);
  }

  // ------------------------------------------------------------- служебное

  /// Проверка токена. Два разных кода намеренно: код 2 — токена нет вовсе
  /// (пустой или чужой), код 3 — выданный, но просроченный. Оба у нас
  /// сходятся в `tokenExpired`, и **обе строки `case` в `_mapError` обязаны
  /// быть достижимы порознь**, иначе одну из них можно удалить незаметно.
  _Answer? _checkToken(Map<String, Object?> body, List<String> reasons) {
    final raw = body['Token']?.toString() ?? '';
    if (raw.isEmpty) {
      return _Answer.refuse(2, 'Токен не передан', [
        ...reasons,
        'поле Token пусто → код 2 → tokenExpired (транзиентный)',
      ]);
    }
    final token = state.tokens[raw];
    if (token == null) {
      return _Answer.refuse(2, 'Токен не найден', [
        ...reasons,
        'токен «$raw» эмулятор не выдавал → код 2 → tokenExpired',
      ]);
    }
    if (token.expiredAt(_now())) {
      state.tokens.remove(raw);
      return _Answer.refuse(3, 'Срок действия токена истёк', [
        ...reasons,
        'токен выдан ${token.issuedAt.toIso8601String()}, TTL ${token.ttl.inSeconds} с',
        'у нас это _withReauthRetry: перевыпуск и повтор операции',
      ]);
    }
    reasons.add('токен «$raw» действителен');
    return null;
  }

  EmulatedCashbox? _cashbox(Map<String, Object?> body) {
    final name =
        (body['CashboxUniqueNumber'] ?? body['cashboxUniqueNumber'])
            ?.toString() ??
        '';
    if (name.isEmpty && state.cashboxes.length == 1) {
      return state.cashboxes.values.first;
    }
    return state.cashboxes[name];
  }

  Decimal _cashPart(Map<String, Object?> body) {
    var cash = Decimal.zero;
    for (final raw in (body['Payments'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final p = raw.cast<String, Object?>();
      if (((p['PaymentType'] as num?)?.toInt() ?? 0) == 0) {
        cash += money(p['Sum']);
      }
    }
    return cash;
  }

  String _sign(int seq) => (900000000000 + seq).toString();

  PendingFault? _takeFault(String path) {
    for (final fault in List<PendingFault>.from(_faults)) {
      if (fault.path != path) continue;
      if (fault.afterN > 0) {
        fault.afterN -= 1;
        return null;
      }
      if (fault.count <= 0) {
        _faults.remove(fault);
        continue;
      }
      fault.count -= 1;
      if (fault.count <= 0) _faults.remove(fault);
      return fault;
    }
    return null;
  }

  List<Map<String, Object?>> _errors(int code, String text) => [
    {'Code': code, 'Text': text},
  ];

  void _log(
    String path,
    Map<String, Object?> request,
    Map<String, Object?> response,
    List<String> reasons,
    String outcome,
  ) {
    final safe = Map<String, Object?>.from(request);
    if (safe.containsKey('Password')) safe['Password'] = '***';
    final entry = state.record(
      path: path,
      request: safe,
      response: response,
      reasons: reasons,
      outcome: outcome,
      now: _now(),
    );
    if (echo) stdout.writeln(entry.line);
  }

  Future<void> _write(
    HttpRequest request,
    int status,
    Map<String, Object?> payload,
  ) async {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(payload));
    await request.response.close();
  }

  // ---------------------------------------------------------------- пульт

  Future<void> _console(
    HttpRequest request,
    String path,
    Map<String, Object?> body,
  ) async {
    Map<String, Object?> answer;
    switch (path) {
      case '/_emul/fault':
        final fault = PendingFault(
          path: body['path']?.toString() ?? '/api/v4/check',
          code: (body['code'] as num?)?.toInt() ?? 999,
          text: body['text']?.toString() ?? 'Отказ по требованию пульта',
          count: (body['count'] as num?)?.toInt() ?? 1,
          afterN: (body['afterN'] as num?)?.toInt() ?? 0,
        );
        _faults.add(fault);
        answer = {'ok': true, 'fault': fault.toJson()};
      case '/_emul/offline':
        for (final box in state.cashboxes.values) {
          box.offlineMode = body['on'] as bool? ?? true;
          box.offlineLimit =
              (body['limit'] as num?)?.toInt() ?? box.offlineLimit;
          box.offlineSupported = body['supported'] as bool? ?? true;
          if (!box.offlineMode) {
            box.offlineDocs = 0;
            box.offlineSince = null;
          }
        }
        answer = {'ok': true, 'state': state.toJson()};
      case '/_emul/latency':
        _latency = Duration(milliseconds: (body['ms'] as num?)?.toInt() ?? 0);
        answer = {'ok': true, 'latencyMs': _latency.inMilliseconds};
      case '/_emul/kill':
        _killsLeft = (body['count'] as num?)?.toInt() ?? 1;
        answer = {'ok': true, 'killsLeft': _killsLeft};
      case '/_emul/malformed':
        _malformedLeft = (body['count'] as num?)?.toInt() ?? 1;
        answer = {'ok': true, 'malformedLeft': _malformedLeft};
      case '/_emul/http':
        _httpLeft = (body['count'] as num?)?.toInt() ?? 1;
        _httpStatus = (body['status'] as num?)?.toInt() ?? 503;
        _httpBody = body['body']?.toString() ?? _httpBody;
        answer = {'ok': true, 'httpLeft': _httpLeft, 'status': _httpStatus};
      case '/_emul/shift':
        for (final box in state.cashboxes.values) {
          if (body.containsKey('open')) {
            final open = body['open'] as bool? ?? false;
            if (open && !box.shiftOpen) {
              box.openShiftImplicitly(_now());
            } else if (!open) {
              box.shiftOpen = false;
            }
          }
          if (body.containsKey('locked')) {
            box.shiftLocked = body['locked'] as bool? ?? false;
          }
          if (body.containsKey('stale')) {
            box.shiftStale = body['stale'] as bool? ?? false;
          }
        }
        answer = {'ok': true, 'state': state.toJson()};
      case '/_emul/block':
        for (final box in state.cashboxes.values) {
          box.blocked = body['on'] as bool? ?? true;
        }
        answer = {'ok': true, 'state': state.toJson()};
      case '/_emul/mark':
        final code = body['code']?.toString() ?? '';
        final status = body['status']?.toString() ?? 'retired';
        if (code.isEmpty) {
          _markStatus.clear();
        } else {
          _markStatus[code] = status;
        }
        answer = {'ok': true, 'marks': _markStatus};
      case '/_emul/reset':
        _faults.clear();
        _killsLeft = 0;
        _malformedLeft = 0;
        _httpLeft = 0;
        _latency = Duration.zero;
        _markStatus.clear();
        state.reset(_now());
        answer = {'ok': true, 'state': state.toJson()};
      case '/_emul/state':
        answer = {
          'state': state.toJson(),
          'faults': [for (final f in _faults) f.toJson()],
          'killsLeft': _killsLeft,
          'malformedLeft': _malformedLeft,
          'latencyMs': _latency.inMilliseconds,
        };
      case '/_emul/journal':
        answer = {
          'journal': [for (final e in state.journal) e.toJson()],
        };
      case '/_emul/stop':
        // Дверь остановки. Правило дерева: поднял — умей погасить; у стенда
        // печати двери не было, и за сутки это дало три висящих процесса.
        // Гашение отложено на полвздоха: `stop()` закрывает сервер силой, и
        // сделай мы это сразу — ответ «останавливаюсь» не успел бы уйти, а
        // стучавший увидел бы обрыв вместо подтверждения.
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'stopping': true}));
        await request.response.close();
        unawaited(Future<void>.delayed(const Duration(milliseconds: 50), stop));
        return;
      default:
        request.response
          ..statusCode = 404
          ..write(
            jsonEncode({'ok': false, 'error': 'нет такого пульта: $path'}),
          );
        await request.response.close();
        return;
    }
    await _write(request, 200, answer);
  }
}

class _Answer {
  _Answer.ok(Map<String, Object?> data, this.reasons)
    : payload = {'Data': data},
      outcome = 'ok';

  _Answer.refuse(int code, String text, List<String> reasons)
    : payload = {
        'Errors': [
          {'Code': code, 'Text': text},
        ],
      },
      reasons = [...reasons, 'отказ $code: $text'],
      outcome = 'refused:$code';

  final Map<String, Object?> payload;
  final List<String> reasons;
  final String outcome;
}
