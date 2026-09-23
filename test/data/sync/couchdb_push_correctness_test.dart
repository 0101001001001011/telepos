/// Отправка в CouchDB против настоящего сервера: шаги 1–3 спеки.
///
/// # Почему против эмулятора, а не подделки
///
/// Три находки из четырёх — про отказы CouchDB, и подделка клиента
/// проверяла бы наше представление о них. Здесь касса говорит по HTTP с тем,
/// что отвечает как CouchDB: `409 conflict` по документу внутри пакета,
/// остальные в том же пакете принимаются.
///
/// # Что доказывает каждая проба
///
/// * шаг 1 — отказ **назван**, а не растворён в числе «принято N»;
/// * шаг 2 — второе обновление документа **доезжает**, а до правки не могло
///   доехать никогда: ревизию касса не слала вовсе;
/// * шаг 3 — один отклонённый документ **не держит** в очереди соседей.
///
/// # Чего эти пробы НЕ доказывают
///
/// Что данные соседней кассы оказались в нашей базе: приём (шаг 4) не
/// сделан, и это названо в плане, а не подразумевается.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/logging/app_talker.dart' as app_log;
import 'package:telepos/data/sync/couchdb_sync_engine.dart';

import '../../emulators/couchdb/emulator.dart';

void main() {
  late CouchDbEmulator emulator;
  late CouchDbSyncEngine engine;

  setUp(() async {
    // Журнал ставится первым: отказы движок пишет уровнем `warning`, и без
    // журнала проба упала бы на `LateInitializationError` вместо предмета.
    if (!app_log.isLoggerReady) app_log.installLogger(Talker());
    SharedPreferences.setMockInitialValues({});
    emulator = CouchDbEmulator();
    await emulator.start();
    engine = CouchDbSyncEngine(prefs: await SharedPreferences.getInstance());
    await engine.initialize(
      url: emulator.baseUrl,
      dbName: emulator.dbName,
      username: 'нет',
      password: 'нет',
    );
  });

  tearDown(() async {
    engine.dispose();
    await emulator.stop();
  });

  group('шаг 1: отказ назван', () {
    test('исход перечисляет доехавшие ПОИМЁННО, а не числом', () async {
      final result = await engine.pushDocuments([
        {'_id': 'sale:1:1', 'type': 'sale'},
        {'_id': 'sale:1:2', 'type': 'sale'},
      ]);

      expect(result.confirmedCount, 2);
      expect(result.landed('sale:1:1'), isTrue);
      expect(result.landed('sale:1:2'), isTrue);
      expect(
        result.landed('sale:1:3'),
        isFalse,
        reason: 'исход не имеет права утверждать про то, чего не посылали',
      );
      expect(result.rejected, isEmpty);
    });

    test('отклонённый назван с причиной CouchDB, а не общим словом', () async {
      final result = await engine.pushDocuments([
        {'type': 'sale'}, // без `_id` — отказ, который не разрешится никогда
      ]);

      expect(result.confirmed, isEmpty);
      expect(result.rejected, hasLength(1));
      expect(result.rejected.single.error, 'bad_request');
      expect(
        result.rejected.single.reason,
        isNotEmpty,
        reason: 'причина едет как есть: по ней разбирают, а не догадываются',
      );
      expect(
        result.rejected.single.mayResolveOnRetry,
        isFalse,
        reason: 'документ без `_id` не станет верным от повтора',
      );
    });
  });

  group('шаг 2: ревизия отправляется', () {
    test('ВТОРОЕ обновление доезжает — до правки не могло никогда', () async {
      // Это и есть находка 1. Касса не слала `_rev` вовсе, поэтому первая
      // отправка документа проходила, а каждая следующая обречена.
      await engine.pushDocuments([
        {'_id': 'product:1', 'name': 'Молоко'},
      ]);

      final second = await engine.pushDocuments([
        {'_id': 'product:1', 'name': 'Молоко 3.2%'},
      ]);

      expect(second.landed('product:1'), isTrue);
      expect(second.rejected, isEmpty);
      expect(
        emulator.document('product:1')!['name'],
        'Молоко 3.2%',
        reason: 'на сервере обязано лежать новое значение, а не старое',
      );
    });

    test('третье тоже — ревизия берётся свежая каждый раз', () async {
      // Страховка от правки, которая запоминает ревизию один раз: тогда
      // второй раз пройдёт, а третий снова упрётся в конфликт.
      for (final name in ['раз', 'два', 'три']) {
        final r = await engine.pushDocuments([
          {'_id': 'product:1', 'name': name},
        ]);
        expect(r.landed('product:1'), isTrue, reason: 'шаг «$name»');
      }
      expect(emulator.document('product:1')!['name'], 'три');
    });

    test('чужая запись между вопросом и отправкой — разрешимый отказ', () async {
      // Гонка, которую ревизии не убирают и не должны: соседняя касса
      // успевает записать своё в окне между `_all_docs` и `_bulk_docs`.
      //
      // Подсунуть устаревшую ревизию снаружи нельзя — движок обновляет её
      // прямо перед отправкой, и это верно. Первая попытка написать эту
      // пробу именно так и **провалилась**: движок подменил подсунутое, и
      // ложным оказалось утверждение пробы, а не поведение продукта.
      // Поэтому вмешательство здесь — изнутри окна.
      emulator.seed('product:1', {'name': 'чужое'});
      emulator.onBeforeBulkDocs = () async {
        emulator.seed('product:1', {'name': 'сосед успел'});
        emulator.onBeforeBulkDocs = null; // один раз, иначе круг вечен
      };

      final result = await engine.pushDocuments([
        {'_id': 'product:1', 'name': 'наше'},
      ]);

      expect(result.landed('product:1'), isFalse);
      expect(result.rejected.single.error, 'conflict');
      expect(
        result.rejected.single.mayResolveOnRetry,
        isTrue,
        reason: 'конфликт разрешится следующим кругом — документ не терять',
      );

      // И он действительно разрешается: следующий круг спрашивает ревизию
      // заново. Без этого утверждения «разрешимый» осталось бы словом.
      final again = await engine.pushDocuments([
        {'_id': 'product:1', 'name': 'наше'},
      ]);
      expect(again.landed('product:1'), isTrue);
      expect(emulator.document('product:1')!['name'], 'наше');
    });
  });

  group('шаг 3: соседей не держит', () {
    test('отказ одного не отменяет приёма остальных', () async {
      final result = await engine.pushDocuments([
        {'type': 'sale'}, // безнадёжный
        {'_id': 'sale:1:1', 'type': 'sale'},
        {'_id': 'sale:1:2', 'type': 'sale'},
      ]);

      expect(result.confirmedCount, 2);
      expect(result.landed('sale:1:1'), isTrue);
      expect(result.landed('sale:1:2'), isTrue);
      expect(result.rejected, hasLength(1));
      expect(
        emulator.documentCount,
        2,
        reason: 'два годных обязаны лечь на сервер, несмотря на соседа',
      );
    });

    test('безнадёжный документ не мешает повтору годных', () async {
      // Круг за кругом: до правки вечный отказ держал в очереди всё, очередь
      // росла без предела, и ни один документ больше не подтверждался.
      for (var i = 0; i < 3; i++) {
        final r = await engine.pushDocuments([
          {'type': 'sale'},
          {'_id': 'sale:1:$i', 'type': 'sale'},
        ]);
        expect(r.landed('sale:1:$i'), isTrue, reason: 'круг $i');
      }
      expect(emulator.documentCount, 3);
    });
  });

  test('сорвавшаяся отправка не отмечает НИЧЕГО', () async {
    // Сервер лёг между кругами: что из пакета успело лечь — неизвестно.
    // Пустой исход означает «не отмечать», и это единственный честный
    // ответ: отметить догадкой значило бы потерять документ навсегда.
    await emulator.stop();

    final result = await engine.pushDocuments([
      {'_id': 'sale:1:1', 'type': 'sale'},
    ]);

    expect(result.confirmed, isEmpty);
    expect(result.rejected, isEmpty, reason: 'это не отказ по документу');
    expect(result.anyConfirmed, isFalse);
  });
}
