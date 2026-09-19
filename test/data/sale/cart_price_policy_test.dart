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
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

/// Задача 9 ревизии 2026-09-19: **настройку кассы `editPrice` проверял только
/// экран**.
///
/// # Что было измерено на `6237809d`
///
/// Единственным читателем `ThisPosEntries.editPrice` во всём дереве был
/// `sale_screen._showEditDialog` (`!policy.editPrice`). Ни
/// `LocalCartService.updatePrice`, ни обработчик провода
/// `SaleOps.updatePrice` её не читали вовсе — то есть с планшета цену правили
/// вопреки настройке «Политика продаж», выставленной на кассе, а сама
/// настройка выглядела работающей. Это случай I162 дословно: проверка стояла
/// там, где рисуется интерфейс, а не там, где исполняется операция.
///
/// # Почему проба зовёт корзину, а не экран
///
/// Экранную половину (снять поле, показать причину) закрывать нечем: она уже
/// была, и именно она создавала видимость. Доказать нужно обратное — что
/// **команда** отказывает и без экрана. Поэтому здесь тот же путь, каким
/// пойдёт кассир за кассой: вызов `LocalCartService` поверх настоящей базы.
/// Второй фронт — кадр по проводу через настоящего сторожа — лежит в
/// `test/backend/sale_permissions_test.dart`, группа «настройка кассы
/// «правка цены» доезжает до провода».
///
/// # Ревизия второго фронта 2026-09-19: опт был второй дверью к той же цене
///
/// Первая редакция этого файла кончалась словами «`setWholesale` этой
/// настройкой не закрыт», и это было **названной открытой дверью**, а не
/// оговоркой: оптовый прейскурант — тот же «продать дешевле розничной»,
/// только списком, и кассиру со старшим правом хватало переключить режим
/// чека. Группы «опт закрыт той же настройкой» ниже закрывают её, и
/// закрывают **оба** входа: команду `setWholesale` и `start(wholesale:
/// true)`, которым экран продажи начинает чек, если режим остался оптовым с
/// прошлого. Второй вход нашёлся вопросом «чем ещё чек становится оптовым»,
/// а не чтением плана; закрой первый и оставь второй — файл позеленел бы, а
/// деньги продолжали бы уходить.
///
/// # Чего эти пробы НЕ доказывают
///
/// Что цену строки нельзя изменить другим путём: акции считаются при сборке
/// снимка и через команду не проходят вовсе. И что опт закрыт **правом** на
/// начале чека: у `start` довода `DiscountAuthority` нет ни на одном фронте,
/// здесь мерится только настройка. Названо здесь, чтобы зелёный файл не
/// читался как «дешевле розницы не продать».
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

  /// Всё разрешено: здесь мерится **настройка кассы**, а не право кассира.
  const full = DiscountAuthority(
    roleIndex: 0,
    permissions: {
      PermissionKeys.opSellDiscount,
      PermissionKeys.opEditPrice,
      PermissionKeys.opDeferSale,
    },
  );

  /// Правки цены нет — для пробы порядка отказов.
  const noEditPrice = DiscountAuthority(
    roleIndex: 0,
    permissions: {PermissionKeys.opSellDiscount, PermissionKeys.opDeferSale},
  );

  Matcher deniedPolicy = throwsA(
    isA<WireRefusal>()
        .having((r) => r.code, 'code', cartDeniedPolicyCode)
        .having((r) => r.message, 'message', contains('Политика продаж')),
  );

  Future<void> setEditPrice(bool value) =>
      (db.update(db.thisPosEntries)..where((t) => t.id.equals(1))).write(
        ThisPosEntriesCompanion(editPrice: Value(value)),
      );

  Future<CartView> oneLine({int terminalId = 7, int firstKey = 1}) async {
    final started = await cart.start(
      terminalId: terminalId,
      wholesale: false,
      meta: m(firstKey),
    );
    return cart.addByBarcode(terminalId, barcode, mv(started, firstKey + 1));
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            // Тумблер включён в оснастке, а каждая проба ставит его сама:
            // умолчание колонки (`false`) совпало бы с запрещающим случаем,
            // и проба «запрещено» прошла бы, ничего не настроив, — то есть
            // не отличила бы настройку от её отсутствия.
            editPrice: Value(true),
            sellInDiscount: Value(true),
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
            // Оптовая цена заведена ревизией второго фронта 2026-09-19:
            // без неё пробы про опт мерили бы флаг в строке `Sales`, а не
            // **деньги**. Разница 500 → 300 и есть то, ради чего настройка
            // «Правка цены» существует.
            wholesalePrice: Value(d('300')),
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

  group('выключенная настройка запрещает правку цены всем', () {
    test('повышение цены — отказ denied_policy, строка цела', () async {
      // **Повышение, а не понижение.** Понижение меряется пределом скидки, и
      // отказ мог бы прийти оттуда (`denied_limit`) — проба сказала бы о
      // пределе, а не о настройке. Повышение пределом не меряется вовсе.
      final view = await oneLine();
      await setEditPrice(false);

      await expectLater(
        () => cart.updatePrice(
          7,
          view.lines.single.id,
          d('600'),
          mv(view, 3),
          by: full,
        ),
        deniedPolicy,
      );

      final rows = await db.saleProductDao.findBySale(
        view.receiptNo!,
        view.posId,
      );
      expect(rows.single.price, d('500'), reason: 'цена в базе не менялась');
    });

    test('отказ не зависит от строки: версия чека не двигалась', () async {
      // Отличает «настройка проверена до изменения» от «изменение сделано и
      // откатилось». Версия растёт с каждой исполненной командой.
      final view = await oneLine();
      await setEditPrice(false);

      await expectLater(
        () => cart.updatePrice(
          7,
          view.lines.single.id,
          d('600'),
          mv(view, 3),
          by: full,
        ),
        deniedPolicy,
      );

      final after = await cart.currentView(7);
      expect(after.version, view.version);
    });

    test('понижение тоже закрыто — не только повышение', () async {
      // Без неё правка могла бы остаться открытой ровно там, где кассир и
      // отдаёт деньги покупателю.
      final view = await oneLine();
      await setEditPrice(false);

      await expectLater(
        () => cart.updatePrice(
          7,
          view.lines.single.id,
          d('400'),
          mv(view, 3),
          by: full,
        ),
        deniedPolicy,
      );
    });
  });

  group('право кассира и настройка кассы складываются «и»', () {
    test('нет права — forbidden, а не denied_policy: право первым', () async {
      // Порядок отказов назван в докстринге `CartService.updatePrice` и
      // проверяется здесь: кассир без права на кассе с выключенной
      // настройкой обязан узнать про **своё право**, иначе владелец,
      // включивший настройку, получит вторую жалобу на ровном месте.
      final view = await oneLine();
      await setEditPrice(false);

      await expectLater(
        () => cart.updatePrice(
          7,
          view.lines.single.id,
          d('600'),
          mv(view, 3),
          by: noEditPrice,
        ),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', cartForbiddenCode),
        ),
      );
    });

    test('есть право, но настройка выключена — всё равно нельзя', () async {
      // Вторая половина «и». Первая (нет права, настройка включена) уже
      // измерена `cart_rights_desktop_test.dart`.
      final view = await oneLine();
      await setEditPrice(false);

      await expectLater(
        () => cart.updatePrice(
          7,
          view.lines.single.id,
          d('600'),
          mv(view, 3),
          by: full,
        ),
        deniedPolicy,
      );
    });
  });

  group('управляющие пробы: починка не заперла всех подряд', () {
    test('включённая настройка + право — цена меняется как раньше', () async {
      final view = await oneLine();
      await setEditPrice(true);

      final after = await cart.updatePrice(
        7,
        view.lines.single.id,
        d('600'),
        mv(view, 3),
        by: full,
      );

      expect(after.lines.single.price, d('600'));
    });

    test('касса не настроена — отказ приходит раньше политики', () async {
      // **Измерение, а не украшение.** Первая редакция этой пробы ждала
      // «строки настроек нет → правка разрешена» и покраснела: команда идёт
      // внутри `_command`, а тот спрашивает номер кассы (`_posId`) и
      // отказывает `till_not_configured` раньше, чем дело доходит до
      // настройки. То есть ветка `pos == null` через `updatePrice`
      // недостижима вовсе, и в докстринге
      // `LocalCartService._requirePriceEditingEnabled` это сказано словами.
      //
      // Проба осталась затем, чтобы порядок был закреплён: незаведённая
      // касса обязана называться незаведённой, а не «политикой продаж», —
      // кассир, которому сказали про тумблер, пойдёт искать его в пустых
      // настройках.
      final view = await oneLine();
      await db.delete(db.thisPosEntries).go();

      await expectLater(
        () => cart.updatePrice(
          7,
          view.lines.single.id,
          d('600'),
          mv(view, 3),
          by: full,
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            'till_not_configured',
          ),
        ),
      );
    });

    test('выключенная настройка не трогает соседние команды', () async {
      // Диверсия второго рода: «запретить всё» прошло бы каждую пробу выше.
      // Количество и скидка настройкой правки цены не закрыты.
      var view = await oneLine();
      await setEditPrice(false);

      view = await cart.setQuantity(
        7,
        view.lines.single.id,
        d('3'),
        mv(view, 3),
      );
      expect(view.lines.single.quantity, d('3'));

      view = await cart.setDiscountAmount(
        7,
        view.lines.single.id,
        d('100'),
        mv(view, 4),
        by: full,
      );
      expect(view.totalDiscount, d('100'));
    });
  });

  group('опт закрыт той же настройкой: команда setWholesale', () {
    test('включение опта при выключенном тумблере — denied_policy', () async {
      final view = await oneLine();
      await setEditPrice(false);

      await expectLater(
        () => cart.setWholesale(7, true, mv(view, 3), by: full),
        deniedPolicy,
      );

      final sale = await db.saleDao.findByKey(view.receiptNo!, view.posId);
      expect(sale!.isWholesale, isFalse, reason: 'чек остался розничным');
    });

    test('отказ доходит до денег: новая строка идёт по 500, не по 300', () async {
      // **Главная проба группы.** Остальные мерят флаг и код; эта мерит то,
      // ради чего настройка заведена: цену, по которой товар уедет в чек.
      // Без неё «опт не включился» могло бы означать что угодно, вплоть до
      // того, что оптовой цены у товара просто нет.
      var view = await oneLine();
      await setEditPrice(false);

      await expectLater(
        () => cart.setWholesale(7, true, mv(view, 3), by: full),
        deniedPolicy,
      );

      view = await cart.addByBarcode(7, barcode, mv(view, 4));
      expect(view.lines.single.price, d('500'));
      expect(view.lines.single.quantity, d('2'), reason: 'слилось в строку');
    });

    test('нет права — forbidden, а не denied_policy: право первым', () async {
      // Тот же порядок «кому → где → сколько», что у правки цены: кассир
      // без права обязан узнать про своё право, а не про чужой тумблер.
      final view = await oneLine();
      await setEditPrice(false);

      await expectLater(
        () => cart.setWholesale(7, true, mv(view, 3), by: noEditPrice),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', cartForbiddenCode),
        ),
      );
    });

    test('возврат в розницу при выключенном тумблере — работает', () async {
      // Асимметрия намеренная (докстринг
      // `LocalCartService._requirePriceEditingEnabled`): запрет на
      // `value == false` запер бы в опте чек, начатый до щелчка тумблером.
      // Проба держит это решение записанным: сделай проверку симметричной —
      // и она покраснеет.
      var view = await oneLine();
      view = await cart.setWholesale(7, true, mv(view, 3), by: full);
      await setEditPrice(false);

      view = await cart.setWholesale(7, false, mv(view, 4), by: full);

      final sale = await db.saleDao.findByKey(view.receiptNo!, view.posId);
      expect(sale!.isWholesale, isFalse);
    });

    test('управляющая: тумблер включён — опт включается и меняет цену', () async {
      // Починка не заперла всех подряд: с разрешающей настройкой и правом
      // всё работает как до ревизии, включая саму оптовую цену.
      var view = await oneLine();
      await setEditPrice(true);

      view = await cart.setWholesale(7, true, mv(view, 3), by: full);
      view = await cart.addByBarcode(7, barcode, mv(view, 4));

      expect(
        view.lines.map((l) => l.price),
        containsAll([d('500'), d('300')]),
        reason: 'старая строка по рознице, новая по опту',
      );
    });
  });

  group('опт закрыт той же настройкой: второй вход, start(wholesale)', () {
    test('новый оптовый чек при выключенном тумблере — denied_policy', () async {
      // Вход, которого не было в плане ревизии. `sale_controller._start`
      // передаёт сюда `state.mode == SaleMode.wholesale`, а режим переживает
      // завершённый чек: владелец, выключивший тумблер при открытом оптовом
      // чеке, получал следующий чек снова оптовым — мимо `setWholesale` и
      // мимо её проверки.
      await setEditPrice(false);

      await expectLater(
        () => cart.start(terminalId: 11, wholesale: true, meta: m(1)),
        deniedPolicy,
      );

      final mine = await cart.currentView(11);
      expect(mine.receiptNo, isNull, reason: 'чек не заведён вовсе');
    });

    test('розничный чек при выключенном тумблере начинается как раньше', () async {
      // Диверсия второго рода: «отказывать всякому `start`» прошло бы пробу
      // выше и остановило бы торговлю целиком.
      await setEditPrice(false);

      final view = await cart.start(terminalId: 12, wholesale: false, meta: m(1));

      expect(view.receiptNo, isNotNull);
    });

    test('управляющая: тумблер включён — оптовый чек начинается', () async {
      await setEditPrice(true);

      final view = await cart.start(terminalId: 13, wholesale: true, meta: m(1));

      final sale = await db.saleDao.findByKey(view.receiptNo!, view.posId);
      expect(sale!.isWholesale, isTrue);
    });

    test('возобновление оптового чека тумблером не заперто', () async {
      // Вторая половина асимметрии: `wholesale` на возобновлении не читается
      // вовсе, и отказ на нём отнял бы у кассира уже начатый чек. Проба
      // покраснеет, если проверку поднять выше ветки возобновления.
      await setEditPrice(true);
      final started = await cart.start(
        terminalId: 14,
        wholesale: true,
        meta: m(1),
      );
      await setEditPrice(false);

      final again = await cart.start(
        terminalId: 14,
        wholesale: true,
        meta: mv(started, 2),
      );

      expect(again.receiptNo, started.receiptNo);
    });
  });
}
