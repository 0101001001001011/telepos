/// Повтор `ExternalCheckNumber`: **код 14 — беда с именем, а не успех**.
///
/// # Случай из жизни, который здесь воспроизводится
///
/// Найден живой приёмкой 2026-09-17. Касса отправляет документ с ключом
/// идемпотентности `sale-<чек>-<касса>`. Первая отправка **доходит** до
/// оператора и регистрируется, а ответ теряется в сети. Касса повторяет тем
/// же ключом — это и есть смысл ключа, — и оператор отвечает кодом 14:
/// «Документ с ExternalCheckNumber … уже зарегистрирован».
///
/// До 2026-09-18 касса принимала этот ответ за успех
/// (`FiscalResult.ok(fiscalSign: '')`). Цена: чек печатался **без
/// фискального признака**, строки в `WebkassaReceipts` не появлялось
/// (`FiscalServiceImpl._persistReceipt` выходит по `!hasFiscalSign`), а
/// кассир читал «фискализовано». Покупатель уносил бумажку, по которой
/// документ у оператора не найти, и след об этом не оставался нигде.
///
/// # Что доказывается, а что нет
///
/// Доказывается: повтор ключа **не даёт чека с пустым признаком** ни в одном
/// из ярусов — ни в первой линии, ни в денежной операции, ни в очереди.
///
/// НЕ доказывается и доказано быть не может: что касса узнаёт признак
/// исходного документа. Его неоткуда взять — ни один из девяти путей
/// `/api/v4/*`, которые знает `WebKassaApiClient`, не отдаёт документ по
/// `ExternalCheckNumber`, а тело кода 14 несёт ключ, а не `CheckNumber`.
/// Поэтому проба утверждает обратное и именно это: признак у оператора
/// **есть** (эмулятор его помнит, и проба сверяется с его памятью), а касса
/// его **не получила** — и говорит об этом вслух, вместо того чтобы печатать
/// пустоту. Разбор решения — в докстринге `WebKassaProvider._checkResult`.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/datasources/remote/webkassa_api_client.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';
import 'package:telepos/data/fiscal/webkassa_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_failure_reason.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

import 'support/webkassa_rig.dart';

WebKassaRig? _current;
WebKassaRig get rig => _current!;
set rig(WebKassaRig value) => _current = value;

void main() {
  tearDown(() async {
    await _current?.stop();
    _current = null;
  });

  group('живьём против эмулятора, настоящий сокет', () {
    test(
      'повтор ключа: признак исходного документа у оператора остался тот же, '
      'а касса его не получила и не выдумала',
      () async {
        rig = await startWebKassaRig();
        await rig.warm();

        const key = 'sale-4242-1';
        final first = await rig.provider.fiscalizeSale(rigSale(key));
        expect(first.success, isTrue, reason: first.errorMessage);
        expect(first.hasFiscalSign, isTrue);

        // Признак, который оператор выдал первой отправке. Дальше он нам
        // нужен дважды: сверить, что повтор его не изменил, и показать, что
        // касса его всё-таки не узнала.
        final signAtOperator = rig.state.answered[key]!['CheckNumber'];
        expect(signAtOperator, first.fiscalSign);

        final second = await rig.provider.fiscalizeSale(rigSale(key));

        expect(
          second.success,
          isFalse,
          reason:
              'было success=true sign="" — успех без признака; чек уходил в '
              'печать пустым, и следа не оставалось',
        );
        expect(second.errorCode, FiscalErrorCode.duplicate);
        expect(
          second.rawErrorCode,
          14,
          reason: 'код оператора едет рядом и объясняет причину на экране',
        );
        expect(
          second.hasFiscalSign,
          isFalse,
          reason: 'признак не выдуман: протокол его на код 14 не отдаёт',
        );

        // Документ у оператора **один** и признак у него **тот же**: повтор
        // не завёл второго документа — ради этого ключ и существует.
        expect(
          rig.state.answered[key]!['CheckNumber'],
          signAtOperator,
          reason: 'повтор обязан быть повтором, а не вторым документом',
        );
        expect(rig.acceptedKeys(), [
          key,
        ], reason: 'оператор принял ровно одну отправку из двух');

        expect(
          FiscalFailureReason.fromResult(second).encode(),
          'fiscal(duplicate#14)',
          reason:
              'эта строка ляжет в lastError и станет фразой словаря '
              'fiscalReasonDuplicate на экране нефискализованных чеков',
        );
      },
    );

    test(
      'первая линия: повтор не прячется в очередь, а зовёт человека',
      () async {
        rig = await startWebKassaRig();
        await rig.warm();

        const key = 'sale-4243-1';
        final first = await rig.queued.fiscalizeSale(rigSale(key));
        expect(first.success, isTrue);
        expect(await rig.store.pendingCount(), 0);

        final second = await rig.queued.fiscalizeSale(rigSale(key));

        expect(
          second.queued,
          isFalse,
          reason:
              '«в очереди» обещает лечение временем; повтор ключа временем не '
              'лечится — оператор ответит тем же кодом 14 и через час',
        );
        expect(second.success, isFalse);
        expect(second.errorCode, FiscalErrorCode.duplicate);
        expect(
          second.errorCode.isTransient,
          isFalse,
          reason: 'нетранзиентный отказ: строка failed, а не pending',
        );
        expect(
          await rig.store.pendingCount(),
          0,
          reason:
              'в pending такая строка загородила бы всех зависимых за собой',
        );
      },
    );

    test(
      'очередь: повтор оставляет строку человеку, а не убирает её',
      () async {
        rig = await startWebKassaRig();
        await rig.warm();

        const key = 'sale-4244-1';
        final req = rigSale(key);
        final first = await rig.provider.fiscalizeSale(req);
        expect(first.success, isTrue);
        final signAtOperator = first.fiscalSign;
        expect(signAtOperator, isNotEmpty);

        await rig.store.enqueue(rigSaleRow(req));
        final report = await rig.queued.replay();

        expect(report.remaining, 0, reason: 'в pending она больше не стоит');
        expect(
          report.duplicates,
          1,
          reason:
              'ветка `errorCode == duplicate` в replay была недостижима для '
              'продаж до правки 2026-09-18: _checkResult успевал сказать '
              'success',
        );
        expect(
          report.fiscalized,
          0,
          reason: 'документ не фискализован этим проходом — он уже лежал',
        );

        // Вот вся правка 2026-09-19 одной проверкой: строка **есть**.
        // До неё она убиралась как «дедуп», и у продажи не оставалось ни
        // признака, ни записи в `WebkassaReceipts`, ни строки, по которой
        // расхождение можно было бы найти.
        final left = await rig.store.failed();
        expect(
          left.map((e) => e.idempotencyKey),
          [key],
          reason:
              'у оператора документ, у кассы признака нет — это беда, а не '
              'успех, и она обязана остаться видимой',
        );
        expect(
          left.single.lastError,
          'fiscal(duplicate#14)',
          reason:
              'причина кодом, а не фразой: экран нефискализованных чеков '
              'переведёт её словарём (fiscalReasonDuplicate)',
        );
        expect(
          left.single.writeOff,
          isNull,
          reason: 'строка ждёт человека, а не помечена разобранной сама собой',
        );
        expect(
          signAtOperator,
          isNot(equals('')),
          reason:
              'признак у оператора есть (эмулятор его помнит) — и касса его '
              'всё равно не узнала: дозапросить его протоколом нечем',
        );
      },
    );

    test('очередь: повтор рукой человека тоже не стирает строку', () async {
      rig = await startWebKassaRig();
      await rig.warm();

      const key = 'sale-4246-1';
      final req = rigSale(key);
      expect((await rig.provider.fiscalizeSale(req)).success, isTrue);

      final row = rigSaleRow(req)..status = FiscalQueueStatus.failed;
      await rig.store.enqueue(row);

      final result = await rig.queued.retryFailed(row);

      expect(result.success, isFalse);
      expect(result.errorCode, FiscalErrorCode.duplicate);
      final left = await rig.store.failed();
      expect(
        left.map((e) => e.idempotencyKey),
        [key],
        reason:
            'нажатие «Повторить» не чинит расхождение: признака кассе не '
            'выдали и на этот раз. Закрыть строку можно только списанием с '
            'именем и причиной — после сверки в кабинете оператора',
      );
      expect(left.single.attempts, 1, reason: 'попытка сосчитана');
      expect(left.single.lastError, 'fiscal(duplicate#14)');
    });

    test('внесение денег: повтор ключа тоже не «успех без признака»', () async {
      rig = await startWebKassaRig();
      await rig.warm();

      final req = FiscalMoneyRequest(
        idempotencyKey: 'money-777',
        amount: rigD('5000'),
        occurredAt: DateTime.now(),
        comment: 'размен',
      );
      final first = await rig.provider.moneyIn(req);
      expect(first.success, isTrue, reason: first.errorMessage);
      expect(first.hasFiscalSign, isTrue);

      final second = await rig.provider.moneyIn(req);
      expect(second.success, isFalse);
      expect(second.errorCode, FiscalErrorCode.duplicate);
      expect(second.hasFiscalSign, isFalse);
    });

    test('пульт умеет отдать код 14 на свежий ключ — случай «первая отправка '
        'легла у оператора, но не в этом процессе»', () async {
      rig = await startWebKassaRig();
      await rig.warm();

      // Память эмулятора этого случая не воспроизводит: документа, ушедшего
      // до перезапуска кассы, в ней нет. Ответить так, как ответил бы
      // оператор, у которого он всё-таки лежит, умеет только пульт.
      await rig.console('/_emul/fault', {
        'path': '/api/v4/check',
        'code': 14,
        'text':
            'Документ с ExternalCheckNumber «sale-4245-1» уже '
            'зарегистрирован',
        'count': 1,
      });

      final r = await rig.provider.fiscalizeSale(rigSale('sale-4245-1'));

      expect(r.success, isFalse);
      expect(r.errorCode, FiscalErrorCode.duplicate);
      expect(r.rawErrorCode, 14);
      expect(r.hasFiscalSign, isFalse);
      expect(
        rig.state.answered.containsKey('sale-4245-1'),
        isFalse,
        reason:
            'отказ пришёл пультом, а не памятью: именно этим случай и ценен',
      );
    });
  });

  group('уровень провайдера и клиента, без сокета', () {
    /// Ответ оператора на код 14 — **дословно тот конверт**, который отдаёт
    /// WebKassa: `{"Errors":[{"Code":14,"Text":…}]}`. Признака в нём нет, и
    /// это и есть причина, по которой касса его не печатает.
    String duplicateEnvelope(String key) => jsonEncode({
      'Errors': [
        {
          'Code': 14,
          'Text': 'Документ с ExternalCheckNumber «$key» уже зарегистрирован',
        },
      ],
    });

    WebKassaProvider providerAnswering(String Function(Uri uri) answer) {
      final settings = FiscalSettings(
        operatorType: FiscalOperatorType.webkassa,
        testMode: true,
        baseUrl: 'http://stub.invalid',
        login: 'l',
        password: 'p',
        apiKey: 'k',
        cashboxUniqueNumber: 'SWK00000001',
        registrationNumber: '000000000001',
      );
      final logger = Talker(settings: TalkerSettings(enabled: false));
      return WebKassaProvider(
        settings: settings,
        logger: logger,
        client: WebKassaApiClient(
          baseUrl: settings.baseUrl!,
          apiKey: settings.apiKey,
          logger: logger,
          send: (uri, headers, body) async =>
              WebKassaRawResponse(statusCode: 200, body: answer(uri)),
        ),
      );
    }

    test('клиент: конверт кода 14 разбирается в отказ, а не в данные', () {
      final resp = WebKassaResponse.parse(200, duplicateEnvelope('sale-1-1'));

      expect(resp.success, isFalse);
      expect(resp.errorCode, 14);
      expect(
        resp.data,
        isNull,
        reason:
            'в конверте кода 14 данных нет вовсе — читать признак не из чего',
      );
      expect(resp.errorMessage, contains('уже зарегистрирован'));
    });

    test(
      'провайдер: код 14 на чеке → duplicate, а не ok с пустым признаком',
      () async {
        final provider = providerAnswering(
          (uri) => uri.path.endsWith('/Authorize')
              ? jsonEncode({
                  'Data': {'Token': 'stub-token'},
                })
              : duplicateEnvelope('sale-1-1'),
        );

        final r = await provider.fiscalizeSale(rigSale('sale-1-1'));

        expect(r.success, isFalse);
        expect(r.errorCode, FiscalErrorCode.duplicate);
        expect(r.rawErrorCode, 14);
        expect(r.hasFiscalSign, isFalse);
        provider.dispose();
      },
    );

    test('провайдер: код 14 на возврате разбирается тем же путём', () async {
      final provider = providerAnswering(
        (uri) => uri.path.endsWith('/Authorize')
            ? jsonEncode({
                'Data': {'Token': 'stub-token'},
              })
            : duplicateEnvelope('refund-1-1'),
      );

      final r = await provider.fiscalizeRefund(rigRefund('refund-1-1'));

      expect(r.success, isFalse);
      expect(r.errorCode, FiscalErrorCode.duplicate);
      expect(r.hasFiscalSign, isFalse);
      provider.dispose();
    });

    test(
      'провайдер: код 14 на MoneyOperation разбирается тем же путём',
      () async {
        final provider = providerAnswering(
          (uri) => uri.path.endsWith('/Authorize')
              ? jsonEncode({
                  'Data': {'Token': 'stub-token'},
                })
              : duplicateEnvelope('money-1'),
        );

        final r = await provider.moneyOut(
          FiscalMoneyRequest(
            idempotencyKey: 'money-1',
            amount: rigD('100'),
            occurredAt: DateTime.now(),
          ),
        );

        expect(r.success, isFalse);
        expect(r.errorCode, FiscalErrorCode.duplicate);
        expect(r.hasFiscalSign, isFalse);
        provider.dispose();
      },
    );

    test('код 14 не транзиентный: слепой повтор повторил бы его вечно', () {
      expect(FiscalErrorCode.duplicate.isTransient, isFalse);
    });
  });
}
