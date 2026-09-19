/// Щуп задачи 7 («живая проверка», план «знакомство терминала с кассой»):
/// проверяет саму механику `terminals.register`/`terminals.resume` (задачи
/// 4–6) по настоящему проводу, в обход `LoginNotifier`.
///
/// # Почему в обход `LoginNotifier`, а не через него
///
/// Живая проверка этой сессии нашла: `LoginNotifier._resolveTerminalId()`
/// (`lib/presentation/controllers/auth/login_controller.dart`) зовёт
/// `_terminals.register(name: ...)` **без единого довода `code`** — тем
/// самым конструктором, у которого `code` по умолчанию `''`
/// (`terminal_repository.dart:118`). После задачи 6 этой же работы
/// (`terminals.register` требует код привязки, коммит `fb30011`) касса на
/// такой запрос всегда отвечает `WireRefusal('pairing_code_invalid', ...)`,
/// и `LoginNotifier` не различает эту причину: `catch (WireRefusal error)`
/// проверяет только `error.code == 'terminal_limit_reached'`, а
/// `pairing_code_invalid` тонет в общем `catch (_)` и превращается в
/// `error.auth_unknown` — «Касса не смогла ответить на попытку входа.
/// Попробуйте ещё раз» (`app_localizations_ru.dart:5980`). Названная причина
/// с провода до человека не доезжает вовсе, а «попробуйте ещё раз» — совет,
/// от которого ничего не изменится: без кода эта ветка не пройдёт никогда.
///
/// Итог: **ни один браузерный терминал — ни новый, ни существующий без
/// секрета — с этой сборки войти не может**. Живой прогон через настоящий
/// экран входа (headless Chrome, см. `docs/internal/testing-notes.md`) это
/// подтвердил: выбор кассира и клик «Login without PIN» кончается ровно
/// этим экраном, `terminals` на кассе остаются пустыми
/// (`GET /stand/state` → `{"terminals":[]}`) сколько угодно попыток.
///
/// Эта находка — предмет отчёта задачи 7, а не то, что чинит этот файл: он
/// **не патчит** `login_controller.dart`, только показывает, что сама
/// механика `register()`/`resume()` (задачи 4 и 5, до задачи 6) при
/// правильно переданном коде работает так, как спека и требует, — то есть
/// что дефект локализован именно в контроллере входа, не в проводе, не в
/// `TillOperations`, не в `LocalTerminalRepository`.
///
/// # Управление через `Uri.base.queryParameters`
///
/// - `?code=<код>` — обязателен для первой регистрации на пустом
///   `localStorage`; без него щуп зовёт `register(code: '')` намеренно, чтобы
///   напечатать, какую причину называет провод (тот же путь, что уже привёл
///   человека к «Попробуйте ещё раз» на настоящем экране).
/// - `?name=<имя>` — имя терминала, по умолчанию `Probe Terminal`.
/// - `?pin=<pin>&userName=<имя>` — если заданы, после регистрации/резюме щуп
///   логинится этим кассиром (`auth.login`) и сохраняет токен в
///   `SessionTokenStore` — тем же вызовом, каким это делает
///   `LoginNotifier._onSession`, только напрямую.
///
/// Секрет читается/пишется тем же `TerminalSecretStore`
/// (`lib/web/wt_terminal_secret_store.dart`), что и рабочий код — значит F5
/// той же вкладки, закрытие и повторное открытие проверяются на настоящем
/// хранилище браузера, не на подмене.
///
/// # Запуск
///
/// ```
/// flutter build web -t test/manual/wt_enrolment_probe.dart --release --pwa-strategy=none
/// TELEPOS_STAND_WEB=build/web flutter test --tags manual --run-skipped test/manual/wt_stand.dart
/// ```
///
/// Затем открывать `https://<адрес стенда>:<порт>/?code=<код от
/// /stand/invite>&name=...` — читать `window.TELEPOS_PROBE_LOG`/
/// `window.TELEPOS_PROBE_DONE` тем же CDP-путём, что и `wt_auth_probe.dart`.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';

import 'package:telepos/domain/auth/auth_attempt.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/web/wt_auth_repository.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_session.dart';
import 'package:telepos/web/wt_session_token_store.dart';
import 'package:telepos/web/wt_terminal_repository.dart';
import 'package:telepos/web/wt_terminal_secret_store.dart';

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
    print('[щуп-знакомство] $line');
    _probeLogJS = _log.join('\n').toJS;
    if (mounted) setState(() {});
  }

  Future<void> _run() async {
    try {
      final params = Uri.base.queryParameters;
      final code = params['code'] ?? '';
      final name = params['name'] ?? 'Probe Terminal';
      final pin = params['pin'];
      final userName = params['userName'];

      final link = WtLink(WtSession.openFromDocument);
      final tokens = const SessionTokenStore();
      final dispatcher = WtDispatcher(link, tokens: tokens);
      final terminals = WtTerminalRepository(dispatcher);
      const secretStore = TerminalSecretStore();

      final remembered = secretStore.read();
      if (remembered != null) {
        _say(
          'localStorage уже несёт секрет терминала #${remembered.terminalId} '
          '— пробую resume() (это и есть путь «вкладка пережила F5/закрытие»)',
        );
        try {
          final terminal = await terminals.resume(
            terminalId: remembered.terminalId,
            secret: remembered.secret,
          );
          _say(
            'resume() OK: терминал #${terminal.id} «${terminal.name}» — '
            'та же строка, новая регистрация НЕ заведена',
          );
          await _maybeLogin(dispatcher, terminal.id, pin, userName);
        } on WireRefusal catch (error) {
          _say(
            'resume() ОТКАЗ ${error.code}: ${error.message} — секрет больше '
            'не годится (терминал удалили / хранилище не оттуда / до '
            'миграции секрета). Это и есть «старое устройство без секрета» '
            '(пункт 7): дальше нужен новый код.',
          );
          secretStore.clear();
        }
        _say('ГОТОВО');
        return;
      }

      if (code.isEmpty) {
        _say('secretStore пуст, ?code= не передан — зову register(code: \'\')');
        try {
          final enrollment = await terminals.register(name: name);
          _say(
            'НЕОЖИДАННО: register() без кода прошёл — терминал '
            '#${enrollment.terminal.id}. Гейт задачи 6 не сработал.',
          );
        } on WireRefusal catch (error) {
          _say(
            'register(code: \'\') ОТКАЗ ${error.code}: ${error.message} — '
            'ровно то, что провод отвечает и настоящему экрану входа; экран '
            'этот текст человеку не показывает (см. докстринг файла).',
          );
        }
        _say('ГОТОВО');
        return;
      }

      _say('secretStore пуст, код передан — зову register(code: "$code")');
      try {
        final enrollment = await terminals.register(name: name, code: code);
        final terminal = enrollment.terminal;
        secretStore.write(terminal.id, enrollment.secret);
        _say(
          'register() OK: терминал #${terminal.id} «${terminal.name}», '
          'секрет сохранён в localStorage (${enrollment.secret.length} '
          'символ(ов))',
        );

        // Пункт 5 брифа: тот же код второй раз в том же прогоне — не должен
        // завести терминал повторно.
        try {
          final second = await terminals.register(
            name: '$name (повтор)',
            code: code,
          );
          _say(
            'НЕОЖИДАННО: тот же код второй раз тоже прошёл — терминал '
            '#${second.terminal.id}. Потраченный код завёл терминал заново.',
          );
        } on WireRefusal catch (error) {
          _say(
            'повтор того же кода ОТКАЗ ${error.code}: ${error.message} — '
            'потраченный код терминал второй раз не заводит (пункт 5 — ОК)',
          );
        }

        await _maybeLogin(dispatcher, terminal.id, pin, userName);
      } on WireRefusal catch (error) {
        _say('register(code: "$code") ОТКАЗ ${error.code}: ${error.message}');
      }

      _say('ГОТОВО');
    } on Object catch (error, stack) {
      _say('ЩУП УПАЛ: $error');
      _say('$stack');
    } finally {
      _probeDoneJS = true.toJS;
    }
  }

  Future<void> _maybeLogin(
    WtDispatcher dispatcher,
    int terminalId,
    String? pin,
    String? userName,
  ) async {
    if (pin == null || userName == null) return;
    final auth = WtAuthRepository(dispatcher);
    final users = await auth.watchUsers().first;
    final match = users.where((u) => u.name == userName);
    if (match.isEmpty) {
      _say('логин пропущен: нет кассира «$userName»');
      return;
    }
    final outcome = await auth.login(
      AuthAttempt(pin: pin, terminalId: terminalId, userId: match.first.id),
    );
    switch (outcome) {
      case AuthSession(:final token, :final expiresAt):
        const SessionTokenStore().write(token, expiresAt);
        _say(
          'auth.login OK: токен сохранён в sessionStorage, '
          'истекает $expiresAt',
        );
      case AuthRejection(:final reason):
        _say('auth.login ОТКАЗ: $reason');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Щуп: знакомство терминала с кассой',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Щуп: знакомство терминала')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            _log.join('\n'),
            style: const TextStyle(fontFamily: 'TeleposMono', fontSize: 14),
          ),
        ),
      ),
    );
  }
}
