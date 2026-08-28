import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/wire/wire_access.dart';
import 'package:telepos/domain/wire/wire_op.dart';

/// Договор операций провода — общий для кассы и терминала.
///
/// Смысл в том, что оба конца собираются из одного описания и потому не могут
/// разойтись молча. Раньше согласование держалось на строке пути в двух местах:
/// `lib/backend/api_server.dart` объявлял маршрут, `lib/web/*` его набирал, и
/// опечатка обнаруживалась только в браузере — кодом 404, который до
/// 2026-08-04 приводил к белому экрану без единого слова.
void main() {
  test('операция знает своё имя и умеет обе стороны перевода', () {
    final op = Ask<int, String>(
      'demo.echo',
      access: OpenAccess(),
      encode: (value) => {'value': value},
      decode: (body) => body['text']! as String,
    );

    expect(op.name, 'demo.echo');
    expect(op.encode(7), {'value': 7});
    expect(op.decode({'text': 'семь'}), 'семь');
  });

  test('род операции различим по типу, а не по строке', () {
    // Разбор на кассе выбирает поведение по роду. Строковое поле позволило бы
    // прислать «watch» туда, где обработчик одноразовый, — и подписка повисла
    // бы на потоке, который никто не закроет.
    final ask = Ask<void, int>(
      'a',
      access: OpenAccess(),
      encode: (_) => const {},
      decode: (b) => 0,
    );
    final watch = Watch<void, int>(
      'w',
      access: OpenAccess(),
      encode: (_) => const {},
      decode: (b) => 0,
    );
    final run = Run<void, int>(
      'r',
      access: OpenAccess(),
      encode: (_) => const {},
      decode: (b) => 0,
    );

    expect(ask, isA<Ask<void, int>>());
    expect(watch, isA<Watch<void, int>>());
    expect(run, isA<Run<void, int>>());
    expect(watch, isNot(isA<Ask<void, int>>()));
    expect(run, isNot(isA<Watch<void, int>>()));
  });

  test('имя операции — не путь URL', () {
    // Маршрутов больше нет, есть операции. Косая черта в имени означала бы,
    // что кто-то переносит старую схему целиком, а вместе с ней и привычку
    // спрашивать там, где можно подписаться.
    final op = Ask<void, void>(
      'setup.state',
      access: OpenAccess(),
      encode: (_) => const {},
      decode: (_) {},
    );

    expect(op.name, isNot(contains('/')));
  });
}
