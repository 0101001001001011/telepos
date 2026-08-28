/// Прямой клиент провода для задачи 8: доказывает, что закрытую операцию
/// проверяет касса, а не экран, — на живом QUIC/WebTransport, без единого
/// байта из UI-слоя приложения.
///
/// # Что здесь доказывается и чем
///
/// Три шага, один вызов `TillOps.deviceCheck` в каждом — той самой операции,
/// что печатает пробный чек и открывает денежный ящик
/// (`lib/domain/wire/till_ops.dart:262-267`):
///
/// 1. **Без сеанса.** `WtDispatcher.ask` зовётся с пустым
///    `SessionTokenStore` — токена в кадре нет вовсе. Касса обязана ответить
///    `unauthorized` до того, как обработчик увидел запрос.
/// 2. **С сеансом и правом.** Вход кассиром «Кассир С PIN» (заводит
///    `stand/seed-cashiers`, права по умолчанию — все, `settings.hardware`
///    среди них) — тот же вызов обязан пройти проверку кассы. Стенд поднят с
///    `deviceCheck: null` (см. докстринг `wt_stand.dart` — голому процессу
///    негде взять драйверы), поэтому «прошёл проверку» здесь виден не как
///    успешный чек, а как **смена кода отказа**: не `unauthorized` от
///    стража, а `handler_failed` от самого обработчика
///    (`till_operations.dart:_requireCheck`), — то есть охрана пустила
///    запрос дальше себя.
/// 3. **С сеансом без права.** Вход кассиром «Кассир Без Права На
///    Оборудование» (заводит `stand/seed-restricted-cashier` — задача 8
///    добавила эту команду стенду, у обоих кассиров `seed-cashiers` нет ни
///    одной строки в `UserPermissions`, а её отсутствие читается кассой как
///    «разрешено всё» — см. `UserPermissionDao.getAllowedKeys`, — так что
///    без отдельно заведённого кассира с явным запретом отличить отказ по
///    праву от отказа по сеансу нечем). Тот же вызов, тот же валидный сеанс
///    — и снова отказ, но теперь `forbidden`, а не `unauthorized` (круг
///    правок 1 задачи 4 развёл эти два кода — `WireDenied.code`,
///    `lib/domain/wire/wire_guard.dart`: `unauthorized` лечится входом
///    заново, `forbidden` — не лечится вовсе, и путать их значило бы гонять
///    вошедшего кассира по кругу «войди — получи тот же отказ»). Это и
///    есть главное доказательство: право проверяется кассой на каждой
///    операции, а не однократно на входе и не разметкой экрана.
///
/// # Почему не браузер приложения и не сама интерактивная страница
///
/// Настоящее WebTransport-соединение существует только в браузере
/// (`lib/web/wt_session.dart` — `dart:js_interop`, второй реализации на VM
/// нет и быть не может: `rk_quic` — только серверный конец, см. его
/// `lib/rk_quic.dart`, «a browser is the client of this endpoint, never its
/// host»). Открыть стенд интерактивным браузером в этой среде не вышло —
/// таскинг задачи назвал это прямо: установка самоподписанного корня в
/// хранилище Windows виснет на невидимом окне подтверждения. Измерено здесь
/// же ещё раз другим путём: `mcp__plugin_playwright_playwright__browser_navigate`
/// на `https://127.0.0.1:9443/` отвечает `net::ERR_CERT_AUTHORITY_INVALID` —
/// автоматизированный Chromium этого плагина тоже проверяет цепочку и не
/// даёт её обойти.
///
/// Рабочий путь этой сессии — не установка корня, а команда, которой он не
/// нужен вовсе: настоящий Chrome, поднятый заголовочно с
/// `--ignore-certificate-errors` (флаг процесса, а не хранилище системы —
/// никакого UAC), управляемый по Chrome DevTools Protocol из `node`
/// (`node --version` здесь 24 — глобальный `WebSocket` есть без пакетов).
/// Драйвер — не часть репозитория (одноразовый инструмент сессии), но
/// рецепт воспроизводим дословно:
///
/// ```
/// "C:\Program Files\Google\Chrome\Application\chrome.exe" ^
///   --headless=new --disable-gpu --ignore-certificate-errors ^
///   --remote-debugging-port=9333 --user-data-dir=<temp>
/// # затем по CDP (Page.navigate на страницу стенда, Runtime.evaluate
/// # опрашивает window.TELEPOS_PROBE_DONE / window.TELEPOS_PROBE_LOG)
/// ```
///
/// Здесь настоящий Chromium с настоящей реализацией WebTransport браузера —
/// не подделка транспорта ради удобства проверки, только способ довести до
/// него команды без интерактивного окна.
///
/// # Почему это не браузерный сторож, а именно проверка кассы
///
/// Проба не заходит ни на один экран приложения (`main_web.dart` вообще не
/// участвует) и не проверяет ни `go_router`, ни `HardwareSettingsScreen` —
/// только `WtDispatcher.ask(TillOps.deviceCheck, …)` напрямую, тем же
/// вызовом, каким `WtDeviceCheck` (`lib/web/wt_device_check.dart`) кормит
/// настоящий экран настроек. Если бы отказ был построен в виджете (кнопка
/// скрыта, маршрут не пускает), эта проба увидела бы кадр `handler_failed`
/// или успешный ответ независимо от прав — здесь его нет ни разу: у
/// кассира без права всегда `forbidden`, у кассира с правом — никогда.
///
/// # Запуск (интерактивно, как `wt_watch_probe.dart`)
///
/// ```
/// flutter build web -t test/manual/wt_auth_probe.dart --release --pwa-strategy=none
/// TELEPOS_STAND_WEB=build/web flutter test --tags manual --run-skipped \
///   test/manual/wt_stand.dart
/// ```
///
/// Затем:
/// 1. `curl -k "http://127.0.0.1:8799/stand/configure?company=Провод&cashbox=Касса-1"`
/// 2. `curl -k "http://127.0.0.1:8799/stand/seed-cashiers"`
/// 3. `curl -k "http://127.0.0.1:8799/stand/seed-restricted-cashier"`
/// 4. Открыть `https://<адрес стенда>:<порт>/` — проба сама, без единого
///    клика, проходит все три шага и печатает результат и в `<pre>` на
///    странице, и в консоль браузера (`print`), и в `window.TELEPOS_PROBE_LOG`
///    (готовность — `window.TELEPOS_PROBE_DONE === true`) для внешнего
///    опроса тем же CDP-путём, каким это сделано в этой сессии.
///
/// **Какой адрес подставить в шаг 4 — зависит от машины.** На машине этой
/// сессии слушатель QUIC стенда встал только на `[::]` (IPv6-wildcard;
/// `netstat` показывал одну запись, не две, при заявленном в `wt_stand.dart`
/// `ListenScope.everywhere`), и единственным работающим адресом оказался
/// `https://[::1]:<порт>/` — IPv4-адреса (`127.0.0.1`, LAN-адрес, имя
/// `.local`) отвечали открытием страницы, но роняли `WebTransport` кадром
/// `Opening handshake failed` (в `--log-net-log` — `ERR_CONNECTION_RESET`,
/// подпись ICMP «порт недостижим»). На целевом железе, где HTTPS и QUIC
/// стоят на одних и тех же интерфейсах, ожидать этого не следует — подробный
/// разбор в `docs/internal/testing-notes.md`, раздел «Авторизация операций провода —
/// живая проверка».
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';

import 'package:telepos/domain/auth/auth_attempt.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/web/wt_auth_repository.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_session.dart';
import 'package:telepos/web/wt_session_token_store.dart';
import 'package:telepos/web/wt_terminal_repository.dart';

/// Заводится `curl .../stand/seed-cashiers`. Права по умолчанию — без строк
/// в `UserPermissions`, значит все, включая `settings.hardware`.
const _permittedName = 'Кассир С PIN';
const _permittedPin = '1234';

/// Заводится `curl .../stand/seed-restricted-cashier` — новая команда стенда
/// (см. докстринг файла и `wt_stand.dart`), у неё `settings.hardware`
/// отнято явной строкой.
const _restrictedName = 'Кассир Без Права На Оборудование';
const _restrictedPin = '9999';

/// Отдаёт лог наружу тем же путём, каким касса отдаёт браузеру порт QUIC и
/// отпечаток листа (`window.TELEPOS_WT_PORT` и соседи, `wt_session.dart`):
/// глобальная переменная документа, а не второй канал связи. CDP-опрос из
/// задачи 8 читал ровно эти два имени.
@JS('TELEPOS_PROBE_LOG')
external set _probeLogJS(JSString value);

@JS('TELEPOS_PROBE_DONE')
external set _probeDoneJS(JSBoolean value);

void main() {
  runApp(const _ProbeApp());
}

class _ProbeApp extends StatefulWidget {
  const _ProbeApp();

  @override
  State<_ProbeApp> createState() => _ProbeAppState();
}

class _ProbeAppState extends State<_ProbeApp> {
  final _log = <String>[];

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  void _say(String line) {
    _log.add(line);
    // ignore: avoid_print
    print('[проба] $line');
    _probeLogJS = _log.join('\n').toJS;
    if (mounted) setState(() {});
  }

  Future<void> _run() async {
    try {
      final link = WtLink(WtSession.openFromDocument);
      // Собственное хранилище токена, не то, что могло остаться от другой
      // пробы на той же вкладке: три шага этого файла обязаны начинаться с
      // «токена нет», иначе шаг 1 доказывал бы не то, что заявлено.
      final tokens = const SessionTokenStore()..clear();
      final dispatcher = WtDispatcher(link, tokens: tokens);
      final auth = WtAuthRepository(dispatcher);
      final terminals = WtTerminalRepository(dispatcher);

      final terminal = await terminals.self();
      _say('терминал #${terminal.id} «${terminal.name}»');

      final request = (
        terminalId: terminal.id,
        deviceClass: DeviceClass.cashDrawer,
      );

      // --- Шаг 1: без сеанса вовсе ---
      _say(
        '1) БЕЗ ВХОДА:                 ${await _tryDeviceCheck(dispatcher, request)}',
      );

      // --- Шаг 2: сеанс с правом ---
      final permitted = (await auth.watchUsers().first).where(
        (u) => u.name == _permittedName,
      );
      if (permitted.isEmpty) {
        _say('— нет кассира «$_permittedName»: curl .../stand/seed-cashiers');
      } else {
        final outcome = await auth.login(
          AuthAttempt(
            pin: _permittedPin,
            terminalId: terminal.id,
            userId: permitted.first.id,
          ),
        );
        _say('вход «$_permittedName»: ${_describeLogin(outcome, tokens)}');
      }
      _say(
        '2) С ПРАВОМ:                  ${await _tryDeviceCheck(dispatcher, request)}',
      );

      // --- Шаг 3: сеанс без права ---
      final restricted = (await auth.watchUsers().first).where(
        (u) => u.name == _restrictedName,
      );
      if (restricted.isEmpty) {
        _say(
          '— нет кассира «$_restrictedName»: '
          'curl .../stand/seed-restricted-cashier',
        );
      } else {
        final outcome = await auth.login(
          AuthAttempt(
            pin: _restrictedPin,
            terminalId: terminal.id,
            userId: restricted.first.id,
          ),
        );
        _say('вход «$_restrictedName»: ${_describeLogin(outcome, tokens)}');
      }
      _say(
        '3) БЕЗ ПРАВА (вошедшего):     ${await _tryDeviceCheck(dispatcher, request)}',
      );

      _say('ГОТОВО');
    } on Object catch (error, stack) {
      _say('ПРОБА УПАЛА: $error');
      _say('$stack');
    } finally {
      _probeDoneJS = true.toJS;
    }
  }

  String _describeLogin(AuthOutcome outcome, SessionTokenStore tokens) {
    switch (outcome) {
      case AuthSession(:final token, :final permissions, :final expiresAt):
        tokens.write(token, expiresAt);
        final has = permissions.contains('settings.hardware');
        return 'сеанс выписан, settings.hardware = $has';
      case AuthRejection(:final reason):
        return 'ОТКАЗ ВХОДА: $reason';
    }
  }

  Future<String> _tryDeviceCheck(
    WtDispatcher dispatcher,
    DeviceCheckRequest request,
  ) async {
    try {
      final outcome = await dispatcher.ask(TillOps.deviceCheck, request);
      // Успешный ответ здесь означал бы, что стенд поднят с настоящим
      // `DeviceCheck` (не так — см. докстринг файла) либо что охрана вообще
      // не сработала. Оба случая печатаются как есть, не подгоняются.
      return 'ОТВЕТ ОБРАБОТЧИКА: $outcome';
    } on WtProtocolError catch (error) {
      return 'ОТКАЗ ${error.code}: ${error.detail}';
    } on Object catch (error) {
      return 'ИСКЛЮЧЕНИЕ: $error';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Щуп: авторизация провода',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Щуп: авторизация провода')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            _log.join('\n'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          ),
        ),
      ),
    );
  }
}
