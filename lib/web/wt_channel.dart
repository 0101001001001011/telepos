/// Договор браузерного конца провода — без единого платформенного импорта.
///
/// # Почему это отдельный файл от `wt_session.dart`
///
/// `wt_session.dart` тянет `dart:js_interop`, которого на VM не существует:
/// файл, его импортировавший, не собирается под `flutter test` вовсе. Пока
/// договор жил бы там же, ни диспетчер, ни опора, ни экран нельзя было бы
/// проверить иначе как в браузере — а браузерный прогон на этом проекте
/// (Windows, Flutter 3.32.4) до первого теста не доходит по дефекту самого
/// `flutter_tools`, см. `docs/internal/testing-notes.md`. Отделение договора от его
/// единственной браузерной реализации стоит одного файла и возвращает
/// проверяемость всему, что не есть вызов конструктора `WebTransport`.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:telepos/core/errors/named_refusal.dart';

/// Один двунаправленный поток к кассе.
///
/// Соответствие ответа запросу даёт сам поток: отвечать некуда, кроме как в
/// него. Поэтому здесь нет ни идентификаторов, ни книги учёта — её нечем было
/// бы проверить, и она была бы ещё одним местом, где два конца расходятся
/// молча.
abstract interface class WtStream {
  /// Пишет один кадр. Поток при этом **не** закрывается.
  Future<void> send(String frame);

  /// Закрывает **свою половину отправки**, оставляя половину приёма открытой.
  ///
  /// Без этого вызова касса запроса не увидит вовсе, и это не соглашение, а
  /// устройство приёма: `rk_quic` читает поток целиком
  /// (`transport.rs`, `read_bi_stream`: `recv.read_to_end`), прежде чем он
  /// станет событием `StreamData`, — половина сообщения выглядела бы как целое.
  /// Конец потока для него и есть «терминалу больше нечего сказать».
  ///
  /// Измерено в настоящем браузере 2026-08-05, стендом
  /// `test/manual/wt_stand.dart`: тот же самый кадр `startup.boot` **без**
  /// закрытия половины отправки не получил ответа за пять секунд, **с**
  /// закрытием получил `{"ok":true,"body":{"status":"success"}}`. До этого
  /// провод проверялся только петлёй на VM, а она отдавала кадр кассе прямо из
  /// [send] — и потому была зелёной при неработающем проводе.
  ///
  /// Подписку это не снимает: `TillWire` читает `streamClosed` именно как
  /// «запрос дочитан», а не как отписку (см. `TillSubscriptions`), и обновления
  /// продолжают идти в половину приёма, которая остаётся открытой.
  ///
  /// Повторный вызов не ошибка.
  Future<void> finishSending();

  /// Кадры, приходящие из потока, уже нарезанные.
  Stream<String> get frames;

  /// Закрывает обе половины. Повторный вызов не ошибка.
  Future<void> close();
}

/// Источник потоков — всё, что диспетчеру нужно знать о сессии.
///
/// Диспетчер не знает о браузере ничего: он знает этот договор. Поэтому его
/// поведение проверяется на VM, а браузерным остаётся только подъём сессии.
abstract interface class WtStreams {
  /// Открывает новый двунаправленный поток под один обмен.
  Future<WtStream> openStream();

  /// Завершается, когда сессии больше нет.
  ///
  /// `Future`, а не `Stream`: сессия закрывается один раз. Поток из одного
  /// события — обещание, что их может быть больше, а их не может, и это
  /// обещание пришлось бы поддерживать каждому, кто его слушает.
  Future<void> get closed;

  /// Закрывает сессию.
  Future<void> close();
}

/// Сессии нет, и вот почему.
///
/// Значение, а не исключение (И144). За 2026-08-04 на этом же месте найдено
/// три дефекта, и каждый белил экран целиком: причина была в логе и не была на
/// экране. Отсюда она обязана дойти до экрана — `WtUnavailableScreen`.
final class WtUnavailable {
  const WtUnavailable(this.reason);

  /// Названная причина, годная к показу человеку.
  ///
  /// Пустой она не бывает: «не получилось» без продолжения — это тот же белый
  /// экран, только с рамкой.
  final String reason;

  @override
  String toString() => 'WtUnavailable($reason)';
}

/// Ответ не разобрался, или его не было вовсе.
///
/// Исключение, а не значение, и это не противоречие И144: значением приходит
/// **отсутствие сессии** — состояние, которое экран показывает. Отказ внутри
/// уже поднятой сессии приходит туда, где вызывающий и так ждёт результата:
/// в `Future` вопроса или в `Stream` подписки. Другого канала у них нет.
///
/// [NamedRefusal]: на экран через `safeErrorText` уходит код, а не имя типа —
/// в dart2js оно минифицировано, и кассир читал «Ошибка сохранения:
/// minified:du» вместо названной кассой причины (живая приёмка 2026-09-13).
final class WtProtocolError implements Exception, NamedRefusal {
  const WtProtocolError(this.code, this.detail);

  /// Код кассы (`unknown_op`, `handler_failed`) либо код разбора
  /// (`not_a_frame`, `bad_body`, `no_answer`, `stream_ended`, `no_session`).
  ///
  /// Отделён от подробности намеренно: по коду отличают «нет такой операции»
  /// от «обработчик упал», и это разные действия оператора.
  @override
  final String code;

  final String detail;

  @override
  String get reasonText => detail;

  @override
  String toString() => 'WtProtocolError($code: $detail)';
}

/// Отпечаток листа из шестнадцатеричной строки в тридцать два байта.
///
/// `serverCertificateHashes` берёт байты, а касса кладёт в документ строку.
/// Это единственное место перевода, и ошибиться в нём значит не открыть ни
/// одной сессии при полностью исправной кассе — отказ, который выглядит
/// сетевым и ищется не там.
///
/// `null` — строка не является отпечатком SHA-256. Обрезанный или дополненный
/// массив не отдаётся: пин на половину отпечатка — это пин ни на что.
Uint8List? parseCertificateHash(String hex) {
  // Двоеточия ставят `openssl` и все браузеры; рано или поздно отпечаток
  // вставят именно в этом виде.
  final cleaned = hex.replaceAll(':', '').replaceAll(RegExp(r'\s'), '');
  if (cleaned.length != 64) return null;

  final bytes = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    final byte = int.tryParse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
    if (byte == null) return null;
    bytes[i] = byte;
  }
  return bytes;
}

/// Хост для URL WebTransport — литерал IPv6 в скобках, всё прочее как есть.
///
/// `https://::1:1234/x` не читается как «хост `::1`, порт `1234`»: в URL
/// двоеточие само по себе разделяет хост и порт, и цепочка из нескольких
/// двоеточий обваливает разбор до синтаксической ошибки конструктора, а не
/// до отказа соединения. Найдено живой проверкой задачи 8
/// (`test/manual/wt_auth_probe.dart`): единственный путь, где слушатель QUIC
/// стенда на этой машине вообще отвечал, — `::1`, и до этой правки
/// `WtSession.open` не собирал по нему вызов вовсе.
///
/// Признак — не длина и не число двоеточий, а сам факт хотя бы одного:
/// доменные имена и IPv4 двоеточий не содержат никогда, а IPv6 — всегда, в
/// любой форме (полной, свёрнутой, с `%zone`).
///
/// # Зона кодируется по RFC 6874
///
/// `%` перед зоной (`fe80::1%eth0`) в URL сам по себе браузер не примет —
/// RFC 6874 требует `%25` вместо голого `%`. Уже закодированный вход
/// (`%25eth0`) второй раз не кодируется — иначе зона доехала бы как `%2525eth0`.
String bracketHostForUrl(String host) {
  if (!host.contains(':')) return host;
  // `(?!25)` — не трогать `%`, за которым уже стоит `25`: он закодирован.
  final zoneEncoded = host.replaceAll(RegExp(r'%(?!25)'), '%25');
  return '[$zoneEncoded]';
}

/// Как поднимается сессия. Отдаёт [WtStreams] либо [WtUnavailable].
typedef WtSessionOpener = Future<Object> Function();

/// Опора, переживающая обрыв.
///
/// Сессия одна на терминал, а не одна на вопрос: поднимать её на каждый обмен
/// значило бы платить рукопожатием QUIC за каждое нажатие. Но она смертна —
/// уснувший ноутбук, ушедшая сеть, перезапуск кассы, — и после смерти
/// следующий вопрос обязан уехать, а не упереться в закрытую сессию.
///
/// # Почему попыток конечное число
///
/// Бесконечное переподнятие выглядит как работающий терминал с пустым
/// экраном — ровно то состояние, которое этот проект трижды ловил за один
/// день. Исчерпав попытки, опора отвечает [WtUnavailable] с причиной, и
/// дальше решает человек: [retry] — это кнопка на экране, а не таймер.
final class WtLink implements WtStreams {
  WtLink(
    this._opener, {
    this.attempts = 3,
    this.pause = const Duration(milliseconds: 500),
  }) : assert(attempts > 0, 'ноль попыток — это отказ, а не настройка');

  final WtSessionOpener _opener;

  /// Сколько раз подряд пытаться поднять сессию, прежде чем назвать отказ.
  final int attempts;

  /// Пауза между попытками.
  final Duration pause;

  WtStreams? _live;
  Future<Object>? _opening;
  WtUnavailable? _lastFailure;

  /// Последний названный отказ — то, что показывает экран.
  WtUnavailable? get lastFailure => _lastFailure;

  /// Живая сессия либо названная причина её отсутствия.
  Future<Object> session() {
    final live = _live;
    if (live != null) return Future.value(live);

    // Одновременные вопросы не поднимают вторую сессию: без этого первый
    // экран терминала открыл бы столько сессий, сколько на нём подписок.
    return _opening ??= _openWithRetries().whenComplete(() => _opening = null);
  }

  /// Забыть исчерпанные попытки и попробовать снова. Кнопка «Повторить».
  Future<Object> retry() {
    _lastFailure = null;
    return session();
  }

  @override
  Future<WtStream> openStream() async {
    final outcome = await session();
    if (outcome is WtStreams) return outcome.openStream();

    // Поток, отданный в никуда, увёл бы отказ на предел простоя вместо того,
    // чтобы назвать его сразу.
    throw WtProtocolError('no_session', (outcome as WtUnavailable).reason);
  }

  @override
  Future<void> get closed async {
    final live = _live;
    if (live == null) return;
    await live.closed;
  }

  @override
  Future<void> close() async {
    final live = _live;
    _live = null;
    await live?.close();
  }

  Future<Object> _openWithRetries() async {
    for (var attempt = 1; attempt <= attempts; attempt++) {
      Object outcome;
      try {
        outcome = await _opener();
      } on Object catch (error) {
        // Открыватель обязан отвечать значением, но упавший открыватель не
        // должен превращать названный отказ в белый экран.
        outcome = WtUnavailable('подъём сессии сорвался: $error');
      }

      if (outcome is WtStreams) {
        _live = outcome;
        _lastFailure = null;
        // Смерть сессии обязана быть замечена без вопроса: иначе следующий
        // обмен узнает о ней отказом записи, а подписки — вообще никогда.
        unawaited(
          outcome.closed.then((_) {
            if (identical(_live, outcome)) _live = null;
          }),
        );
        return outcome;
      }

      _lastFailure = outcome as WtUnavailable;
      if (attempt < attempts && pause > Duration.zero) {
        await Future<void>.delayed(pause);
      }
    }

    return _lastFailure!;
  }
}
