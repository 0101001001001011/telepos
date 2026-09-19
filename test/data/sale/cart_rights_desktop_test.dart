import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/domain/discount/discount_policy.dart';
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

/// Задача 28 плана «Продажа с браузерного терминала»: второй фронт кассы —
/// права мимо провода.
///
/// # Что было измерено на `9ac079a5`
///
/// `op.editPrice` и `op.deferSale` проверял **только сторож провода**
/// (`SaleOps.updatePrice/setWholesale/defer/loadDeferred` →
/// `SessionAccess(needs: …)`), а подъём оптового отложенного чека —
/// `TillOperations._requireRightToContinueWholesale`. В `lib/data` проверок
/// этих прав было ноль. Экран кассы зовёт тот же `LocalCartService`
/// напрямую, минуя провод, — значит владелец, снявший кассиру «Правку цены»
/// или «Отложенную продажу», запрещал это браузеру и **ничего** на самой
/// кассе, где идёт основная торговля.
///
/// # Приём — тот же, что у скидки (задача 12)
///
/// Полномочия приходят **обязательным доводом** команды ([DiscountAuthority])
/// и читаются **в корзине**, а не у сторожа: забыть довод нельзя по сборке,
/// а проверка стоит там, куда сходятся оба фронта. Провод строит довод из
/// сеанса, экран — из `AppState` вошедшего.
void main() {
  late AppDatabase db;
  late LocalCartService cart;

  const barcode = '4870001234567';

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta m(int n) =>
      CartCommandMeta(key: 'k$n', baseVersion: 0, receiptNo: null);

  CartCommandMeta mv(CartView v, int n) => CartCommandMeta(
    key: 'k$n',
    baseVersion: v.version,
    receiptNo: v.receiptNo,
  );

  /// Всё разрешено — фон для подготовки и управляющие пробы.
  const full = DiscountAuthority(
    roleIndex: 0,
    permissions: {
      PermissionKeys.opSellDiscount,
      PermissionKeys.opEditPrice,
      PermissionKeys.opDeferSale,
    },
  );

  /// Кассир по умолчанию роли: откладывать можно, править цену — нет.
  const noEditPrice = DiscountAuthority(
    roleIndex: 3,
    permissions: {PermissionKeys.opSellDiscount, PermissionKeys.opDeferSale},
  );

  /// Правка цены есть, отложенной продажи — нет.
  const noDefer = DiscountAuthority(
    roleIndex: 0,
    permissions: {PermissionKeys.opSellDiscount, PermissionKeys.opEditPrice},
  );

  Matcher forbidden(String right) => throwsA(
    isA<WireRefusal>()
        .having((r) => r.code, 'code', cartForbiddenCode)
        .having((r) => r.message, 'message', contains(right)),
  );

  Future<CartView> oneLine({int terminalId = 7, int firstKey = 1}) async {
    final started = await cart.start(
      terminalId: terminalId,
      wholesale: false,
      meta: m(firstKey),
    );
    return cart.addByBarcode(terminalId, barcode, mv(started, firstKey + 1));
  }

  Future<Sale> saleOf(CartView v) async =>
      (await db.saleDao.findByKey(v.receiptNo!, v.posId))!;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            // Задача 9 ревизии 2026-09-19: у настройки кассы «правка цены»
            // появился читатель в самой команде, а колонка по умолчанию
            // `false`. Здесь мерится **право кассира**, и выключенная
            // настройка подменяла бы его отказ своим (`denied_policy`
            // вместо `forbidden`) — тумблер включён нарочно, чтобы пробы
            // говорили о том, о чём заявлены.
            editPrice: Value(true),
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
            // Текущее время, а не 1970 год: смена старше суток — отдельный
            // отказ кассы, и он не должен подменять здесь отказ по праву.
            openTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
            isOpened: const Value(true),
            isSynced: const Value(false),
          ),
        );
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(100),
            barcode: int.parse(barcode),
            name: 'Товар',
            type: 0,
            measure: 0,
            quantity: Value(d('100')),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            ucode: const Value(100),
            barcode: int.parse(barcode),
            sellingPrice: Value(d('500')),
          ),
        );

    final logger = Talker();
    cart = LocalCartService(
      db: db,
      logger: logger,
      initiation: SaleInitiationUseCaseImpl(db: db, logger: logger),
      deferred: DeferredSaleServiceImpl(db: db, logger: logger),
      rounding: SaleRoundOptionUseCaseImpl(),
      findByBarcode: FindByBarcodeUseCaseImpl(db: db, logger: logger),
      searchProducts: SearchProductInfoUseCaseImpl(db: db, logger: logger),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('op.editPrice на кассе', () {
    test('цену без права не поднять — отказ по праву, строка цела', () async {
      // Повышение, а не понижение: понижение меряется пределом скидки, и
      // отказ мог бы прийти оттуда. Повышение пределом не меряется вовсе —
      // значит единственное, что может его остановить, это право.
      final view = await oneLine();

      await expectLater(
        () => cart.updatePrice(
          7,
          view.lines.single.id,
          d('600'),
          mv(view, 3),
          by: noEditPrice,
        ),
        forbidden(PermissionKeys.opEditPrice),
      );

      final rows = await db.saleProductDao.findBySale(
        view.receiptNo!,
        view.posId,
      );
      expect(rows.single.price, d('500'));
    });

    test('опт без права не включить', () async {
      final view = await oneLine();

      await expectLater(
        () => cart.setWholesale(7, true, mv(view, 3), by: noEditPrice),
        forbidden(PermissionKeys.opEditPrice),
      );
      expect((await saleOf(view)).isWholesale, isFalse);
    });

    test('оптовый отложенный чек без права не поднять', () async {
      // Перенесено с провода (`TillOperations._requireRightToContinueWholesale`):
      // «опт под своим правом» держалось на включении и не держалось на
      // продолжении — и только для браузера.
      var view = await oneLine();
      view = await cart.setWholesale(7, true, mv(view, 3), by: full);
      await cart.defer(7, mv(view, 4), by: full);

      await expectLater(
        () => cart.loadDeferred(9, view.receiptNo!, m(20), by: noEditPrice),
        forbidden(PermissionKeys.opEditPrice),
      );
      expect((await saleOf(view)).state, 3, reason: 'чек остался в пуле');
    });
  });

  group('op.deferSale на кассе', () {
    test('без права чек не отложить', () async {
      final view = await oneLine();

      await expectLater(
        () => cart.defer(7, mv(view, 3), by: noDefer),
        forbidden(PermissionKeys.opDeferSale),
      );
      expect((await saleOf(view)).state, 0, reason: 'чек остался в работе');
    });

    test('без права отложенный не поднять', () async {
      final view = await oneLine();
      await cart.defer(7, mv(view, 3), by: full);

      await expectLater(
        () => cart.loadDeferred(9, view.receiptNo!, m(20), by: noDefer),
        forbidden(PermissionKeys.opDeferSale),
      );
      expect((await saleOf(view)).state, 3, reason: 'чек остался в пуле');
    });

    /// Задача 10 ревизии 2026-09-19: **читающая половина** права.
    ///
    /// На проводе `sale.deferredList` закрыт `op.deferSale` с задачи 9
    /// (`SaleOps.deferredList`), а на самой кассе подписка звалась **без
    /// полномочий вовсе**: `deferredCartsProvider` →
    /// `GetIt.I<CartService>().watchDeferred()`. То есть кассир без права,
    /// сидящий за кассой, видел чужой пул целиком — номера, суммы и имена
    /// кассиров. Касса была слабее планшета ровно там, где идёт основная
    /// торговля.
    test('без права не видно и пула — право закрыто с обеих сторон', () async {
      // Пул не пуст: пустой список прошёл бы пробу и при снятой проверке.
      final view = await oneLine();
      await cart.defer(7, mv(view, 3), by: full);

      await expectLater(
        () => cart.watchDeferred(by: noDefer).first,
        forbidden(PermissionKeys.opDeferSale),
      );
    });

    test('с правом пул виден — отказ не всем подряд', () async {
      final view = await oneLine();
      await cart.defer(7, mv(view, 3), by: full);

      final pool = await cart.watchDeferred(by: full).first;
      expect(pool.map((c) => c.receiptNo), [view.receiptNo]);
    });

    test('отказ приходит исключением, а не пустым пулом', () async {
      // Пустой пул — законное состояние кассы, и подменять им запрет значит
      // сказать кассиру «отложенных нет» там, где их просто не показывают.
      // Без этой пробы «возвращать пустой список» прошло бы предыдущую.
      final view = await oneLine();
      await cart.defer(7, mv(view, 3), by: full);

      Object? caught;
      try {
        await cart.watchDeferred(by: noDefer).first;
      } on Object catch (e) {
        caught = e;
      }
      expect(
        caught,
        isA<WireRefusal>(),
        reason: 'молчание неотличимо от пустого пула',
      );
    });
  });

  test('с правами всё проходит — проверка не запирает всех подряд', () async {
    var view = await oneLine();
    view = await cart.updatePrice(
      7,
      view.lines.single.id,
      d('600'),
      mv(view, 3),
      by: full,
    );
    expect(view.lines.single.price, d('600'));
    view = await cart.setWholesale(7, true, mv(view, 4), by: full);
    expect(view.wholesale, isTrue);
    await cart.defer(7, mv(view, 5), by: full);

    // Розничный отложенный чек кассиру без правки цены поднимать можно:
    // проверка опта обязана молчать на рознице.
    final retail = await oneLine(terminalId: 8, firstKey: 30);
    await cart.defer(8, mv(retail, 32), by: full);
    final taken = await cart.loadDeferred(
      9,
      retail.receiptNo!,
      m(40),
      by: noEditPrice,
    );
    expect(taken.receiptNo, retail.receiptNo);
  });
}
