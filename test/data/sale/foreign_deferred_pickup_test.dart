/// Подъём отложенного чека соседней кассы: деньги достаются той кассе,
/// которая пробьёт.
///
/// # Сценарий заказчика 2026-09-19
///
/// Покупатель набрал корзину на кассе 1, что-то забыл — чек отложили, чтобы
/// не держать очередь. Вернулся, а там очередь; пошёл на кассу 2, и она
/// поднимает ту самую корзину.
///
/// # Что здесь главное
///
/// Не то, что корзина поднялась, а то, **чьим чеком она стала**. До этой
/// работы `loadDeferred` продолжала существующую строку `{receiptNo, posId}`
/// и меняла только состояние — чек остался бы чеком кассы 1, и выручка ушла
/// бы соседу: в его смену, его ящик, его X/Z-отчёт. Поэтому чужой чек не
/// продолжается, а **переносится**: получает наш номер и нашу кассу.
///
/// Второе главное — подъём **исключителен**. Как только корзина видна двум
/// кассам, поднять её могут обе, и она продастся дважды.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/deferred_claim_port.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

import '../../helpers/discount_authority.dart';

/// Порт занятия, которым управляет проба.
class _Claim implements DeferredClaimPort {
  _Claim(this.answer);

  /// `null` — занял; число — проиграл этой кассе; 0 — нет связи.
  int? answer;
  int calls = 0;
  ({int receiptNo, int posId, int byPosId})? last;

  @override
  Future<int?> claim({
    required int receiptNo,
    required int posId,
    required int byPosId,
  }) async {
    calls++;
    last = (receiptNo: receiptNo, posId: posId, byPosId: byPosId);
    return answer;
  }

  /// Отзыв к подъёму отношения не имеет — он живёт у закрытия смены и
  /// мерится своей пробой (`deferred_cleared_on_close_test`).
  @override
  Future<void> withdraw({required int receiptNo, required int posId}) async {}
}

void main() {
  late AppDatabase db;
  late Talker logger;
  const ownPos = 1;
  const otherPos = 2;

  CartCommandMeta meta(int key, int version, {int? receiptNo}) =>
      CartCommandMeta(key: 'k$key', baseVersion: version, receiptNo: receiptNo);

  LocalCartService build({DeferredClaimPort? claim}) => LocalCartService(
    db: db,
    logger: logger,
    initiation: SaleInitiationUseCaseImpl(db: db, logger: logger),
    deferred: DeferredSaleServiceImpl(db: db, logger: logger),
    rounding: SaleRoundOptionUseCaseImpl(),
    findByBarcode: FindByBarcodeUseCaseImpl(db: db, logger: logger),
    searchProducts: SearchProductInfoUseCaseImpl(db: db, logger: logger),
    claim: claim,
  );

  /// Отложенный чек соседней кассы — так он приезжает обменом.
  Future<void> seedForeign({int receiptNo = 900, int posId = otherPos}) async {
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: receiptNo,
            posId: posId,
            userId: 4,
            amount: Decimal.parse('1000'),
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
            quantity: Decimal.parse('2.000'),
            price: Decimal.parse('500.000'),
            priceBefore: Decimal.parse('500.000'),
            receiptNo: Value(receiptNo),
            posId: Value(posId),
          ),
        );
  }

  setUp(() async {
    logger = Talker();
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

  test(
    'поднятый чек соседа становится НАШИМ — с нашим номером и кассой',
    () async {
      await seedForeign();
      final claim = _Claim(null); // заняли успешно
      final cart = build(claim: claim);

      final view = await cart.loadDeferred(
        7,
        900,
        meta(1, 0),
        by: fullDiscountAuthority,
        deferredPosId: otherPos,
      );

      expect(
        view.posId,
        ownPos,
        reason:
            'чек обязан стать нашим: иначе выручка попадёт в смену, ящик и '
            'X/Z-отчёт соседней кассы',
      );
      expect(view.receiptNo, isNot(900), reason: 'номер выдаётся наш');
      expect(view.lines, hasLength(1), reason: 'корзина перенесена целиком');
      expect(view.lines.single.price, Decimal.parse('500.000'));

      expect(
        await db.saleDao.findByKey(900, otherPos),
        isNull,
        reason: 'чужая строка своё отслужила и остаться не может',
      );
      expect(claim.last, (
        receiptNo: 900,
        posId: otherPos,
        byPosId: ownPos,
      ), reason: 'занимается ЧУЖОЙ документ в пользу НАШЕЙ кассы');
    },
  );

  test('если чек уже занят — отказ называет кассу-победителя', () async {
    await seedForeign();
    final cart = build(claim: _Claim(otherPos));

    await expectLater(
      cart.loadDeferred(
        7,
        900,
        meta(1, 0),
        by: fullDiscountAuthority,
        deferredPosId: otherPos,
      ),
      throwsA(
        isA<WireRefusal>()
            .having((e) => e.code, 'code', cartDeferredTakenCode)
            .having((e) => e.message, 'message', contains('кассой 2')),
      ),
    );

    expect(
      await db.saleDao.findByKey(900, otherPos),
      isNotNull,
      reason: 'проигравший не имеет права стирать чужую корзину',
    );
  });

  test('без связи чужой чек не поднимается — и это сказано словами', () async {
    await seedForeign();
    final cart = build(claim: _Claim(0)); // 0 — занять не вышло

    await expectLater(
      cart.loadDeferred(
        7,
        900,
        meta(1, 0),
        by: fullDiscountAuthority,
        deferredPosId: otherPos,
      ),
      throwsA(
        isA<WireRefusal>().having(
          (e) => e.message,
          'message',
          contains('нет связи'),
        ),
      ),
    );
  });

  test('обмена нет вовсе — чужой чек поднять нечем, и это названо', () async {
    await seedForeign();
    final cart = build(); // порта нет

    await expectLater(
      cart.loadDeferred(
        7,
        900,
        meta(1, 0),
        by: fullDiscountAuthority,
        deferredPosId: otherPos,
      ),
      throwsA(
        isA<WireRefusal>().having(
          (e) => e.message,
          'message',
          contains('обмен не настроен'),
        ),
      ),
    );
  });

  test('СВОЙ отложенный чек поднимается без связи и без занятия', () async {
    // Его не видит никто другой — занимать не у кого. Потребуй мы занятия и
    // здесь, касса без обмена перестала бы поднимать собственные чеки, и
    // правка сломала бы то, что работало годами.
    await seedForeign(receiptNo: 700, posId: ownPos);
    final claim = _Claim(0); // порт есть, но связи нет
    final cart = build(claim: claim);

    final raised = await cart.loadDeferred(
      7,
      700,
      meta(1, 0),
      by: fullDiscountAuthority,
    );

    expect(
      raised.receiptNo,
      700,
      reason: 'свой чек ПРОДОЛЖАЕТСЯ под своим номером, а не переносится',
    );
    expect(raised.posId, ownPos);
    expect(claim.calls, 0, reason: 'занимать свой чек не у кого');
  });
}
