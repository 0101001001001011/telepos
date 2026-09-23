/// Эмулятор CouchDB обязан ОТКАЗЫВАТЬ, а не принимать всё подряд.
///
/// # Зачем проба на эмулятор
///
/// Эмулятор здесь не удобство, а измерительный прибор: им проверяются четыре
/// находки о сломанной синхронизации, и все четыре — про отказы. Прибор,
/// который всегда говорит «принято», покрасил бы их зелёным не глядя, и
/// работа выглядела бы сделанной.
///
/// Поэтому первым делом меряется не то, что эмулятор принимает, а то, что он
/// **отвергает** — и ровно так же, как настоящий CouchDB: отказом по
/// документу внутри пакета, не отказом пакета.
///
/// # Чего эта проба НЕ доказывает
///
/// Что эмулятор совпадает с CouchDB во всём. Он и не должен: дерева ревизий
/// в нём нет намеренно (докстринг `CouchDbEmulator`). Мерится совпадение в
/// той части, на которой стоит продукт, — и только она.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/datasources/remote/couchdb_client.dart';

import 'emulator.dart';

void main() {
  late CouchDbEmulator emulator;
  late CouchDbClient client;

  setUp(() async {
    emulator = CouchDbEmulator();
    await emulator.start();
    client = CouchDbClient(
      url: emulator.baseUrl,
      dbName: emulator.dbName,
      username: 'нет',
      password: 'нет',
    );
  });

  tearDown(() => emulator.stop());

  test('поднялся и отвечает на _up', () async {
    expect(await client.ping(), isTrue);
  });

  test('новый документ принимается', () async {
    final result = await client.bulkDocs([
      {'_id': 'product:1', 'name': 'Молоко'},
    ]);

    expect(result.single['ok'], isTrue);
    expect(result.single['rev'], startsWith('1-'));
    expect(emulator.document('product:1')!['name'], 'Молоко');
  });

  test('ПОВТОРНАЯ отправка без ревизии — конфликт, а не тихий успех', () async {
    // Это и есть находка 1: продукт не шлёт `_rev` НИКОГДА, поэтому вторая
    // отправка любого документа обречена. Если эмулятор здесь ответит «ok»,
    // все пробы синхронизации станут ложно-зелёными.
    await client.bulkDocs([
      {'_id': 'product:1', 'name': 'Молоко'},
    ]);

    final second = await client.bulkDocs([
      {'_id': 'product:1', 'name': 'Молоко 3.2%'},
    ]);

    expect(second.single['ok'], isNull);
    expect(second.single['error'], 'conflict');
    expect(
      emulator.document('product:1')!['name'],
      'Молоко',
      reason: 'отклонённая отправка не имеет права изменить документ',
    );
  });

  test('с верной ревизией обновление проходит', () async {
    // Обратная диверсия к предыдущей: запрет, не пропускающий никого,
    // выглядит так же зелено, как запрет, не останавливающий никого.
    final first = await client.bulkDocs([
      {'_id': 'product:1', 'name': 'Молоко'},
    ]);
    final rev = first.single['rev'] as String;

    final second = await client.bulkDocs([
      {'_id': 'product:1', '_rev': rev, 'name': 'Молоко 3.2%'},
    ]);

    expect(second.single['ok'], isTrue);
    expect(second.single['rev'], startsWith('2-'));
    expect(emulator.document('product:1')!['name'], 'Молоко 3.2%');
  });

  test('отказ ОДНОГО документа не отменяет приёма остальных', () async {
    // Несущее свойство `_bulk_docs`, на котором стоит шаг 3 спеки: очередь
    // встаёт навсегда именно потому, что продукт отмечает пакет целиком.
    // Пакетный отказ сделал бы эту находку невоспроизводимой.
    await client.bulkDocs([
      {'_id': 'занятый', 'name': 'первый'},
    ]);

    final mixed = await client.bulkDocs([
      {'_id': 'занятый', 'name': 'второй'},
      {'_id': 'свободный-1', 'name': 'a'},
      {'_id': 'свободный-2', 'name': 'b'},
    ]);

    expect(mixed, hasLength(3));
    expect(mixed[0]['error'], 'conflict');
    expect(mixed[1]['ok'], isTrue);
    expect(mixed[2]['ok'], isTrue);
    expect(
      emulator.documentCount,
      3,
      reason: 'два новых обязаны лечь, несмотря на соседний отказ',
    );
  });

  test('_all_docs по ключам отдаёт ревизии — ими живёт шаг 2', () async {
    await client.bulkDocs([
      {'_id': 'a', 'v': 1},
      {'_id': 'b', 'v': 2},
    ]);

    final docs = await client.allDocs(keys: ['a', 'b', 'нет-такого']);

    expect(docs, hasLength(2), reason: 'несуществующий не выдумывается');
    expect(docs.every((d) => (d['_rev'] as String).startsWith('1-')), isTrue);
  });

  test('_changes отдаёт всё с начала и двигает метку', () async {
    await client.bulkDocs([
      {'_id': 'a', 'v': 1},
      {'_id': 'b', 'v': 2},
    ]);

    final first = await client.getChanges();
    expect(first.results, hasLength(2));
    expect(first.results.first.doc, isNotNull);

    await client.bulkDocs([
      {'_id': 'c', 'v': 3},
    ]);

    final next = await client.getChanges(since: first.lastSeq);
    expect(
      next.results.map((r) => r.id),
      ['c'],
      reason: 'с метки приезжает только новое — иначе приём читает всё заново',
    );
  });

  test('документ без _id отклоняется названной причиной', () async {
    final result = await client.bulkDocs([
      {'name': 'без имени'},
    ]);

    expect(result.single['error'], 'bad_request');
    expect(emulator.documentCount, 0);
  });
}
