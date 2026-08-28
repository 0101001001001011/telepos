/// Три рода обмена поверх двунаправленных потоков.
///
/// # Почему не форма `ApiClient`
///
/// Повторить её значило бы оставить опрос при транспорте, который заводили
/// ради того, чтобы опрос убрать. Обменов ровно три, и они различаются по
/// существу: [ask] спрашивает один раз, [watch] подписывается на состояние,
/// [run] ведёт длинную работу с ходом выполнения.
///
/// # Почему нет книги учёта идентификаторов
///
/// Свой поток на каждый обмен. Соответствие ответа запросу даёт сам поток —
/// отвечать некуда, кроме как в него, — поэтому сводить ответы с вопросами
/// нечем и незачем. Книга учёта была бы ещё одним местом, где два конца
/// расходятся молча, и проверить её было бы нечем.
///
/// # Почему разбор здесь, а не в репозиториях
///
/// Белый экран 2026-08-04 родился на нетипизованном слое: `body['result'] as
/// String?` над картой, которая оказалась страницей HTML. Пока разбор
/// размазан по десяти файлам, такой отказ повторяется в каждом заново. Здесь
/// он в одном месте, и `WireFrame.decode` не бросает никогда.
library;

import 'dart:async';

import 'package:telepos/domain/auth/session_token_storage.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/domain/wire/wire_frame.dart';
import 'package:telepos/domain/wire/wire_op.dart';
import 'package:telepos/web/wt_channel.dart';

/// Один шаг длинной работы: либо ход выполнения, либо её конец.
///
/// [isDone] отделено от `done != null` намеренно: у работы, чей ответ
/// `bool false`, конец есть, и различить его по значению нельзя.
final class RunProgress<Res> {
  const RunProgress.step(double this.value, String this.text)
    : done = null,
      isDone = false;

  const RunProgress.finished(this.done)
    : value = null,
      text = null,
      isDone = true;

  /// Доля от нуля до единицы. `null` у завершающего шага.
  final double? value;

  /// Что сейчас делается. `null` у завершающего шага.
  final String? text;

  /// Ответ работы. Осмыслен только при [isDone].
  final Res? done;

  /// Работа кончилась, и кончилась успешно.
  ///
  /// Оборванная работа этого шага **не** отдаёт вовсе: «готово» означает
  /// целый магазин, и выдать незавершённое за завершённое дороже, чем
  /// показать отказ.
  final bool isDone;
}

/// Переводит операции в кадры и обратно.
final class WtDispatcher {
  const WtDispatcher(this._streams, {SessionTokenStorage? tokens})
    : _tokens = tokens;

  final WtStreams _streams;

  /// Читатель сеансового токена терминала, если браузерный регистр поднялся.
  /// На VM (тесты, кассе) это всегда `null`.
  final SessionTokenStorage? _tokens;

  /// Спросить один раз. Поток закрывается сразу после ответа.
  Future<Res> ask<Req, Res>(Ask<Req, Res> op, Req request) async {
    final stream = await _streams.openStream();
    try {
      // Токен кладётся в конверт кадра, отдельно от тела. Отсутствующий и
      // пустой токен касса не различает — `WireGuard.check` отвечает «нужен
      // сеанс» на оба одинаково (ветка `SessionAccess` в `WireGuard.check`).
      await stream.send(
        RequestFrame(
          op.name,
          op.encode(request),
          token: _tokens?.read(),
        ).encode(),
      );
      // Половина отправки закрывается **до** ожидания ответа: пока она открыта,
      // касса запроса не видит вовсе. Почему — на `WtStream.finishSending`;
      // измерено в браузере 2026-08-05.
      await stream.finishSending();

      final String raw;
      try {
        raw = await stream.frames.first;
      } on StateError {
        // Поток закрылся, не ответив: касса перезапустилась посреди обмена.
        // Без этого `first` бросил бы `StateError`, который никакой `catch`
        // в вызывающем коде не ловит, — тот самый класс отказа, что белил
        // экран.
        throw const WtProtocolError(
          'no_answer',
          'поток закрылся, не ответив ни одним кадром',
        );
      }

      final frame = WireFrame.decode(raw);
      return switch (frame) {
        OkFrame(:final body) => _decode(op, body),
        ErrorFrame(:final code, :final detail) => throw _errorFor(code, detail),
        _ => throw WtProtocolError(
          'not_a_frame',
          'на вопрос ответили кадром рода ${frame.runtimeType}',
        ),
      };
    } finally {
      await stream.close();
    }
  }

  /// Подписаться на состояние.
  ///
  /// Первый кадр — текущее значение, дальнейшие — изменения. Отписка
  /// закрывает поток: иначе касса продолжает слать в экран, которого больше
  /// нет, а подписки копятся молча и живут дольше своих экранов.
  Stream<Res> watch<Req, Res>(Watch<Req, Res> op, Req request) {
    return _exchange<Req, Res, Res>(
      op,
      request,
      onFrame: (frame, sink) {
        switch (frame) {
          case UpdateFrame(:final body):
            sink.value(() => _decode(op, body));
          case ErrorFrame(:final code, :final detail):
            sink.failure(_errorFor(code, detail));
          default:
            sink.failure(
              WtProtocolError(
                'not_a_frame',
                'подписке ответили кадром рода ${frame.runtimeType}',
              ),
            );
        }
      },
      // Тихо завершившийся поток означает для экрана, что состояние
      // окончательное. Оборванная сессия — не окончательное состояние, и
      // выдать одно за другое значит показать устаревшее как свежее.
      onEnded: const WtProtocolError(
        'stream_ended',
        'подписка оборвалась — состояние больше не приходит',
      ),
    );
  }

  /// Длинная работа: кадры хода выполнения и один завершающий.
  Stream<RunProgress<Res>> run<Req, Res>(Run<Req, Res> op, Req request) {
    return _exchange<Req, Res, RunProgress<Res>>(
      op,
      request,
      onFrame: (frame, sink) {
        switch (frame) {
          case ProgressFrame(:final value, :final text):
            sink.value(() => RunProgress<Res>.step(value, text));
          case DoneFrame(:final body):
            sink.value(() => RunProgress<Res>.finished(_decode(op, body)));
            sink.finish();
          case ErrorFrame(:final code, :final detail):
            sink.failure(_errorFor(code, detail));
          default:
            sink.failure(
              WtProtocolError(
                'not_a_frame',
                'работе ответили кадром рода ${frame.runtimeType}',
              ),
            );
        }
      },
      // Обрыв на середине обязан остаться обрывом.
      onEnded: const WtProtocolError(
        'run_incomplete',
        'работа оборвалась, не сказав «готово»',
      ),
    );
  }

  /// Общая часть [watch] и [run]: открыть поток, задать вопрос, разбирать
  /// кадры до конца обмена, закрыть поток ровно один раз.
  Stream<Out> _exchange<Req, Res, Out>(
    WireOp<Req, Res> op,
    Req request, {
    required void Function(WireFrame frame, _FrameSink<Out> sink) onFrame,
    required WtProtocolError onEnded,
  }) {
    late final StreamController<Out> controller;
    WtStream? stream;
    StreamSubscription<String>? frames;
    var over = false;

    Future<void> shutDown() async {
      if (over) return;
      over = true;
      await frames?.cancel();
      frames = null;
      await stream?.close();
      stream = null;
    }

    controller = StreamController<Out>(
      onListen: () async {
        try {
          final opened = await _streams.openStream();
          if (over) {
            // Отписались, пока поток открывался. Оставить его открытым
            // значило бы завести подписку, которую уже некому снять.
            await opened.close();
            return;
          }
          stream = opened;
          // Токен кладётся в конверт кадра, отдельно от тела. Отсутствующий и
          // пустой токен касса не различает — ветка `SessionAccess` в
          // `WireGuard.check` отвечает «нужен сеанс» на оба одинаково.
          await opened.send(
            RequestFrame(
              op.name,
              op.encode(request),
              token: _tokens?.read(),
            ).encode(),
          );
          // Та же причина, что и в [ask], и для подписки она не мягче: касса
          // читает запрос целиком, прежде чем он станет событием, — а значит
          // подписка, не закрывшая свою половину отправки, не заводится вовсе.
          // Половина приёма остаётся открытой, и обновления идут по ней.
          await opened.finishSending();

          final sink = _FrameSink<Out>(controller, shutDown);
          frames = opened.frames.listen(
            (raw) => onFrame(WireFrame.decode(raw), sink),
            onError: (Object error) =>
                sink.failure(WtProtocolError('stream_failed', '$error')),
            onDone: () => sink.ended(onEnded),
          );
        } on Object catch (error) {
          if (!controller.isClosed) {
            controller.addError(
              error is WtProtocolError
                  ? error
                  : WtProtocolError('no_session', '$error'),
            );
            await controller.close();
          }
          await shutDown();
        }
      },
      onCancel: shutDown,
    );

    return controller.stream;
  }

  /// Разбор тела в ответ операции.
  ///
  /// `on Object`, а не `on Exception`: `body['text']! as String` над картой
  /// без `text` даёт `TypeError`, который Exception'ом не является и мимо
  /// `on Exception` проходит насквозь. Именно эта форма отказа белила экран.
  static Res _decode<Req, Res>(WireOp<Req, Res> op, Map<String, Object?> body) {
    try {
      return op.decode(body);
    } on Object catch (error) {
      throw WtProtocolError(
        'bad_body',
        'ответ на ${op.name} не разобрался: $error',
      );
    }
  }
}

/// Единственное место провода, где код кассы `unauthorized` становится
/// именованным исключением [SessionLost], а не рядовым [WtProtocolError].
///
/// Только `unauthorized` — код [WireDenied.unauthorized]
/// (`lib/domain/wire/wire_guard.dart`) для «нет сеанса» и «сеанс
/// неизвестен/истёк», лечится входом заново. Сосед `forbidden`
/// ([WireDenied.forbidden] — сеанс живой, права не хватает) сюда нарочно не
/// попадает: тот же кассир с той же учёткой, войдя заново, получит тот же
/// отказ, и уводить его на экран входа значило бы завести круг вместо
/// починки. `forbidden` остаётся рядовым [WtProtocolError] и идёт прежним
/// путём отказа операции.
///
/// [ask], [watch] и [run] заводят каждый свой `ErrorFrame`-разбор — общего
/// узла для всех трёх кадр не проходит, — но три вызова этой функции лучше
/// одного и того же сравнения с литералом `'unauthorized'`, вписанного в
/// каждый разбор заново: разойдись оно в одном месте — и один из трёх родов
/// обмена продолжит доставлять истёкший сеанс обычным отказом.
Object _errorFor(String code, String detail) => code == 'unauthorized'
    ? SessionLost(detail)
    : WtProtocolError(code, detail);

/// Куда разбор кадров складывает свои итоги.
///
/// Отдельный тип, потому что [WtDispatcher._exchange] обязан закрывать поток
/// ровно один раз, и решение «обмен окончен» принимается в трёх местах:
/// завершающий кадр, кадр отказа, конец потока.
final class _FrameSink<Out> {
  _FrameSink(this._controller, this._shutDown);

  final StreamController<Out> _controller;
  final Future<void> Function() _shutDown;
  var _finished = false;

  /// Значение, которое ещё надо получить: разбор может отказать, и тогда это
  /// отказ обмена, а не падение.
  void value(Out Function() build) {
    if (_controller.isClosed) return;
    try {
      _controller.add(build());
    } on WtProtocolError catch (error) {
      failure(error);
    }
  }

  /// `Object`, а не `WtProtocolError`: [_errorFor] может отдать сюда
  /// [SessionLost] — исключение, которое обязано доехать до вызывающего
  /// нетронутым, а не быть заново обёрнутым в [WtProtocolError].
  void failure(Object error) {
    if (_controller.isClosed) return;
    _controller.addError(error);
    finish();
  }

  /// Обмен окончен по существу — закрываем поток и подписчика.
  void finish() {
    if (_finished) return;
    _finished = true;
    unawaited(
      _shutDown().then((_) {
        if (!_controller.isClosed) _controller.close();
      }),
    );
  }

  /// Поток кончился сам. Если обмен по существу не был окончен — это отказ.
  void ended(WtProtocolError reason) {
    if (_finished || _controller.isClosed) return;
    _controller.addError(reason);
    finish();
  }
}
