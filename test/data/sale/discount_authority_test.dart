import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/constants/enums/user_role.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

/// Задача 12 плана «Полнота продажи»: у ручной скидки появляется предел, и
/// решает его **касса**, а не экран.
///
/// # Что здесь доказывается, и почему именно на этом фронте
///
/// До этой работы единственным потолком скидки была арифметика — «скидка не
/// больше стоимости строки», — то есть **строка бесплатно была законной
/// операцией**. Права `op.sellDiscount` на десктопе не проверял никто: сторож
/// провода стоит на пути браузера (`sale_permissions_test.dart`), а кассовый
/// экран звал контракт напрямую, и «скрытая кнопка» была всей защитой
/// (`sale_screen.dart:414` — `if (!policy.sellInDiscount) showBlocked()`).
///
/// Это **тот же фронт**, что и браузерный: с задачи 8 экран кассы резолвит
/// `CartService` через контракт, и все шестнадцать команд десктопа идут через
/// тот же `LocalCartService`, что и команды провода. Поэтому предел заведён
/// не сторожем, а **обязательным доводом** четырёх команд
/// ([DiscountAuthority]): забыть его нельзя — операция без него не
/// компилируется. Проба на этот довод — сама сборка; проба здесь — на то, что
/// довод читается, а не носится зря.
///
/// Второй фронт (провод) закрыт в `test/backend/sale_permissions_test.dart`,
/// группой «предел скидки действует и по проводу»: там кадр идёт через
/// настоящий `WireGuard` и настоящий `TillOperations`, и полномочия строятся
/// **из сеанса**, а не из тела кадра.
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

  /// Кассир с правом на скидку. Роль — кассир: именно её предел настраивают.
  const cashier = DiscountAuthority(
    roleIndex: 3, // UserRole.cashier
    permissions: {PermissionKeys.opSellDiscount, PermissionKeys.opEditPrice},
  );

  /// Тот же кассир, но без права. Не «пустой набор прав»: `op.editPrice` при
  /// нём остаётся, иначе отказ мог бы прийти не от того ключа.
  const cashierNoDiscount = DiscountAuthority(
    roleIndex: 3,
    permissions: {PermissionKeys.opEditPrice},
  );

  Future<void> setLimit({
    required int role,
    String? maxPercentPerLine,
    String? approvalAbovePercent,
  }) => db
      .into(db.discountLimits)
      .insertOnConflictUpdate(
        DiscountLimitsCompanion.insert(
          role: Value(role),
          maxPercentPerLine: maxPercentPerLine == null
              ? const Value.absent()
              : Value(d(maxPercentPerLine)),
          approvalAbovePercent: approvalAbovePercent == null
              ? const Value.absent()
              : Value(d(approvalAbovePercent)),
        ),
      );

  Future<void> setPosFlags({bool? sellInDiscount, bool? blockPriceDecrease}) =>
      (db.update(db.thisPosEntries)..where((t) => t.id.equals(1))).write(
        ThisPosEntriesCompanion(
          sellInDiscount: sellInDiscount == null
              ? const Value.absent()
              : Value(sellInDiscount),
          isKassaPriceDecreasingBlocked: blockPriceDecrease == null
              ? const Value.absent()
              : Value(blockPriceDecrease),
        ),
      );

  /// Чек с одной строкой: товар 500 за штуку.
  Future<CartView> oneLine() async {
    final started = await cart.start(
      terminalId: 7,
      wholesale: false,
      meta: m(1),
    );
    return cart.addByBarcode(7, barcode, mv(started, 2));
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());

    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            // Тумблер кассы «продажа со скидкой» включён: у него с этой
            // задачи есть читатель на кассе, и выключенным он отказывал бы
            // каждой пробе ниже прежде, чем дело дошло бы до предела.
            sellInDiscount: Value(true),
            // Тем же доводом — тумблер «правка цены» (задача 9 ревизии
            // 2026-09-19): его читает `updatePrice`, а колонка по
            // умолчанию `false`. Пробы ниже мерят **предел уступки** через
            // цену, и выключенный тумблер отказывал бы им раньше предела.
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
            userId: Value(4),
            openTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
            isOpened: Value(true),
            isSynced: Value(false),
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

  // ── предел ────────────────────────────────────────────────────────────

  test(
    'предел действует: 21 % при пределе 20 % отклоняется с суммой в тексте',
    () async {
      await setLimit(role: UserRole.cashier.index, maxPercentPerLine: '20');
      final view = await oneLine();

      await expectLater(
        () => cart.setDiscountPercent(
          7,
          view.lines.single.id,
          d('21'),
          mv(view, 3),
          by: cashier,
        ),
        throwsA(
          isA<WireRefusal>()
              .having((r) => r.code, 'code', cartDeniedLimitCode)
              // Число в тексте — не украшение: кассир обязан узнать, до
              // скольки ему можно, а не только что «нельзя».
              .having((r) => r.message, 'message', contains('20')),
        ),
      );

      // Отказ не оставил половины работы: строка не тронута.
      final rows = await db.saleProductDao.findBySale(
        view.receiptNo!,
        view.posId,
      );
      expect(rows.single.price, d('500'));
    },
  );

  test('ровно предел проходит, а на волос больше — нет', () async {
    await setLimit(role: UserRole.cashier.index, maxPercentPerLine: '20');
    final view = await oneLine();

    final ok = await cart.setDiscountPercent(
      7,
      view.lines.single.id,
      d('20'),
      mv(view, 3),
      by: cashier,
    );
    expect(ok.lines.single.discount, d('100'));

    await expectLater(
      () => cart.setDiscountPercent(
        7,
        ok.lines.single.id,
        d('20.001'),
        mv(ok, 4),
        by: cashier,
      ),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', cartDeniedLimitCode),
      ),
    );
  });

  test('скидка суммой меряется тем же пределом, что и процентом', () async {
    // Иначе предел — театр: 20 % запрещено, а «скидка 500 из 500» разрешено.
    await setLimit(role: UserRole.cashier.index, maxPercentPerLine: '20');
    final view = await oneLine();

    await expectLater(
      () => cart.setDiscountAmount(
        7,
        view.lines.single.id,
        d('500'),
        mv(view, 3),
        by: cashier,
      ),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', cartDeniedLimitCode),
      ),
    );

    final ok = await cart.setDiscountAmount(
      7,
      view.lines.single.id,
      d('100'),
      mv(view, 4),
      by: cashier,
    );
    expect(ok.lines.single.discount, d('100'));
  });

  test(
    'арифметический потолок остаётся ПОСЛЕДНИМ, а не становится первым',
    () async {
      // Найдено первым же прогоном после правки: проба «скидка больше строки
      // не уводит чек в минус» была зелёной до задачи 12 и покраснела.
      // Причина — доля 900 от 500 это 180 %, и предел умолчания (сто) отказал
      // бы там, где вчера скидка просто срезалась до стоимости строки. То
      // есть миграция ужесточила бы кассу ровно там, где обещала не
      // ужесточать (I165).
      //
      // Правильный порядок: при пределе 100 % арифметика срезает, при
      // пределе 20 % отказывает правило. Оба потолка на месте, и каждый
      // делает своё.
      final view = await oneLine();
      final ok = await cart.setDiscountAmount(
        7,
        view.lines.single.id,
        d('900'),
        mv(view, 3),
        by: cashier,
      );
      expect(ok.lines.single.discount, d('500'));
      expect(ok.total, Decimal.zero);

      await setLimit(role: UserRole.cashier.index, maxPercentPerLine: '20');
      await expectLater(
        () => cart.setDiscountAmount(
          7,
          ok.lines.single.id,
          d('900'),
          mv(ok, 4),
          by: cashier,
        ),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', cartDeniedLimitCode),
        ),
      );
    },
  );

  test('строку нельзя раздать бесплатно ценой в обход предела', () async {
    // Дыра, которую предел обязан закрыть вместе со скидкой: `updatePrice(0)`
    // на товар за 500 — та же стопроцентная скидка, только другим входом.
    await setLimit(role: UserRole.cashier.index, maxPercentPerLine: '20');
    final view = await oneLine();

    await expectLater(
      () => cart.updatePrice(
        7,
        view.lines.single.id,
        Decimal.zero,
        mv(view, 3),
        by: cashier,
      ),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', cartDeniedLimitCode),
      ),
    );

    // Цена в пределах предела проходит: 450 из 500 — это 10 %.
    final ok = await cart.updatePrice(
      7,
      view.lines.single.id,
      d('450'),
      mv(view, 4),
      by: cashier,
    );
    expect(ok.lines.single.price, d('450'));
  });

  test(
    'предел цены меряется от каталожной, а не от вчерашней уступки',
    () async {
      // Нарезка ломтями: два раза по 10 % от предыдущей цены — это 19 % от
      // каталожной, и предел в 15 % обязан остановить вторую правку.
      await setLimit(role: UserRole.cashier.index, maxPercentPerLine: '15');
      final view = await oneLine();

      final first = await cart.updatePrice(
        7,
        view.lines.single.id,
        d('450'),
        mv(view, 3),
        by: cashier,
      );

      await expectLater(
        () => cart.updatePrice(
          7,
          first.lines.single.id,
          d('405'),
          mv(first, 4),
          by: cashier,
        ),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', cartDeniedLimitCode),
        ),
      );
    },
  );

  test('повышение цены пределом скидки не меряется', () async {
    await setLimit(role: UserRole.cashier.index, maxPercentPerLine: '0');
    final view = await oneLine();

    final ok = await cart.updatePrice(
      7,
      view.lines.single.id,
      d('600'),
      mv(view, 3),
      by: cashier,
    );
    expect(ok.lines.single.price, d('600'));
  });

  // ── право и политика ──────────────────────────────────────────────────

  test(
    'кассир без op.sellDiscount получает forbidden и на кассе, минуя экран',
    () async {
      final view = await oneLine();

      await expectLater(
        () => cart.setDiscountPercent(
          7,
          view.lines.single.id,
          d('5'),
          mv(view, 3),
          by: cashierNoDiscount,
        ),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', cartForbiddenCode),
        ),
      );
    },
  );

  test(
    'выключенный тумблер кассы отказывает своим кодом, а не пределом',
    () async {
      // `denied_policy` и `denied_limit` лечатся в разных местах: первое — в
      // настройках кассы, второе — у того, кто назначает предел роли. Один код
      // на две беды отправил бы кассира не туда.
      await setPosFlags(sellInDiscount: false);
      final view = await oneLine();

      await expectLater(
        () => cart.setDiscountPercent(
          7,
          view.lines.single.id,
          d('1'),
          mv(view, 3),
          by: cashier,
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            cartDeniedPolicyCode,
          ),
        ),
      );
    },
  );

  test('нет права — отказ приходит раньше предела', () async {
    // Порядок отказов от дешёвого к дорогому объявлен шагом 5 плана, и он
    // проверяем: у кассира без права и скидка за пределом — код обязан быть
    // про право, а не про предел.
    await setLimit(role: UserRole.cashier.index, maxPercentPerLine: '20');
    final view = await oneLine();

    await expectLater(
      () => cart.setDiscountPercent(
        7,
        view.lines.single.id,
        d('99'),
        mv(view, 3),
        by: cashierNoDiscount,
      ),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', cartForbiddenCode),
      ),
    );
  });

  // ── заслонка на двух дверях ───────────────────────────────────────────

  test(
    'blockPriceDecrease = true при пределе 100 % — касса скидку РАЗРЕШАЕТ',
    () async {
      // Утверждение как факт, а не как описание: проба краснеет, если кто-то
      // свяжет две настройки молча. «Запрещено снижать цену» и «разрешена
      // скидка» — это две двери, и заслонка на одной из них не закрывает
      // вторую; владелец, включивший запрет снижения цены и думающий, что
      // закрыл скидку, закрыл ровно половину.
      await setPosFlags(blockPriceDecrease: true);
      final view = await oneLine();

      final ok = await cart.setDiscountPercent(
        7,
        view.lines.single.id,
        d('100'),
        mv(view, 3),
        by: cashier,
      );
      expect(ok.lines.single.discount, d('500'));
    },
  );

  test(
    'та же настройка вторую дверь закрывает: цена ниже каталожной отказана',
    () async {
      await setPosFlags(blockPriceDecrease: true);
      final view = await oneLine();

      await expectLater(
        () => cart.updatePrice(
          7,
          view.lines.single.id,
          d('499'),
          mv(view, 3),
          by: cashier,
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            cartDeniedPolicyCode,
          ),
        ),
      );
    },
  );

  // ── подтверждение старшего ────────────────────────────────────────────

  test('скидка выше порога подтверждения отказана своим кодом', () async {
    await setLimit(
      role: UserRole.cashier.index,
      maxPercentPerLine: '50',
      approvalAbovePercent: '10',
    );
    final view = await oneLine();

    final ok = await cart.setDiscountPercent(
      7,
      view.lines.single.id,
      d('10'),
      mv(view, 3),
      by: cashier,
    );
    expect(ok.lines.single.discount, d('50'));

    await expectLater(
      () => cart.setDiscountPercent(
        7,
        ok.lines.single.id,
        d('11'),
        mv(ok, 4),
        by: cashier,
      ),
      throwsA(
        isA<WireRefusal>()
            .having((r) => r.code, 'code', cartApprovalRequiredCode)
            .having((r) => r.message, 'message', contains('10')),
      ),
    );
  });

  // ── умолчание ─────────────────────────────────────────────────────────

  test('без единой настройки предела касса работает как вчера', () async {
    // Ни одной строки роли — только та, что положила миграция. Сто процентов
    // разрешено: I165, «предела нет» не существует, существует объявленное
    // значение.
    final view = await oneLine();

    final ok = await cart.setDiscountPercent(
      7,
      view.lines.single.id,
      d('100'),
      mv(view, 3),
      by: cashier,
    );
    expect(ok.lines.single.discount, d('500'));
  });
}
