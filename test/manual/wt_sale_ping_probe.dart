/// Прямой клиент провода для задачи 1 плана «Продажа с браузерного терминала»
/// (спека 2026-09-06): измеряет цену одного круга `sale.ping` на настоящем
/// QUIC/WebTransport, без единого экрана приложения.
///
/// # Что здесь измеряется и чем
///
/// Сто последовательных вызовов `SaleOps.salePing`
/// (`lib/domain/wire/sale_ops.dart`) через `WtDispatcher.ask` — тот же
/// вызов, каким в итоге будет кормиться сканирование на экране продажи.
/// Каждый круг обёрнут в `Stopwatch`; по итоговому списку — медиана и p95.
/// Штрихкод — заведомо отсутствующий (`0000000000`): цель замера — стоимость
/// самого круга по проводу (сериализация кадра, QUIC, разбор ответа), а не
/// скорость конкретного запроса к базе — обработчик
/// (`till_operations.dart`) делает один и тот же один запрос
/// `productInfoDao.findByBarcode` независимо от того, нашёлся товар или нет.
///
/// # Почему это не браузер приложения и не тест на VM
///
/// Тот же довод, что и у `wt_auth_probe.dart` (задача 8): настоящее
/// WebTransport-соединение существует только в браузере
/// (`lib/web/wt_session.dart`, `dart:js_interop`), второй реализации на VM
/// нет и быть не может. Проба — не своя `MaterialApp` ради экрана, а прямой
/// вызов провода, идущий по тому же пути и тем же приёмом обхода
/// недоверенного корня (headless Chrome + CDP), что и предыдущие пробы этого
/// каталога — рецепт в докстринге `wt_auth_probe.dart` и в
/// `docs/internal/testing-notes.md`.
///
/// # Запуск
///
/// ```
/// flutter build web -t test/manual/wt_sale_ping_probe.dart --release --pwa-strategy=none
/// TELEPOS_STAND_WEB=build/web flutter test --tags manual --run-skipped \
///   test/manual/wt_stand.dart
/// ```
///
/// Затем: `stand/configure`, `stand/seed-cashiers`, открыть страницу стенда
/// тем же способом, что и другие пробы каталога (headless Chrome + CDP,
/// адрес зависит от машины — см. `docs/internal/testing-notes.md`). Готовность
/// — `window.TELEPOS_PROBE_DONE === true`, результат — `window.TELEPOS_PROBE_LOG`.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';

import 'package:telepos/domain/auth/auth_attempt.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/wire/sale_ops.dart';
import 'package:telepos/web/wt_auth_repository.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_session.dart';
import 'package:telepos/web/wt_session_token_store.dart';
import 'package:telepos/web/wt_terminal_repository.dart';

/// Заводится `curl .../stand/seed-cashiers`. Права по умолчанию — без строк
/// в `UserPermissions`, значит все, включая право на продажу.
const _cashierName = 'Кассир С PIN';
const _cashierPin = '1234';

/// Штрихкод, заведомо отсутствующий в пустой базе стенда.
const _barcode = '0000000000';

const _rounds = 100;

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
      final tokens = const SessionTokenStore()..clear();
      final dispatcher = WtDispatcher(link, tokens: tokens);
      final auth = WtAuthRepository(dispatcher);
      final terminals = WtTerminalRepository(dispatcher);

      final terminal = await terminals.self();
      _say('терминал #${terminal.id} «${terminal.name}»');

      final cashiers = (await auth.watchUsers().first).where(
        (u) => u.name == _cashierName,
      );
      if (cashiers.isEmpty) {
        _say(
          'ОШИБКА: нет кассира «$_cashierName» — curl .../stand/seed-cashiers',
        );
        return;
      }

      final outcome = await auth.login(
        AuthAttempt(
          pin: _cashierPin,
          terminalId: terminal.id,
          userId: cashiers.first.id,
        ),
      );
      switch (outcome) {
        case AuthSession(:final token, :final expiresAt):
          tokens.write(token, expiresAt);
          _say('вход «$_cashierName»: сеанс выписан');
        case AuthRejection(:final reason):
          _say('ОШИБКА ВХОДА: $reason');
          return;
      }

      // --- Разогрев: первый круг платит за то, чего не платят следующие
      // (открытие потока QUIC внутри уже поднятой сессии, JIT первого
      // вызова кодировщика) — считается отдельно, не в выборку.
      final warmup = Stopwatch()..start();
      await dispatcher.ask(SaleOps.salePing, _barcode);
      warmup.stop();
      _say('разогрев (не в выборке): ${warmup.elapsedMicroseconds / 1000} мс');

      final samples = <int>[];
      for (var i = 0; i < _rounds; i++) {
        final sw = Stopwatch()..start();
        await dispatcher.ask(SaleOps.salePing, _barcode);
        sw.stop();
        samples.add(sw.elapsedMicroseconds);
      }

      samples.sort();
      final medianUs = _percentileUs(samples, 0.5);
      final p95Us = _percentileUs(samples, 0.95);
      final minUs = samples.first;
      final maxUs = samples.last;

      _say('кругов: $_rounds');
      _say('медиана: ${medianUs / 1000} мс');
      _say('p95: ${p95Us / 1000} мс');
      _say('минимум: ${minUs / 1000} мс');
      _say('максимум: ${maxUs / 1000} мс');
      _say('ГОТОВО');
    } on Object catch (error, stack) {
      _say('ПРОБА УПАЛА: $error');
      _say('$stack');
    } finally {
      _probeDoneJS = true.toJS;
    }
  }

  /// [p] в диапазоне `[0, 1]`. `samples` уже отсортирован по возрастанию.
  int _percentileUs(List<int> samples, double p) {
    final index = (samples.length * p).floor().clamp(0, samples.length - 1);
    return samples[index];
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Щуп: цена круга sale.ping',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Щуп: цена круга sale.ping')),
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
