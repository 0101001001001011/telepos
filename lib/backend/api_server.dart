import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

import 'package:telepos/core/net/listen_scope.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/auth/session_admin.dart';
import 'package:telepos/domain/auth/terminal_session_check.dart';
import 'package:telepos/domain/device/device_check.dart';
import 'package:telepos/domain/device/device_discovery.dart';
import 'package:telepos/domain/network/network_repository.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_access.dart';

import 'api_security.dart';
import 'pairing_invites.dart';
import 'till_operations.dart';
import 'web_bundle.dart';

/// Раздатчик страницы. Данных он больше не отдаёт.
///
/// # Что здесь осталось и почему
///
/// Браузер обязан скачать документ, бандл и шрифты **до** того, как появится
/// хоть одна сессия WebTransport: конструктор `WebTransport` живёт на
/// странице, а страницу неоткуда взять, кроме как по HTTP. Это единственная
/// причина, по которой сервер существует, — и вся его работа теперь в
/// [_frontendHandler], который заодно кладёт в документ адрес слушателя QUIC и
/// отпечаток его листа.
///
/// # Почему маршрутов данных больше нет
///
/// Четырнадцать `/api/*` были первой реализацией провода. С 2026-08-04 их
/// место занял `TillWire` поверх WebTransport, и `lib/web/` не содержит ни
/// одного обращения по HTTP — ни `package:http`, ни `fetch`, ни
/// `XMLHttpRequest`; сторож в `test/architecture/layering_test.dart` краснеет,
/// если они вернутся. Оставить маршруты рядом значило бы держать две живых
/// реализации одного и того же, а у этого проекта их не бывает: разошлись бы
/// они молча, и первым бы это увидел кассир.
///
/// Недостижимость доказана, а не предположена (2026-08-05): единственным, кто
/// строил `SetupRoutes`/`TerminalRoutes`, был сам этот файл; ни одного клиента
/// — ни в Dart, ни в скриптах, ни в CI, ни в приборах — у них не нашлось.
/// Проверки, которые за ними стояли, стоят теперь за операциями провода:
/// `test/backend/till_watch_test.dart` и `test/domain/wire/terminal_wire_test.dart`.
///
/// # Что здесь всё ещё не про страницу
///
/// [operations] — кассовая половина провода. Она собрана здесь, потому что
/// здесь уже собраны её зависимости; собрать их второй раз означало бы завести
/// вторую кассу внутри этой, и первым бы сломался подъём, посчитанный дважды.
/// Транспорта она не знает: над ней встаёт `TillWire` (`lib/main.dart`).
class ApiServer {
  ApiServer({
    required AppDatabase db,
    required AppBootstrap bootstrap,
    required SetupRepository setup,
    required TerminalRepository terminals,
    required DeviceBindingRepository deviceBindings,
    required AuthRepository auth,
    FirstLaunchRepository? firstLaunch,
    // Опциональны затем же, зачем и [firstLaunch]: голый процесс Dart
    // (`bin/telepos_backend.dart`) не строит ни одного драйвера железа, так
    // что построить `DeviceDiscoveryLocal`/`DeviceCheckLocal` там нечем.
    // `null` — операции обнаружения и проверки отказывают названной причиной,
    // а не падают и не выдумывают результат (план 2b, задача 4).
    DeviceDiscovery? deviceDiscovery,
    DeviceCheck? deviceCheck,
    // Задача «сетевые настройки по проводу» (спека 2026-08-24): тем же
    // приёмом опционального довода, что и [deviceDiscovery]/[deviceCheck]
    // выше — прокидывается в [TillOperations] как есть, докстринг там.
    NetworkRepository? network,
    // Довесок фазы 3/4 закрытия долга, часть Б: прокидывается в
    // [TillOperations] как есть, тем же приёмом опционального довода — см.
    // докстринг у неё.
    TerminalSessionCheck? terminalSessions,
    // Задача 19 закрытия долга безопасности: тем же приёмом опционального
    // довода, что и [terminalSessions] выше — прокидывается в
    // [TillOperations] как есть.
    SessionAdmin? sessionAdmin,
    this.port = 8787,
    this.scope = ListenScope.loopback,
    String? publicHost,
    String? frontendDirectory,
    this.frontendUnavailableReason,
    this.webTransportPort,
    this.webTransportFingerprintSha256,
    this.rootCertificatePem,
    // Пункт 3 волны правок «касса говорит, что набирать» (2026-08-23):
    // обязателен, а не `PairingInvites? invites` с умолчанием
    // `invites ?? PairingInvites()`, которое стояло здесь раньше.
    // Забывший довод вызывающий получал бы ВТОРОЙ список кодов молча — ровно
    // то, что докстринг у поля [invites] ниже называет ошибкой прямо. Единственной
    // защитой была одна строка в `main.dart`, которую ничто не сторожило:
    // `main.dart` под тестом не поднимается. Задача 6 этой работы будет
    // тратить коды при регистрации терминала через тот же `ApiServer` — эта
    // ловушка обязана исчезнуть до неё, а не после.
    required this.invites,
  }) : // `localhost`, а не адрес сокета: сокетов теперь может быть два (обе
       // петли), и ни один из двух адресов не является «тем, что набирают».
       // Имя же разрешается в оба семейства, и потому годится независимо от
       // того, какое из них на этой машине идёт первым.
       _publicHost = publicHost ?? 'localhost',
       _frontendDirectory = frontendDirectory ?? 'build/web',
       operations = TillOperations(
         db: db,
         bootstrap: bootstrap,
         setup: setup,
         terminals: terminals,
         deviceBindings: deviceBindings,
         firstLaunch: firstLaunch,
         deviceDiscovery: deviceDiscovery,
         deviceCheck: deviceCheck,
         network: network,
         auth: auth,
         sessions: terminalSessions,
         sessionAdmin: sessionAdmin,
         // Тот же список, что и `/ca.crt` ниже ([_rootCertificate]) — задача
         // 6 плана «знакомство терминала с кассой»: `terminals.register`
         // тратит код привязки этим же экземпляром `PairingInvites`, а не
         // вторым списком (докстринг [invites]). Код для `/ca.crt` и код для
         // `terminals.register` — не обязаны быть одним и тем же кодом (один
         // потрачен раньше, при доставке корня); список один — коды разные,
         // мятые тем же `mint()` на том же экране.
         invites: invites,
       );

  /// Порт, который просят у системы. `0` означает «любой свободный», и тогда
  /// доставшийся читается из [boundPort], а не отсюда.
  final int port;

  /// Насколько широко слушать — и на каких семействах адресов.
  ///
  /// Умолчание — петля, и оно перестало быть единственно возможным значением
  /// 2026-08-05: терминал переехал на отдельное устройство, а страницу оттуда
  /// неоткуда взять, кроме как по сети. Расширять слушателя без TLS права нет
  /// — см. [start], который отказывается подниматься без сертификата.
  ///
  /// Раньше здесь стояла строка адреса `'127.0.0.1'`, и это была половина
  /// парного дефекта 2026-08-06: строка называет одно семейство, а браузер
  /// приходит по тому, которое разрешилось первым. См. [ListenScope].
  final ListenScope scope;

  /// Как эту кассу назовёт тот, кто её открывает.
  ///
  /// Отдельно от [scope], потому что это разные вещи: слушать можно все
  /// адреса, а в документ обязано попасть имя, по которому касса разрешается у
  /// планшета (`till-3.local`).
  final String _publicHost;

  final String _frontendDirectory;

  /// Почему бандла нет — словами того, кто его искал.
  ///
  /// Отказ приходит значением (И144), и значение обязано называть **все**
  /// просмотренные места, а не одно. Прежняя строка `Frontend bundle not found
  /// at build/web` называла каталог, которого на установленной кассе нет и быть
  /// не может: у неё рабочий каталог `C:\Program Files\TelePOS`. То есть
  /// единственная подсказка, которую видел заказчик, отправляла искать не туда.
  /// `null` означает «искал не я» — тогда о каталоге рассказывает
  /// [_frontendDirectory].
  final String? frontendUnavailableReason;

  /// Корень удостоверяющего центра этой установки, PEM.
  ///
  /// `null` на кассе, у которой центра нет — тогда `/ca.crt` отвечает
  /// названной причиной, а не пустотой: «корня нет» и «корень не отдам» — это
  /// разные состояния, и оператор, стоящий с планшетом, должен видеть какое.
  final String? rootCertificatePem;

  /// Одноразовые коды, которыми оператор впускает планшет за корнем.
  ///
  /// Открыты наружу, потому что мятит их экран привязки, а тратит этот сервер,
  /// и второго списка заводить нельзя: код, выданный одним объектом и
  /// проверяемый другим, — это код, который не проверяется.
  final PairingInvites invites;

  /// Операции провода, собранные из зависимостей, которые всё равно приходят
  /// сюда. Наружу открыты затем, чтобы `main.dart` поднял над ними `TillWire`
  /// и не собирал второй набор репозиториев.
  final TillOperations operations;

  /// Словарь требований доступа по имени операции — вход для [WireGuard].
  ///
  /// Строится из того же каталога, что и карты обработчиков в [operations]:
  /// расхождение здесь означало бы, что операция обслуживается, а право на неё
  /// проверять нечем.
  Map<String, WireAccess> get access => {
    for (final op in TillOps.all) op.name: op.access,
  };

  /// Поднятые сокеты. Их может быть два — см. [ListenScope.loopback].
  final List<HttpServer> _servers = [];

  /// Адреса, которые занять не удалось, с причиной у каждого.
  ///
  /// Пусто в нормальном случае. Непусто, когда часть семейств отпала, но
  /// хотя бы одно поднялось: страница при этом отдаётся, и отказывать целиком
  /// было бы хуже — но и молчать нельзя, иначе «терминал не соединяется»
  /// придётся объяснять с нуля. Значение, а не исключение и не лог изнутри
  /// (И144): пишет его тот, кто поднимал сервер.
  final List<String> _bindFailures = [];

  List<String> get bindFailures => List.unmodifiable(_bindFailures);

  /// Адреса, на которых сервер действительно слушает. Пусто, пока не поднят.
  ///
  /// Спрашивается у сокетов, а не собирается из [scope]: единственная величина,
  /// которую стоит показывать человеку, — это та, что получилась, а не та, что
  /// просили. Строка «слушает 0.0.0.0», написанная руками рядом с подъёмом,
  /// пережила переезд слушателя на `::` и продолжала это утверждать.
  List<String> get listeningOn => [
    for (final server in _servers) server.address.address,
  ];

  ApiSecurity? _security;

  /// Адрес, который открывает оператор. `null`, пока [start] не удался.
  ///
  /// Всегда `https://`: другой схемы у этого сервера больше нет — см. [start].
  String? get url =>
      _servers.isEmpty ? null : 'https://$_publicHost:${_servers.first.port}';

  /// Порт, который в итоге достался. `null`, пока сервер не поднят.
  ///
  /// Отличается от [port], когда просили `0`: тогда порт выбирает система, и
  /// это единственное место, где выбор становится известен. Когда сокетов два,
  /// порт у них общий: второй занимает ровно тот, что достался первому, —
  /// иначе страница и провод разъехались бы по портам.
  int? get boundPort => _servers.isEmpty ? null : _servers.first.port;

  /// Признак сессии, который впрыскивается в страницу.
  ///
  /// Данных по HTTP больше не отдаётся, поэтому предъявлять его теперь нечему;
  /// он остаётся признаком происхождения страницы.
  String? get token => _security?.token;

  /// Поднимает раздатчик страницы поверх TLS.
  ///
  /// Отдаёт `String` — адрес — или [ApiServerUnavailable]. Не бросает.
  ///
  /// # Почему [context] обязателен и почему `null` — отказ, а не откат
  ///
  /// `WebTransport` в браузере помечен `[SecureContext]`. На `http://127.0.0.1`
  /// конструктор есть по исключению для петли; на `http://192.168.1.50:8787`
  /// его **нет вовсе** — не «не соединяется», а отсутствует. Пока терминал жил
  /// на самой кассе, обычного HTTP хватало; с 2026-08-05 терминал — отдельное
  /// устройство, и страницу оно берёт по сети.
  ///
  /// `serverCertificateHashes` этого не закрывает: отпечаток спасает
  /// рукопожатие QUIC, а страницу браузер грузит раньше и другим протоколом.
  ///
  /// Поэтому молчаливого отката на HTTP здесь нет. Он выглядел бы как
  /// работающая касса: страница открылась, экран нарисовался, — и как
  /// сломанный провод, причину которого искали бы в QUIC, то есть не там.
  Future<Object> start({required SecurityContext? context}) async {
    if (_servers.isNotEmpty) return url!;

    if (context == null) {
      return const ApiServerUnavailable(
        'нет сертификата для страницы: браузер не даёт WebTransport на '
        'незащищённой странице, а без него терминал недостижим. '
        'Обычный HTTP здесь не запасной путь, а тот же отказ без объяснения',
      );
    }

    final origin = 'https://$_publicHost:$port';
    final security = ApiSecurity(allowedOrigin: origin);

    final frontend = _frontendHandler(security);
    final pipeline = const Pipeline()
        .addMiddleware(security.middleware)
        .addHandler((Request request) {
          // Одна не-страничная выдача, и она обязана быть до бандла: файла
          // `ca.crt` в собранном бандле нет и быть не должно, а статический
          // раздатчик ответил бы на него 404 — то есть «такого нет» там, где
          // верный ответ «есть, но не вам». Диспетчеризация здесь — только по
          // пути; метод проверяет сама [_rootCertificate] (пункт 5 волны
          // правок 2026-08-23) — там же и причина, почему не здесь.
          if (request.url.path == 'ca.crt') return _rootCertificate(request);
          return frontend(request);
        });

    // Список отказов — про эту попытку, а не про все с начала процесса: после
    // неудачного подъёма (порт был занят) повторный вызов иначе показал бы
    // старые адреса рядом с новыми, и читать их пришлось бы гадая.
    _bindFailures.clear();

    // Первым — тот адрес, который обязан достаться: от него берётся порт для
    // остальных, и по нему считается [url].
    for (final address in _required(scope)) {
      await _bind(pipeline, context, address);
    }

    if (_servers.isEmpty) {
      // Запасные — не «на всякий случай», а на машину с выключенным IPv6:
      // там `::` не биндится вовсе, и без этого шага касса перестала бы
      // отдавать страницу совсем — регресс по сравнению с `0.0.0.0`, который
      // стоял здесь до 2026-08-06. Пробуются только если не поднялось НИЧЕГО:
      // на исправной машине `0.0.0.0` поверх уже занятого `::` всё равно
      // отказал бы «адрес занят», и эта строка врала бы в каждом запуске.
      for (final address in _fallback(scope)) {
        await _bind(pipeline, context, address);
      }
    }

    if (_servers.isEmpty) {
      // Занятый порт и отсутствующий адрес — обычные состояния, а не сбой
      // кассы: вторая копия на той же машине встречается чаще, чем хотелось бы.
      return ApiServerUnavailable(
        'страницу не удалось начать отдавать на порт $port: '
        '${_bindFailures.join('; ')}',
      );
    }

    _security = security;
    return url!;
  }

  /// Занимает один адрес, складывая отказ в [_bindFailures], а не бросая.
  ///
  /// Порт берётся у первого поднявшегося сокета, а не из [port]: при `port: 0`
  /// система выбирает его сама, и второе семейство обязано встать на тот же
  /// номер — иначе в документ уехал бы порт, которого на второй петле нет.
  Future<void> _bind(
    Handler pipeline,
    SecurityContext context,
    InternetAddress address,
  ) async {
    final wanted = _servers.isEmpty ? port : _servers.first.port;
    try {
      // `securityContext` — это и есть вся разница между слушателем, который
      // браузер считает защищённым, и слушателем, на котором конструктора
      // WebTransport не существует.
      _servers.add(
        await shelf_io.serve(
          pipeline,
          address,
          wanted,
          securityContext: context,
        ),
      );
    } on Object catch (error) {
      _bindFailures.add('${address.address}:$wanted — $error');
    }
  }

  /// Адреса, которые слушатель обязан занять при этом [ListenScope].
  ///
  /// Почему у петли их два, а у «всех адресов» один — измерено и записано в
  /// [ListenScope]: `::` с выключенным `IPV6_V6ONLY` (Dart так и биндит)
  /// принимает и IPv4, а `::1` — нет, это отдельный адрес, а не подсеть.
  static List<InternetAddress> _required(ListenScope scope) => switch (scope) {
    ListenScope.loopback => [
      InternetAddress.loopbackIPv6,
      InternetAddress.loopbackIPv4,
    ],
    ListenScope.everywhere => [InternetAddress.anyIPv6],
  };

  /// Чем закрыться, если из [_required] не поднялось ничего.
  ///
  /// У петли пусто: `127.0.0.1` уже в обязательных, и подставлять там нечего.
  static List<InternetAddress> _fallback(ListenScope scope) => switch (scope) {
    ListenScope.loopback => const <InternetAddress>[],
    ListenScope.everywhere => [InternetAddress.anyIPv4],
  };

  /// Где эта касса слушает WebTransport, когда слушает.
  ///
  /// UDP и другой порт, нежели [port]: QUIC — не TCP. `null` означает, что
  /// слушатель не поднялся, и тогда страница откроется на названном отказе
  /// (`WtUnavailableScreen`), а не на пустоте: запасного пути через HTTP
  /// больше нет.
  final int? webTransportPort;

  /// SHA-256, который браузер обязан пришить, чтобы открыть сессию.
  ///
  /// Лист выписан удостоверяющим центром самой установки, и по цепочке ему не
  /// верит ни один браузер; `serverCertificateHashes` — это и есть всё
  /// доверие на браузерной стороне.
  final String? webTransportFingerprintSha256;

  /// Отдаёт собранный бандл, впрыскивая в документ то, чего в бандле быть не
  /// может.
  ///
  /// Адрес слушателя QUIC и отпечаток его листа едут именно так, потому что
  /// страница, которой их продиктовали руками, — это страница, чьё решение о
  /// доверии принял человек, переписавший шестнадцатеричную строку.
  Handler _frontendHandler(ApiSecurity security) {
    // Не `Directory.existsSync`: каталог может существовать и быть пустым —
    // например, `build/web` после неудавшейся сборки, — и тогда прежняя
    // проверка отвечала «бандл есть», а браузер получал 404 на каждый файл и
    // белый экран без единого слова о причине. Признак бандла — те же два
    // файла, которые называет сборка установщика.
    if (!isWebBundle(_frontendDirectory)) {
      final reason =
          frontendUnavailableReason ??
          'бандл браузера не найден в $_frontendDirectory; ожидались файлы '
              '${kWebBundleMarkers.join(' и ')}. Соберите его: '
              'flutter build web -t lib/web/main_web.dart';
      return (Request request) => Response.notFound(reason);
    }

    final static = createStaticHandler(
      _frontendDirectory,
      defaultDocument: 'index.html',
    );

    return (Request request) async {
      final response = await static(request);
      final isDocument =
          request.url.path.isEmpty || request.url.path.endsWith('.html');
      if (!isDocument || response.statusCode != 200) return response;

      final html = await response.readAsString();

      // Отсутствуют, когда слушатель не поднялся. Браузерная сторона читает их
      // как необязательные и в этом случае показывает названную причину.
      final port = webTransportPort;
      final quic = port == null
          ? ''
          : '\n  <script>window.TELEPOS_WT_PORT = $port; '
                'window.TELEPOS_WT_CERT_SHA256 = '
                '"${webTransportFingerprintSha256 ?? ''}";</script>';

      final injected = html.replaceFirst(
        '<head>',
        '<head>\n  <script>window.TELEPOS_TOKEN = '
            '"${security.token}";</script>$quic',
      );
      return Response.ok(
        injected,
        headers: {'content-type': 'text/html; charset=utf-8'},
      );
    };
  }

  /// Отдаёт корень магазина — по действующему коду привязки и один раз на код.
  ///
  /// # Почему код, если корень открыт
  ///
  /// Корень публичен: ключа в нём нет, и знание его не даёт ничего. Код
  /// закрывает не тайну, а **момент**. Установка корня на устройство — это
  /// решение доверять, и принимать его должен человек, который в эту секунду
  /// стоит у кассы и привязывает планшет, а не браузер, забредший на адрес.
  /// Другого момента, когда человек уже держит устройство в руках и уже
  /// подтверждает доверие, в системе нет.
  ///
  /// Чем это не является — тоже сказано вслух: от подмены кассы это не
  /// защищает и защищать не может. Планшет, которому подсунули чужой корень,
  /// узнает об этом не здесь.
  ///
  /// # Почему метод проверяется здесь, а не диспетчером выше
  ///
  /// Пункт 5 волны правок «касса говорит, что набирать» (2026-08-23): до этой
  /// правки диспетчер выше решал только по пути (`request.url.path ==
  /// 'ca.crt'`), и любой метод — `HEAD`, `POST`, обрыв закачки на середине —
  /// доходил до [redeem], **тратя код, ничего не доставив человеку**.
  /// `OPTIONS` этого не касался — его перехватывает `security.middleware`
  /// раньше конвейера, — но остальные методы доходили сюда свободно.
  ///
  /// Отвечает только `GET`. `HEAD` намеренно **не** отвечает тем же телом без
  /// траты кода: чтобы ответить `200`/`403` по действительности кода без
  /// траты, `PairingInvites` понадобился бы третий метод — «посмотреть, не
  /// тратя» — рядом с `redeem`/`revoke`, а у этого эндпоинта нет ни одного
  /// настоящего вызывающего, которому HEAD нужен: адресную строку браузера и
  /// заголовок `<a href>`, единственные два реалистичных потребителя, `GET`
  /// закрывает целиком. Поэтому прочим методам, включая `HEAD`, — один и тот
  /// же названный отказ, а не молчаливая тонкая логика ради метода без
  /// вызывающего.
  ///
  /// Оборванная закачка (клиент разорвал соединение после того, как
  /// [redeem] уже вернул `true`, но до того, как тело дошло) этой правкой не
  /// закрыта — граница названа явно в спеке
  /// (`docs/internal/superpowers/specs/2026-08-23-terminal-enrolment-design.md`,
  /// «Границы»): подтверждение доставки потребовало бы протокола из двух
  /// шагов («выдан» → отдельное «получен»), а не одного `GET`, и это отдельная
  /// работа, а не строка в этой правке.
  Response _rootCertificate(Request request) {
    if (request.method != 'GET') {
      return Response(
        405,
        body:
            'корень отдаётся только по GET; ${request.method} к этому '
            'эндпоинту не обращается ни один настоящий клиент',
        headers: {..._plainText, 'allow': 'GET'},
      );
    }

    final pem = rootCertificatePem;
    if (pem == null) {
      // 503, а не 403: отказ по коду и отсутствие центра — разные состояния, и
      // оператор с планшетом в руках должен видеть, какое из двух.
      return Response(
        503,
        body: 'у этой кассы нет удостоверяющего центра — корень взять неоткуда',
        headers: _plainText,
      );
    }

    final code = request.url.queryParameters['invite'];
    if (!invites.redeem(code)) {
      return Response.forbidden(
        'корень отдаётся только по действующему коду привязки: заведите его '
        'на кассе и откройте эту страницу заново',
        headers: _plainText,
      );
    }

    return Response.ok(
      pem,
      headers: const {
        // То, по чему и Android, и Windows понимают, что им предложили корень,
        // и открывают свой диалог установки. `text/plain` сохранил бы файл в
        // загрузки, и дальше пришлось бы объяснять человеку, куда его нести.
        'content-type': 'application/x-x509-ca-cert',
        'content-disposition': 'attachment; filename="telepos-ca.crt"',
        // Пропуск потрачен; отданный из кэша ответ означал бы второй проход
        // без второго кода.
        'cache-control': 'no-store',
      },
    );
  }

  static const Map<String, String> _plainText = {
    'content-type': 'text/plain; charset=utf-8',
  };

  Future<void> stop() async {
    // Все, а не первый: незакрытый второй сокет держал бы порт занятым, и
    // следующий подъём в том же процессе (перевыпуск листа, тест) отказал бы
    // «адрес занят» по причине, которую ищут не там.
    for (final server in _servers) {
      await server.close(force: true);
    }
    _servers.clear();
    _bindFailures.clear();
    _security = null;
  }
}

/// Почему страница не отдаётся, когда она не отдаётся.
///
/// Значение, а не исключение (И144). Касса без раздатчика страницы продолжает
/// продавать — деньги не идут через этот сокет, — но браузерный терминал в
/// этом состоянии недостижим, и причина обязана быть читаемой в логе, а не
/// восстанавливаемой по отсутствию строки.
class ApiServerUnavailable {
  const ApiServerUnavailable(this.reason);

  final String reason;

  @override
  String toString() => reason;
}
