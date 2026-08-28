/// Экран-щуп: одна подписка провода, нарисованная на странице.
///
/// # Зачем он нужен, если есть `lib/web/main_web.dart`
///
/// Проверка цели всей работы звучит так: «касса изменила состояние — экран
/// обновился сам». Сегодняшняя браузерная сборка этого показать **не может**, и
/// это не догадка, а разбор её трёх маршрутов (`createSetupRouter`): заставка
/// берёт `startup.watch().first`, мастер настройки — `startup.watch().first`,
/// развилка восстановления спрашивает список копий вопросом. Все три снимают
/// подписку сразу после первого значения. Живой подписки на экране нет ни
/// одной, потому что перевод экранов на подписки — это задачи плана, которые
/// ещё не сделаны, а не свойство провода.
///
/// # Что он доказывает
///
/// Ровно то звено, которого не достаёт ни набору, ни сырой проверке протокола:
/// `WtSession` → `_WtBidiChannel` (нарезка `ReadableStream` обратно на кадры) →
/// `WtDispatcher.watch` → `WtTerminalRepository` → виджет. Всё это —
/// **производственные** классы, ни одного своего. `wt_session.dart` о себе
/// прямо пишет, что проверке набором не подлежит вовсе (браузерный прогон на
/// Windows не доходит до первого теста), — значит проверить его можно только
/// так.
///
/// # Почему здесь есть вход (с 2026-08-21)
///
/// `terminals.list` — операция с сеансом (`SessionAccess()`,
/// `lib/domain/wire/till_ops.dart`): договор авторизации закрыл её для
/// щупа так же, как для настоящего терминала. Ограничить щуп открытой
/// операцией было бы дешевле, но ни одна открытая подписка
/// (`setup.state`, `terminals.self`, `auth.users`) не меняется от команды
/// `stand/terminal`, которой щуп и проверяется, — подмена операции стёрла бы
/// саму проверку, ради которой этот файл существует. Поэтому здесь настоящий
/// вход: `WtAuthRepository` и `SessionTokenStore` — те же производственные
/// классы, что использует `lib/web/main_web.dart`, ни одной второй
/// реализации. Это к тому же честнее: щуп теперь проверяет ту же цепочку,
/// что и настоящий терминал, — с сеансом, а не в обход него.
///
/// # Запуск
///
/// ```
/// flutter build web -t test/manual/wt_watch_probe.dart --release --pwa-strategy=none
/// TELEPOS_STAND_WEB=build/web flutter test --tags manual --run-skipped \
///   test/manual/wt_stand.dart
/// ```
///
/// Затем в браузере:
///
/// 1. `curl "http://127.0.0.1:8799/stand/configure?company=Магазин&cashbox=POS"`
///    — без этого вход откажет раньше PIN («касса не настроена»).
/// 2. `curl "http://127.0.0.1:8799/stand/seed-cashiers"` — заводит кассира
///    «Кассир С PIN» (PIN 1234) и «Кассир Без PIN».
/// 3. Открыть страницу щупа, выбрать кассира и войти (PIN 1234 или без PIN).
/// 4. Дальше браузер не трогать: `curl -X POST
///    'http://127.0.0.1:8799/stand/terminal?name=Касса+у+входа'` — список на
///    экране обязан обновиться сам.
library;

import 'package:flutter/material.dart';

import 'package:telepos/domain/auth/auth_attempt.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_user.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/web/wt_auth_repository.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_session.dart';
import 'package:telepos/web/wt_session_token_store.dart';
import 'package:telepos/web/wt_terminal_repository.dart';

void main() {
  // Та же опора и тот же диспетчер, что собирает `lib/web/main_web.dart`, и
  // то же хранилище токена (`SessionTokenStore` — настоящий
  // `sessionStorage`, не подделка): `WtDispatcher` читает его при каждом
  // запросе, поэтому вход, случившийся уже после того, как диспетчер
  // построен, всё равно доедет токеном в следующей же подписке.
  final link = WtLink(WtSession.openFromDocument);
  final tokens = const SessionTokenStore();
  final dispatcher = WtDispatcher(link, tokens: tokens);
  runApp(
    _Probe(
      terminals: WtTerminalRepository(dispatcher),
      auth: WtAuthRepository(dispatcher),
      tokens: tokens,
    ),
  );
}

class _Probe extends StatefulWidget {
  const _Probe({
    required this.terminals,
    required this.auth,
    required this.tokens,
  });

  final WtTerminalRepository terminals;
  final WtAuthRepository auth;
  final SessionTokenStore tokens;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  bool _loggedIn = false;
  String? _error;

  Future<void> _login(AuthUser user, String pin) async {
    setState(() => _error = null);
    try {
      // Тот же порядок, что у настоящего входа (`LoginNotifier`): сперва
      // разрешить свой терминал (`terminals.selfEnsure`, открыта), потом
      // предъявить PIN уже с известным `terminalId` — право считается у пары
      // «кто» и «откуда».
      final terminal = await widget.terminals.self();
      final outcome = await widget.auth.login(
        AuthAttempt(pin: pin, terminalId: terminal.id, userId: user.id),
      );
      switch (outcome) {
        case AuthSession(:final token, :final expiresAt):
          widget.tokens.write(token, expiresAt);
          setState(() => _loggedIn = true);
        case AuthRejection(:final reason):
          setState(() => _error = 'отказ: $reason');
      }
    } on Object catch (error) {
      setState(() => _error = 'ошибка: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Щуп провода',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: Text(_loggedIn ? 'Щуп: terminals.list' : 'Щуп: вход'),
        ),
        body: _loggedIn
            ? _Watch(widget.terminals)
            : _Login(auth: widget.auth, error: _error, onSubmit: _login),
      ),
    );
  }
}

/// Экран входа щупа: список кассиров подпиской (`auth.users`, открыта) и PIN.
/// Не полноценный `LoginNotifier` — щупу не нужны ни блокировка попыток на
/// экране, ни повтор при устаревшем `terminalId`, только сам факт «вход
/// состоялся, токен получен».
class _Login extends StatefulWidget {
  const _Login({
    required this.auth,
    required this.error,
    required this.onSubmit,
  });

  final WtAuthRepository auth;
  final String? error;
  final Future<void> Function(AuthUser user, String pin) onSubmit;

  @override
  State<_Login> createState() => _LoginState();
}

class _LoginState extends State<_Login> {
  final _pin = TextEditingController();
  AuthUser? _selected;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AuthUser>>(
      stream: widget.auth.watchUsers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _Line('ОТКАЗ ПОДПИСКИ КАССИРОВ: ${snapshot.error}');
        }
        final users = snapshot.data;
        if (users == null) return const _Line('подписки ещё нет');
        if (users.isEmpty) {
          return const _Line(
            'кассиров нет — сперва curl .../stand/seed-cashiers',
          );
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final user in users)
                RadioListTile<AuthUser>(
                  value: user,
                  groupValue: _selected,
                  title: Text('${user.name} (${user.role})'),
                  subtitle: Text(user.hasPin ? 'PIN' : 'без PIN'),
                  onChanged: (value) => setState(() => _selected = value),
                ),
              if (_selected?.hasPin ?? false)
                TextField(
                  controller: _pin,
                  decoration: const InputDecoration(labelText: 'PIN'),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _selected == null
                    ? null
                    : () => widget.onSubmit(_selected!, _pin.text),
                child: const Text('Войти'),
              ),
              if (widget.error != null) _Line(widget.error!),
            ],
          ),
        );
      },
    );
  }
}

class _Watch extends StatelessWidget {
  const _Watch(this._terminals);

  final WtTerminalRepository _terminals;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Terminal>>(
      // Подписка заводится один раз и не снимается: `.first` здесь был бы
      // ровно тем, из-за чего щуп и понадобился.
      stream: _terminals.watchAll(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _Line('ОТКАЗ: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const _Line('подписки ещё нет');
        }
        final terminals = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Line('КАДРОВ ПОЛУЧЕНО: терминалов ${terminals.length}'),
            for (final terminal in terminals)
              _Line('#${terminal.id} ${terminal.name}'),
          ],
        );
      },
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(text, style: const TextStyle(fontSize: 22)),
  );
}
