import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/web/wt_channel.dart';

void main() {
  group('отпечаток сертификата', () {
    test('шестьдесят четыре знака становятся тридцатью двумя байтами', () {
      // `serverCertificateHashes` берёт байты, а касса кладёт в документ
      // строку. Это единственное место перевода, и ошибиться в нём значит
      // не открыть ни одной сессии — при полностью исправной кассе.
      final bytes = parseCertificateHash('00ff' * 16);

      expect(bytes, isNotNull);
      expect(bytes!, hasLength(32));
      expect(bytes.first, 0x00);
      expect(bytes[1], 0xff);
    });

    test('регистр знаков значения не имеет', () {
      expect(parseCertificateHash('AB' * 32), parseCertificateHash('ab' * 32));
    });

    test('двоеточия между парами допускаются', () {
      // Так отпечаток печатают `openssl` и все браузеры, и рано или поздно
      // кто-то вставит его именно в этом виде.
      final withColons = List.filled(32, 'ab').join(':');

      expect(parseCertificateHash(withColons), parseCertificateHash('ab' * 32));
    });

    test('короткий отпечаток — null, а не обрезанный массив', () {
      // Пин на половину отпечатка — это пин ни на что: браузер отвергнет
      // сессию, и причина будет выглядеть как сетевая. Лучше назвать её
      // здесь.
      expect(parseCertificateHash('ab' * 16), isNull);
    });

    test('не-шестнадцатеричные знаки — null', () {
      expect(parseCertificateHash('zz' * 32), isNull);
    });

    test('пустая строка — null', () {
      // Касса впрыскивает пустую строку, когда слушатель не поднялся.
      expect(parseCertificateHash(''), isNull);
    });
  });

  group('хост для URL WebTransport', () {
    // Найдено живой проверкой задачи 8: конструктор `WebTransport` бросает
    // `SyntaxError` на `https://::1:1234/x`, потому что двоеточие в URL само
    // разделяет хост и порт, а не обрывом соединения — значит без скобок
    // терминал по IPv6 не соберёт вызов вовсе, а не просто не достучится.
    test('литерал IPv6 уезжает в скобках', () {
      // Путь без зоны не меняется этой правкой — на нём стоит живая проба
      // задачи 8 (см. комментарий выше).
      expect(bracketHostForUrl('::1'), '[::1]');
    });

    test('зона кодируется по RFC 6874 — голый % браузер не примет', () {
      expect(
        bracketHostForUrl('fe80::1234:5678%eth0'),
        '[fe80::1234:5678%25eth0]',
      );
    });

    test('уже закодированная зона не кодируется второй раз', () {
      expect(
        bracketHostForUrl('fe80::1234:5678%25eth0'),
        '[fe80::1234:5678%25eth0]',
      );
    });

    test('имя и IPv4 остаются как есть', () {
      expect(
        bracketHostForUrl('desktop-n89srfh.local'),
        'desktop-n89srfh.local',
      );
      expect(bracketHostForUrl('192.168.1.210'), '192.168.1.210');
      expect(bracketHostForUrl('localhost'), 'localhost');
    });
  });

  group('опора, переживающая обрыв', () {
    test('пока сессия жива, второй раз её не поднимают', () async {
      var opened = 0;
      final link = WtLink(() async {
        opened++;
        return _FakeSession();
      });

      await link.session();
      await link.session();

      expect(opened, 1, reason: 'сессия одна на терминал, а не на вопрос');
    });

    test('после обрыва сессия поднимается заново', () async {
      // Ради этого опора и заводится: вкладка пережила уснувший ноутбук
      // кассира, и следующий вопрос обязан уехать, а не упереться в
      // закрытую сессию.
      var opened = 0;
      final sessions = <_FakeSession>[];
      final link = WtLink(() async {
        opened++;
        final session = _FakeSession();
        sessions.add(session);
        return session;
      });

      await link.session();
      sessions.first.breakIt();
      await Future<void>.delayed(Duration.zero);
      await link.session();

      expect(opened, 2);
    });

    test(
      'неподнявшаяся сессия — значение с причиной, а не исключение',
      () async {
        final link = WtLink(
          () async => const WtUnavailable('конструктора WebTransport нет'),
          attempts: 2,
          pause: Duration.zero,
        );

        final outcome = await link.session();

        expect(outcome, isA<WtUnavailable>());
        expect((outcome as WtUnavailable).reason, contains('WebTransport'));
      },
    );

    test('попытки ограничены — терминал не крутит петлю молча', () async {
      // Бесконечное переподнятие выглядит как работающий терминал с пустым
      // экраном: ровно то состояние, которое этот проект уже трижды ловил.
      var attempts = 0;
      final link = WtLink(
        () async {
          attempts++;
          return const WtUnavailable('касса не отвечает');
        },
        attempts: 3,
        pause: Duration.zero,
      );

      await link.session();

      expect(attempts, 3);
    });

    test('повтор после отказа поднимает сессию заново', () async {
      // Это и есть кнопка «Повторить» на экране: без сброса она нажималась
      // бы в счётчик, который уже исчерпан.
      var fail = true;
      final link = WtLink(
        () async => fail ? const WtUnavailable('нет') : _FakeSession(),
        attempts: 1,
        pause: Duration.zero,
      );

      expect(await link.session(), isA<WtUnavailable>());
      fail = false;

      expect(await link.retry(), isA<WtStreams>());
    });

    test('без сессии поток не выдумывается', () async {
      // `openStream`, отдавший поток в никуда, увёл бы отказ на предел
      // простоя вместо того, чтобы назвать его сразу.
      final link = WtLink(
        () async => const WtUnavailable('порт занят'),
        attempts: 1,
        pause: Duration.zero,
      );

      await expectLater(
        link.openStream(),
        throwsA(
          isA<WtProtocolError>().having((e) => e.code, 'code', 'no_session'),
        ),
      );
    });
  });
}

class _FakeSession implements WtStreams {
  final _closed = Completer<void>();

  void breakIt() => _closed.complete();

  @override
  Future<void> get closed => _closed.future;

  @override
  Future<WtStream> openStream() async => throw UnimplementedError();

  @override
  Future<void> close() async {}
}
