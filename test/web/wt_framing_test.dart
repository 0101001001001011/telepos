import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/web/wt_framing.dart';

void main() {
  test('два кадра, приехавшие одним куском, разбираются на два', () {
    // QUIC-поток — это байты, а не сообщения. Касса пишет кадр за кадром
    // (`sendOn` на том же потоке), и ядро вправе склеить их в одну выдачу.
    // Без нарезки подписка на два обновления показала бы одно нечитаемое.
    final splitter = WireFrameSplitter();

    final frames = splitter.add(
      '{"kind":"update","body":{"n":1}}{"kind":"update","body":{"n":2}}',
    );

    expect(frames, hasLength(2));
    expect(frames.first, contains('"n":1'));
    expect(frames.last, contains('"n":2'));
  });

  test('кадр, разорванный посередине, не отдаётся половиной', () {
    // Обратная беда той же природы: половина кадра — это не кадр, но
    // выглядит как целый, потому что `jsonDecode` от неё просто откажется, и
    // терминал назовёт отказом то, что на самом деле ещё едет.
    final splitter = WireFrameSplitter();

    expect(splitter.add('{"kind":"upd'), isEmpty);
    expect(splitter.add('ate","body":{"n":7}}'), hasLength(1));
  });

  test('закрывающая скобка внутри строки кадр не обрывает', () {
    // Название точки «Склад №2}» — обычное название, а не диверсия. Счётчик
    // скобок, не знающий про строки, увидел бы здесь конец кадра и отдал бы
    // обрубок, который не разберётся: отказ при полностью исправной кассе.
    //
    // Скобки берутся НЕПАРНЫЕ намеренно. Парные («Касса {1}») переживают и
    // счётчик без знания строк — измерено мутацией 2026-08-05: тест с ними
    // проходил и на сломанном разборе, то есть не доказывал ничего.
    final splitter = WireFrameSplitter();

    final frames = splitter.add('{"body":{"name":"Склад №2}"}}');

    expect(frames, hasLength(1));
    expect(frames.single, '{"body":{"name":"Склад №2}"}}');
  });

  test('открывающая скобка внутри строки не оставляет кадр недособранным', () {
    // Обратная половина той же беды: лишняя `{` в строке заставила бы
    // счётчик ждать закрывающей вечно, и целый кадр висел бы до предела
    // простоя.
    final splitter = WireFrameSplitter();

    final frames = splitter.add('{"detail":"скидка {50"}');

    expect(frames, hasLength(1));
  });

  test('экранированная кавычка не открывает строку заново', () {
    final splitter = WireFrameSplitter();

    final frames = splitter.add(r'{"detail":"кавычка \" внутри"}');

    expect(frames, hasLength(1));
  });

  test('пробелы между кадрами пропускаются', () {
    final splitter = WireFrameSplitter();

    expect(splitter.add('{"a":1}\n {"b":2}\n'), hasLength(2));
  });

  test('не-JSON отдаётся целиком, а не копится молча', () {
    // Ровно этот класс отказа стоил белого экрана 2026-08-04: по адресу
    // отвечал не тот, кого спрашивали. Копить страницу HTML в ожидании
    // закрывающей скобки значило бы висеть до предела простоя, ничего не
    // сказав. Кадр обязан дойти до разбора, который его назовёт.
    final splitter = WireFrameSplitter();

    final frames = splitter.add('<!DOCTYPE html><html>404</html>');

    expect(frames, hasLength(1));
    expect(frames.single, startsWith('<!DOCTYPE'));
  });

  test('недособранный хвост отдаётся при закрытии потока', () {
    // Поток закрылся на половине кадра — это отказ, и он обязан быть виден.
    // Молча выброшенный хвост означал бы обмен, который просто не ответил.
    final splitter = WireFrameSplitter();
    splitter.add('{"kind":"upd');

    expect(splitter.drain(), '{"kind":"upd');
  });

  test('после чистой нарезки хвоста не остаётся', () {
    final splitter = WireFrameSplitter();
    splitter.add('{"a":1}');

    expect(splitter.drain(), isNull);
  });
}
