/// Классификация отказов WebKassa: **что встаёт в очередь, а что зовёт
/// человека** — по одной пробе на ветку, через эмулятор на настоящем сокете.
///
/// # Правило, которое здесь проверяется
///
/// Повторимо то, что **лечится временем без участия человека**: связь
/// порвалась, оператор или то, что стоит перед ним, не ответил, ответ
/// потерялся по дороге. Повтор такого документа безопасен — он уходит тем же
/// `ExternalCheckNumber`, и оператор, успевший его принять, отвечает кодом 14.
///
/// Неповторимо то, что **повторится детерминированно**: запрос не собирается,
/// TLS не сходится (чужая схема, часы кассы, сертификат), оператор отверг
/// документ по существу, сломался код кассы. Такой отказ в `pending` —
/// обещание лечения, которого нет: строка не видна ни одному экрану и через
/// 72 часа спишется чужой причиной «превышено автономное окно».
///
/// Таблица кодов живёт одним местом — `FiscalErrorCode.isTransient`
/// (`lib/domain/fiscal/fiscal_models.dart`); последняя проба закрепляет её.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/datasources/remote/webkassa_api_client.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';

import 'support/webkassa_rig.dart';

WebKassaRig? _current;
WebKassaRig get rig => _current!;
set rig(WebKassaRig value) => _current = value;

void main() {
  // Пробам без сокета стенд не нужен — и поднимать его им незачем.
  tearDown(() async {
    await _current?.stop();
    _current = null;
  });

  Future<FiscalResult> sellThroughQueue(String key) =>
      rig.queued.fiscalizeSale(rigSale(key));

  group('повторимо: в очередь', () {
    test('HTTP 503 со страницей HTML — оператор недоступен, чек в очереди', () async {
      rig = await startWebKassaRig();
      await rig.warm();
      await rig.console('/_emul/http', {'status': 503, 'count': 1});

      final direct = await rig.provider.fiscalizeSale(rigSale('http-503-direct'));
      // ignore: avoid_print
      print(
        'HTTP 503 напрямую: ${direct.errorCode.name} raw=${direct.rawErrorCode} '
        '«${direct.errorMessage}»',
      );

      await rig.console('/_emul/http', {'status': 503, 'count': 1});
      final r = await sellThroughQueue('http-503');

      expect(direct.errorCode.name, 'operatorUnavailable');
      expect(direct.rawErrorCode, 503, reason: 'человеку нужен статус, а не −5');
      expect(
        r.queued,
        isTrue,
        reason:
            '503 без кода оператора — не отказ по существу; сейчас '
            '${r.errorCode.name}:${r.rawErrorCode}',
      );
      expect(await rig.store.pendingCount(), 1);
    });

    test('HTTP 429 — оператор просит подождать, чек в очереди', () async {
      rig = await startWebKassaRig();
      await rig.warm();
      await rig.console('/_emul/http', {
        'status': 429,
        'count': 1,
        'body': 'Too Many Requests',
      });

      final r = await sellThroughQueue('http-429');

      expect(r.queued, isTrue, reason: '${r.errorCode.name}:${r.rawErrorCode}');
      expect(await rig.store.pendingCount(), 1);
    });

    test('сокет закрыт без ответа — в очередь', () async {
      rig = await startWebKassaRig();
      await rig.warm();
      await rig.console('/_emul/kill', {'count': 1});

      final direct = await rig.provider.fiscalizeSale(rigSale('kill-direct'));
      // ignore: avoid_print
      print(
        'обрыв напрямую: ${direct.errorCode.name} raw=${direct.rawErrorCode} '
        '«${direct.errorMessage}»',
      );
      expect(direct.success, isFalse);

      await rig.console('/_emul/kill', {'count': 1});
      final r = await sellThroughQueue('kill');
      expect(r.queued, isTrue);
      expect(await rig.store.pendingCount(), 1);
    });

    test('ответ не JSON при HTTP 200 — ответ потерян, в очередь', () async {
      rig = await startWebKassaRig();
      await rig.warm();
      await rig.console('/_emul/malformed', {'count': 1});

      final r = await sellThroughQueue('malformed');
      expect(r.queued, isTrue);
      expect(await rig.store.pendingCount(), 1);
    });

    test('молчание дольше тайм-аута клиента — в очередь', () async {
      rig = await startWebKassaRig(clientTimeout: const Duration(seconds: 1));
      await rig.warm();
      await rig.console('/_emul/latency', {'ms': 1500});

      final r = await sellThroughQueue('timeout');
      await rig.console('/_emul/latency', {'ms': 0});
      expect(r.queued, isTrue);
      expect(await rig.store.pendingCount(), 1);
    });
  });

  group('неповторимо: отказ с названной причиной', () {
    test('HTTP 404 со страницей — адрес не тот, не очередь', () async {
      rig = await startWebKassaRig();
      await rig.warm();
      await rig.console('/_emul/http', {
        'status': 404,
        'count': 1,
        'body': '<html>Not Found</html>',
      });

      final r = await sellThroughQueue('http-404');
      expect(r.success, isFalse);
      expect(r.queued, isFalse);
      expect(await rig.store.pendingCount(), 0);
    });

    test('https к порту без TLS — рукопожатие не сошлось, не очередь', () async {
      rig = await startWebKassaRig(scheme: 'https');

      final r = await sellThroughQueue('tls');
      // ignore: avoid_print
      print(
        'https → http: success=${r.success} queued=${r.queued} '
        '${r.errorCode.name} raw=${r.rawErrorCode} «${r.errorMessage}»',
      );

      expect(
        r.queued,
        isFalse,
        reason:
            'TLS, не сошедшийся раз, не сойдётся и на повторе: чужая схема, '
            'часы кассы, сертификат — лечит человек',
      );
      expect(r.success, isFalse);
      expect(r.errorCode.name, 'tlsRejected');
      expect(await rig.store.pendingCount(), 0);
      expect(rig.state.journal, isEmpty, reason: 'до оператора не дошло');
    });

    test(
      'исключение не из ввода-вывода (сбой кода кассы) — не сеть и не очередь',
      () async {
        // Единственная проба здесь с подменой `send:` — и названо почему:
        // исключение, не являющееся `IOException`, сокет не производит, а
        // эмулятор его вызвать не может. Проверяется **ветка разбора в
        // `post`**, а не транспорт.
        final client = WebKassaApiClient(
          baseUrl: 'http://127.0.0.1:1',
          apiKey: 'k',
          logger: Talker(settings: TalkerSettings(enabled: false)),
          send: (uri, headers, body) async => throw StateError('сбой кассы'),
        );
        final resp = await client.check(const {'Token': 't'});
        expect(resp.success, isFalse);
        expect(
          resp.errorCode,
          isNot(anyOf(-1, -2, -3)),
          reason: 'сбой кода кассы — не обрыв связи: код ${resp.errorCode}',
        );
        expect(resp.errorMessage, isNot(contains('сбой кассы')));
      },
    );
  });

  test('таблица повторимости закреплена: ровно три кода лечатся временем', () {
    final transient = {
      for (final c in FiscalErrorCode.values)
        if (c.isTransient) c,
    };
    expect(transient, {
      FiscalErrorCode.network,
      FiscalErrorCode.operatorUnavailable,
      FiscalErrorCode.tokenExpired,
    });
  });

  test('HttpException и SocketException — оба ввод-вывод, оба сеть', () async {
    for (final e in <Object>[
      const HttpException('Connection closed before full header was received'),
      const SocketException('Connection reset by peer'),
      TimeoutException('t'),
    ]) {
      final client = WebKassaApiClient(
        baseUrl: 'http://127.0.0.1:1',
        apiKey: 'k',
        logger: Talker(settings: TalkerSettings(enabled: false)),
        send: (uri, headers, body) async => throw e,
      );
      final resp = await client.check(const {'Token': 't'});
      expect(
        resp.errorCode,
        anyOf(-1, -2),
        reason: '${e.runtimeType} → ${resp.errorCode}',
      );
    }
  });
}
