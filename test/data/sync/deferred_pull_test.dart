/// Приём чужих отложенных чеков: что берём, а что отбрасываем.
///
/// # Главная проба здесь — НЕ про приём
///
/// Она про отказ: **проданный чек соседа не принимается никогда**. Решение
/// заказчика 2026-09-19 — между кассами ездит только отложенный чек, где
/// продажи ещё нет. Прими мы проданный, у нас завелась бы чужая выручка, и
/// она попала бы в нашу смену, ящик и X/Z-отчёт. Это ровно тот род дефекта,
/// который в этом дереве ловили шесть раз подряд, и ловился он всегда
/// пробой, а не чтением.
///
/// # Чего эти пробы НЕ доказывают
///
/// Что чужой чек показан кассиру и поднимается: пул и подъём — следующая
/// работа. Здесь только то, что доезжает до базы.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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

  const ownPos = 1;
  const otherPos = 2;

  /// Документ чека соседней кассы так, как его кладёт `_pushDeferredSales`.
  Map<String, Object?> saleDoc({
    required int receiptNo,
    int posId = otherPos,
    int state = 3,
    int? claimedBy,
    List<Map<String, Object?>>? lines,
  }) => {
    'type': 'sale',
    'receipt_no': receiptNo,
    'pos_id': posId,
    'user_id': 7,
    'amount': '1000.000',
    'time': 1700000000,
    'state': state,
    'is_wholesale': false,
    'claimed_by_pos_id': claimedBy,
    'products':
        lines ??
        [
          {
            'ucode': 100,
            'barcode': 4870001234567,
            'quantity': '2.000',
            'price': '500.000',
            'price_before': '500.000',
          },
        ],
  };

  setUp(() async {
    if (!app_log.isLoggerReady) app_log.installLogger(Talker());
    SharedPreferences.setMockInitialValues({});
    emulator = CouchDbEmulator();
    await emulator.start();

    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Своя касса — номер 1: без неё координатор не знает, что «чужое».
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(ownPos),
            cashBoxName: Value('Касса-1'),
          ),
        );

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
  });

  tearDown(() async {
    await db.close();
    await emulator.stop();
  });

  Future<void> seedAndSync(Map<String, Object?> doc) async {
    emulator.seed(
      CouchDbDocumentMapper.saleDocId(
        doc['receipt_no']! as int,
        doc['pos_id']! as int,
      ),
      doc,
    );
    final result = await coordinator.syncNow();
    expect(result.ok, isTrue, reason: 'обмен обязан состояться');
  }

  test('чужой отложенный чек ложится СО СТРОКАМИ', () async {
    await seedAndSync(saleDoc(receiptNo: 501));

    final sale = await db.saleDao.findByKey(501, otherPos);
    expect(sale, isNotNull, reason: 'корзина соседа обязана доехать');
    expect(sale!.state, 3);
    expect(sale.posId, otherPos, reason: 'чек остаётся чеком соседней кассы');
    expect(
      sale.terminalId,
      isNull,
      reason: 'у отложенного владельца нет (И156), у чужого — тем более',
    );

    final lines = await db.saleProductDao.findBySale(501, otherPos);
    expect(lines, hasLength(1), reason: 'чек без строк — пустая корзина');
    expect(lines.single.ucode, 100);
    expect(
      lines.single.price,
      Decimal.parse('500.000'),
      reason: 'деньги разбираются строкой: double потерял бы третий знак',
    );
    expect(lines.single.quantity, Decimal.parse('2.000'));
  });

  test('ПРОДАННЫЙ чек соседа не принимается — иначе его выручка станет нашей',
      () async {
    await seedAndSync(saleDoc(receiptNo: 502, state: 1));

    expect(
      await db.saleDao.findByKey(502, otherPos),
      isNull,
      reason:
          'проданный чек соседа в нашей базе завёл бы чужую выручку в нашей '
          'смене, ящике и X/Z-отчёте',
    );
  });

  test('занятый соседом чек в пул не попадает', () async {
    // Его уже поднимает третья касса. Показать его кассиру значит предложить
    // то, чего он не получит.
    await seedAndSync(saleDoc(receiptNo: 503, claimedBy: 3));

    expect(await db.saleDao.findByKey(503, otherPos), isNull);
  });

  test('свой собственный чек, приехавший обратно, не применяется', () async {
    // Он уехал отсюда. Применить его значило бы затереть местную правду
    // доставкой — тот же запрет, что у бонусного журнала.
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: 600,
            posId: ownPos,
            userId: 1,
            amount: Decimal.parse('10'),
            time: 1,
            state: const Value(3),
            terminalId: const Value(42),
          ),
        );

    await seedAndSync(saleDoc(receiptNo: 600, posId: ownPos));

    final mine = await db.saleDao.findByKey(600, ownPos);
    expect(
      mine!.terminalId,
      42,
      reason: 'своя строка не имеет права меняться от доставки',
    );
  });

  test('повторная доставка не плодит строк — ключ тот же', () async {
    await seedAndSync(saleDoc(receiptNo: 504));
    await coordinator.syncNow();
    await coordinator.syncNow();

    final lines = await db.saleProductDao.findBySale(504, otherPos);
    expect(
      lines,
      hasLength(1),
      reason: 'каждый круг обмена удваивал бы корзину соседа',
    );
  });

  test('чек, который сосед продал, УБИРАЕТСЯ из нашего пула', () async {
    // Покупатель вернулся на свою кассу и там расплатился. Наш пул обязан
    // это заметить, иначе кассир будет предлагать поднять проданную корзину.
    await seedAndSync(saleDoc(receiptNo: 505));
    expect(await db.saleDao.findByKey(505, otherPos), isNotNull);

    emulator.seed(
      CouchDbDocumentMapper.saleDocId(505, otherPos),
      saleDoc(receiptNo: 505, state: 1),
    );
    await coordinator.syncNow();

    expect(
      await db.saleDao.findByKey(505, otherPos),
      isNull,
      reason: 'проданную корзину из пула надо убрать, а не показывать',
    );
    expect(await db.saleProductDao.findBySale(505, otherPos), isEmpty);
  });
}
