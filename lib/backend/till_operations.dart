/// Единственное место, где имя операции провода связывается с работой кассы.
///
/// # Почему это здесь, а не в `TillWire`
///
/// `lib/data/transport/till_wire.dart` не знает ни базы, ни репозиториев, ни
/// железа — он умеет разобрать кадр и написать ответ в тот поток, из которого
/// пришёл вопрос. Зависимости, которые нужны обработчикам, уже собраны здесь,
/// в `lib/backend/`; собирать их второй раз означало бы завести вторую кассу
/// внутри той же.
///
/// # Единственная реализация, а не «главная из двух»
///
/// До 2026-08-05 рядом жили четырнадцать маршрутов `/api/*`
/// (`setup_routes.dart`, `terminal_routes.dart`), и обработчики ниже делили с
/// ними и репозитории, и вспомогательные функции — [readSetupState],
/// [findBackup], — чтобы две реализации не разошлись. Маршруты сняты: их
/// недостижимость доказана поимённо (ни одного клиента ни в Dart, ни в
/// скриптах, ни в CI), и делить теперь не с кем. Вспомогательные функции
/// остались — их зовёт этот же файл.
///
/// # Имена берутся из `TillOps`, а не набираются строкой
///
/// До 2026-08-04 согласование концов держалось на строке пути в двух местах, и
/// расхождение обнаруживалось в браузере кодом 404. Здесь имя приходит из
/// каталога операций — того самого, из которого его берёт и терминал.
///
/// # Откуда у кассы взялся источник изменений
///
/// [TillOps.setupState], [TillOps.terminalsList], [TillOps.terminalSelf] и
/// [TillOps.deviceBindings] объявлены подписками, и до 2026-08-05 их здесь не
/// было: договоры репозиториев отдавали `Future<T>`, то есть значение на момент
/// вопроса, а подписка, отдающая одно значение и закрывающаяся, была бы
/// вопросом в одежде подписки — выглядела бы работающей и не приносила бы ровно
/// того, ради чего менялся транспорт.
///
/// Источником стал `AppDatabase.tableUpdates` — сигнал, который drift подаёт
/// от самой записи. Заводить рядом свою шину событий было бы вторым
/// источником правды о том же: запись, попавшая в базу мимо шины, разошлась бы
/// с тем, что видит терминал, и разошлась бы молча.
///
/// Значение по сигналу читают **те же методы репозиториев**, которыми касса
/// отвечает на одноразовый вопрос, — `watchTables`
/// (`lib/data/database/watch_source.dart`) устроен именно так. Почему не
/// `Selectable.watch()` drift, который делает и то и другое разом, там же и
/// записано: под `testWidgets` он не отдаёт ни одного значения, и экран,
/// ждущий первого, остаётся со спиннером навсегда.
///
/// Цена названа: сигнал приходит по **таблице**, а не по строке, поэтому кадр
/// может уйти и тогда, когда по существу ничего не изменилось. Значение в нём
/// всегда верное — читает тот же метод, — и это дешевле, чем вести список
/// того, что кого касается.
library;

import 'dart:async';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/setup/setup_state_source.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/auth/auth_attempt.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/auth/session_admin.dart';
import 'package:telepos/domain/auth/terminal_session_check.dart';
import 'package:telepos/domain/device/device_check.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_discovery.dart';
import 'package:telepos/domain/network/network_repository.dart';
import 'package:telepos/domain/setup/setup_draft_json.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/auth_wire.dart';
import 'package:telepos/domain/wire/device_wire.dart';
import 'package:telepos/domain/wire/network_wire.dart';
import 'package:telepos/domain/wire/setup_state.dart';
import 'package:telepos/domain/wire/terminal_wire.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_frame.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

import 'pairing_invites.dart';

class TillOperations {
  TillOperations({
    required AppDatabase db,
    required AppBootstrap bootstrap,
    required SetupRepository setup,
    required TerminalRepository terminals,
    required DeviceBindingRepository deviceBindings,
    required AuthRepository auth,
    FirstLaunchRepository? firstLaunch,
    DeviceDiscovery? deviceDiscovery,
    DeviceCheck? deviceCheck,
    // Довесок фазы 3/4 закрытия долга — уборка неиспользуемых строк
    // `terminals` (см. [_pruneUnusedTerminals]). `null` — та же осторожная
    // деградация, что у [_deviceDiscovery]/[_deviceCheck] выше: без порта,
    // умеющего ответить «есть ли живой сеанс на этом терминале», уборка не
    // может доказать, что строка безопасна трогать, и не трогает вовсе —
    // не отказом, молча, потому что уборка не операция, которую кто-то
    // ждёт, а внутренняя гигиена. Тесты, которым эта гигиена не нужна (их
    // большинство — до этого довеска их было тринадцать), не обязаны знать
    // о новом доводе.
    TerminalSessionCheck? sessions,
    // Задача 19 закрытия долга безопасности: экран списка сеансов и его
    // отзыв. Опционально тем же приёмом, что и [_deviceDiscovery]/
    // [_deviceCheck]/[_firstLaunch] выше — на настоящей кассе всегда
    // приходит (`main.dart` передаёт тот же `SessionRegistry`, что и
    // `sessions`/`auth` парой строк выше), но тесты, которым эти две
    // операции не нужны, не обязаны знать о новом доводе.
    SessionAdmin? sessionAdmin,
    // Задача 6 плана «знакомство терминала с кассой» (шаг 3 спеки): довод
    // `terminals.register` — код привязки, который тратится здесь
    // (`PairingInvites.redeem`), не в сторожа (докстринг [EnrolmentAccess],
    // `wire_access.dart`). `null` — **не** та же деградация, что у
    // [_deviceDiscovery]/[_sessions]/[_sessionAdmin] выше (там отсутствие
    // порта отключает одну необязательную деталь, а сама операция либо
    // отвечает по существу иначе, либо не про безопасность). Здесь
    // отсутствие означает, что заводить терминалы **некому доказать право**
    // — то же самое «отказ вместо тихого прохода», которым уже отвечают
    // [_requireDiscovery]/[_requireSessionAdmin] на отсутствующий порт, и то
    // же имя типа отказа (`WireRefusal`), но без него операция не выполняет
    // ничего и не деградирует до «работает иначе» — заведение терминала без
    // способа проверить код было бы ровно той дырой, которую задача 6
    // закрывает. `ApiServer` передаёт сюда тот же экземпляр, что и
    // `/ca.crt` (`api_server.dart`, `required this.invites`) — вторых
    // списков кодов в процессе нет.
    PairingInvites? invites,
    // Задача «сетевые настройки по проводу» (спека 2026-08-24): `null` —
    // та же деградация, что у [_deviceDiscovery]/[_deviceCheck] выше, но по
    // другому доводу — не отсутствие драйверов, а отсутствие демона
    // `telepos-sysd` (обычная Windows-касса). Операции отказывают названной
    // причиной (`_requireNetwork`), а не падают и не выдумывают результат.
    NetworkRepository? network,
    Duration terminalIdleGrace = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _db = db,
       _bootstrap = bootstrap,
       _setup = setup,
       _terminals = terminals,
       _deviceBindings = deviceBindings,
       _auth = auth,
       _firstLaunch = firstLaunch,
       _deviceDiscovery = deviceDiscovery,
       _deviceCheck = deviceCheck,
       _sessions = sessions,
       _sessionAdmin = sessionAdmin,
       _invites = invites,
       _network = network,
       _terminalIdleGrace = terminalIdleGrace,
       _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final AppBootstrap _bootstrap;
  final SetupRepository _setup;
  final TerminalRepository _terminals;
  final DeviceBindingRepository _deviceBindings;

  /// Единственная реализация проверки PIN, которую зовёт эта касса — вся
  /// логика входа живёт в ней (`LocalAuthRepository`), а обработчики ниже
  /// только переводят кадр в довод и исход в кадр.
  final AuthRepository _auth;

  /// Отсутствует на установке без транспорта Telegram — это офлайновое
  /// развёртывание. Операции, которым он нужен, отказывают названной причиной,
  /// а не делают вид, что копий нет.
  final FirstLaunchRepository? _firstLaunch;

  /// Отсутствуют там, где железа нет вовсе: голый Dart-процесс
  /// (`bin/telepos_backend.dart`) не строит ни одного драйвера. Операция
  /// отказывает названной причиной, а не выдумывает пустой результат поиска —
  /// «ничего не нашлось» и «искать было нечем» для оператора разные вещи.
  final DeviceDiscovery? _deviceDiscovery;
  final DeviceCheck? _deviceCheck;

  /// `null` — этот процесс не завёл ни одной реализации (голый Dart,
  /// `bin/telepos_backend.dart`), не то же самое, что «демон недоступен»:
  /// демон, недостижимый на настоящей кассе, — это исключение уже внутри
  /// ненулевого `NetworkRepositoryLocal` (см. докстринг [NetworkRepository]),
  /// которое просто не ловится здесь и доезжает как `handler_failed`. Оба
  /// случая заканчиваются отказом, а не пустотой — см. докстринг довода
  /// конструктора выше и `_requireNetwork`.
  final NetworkRepository? _network;

  AppInitStatus? _bootResult;

  /// Какая QUIC-сессия какой терминал завела — пункт 2 фазы 3/4 закрытия
  /// долга.
  ///
  /// До этой правки `auth.login` брал `terminalId` из тела кадра как есть и
  /// проверял о нём только одно: что такая строка существует
  /// (`terminals.list()`). Кассир с собственным действительным PIN мог
  /// назваться **чужим** терминалом — список видно через `terminals.list`
  /// любому сеансу — и получить `AuthSession.terminalId`, за которым его
  /// вкладка не сидит: пробный чек и денежный ящик открывались бы ровно как
  /// до задачи 10.
  ///
  /// Заполняется двумя обработчиками, которым это доступно, —
  /// `terminals.register` (браузер заводит свою строку) и
  /// `terminals.selfEnsure` (десктоп через `WtTerminalRepository.self()`,
  /// хотя настоящий десктоп сюда не заходит вовсе — он не ходит по проводу,
  /// см. докстринг у `authLogin` ниже) — и читается `auth.login`: терминал
  /// берётся из того, что **эта же сессия** сама только что завела, а не из
  /// тела. Чужим терминалом назваться после этого нельзя — сессия может
  /// назвать только тот id, который сама получила в ответ на свой же
  /// `register()`/`selfEnsure()`.
  ///
  /// Не переживает закрытие сессии — [forgetSession] чистит запись, тот же
  /// приём, что `SessionRegistry._forget()`/`LoginThrottle._forget()`: без
  /// уборки карта росла бы без предела на весь срок жизни кассы.
  ///
  /// **Ключ — не сырой `sessionId`.** До правки 3 волны закрытия долга
  /// безопасности (2026-08-22) им был он, а `TillOperations` — один объект
  /// на всё развёртывание (см. `main.dart`), в то время как `rk_quic`
  /// заводит `sessionId` независимым счётчиком **на каждый листенер**
  /// (`packages/rk_quic/rust/src/transport.rs`, `next_session` — счётчик
  /// внутри функции подъёма, не статика процесса). В `loopback` (два
  /// листенера — IPv4- и IPv6-петля) `sessionId=1` существовал на обоих
  /// одновременно, и запись одного слушателя перезаписывала запись другого:
  /// та самая подмена терминала, которую задача 10 закрывала на уровне
  /// сторожа, вернулась бы с другой стороны.
  ///
  /// Решено не здесь и не в `rk_quic`, а на стороне кассы, в `TillWire`
  /// (`till_wire.dart`, `TillWire.listenerId`/`_sessionKey`): то, что
  /// приходит сюда вторым доводом [WireHandler] и первым доводом
  /// [forgetSession], уже уникально на кассу — `loopback`-коллизии нет
  /// структурно, а не потому, что она маловероятна. `everywhere` (настоящее
  /// развёртывание, один сокет, один `TillWire`) не меняется вовсе:
  /// `listenerId` там 0, и составной ключ равен сырому.
  final Map<int, int> _sessionTerminals = {};

  /// Порт «есть ли живой сеанс на этом терминале» — довесок фазы 3/4
  /// закрытия долга, часть Б. `null` там, где его не завели (см. докстринг
  /// конструктора): уборка тогда не работает вовсе, а не работает неверно.
  final TerminalSessionCheck? _sessions;

  /// Порт «список живых сеансов и их отзыв» — задача 19 закрытия долга
  /// безопасности. `null` там, где его не завели, см. докстринг
  /// конструктора; операции [TillOps.authSessions]/[TillOps.authSessionRevoke]
  /// отказывают названной причиной через [_requireSessionAdmin], а не молчат.
  final SessionAdmin? _sessionAdmin;

  /// Список выданных кодов привязки — довод `terminals.register` (задача 6
  /// плана «знакомство терминала с кассой», шаг 3 спеки). `null` там, где не
  /// заведён — регистрация тогда отказывает названной причиной на любой
  /// код, а не пропускает: см. докстринг конструктора про то, чем это
  /// отличается от прочих опциональных портов выше.
  final PairingInvites? _invites;

  /// Сколько терминал обязан простоять без хозяина, прежде чем
  /// [_pruneUnusedTerminals] сочтёт его безопасным убрать — см. докстринг
  /// там же.
  final Duration _terminalIdleGrace;

  final DateTime Function() _clock;

  /// Когда [_pruneUnusedTerminals] в последний раз видела, что у терминала
  /// **нет** сессии-хозяина — то есть с этого момента он простаивает.
  /// Заполняется в двух местах: [forgetSession] (QUIC-сессия, владевшая
  /// терминалом, закрылась) и `terminals.register` (та же QUIC-сессия
  /// зарегистрировала себе замену, не закрывшись, — брошенный терминал
  /// осиротел ровно тем же способом, просто без события `SessionClosed`).
  ///
  /// Не переживает перезапуск кассы — тем же решением, что и
  /// [_sessionTerminals], которую эта карта зеркалит: `sessionId`, с которым
  /// связана запись, сам не переживает перезапуск (`rk_quic` заводит его
  /// заново с нуля на каждый листенер), так что хранить это где-то ещё, кроме
  /// памяти процесса, было бы враньём о точности, которой нет. Касса,
  /// перезапущенная посреди дня, честно теряет память о том, что терминал
  /// давно осиротел, — как теряет и все живые сеансы
  /// (`SessionRegistry`, «это свойство»).
  final Map<int, DateTime> _terminalIdleSince = {};

  /// Забывает, какой терминал завела эта сессия — зовётся `TillWire` на
  /// `SessionClosed` (`onSessionClosed`, `till_wire.dart`).
  ///
  /// Отмечает терминал осиротевшим в [_terminalIdleSince] — единственный
  /// путь, которым карта узнаёт про закрытие QUIC-сессии; сама она наружу
  /// об этом не сигналит. `terminalSelfEnsure` — второй писатель
  /// [_sessionTerminals] — сюда не заходит намеренно: он не заводит новую
  /// строку (`self()` идемпотентен), значит и осиротевшего терминала после
  /// него не остаётся, а `isSelf`-терминал, на который он указывает,
  /// [_pruneUnusedTerminals] и так не тронет ни при каких условиях.
  void forgetSession(int sessionId) {
    final terminalId = _sessionTerminals.remove(sessionId);
    if (terminalId != null) _terminalIdleSince[terminalId] = _clock();
  }

  /// Терминал, который эта же QUIC-сессия сама завела через
  /// `terminals.register`/`terminals.selfEnsure` — задача 21 закрытия долга
  /// безопасности.
  ///
  /// Читающий двойник [_sessionTerminals], а не второй источник: тот же
  /// самый источник, которым уже пользуется `auth.login` (`askHandlers`
  /// выше). Заведён затем, что `TillWire.onDenied`
  /// (`lib/data/transport/till_wire.dart`) видит отказ сторожа раньше, чем
  /// дело доходит до `askHandlers`, и без сеанса (`WireDenied.unauthorized`)
  /// у него нет другого способа узнать, какой терминал прислал отказанный
  /// запрос — см. `buildWireDeniedJournalHandler`,
  /// `lib/backend/security_journal.dart`.
  int? terminalForSessionKey(int sessionKey) => _sessionTerminals[sessionKey];

  /// Чем закончился подъём этой кассы.
  ///
  /// Считается один раз и запоминается: перезагрузка страницы не имеет права
  /// заново прогонять подъём кассы, которая уже открыта. Память живёт здесь, а
  /// не у транспорта, и это пережило снятие HTTP: пока транспорта было два,
  /// памятка на каждый из них подняла бы кассу дважды на машине, где есть оба.
  Future<AppInitStatus> boot() async =>
      _bootResult ??= await _bootstrap.start(onProgress: (_, _) {});

  /// Одноразовые вопросы, включая `auth.login` и `auth.logout` — их логика
  /// целиком в [_auth] (`LocalAuthRepository`), здесь только перевод кадра.
  ///
  /// Карта строится один раз: обработчики держат состояние (память о подъёме),
  /// и пересобирать их на каждое обращение значило бы раздать разным читателям
  /// разные замыкания над одним и тем же объектом — работает, но выглядит как
  /// две реализации, а их здесь быть не должно.
  late final Map<String, WireHandler> askHandlers = {
    TillOps.startupBoot.name: (_, [_]) async => {'status': (await boot()).name},

    TillOps.setupFirstLaunch.name: (_, [_]) async => {
      'result': (await _requireFirstLaunch().determineResult()).name,
    },

    TillOps.setupBackups.name: (_, [_]) async => {
      'backups': (await _requireFirstLaunch().findAvailableBackups())
          .map((backup) => backup.toJson())
          .toList(),
    },

    TillOps.setupNewPos.name: (_, [_]) async => {
      'posKey': await _requireFirstLaunch().startNewPos(),
    },

    // Весь черновик едет одним обменом, потому что фиксация — одна
    // транзакция: касса со счетами и без пользователей не может ни принять
    // деньги, ни быть донастроенной.
    TillOps.setupComplete.name: (body, [_]) async {
      await _setup.completeSetup(setupDraftFromJson(body));
      return {'ok': true};
    },

    TillOps.deviceBindingSave.name: (body, [_]) async {
      final terminalId = _requireInt(body, 'terminalId');
      final raw = body['binding'];
      if (raw is! Map<String, dynamic>) {
        // Задача 2б, отложенная в задачу 10: `WireRefusal`, а не
        // `ArgumentError` — тот же перевод, что и у `_requireInt` ниже и у
        // `terminalRename`/`terminalRegister` выше. `ArgumentError` доезжал
        // бы до терминала только именем типа (`safeErrorText`,
        // `lib/core/errors/safe_error_text.dart`) — «ожидался объект
        // привязки» до человека не доходило вовсе.
        throw const WireRefusal('bad_request', 'ожидался объект привязки');
      }
      // Тот же разбор, которым пользуется читающая сторона: `save` заменяет
      // привязку того же класса, а не добавляет вторую строку.
      await _deviceBindings.save(
        terminalId,
        deviceBindingFromWireJson(raw, terminalId: terminalId),
      );
      return {'ok': true};
    },

    TillOps.terminalRename.name: (body, [_]) async {
      final name = (body['name'] as String? ?? '').trim();
      if (name.isEmpty) {
        throw const WireRefusal('bad_request', 'имя обязательно');
      }
      await _terminals.rename(_requireInt(body, 'terminalId'), name);
      return {'ok': true};
    },

    // Единственная сессия, читающая `sessionId` затем, чтобы **запомнить**
    // терминал, а не только прочитать (`terminalSelfEnsure` ниже — второй) —
    // см. докстринг [_sessionTerminals].
    TillOps.terminalRegister.name: (body, [sessionId]) async {
      // Пустое имя отклоняет и сам репозиторий; проверка здесь — чтобы отказ
      // назывался «имя обязательно», а не приходил из глубины drift.
      final name = (body['name'] as String? ?? '').trim();
      if (name.isEmpty) {
        throw const WireRefusal('bad_request', 'имя обязательно');
      }
      // Задача 6 плана «знакомство терминала с кассой» (шаг 3 спеки): гейт —
      // здесь, а не в сторожа (докстринг [EnrolmentAccess], `wire_access
      // .dart`, объясняет почему). До проверки уборки ниже: непроверенный
      // запрос не имеет права трогать базу, даже уборкой чужих строк.
      //
      // `_invites == null` — регистрация недоступна вовсе (докстринг поля
      // [_invites]), не то же самое, что «код неверный», но терминалу это
      // не сообщается отдельным кодом: с его стороны нечем отличить кассу
      // без настроенного привязчика от кассы, которой не предъявили код —
      // оба раза единственное действие одно и то же: получить код на кассе.
      final code = body['code'] as String?;
      if (_invites == null || !_invites.redeem(code)) {
        throw const WireRefusal(
          'pairing_code_invalid',
          'нужен действующий код привязки — заведите его на кассе '
              '(«Привязка терминала») и повторите',
        );
      }
      // Довесок фазы 3/4 закрытия долга, часть Б: то самое место, где строки
      // и копятся (F5 вкладки заводит новый терминал на каждую перезагрузку,
      // пункт 6 фазы 3/4 не даёт переиспользовать старый) — здесь же их и
      // убирают, тем же приёмом, что `SessionRegistry.mint()`/`LoginThrottle`
      // зовут свою уборку первой строкой операции, а не по будильнику. До
      // проверки потолка [_terminals.register] — свежее место обязано
      // засчитаться до того, как потолок откажет новой регистрации.
      await _pruneUnusedTerminals();
      final enrollment = await _terminals.register(name: name);
      final terminal = enrollment.terminal;
      if (sessionId != null) {
        // Та же сессия уже сидела на другом терминале и заводит замену, не
        // закрывшись, — например, `login_controller.dart` после
        // `UnknownTerminalException` сбрасывает кэш и зовёт `register` снова
        // на той же QUIC-сессии. Прежний терминал осиротел прямо сейчас, и
        // без этой строки [_terminalIdleSince] узнала бы об этом только на
        // `SessionClosed`, если он вообще случится раньше, чем вкладку
        // закроют совсем.
        final previous = _sessionTerminals[sessionId];
        if (previous != null && previous != terminal.id) {
          _terminalIdleSince[previous] = _clock();
        }
        _sessionTerminals[sessionId] = terminal.id;
      }
      // Секрет едет в ответе значением — единственный обмен на всём проводе,
      // которому это разрешено (докстринг `terminalEnrollmentToWireJson`,
      // `terminal_wire.dart`). Задача 4 — выдача и хранение: кто на другом
      // конце сохранит его и предъявит обратно на новой сессии — задача 5,
      // ниже (`terminalResume`).
      return terminalEnrollmentToWireJson(enrollment);
    },

    // Третий писатель [_sessionTerminals] (после `terminalRegister` и
    // `terminalSelfEnsure` выше) — задача 5 плана «знакомство терминала с
    // кассой», шаг 2 спеки. Вкладка, пережившая F5 или закрытие/повторное
    // открытие, предъявляет секрет, который получила от `terminalRegister`
    // единственный раз, вместо того чтобы заводить новую строку заново.
    //
    // `_terminals.resume` сама решает, свой это секрет или чужой
    // ([TerminalSecret.matches] — константное время, докстринг там), и сама
    // бросает [WireRefusal] на любой из трёх поводов (id не существует,
    // отпечатка нет, секрет не сходится) — обработчику здесь сверять уже
    // нечего, только перевести кадр в довод и исход в кадр, тем же приёмом,
    // что и у соседних обработчиков.
    //
    // Уборки (`_pruneUnusedTerminals`) здесь нет намеренно, в отличие от
    // `terminalRegister`: эта ветка не вставляет новую строку — освобождать
    // место не для чего, — а звать её означало бы рисковать убрать именно
    // тот терминал, который эта же операция сейчас возвращает к жизни (гонка
    // с [_terminalIdleSince], закрытая ниже явным `remove`, а не порядком
    // вызовов).
    TillOps.terminalResume.name: (body, [sessionId]) async {
      final terminalId = _requireInt(body, 'terminalId');
      final secret = body['secret'] as String? ?? '';
      final terminal = await _terminals.resume(
        terminalId: terminalId,
        secret: secret,
      );
      if (sessionId != null) {
        // Та же сессия уже сидела на другом терминале — тот же довод, что и
        // у `terminalRegister`: прежний терминал осиротел прямо сейчас, а не
        // когда (и если) эта сессия когда-нибудь закроется.
        final previous = _sessionTerminals[sessionId];
        if (previous != null && previous != terminal.id) {
          _terminalIdleSince[previous] = _clock();
        }
        _sessionTerminals[sessionId] = terminal.id;
      }
      // Терминал живой снова — если [forgetSession] прошлой QUIC-сессии уже
      // отметила его осиротевшим, эта запись обязана уйти немедленно, а не
      // ждать следующего прохода [_pruneUnusedTerminals]: без этой строки
      // терминал, возвращённый ровно сейчас, мог бы быть убран уборкой,
      // запущенной следующим `terminals.register` другой вкладки раньше, чем
      // истечёт [_terminalIdleGrace] — грубее, но той же по сути гонки,
      // которую комментарий выше называет прямо.
      _terminalIdleSince.remove(terminal.id);
      return {'terminal': terminalToWireJson(terminal)};
    },

    // Существование, каскад привязок и запрет на `isSelf` — забота
    // `TerminalRepository.delete` (тот же приём, что у `terminalRegister`
    // выше: потолок и дедупликация по имени решает репозиторий, а не
    // обработчик). `isSelf` — не то же самое, что «терминал вкладки,
    // приславшей этот кадр»: строку самой кассы вызывающая вкладка почти
    // никогда не видит, а свою собственную — видит всегда.
    //
    // Запрет «не удаляй терминал вкладки» (задача 9 закрытия долга) до
    // задачи 10 жил здесь же, обработчиком, вторым доводом `WireHandler` —
    // единственная причина, по которой тот довод вообще существовал. Задача
    // 10 забрала эту сверку в сторож (`SessionAccess.ownTerminal:
    // TerminalOwnership.different`, `till_ops.dart`) вместе с четырьмя
    // соседними дырами, которых у `terminals.delete` не было: обработчику
    // сверять больше нечего, и второй довод снят целиком
    // (`lib/data/transport/till_wire.dart`). Ниже остался только вызов
    // репозитория — `_terminals.delete` сам отказывает `isSelf`-терминалу.
    TillOps.terminalDelete.name: (body, [_]) async {
      await _terminals.delete(_requireInt(body, 'terminalId'));
      return {'ok': true};
    },

    // Второй писатель [_sessionTerminals] — см. докстринг там. Настоящему
    // десктопу это не грозит и не помогает: он не ходит по проводу вовсе
    // (`ownsData == true` зовёт `LocalTerminalRepository`/`LocalAuthRepository`
    // напрямую, в обход `TillWire` целиком) — сюда доходят только браузеры, у
    // которых `self()` отдаёт терминал самой кассы (`isSelf`), не терминал
    // сессии. Запоминание здесь не портит `auth.login`: честный браузер
    // входит через `register()`, не через `self()` (`login_controller.dart`,
    // `_resolveTerminalId`) — но не запомнить было бы хуже, чем запомнить
    // лишнее: без записи `deviceCheck` тут же после `terminals.selfEnsure`
    // на новой вкладке видел бы её как терминал, ничего не зарегистрировавший
    // (см. И1 в отчёте про то, что этой веткой в проде не пользуются).
    //
    // `access: OpenAccess()` (`till_ops.dart`) — эта же запись работает и
    // для нечестного клиента: `terminals.selfEnsure` не спрашивает ни кода
    // привязки, ни секрета, только доходит до `auth.login` с сессией,
    // привязанной к терминалу самой кассы (`isSelf`, `pointMode: cashier` по
    // умолчанию — самый широкий режим), а не к выдуманному чужому терминалу.
    // Разобрано и оставлено открытым сознательно волной финальных правок
    // 2026-08-23 (не регрессия — до задачи 6 `register()` была открыта тем
    // же путём и короче) — полный довод и почему закрыть условием не вышло
    // эмпирически (сеанс/петля/`ownsData`) — раздел «Границы»,
    // `docs/internal/superpowers/specs/2026-08-23-terminal-enrolment-design.md`.
    TillOps.terminalSelfEnsure.name: (_, [sessionId]) async {
      try {
        final terminal = await _terminals.self();
        if (sessionId != null) _sessionTerminals[sessionId] = terminal.id;
        return {'terminal': terminalToWireJson(terminal)};
      } on InstallationNotConfiguredException {
        // Значением, а не кадром отказа: «мастер ещё не проходил» — обычное
        // состояние свежей установки, и отличать его от настоящей поломки по
        // тексту ошибки пришлось бы строкой.
        return {'terminal': null};
      }
    },

    TillOps.deviceDiscovery.name: (body, [_]) async =>
        deviceDiscoveryResultToJson(
          await _requireDiscovery().find(_requireDeviceClass(body)),
        ),

    TillOps.deviceCheck.name: (body, [_]) async => deviceCheckOutcomeToJson(
      await _requireCheck().check(
        terminalId: _requireInt(body, 'terminalId'),
        deviceClass: _requireDeviceClass(body),
      ),
    ),

    // Пункт 2 фазы 3/4 закрытия долга: `terminalId` больше не берётся из
    // тела кадра — тело кассир может набрать сам, `sessionId` подделать не
    // может (его назначает `rk_quic` на своей стороне, до разбора кадра —
    // см. докстринг [WireHandler]). Берётся из [_sessionTerminals]: что эта
    // же QUIC-сессия сама завела через `terminals.register`/`terminals
    // .selfEnsure` до этого запроса. Тело всё ещё несёт `terminalId` —
    // десктопный `AuthAttempt` (`LocalAuthRepository.login`, вызывается в
    // обход провода) продолжает использовать его как раньше; здесь оно
    // читается только диагностики ради ниже, в тексте отказа.
    //
    // Без предварительной регистрации на этой сессии входа нет —
    // `unknown_terminal`, тот же код, что раньше отвечал на несуществующий
    // id. `WtAuthRepository` (`lib/web/wt_auth_repository.dart`) уже
    // переводит его в `UnknownTerminalException`, и `login_controller.dart`
    // уже на него реагирует повторной заводкой — эта ветка не заводит нового
    // клиентского пути, только делает существующий обязательным.
    TillOps.authLogin.name: (body, [sessionId]) async {
      final pin = body['pin'] as String? ?? '';
      final userId = body['userId'] as int?;

      final boundTerminalId = sessionId == null
          ? null
          : _sessionTerminals[sessionId];
      if (boundTerminalId == null) {
        throw WireRefusal(
          'unknown_terminal',
          'эта сессия ещё не завела терминал через terminals.register/'
              'terminals.selfEnsure (тело называло terminalId='
              '${body['terminalId']})',
        );
      }

      // Защита не от подделки (сессия уже доказала владение регистрацией),
      // а от гонки: терминал этой же сессии успели удалить
      // (`terminals.delete`) между регистрацией и входом.
      final terminals = await _terminals.list();
      if (!terminals.any((terminal) => terminal.id == boundTerminalId)) {
        throw WireRefusal(
          'unknown_terminal',
          'терминала с таким id не существует: $boundTerminalId',
        );
      }

      final outcome = await _auth.login(
        AuthAttempt(
          pin: pin,
          terminalId: boundTerminalId,
          userId: userId,
          // Правка А БЛОКЕРА закрытия долга безопасности (2026-08-22):
          // ключ справедливости для `Pbkdf2Gate` — та же QUIC-сессия,
          // которую уже проверил `boundTerminalId` выше, а не сырой
          // `userId` (его нападающий выбирает свободно — это имя жертвы, не
          // его собственное). См. докстринг `AuthAttempt.sessionKey`.
          sessionKey: sessionId,
        ),
      );
      // Обработчик не содержит ни одной строки логики входа: он переводит
      // кадр в довод и исход в кадр. Проверка PIN живёт в одном месте на всю
      // систему — в `LocalAuthRepository`.
      return authOutcomeToWireJson(outcome);
    },

    TillOps.authLogout.name: (body, [_]) async {
      await _auth.logout(body['token'] as String? ?? '');
      return {'ok': true};
    },

    // Задача 19 закрытия долга безопасности: экран списка сеансов
    // (`sessions_screen.dart`) не имел вызывающего для отзыва — этот
    // обработчик и есть недостающий путь, зовёт `revokeSession` (по
    // терминалу, не по токену — см. докстринг `TillOps.authSessionRevoke`).
    // Не тот же метод, что `SessionRegistry.revokeAll()` (существовал с
    // задачи 9, ни разу не был вызван рабочим кодом, снят задачей 21) —
    // тот гасил всю кассу разом, этот — один терминал.
    TillOps.authSessionRevoke.name: (body, [_]) async => {
      'ok': await _requireSessionAdmin().revokeSession(
        _requireInt(body, 'terminalId'),
      ),
    },

    // Задача «сетевые настройки по проводу» (спека 2026-08-24): шесть
    // обработчиков, каждый — перевод кадра в довод и исход в кадр поверх
    // `_requireNetwork()`, без логики здесь — она вся в
    // `NetworkRepositoryLocal`/`SysdClient`.
    TillOps.networkStatus.name: (_, [_]) async =>
        networkStatusToWireJson(await _requireNetwork().status()),

    TillOps.networkWifiScan.name: (_, [_]) async => {
      'networks': (await _requireNetwork().wifiScan())
          .map(wifiNetworkToWireJson)
          .toList(),
    },

    TillOps.networkWifiConnect.name: (body, [_]) async {
      final ssid = (body['ssid'] as String? ?? '').trim();
      if (ssid.isEmpty) {
        throw const WireRefusal('bad_request', 'ssid обязателен');
      }
      final res = await _requireNetwork().wifiConnect(
        ssid,
        body['password'] as String?,
      );
      return {'success': res.success, 'message': res.message};
    },

    TillOps.networkWifiDisconnect.name: (_, [_]) async => {
      'ok': await _requireNetwork().wifiDisconnect(),
    },

    TillOps.networkEthernetStatus.name: (_, [_]) async =>
        await _requireNetwork().ethernetStatus(),

    TillOps.networkEthernetConfigure.name: (body, [_]) async {
      final iface = (body['iface'] as String? ?? '').trim();
      if (iface.isEmpty) {
        throw const WireRefusal('bad_request', 'iface обязателен');
      }
      final network = _requireNetwork();
      final mode = body['mode'] as String? ?? 'dhcp';
      final ({bool success, String mode}) res;
      if (mode == 'static') {
        final ipCidr = (body['ipCidr'] as String? ?? '').trim();
        if (ipCidr.isEmpty) {
          throw const WireRefusal(
            'bad_request',
            'ipCidr обязателен для статического режима',
          );
        }
        res = await network.ethernetConfigureStatic(
          iface,
          ipCidr: ipCidr,
          gateway: body['gateway'] as String?,
          dns: body['dns'] as String?,
        );
      } else {
        res = await network.ethernetConfigureDhcp(iface);
      }
      return {'success': res.success, 'mode': res.mode};
    },
  };

  /// Ленивая уборка неиспользуемых строк `terminals` — довесок фазы 3/4
  /// закрытия долга, часть Б. Тот же приём, что `SessionRegistry._forget()`/
  /// `LoginThrottle._forget()` (докстринги там): чистка на обращении, без
  /// второго процесса и без будильника — зовётся первой строкой
  /// [TillOps.terminalRegister], то самое место, где строки и копятся
  /// (каждая перезагрузка вкладки — честная новая строка, пункт 2 фазы 3/4;
  /// переиспользования нет нарочно, пункт 6 — отчёт `phase34-fix-report.md`).
  ///
  /// Убирает терминал, только если верны **все** условия разом — брошенная
  /// строка не значит ничья строка, а по брифу «сомневаешься — не убирай»:
  ///
  /// - **не `isSelf`.** Терминал самой кассы неприкосновенен по
  ///   определению — `LocalTerminalRepository.delete` откажет и сам, но
  ///   проверка здесь тоже есть: без неё один отказ прервал бы уборку
  ///   остальных кандидатов в этом же проходе, а `isSelf` — не то, ради чего
  ///   стоит останавливать всю уборку.
  /// - **нет ни одной привязки устройства** (`TerminalDeviceBindings`).
  ///   Терминал с настроенным принтером/сканером — это чья-то настоящая
  ///   рабочая станция, а не мусор от F5, даже если на ней сейчас никто не
  ///   сидит: смена кончилась, касса выключена на ночь, привязка осталась.
  /// - **нет `secretFingerprint`.** Финальная правка закрытия долга: до
  ///   задачи 5 всякая строка была честным мусором от F5 — вкладка всё равно
  ///   регистрировалась бы заново на следующей загрузке, терять было нечего.
  ///   С задачи 5 у терминала, прошедшего привязку по одноразовому коду,
  ///   есть личность («личность переживает перезагрузку» — шаг 2 спеки), и
  ///   удаление строки эту личность уничтожает: планшет, закрытый на ночь,
  ///   терял бы привязку в тот самый момент, когда утром рядом заводят
  ///   другое устройство, и требовал бы нового кода у оператора без всякой
  ///   на то причины. Секрет не протухает — раз выданный, он либо ещё
  ///   действителен, либо явно отозван через `terminals.delete` — так что это
  ///   условие не «пока», а окончательное: такую строку эта уборка не тронет
  ///   никогда.
  /// - **на него не выписан живой `AuthSession`** ([_sessions],
  ///   [TerminalSessionCheck]). Критично для самого сценария, ради которого
  ///   пишется уборка: F5 заводит НОВУЮ QUIC-сессию и НОВЫЙ `terminalId`
  ///   (пункт 6 фазы 3/4 — переиспользования нет), но токен в
  ///   `SessionTokenStorage` переживает перезагрузку и восстанавливает
  ///   СТАРЫЙ сеанс через `_restoreSession()` (`login_controller.dart`) —
  ///   сеанс, выписанный на СТАРЫЙ `terminalId`. У старой строки в этот
  ///   момент одновременно и «QUIC-сессия закрыта» (следующее условие это
  ///   разрешит), и «под живым сеансом кассира, который прямо сейчас
  ///   работает» — убрать её значило бы вышибить терминал из-под
  ///   работающего человека, ровно то, что бриф запрещает первым делом.
  /// - **её QUIC-сессия закрыта, и с тех пор прошло не меньше
  ///   [_terminalIdleGrace].** «Закрыта» здесь означает «эта строка есть в
  ///   [_terminalIdleSince]» — строка, которую в памяти этого процесса
  ///   никогда не видели осиротевшей (свежая регистрация; сессия ещё
  ///   открыта; терминал заведён вручную из настроек, минуя `register()`;
  ///   или касса перезапускалась и память потеряна вместе со всеми
  ///   остальными сеансами — то же решение, что у `SessionRegistry`), не
  ///   трогается вовсе — тот же довод «сомневаешься — не убирай». Сама
  ///   задержка — не защита от найденной гонки (переиспользования
  ///   `terminalId` не бывает, значит и обратно завладеть той же строкой
  ///   никто не попытается), а дешёвый запас осторожности: проблема, которую
  ///   чинит уборка, копится часами (сотни F5 за смену), а не секундами, так
  ///   что несколько минут задержки не мешают эффективности и оставляют
  ///   время утихнуть любой гонке, которую этот разбор не нашёл.
  ///
  /// [_sessions] отсутствует (см. докстринг конструктора) → уборка не
  /// делает ничего вовсе, а не что-то по неполным данным: без порта, умеющего
  /// ответить про живой сеанс, третье условие недоказуемо, а угадывать его
  /// значило бы разменять «лучше лишняя строка» на «лучше отрезанный
  /// кассир».
  Future<void> _pruneUnusedTerminals() async {
    final sessions = _sessions;
    if (sessions == null || _terminalIdleSince.isEmpty) return;

    final cutoff = _clock().subtract(_terminalIdleGrace);
    final candidates = [
      for (final entry in _terminalIdleSince.entries)
        if (!entry.value.isAfter(cutoff)) entry.key,
    ];

    for (final terminalId in candidates) {
      // Терминал этого id снова под живой QUIC-сессией — тем же приёмом
      // защищена и версия, где `terminalId` теоретически переиспользовался
      // бы: сегодня это недостижимый путь (пункт 6), но проверка дешевле,
      // чем довод о том, почему она не нужна.
      if (_sessionTerminals.containsValue(terminalId)) continue;

      final row = await _db.terminalDao.findById(terminalId);
      if (row == null) {
        // Терминал уже убран другим путём (`terminals.delete` из настроек) —
        // бухгалтерии больше не за чем следить.
        _terminalIdleSince.remove(terminalId);
        continue;
      }
      if (row.isSelf) {
        // Не должно случаться — `terminalSelfEnsure` не пишет
        // [_terminalIdleSince] намеренно (см. докстринг [forgetSession]) —
        // но обрывает надёжно, а не по факту, что путь сюда не найден.
        _terminalIdleSince.remove(terminalId);
        continue;
      }
      if (row.secretFingerprint != null) {
        // Терминал прошёл привязку по одноразовому коду (задача 5) — у него
        // есть личность, которая обязана пережить простой и перезапуск кассы
        // (шаг 2 спеки: «личность переживает перезагрузку»). До задачи 5
        // брошенная строка без секрета была честным мусором от F5 — теперь
        // это может быть планшет, выключенный на ночь. Секрет не протухает,
        // так что строка не выйдет из этого исключения сама — раз и навсегда
        // снимаем её с учёта, а не откладываем то же решение на каждый
        // следующий проход.
        _terminalIdleSince.remove(terminalId);
        continue;
      }

      final bindings = await _db.terminalDao.deviceBindingsFor(terminalId);
      if (bindings.isNotEmpty) continue; // настоящая станция — не мусор.

      if (sessions.hasLiveSession(terminalId)) continue; // кассир работает.

      try {
        await _terminals.delete(terminalId);
      } on Object {
        // Уборка — любезность, не обещание: гонка (кто-то удалил ту же
        // строку между `findById` выше и этим вызовом) или любой другой
        // отказ репозитория не имеют права сорвать `terminals.register`,
        // ради которого эта уборка вообще позвана.
      }
      _terminalIdleSince.remove(terminalId);
    }
  }

  /// Подписки, включая `auth.users` и `auth.session` — то самое, ради чего
  /// менялся транспорт.
  ///
  /// Каждая отдаёт **бесконечный** поток: состояние не «заканчивается», и
  /// завершившийся поток означал бы для терминала «дальше изменений не будет»,
  /// то есть окончательность, которой нет. Снимаются они уходом подписчика —
  /// см. `TillSubscriptions`.
  late final Map<String, WireWatchHandler> watchHandlers = {
    TillOps.setupState.name: (_) =>
        watchSetupStateOf(_db).map(setupStateToWireJson),

    TillOps.terminalsList.name: (_) => _terminals.watchAll().map(
      (terminals) => {'terminals': terminals.map(terminalToWireJson).toList()},
    ),

    // `null` уезжает кадром с `terminal: null`, а не отказом: свежая
    // установка, где мастер ещё не проходил, — обычное состояние, и экран
    // мастера обязан открыться именно на нём.
    TillOps.terminalSelf.name: (_) => _terminals.watchSelf().map(
      (terminal) => {
        'terminal': terminal == null ? null : terminalToWireJson(terminal),
      },
    ),

    TillOps.deviceBindings.name: (body) {
      // Идентификатор читается **до** подписки, а не внутри `map`: плохой
      // довод обязан стать кадром отказа сразу, а не подпиской, которая
      // заведётся и упадёт на первом же обновлении.
      final terminalId = _requireInt(body, 'terminalId');
      return _deviceBindings
          .watchForTerminal(terminalId)
          .map(
            (bindings) => {
              // `terminalId` едет в ответе — его ждёт `_decodeBindings` в
              // `till_ops.dart` ради текста отказа при нераспознанном классе.
              'terminalId': terminalId,
              'bindings': bindings.map(deviceBindingToWireJson).toList(),
            },
          );
    },

    TillOps.authUsers.name: (_) => _auth.watchUsers().map(
      (users) => {'users': users.map(authUserToWireJson).toList()},
    ),

    TillOps.authSession.name: (body) {
      // Токен читается до подписки, как и `terminalId` в deviceBindings:
      // плохой довод обязан стать кадром отказа сразу.
      final token = body['token'] as String? ?? '';
      return _auth
          .watchSession(token)
          .map(
            (session) => {
              'session': session == null
                  ? null
                  : authSessionToWireJson(session),
            },
          );
    },

    // Задача 19 закрытия долга безопасности: экран списка живых сеансов.
    // Подписка, тем же доводом, что у `authUsers`/`authSession` рядом —
    // чужой вход и чужой отзыв обязаны дойти в момент события.
    TillOps.authSessions.name: (_) =>
        _requireSessionAdmin().watchLiveSessions().map(
          (sessions) => {
            'sessions': sessions.map(liveSessionToWireJson).toList(),
          },
        ),
  };

  /// Длинные работы. Обе идут минутами, и до провода канала для хода
  /// выполнения у них не было вовсе.
  late final Map<String, WireRunHandler> runHandlers = {
    TillOps.setupRestore.name: (body) async* {
      final firstLaunch = _requireFirstLaunch();
      final messageId = _requireInt(body, 'messageId');
      final backup = await findBackup(firstLaunch, messageId);
      if (backup == null) {
        // Отказ до первого кадра хода выполнения. `TillWire` превратит его в
        // кадр отказа: полоса, которая начала двигаться и остановилась, хуже
        // полосы, которая не начиналась. `WireRefusal` — та же болезнь, что
        // и у остальных мест этой задачи: текст называет копию по
        // `messageId` для человека, а не для лога, и общий `run_failed` его
        // прятал бы за именем типа исключения.
        throw WireRefusal(
          'backup_not_found',
          'копии с messageId=$messageId нет',
        );
      }
      yield* _withProgress(
        (onProgress) =>
            firstLaunch.restoreFromBackup(backup, onProgress: onProgress),
      );
    },

    TillOps.setupLoadGlobalData.name: (_) async* {
      final firstLaunch = _requireFirstLaunch();
      yield* _withProgress(
        (onProgress) => firstLaunch.loadGlobalData(onProgress: onProgress),
      );
    },
  };

  /// Превращает работу, которая сообщает о себе обратным вызовом, в поток
  /// кадров.
  ///
  /// [DoneFrame] уходит **только** при успешном возврате. Работа, бросившая
  /// исключение, заканчивается отказом без него: «готово» здесь означает целый
  /// магазин, и выдать незавершённое за завершённое дороже, чем показать
  /// причину.
  Stream<WireFrame> _withProgress(
    Future<bool> Function(BootProgress onProgress) work,
  ) {
    final frames = StreamController<WireFrame>();

    // Работа начинается сразу, а не с очередного оборота цикла событий:
    // `Future(...)` отложил бы её на событие, и первый кадр хода выполнения
    // приходил бы позже, чем есть что сказать. Слушатель уже есть — этот поток
    // возвращается изнутри генератора, которого слушают.
    Future<void> pump() async {
      try {
        final ok = await work((value, message) {
          if (frames.isClosed) return;
          // Число за краем — признак того, что его выдумали. Приёмник такой
          // кадр отвергает целиком, поэтому здесь оно приводится к отрезку:
          // окончание работы удостоверяет [DoneFrame], а не полоса, и врать о
          // завершении число не может.
          frames.add(ProgressFrame(value.clamp(0.0, 1.0).toDouble(), message));
        });
        frames.add(DoneFrame({'ok': ok}));
      } on Object catch (error, stackTrace) {
        // Отказ уезжает ошибкой потока, и `TillWire` делает из неё кадр
        // отказа **без** [DoneFrame].
        frames.addError(error, stackTrace);
      } finally {
        await frames.close();
      }
    }

    unawaited(pump());
    return frames.stream;
  }

  DeviceDiscovery _requireDiscovery() {
    final discovery = _deviceDiscovery;
    if (discovery == null) {
      // Свой код, а не `bad_request`: тело запроса тут ни при чём, отказывает
      // сама касса — на голом Dart-процессе (`bin/telepos_backend.dart`) нет
      // ни одного драйвера. «Искать было нечем» и «ничего не нашлось» для
      // оператора разные вещи, и код обязан их не путать так же, как текст.
      throw const WireRefusal(
        'no_drivers',
        'эта касса не умеет искать устройства (нет драйверов)',
      );
    }
    return discovery;
  }

  DeviceCheck _requireCheck() {
    final check = _deviceCheck;
    if (check == null) {
      // Тот же код, что у `_requireDiscovery`, и по тому же доводу: «искать
      // было нечем» и «ничего не нашлось» — разные вещи для `deviceCheck`
      // ровно так же, как для `deviceDiscovery` — держать их одним кодом
      // было бы расхождением на ровном месте.
      throw const WireRefusal(
        'no_drivers',
        'эта касса не умеет проверять устройства (нет драйверов)',
      );
    }
    return check;
  }

  /// Задача «сетевые настройки по проводу» (спека 2026-08-24). Свой код, не
  /// `no_drivers`: это не отсутствие драйвера железа, а процесс, для которого
  /// сеть кассы вовсе не заводили (докстринг поля [_network]) — отдельная
  /// причина заслуживает отдельного имени, а не переиспользования соседнего.
  NetworkRepository _requireNetwork() {
    final network = _network;
    if (network == null) {
      throw const WireRefusal(
        'no_network_module',
        'эта касса не умеет управлять сетью',
      );
    }
    return network;
  }

  /// Сколько символов присланного имени класса едет обратно в отказе.
  ///
  /// Терминал, приславший строку длиннее этого, получает свою же строку,
  /// но обрезанную — не потому что более длинное имя опасно само по себе, а
  /// потому что нет предела длине, которую доверенный протокол не проверяет:
  /// `deviceClass` в теле запроса читается как `Object?` и раньше уезжало в
  /// кадр отказа без единой проверки формы.
  static const _deviceClassNameLimit = 64;

  /// Читает класс устройства по имени.
  ///
  /// Нераспознанное имя — отказ, а не ближайший знакомый класс: угаданный
  /// класс отправил бы кассу искать не то железо и рапортовать о нём как о
  /// запрошенном.
  static DeviceClass _requireDeviceClass(Map<String, Object?> body) {
    final raw = body['deviceClass'];
    for (final value in DeviceClass.values) {
      if (value.name == raw) return value;
    }
    // Довод сужен до `String?` прежде, чем попасть в текст отказа: `raw` —
    // непроверенный `Object?` с провода, и терминал волен прислать туда
    // `Map`, число или строку любой длины. Кадр отказа не место для чужого
    // JSON целиком — только имя, которое реально пробовали, и с пределом
    // длины.
    final display = switch (raw) {
      String s when s.length > _deviceClassNameLimit =>
        '${s.substring(0, _deviceClassNameLimit)}…',
      String s => s,
      _ => 'не строка',
    };
    // `bad_request`, а не свой код: причина в теле запроса, ровно как у
    // пустого имени — терминал прислал класс устройств, которого касса не
    // знает, а не касса чего-то не умеет.
    throw WireRefusal(
      'bad_request',
      'этой кассе неизвестен такой класс устройств: $display',
    );
  }

  /// Порт списка сеансов и их отзыва — задача 19 закрытия долга
  /// безопасности. Тот же приём и тот же довод, что у [_requireDiscovery]/
  /// [_requireCheck] выше: на настоящей кассе он всегда есть, а тесты, у
  /// которых его нет, узнают об этом названной причиной, а не молчаливой
  /// пустотой.
  SessionAdmin _requireSessionAdmin() {
    final sessionAdmin = _sessionAdmin;
    if (sessionAdmin == null) {
      throw const WireRefusal(
        'no_session_registry',
        'эта касса не умеет показывать и отзывать сеансы (реестр сеансов '
            'не собран)',
      );
    }
    return sessionAdmin;
  }

  FirstLaunchRepository _requireFirstLaunch() {
    final firstLaunch = _firstLaunch;
    if (firstLaunch == null) {
      // Свой код, тем же доводом, что у `_requireDiscovery`: транспорта нет —
      // состояние самой кассы (офлайновое развёртывание), а не испорченное
      // тело запроса.
      throw const WireRefusal(
        'no_backup_transport',
        'на этой установке нет транспорта резервных копий (офлайновое '
            'развёртывание)',
      );
    }
    return firstLaunch;
  }

  /// Читает обязательное целое, не доверяя типу.
  ///
  /// Не подставляет умолчание: незаметно подменённый идентификатор терминала
  /// записал бы привязку устройства не туда, и увидеть это можно было бы
  /// только по неработающему принтеру у другого кассира.
  ///
  /// Задача 2б, отложенная в задачу 10: бросает `WireRefusal`, а не
  /// `ArgumentError`. `ArgumentError` доезжал бы до терминала только именем
  /// типа (`safeErrorText`, `lib/core/errors/safe_error_text.dart`) —
  /// «ожидалось целое: terminalId» до человека не доходило вовсе, и звалась
  /// эта функция шестью с лишним обработчиками.
  static int _requireInt(Map<String, Object?> body, String field) {
    final value = body[field];
    if (value is int) return value;
    throw WireRefusal('bad_request', 'ожидалось целое: $field');
  }

  /// Состояние установки — обе таблицы разом.
  ///
  /// Форма — [setupStateToWireJson], та же самая, которую читает
  /// [setupStateFromWireJson].
  Future<Map<String, Object?>> setupState() => readSetupState(_db);
}

/// Собирает [SetupState] этой установки в форму провода.
///
/// Сама сборка живёт в [readSetupStateOf] (`lib/data/setup/setup_state_source.dart`)
/// вместе со своей потоковой половиной: читателей у неё два — подписка провода
/// и локальный `StartupStateRepository` десктопной кассы, — а был и третий,
/// HTTP-маршрут, и однажды они уже разошлись (маршрут не писал `hasUsers`,
/// хотя читатель его читал, и браузерный терминал вечно получал «пользователей
/// нет»). Здесь остался только перевод в форму провода.
Future<Map<String, Object?>> readSetupState(AppDatabase db) async =>
    setupStateToWireJson(await readSetupStateOf(db));

/// Находит копию по идентификатору сообщения.
///
/// Копию ищет сама касса — у неё уже есть их список, — и по проводу едет один
/// идентификатор, а не вся копия. `null` означает «такой копии нет», и
/// решение, чем это назвать, принимает вызывающий: HTTP отвечает 404, провод —
/// кадром отказа.
Future<FoundBackup?> findBackup(
  FirstLaunchRepository firstLaunch,
  int messageId,
) async {
  final backups = await firstLaunch.findAvailableBackups();
  return backups.where((backup) => backup.messageId == messageId).firstOrNull;
}
