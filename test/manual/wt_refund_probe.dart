/// Живая проверка шести операций возврата по настоящему QUIC/WebTransport —
/// задача «стенд без возвратов» (2026-09-06).
///
/// # Зачем эта проба существует
///
/// Охранная правка задачи 19 («шесть операций возврата на проводе») была
/// проверена **только набором**: стенд живой проверки собирал `ApiServer`
/// без довода `refund:`, и все шесть операций отвечали `no_refund_service` —
/// то есть на стенде их не существовало вовсе, молча. Правило проекта
/// «живые прогоны обязательны» при этом считалось выполненным.
///
/// Проба — то, чем «стенд собирает возврат» перестаёт быть утверждением:
/// каждая из шести операций зовётся по проводу и печатает **свой** ответ.
/// Именно свой: `no_refund_service` — отказ **сборки кассы**, а
/// `refund_receipt_not_found`, `refund_empty`, `shift_not_open` — ответы
/// самого `LocalRefundService`. Отличить одно от другого можно только по
/// коду, и проба печатает код всегда.
///
/// # Почему это браузер, а не тест на VM
///
/// Тот же довод, что у `wt_auth_probe.dart` и `wt_sale_ping_probe.dart`:
/// настоящая сессия WebTransport существует только в браузере
/// (`lib/web/wt_session.dart`, `dart:js_interop`), второй реализации на VM
/// нет и быть не может. Набор проверяет обработчики над `QuicServer` в том
/// же процессе; здесь между терминалом и кассой настоящий QUIC.
///
/// # Что именно проверяется — и в каком порядке
///
/// Порядок не косметический: он ведёт черновик через все состояния, в
/// которых операции имеют смысл.
///
/// 1. `refund.view` — **подписка**, заводится первой и держится до конца:
///    каждое изменение обязано приехать в неё само, а не по запросу. Число
///    пришедших снимков печатается в конце — подписка, не получившая ни
///    одного обновления, отличается от рабочей только этим числом.
/// 2. `refund.loadReceipt` на заведомо отсутствующий чек — ждём **названный**
///    отказ `refund_receipt_not_found`. Это ответ по существу: касса сходила
///    в `SaleDao.findByKey` и не нашла.
/// 3. `refund.startWithoutReceipt` — черновик заводится; в ответе появляется
///    `draftNo`.
/// 4. `refund.addProduct` — товар из каталога (`stand/seed-product`).
/// 5. `refund.setLine` — количество той же строки меняется.
/// 6. `refund.complete` — деньги и товар. Без открытой смены
///    (`stand/open-shift`) касса откажет `shift_not_open` — тоже ответ, и
///    проба его так и назовёт, а не выдаст за успех.
///
/// # Запуск
///
/// ```
/// flutter build web -t test/manual/wt_refund_probe.dart --release --pwa-strategy=none
/// PATH=<каталог с rk_quic.dll, rk_pki.dll, sqlite3.dll>;$PATH \
/// TELEPOS_STAND_WEB=build/web TELEPOS_STAND_PORT=8790 \
///   flutter test --tags manual --run-skipped test/manual/wt_stand.dart
/// ```
///
/// Затем на петле управления стенда:
///
/// ```
/// curl "http://127.0.0.1:8799/stand/configure?company=Магазин&cashbox=POS"
/// curl "http://127.0.0.1:8799/stand/seed-cashiers"
/// curl "http://127.0.0.1:8799/stand/seed-product"
/// curl "http://127.0.0.1:8799/stand/open-shift"
/// ```
///
/// и открыть страницу стенда тем же приёмом обхода недоверенного корня
/// (headless Chrome + CDP), что и остальные пробы каталога — рецепт в
/// `docs/internal/testing-notes.md`. Готовность — `window.TELEPOS_PROBE_DONE
/// === true`, протокол обмена — `window.TELEPOS_PROBE_LOG`.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:telepos/domain/auth/auth_attempt.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/wire/refund_ops.dart';
import 'package:telepos/web/wt_auth_repository.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_session.dart';
import 'package:telepos/web/wt_session_token_store.dart';
import 'package:telepos/web/wt_terminal_repository.dart';

/// Заводится `curl .../stand/seed-cashiers`; права — полный набор, включая
/// `op.refund` и `op.refundWithoutReceipt`, без которых сторож провода не
/// пустил бы ни одну из шести (`refund_ops.dart`, `SessionAccess.needs`).
const _cashierName = 'Кассир С PIN';
const _cashierPin = '1234';

/// Товар из `curl .../stand/seed-product` — умолчания той команды.
const _productUcode = 100;

/// Чек, которого на стенде заведомо нет: база в памяти, продаж в ней не
/// делали. Отказ по нему — доказательство того, что касса **искала**.
const _missingReceiptNo = 999999;
const _missingReceiptPos = 1;

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

  /// Один шаг обмена: зовёт операцию и печатает **что именно** ответила
  /// касса — значение или названный отказ.
  ///
  /// Отказ здесь не провал пробы: половина шагов проверяет ровно его.
  /// Провалом считается только `no_refund_service` — единственный ответ,
  /// означающий «этой кассе возврат не собрали», — и он назван отдельной
  /// строкой, чтобы его нельзя было принять за рабочий отказ.
  Future<T?> _step<T>(
    String title,
    Future<T> Function() call, {
    required String Function(T) describe,
  }) async {
    try {
      final value = await call();
      _say('$title → ОТВЕТ ${describe(value)}');
      return value;
    } on WtProtocolError catch (error) {
      if (error.code == 'no_refund_service') {
        _say(
          '$title → СТЕНД БЕЗ ВОЗВРАТА: ${error.code} (${error.detail}). '
          'Это отказ СБОРКИ кассы, а не ответ возврата — ApiServer подняли '
          'без довода refund:.',
        );
      } else {
        _say('$title → ОТКАЗ ${error.code}: ${error.detail}');
      }
      return null;
    }
  }

  Future<void> _run() async {
    var updates = 0;
    StreamSubscription<RefundView>? watching;
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

      // ── 1. refund.view — подписка, заводится первой и живёт до конца ──
      final firstSnapshot = Completer<RefundView>();
      watching = dispatcher
          .watch(RefundOps.view, null)
          .listen(
            (view) {
              updates++;
              if (!firstSnapshot.isCompleted) firstSnapshot.complete(view);
              _say(
                '  refund.view #$updates → черновик ${view.draftNo ?? "нет"}, '
                'версия ${view.version}, строк ${view.lines.length}',
              );
            },
            onError: (Object error) {
              _say('  refund.view → ОШИБКА ПОДПИСКИ $error');
              if (!firstSnapshot.isCompleted)
                firstSnapshot.completeError(error);
            },
          );

      final view = await firstSnapshot.future.timeout(
        const Duration(seconds: 20),
      );
      _say(
        '1/6 refund.view → ОТВЕТ первый снимок: место ${view.terminalId}, '
        'версия ${view.version}, черновик ${view.draftNo ?? "нет"}',
      );

      // ── 2. refund.loadReceipt по чеку, которого нет ───────────────────
      await _step<RefundView>(
        '2/6 refund.loadReceipt (чек $_missingReceiptNo — заведомо нет)',
        () => dispatcher.ask(
          RefundOps.loadReceipt,
          ReceiptKey(
            receiptNo: _missingReceiptNo,
            posId: _missingReceiptPos,
            meta: const CartCommandMeta(
              key: 'probe-load',
              baseVersion: 0,
              receiptNo: null,
            ),
          ),
        ),
        describe: (v) => 'черновик ${v.draftNo}, строк ${v.lines.length}',
      );

      // ── 3. refund.startWithoutReceipt ─────────────────────────────────
      final started = await _step<RefundView>(
        '3/6 refund.startWithoutReceipt',
        () => dispatcher.ask(
          RefundOps.startWithoutReceipt,
          const CartCommandMeta(
            key: 'probe-start',
            baseVersion: 0,
            receiptNo: null,
          ),
        ),
        describe: (v) => 'черновик ${v.draftNo}, версия ${v.version}',
      );
      if (started == null) return;

      // ── 4. refund.addProduct ──────────────────────────────────────────
      final filled = await _step<RefundView>(
        '4/6 refund.addProduct (товар $_productUcode, 2 шт)',
        () => dispatcher.ask(
          RefundOps.addProduct,
          RefundLineRequest(
            productId: _productUcode,
            quantity: Decimal.fromInt(2),
            meta: CartCommandMeta(
              key: 'probe-add',
              baseVersion: started.version,
              receiptNo: started.draftNo,
            ),
          ),
        ),
        describe: (v) =>
            'версия ${v.version}, строк ${v.lines.length}, '
            'первая ${v.lines.isEmpty ? "—" : "${v.lines.first.id} "
                      "×${v.lines.first.quantity} по ${v.lines.first.price}"}',
      );
      if (filled == null) return;

      // ── 5. refund.setLine ─────────────────────────────────────────────
      final trimmed = await _step<RefundView>(
        '5/6 refund.setLine (той же строке 1 шт)',
        () => dispatcher.ask(
          RefundOps.setLine,
          RefundLineQuantity(
            lineId: filled.lines.first.id,
            quantity: Decimal.one,
            meta: CartCommandMeta(
              key: 'probe-set',
              baseVersion: filled.version,
              receiptNo: filled.draftNo,
            ),
          ),
        ),
        describe: (v) =>
            'версия ${v.version}, строк ${v.lines.length}, '
            'первая ×${v.lines.isEmpty ? "—" : v.lines.first.quantity}',
      );

      // ── 6. refund.complete ────────────────────────────────────────────
      final base = trimmed ?? filled;
      await _step<RefundOutcome>(
        '6/6 refund.complete',
        () => dispatcher.ask(
          RefundOps.complete,
          CartCommandMeta(
            key: 'probe-complete',
            baseVersion: base.version,
            receiptNo: base.draftNo,
          ),
        ),
        describe: (o) =>
            'возврат #${o.refundLocalId} на ${o.amount}, '
            'строк ${o.lineCount}, платежей ${o.paymentCount}',
      );

      // Подписка обязана была увидеть изменения сама. Число печатается
      // всегда: единица означала бы «пришёл только первый снимок», то есть
      // подписку, которая на самом деле не подписка.
      _say('refund.view получила снимков: $updates');
      _say('ГОТОВО');
    } on Object catch (error, stack) {
      _say('ПРОБА УПАЛА: $error');
      _say('$stack');
    } finally {
      await watching?.cancel();
      _probeDoneJS = true.toJS;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Щуп: шесть операций возврата',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Щуп: шесть операций возврата')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: SelectableText(
              _log.join('\n'),
              style: const TextStyle(fontFamily: 'TeleposMono', fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}
