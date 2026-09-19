/// Возврат держится за **своё** основание, а не за любую застрявшую
/// строку — через эмулятор WebKassa на настоящем сокете.
///
/// # Что мерялось и что чинится
///
/// Ревизия 2026-09-19, пункт 16: правило очереди было названо в коде прямо
/// — «застряла любая строка, держатся все зависимые». У заказчика это
/// выглядело так: чек, который оператор отказался принять (или который
/// ждёт связи), **останавливал фискализацию посторонних документов** —
/// возврат по чужому чеку не уезжал, потому что чья-то продажа застряла.
///
/// Теперь возврат несёт ключ своего основания
/// (`FiscalRefundBasis.originalIdempotencyKey`), и очередь держит его
/// **только** пока это основание не у оператора.
///
/// # Обе половины меряются, и вторая не менее важна первой
///
/// Ослабить правило целиком значило бы отправить оператору возврат по
/// чеку, которого у него нет: конверт возврата несёт признак основания, а
/// у застрявшей продажи признака ещё нет. Поэтому здесь по паре проб на
/// каждый вход очереди: отпускает ли она чужое **и** держит ли своё.
///
/// # Почему через сокет, а не через двойник провайдера
///
/// Держать или отправить — решение очереди, но «отправлено» здесь
/// означает «дошло до оператора и он его принял», и это читается из
/// журнала эмулятора, а не из счётчика двойника. Двойник согласился бы
/// с любым конвертом, в том числе с таким, который настоящий клиент не
/// собрал бы вовсе.
///
/// # Чего эти пробы НЕ доказывают
///
/// Что настоящая WebKassa примет отпущенный возврат. Эмулятор основание
/// не сверяет вовсе (у него нет реестра признаков), и проверять это ему
/// нечем — открытый вопрос живого прогона. Доказывается ровно одно:
/// **порядок отправки** стал точным, и чужая беда больше не держит чужой
/// документ.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'support/webkassa_rig.dart';

void main() {
  late WebKassaRig rig;

  setUp(() async {
    rig = await startWebKassaRig();
    await rig.warm();
  });

  tearDown(() async => rig.stop());

  final t0 = DateTime.now().subtract(const Duration(minutes: 10));
  DateTime after(int minutes) => t0.add(Duration(minutes: minutes));

  group('проход повтора', () {
    test('чужая застрявшая продажа не держит возврат по другому чеку', () async {
      // «Своя» продажа возврата уехала оператору давно — её в очереди нет.
      await rig.queued.fiscalizeSale(rigSale('sale-mine', at: after(0)));
      expect(rig.acceptedKeys(), ['sale-mine']);

      await rig.store.enqueue(rigSaleRow(rigSale('sale-alien', at: after(1))));
      await rig.store.enqueue(
        rigRefundRow(
          rigRefund(
            'refund-mine',
            at: after(2),
            basisKey: 'sale-mine',
            basisSign: 'FP-1',
          ),
        ),
      );
      await rig.console('/_emul/kill', {'count': 1});

      final report = await rig.queued.replay();
      // ignore: avoid_print
      print(
        'проход: fiscalized=${report.fiscalized} held=${report.held} '
        'sent=${rig.sentKeys()} accepted=${rig.acceptedKeys()}',
      );

      expect(
        rig.acceptedKeys(),
        ['sale-mine', 'refund-mine'],
        reason:
            'возврат по чеку, который у оператора есть, не имеет отношения '
            'к застрявшей чужой продаже',
      );
      expect(report.held, 0);
      expect(report.fiscalized, 1);
      expect(
        (await rig.store.pending()).map((e) => e.idempotencyKey),
        ['sale-alien'],
      );
    });

    test('своя застрявшая продажа держит свой возврат', () async {
      await rig.store.enqueue(rigSaleRow(rigSale('sale-mine', at: after(0))));
      await rig.store.enqueue(
        rigRefundRow(
          rigRefund('refund-mine', at: after(1), basisKey: 'sale-mine'),
        ),
      );
      await rig.console('/_emul/kill', {'count': 1});

      final report = await rig.queued.replay();

      expect(
        rig.sentKeys(),
        isNot(contains('refund-mine')),
        reason: 'основания у оператора нет — возврат ехать не имеет права',
      );
      expect(report.held, 1);
      expect(
        (await rig.store.pending()).map((e) => e.idempotencyKey),
        ['sale-mine', 'refund-mine'],
      );

      // Связь вернулась — следующий проход везёт оба и в прежнем порядке.
      final second = await rig.queued.replay();
      expect(second.fiscalized, 2);
      expect(rig.acceptedKeys(), ['sale-mine', 'refund-mine']);
    });

    test('возврат без названного основания держится по-прежнему — за любую', () async {
      // Строки, легшие до правки, и возвраты без чека: ключа основания у
      // них нет. Осторожность для них не снимается, и это названный выбор
      // — «не знаем, чьё основание» не то же самое, что «ничьё».
      await rig.store.enqueue(rigSaleRow(rigSale('sale-alien', at: after(0))));
      await rig.store.enqueue(
        rigRefundRow(rigRefund('refund-nameless', at: after(1))),
      );
      await rig.console('/_emul/kill', {'count': 1});

      final report = await rig.queued.replay();

      expect(rig.sentKeys(), isNot(contains('refund-nameless')));
      expect(report.held, 1);
    });

    test('изъятие держится за любую застрявшую строку — зависимость иная', () async {
      // У изъятия зависимость арифметическая (остаток в ящике, код 8), а
      // не ссылочная: сослаться ему не на что. Правило для него осталось
      // осторожным намеренно, и это здесь измерено, а не подразумевается.
      await rig.store.enqueue(rigSaleRow(rigSale('sale-alien', at: after(0))));
      await rig.store.enqueue(
        rigMoneyOutRow(rigMoneyOut('out-1', at: after(1))),
      );
      await rig.console('/_emul/kill', {'count': 1});

      final report = await rig.queued.replay();

      expect(
        rig.sentKeys('/api/v4/MoneyOperation'),
        isEmpty,
        reason: 'деньги, которых в ящике у оператора ещё нет, не изымаются',
      );
      expect(report.held, 1);
    });

    test('основание, отвергнутое навсегда, отпускает свой возврат', () async {
      // Документа по отвергнутой строке не будет никогда. Держать за неё
      // возврат значит держать его до конца автономного окна и молча:
      // пусть уедет и получит **свой** названный отказ рядом с основанием.
      await rig.store.enqueue(rigSaleRow(rigSale('sale-mine', at: after(0))));
      await rig.store.enqueue(
        rigRefundRow(
          rigRefund('refund-mine', at: after(1), basisKey: 'sale-mine'),
        ),
      );
      // Код 9 — нетранзиентный отказ конверта; один раз, на первую строку.
      await rig.console('/_emul/fault', {
        'path': '/api/v4/check',
        'code': 9,
        'count': 1,
      });

      final report = await rig.queued.replay();

      expect(report.failed, 1, reason: 'продажа отвергнута навсегда');
      expect(
        rig.acceptedKeys(),
        contains('refund-mine'),
        reason: 'возврат отпущен: ждать больше нечего',
      );
      expect(report.held, 0);
    });
  });

  group('новый документ, ещё не в очереди', () {
    test('возврат по чужому чеку при ждущей чужой продаже уходит сразу', () async {
      await rig.store.enqueue(rigSaleRow(rigSale('sale-alien', at: after(0))));

      final r = await rig.queued.fiscalizeRefund(
        rigRefund('refund-mine', basisKey: 'sale-elsewhere', basisSign: 'FP-7'),
      );

      expect(r.success, isTrue);
      expect(r.queued, isFalse);
      expect(rig.acceptedKeys(), contains('refund-mine'));
      expect(
        (await rig.store.pending()).map((e) => e.idempotencyKey),
        ['sale-alien'],
        reason: 'чужая беда в очередь возврат не кладёт',
      );
    });

    test('возврат по своему ждущему чеку встаёт в очередь', () async {
      await rig.store.enqueue(rigSaleRow(rigSale('sale-mine', at: after(0))));

      final r = await rig.queued.fiscalizeRefund(
        rigRefund('refund-mine', basisKey: 'sale-mine'),
      );

      expect(r.queued, isTrue);
      expect(rig.sentKeys(), isEmpty);
      expect(
        (await rig.store.pending()).map((e) => e.idempotencyKey),
        ['sale-mine', 'refund-mine'],
      );
    });
  });

  test('ключ основания оператору не уезжает', () async {
    // Поле заведено для очереди, а не для протокола: конверт собирает
    // `WebKassaProvider._sendCheck` из пяти полей основания поимённо.
    // Проба смотрит в **тело запроса, дошедшее до сокета**, а не в наш
    // объект — иначе она мерила бы наше намерение, а не то, что уехало.
    await rig.queued.fiscalizeRefund(
      rigRefund('refund-mine', basisKey: 'sale-secret', basisSign: 'FP-7'),
    );

    final bodies = [
      for (final e in rig.state.journal)
        if (e.path == '/api/v4/check') jsonEncode(e.request),
    ];
    expect(bodies, hasLength(1));
    expect(bodies.single, contains('FP-7'), reason: 'признак уезжает');
    expect(
      bodies.single,
      isNot(contains('sale-secret')),
      reason: 'ключ основания — дело кассы, оператору его слать не за чем',
    );
    expect(bodies.single, isNot(contains('originalIdempotencyKey')));
  });
}
