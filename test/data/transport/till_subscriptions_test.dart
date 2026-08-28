import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rk_quic/rk_quic.dart';
import 'package:telepos/data/transport/till_subscriptions.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/wire/wire_frame.dart';

import 'fake_quic_server.dart';
import 'open_guard.dart';

void main() {
  late FakeQuicServer server;

  setUp(() => server = FakeQuicServer());
  tearDown(() => server.dispose());

  group('учёт подписок', () {
    test('подписка снимается, когда запись отвечает peerGone', () async {
      // Терминал закрыл свою половину приёма — узнать об этом можно только
      // попыткой что-то прислать. Подписка, которая этого не делает, пишет в
      // экран, которого больше нет, и живёт дольше него.
      server.failNextSendWith(RkQuicStatus.peerGone);
      final subs = TillSubscriptions();
      final source = StreamController<void>();
      subs.add(1, 4, source.stream.listen((_) {}));

      final status = await subs.deliver(
        server,
        sessionId: 1,
        streamId: 4,
        frame: const UpdateFrame({}),
      );

      expect(status, RkQuicStatus.peerGone);
      expect(
        subs.live,
        0,
        reason: 'ушедший подписчик снимается на первой же записи',
      );
      expect(
        source.hasListener,
        isFalse,
        reason:
            'снятая подписка обязана быть отменена, а не просто забыта: '
            'иначе источник продолжает работать на никого',
      );
      await source.close();
    });

    test('удавшаяся запись подписку не трогает', () async {
      // Обратная половина того же: снятие по отказу не должно превращаться в
      // снятие по любому обновлению.
      final subs = TillSubscriptions();
      final source = StreamController<void>();
      subs.add(1, 4, source.stream.listen((_) {}));

      final status = await subs.deliver(
        server,
        sessionId: 1,
        streamId: 4,
        frame: const UpdateFrame({'n': 1}),
      );

      expect(status, RkQuicStatus.ok);
      expect(subs.live, 1);
      expect(WireFrame.decode(server.sentFrames.single), isA<UpdateFrame>());
      await subs.removeAll();
      await source.close();
    });

    test('закрытие сессии снимает все её подписки', () async {
      // Закрытая крышка ноутбука не шлёт «отписаться». Без снятия по сессии
      // подписки копятся молча и живут дольше экранов, которые их завели, —
      // а касса продолжает считать, что кто-то слушает.
      final subs = TillSubscriptions();
      final sources = [
        StreamController<void>(),
        StreamController<void>(),
        StreamController<void>(),
      ];
      subs.add(1, 4, sources[0].stream.listen((_) {}));
      subs.add(1, 5, sources[1].stream.listen((_) {}));
      subs.add(2, 4, sources[2].stream.listen((_) {}));

      await subs.removeSession(1);

      expect(subs.live, 1, reason: 'осталась только подписка чужой сессии');
      expect(sources[0].hasListener, isFalse);
      expect(sources[1].hasListener, isFalse);
      expect(sources[2].hasListener, isTrue, reason: 'чужую сессию не трогаем');
      await subs.removeAll();
      for (final source in sources) {
        await source.close();
      }
    });

    test('повторное снятие не ошибка', () async {
      // Снятие приходит с двух сторон сразу — по отказу записи и по закрытию
      // сессии, — и порядок между ними не определён.
      final subs = TillSubscriptions();
      final source = StreamController<void>();
      subs.add(1, 4, source.stream.listen((_) {}));

      await subs.removeStream(1, 4);
      await subs.removeStream(1, 4);

      expect(subs.live, 0);
      await source.close();
    });

    test('запись в снятую подписку ничего не отправляет', () async {
      // Гонка, которая обязательно случится: обновление источника и закрытие
      // сессии приходят одновременно. Слать в поток, про который уже решено,
      // что его нет, — значит держать ссылку на ушедший терминал дольше, чем
      // договаривались.
      final subs = TillSubscriptions();
      final source = StreamController<void>();
      subs.add(1, 4, source.stream.listen((_) {}));
      await subs.removeSession(1);

      final status = await subs.deliver(
        server,
        sessionId: 1,
        streamId: 4,
        frame: const UpdateFrame({}),
      );

      expect(status, RkQuicStatus.unknownHandle);
      expect(server.sentFrames, isEmpty);
      await source.close();
    });
  });

  group('подписки на проводе', () {
    late TillWire wire;
    tearDown(() => wire.stop());

    /// Терминал открыл поток, прислал запрос и закрыл свою половину отправки.
    Future<void> watchAndSettle(String op) async {
      server.emitStreamOpened(sessionId: 1, streamId: 4);
      server.emitStreamData(
        sessionId: 1,
        streamId: 4,
        message: '{"op":"$op","body":{}}',
      );
      // Приходит сразу за запросом — так устроен приём. Отпиской он не
      // является, и это ровно то, что проверяется ниже.
      server.emitStreamClosed(sessionId: 1, streamId: 4);
      await Future<void>.delayed(Duration.zero);
    }

    test('изменение доезжает без вопроса со стороны терминала', () async {
      // Это и есть цель всей работы: касса говорит первой. Тест обязан
      // краснеть, если она снова начнёт ждать вопроса.
      final source = StreamController<Map<String, Object?>>();
      wire = TillWire(
        server,
        const {},
        watchHandlers: {'demo.state': (body) => source.stream},
        guard: openGuard,
      )..start();

      await watchAndSettle('demo.state');
      expect(
        server.sentFrames,
        isEmpty,
        reason: 'источник ещё ничего не сказал',
      );

      source.add({'n': 1});
      await Future<void>.delayed(Duration.zero);
      source.add({'n': 2});
      await Future<void>.delayed(Duration.zero);

      final frames = server.sentFrames.map(WireFrame.decode).toList();
      expect(frames.whereType<UpdateFrame>().map((f) => f.body['n']), [1, 2]);
      await source.close();
    });

    test('streamClosed подписку не снимает', () async {
      // Ловушка, из-за которой этот файл вообще переписывался: касса читает
      // сообщение до конца, поэтому видит запрос только после того, как
      // терминал закрыл свою половину отправки. Снятие по streamClosed сняло
      // бы подписку немедленно после создания, и часовая подписка жила бы
      // микросекунду.
      final source = StreamController<Map<String, Object?>>();
      wire = TillWire(
        server,
        const {},
        watchHandlers: {'demo.state': (body) => source.stream},
        guard: openGuard,
      )..start();

      await watchAndSettle('demo.state');

      expect(wire.liveSubscriptions, 1);
      expect(server.closedStreams, isEmpty, reason: 'подписка живёт дальше');
      await source.close();
    });

    test('ушедший терминал снимает подписку на первом же обновлении', () async {
      final source = StreamController<Map<String, Object?>>();
      wire = TillWire(
        server,
        const {},
        watchHandlers: {'demo.state': (body) => source.stream},
        guard: openGuard,
      )..start();
      await watchAndSettle('demo.state');

      server.failNextSendWith(RkQuicStatus.peerGone);
      source.add({'n': 1});
      await Future<void>.delayed(Duration.zero);

      expect(wire.liveSubscriptions, 0);
      expect(source.hasListener, isFalse, reason: 'источник отпущен');
      await source.close();
    });

    test('закрытая сессия снимает подписки этой сессии', () async {
      final source = StreamController<Map<String, Object?>>();
      wire = TillWire(
        server,
        const {},
        watchHandlers: {'demo.state': (body) => source.stream},
        guard: openGuard,
      )..start();
      await watchAndSettle('demo.state');
      expect(wire.liveSubscriptions, 1);

      server.emitSessionClosed(sessionId: 1);
      await Future<void>.delayed(Duration.zero);

      expect(wire.liveSubscriptions, 0);
      expect(source.hasListener, isFalse);
      await source.close();
    });

    test('источник, кончившийся сам, закрывает поток', () async {
      // Подписка на то, чего больше нет, обязана перестать быть подпиской:
      // иначе терминал ждёт обновлений от закончившегося источника до предела
      // простоя сессии.
      final source = StreamController<Map<String, Object?>>();
      wire = TillWire(
        server,
        const {},
        watchHandlers: {'demo.state': (body) => source.stream},
        guard: openGuard,
      )..start();
      await watchAndSettle('demo.state');

      await source.close();
      await Future<void>.delayed(Duration.zero);

      expect(wire.liveSubscriptions, 0);
      expect(server.closedStreams, [(1, 4)]);
    });
  });
}
