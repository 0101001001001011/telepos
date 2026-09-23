/// Закрытие смены чистит отложенные чеки — решение заказчика 2026-09-19.
///
/// # Почему не кнопкой кассира
///
/// Вернётся покупатель или нет, касса знать не может, и держать корзину
/// вечно — копить мусор, который однажды поднимут. Но права удалять
/// отложенные кассиру **не дают**: он мог бы снести корзину соседней кассы,
/// а её владелец узнал бы об этом, только когда покупатель вернётся.
/// Закрытие смены — действие с собственным замком, и чистка висит на нём.
///
/// # Что здесь главное
///
/// Не то, что свои чеки исчезли, а то, что **чужие остались**. Удалить
/// чужую копию значило бы решить за соседнюю кассу, что её смена кончилась.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/shift/local_shift_desk.dart';
import 'package:telepos/domain/sale/deferred_claim_port.dart';

/// Порт, который запоминает, что у него отзывали.
class _Claim implements DeferredClaimPort {
  final withdrawn = <({int receiptNo, int posId})>[];

  @override
  Future<int?> claim({
    required int receiptNo,
    required int posId,
    required int byPosId,
  }) async => null;

  @override
  Future<void> withdraw({required int receiptNo, required int posId}) async {
    withdrawn.add((receiptNo: receiptNo, posId: posId));
  }
}

/// Порт, у которого отзыв всегда срывается — как без связи.
class _BrokenClaim implements DeferredClaimPort {
  @override
  Future<int?> claim({
    required int receiptNo,
    required int posId,
    required int byPosId,
  }) async => 0;

  @override
  Future<void> withdraw({required int receiptNo, required int posId}) async {
    throw StateError('связи нет');
  }
}

void main() {
  late AppDatabase db;
  const ownPos = 1;
  const otherPos = 2;

  Future<void> seedDeferred({required int receiptNo, required int posId}) async {
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: receiptNo,
            posId: posId,
            userId: 4,
            amount: Decimal.parse('500'),
            time: 1700000000,
            state: const Value(3),
            terminalId: const Value(null),
          ),
        );
    await db
        .into(db.saleProducts)
        .insert(
          SaleProductsCompanion.insert(
            ucode: 100,
            quantity: Decimal.parse('1.000'),
            price: Decimal.parse('500.000'),
            priceBefore: Decimal.parse('500.000'),
            receiptNo: Value(receiptNo),
            posId: Value(posId),
          ),
        );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(ownPos),
            cashBoxName: Value('Касса-1'),
          ),
        );
    await db
        .into(db.users)
        .insert(const UsersCompanion(id: Value(4), name: Value('Айгуль')));
    await db
        .into(db.shifts)
        .insert(
          ShiftsCompanion(
            userId: const Value(4),
            openTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
            isOpened: const Value(true),
            isSynced: const Value(false),
          ),
        );
  });

  tearDown(() => db.close());

  test('свои отложенные сняты, ЧУЖИЕ остались', () async {
    await seedDeferred(receiptNo: 700, posId: ownPos);
    await seedDeferred(receiptNo: 900, posId: otherPos);
    final claim = _Claim();

    await LocalShiftDesk(
      db: db,
      actorUserId: 4,
      logger: Talker(),
      claim: claim,
    ).close();

    expect(
      await db.saleDao.findByKey(700, ownPos),
      isNull,
      reason: 'свой отложенный чек снимается закрытием смены',
    );
    expect(
      await db.saleProductDao.findBySale(700, ownPos),
      isEmpty,
      reason: 'строки не имеют права пережить свой чек — это сироты',
    );
    expect(
      await db.saleDao.findByKey(900, otherPos),
      isNotNull,
      reason:
          'чужая корзина — копия соседней кассы; удалить её значит решить за '
          'неё, что её смена кончилась',
    );
  });

  test('свой чек ОТЗЫВАЕТСЯ с сервера, чужой — нет', () async {
    await seedDeferred(receiptNo: 700, posId: ownPos);
    await seedDeferred(receiptNo: 900, posId: otherPos);
    final claim = _Claim();

    await LocalShiftDesk(
      db: db,
      actorUserId: 4,
      logger: Talker(),
      claim: claim,
    ).close();

    expect(
      claim.withdrawn,
      [(receiptNo: 700, posId: ownPos)],
      reason:
          'без отзыва документ остался бы отложенным, и соседняя касса '
          'показывала бы корзину, которой уже нет',
    );
  });

  test('сорвавшийся отзыв НЕ отменяет закрытия смены', () async {
    // Остаться с незакрытой сменой хуже, чем с лишней строкой в чужом пуле:
    // она пропадёт при первом же подъёме, а незакрытая смена ломает день.
    await seedDeferred(receiptNo: 700, posId: ownPos);

    await LocalShiftDesk(
      db: db,
      actorUserId: 4,
      logger: Talker(),
      claim: _BrokenClaim(),
    ).close();

    expect(
      (await db.shiftDao.findOpenedShift()),
      isNull,
      reason: 'смена обязана закрыться, несмотря на отказ отзыва',
    );
  });

  test('обмена нет вовсе — свои чеки всё равно чистятся', () async {
    // Одна касса в магазине: отзывать не у кого, но мусор копить незачем.
    await seedDeferred(receiptNo: 700, posId: ownPos);

    await LocalShiftDesk(db: db, actorUserId: 4, logger: Talker()).close();

    expect(await db.saleDao.findByKey(700, ownPos), isNull);
  });
}
