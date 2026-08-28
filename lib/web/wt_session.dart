/// Сессия WebTransport — единственное место, где браузерный конец провода
/// касается платформы.
///
/// # Почему здесь нет пакета
///
/// `rk_quic` — серверный конец, и он говорит это о себе прямо: `server_web.dart`
/// отвечает `unsupportedPlatform`, потому что в браузере нет ни `dart:ffi`, ни
/// UDP-сокета. Браузер по устройству WebTransport — **клиент**, а клиентский
/// `WebTransport` у него встроенный. Пакет для этого не нужен и невозможен;
/// нужны привязки, и они здесь.
///
/// # Почему всё, кроме конструктора, живёт в других файлах
///
/// `dart:js_interop` не существует на VM: файл, его импортировавший, не
/// собирается под `flutter test` вовсе. А браузерный прогон на Windows с
/// Flutter 3.32.4 не доходит до первого теста — два дефекта самого
/// `flutter_tools`, оба про разделитель пути, оба измерены 2026-08-05
/// (`docs/internal/testing-notes.md`). Значит всё, что попало сюда, проверке не
/// подлежит вовсе, и сюда попадает ровно то, что иначе никак: вызов
/// конструктора, чтение двух величин из документа и перекладывание байт между
/// `ReadableStream` и Dart.
///
/// Разбор отпечатка — в `wt_channel.dart`, нарезка кадров — в
/// `wt_framing.dart`, три рода обмена — в `wt_dispatcher.dart`, и каждое из
/// трёх покрыто набором на VM.
///
/// # Защищённый контекст
///
/// Интерфейс помечен `[SecureContext]`. На `http://127.0.0.1` он есть — петля
/// доверенная по исключению. На `http://192.168.1.50:8787` конструктора **нет
/// вовсе**: не «не соединяется», а отсутствует. Поэтому терминал на отдельном
/// устройстве требует HTTPS для самого бандла, и это отдельная работа
/// (задача 19 плана), а здесь — названная причина вместо белого экрана.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_framing.dart';

/// Порт слушателя QUIC, впрыснутый кассой в документ.
///
/// Читается тем же способом, каким `ApiClient` читает `TELEPOS_TOKEN`:
/// значение приезжает от кассы, а не набирается человеком. Отсутствует, когда
/// слушатель не поднялся, — и это состояние обязано быть названным.
@JS('TELEPOS_WT_PORT')
external JSNumber? get _injectedPort;

/// Отпечаток листа, который браузер обязан пришить.
///
/// Сертификат выписан своим удостоверяющим центром установки, и по цепочке ему
/// не верит ни один браузер. `serverCertificateHashes` — это и есть всё
/// доверие на браузерной стороне.
@JS('TELEPOS_WT_CERT_SHA256')
external JSString? get _injectedCertHash;

/// Сам конструктор. `null` означает незащищённый контекст либо старый браузер.
@JS('WebTransport')
external JSFunction? get _webTransportCtor;

@JS('WebTransport')
extension type _WebTransport._(JSObject _) implements JSObject {
  external factory _WebTransport(String url, _WtOptions options);

  external JSPromise<JSAny?> get ready;
  external JSPromise<JSAny?> get closed;
  external JSPromise<_WtBidiStream> createBidirectionalStream();
  external void close();
}

extension type _WtOptions._(JSObject _) implements JSObject {
  external factory _WtOptions({JSArray<_WtCertHash> serverCertificateHashes});
}

extension type _WtCertHash._(JSObject _) implements JSObject {
  external factory _WtCertHash({String algorithm, JSUint8Array value});
}

extension type _WtBidiStream._(JSObject _) implements JSObject {
  external _JsReadable get readable;
  external _JsWritable get writable;
}

extension type _JsReadable._(JSObject _) implements JSObject {
  external _JsReader getReader();
}

extension type _JsReader._(JSObject _) implements JSObject {
  external JSPromise<_JsReadResult> read();
  external JSPromise<JSAny?> cancel();
}

extension type _JsReadResult._(JSObject _) implements JSObject {
  external JSAny? get value;
  external bool get done;
}

extension type _JsWritable._(JSObject _) implements JSObject {
  external _JsWriter getWriter();
}

extension type _JsWriter._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> write(JSUint8Array chunk);
  external JSPromise<JSAny?> close();
}

/// Живая сессия к кассе.
final class WtSession implements WtStreams {
  WtSession._(this._transport) {
    // Смерть сессии обязана быть замечена без вопроса: уснувший ноутбук и
    // ушедшая сеть не шлют «до свидания».
    _transport.closed.toDart.then((_) => _die(), onError: (Object _) => _die());
  }

  final _WebTransport _transport;
  final _gone = Completer<void>();

  void _die() {
    if (!_gone.isCompleted) _gone.complete();
  }

  /// Путь, на котором касса слушает.
  ///
  /// Совпадает с умолчанием `startWebTransport` в
  /// `lib/data/transport/webtransport_endpoint.dart`. В документ он не
  /// впрыскивается, потому что не менялся ни разу; если начнёт — впрыскивать
  /// придётся, и лучше здесь одна названная связь, чем два молчащих умолчания.
  static const defaultPath = '/rk';

  /// Поднимает сессию по величинам, которые касса положила в документ.
  ///
  /// Никогда не бросает: отдаёт [WtSession] либо [WtUnavailable] с причиной,
  /// годной к показу человеку.
  static Future<Object> openFromDocument({String? host}) {
    final port = _injectedPort?.toDartInt;
    if (port == null) {
      return Future.value(
        const WtUnavailable(
          'касса не сообщила порт WebTransport — слушатель QUIC на ней не '
          'поднялся',
        ),
      );
    }

    return open(
      host: host ?? Uri.base.host,
      port: port,
      certSha256: _injectedCertHash?.toDart ?? '',
    );
  }

  /// Поднимает сессию. **Никогда не бросает** (И144).
  static Future<Object> open({
    required String host,
    required int port,
    required String certSha256,
    String path = defaultPath,
  }) async {
    if (_webTransportCtor == null) {
      return const WtUnavailable(
        'браузер не даёт WebTransport: страница открыта не по защищённому '
        'адресу либо браузер слишком стар',
      );
    }

    final hash = parseCertificateHash(certSha256);
    if (hash == null) {
      return WtUnavailable(
        'касса сообщила отпечаток, который не является SHA-256: '
        '«$certSha256»',
      );
    }

    try {
      final transport = _WebTransport(
        'https://${bracketHostForUrl(host)}:$port$path',
        _WtOptions(
          serverCertificateHashes: <_WtCertHash>[
            _WtCertHash(algorithm: 'sha-256', value: hash.toJS),
          ].toJS,
        ),
      );
      await transport.ready.toDart;
      return WtSession._(transport);
    } on Object catch (error) {
      // Конструктор бросает на неверном адресе, `ready` — на несошедшемся
      // отпечатке, на закрытом порте и на UDP, который съела сеть. Все они
      // для терминала одно: сессии нет, и надо сказать почему.
      // `$error` здесь называет причину, а не даёт `[object Object]`:
      // `WebTransportError` наследует `DOMException`, у которой есть свой
      // `toString`, и он выглядит как «WebTransportError: certificate hash
      // mismatch» — ровно то, что нужно человеку на экране.
      return WtUnavailable('сессия не поднялась: $error');
    }
  }

  @override
  Future<WtStream> openStream() async {
    final stream = await _transport.createBidirectionalStream().toDart;
    return _WtBidiChannel(stream);
  }

  @override
  Future<void> get closed => _gone.future;

  @override
  Future<void> close() async {
    try {
      _transport.close();
    } on Object catch (_) {
      // Закрытие закрытого — не отказ.
    }
    _die();
  }
}

/// Один двунаправленный поток: кадры туда, кадры обратно.
class _WtBidiChannel implements WtStream {
  _WtBidiChannel(_WtBidiStream stream)
    : _reader = stream.readable.getReader(),
      _writer = stream.writable.getWriter() {
    unawaited(_pump());
  }

  final _JsReader _reader;
  final _JsWriter _writer;
  final _frames = StreamController<String>();
  var _closed = false;

  /// Половина отправки уже закрыта. Второй `close()` на том же писателе
  /// отвергается самим `WritableStream`, и без этого признака обычный конец
  /// обмена выглядел бы отказом.
  var _sendingFinished = false;

  @override
  Stream<String> get frames => _frames.stream;

  @override
  Future<void> send(String frame) async {
    await _writer.write(Uint8List.fromList(utf8.encode(frame)).toJS).toDart;
  }

  @override
  Future<void> finishSending() async {
    if (_sendingFinished) return;
    _sendingFinished = true;
    try {
      // `WritableStreamDefaultWriter.close()` закрывает **только** половину
      // отправки: `readable` того же потока продолжает жить, и обновления
      // подписки приходят по ней. Почему без этого касса не видит запроса
      // вовсе — на `WtStream.finishSending`.
      await _writer.close().toDart;
    } on Object catch (_) {
      // Половина уже закрыта той стороной — обычный конец обмена, не отказ.
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await finishSending();
    try {
      await _reader.cancel().toDart;
    } on Object catch (_) {}
    if (!_frames.isClosed) await _frames.close();
  }

  /// Читает поток до конца, нарезая байты обратно на кадры.
  ///
  /// Границы записей кассы здесь не сохранены — поток QUIC это байты, — и
  /// восстанавливает их [WireFrameSplitter]. Многобайтовый знак, разорванный
  /// между выдачами, склеивается кусочным разбором UTF-8: иначе «Восстановление»
  /// посреди хода выполнения превратилось бы в ромбы с вопросами.
  Future<void> _pump() async {
    final splitter = WireFrameSplitter();
    final decoder = utf8.decoder.startChunkedConversion(
      _TextSink((text) {
        for (final frame in splitter.add(text)) {
          if (!_frames.isClosed) _frames.add(frame);
        }
      }),
    );

    try {
      while (true) {
        final result = await _reader.read().toDart;
        if (result.done) break;
        final chunk = result.value;
        if (chunk == null) continue;
        decoder.add((chunk as JSUint8Array).toDart);
      }
    } on Object catch (error) {
      if (!_frames.isClosed) _frames.addError(error);
    }

    decoder.close();
    final tail = splitter.drain();
    if (tail != null && !_frames.isClosed) {
      // Поток кончился на половине кадра. Молча выброшенный хвост означал бы
      // обмен, который просто не ответил.
      _frames.add(tail);
    }
    if (!_frames.isClosed) await _frames.close();
  }
}

/// Приёмник кусочного разбора UTF-8.
class _TextSink implements Sink<String> {
  _TextSink(this._onText);

  final void Function(String) _onText;

  @override
  void add(String data) => _onText(data);

  @override
  void close() {}
}
