import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/wire/wire_frame.dart';

/// Кадры провода и их разбор.
///
/// Главное утверждение набора — **разбор не бросает никогда**. Оно взято не из
/// вкуса: 2026-08-04 на HTTP `jsonDecode` бросил `FormatException` над
/// страницей 404, и та прошла мимо всех `catch (ApiException)` в вызывающем
/// коде. Кассир увидел белый экран без единого слова — ни причины, ни адреса,
/// ни кода ответа. На новом проводе этот класс отказа закрыт в самом разборе,
/// а не в каждом из десяти мест, которые его зовут.
void main() {
  group('разбор не бросает', () {
    test('не-JSON становится кадром отказа', () {
      final frame = WireFrame.decode('<!DOCTYPE html><html>404</html>');

      expect(frame, isA<ErrorFrame>());
      expect((frame as ErrorFrame).code, 'not_a_frame');
      expect(frame.detail, isNotEmpty, reason: 'причина обязана быть названа');
    });

    test('пустой кадр — тоже отказ, а не пустой ответ', () {
      // «Ничего не пришло» и «пришёл пустой ответ» — разные вещи. Выдать
      // первое за второе значит показать пустой экран вместо причины.
      expect(WireFrame.decode(''), isA<ErrorFrame>());
    });

    test('JSON, который не объект, — отказ', () {
      // Массив или число на месте кадра означают, что отвечает не тот, кого
      // спрашивали: прокси, портал гостевого Wi-Fi, чужой сервис на порту.
      expect(WireFrame.decode('[1,2,3]'), isA<ErrorFrame>());
      expect(WireFrame.decode('42'), isA<ErrorFrame>());
    });

    test('объект без узнаваемого рода — отказ, а не молчаливый пропуск', () {
      // Касса новее терминала — обычное состояние при обновлении по одной
      // машине. Неизвестный кадр обязан быть виден, иначе обмен зависает.
      expect(WireFrame.decode('{"что-то":"иное"}'), isA<ErrorFrame>());
    });

    test('токен не строка молча игнорируется, decode не бросает', () {
      // Токен может быть числом или объектом: недопустимое значение молча
      // проигнорировать безопаснее, чем принять. Проверка всё равно откажет
      // по отсутствию сеанса. Главное — разбор не бросает.
      final decoded1 = WireFrame.decode('{"op":"test","body":{},"token":123}');
      expect(decoded1, isA<RequestFrame>());
      expect((decoded1 as RequestFrame).token, isNull);

      final decoded2 = WireFrame.decode(
        '{"op":"test","body":{},"token":{"key":"val"}}',
      );
      expect(decoded2, isA<RequestFrame>());
      expect((decoded2 as RequestFrame).token, isNull);
    });
  });

  group('круг туда-обратно', () {
    test('запрос', () {
      final frame = RequestFrame('setup.state', const {'since': 1});
      final back = WireFrame.decode(frame.encode());

      expect(back, isA<RequestFrame>());
      expect((back as RequestFrame).op, 'setup.state');
      expect(back.body, {'since': 1});
    });

    test('ответ', () {
      final back = WireFrame.decode(OkFrame(const {'n': 2}).encode());

      expect(back, isA<OkFrame>());
      expect((back as OkFrame).body, {'n': 2});
    });

    test('отказ сохраняет код и подробность', () {
      // По коду отличают «нет такой операции» от «обработчик упал», и это
      // разные действия оператора.
      final back = WireFrame.decode(
        ErrorFrame('unknown_op', 'нет операции demo').encode(),
      );

      expect(back, isA<ErrorFrame>());
      expect((back as ErrorFrame).code, 'unknown_op');
      expect(back.detail, 'нет операции demo');
    });

    test('изменение', () {
      final back = WireFrame.decode(UpdateFrame(const {'n': 3}).encode());

      expect(back, isA<UpdateFrame>());
      expect((back as UpdateFrame).body, {'n': 3});
    });

    test('ход выполнения', () {
      final back = WireFrame.decode(
        ProgressFrame(0.5, 'Восстановление...').encode(),
      );

      expect(back, isA<ProgressFrame>());
      expect((back as ProgressFrame).value, 0.5);
      expect(back.text, 'Восстановление...');
    });

    test('завершение', () {
      final back = WireFrame.decode(DoneFrame(const {'ok': true}).encode());

      expect(back, isA<DoneFrame>());
      expect((back as DoneFrame).body, {'ok': true});
    });

    test('токен едет конвертом и переживает круг', () {
      const frame = RequestFrame('terminals.rename', {
        'name': 'Касса',
      }, token: 'tok-1');

      final back = WireFrame.decode(frame.encode());

      expect(back, isA<RequestFrame>());
      expect((back as RequestFrame).token, 'tok-1');
      expect(back.body, {'name': 'Касса'});
    });

    test('кадр без токена разбирается по-прежнему', () {
      const frame = RequestFrame('startup.boot', {});

      final back = WireFrame.decode(frame.encode()) as RequestFrame;

      expect(back.token, isNull);
    });

    test('токен не смешивается с телом операции', () {
      // Тело принадлежит операции: её кодировщик волен положить туда что
      // угодно, включая ключ с именем token. Конверт обязан остаться отдельно.
      const frame = RequestFrame('x', {
        'token': 'довод операции',
      }, token: 'настоящий');

      final back = WireFrame.decode(frame.encode()) as RequestFrame;

      expect(back.token, 'настоящий');
      expect(back.body['token'], 'довод операции');
    });
  });

  group('сериализованная форма', () {
    test('кадр без токена не содержит ключа token в сыром JSON', () {
      // Пустого ключа в кадре быть не должно. Разница между отсутствующим
      // ключом и {"token": null} сохраняется на сериализованном уровне,
      // хотя в круге туда-обратно она стирается. Принимающей стороне это не
      // важно: `WireGuard.check` отвечает «нужен сеанс» и на `null`, и на
      // пустую строку одинаково (ветка `SessionAccess` в `WireGuard.check`).
      const frame = RequestFrame('test.op', {});

      final encoded = frame.encode();
      final decoded = jsonDecode(encoded) as Map<String, Object?>;

      expect(
        decoded.containsKey('token'),
        false,
        reason: 'пустого ключа быть не должно',
      );
      expect(
        encoded.contains('"token"'),
        false,
        reason: 'строка не должна содержать подстроку "token"',
      );
    });

    test('null в поле token на разборе молча превращается в отсутствие', () {
      // {"token": null} эквивалентен отсутствию ключа. На разборе оба дают
      // RequestFrame с token == null.
      final backNull = WireFrame.decode('{"op":"test","body":{},"token":null}');
      final backAbsent = WireFrame.decode('{"op":"test","body":{}}');

      expect(backNull, isA<RequestFrame>());
      expect((backNull as RequestFrame).token, isNull);
      expect(backAbsent, isA<RequestFrame>());
      expect((backAbsent as RequestFrame).token, isNull);
    });
  });

  group('ход выполнения не выдумывается', () {
    test('значение вне 0..1 отвергается на разборе', () {
      // Полоса, ушедшая за край, — признак того, что число придумали.
      // Лучше показать отказ, чем нарисовать 900 процентов.
      expect(
        WireFrame.decode('{"kind":"progress","value":9,"text":"x"}'),
        isA<ErrorFrame>(),
      );
      expect(
        WireFrame.decode('{"kind":"progress","value":-1,"text":"x"}'),
        isA<ErrorFrame>(),
      );
    });

    test('края допустимы', () {
      expect(
        WireFrame.decode('{"kind":"progress","value":0,"text":"x"}'),
        isA<ProgressFrame>(),
      );
      expect(
        WireFrame.decode('{"kind":"progress","value":1,"text":"x"}'),
        isA<ProgressFrame>(),
      );
    });

    test('целое число тоже принимается', () {
      // JSON не различает 1 и 1.0, и отвергать целое значило бы падать на
      // границе, которую сам же и обещал допускать.
      final frame = WireFrame.decode(
        '{"kind":"progress","value":1,"text":"x"}',
      );

      expect((frame as ProgressFrame).value, 1.0);
    });
  });
}
