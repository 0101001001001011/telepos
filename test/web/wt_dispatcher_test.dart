import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/domain/wire/wire_access.dart';
import 'package:telepos/domain/wire/wire_frame.dart';
import 'package:telepos/domain/wire/wire_op.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';

import 'support/fake_dispatcher.dart';

/// Операции для проверок. Настоящие живут в `till_ops.dart`; здесь нужны
/// простейшие, чтобы отказ разбора нельзя было списать на их форму.
const _echo = Ask<void, String>(
  'demo.echo',
  access: OpenAccess(),
  encode: _nothing,
  decode: _text,
);
const _counter = Watch<void, int>(
  'demo.counter',
  access: OpenAccess(),
  encode: _nothing,
  decode: _n,
);
const _restore = Run<void, bool>(
  'demo.restore',
  access: OpenAccess(),
  encode: _nothing,
  decode: _ok,
);

Map<String, Object?> _nothing(void _) => const {};
String _text(Map<String, Object?> body) => body['text']! as String;
int _n(Map<String, Object?> body) => body['n']! as int;
bool _ok(Map<String, Object?> body) => body['ok'] == true;

void main() {
  group('ask', () {
    test('отдаёт разобранный ответ и закрывает поток', () async {
      final session = FakeWtSession()
        ..replyWith('{"ok":true,"body":{"text":"да"}}');

      final answer = await WtDispatcher(session).ask(_echo, null);

      expect(answer, 'да');
      expect(
        session.closedStreams,
        1,
        reason: 'одноразовый обмен не оставляет потока',
      );
    });

    test('вопрос уходит кадром запроса с именем операции', () async {
      // Имя на проводе — единственное, по чему касса выбирает обработчик.
      // Молча уехавший не тот кадр дал бы отказ «нет такой операции» при
      // полностью верном каталоге.
      final session = FakeWtSession()
        ..replyWith('{"ok":true,"body":{"text":"д"}}');

      await WtDispatcher(session).ask(_echo, null);

      final sent = WireFrame.decode(session.sent.single);
      expect(sent, isA<RequestFrame>());
      expect((sent as RequestFrame).op, 'demo.echo');
    });

    test(
      'половина отправки закрывается — иначе касса вопроса не увидит',
      () async {
        // Не оформление обмена, а условие того, что он состоится. `rk_quic`
        // читает поток целиком (`transport.rs`, `read_bi_stream`:
        // `recv.read_to_end`), прежде чем он станет событием `StreamData`, —
        // значит запрос доезжает до кассы только после того, как терминал
        // закрыл свою половину отправки.
        //
        // Измерено в настоящем браузере 2026-08-05 стендом
        // `test/manual/wt_stand.dart`: кадр `startup.boot` без закрытия не
        // получил ответа за пять секунд, с закрытием получил
        // `{"ok":true,"body":{"status":"success"}}`. До этого дня петля на VM
        // отдавала кадр кассе прямо из `send` — и была зелёной при проводе,
        // который в браузере молчал.
        final session = FakeWtSession()
          ..replyWith('{"ok":true,"body":{"text":"д"}}');

        await WtDispatcher(session).ask(_echo, null);

        expect(session.finishedSending, greaterThanOrEqualTo(1));
      },
    );

    test('кадр отказа становится WtProtocolError с кодом кассы', () async {
      final session = FakeWtSession()
        ..replyWith('{"ok":false,"code":"unknown_op","detail":"нет такой"}');

      await expectLater(
        WtDispatcher(session).ask(_echo, null),
        throwsA(
          isA<WtProtocolError>().having((e) => e.code, 'code', 'unknown_op'),
        ),
      );
    });

    test(
      'код unauthorized становится SessionLost, а не WtProtocolError',
      () async {
        final session = FakeWtSession()
          ..replyWith(
            '{"ok":false,"code":"unauthorized","detail":"сеанс неизвестен или истёк"}',
          );

        await expectLater(
          WtDispatcher(session).ask(_echo, null),
          throwsA(isA<SessionLost>()),
        );
      },
    );

    test(
      'код forbidden остаётся WtProtocolError, а не SessionLost — '
      'круг правок 1: живой сеанс без права не лечится входом заново',
      () async {
        final session = FakeWtSession()
          ..replyWith('{"ok":false,"code":"forbidden","detail":"нет права"}');

        await expectLater(
          WtDispatcher(session).ask(_echo, null),
          throwsA(
            isA<WtProtocolError>().having((e) => e.code, 'code', 'forbidden'),
          ),
        );
      },
    );

    test('не-JSON становится WtProtocolError, а не белым экраном', () async {
      // 2026-08-04: по адресу API ответил статический сервер страницей 404,
      // `FormatException` прошла мимо всех `catch`, кассир увидел белизну.
      final session = FakeWtSession()..replyWith('<!DOCTYPE html>');

      await expectLater(
        WtDispatcher(session).ask(_echo, null),
        throwsA(
          isA<WtProtocolError>().having((e) => e.code, 'code', 'not_a_frame'),
        ),
      );
    });

    test(
      'поток, закрывшийся без ответа, — названный отказ, а не зависание',
      () async {
        // Касса перезапустилась посреди обмена. Без этого `first` бросил бы
        // `StateError`, который никакой `catch` в вызывающем коде не ловит.
        final session = FakeWtSession()..endAfterScript = true;

        await expectLater(
          WtDispatcher(session).ask(_echo, null),
          throwsA(
            isA<WtProtocolError>().having((e) => e.code, 'code', 'no_answer'),
          ),
        );
        expect(
          session.closedStreams,
          1,
          reason: 'поток закрывается и на отказе',
        );
      },
    );

    test('ответ не той формы — отказ разбора, а не падение типа', () async {
      // `body['text']! as String` над картой без `text` даёт `TypeError`,
      // который не Exception и не ловится `on Exception`. Именно эта форма
      // отказа белила экран.
      final session = FakeWtSession()..replyWith('{"ok":true,"body":{}}');

      await expectLater(
        WtDispatcher(session).ask(_echo, null),
        throwsA(
          isA<WtProtocolError>().having((e) => e.code, 'code', 'bad_body'),
        ),
      );
    });
  });

  group('watch', () {
    test('отдаёт первым текущее значение, потом изменения', () async {
      // Это и есть цель всей работы: изменение доходит без вопроса со
      // стороны терминала. Тест обязан краснеть, если касса снова начнёт
      // ждать вопроса.
      final session = FakeWtSession()
        ..replyWith('{"kind":"update","body":{"n":1}}')
        ..replyWith('{"kind":"update","body":{"n":2}}');

      final seen = await WtDispatcher(
        session,
      ).watch(_counter, null).take(2).toList();

      expect(seen, [1, 2]);
    });

    test('подписка спрашивает ровно один раз', () async {
      // Опрос, переодетый в подписку, прошёл бы все остальные проверки.
      final session = FakeWtSession()
        ..replyWith('{"kind":"update","body":{"n":1}}')
        ..replyWith('{"kind":"update","body":{"n":2}}');

      await WtDispatcher(session).watch(_counter, null).take(2).toList();

      expect(session.sent, hasLength(1));
    });

    test('отписка закрывает поток', () async {
      // Иначе касса продолжает слать в экран, которого больше нет, а
      // подписки копятся молча и живут дольше своих экранов.
      final session = FakeWtSession()
        ..replyWith('{"kind":"update","body":{"n":1}}');

      final sub = WtDispatcher(session).watch(_counter, null).listen((_) {});
      await pumpEventQueue();
      await sub.cancel();

      expect(session.closedStreams, 1);
    });

    test('кадр отказа доезжает до подписчика ошибкой', () async {
      final session = FakeWtSession()
        ..replyWith('{"ok":false,"code":"unknown_op","detail":"нет"}');

      await expectLater(
        WtDispatcher(session).watch(_counter, null),
        emitsError(
          isA<WtProtocolError>().having((e) => e.code, 'code', 'unknown_op'),
        ),
      );
    });

    test(
      'оборванная подписка не выглядит как «изменений больше не будет»',
      () async {
        // Тихо завершившийся поток означает для экрана, что состояние
        // окончательное. Оборванная сессия — не окончательное состояние, и
        // выдать одно за другое значит показать устаревшее как свежее.
        final session = FakeWtSession()
          ..replyWith('{"kind":"update","body":{"n":1}}')
          ..endAfterScript = true;

        await expectLater(
          WtDispatcher(session).watch(_counter, null),
          emitsInOrder([
            1,
            emitsError(
              isA<WtProtocolError>().having(
                (e) => e.code,
                'code',
                'stream_ended',
              ),
            ),
            emitsDone,
          ]),
        );
      },
    );
  });

  group('run', () {
    test('отдаёт ход выполнения, а не два крайних числа', () async {
      // `http_first_launch_repository.dart` писал о себе, что канала для
      // этого нет и промежуточные числа он придумывать отказывается.
      // Канал появился — проверяем, что им пользуются.
      final session = FakeWtSession()
        ..replyWith('{"kind":"progress","value":0.1,"text":"Начали"}')
        ..replyWith('{"kind":"progress","value":0.6,"text":"Половина"}')
        ..replyWith('{"kind":"done","body":{"ok":true}}');

      final seen = await WtDispatcher(session).run(_restore, null).toList();

      expect(seen.where((step) => !step.isDone).map((s) => s.value), [
        0.1,
        0.6,
      ]);
      expect(seen.last.isDone, isTrue);
      expect(seen.last.done, isTrue);
    });

    test('после завершения поток закрывается', () async {
      final session = FakeWtSession()
        ..replyWith('{"kind":"done","body":{"ok":true}}');

      await WtDispatcher(session).run(_restore, null).toList();

      expect(session.closedStreams, 1);
    });

    test('обрыв не выдаёт незавершённое за завершённое', () async {
      // Восстановление, оборванное на середине, обязано остаться
      // оборванным: «готово» здесь означает целый магазин.
      final session = FakeWtSession()
        ..replyWith('{"kind":"progress","value":0.1,"text":"Начали"}')
        ..endAfterScript = true;

      final (seen, failure) = await _collect(
        WtDispatcher(session).run(_restore, null),
      );

      expect(
        failure,
        isA<WtProtocolError>().having((e) => e.code, 'code', 'run_incomplete'),
      );
      expect(seen.where((step) => step.isDone), isEmpty);
    });

    test('отказ кассы посреди работы приходит ошибкой без «готово»', () async {
      final session = FakeWtSession()
        ..replyWith('{"kind":"progress","value":0.1,"text":"Начали"}')
        ..replyWith('{"ok":false,"code":"handler_failed","detail":"питание"}');

      final (seen, failure) = await _collect(
        WtDispatcher(session).run(_restore, null),
      );

      expect(
        failure,
        isA<WtProtocolError>().having((e) => e.code, 'code', 'handler_failed'),
      );
      expect(seen.where((step) => step.isDone), isEmpty);
    });
  });

  group('авторизация', () {
    test('запрос несёт токен из хранилища', () async {
      // Каждый запрос обязан предъявить токен, если он есть. Иначе касса
      // откажет «нужен сеанс» вместо нужной операции.
      final tokens = FakeTokens('tok-9');
      final session = FakeWtSession()
        ..replyWith('{"ok":true,"body":{"text":"д"}}');
      final wire = WtDispatcher(session, tokens: tokens);

      await wire.ask(_echo, null);

      final sent = WireFrame.decode(session.sent.single);
      expect(sent, isA<RequestFrame>());
      expect((sent as RequestFrame).token, 'tok-9');
    });

    test('без токена запрос уходит без конверта, а не с пустым', () async {
      // Касса пустую строку и отсутствие токена не различает: ветка
      // `SessionAccess` в `WireGuard.check` отвечает «нужен сеанс» на оба.
      // Ключа в кадре всё равно быть не должно — конверт везёт токен, а
      // пустая строка токеном не является. `RequestFrame` с `null` его не
      // кладёт вовсе, и этот тест сторожит именно сериализованную форму.
      final session = FakeWtSession()
        ..replyWith('{"ok":true,"body":{"text":"ответ"}}');
      final wire = WtDispatcher(session, tokens: FakeTokens(null));

      await wire.ask(_echo, null);

      final sent = WireFrame.decode(session.sent.single);
      expect(sent, isA<RequestFrame>());
      expect((sent as RequestFrame).token, isNull);
    });

    test('токен отправляется и в подписках (watch)', () async {
      // Если токен отправляется только в ask, подписки будут молча отказываться.
      final tokens = FakeTokens('sub-token');
      final session = FakeWtSession()
        ..replyWith('{"kind":"update","body":{"n":1}}');
      final wire = WtDispatcher(session, tokens: tokens);

      await wire.watch(_counter, null).first;

      final sent = WireFrame.decode(session.sent.single);
      expect((sent as RequestFrame).token, 'sub-token');
    });

    test('токен отправляется и в длинных работах (run)', () async {
      // Если токен отправляется только в ask, работы будут молча отказываться.
      final tokens = FakeTokens('run-token');
      final session = FakeWtSession()
        ..replyWith('{"kind":"done","body":{"ok":true}}');
      final wire = WtDispatcher(session, tokens: tokens);

      await wire.run(_restore, null).first;

      final sent = WireFrame.decode(session.sent.single);
      expect((sent as RequestFrame).token, 'run-token');
    });
  });
}

/// Слушает поток до конца и отдаёт увиденное вместе с отказом, если он был.
///
/// `asFuture` здесь не годится: он **подменяет** обработчик ошибок, заданный
/// в `listen`, и отказ до проверки не доезжает.
Future<(List<T>, Object?)> _collect<T>(Stream<T> stream) async {
  final seen = <T>[];
  Object? failure;
  final over = Completer<void>();
  stream.listen(
    seen.add,
    onError: (Object error) => failure = error,
    onDone: over.complete,
  );
  await over.future;
  return (seen, failure);
}

/// Подставная сессия: раздаёт потоки по сценарию и считает закрытия.
///
/// Настоящая `WtSession` в наборе не поднимается — конструктора `WebTransport`
/// на VM не существует вовсе, — и это не обход проверки: диспетчер не знает о
/// браузере ничего, он знает только договор `WtStreams`.
class FakeWtSession implements WtStreams {
  final List<String> _scripted = [];

  /// Всё, что диспетчер написал в потоки.
  final List<String> sent = [];

  /// Сколько потоков закрыто — по одному на завершённый обмен.
  int closedStreams = 0;

  /// Сколько раз диспетчер закончил говорить.
  ///
  /// Наблюдаемая величина, а не мелочь учёта: касса читает запрос целиком,
  /// прежде чем он станет для неё событием, и обмен, не закрывший свою
  /// половину отправки, не доезжает до кассы вовсе (измерено в браузере
  /// 2026-08-05).
  int finishedSending = 0;

  /// Закрывать поток после сценария: так выглядит перезапустившаяся касса.
  bool endAfterScript = false;

  void replyWith(String frame) => _scripted.add(frame);

  @override
  Future<WtStream> openStream() async =>
      _FakeWtStream(this, List.of(_scripted), endAfterScript);

  @override
  Future<void> get closed => Completer<void>().future;

  @override
  Future<void> close() async {}
}

class _FakeWtStream implements WtStream {
  _FakeWtStream(this._session, this._scripted, this._end) {
    _controller = StreamController<String>(
      onListen: () {
        for (final frame in _scripted) {
          _controller.add(frame);
        }
        if (_end) _controller.close();
      },
    );
  }

  final FakeWtSession _session;
  final List<String> _scripted;
  final bool _end;
  late final StreamController<String> _controller;

  @override
  Stream<String> get frames => _controller.stream;

  @override
  Future<void> send(String frame) async => _session.sent.add(frame);

  @override
  Future<void> finishSending() async => _session.finishedSending++;

  @override
  Future<void> close() async {
    _session.closedStreams++;
    if (!_controller.isClosed) await _controller.close();
  }
}
