/// Отложенный чек между кассами: подъём обязан быть исключительным.
///
/// # Сценарий заказчика 2026-09-19
///
/// Покупатель набрал корзину на кассе 1, что-то забыл — чек отложили, чтобы
/// не держать очередь. Вернулся, а там очередь; пошёл на кассу 2, и она
/// обязана поднять ту самую корзину. Деньги получает касса 2: продажи до
/// этого не было, спорить не о чем.
///
/// # Чем это опасно и что здесь мерится
///
/// Как только корзина видна двум кассам, её могут поднять **обе** — кассир
/// на кассе 1 решит, что покупатель вернулся, и пробьёт параллельно. Одна
/// корзина продастся дважды. Опрос раз в пять минут этого не ловит: вторая
/// касса узнает о подъёме через минуты.
///
/// Поэтому подъём — «сравни и запиши» по ревизии документа. Проверка на
/// сервере и атомарна. Здесь мерится именно она: **два занятия одного чека,
/// и ровно одно обязано победить**.
///
/// # Чего эти пробы НЕ доказывают
///
/// Что корзина появилась на экране кассы 2: приём отложенных в пул (шаг 4а)
/// и показ — отдельная работа, названная в плане. Здесь только замок.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/logging/app_talker.dart' as app_log;
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/sync/couchdb_document_mapper.dart';
import 'package:telepos/data/sync/couchdb_sync_coordinator.dart';
import 'package:telepos/data/sync/couchdb_sync_engine.dart';

import '../../emulators/couchdb/emulator.dart';

void main() {
  late CouchDbEmulator emulator;
  late AppDatabase db;
  late CouchDbSyncCoordinator coordinator;

  const receiptNo = 77;
  const homePos = 1; // касса, на которой чек отложили
  const otherPos = 2; // касса, на которую пришёл покупатель

  setUp(() async {
    if (!app_log.isLoggerReady) app_log.installLogger(Talker());
    SharedPreferences.setMockInitialValues({});
    emulator = CouchDbEmulator();
    await emulator.start();

    db = AppDatabase.forTesting(NativeDatabase.memory());
    final engine = CouchDbSyncEngine(
      prefs: await SharedPreferences.getInstance(),
    );
    await engine.initialize(
      url: emulator.baseUrl,
      dbName: emulator.dbName,
      username: 'нет',
      password: 'нет',
    );
    coordinator = CouchDbSyncCoordinator(db: db, engine: engine);

    // Отложенный чек кассы 1 уже на сервере и свободен.
    emulator.seed(CouchDbDocumentMapper.saleDocId(receiptNo, homePos), {
      'type': 'sale',
      'receipt_no': receiptNo,
      'pos_id': homePos,
      'state': 3,
      'claimed_by_pos_id': null,
      'products': [
        {'ucode': 100, 'quantity': '2.000', 'price': '500.00'},
      ],
    });
  });

  tearDown(() async {
    await db.close();
    await emulator.stop();
  });

  test('свободный чек занимается — это предпосылка остальных проб', () async {
    final loser = await coordinator.claimDeferred(
      receiptNo: receiptNo,
      posId: homePos,
      byPosId: otherPos,
    );

    expect(loser, isNull, reason: 'null означает «занял я»');
    expect(
      CouchDbDocumentMapper.claimedByPosId(
        emulator.document(CouchDbDocumentMapper.saleDocId(receiptNo, homePos))!,
      ),
      otherPos,
    );
  });

  test('ВТОРОЕ занятие проигрывает и НАЗЫВАЕТ победителя', () async {
    // Касса 2 успела первой.
    await coordinator.claimDeferred(
      receiptNo: receiptNo,
      posId: homePos,
      byPosId: otherPos,
    );

    // Касса 1 пытается поднять тот же чек — кассир решил, что покупатель
    // вернулся. До этой работы обе подняли бы, и корзина продалась бы дважды.
    final loser = await coordinator.claimDeferred(
      receiptNo: receiptNo,
      posId: homePos,
      byPosId: homePos,
    );

    expect(
      loser,
      otherPos,
      reason: 'проигравший обязан узнать НОМЕР кассы, а не просто отказ',
    );
  });

  test('занявший может занять свой же чек повторно', () async {
    // Иначе повтор команды (сеть моргнула, кассир нажал дважды) выглядел бы
    // как «чек занял кто-то другой» и отбирал бы у кассы её собственную
    // корзину.
    await coordinator.claimDeferred(
      receiptNo: receiptNo,
      posId: homePos,
      byPosId: otherPos,
    );
    final again = await coordinator.claimDeferred(
      receiptNo: receiptNo,
      posId: homePos,
      byPosId: otherPos,
    );

    expect(again, isNull);
  });

  test('гонка: занятие соседа ВНУТРИ окна — мы проигрываем', () async {
    // Настоящая гонка, а не её пересказ: соседняя касса записывает занятие
    // между чтением документа и записью нашего. Без ревизии в записи мы
    // затёрли бы её отметку и обе кассы считали бы чек своим.
    final docId = CouchDbDocumentMapper.saleDocId(receiptNo, homePos);
    emulator.onBeforePutDocument = (id) async {
      if (id != docId) return;
      emulator.onBeforePutDocument = null;
      final doc = emulator.document(docId)!;
      emulator.seed(docId, {...doc, 'claimed_by_pos_id': homePos});
    };

    final loser = await coordinator.claimDeferred(
      receiptNo: receiptNo,
      posId: homePos,
      byPosId: otherPos,
    );

    expect(loser, homePos, reason: 'сосед успел — значит чек его');
    expect(
      CouchDbDocumentMapper.claimedByPosId(emulator.document(docId)!),
      homePos,
      reason: 'наша запись не имела права затереть чужую отметку',
    );
  });

  test('без связи занятие НЕ состоится и не солжёт', () async {
    // Исключительность негарантируема без сервера. Молчаливое «занял»
    // здесь означало бы вторую продажу той же корзины.
    await emulator.stop();

    final loser = await coordinator.claimDeferred(
      receiptNo: receiptNo,
      posId: homePos,
      byPosId: otherPos,
    );

    expect(
      loser,
      0,
      reason: '0 — «занято неизвестно кем»; null означал бы успех',
    );
  });

  test('чека нет на сервере — не занимаем и не выдумываем', () async {
    final loser = await coordinator.claimDeferred(
      receiptNo: 999,
      posId: homePos,
      byPosId: otherPos,
    );

    expect(loser, 0);
  });
}
