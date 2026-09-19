/// Эмулятор провайдера QR/СБП — измерительный прибор, а не заглушка.
///
/// # Почему он живёт в `lib/`, а запуск из командной строки — в `test/`
///
/// Решение заказчика 2026-09-19: эмулятор обязан быть встроен в приложение,
/// «а то это ещё что-то ставить надо будет». Класс поэтому часть продукта, а
/// в `test/emulators/sbp/emulator.dart` осталась тонкая обёртка с `main()`:
/// команды запуска не изменились ни строкой. **Одна реализация, два
/// вызывающих** — тот же приём, которым в дереве уже живут ESC/POS и
/// последовательные приборы.
///
/// **Правило раздела эмуляторов при этом не нарушено.** Оно требует, чтобы
/// точка подстановки была **самой дальней — сетью**, а не интерфейсом над
/// адаптером; отдельный процесс был способом этого добиться, а не целью.
/// Эмулятор внутри приложения открывает настоящий серверный сокет, и касса
/// идёт к нему своим `HttpQrPaymentProvider`: своей сборкой запроса, своим
/// разбором ответа, своими тайм-аутами и своим разбором обрыва.
///
/// # Механизм подстановки: **адресом**
///
/// Правок в продукте под эмулятор — **ноль**. У провайдера QR есть адрес
/// (`QrProviderSettings.baseUrl`, строка `qr_provider_configs` в базе
/// кассы, схема v46), и вписать туда `http://127.0.0.1:8890` — весь способ.
/// До v46 эта ссылка вела в никуда: хранилища адреса не было. Значит
/// проверяется `HttpQrPaymentProvider` целиком: сборка запроса, разбор
/// ответа, тайм-ауты, обрыв связи и разбор незнакомого тела.
///
/// Подменять `QrPaymentProvider` фальшивкой было бы проще и не доказывало бы
/// ничего — фальшивка не умеет оборвать соединение на середине ответа.
///
/// # ГЛАВНОЕ, ЧТО НАДО ЗНАТЬ ОБ ЭТОМ ЭМУЛЯТОРЕ
///
/// **Форма протокола наша.** Единого протокола СБП/QR у нас в дереве нет,
/// договора с провайдером нет, документации нет. Пути `/sbp/v1/*`, имена
/// полей и коды состояний **придуманы здесь**, и ни одно из них не
/// является утверждением о поведении настоящего провайдера.
///
/// Что этот эмулятор проверяет **по-настоящему** — не форму, а **время**:
/// подтверждение приходит после вопроса, может опоздать, может не прийти
/// вовсе, может прийти дважды и может прийти после того, как касса
/// сдалась. Это свойства не протокола, а самого способа оплаты, и они
/// одинаковы у любого провайдера.
///
/// # Чего этот эмулятор НЕ доказывает
///
/// * **Что деньги списаны.** Банка здесь нет.
/// * **Что настоящий провайдер называет состояния этими словами.**
/// * **Что QR-код читается телефоном.** Изображения здесь нет — только
///   строка нагрузки.
/// * **Что вебхук доедет.** Здесь только опрос: касса спрашивает сама.
///   Вебхук требует адреса кассы, доступного снаружи, — которого у кассы
///   в магазине нет, и это не упущение эмулятора, а свойство места.
/// * **Что встроенный выключатель поднимает именно его.** Класс ничего не
///   знает ни о настройках кассы, ни о `BuiltinEmulatorHost`; связь между
///   ними проверяется своими пробами.
///
/// # Вызываемые отказы — **девять**, и каждый открывает свою ветку
///
/// | Пульт | Что делает | Что открывает в продукте |
/// | --- | --- | --- |
/// | `/_emul/pay` | покупатель заплатил | счастливый путь |
/// | `/_emul/pay {afterMs}` | заплатил **позже терпения кассы** | «оплачено после того, как касса сдалась» |
/// | `/_emul/pay {times: 2}` | подтверждение **дважды** | деньги не берутся второй раз |
/// | `/_emul/pay {amount}` | заплатил **меньше** | «оплачено частично» |
/// | `/_emul/decline` | покупатель отказался | `failed` с названной причиной |
/// | `/_emul/expire` | срок вышел на той стороне | `expired` |
/// | (ничего не делать) | **молчание покупателя** | терпение кассы кончается |
/// | `fault: silence` | молчание **провайдера** | `qr_timeout` |
/// | `fault: kill` | связь оборвана | `qr_network` |
/// | `fault: refuseConnect` | сокет не принят | `qr_network` |
/// | `fault: garbage` | тело не разбирается | `qr_malformed_reply` |
/// | `fault: busy` | «занят, спросите позже» | транзиентный отказ |
/// | `fault: unknownIntent` | «такого нет» | `qr_unknown_intent` |
/// | `fault: rejected` | запрос отвергнут | `qr_rejected` |
/// | `fault: reverseUnsupported` | возврата нет | `qr_reverse_unsupported` (отказ **значением**) |
///
/// **Молчание покупателя** — не отказ пульта, а его отсутствие, и это
/// правильно: провайдер, у которого нельзя «ничего не делать», не умеет
/// воспроизвести самый обычный исход QR-оплаты — покупатель передумал.
///
/// # Дверь остановки
///
/// `POST /_emul/stop`, `Ctrl-C`, `--stop`. У стенда её нет, и это уже
/// стоило дереву трёх висящих процессов.
///
/// # Запуск отдельным процессом
///
/// ```
/// dart run test/emulators/sbp/emulator.dart --port 8890 --control 8900
/// dart run test/emulators/sbp/emulator.dart --stop --control 8900
/// ```
///
/// `package:flutter` здесь запрещён: файл поднимается и `dart run`, и
/// встроенным держателем. Сторож — `emulator_guards_test.dart`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Состояния на проводе эмулятора. **Наши**, см. докстринг библиотеки.
const String kCreated = 'created';
const String kPending = 'pending';
const String kPaid = 'paid';
const String kExpired = 'expired';
const String kCancelled = 'cancelled';
const String kFailed = 'failed';
const String kReversed = 'reversed';

/// Отказы, вызываемые пультом. Все имена — наши.
const List<String> kFaults = <String>[
  'silence',
  'kill',
  'refuseConnect',
  'garbage',
  'busy',
  'unknownIntent',
  'rejected',
  'reverseUnsupported',
  'http500',
];

/// Деньги строкой → тысячные доли целым; не число — `null`. Без `double`.
int? millisOfMoney(Object? raw) {
  if (raw is! String) return null;
  final match = RegExp(r'^(\d+)(?:\.(\d{1,3}))?$').firstMatch(raw.trim());
  if (match == null) return null;
  final whole = int.parse(match.group(1)!);
  final fraction = (match.group(2) ?? '').padRight(3, '0');
  return whole * 1000 + int.parse(fraction);
}

/// Тысячные доли → деньги строкой.
String moneyOfMillis(int millis) {
  final whole = millis ~/ 1000;
  final fraction = (millis % 1000).toString().padLeft(3, '0');
  return '$whole.$fraction';
}

/// Намерение на стороне провайдера.
class SbpIntent {
  SbpIntent({
    required this.id,
    required this.intentKey,
    required this.amount,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String intentKey;

  /// Сумма **строкой десятичного числа**, как и всё денежное на проводе
  /// (I159). Ни одного `double` в денежном пути этого файла.
  final String amount;

  final DateTime createdAt;
  final DateTime expiresAt;

  String status = kPending;
  String? paidAmount;
  DateTime? confirmedAt;
  String? message;

  /// Сколько раз этому намерению говорили «оплачено».
  int confirmations = 0;

  /// Сколько уже возвращено — **в тысячных долях**, целым числом: ни
  /// одного `double` в денежном пути (задача 26).
  int refundedMillis = 0;

  String get payload =>
      'https://qr.emul.local/pay?id=$id&sum=$amount';

  Map<String, Object?> toWire() => {
    'intentId': id,
    'intentKey': intentKey,
    'status': status,
    'amount': amount,
    'paidAmount': paidAmount,
    'payload': payload,
    'expiresAt': expiresAt.toIso8601String(),
    'confirmedAt': confirmedAt?.toIso8601String(),
    'confirmations': confirmations,
    'refunded': moneyOfMillis(refundedMillis),
    if (message != null) 'message': message,
  };
}

class SbpEmulator {
  SbpEmulator({this.echo = true, this.ttl = const Duration(minutes: 5)});

  final bool echo;
  final Duration ttl;

  HttpServer? _server;
  HttpServer? _control;

  final List<Map<String, Object?>> journal = [];

  /// Намерения по нашему ключу идемпотентности — **не по ид провайдера**.
  ///
  /// Это и есть весь механизм «повтор не создаёт второго»: карта по
  /// [SbpIntent.intentKey], и второе `POST /sbp/v1/qr` с тем же ключом
  /// достаёт из неё прежнее намерение.
  final Map<String, SbpIntent> byKey = {};
  final Map<String, SbpIntent> byId = {};

  /// Ответы на возвраты по ключу возврата кассы (задача 26): повтор с тем
  /// же ключом получает прежний ответ, деньги второй раз не возвращаются.
  final Map<String, Map<String, Object?>> refundsByKey = {};

  String fault = '';
  int faultsLeft = 0;
  bool refuseConnect = false;
  Duration latency = Duration.zero;
  int _counter = 0;

  /// Отложенные подтверждения — чтобы [stop] мог их снять и не оставить
  /// висящего таймера после теста.
  final List<Timer> _timers = [];

  int get port => _server?.port ?? 0;
  int get controlPort => _control?.port ?? 0;

  String get baseUrl => 'http://127.0.0.1:$port';

  Future<void> start(String host, int port) async {
    _server = await HttpServer.bind(host, port);
    unawaited(_serve());
  }

  Future<void> startControl(String host, int port) async {
    _control = await HttpServer.bind(host, port);
    unawaited(_serveControl());
  }

  String? _takeFault() {
    if (fault.isEmpty || faultsLeft <= 0) return null;
    faultsLeft--;
    final named = fault;
    if (faultsLeft == 0) fault = '';
    return named;
  }

  Future<void> _serve() async {
    final server = _server;
    if (server == null) return;
    await for (final request in server) {
      if (refuseConnect) {
        _log(
          'refuseConnect',
          'соединение отвергнуто: отказ «refuseConnect» — касса обязана '
          'ответить транзиентным qr_network, а не объявить намерение '
          'провалившимся',
        );
        await request.response.close().catchError((_) {});
        try {
          await server.close(force: true);
        } catch (_) {}
        _server = null;
        return;
      }
      unawaited(_route(request));
    }
  }

  /// Заголовки `authorization`, пришедшие на провод провайдера, — по
  /// порядку.
  ///
  /// Существуют ради пробы секрета: «ключа нет ни в одном ответе кассы
  /// терминалу» зелено и у кассы, которая ключ не читает вовсе. Проба
  /// обязана увидеть ключ **здесь** — там, куда он и должен ехать.
  final List<String?> authorizations = [];

  Future<void> _route(HttpRequest request) async {
    authorizations.add(request.headers.value('authorization'));
    Map<String, Object?> body = const {};
    if (request.method == 'POST') {
      final raw = await utf8.decoder.bind(request).join();
      if (raw.trim().isNotEmpty) {
        try {
          body = (jsonDecode(raw) as Map).cast<String, Object?>();
        } catch (_) {}
      }
    }

    final named = _takeFault();
    switch (named) {
      case 'silence':
        _log(
          'fault',
          'ответа не будет: отказ «silence» — касса обязана дождаться '
          'своего тайм-аута и ответить qr_timeout',
        );
        return; // соединение висит, ответа нет
      case 'kill':
        // **Сокет рвётся БЕЗ заголовков.** Первая версия звала
        // `response.close()` и рвала после — и это было не то: клиент
        // получал вполне законный ответ 200 с пустым телом, продукт
        // разбирал его как «непонятное тело» (`qr_malformed_reply`,
        // отказ НЕ транзиентный) и **хоронил намерение**, при котором
        // деньги могли уже уйти.
        //
        // Отказ, притворяющийся другим отказом, хуже отсутствующего: он
        // красит сторожа зелёным по неверной причине. `writeHeaders:
        // false` — единственный способ сказать «связи нет», а не
        // «ответ пустой».
        _log(
          'fault',
          'связь оборвана без единого заголовка: отказ «kill» — касса '
          'обязана ответить транзиентным qr_network и НЕ хоронить '
          'намерение',
        );
        try {
          final socket = await request.response.detachSocket(
            writeHeaders: false,
          );
          socket.destroy();
        } catch (_) {}
        return;
      case 'garbage':
        _log(
          'fault',
          'тело не JSON: отказ «garbage» — касса обязана ответить '
          'qr_malformed_reply, а не упасть исключением наружу',
        );
        await _write(request, 200, null, raw: '<<не json>>');
        return;
      case 'http500':
        _log('fault', 'HTTP 500: отказ «http500»');
        await _write(request, 500, {'error': 'internal'});
        return;
      case 'busy':
        _log('fault', 'провайдер занят: отказ «busy» — транзиентный');
        await _write(request, 503, {
          'error': 'busy',
          'message': 'провайдер занят, спросите позже',
        });
        return;
      case 'unknownIntent':
        _log('fault', 'намерения нет: отказ «unknownIntent»');
        await _write(request, 404, {'error': 'unknown_intent'});
        return;
      case 'rejected':
        _log('fault', 'запрос отвергнут: отказ «rejected»');
        await _write(request, 422, {
          'error': 'rejected',
          'message': 'сумма вне допустимого предела',
        });
        return;
      case 'reverseUnsupported':
        // 501, а не 4xx: «я такого не умею», а не «ты неправильно
        // попросил». Продукт обязан отличить одно от другого — первое
        // лечится другим каналом возврата, второе исправлением запроса.
        _log(
          'fault',
          'возврат не поддержан: отказ «reverseUnsupported» — касса обязана '
          'ответить ЗНАЧЕНИЕМ, а не исключением и не молчанием',
        );
        await _write(request, 501, {
          'error': 'reverse_unsupported',
          'message': 'возврат по этому каналу не поддержан',
        });
        return;
    }

    final path = request.uri.path;
    if (path == '/sbp/v1/qr' && request.method == 'POST') {
      await _create(request, body);
      return;
    }
    final match = RegExp(r'^/sbp/v1/qr/([^/]+)(/cancel|/refund)?$')
        .firstMatch(path);
    if (match != null) {
      final id = match.group(1)!;
      final tail = match.group(2);
      final intent = byId[id];
      if (intent == null) {
        _log('poll', 'спросили про $id — такого намерения нет');
        await _write(request, 404, {'error': 'unknown_intent'});
        return;
      }
      _expireIfDue(intent);
      if (tail == '/cancel') {
        await _cancel(request, intent);
      } else if (tail == '/refund') {
        await _refund(request, intent, body);
      } else {
        _log('poll', 'состояние $id — ${intent.status}');
        await _write(request, 200, intent.toWire());
      }
      return;
    }

    await _write(request, 404, {'error': 'no_such_path', 'path': path});
  }

  Future<void> _create(HttpRequest request, Map<String, Object?> body) async {
    final key = body['intentKey'] as String?;
    final amount = body['amount'];
    if (key == null || key.isEmpty || amount is! String) {
      _log(
        'create',
        'запрос без ключа идемпотентности или без суммы строкой — отказ',
      );
      await _write(request, 400, {
        'error': 'rejected',
        'message': 'нужны intentKey и amount строкой',
      });
      return;
    }

    final existing = byKey[key];
    if (existing != null) {
      // **Идемпотентность на стороне провайдера.** Второе создание с тем
      // же ключом возвращает **то же самое** намерение, а не второе:
      // иначе повтор, вызванный обрывом ответа, взял бы у покупателя
      // деньги дважды. Флаг `existed` существует ради пробы — без него
      // «повтор не создал второго» доказывается только числом строк на
      // той стороне, которого у продукта нет.
      _expireIfDue(existing);
      _log(
        'create',
        'ключ $key уже известен → отдано прежнее намерение ${existing.id} '
        '(${existing.status}); второго намерения НЕ заведено',
      );
      await _write(request, 200, {...existing.toWire(), 'existed': true});
      return;
    }

    _counter++;
    final now = DateTime.now();
    final intent = SbpIntent(
      id: 'SBP${_counter.toString().padLeft(8, '0')}',
      intentKey: key,
      amount: amount,
      createdAt: now,
      expiresAt: now.add(ttl),
    );
    byKey[key] = intent;
    byId[intent.id] = intent;
    _log(
      'create',
      'намерение ${intent.id} на $amount заведено по ключу $key, '
      'срок до ${intent.expiresAt.toIso8601String()}',
    );
    await _write(request, 200, {...intent.toWire(), 'existed': false});
  }

  Future<void> _cancel(HttpRequest request, SbpIntent intent) async {
    if (intent.status == kPaid) {
      // **Самый важный из исходов отмены, и он не ошибка.** Покупатель
      // успел заплатить между «кассир нажал отмену» и «провайдер
      // услышал». Отвечать здесь `cancelled` значило бы соврать про
      // списанные деньги — эмулятор отвечает правду и оставляет продукту
      // разбираться.
      _log(
        'cancel',
        '${intent.id} отменить нельзя: уже оплачено — деньги у покупателя '
        'списаны, и касса обязана это увидеть',
      );
      await _write(request, 200, intent.toWire());
      return;
    }
    if (intent.status == kPending || intent.status == kCreated) {
      intent.status = kCancelled;
      intent.message = 'отменено кассой';
      _log('cancel', '${intent.id} отменено');
    } else {
      _log('cancel', '${intent.id} уже ${intent.status} — отмена не меняет');
    }
    await _write(request, 200, intent.toWire());
  }

  Future<void> _refund(
    HttpRequest request,
    SbpIntent intent,
    Map<String, Object?> body,
  ) async {
    // # Три правила денег возврата — задача 26
    //
    // До неё дверь переводила намерение в `reversed` на любую сумму и
    // сколько угодно раз: частичный возврат был неотличим от полного, а
    // повтор — от второго возврата. Форма протокола по-прежнему наша;
    // настоящее — правила: вернуть можно только оплаченное, не больше
    // оплаченного с учётом прежних возвратов, и повтор ключа не возвращает
    // деньги второй раз.
    final key = body['refundKey'];
    if (key is String) {
      final seen = refundsByKey[key];
      if (seen != null) {
        _log(
          'refund',
          '${intent.id}: ключ $key уже известен — прежний ответ, деньги '
          'второй раз не возвращаются',
        );
        await _write(request, 200, seen);
        return;
      }
    }
    if (intent.status != kPaid) {
      _log('refund', '${intent.id} не оплачено — возвращать нечего');
      await _write(request, 409, {
        'error': 'not_paid',
        'message': 'возврат возможен только для оплаченного намерения',
      });
      return;
    }
    final ask = millisOfMoney(body['amount']);
    final paid = millisOfMoney(intent.paidAmount ?? intent.amount) ?? 0;
    if (ask == null || ask <= 0) {
      _log('refund', '${intent.id}: сумма возврата не строка числа — отказ');
      await _write(request, 400, {
        'error': 'rejected',
        'message': 'нужна сумма возврата строкой больше нуля',
      });
      return;
    }
    if (intent.refundedMillis + ask > paid) {
      _log(
        'refund',
        '${intent.id}: оплачено ${moneyOfMillis(paid)}, возвращено '
        '${moneyOfMillis(intent.refundedMillis)}, просят ${body['amount']} — '
        'больше оплаченного, отказ',
      );
      await _write(request, 409, {
        'error': 'over_refund',
        'message': 'возврат больше оплаченного',
      });
      return;
    }
    intent.refundedMillis += ask;
    if (intent.refundedMillis == paid) intent.status = kReversed;
    intent.message = 'возвращено ${moneyOfMillis(intent.refundedMillis)}';
    _log(
      'refund',
      '${intent.id} возвращено ${body['amount']} '
      '(всего ${moneyOfMillis(intent.refundedMillis)} из ${moneyOfMillis(paid)})',
    );
    final wire = intent.toWire();
    if (key is String) refundsByKey[key] = wire;
    await _write(request, 200, wire);
  }

  /// Срок вышел — **считается при обращении, а не таймером**.
  ///
  /// Тот же довод, что у просрочки рассрочки в плане: фоновая работа
  /// заводит вторую правду, расходящуюся с первой всякий раз, когда
  /// процесс не работал.
  void _expireIfDue(SbpIntent intent) {
    if (intent.status != kPending && intent.status != kCreated) return;
    if (DateTime.now().isBefore(intent.expiresAt)) return;
    intent.status = kExpired;
    intent.message = 'срок намерения вышел';
    _log('expire', '${intent.id} просрочено по сроку намерения');
  }

  /// Покупатель заплатил — **действие пульта, а не продукта**.
  void confirm(SbpIntent intent, {String? amount, bool count = true}) {
    intent.status = kPaid;
    intent.paidAmount = amount ?? intent.amount;
    intent.confirmedAt = DateTime.now();
    if (count) intent.confirmations++;
    final partial = amount != null && amount != intent.amount;
    _log(
      'pay',
      '${intent.id} оплачено на ${intent.paidAmount}'
      '${partial ? ' — ЧАСТИЧНО, просили ${intent.amount}' : ''}, '
      'подтверждений ${intent.confirmations}',
    );
  }

  Future<void> _write(
    HttpRequest request,
    int status,
    Map<String, Object?>? json, {
    String? raw,
  }) async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
    try {
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(raw ?? jsonEncode(json));
      await request.response.close();
    } catch (_) {
      // Клиент ушёл — обычное дело при отказах `kill`/`silence`.
    }
  }

  void _log(String kind, String why) {
    journal.add({
      'at': DateTime.now().toIso8601String(),
      'kind': kind,
      'why': why,
    });
    if (echo) stdout.writeln('[$kind] $why');
  }

  SbpIntent? _pick(Map<String, Object?> body) {
    final id = body['intentId'] as String?;
    if (id != null) return byId[id];
    final key = body['intentKey'] as String?;
    if (key != null) return byKey[key];
    if (byId.length == 1) return byId.values.first;
    return byId.values.isEmpty ? null : byId.values.last;
  }

  Future<void> _serveControl() async {
    final server = _control;
    if (server == null) return;
    await for (final request in server) {
      Map<String, Object?> body = const {};
      if (request.method == 'POST') {
        final raw = await utf8.decoder.bind(request).join();
        if (raw.trim().isNotEmpty) {
          try {
            body = (jsonDecode(raw) as Map).cast<String, Object?>();
          } catch (_) {}
        }
      }

      Object? answer;
      switch (request.uri.path) {
        case '/_emul/pay':
          final intent = _pick(body);
          if (intent == null) {
            answer = {'error': 'нет намерения, которое можно оплатить'};
            break;
          }
          final times = (body['times'] as num?)?.toInt() ?? 1;
          final amount = body['amount'] as String?;
          final afterMs = (body['afterMs'] as num?)?.toInt() ?? 0;
          if (afterMs > 0) {
            // **Подтверждение позже терпения кассы.** Именно этот исход и
            // рождает «деньги без чека»: касса сдалась, а деньги пришли.
            _log(
              'pay',
              '${intent.id} будет оплачено через $afterMs мс — дольше, чем '
              'касса согласна ждать',
            );
            final t = Timer(Duration(milliseconds: afterMs), () {
              for (var i = 0; i < times; i++) {
                confirm(intent, amount: amount);
              }
            });
            _timers.add(t);
            answer = {'scheduledInMs': afterMs, 'intentId': intent.id};
            break;
          }
          for (var i = 0; i < times; i++) {
            confirm(intent, amount: amount);
          }
          answer = intent.toWire();
        case '/_emul/decline':
          final intent = _pick(body);
          if (intent == null) {
            answer = {'error': 'нет намерения'};
            break;
          }
          intent.status = kFailed;
          intent.message =
              (body['message'] as String?) ?? 'покупатель отказался платить';
          _log('decline', '${intent.id} отказано: ${intent.message}');
          answer = intent.toWire();
        case '/_emul/expire':
          final intent = _pick(body);
          if (intent == null) {
            answer = {'error': 'нет намерения'};
            break;
          }
          intent.status = kExpired;
          intent.message = 'срок намерения вышел';
          _log('expire', '${intent.id} просрочено пультом');
          answer = intent.toWire();
        case '/_emul/fault':
          fault = (body['refuse'] as String?) ?? '';
          faultsLeft =
              (body['count'] as num?)?.toInt() ?? (fault.isEmpty ? 0 : 1);
          refuseConnect = (body['refuseConnect'] as bool?) ?? refuseConnect;
          final ms = body['latencyMs'];
          if (ms is num) latency = Duration(milliseconds: ms.toInt());
          answer = state();
        case '/_emul/reset':
          fault = '';
          faultsLeft = 0;
          refuseConnect = false;
          latency = Duration.zero;
          byKey.clear();
          byId.clear();
          refundsByKey.clear();
          journal.clear();
          for (final t in _timers) {
            t.cancel();
          }
          _timers.clear();
          answer = state();
        case '/_emul/state':
          answer = state();
        case '/_emul/journal':
          answer = journal;
        case '/_emul/faults':
          answer = {
            'faults': kFaults,
            'внимание':
                'форма протокола этого эмулятора ВЫДУМАНА: договора с '
                'провайдером СБП у нас нет. Настоящее здесь — время: '
                'подтверждение приходит после вопроса, может опоздать, не '
                'прийти вовсе или прийти дважды.',
          };
        case '/_emul/stop':
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'stopping': true}));
          await request.response.close();
          await stop();
          return;
        default:
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          continue;
      }

      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(answer));
      await request.response.close();
    }
  }

  Map<String, Object?> state() => {
    'fault': fault,
    'faultsLeft': faultsLeft,
    'refuseConnect': refuseConnect,
    'latencyMs': latency.inMilliseconds,
    'intents': byId.values.map((i) => i.toWire()).toList(),
    'journal': journal.length,
  };

  final Completer<void> _stopped = Completer<void>();

  /// Завершается, когда эмулятор остановлен — дверью, `--stop` или тестом.
  /// Точка входа ждёт его, чтобы снять подписку на Ctrl-C: без этого
  /// процесс переживал дверь остановки (измерено 2026-09-13).
  Future<void> get stopped => _stopped.future;

  /// Дверь остановки. Снимает и отложенные подтверждения: таймер,
  /// переживший тест, — висящий процесс, а их в дереве уже было три.
  Future<void> stop() async {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    await _server?.close(force: true);
    _server = null;
    await _control?.close(force: true);
    _control = null;
    if (!_stopped.isCompleted) _stopped.complete();
  }
}
