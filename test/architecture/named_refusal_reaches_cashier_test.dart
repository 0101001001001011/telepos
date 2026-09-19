/// Названный отказ доезжает до кассира **словами словаря**, а не именем типа.
///
/// # Находка, ради которой сторож заведён (живая приёмка 2026-09-13)
///
/// Продажа в рассрочку без покупателя. Касса ответила верно:
/// `WtProtocolError(debt_customer_required: продажа в рассрочку требует
/// названного покупателя)`. Кассир прочёл: «Ошибка сохранения: minified:du».
/// Днём раньше, на поиске: `no_session` → «Ошибка поиска: minified:dl».
///
/// Причина: `safeErrorText` для всего, кроме `SqliteException`, отдавал
/// `runtimeType.toString()`, а в dart2js это имя минифицировано. Вызовов вида
/// `'error.<ключ>:${safeErrorText(e)}'` в `lib/` — больше сотни.
///
/// # Почему сторож «на экране нет `minified:`» не годится
///
/// В Dart VM имя типа читаемое: такой сторож зелен **по построению** на том
/// самом дефекте, который ловит. Поэтому главная проба утверждает не
/// отсутствие мусора, а **присутствие смысла**: строка, собранная из
/// исключения тем же путём, каким её собирают контроллеры
/// (`'$внешний:${safeErrorText(e)}'` → `ErrorLocalizer`), обязана **совпасть**
/// с фразой словаря для этого кода. На дефектном дереве в VM она равна
/// «Ошибка сохранения: WtProtocolError» — и проба красна в VM, а не только в
/// браузере.
///
/// Минификацию моделирует `_Du` — отказ с бессмысленным именем типа. Проба
/// проходит и на нём, значит путь не опирается на имя типа вовсе.
///
/// # Внешние ключи читаются из дерева
///
/// Не списком: список, переписанный руками, зеленеет навсегда в день
/// написания. Разведка обходит `lib/`, считает прочитанное и краснеет, если
/// нашла меньше порога — сторож, ничего не нашедший, иначе был бы зелён по
/// недосмотру.
@Tags(['architecture'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/common.dart' show SqliteException;
import 'package:telepos/core/errors/named_refusal.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/domain/wire/pay_ops.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/sale/sale_refusal_keys.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_payment_service.dart';

import '../fixtures/pin_hash_fixture.dart';
import '../web/support/fake_dispatcher.dart';
import 'support/refusal_code_scan.dart';

/// Отказ с именем типа, которое ничего не значит, — то, во что dart2js
/// превращает всякий класс.
final class _Du implements NamedRefusal {
  const _Du(this.code, this.reasonText);

  @override
  final String code;

  @override
  final String reasonText;
}

/// Сессия, которую рвёт браузер: открытие потока бросает исключение без
/// кода — то, чем WebTransport отвечает на ушедшую сеть.
final class _BrokenOpen implements WtStreams {
  @override
  Future<WtStream> openStream() async =>
      throw Exception('WebTransportError: session is closed');

  @override
  Future<void> get closed async {}

  @override
  Future<void> close() async {}
}

/// Четыре формы одного отказа: как бросает касса, как бросает провод, как
/// провод бросает потерю сеанса, и как выглядит любой из них после
/// минификации.
///
/// [SessionLost] добавлен 2026-09-13: живая приёмка — истёкший сеанс на
/// `pay.certificate` показал кассиру «Ошибка сохранения: неизвестная
/// причина», потому что тип не нёс кода.
List<Object> _refusalsOf(String code, String reason) => [
  WireRefusal(code, reason),
  WtProtocolError(code, reason),
  SessionLost(reason, code: code),
  _Du(code, reason),
];

final _sitePattern = RegExp(r"'(error\.[a-z_]+):\$\{safeErrorText\(");

typedef _SiteScan = ({Set<String> outerKeys, int sites, int files, int read});

_SiteScan _scanSites() {
  final outer = <String>{};
  var sites = 0;
  final files = <String>{};
  var read = 0;
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    read++;
    for (final m in _sitePattern.allMatches(f.readAsStringSync())) {
      outer.add(m.group(1)!);
      sites++;
      files.add(f.path);
    }
  }
  return (outerKeys: outer, sites: sites, files: files.length, read: read);
}

const _locales = <String>['ru', 'kk', 'ky', 'uz', 'en'];

Future<({BuildContext ctx, AppLocalizations l10n})> _pumpLocale(
  WidgetTester tester,
  String code,
) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(code),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (c) {
          ctx = c;
          return const SizedBox();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (ctx: ctx, l10n: AppLocalizations.of(ctx)!);
}

/// Что увидит кассир, если контроллер написал `'$outer:${safeErrorText(e)}'`.
String _shown(BuildContext ctx, String outer, Object error) =>
    ErrorLocalizer.localize(ctx, '$outer:${safeErrorText(error)}');

void main() {
  final scan = _scanSites();

  test('разведка нашла места вызова — иначе сторож смотрит в пустоту', () {
    // Порог, а не точное число: места заводят и снимают. На 2026-09-13
    // найдено 119 мест в 26 файлах, 20 внешних ключей.
    expect(
      scan.read,
      greaterThan(500),
      reason: 'обход `lib/` прочёл ${scan.read} файлов — смотрит не туда',
    );
    expect(
      scan.sites,
      greaterThanOrEqualTo(100),
      reason:
          'найдено ${scan.sites} мест в ${scan.files} файлах — выражение '
          'разведки перестало находить вызовы',
    );
    expect(
      scan.outerKeys,
      containsAll(<String>[
        'error.save_failed',
        'error.search_failed',
        'error.load_failed',
        'error.unknown',
      ]),
    );
  });

  // ── Коды провода без перевода (2026-09-13) ─────────────────────────────
  //
  // Пробы выше гоняли через `safeErrorText` только коды, **уже** стоящие в
  // карте, — и зеленели на коде, которого в карте нет: он честно становился
  // «неизвестной причиной», и это считалось правильным исходом. Так
  // `no_session` на поиске и доехал до кассира «неизвестной причиной (код
  // no_session)». Разведка ниже собирает коды из всего `lib/` и требует ключ
  // словаря **каждому**; разбор границы — `support/refusal_code_scan.dart`.
  final codeScan = scanRefusalCodes();

  test('разведка кодов провода прочла дерево и каждый довод', () {
    // Порог, а не точное число. На 2026-09-13: 1300+ файлов, 190+ мест,
    // 130+ кодов.
    expect(codeScan.filesRead, greaterThan(500));
    expect(codeScan.sites, greaterThanOrEqualTo(150));
    expect(
      codeScan.codes,
      containsAll(<String>[
        // по одному из каждого источника: литерал браузера, константа
        // сторожа, литерал провода кассы, реестр, константа возврата,
        // реестр видов оплаты, реестр провайдера QR
        'no_session',
        'unauthorized',
        'handler_failed',
        'certificate_rate_limited',
        'receipt_already_refunded',
        'kind_system_immutable',
        'qr_network',
      ]),
    );
    expect(
      {
        'имя не привязалось': codeScan.unresolved,
        'довод не разобран': codeScan.unparsed,
        'исключение проброса ничего не пропускает': codeScan.unusedPassThrough,
      },
      {
        'имя не привязалось': <String>[],
        'довод не разобран': <String>[],
        'исключение проброса ничего не пропускает': <String>[],
      },
    );
  });

  test('у каждого кода, который провод или касса могут отдать, есть ключ '
      'словаря', () {
    final missing =
        codeScan.codes.where((c) => !saleRefusalErrorKeys.containsKey(c))
            .toList()
          ..sort();
    expect(
      missing,
      isEmpty,
      reason:
          'Без ключа ${missing.length} из ${codeScan.codes.length} кодов — '
          'кассир увидит «неизвестная причина (код …)». Заведите строку в '
          '`sale_refusal_keys.dart`, ветку в `ErrorLocalizer` и фразу во всех '
          'пяти `assets/i18n/intl_*.arb`:\n'
          '${missing.map((c) => '$c ← ${codeScan.origins[c]!.first}').join('\n')}',
    );
  });

  testWidgets(
    'названный отказ через safeErrorText — фраза словаря, а не имя типа',
    (tester) async {
      const reason = 'Кымыз Дүкен №2';
      final wrong = <String>[];
      for (final locale in _locales) {
        final stand = await _pumpLocale(tester, locale);
        for (final code in saleRefusalErrorKeys.keys) {
          // Эталон — тот путь, который уже доказан сторожем словаря.
          final expected = ErrorLocalizer.localize(
            stand.ctx,
            saleRefusalErrorKeyOf(WireRefusal(code, reason)),
          );
          for (final error in _refusalsOf(code, reason)) {
            for (final outer in scan.outerKeys) {
              final shown = _shown(stand.ctx, outer, error);
              if (shown != expected) {
                wrong.add(
                  '$locale $outer ${error.runtimeType}($code): '
                  '"$shown" ≠ "$expected"',
                );
              }
            }
          }
        }
      }
      expect(
        wrong.take(20).toList(),
        isEmpty,
        reason:
            'Названный отказ, прошедший через `safeErrorText`, не стал фразой '
            'словаря. В браузере это «Ошибка сохранения: minified:du». '
            'Всего расхождений: ${wrong.length}.',
      );
    },
  );

  testWidgets('два измеренных случая — дословно', (tester) async {
    final stand = await _pumpLocale(tester, 'ru');

    // Рассрочка без покупателя, экран оплаты.
    final debt = _shown(
      stand.ctx,
      'error.save_failed',
      const WtProtocolError(
        'debt_customer_required',
        'продажа в рассрочку требует названного покупателя',
      ),
    );
    expect(debt, stand.l10n.errorDebtCustomerRequired);

    // Поиск при обрыве. До 2026-09-13 здесь стояло «кода в словаре нет —
    // честно „неизвестная причина“», и проба утверждала именно это; кассир
    // при обрыве связи не знал, что делать. Теперь — фраза словаря.
    const lostDetail = 'сессия не поднялась';
    final search = _shown(
      stand.ctx,
      'error.search_failed',
      const WtProtocolError('no_session', lostDetail),
    );
    expect(search, stand.l10n.errorConnectionLost);
    expect(search, isNot(contains(lostDetail)));
  });

  testWidgets(
    'кода нет в словаре — «неизвестная причина» с кодом, а не правдоподобная '
    'фраза',
    (tester) async {
      const code = 'zz_never_named';
      const plausible = 'Касса не ответила. Проверьте связь и повторите.';
      expect(saleRefusalErrorKeys.containsKey(code), isFalse);

      final wrong = <String>[];
      for (final locale in _locales) {
        final stand = await _pumpLocale(tester, locale);
        // Все фразы словаря: неизвестный код не имеет права совпасть ни с
        // одной — это и была бы выдуманная причина.
        final dictionary = {
          for (final c in saleRefusalErrorKeys.keys)
            ErrorLocalizer.localize(
              stand.ctx,
              saleRefusalErrorKeyOf(WireRefusal(c, plausible)),
            ),
        };
        final unknown = stand.l10n.errorRefusalUnknownCode(code);
        for (final error in _refusalsOf(code, plausible)) {
          for (final outer in scan.outerKeys) {
            final shown = _shown(stand.ctx, outer, error);
            final problems = [
              if (!shown.contains(unknown)) 'нет «неизвестная причина (код)»',
              if (shown.contains(plausible)) 'показан текст неизвестного кода',
              if (dictionary.contains(shown)) 'совпало с фразой словаря',
              if (shown.startsWith('error.')) 'на экране ключ',
            ];
            if (problems.isNotEmpty) {
              wrong.add('$locale $outer ${error.runtimeType}: "$shown" — '
                  '${problems.join(', ')}');
            }
          }
        }
      }
      expect(wrong.take(20).toList(), isEmpty,
          reason: 'всего: ${wrong.length}');
    },
  );

  // ── Живая приёмка 2026-09-13 23:04:56 ──────────────────────────────────
  //
  // Вкладка простояла час на диалоге оплаты; кассир нажал «Проверить» у
  // сертификата PS-0003 (`pay.certificate`). Касса: `wire.denied`,
  // `unauthorized`. Кассир: снекбар «Ошибка сохранения: неизвестная
  // причина», и только потом — экран входа. Путь: `WtDispatcher._errorFor`
  // → `SessionLost` (без кода) → `PaymentController._errorKeyOf`
  // (`'error.save_failed:${safeErrorText(e)}'`) → имя типа, минифицированное
  // в dart2js, → «неизвестная причина».
  testWidgets(
    'истёкший сеанс на pay.certificate — «Сеанс истёк», не «неизвестная '
    'причина»',
    (tester) async {
      const frame =
          '{"ok":false,"code":"unauthorized",'
          '"detail":"pay.certificate: сеанс неизвестен или истёк"}';
      Object? caught;
      try {
        await WtPaymentService(answering(frame)).findCertificate(
          'PS-0003',
          pin: '1234',
        );
      } on Object catch (e) {
        caught = e;
      }
      expect(caught, isA<SessionLost>(), reason: 'экран входа по-прежнему '
          'ловит тип — он не должен смениться');

      final wrong = <String>[];
      for (final locale in _locales) {
        final stand = await _pumpLocale(tester, locale);
        final expired = stand.l10n.errorSessionExpired;
        final unknownReason = stand.l10n.errorReasonUnknown;
        final unknownCode = stand.l10n.errorRefusalUnknownCode('unauthorized');
        // Экран оплаты — ровно та строка, что собирает
        // `PaymentController._errorKeyOf` для не-`WireRefusal`; поиск,
        // корзина и прочие — каждый внешний ключ, найденный в `lib/`.
        for (final outer in {'error.save_failed', ...scan.outerKeys}) {
          final shown = _shown(stand.ctx, outer, caught!);
          if (shown != expired ||
              shown.contains(unknownReason) ||
              shown.contains(unknownCode)) {
            wrong.add('$locale $outer: "$shown" ≠ "$expired"');
          }
        }
      }
      expect(wrong.take(20).toList(), isEmpty,
          reason: 'всего: ${wrong.length}');
    },
  );

  testWidgets('терминал сменён и терминал не заведён — свои фразы, не общая',
      (tester) async {
    final stand = await _pumpLocale(tester, 'ru');
    for (final (frame, expected) in [
      (
        '{"ok":false,"code":"terminal_changed","detail":"sale.search: место"}',
        stand.l10n.errorTerminalChanged,
      ),
      (
        '{"ok":false,"code":"unauthorized","detail":"sale.search: истёк"}',
        stand.l10n.errorSessionExpired,
      ),
    ]) {
      Object? caught;
      try {
        await answering(frame).ask(PayOps.accounts, null);
      } on Object catch (e) {
        caught = e;
      }
      expect(caught, isA<SessionLost>());
      expect(_shown(stand.ctx, 'error.search_failed', caught!), expected);
    }
  });

  testWidgets('сырой обрыв браузера на вопросе — «Связь с кассой потеряна»', (
    tester,
  ) async {
    final stand = await _pumpLocale(tester, 'ru');
    Object? caught;
    try {
      await WtDispatcher(_BrokenOpen()).ask(PayOps.accounts, null);
    } on Object catch (e) {
      caught = e;
    }
    expect(
      _shown(stand.ctx, 'error.search_failed', caught!),
      stand.l10n.errorConnectionLost,
    );
  });

  testWidgets('имя типа, которое не имя, — «неизвестная причина», не мусор', (
    tester,
  ) async {
    expect(readableTypeName('minified:du'), unnamedErrorText);
    expect(
      readableTypeName('StateError'),
      'StateError',
      reason: 'в VM и на кассе род ошибки по-прежнему назван',
    );

    final stand = await _pumpLocale(tester, 'ru');
    final shown = ErrorLocalizer.localize(
      stand.ctx,
      'error.search_failed:${readableTypeName('minified:dl')}',
    );
    expect(
      shown,
      stand.l10n.errorSearchFailed(stand.l10n.errorReasonUnknown),
    );
    expect(shown, isNot(contains('minified')));
  });

  test('safeErrorText берёт имя типа только через readableTypeName', () {
    // Предел VM, названный вслух: имя типа здесь всегда читаемое, и пробой
    // исполнения нельзя доказать, что `safeErrorText` зовёт
    // `readableTypeName`. Поэтому эта половина — текстовая, и прочитанное
    // считается: `runtimeType` встречается в теле ровно один раз, и это
    // довод `readableTypeName`.
    final source = File('lib/core/errors/safe_error_text.dart')
        .readAsStringSync();
    final code = source
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect('runtimeType'.allMatches(code).length, 1);
    expect(code, contains('readableTypeName(error.runtimeType.toString())'));
  });

  testWidgets('внутренности базы наружу не едут — ни одним из путей', (
    tester,
  ) async {
    final stand = await _pumpLocale(tester, 'ru');
    final sqlite = SqliteException(
      2067,
      'UNIQUE constraint failed: users.password_enc',
      'columns password_enc are not unique',
      'UPDATE users SET password_enc = ? WHERE id = ?',
      [testPbkdf2PinHash, 1],
      'executing a prepared statement',
    );

    final leaks = <String>[];
    void check(String what, Object error) {
      for (final outer in scan.outerKeys) {
        final shown = _shown(stand.ctx, outer, error);
        if (shown.contains(testPbkdf2PinHash) ||
            shown.contains('UPDATE users')) {
          leaks.add('$what / $outer: "$shown"');
        }
      }
    }

    check('SqliteException', sqlite);
    // Код не той формы не едет: его значение не проверено ничем.
    check('код не той формы', _Du('x; hash=$testPbkdf2PinHash', 'причина'));
    // Неизвестный код с текстом, в котором нутро: показывается только код.
    check(
      'неизвестный код',
      WtProtocolError('handler_failed', 'statement: $testPbkdf2PinHash'),
    );
    // Известный код «без текста»: текст отказа на экран не попадает.
    check(
      'известный код без текста',
      WtProtocolError('debt_customer_required', testPbkdf2PinHash),
    );
    expect(leaks, isEmpty);

    expect(
      safeErrorText(_Du('x; hash=$testPbkdf2PinHash', 'причина')),
      unnamedErrorText,
      reason: 'код не той формы не попадает даже в журнал',
    );
  });
}
