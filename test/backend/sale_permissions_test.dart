/// Задача 11 плана «Продажа с браузерного терминала»: права `op.*` работают
/// **достижимо**.
///
/// # Почему проба идёт по проводу, а не зовёт обработчик
///
/// Задачи 9 и 10 доказали своё каждая своим способом: 9 — что право
/// **объявлено** в каталоге (`sale_ops_access_test.dart` сверяет `needs`
/// поимённо), 10 — что обработчик **делает** то, что обещает
/// (`sale_operations_test.dart` зовёт его напрямую, минуя сторожа, ровно как
/// это делает `till_operations_test.dart`). Ни одна из двух не отвечает на
/// вопрос «а получит ли кассир без права отказ, если сядет за браузер».
///
/// Проверка объявления доказывает наше представление о продукте; проверка
/// обработчика доказывает продукт **за** сторожем. Между ними лежит ровно то
/// место, где в этом проекте уже один раз пропало целое требование: код
/// привязки терминала был написан, охранял корень и **не звался ниоткуда** —
/// 3518 зелёных тестов не заметили, что войти нельзя.
///
/// Поэтому здесь единственный путь: кадр в `TillWire` через настоящий
/// `WireGuard`, собранный тем же `wireGuardForTill` и тем же словарём
/// `{for (final op in TillOps.all) op.name: op.access}`, каким его собирает
/// `ApiServer`. Обработчики — настоящие (`TillOperations.askHandlers`),
/// корзина — настоящая (`LocalCartService`) поверх настоящей базы в памяти.
/// Ни один обработчик здесь не зовётся напрямую ни разу.
///
/// # Отказ обязан приходить **значением**, а не отсутствием кнопки
///
/// Скрытая кнопка правом не является (И44, И162, «Общие ограничения» плана).
/// Все пробы ниже читают кадр, который касса написала в поток, и смотрят на
/// его код.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/core/constants/enums/user_role.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_session.dart';
import 'package:telepos/domain/auth/session_lookup.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/terminal/terminal.dart' as domain;
import 'package:telepos/domain/wire/auth_wire.dart';
import 'package:telepos/domain/wire/cart_codec.dart';
import 'package:telepos/domain/wire/sale_ops.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_access.dart';
import 'package:telepos/domain/wire/wire_frame.dart';

import 'support/noop_auth.dart';

import '../data/transport/fake_quic_server.dart';
import '../data/transport/till_operations_stubs.dart';
import 'package:telepos/domain/shift/shift_status.dart';

/// Рабочее место этой QUIC-сессии — то, что она заведёт через
/// `terminals.selfEnsure` по проводу.
const _ownTerminal = 7;

/// Единственная QUIC-сессия проб. `listenerId` у `TillWire` по умолчанию 0,
/// поэтому составной ключ сессии равен сырому — обработчики видят ту же
/// единицу.
const _session = 1;

const _barcode = '4870001234567';

/// Токены трёх сеансов. Разные строки, а не один токен с подменой прав:
/// сторож ищет сеанс **по токену**, и подмена содержимого под одним ключом
/// проверяла бы карту, а не поиск.
const _tokenBare = 'tok-bare';
const _tokenFull = 'tok-full';

void main() {
  late AppDatabase db;
  late LocalCartService cart;
  late TillOperations ops;
  late FakeQuicServer server;
  late TillWire wire;
  late _Sessions sessions;
  late PairingInvites invites;

  Decimal d(String v) => Decimal.parse(v);

  /// Восемь операционных прав целиком. Берутся из словаря
  /// (`PermissionKeys.groups['operations']`), а не набираются руками: ключ,
  /// добавленный когда-нибудь в группу, попадёт сюда сам.
  final allOperationKeys = PermissionKeys.groups['operations']!.toSet();

  AuthSession sessionWith(String token, Set<String> permissions) => AuthSession(
    token: token,
    userId: 4,
    name: 'Айгуль',
    role: 'cashier',
    permissions: permissions,
    operatingMode: 0,
    pointMode: 'cashier',
    shift: ShiftStatus.open,
    issuedAt: DateTime(2026, 9, 6),
    expiresAt: DateTime(2026, 9, 7),
    terminalId: _ownTerminal,
  );

  var streamId = 0;

  /// Один обмен по проводу целиком: открыть поток, положить кадр, закрыть
  /// свою половину — ровно так, как это делает браузер, и ровно теми
  /// событиями, которые отдаёт `rk_quic` (`till_wire.dart`, «`StreamClosed` —
  /// не отписка»).
  ///
  /// Ждёт **появления кадра**, а не фиксированную паузу: обработчики ходят в
  /// настоящую базу, и пауза, подобранная под сегодняшнюю скорость, стала бы
  /// мерцанием набора под нагрузкой.
  ///
  /// Ответ ищется по **своему потоку**, а не по счётчику записей: подписка,
  /// заведённая предыдущей пробой, живёт дальше и пишет обновления в свой
  /// поток — «первый кадр после моего вопроса» иногда оказался бы чужим, и
  /// проба падала бы через раз.
  Future<WireFrame> askWire(
    String op,
    Map<String, Object?> body, {
    String? token,
  }) async {
    final before = server.sentFrames.length;
    streamId += 4;
    final id = streamId;
    server.emitStreamOpened(sessionId: _session, streamId: id);
    server.emitStreamData(
      sessionId: _session,
      streamId: id,
      message: RequestFrame(op, body, token: token).encode(),
    );
    server.emitStreamClosed(sessionId: _session, streamId: id);

    int? mine() {
      for (var i = before; i < server.sentOn.length; i++) {
        if (server.sentOn[i].$2 == id) return i;
      }
      return null;
    }

    for (var i = 0; i < 400 && mine() == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    final index = mine();
    expect(
      index,
      isNotNull,
      reason: 'молчания не бывает: касса обязана ответить на $op',
    );
    return WireFrame.decode(server.sentFrames[index!]);
  }

  /// Код кадра отказа — или `null`, если касса ответила согласием.
  String? codeOf(WireFrame frame) => frame is ErrorFrame ? frame.code : null;

  Map<String, Object?> bodyOf(WireFrame frame) {
    expect(frame, isA<OkFrame>(), reason: 'ожидался ответ, пришло $frame');
    return (frame as OkFrame).body;
  }

  /// Первое значение подписки. Отдельным родом кадра, а не `OkFrame`: подписка
  /// отвечает [UpdateFrame], и приведение вслепую спрятало бы отказ сторожа за
  /// невнятным `TypeError`.
  Map<String, Object?> updateOf(WireFrame frame) {
    expect(
      frame,
      isA<UpdateFrame>(),
      reason: 'ожидалась подписка, пришло $frame',
    );
    return (frame as UpdateFrame).body;
  }

  /// Тело, годное для **любой** операции продажи: сторож отказывает раньше,
  /// чем обработчик посмотрит на лишние ключи, а разрешённой операции нужны
  /// её собственные — набор общий, чтобы таблица прав ниже не превращалась в
  /// таблицу тел.
  Map<String, Object?> anyBody({int baseVersion = 0}) => {
    'key': 'k${streamId + 1}',
    'baseVersion': baseVersion,
    'wholesale': true,
    'barcode': _barcode,
    'query': 'Товар',
    'lineId': 'l1',
    'mark': 'DM-1',
    'productId': 100,
    'deferredReceiptNo': 1,
    'quantity': '1',
    'percent': '10',
    'amount': '50',
    'price': '499',
  };

  Future<void> seedProduct({
    required int ucode,
    required String barcode,
    required String price,
    String name = 'Товар',
  }) async {
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: Value(ucode),
            barcode: int.parse(barcode),
            name: name,
            type: 0,
            measure: 0,
            quantity: Value(d('100')),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            ucode: Value(ucode),
            barcode: int.parse(barcode),
            sellingPrice: Value(d(price)),
          ),
        );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    invites = PairingInvites();

    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            cashBoxName: Value('Касса-тест'),
            // Задача 12: тумблер кассы «продажа со скидкой» получил
            // читателя на самой кассе, а не только на экране. Пробы ниже
            // назначают скидку, значит тумблер обязан быть включён — иначе
            // они мерили бы отказ политики.
            sellInDiscount: Value(true),
            // Задача 9 ревизии 2026-09-19: то же у тумблера «правка цены».
            // Пробы ниже мерят **право** на проводе; выключенный тумблер
            // (умолчание колонки) подменял бы их отказ своим.
            editPrice: Value(true),
          ),
        );
    await db
        .into(db.users)
        .insert(const UsersCompanion(id: Value(4), name: Value('Айгуль')));
    // Смена открыта явно и **сейчас**: касса не открывает её сама с задачи 5,
    // а смена, открытая задним числом, упирается в сторож «открыта более 24
    // часов» (`kShiftMaxAge`, `shift_controller.dart`).
    await db
        .into(db.shifts)
        .insert(
          ShiftsCompanion.insert(
            userId: 4,
            openTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            isOpened: true,
            isSynced: false,
          ),
        );
    await seedProduct(ucode: 100, barcode: _barcode, price: '500');

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

    ops = TillOperations(
      db: db,
      bootstrap: NoopBootstrap(),
      setup: NoopSetupRepository(),
      terminals: _SelfTerminals(_ownTerminal),
      deviceBindings: NoopDeviceBindingRepository(),
      auth: NoopAuth(),
      invites: invites,
      cart: cart,
    );

    sessions = _Sessions({
      // Кассир по умолчанию: продажа открыта, ни одного `op.*`.
      _tokenBare: sessionWith(_tokenBare, {PermissionKeys.navSale}),
      // Старший: продажа и все операционные права.
      _tokenFull: sessionWith(_tokenFull, {
        PermissionKeys.navSale,
        ...allOperationKeys,
      }),
    });

    server = FakeQuicServer();
    wire = TillWire(
      server,
      ops.askHandlers,
      watchHandlers: ops.watchHandlers,
      runHandlers: ops.runHandlers,
      // Тот же сторож и тот же словарь доступа, что у настоящей кассы:
      // `ApiServer.access` — это буквально то же выражение.
      guard: wireGuardForTill(
        db: db,
        access: {for (final op in TillOps.all) op.name: op.access},
        sessions: sessions,
      ),
      onSessionClosed: ops.forgetSession,
    )..start();

    streamId = 0;
    // Рабочее место заводится **по проводу** той же операцией, которой это
    // делает браузер, а не записью в приватную карту. Была
    // `terminals.selfEnsure` — открытая, без кода и без секрета; задача 19
    // вырезала оттуда запись в `_sessionTerminals`, потому что она сажала
    // любую сессию на строку самой кассы. Настоящий путь вкладки —
    // `terminals.register` с одноразовым кодом привязки.
    final bound = await askWire(TillOps.terminalRegister.name, {
      'name': 'Вкладка',
      'code': invites.mint().code,
    });
    expect(
      bodyOf(bound)['terminal'],
      isNotNull,
      reason: 'без места ни одна команда корзины не пойдёт вовсе',
    );
  });

  tearDown(() async {
    await wire.stop();
    await server.dispose();
    await db.close();
  });

  /// Начинает чек и кладёт в него строку — оба кадра под правами кассира без
  /// единого `op.*` (обе операции объявлены под `nav.sale`).
  Future<CartView> cartWithOneLine({String token = _tokenBare}) async {
    final started = cartViewFromWireJson(
      bodyOf(
        await askWire(SaleOps.start.name, {
          'key': 'start',
          'baseVersion': 0,
        }, token: token),
      ),
    );
    return cartViewFromWireJson(
      bodyOf(
        await askWire(SaleOps.addByBarcode.name, {
          'barcode': _barcode,
          'key': 'line',
          'baseVersion': started.version,
          'receiptNo': started.receiptNo,
        }, token: token),
      ),
    );
  }

  /// Снимок корзины подпиской `sale.cart` — тем же кадром, каким его берёт
  /// экран. Первое значение подписки и есть текущее состояние.
  Future<CartView> snapshot({String token = _tokenBare}) async =>
      cartViewFromWireJson(
        updateOf(await askWire(SaleOps.cart.name, const {}, token: token)),
      );

  group('скидка: отказ приходит от кассы, минуя экран', () {
    test('кассир без op.sellDiscount получает forbidden по проводу', () async {
      final view = await cartWithOneLine();

      final refused = await askWire(SaleOps.setDiscountPercent.name, {
        'lineId': view.lines.single.id,
        'percent': '10',
        'key': 'disc',
        'baseVersion': view.version,
        'receiptNo': view.receiptNo,
      }, token: _tokenBare);

      expect(codeOf(refused), 'forbidden');
    });

    test('отказал сторож, а не корзина: чек не тронут вовсе', () async {
      // Отличает «право проверено ДО обработчика» от «обработчик сходил в
      // базу и передумал». Версия чека растёт с каждой исполненной командой;
      // не выросшая версия означает, что команды не было.
      final view = await cartWithOneLine();

      await askWire(SaleOps.setDiscountPercent.name, {
        'lineId': view.lines.single.id,
        'percent': '10',
        'key': 'disc',
        'baseVersion': view.version,
        'receiptNo': view.receiptNo,
      }, token: _tokenBare);

      final after = await snapshot();
      expect(after.version, view.version, reason: 'версия не двигалась');
      expect(after.totalDiscount, Decimal.zero);
      expect(after.lines.single.discount, Decimal.zero);
    });

    test('тот же кассир с правом скидку получает', () async {
      // Управляющая проба, без которой «починка», закрывшая скидку всем
      // подряд, прошла бы обе предыдущие.
      final view = await cartWithOneLine(token: _tokenFull);

      final discounted = bodyOf(
        await askWire(SaleOps.setDiscountPercent.name, {
          'lineId': view.lines.single.id,
          'percent': '10',
          'key': 'disc',
          'baseVersion': view.version,
          'receiptNo': view.receiptNo,
        }, token: _tokenFull),
      );

      expect(discounted['totalDiscount'], isNot('0'));
      expect(
        cartViewFromWireJson(discounted).totalDiscount,
        greaterThan(Decimal.zero),
      );
    });
  });

  /// Второй фронт предела — задача 12 плана «Полнота продажи».
  ///
  /// Предел живёт в `LocalCartService`, то есть в узле, общем для кассы и
  /// браузера. Но у провода есть **собственное** свойство, которого нет у
  /// десктопа: полномочия строятся из **сеанса**, а не из тела кадра.
  /// Доказать это можно только кадром — обработчик, позванный напрямую,
  /// сеанса не разбирает.
  group('предел скидки действует и по проводу', () {
    test('предел роли отклоняет скидку кассира с правом — кадром, не '
        'исключением', () async {
      // Роль сеанса — `cashier` (см. [sessionWith]), значит предел кассира и
      // есть тот, что должен сработать. Право у сеанса есть: без него отказ
      // пришёл бы от сторожа раньше, и проба не сказала бы ничего о пределе.
      await db
          .into(db.discountLimits)
          .insertOnConflictUpdate(
            DiscountLimitsCompanion.insert(
              role: Value(UserRole.cashier.index),
              maxPercentPerLine: Value(d('20')),
            ),
          );

      final view = await cartWithOneLine(token: _tokenFull);

      final refused = await askWire(SaleOps.setDiscountPercent.name, {
        'lineId': view.lines.single.id,
        'percent': '21',
        'key': 'disc',
        'baseVersion': view.version,
        'receiptNo': view.receiptNo,
      }, token: _tokenFull);

      expect(codeOf(refused), 'denied_limit');
      expect(
        (refused as ErrorFrame).detail,
        contains('20'),
        reason: 'кассир обязан узнать из отказа, до скольки ему можно',
      );

      // Чек не тронут: отказ не оставил половины работы на той стороне.
      final after = await snapshot(token: _tokenFull);
      expect(after.totalDiscount, Decimal.zero);
    });

    test('под тем же пределом скидка в двадцать процентов проходит', () async {
      // Управляющая проба: без неё «починка», закрывшая скидку всем подряд,
      // прошла бы предыдущую.
      await db
          .into(db.discountLimits)
          .insertOnConflictUpdate(
            DiscountLimitsCompanion.insert(
              role: Value(UserRole.cashier.index),
              maxPercentPerLine: Value(d('20')),
            ),
          );

      final view = await cartWithOneLine(token: _tokenFull);

      final ok = cartViewFromWireJson(
        bodyOf(
          await askWire(SaleOps.setDiscountPercent.name, {
            'lineId': view.lines.single.id,
            'percent': '20',
            'key': 'disc',
            'baseVersion': view.version,
            'receiptNo': view.receiptNo,
          }, token: _tokenFull),
        ),
      );

      expect(ok.totalDiscount, d('100'));
    });

    test('полномочия берутся из сеанса, а не из тела кадра', () async {
      // Кадр называет роль и права **сам** — ровно тем приёмом, каким
      // вкладка пыталась бы назвать чужое рабочее место. Касса обязана их
      // не заметить: предел роли `cashier` из сеанса действует, а
      // объявленный в теле «владелец без предела» — нет.
      await db
          .into(db.discountLimits)
          .insertOnConflictUpdate(
            DiscountLimitsCompanion.insert(
              role: Value(UserRole.cashier.index),
              maxPercentPerLine: Value(d('20')),
            ),
          );

      final view = await cartWithOneLine(token: _tokenFull);

      final refused = await askWire(SaleOps.setDiscountPercent.name, {
        'lineId': view.lines.single.id,
        'percent': '21',
        'key': 'disc',
        'baseVersion': view.version,
        'receiptNo': view.receiptNo,
        // Самозванство в теле кадра.
        'role': 'owner',
        'roleIndex': 0,
        'permissions': ['op.sellDiscount', 'op.editPrice'],
      }, token: _tokenFull);

      expect(
        codeOf(refused),
        'denied_limit',
        reason: 'касса поверила телу кадра — полномочия стали подделываемыми',
      );
    });
  });

  group('правка цены и опт: op.editPrice достижимо', () {
    test('кассир без op.editPrice не переключит чек в опт', () async {
      final view = await cartWithOneLine();

      final refused = await askWire(SaleOps.setWholesale.name, {
        'wholesale': true,
        'key': 'w',
        'baseVersion': view.version,
        'receiptNo': view.receiptNo,
      }, token: _tokenBare);

      expect(codeOf(refused), 'forbidden');
      expect((await snapshot()).wholesale, isFalse);
    });

    test('старший с op.editPrice переключает', () async {
      final view = await cartWithOneLine(token: _tokenFull);

      final switched = cartViewFromWireJson(
        bodyOf(
          await askWire(SaleOps.setWholesale.name, {
            'wholesale': true,
            'key': 'w',
            'baseVersion': view.version,
            'receiptNo': view.receiptNo,
          }, token: _tokenFull),
        ),
      );

      expect(switched.wholesale, isTrue);
    });
  });

  /// Задача 9 ревизии 2026-09-19: **настройку кассы `editPrice` проверял
  /// только экран кассы**, и по проводу она не действовала вовсе.
  ///
  /// Право и настройка — разные величины с одинаковым именем (разбор в
  /// докстринге `CartService.updatePrice`). Право сторож проверяет по
  /// сеансу; настройку не проверял никто, кроме
  /// `sale_screen._showEditDialog`. Следствие у заказчика было ровно такое:
  /// с планшета цену правили вопреки «Политике продаж», выставленной на
  /// кассе.
  ///
  /// Доказать это можно только **кадром**: обработчик, позванный напрямую
  /// (`sale_operations_test.dart`), проходит за сторожа, а проба на кассе
  /// (`test/data/sale/cart_price_policy_test.dart`) провода не видит вовсе.
  /// Здесь сеанс с полным набором `op.*` — то есть право у кадра есть, и
  /// единственное, что может его остановить, это настройка кассы.
  group('настройка кассы «правка цены» доезжает до провода', () {
    Future<void> setEditPrice(bool value) =>
        (db.update(db.thisPosEntries)..where((t) => t.id.equals(1))).write(
          ThisPosEntriesCompanion(editPrice: Value(value)),
        );

    test('выключенная настройка отказывает кадру с правом', () async {
      // Повышение цены: понижение меряется пределом скидки, и отказ мог бы
      // прийти оттуда — проба говорила бы о пределе, а не о настройке.
      final view = await cartWithOneLine(token: _tokenFull);
      await setEditPrice(false);

      final refused = await askWire(SaleOps.updatePrice.name, {
        'lineId': view.lines.single.id,
        'price': '600',
        'key': 'price',
        'baseVersion': view.version,
        'receiptNo': view.receiptNo,
      }, token: _tokenFull);

      expect(codeOf(refused), 'denied_policy');
      expect(
        (await snapshot(token: _tokenFull)).lines.single.price,
        d('500'),
        reason: 'цена не менялась',
      );
    });

    test('включённая настройка тот же кадр пропускает', () async {
      // Управляющая проба: «отказ всем» прошёл бы предыдущую.
      final view = await cartWithOneLine(token: _tokenFull);
      await setEditPrice(true);

      final changed = cartViewFromWireJson(
        bodyOf(
          await askWire(SaleOps.updatePrice.name, {
            'lineId': view.lines.single.id,
            'price': '600',
            'key': 'price',
            'baseVersion': view.version,
            'receiptNo': view.receiptNo,
          }, token: _tokenFull),
        ),
      );

      expect(changed.lines.single.price, d('600'));
    });

    test(
      'без права — forbidden от сторожа, настройка тут ни при чём',
      () async {
        // Порядок отказов: право решает сторож **до** обработчика, значит
        // выключенная настройка подменить его код не может. Без этой пробы
        // «denied_policy всем подряд» выглядело бы как работающая пара.
        final view = await cartWithOneLine();
        await setEditPrice(false);

        final refused = await askWire(SaleOps.updatePrice.name, {
          'lineId': view.lines.single.id,
          'price': '600',
          'key': 'price',
          'baseVersion': view.version,
          'receiptNo': view.receiptNo,
        }, token: _tokenBare);

        expect(codeOf(refused), 'forbidden');
      },
    );
  });

  group('откладывание: op.deferSale достижимо', () {
    test('кассир без op.deferSale чек не отложит', () async {
      final view = await cartWithOneLine();

      final refused = await askWire(SaleOps.defer.name, {
        'key': 'defer',
        'baseVersion': view.version,
        'receiptNo': view.receiptNo,
      }, token: _tokenBare);

      expect(codeOf(refused), 'forbidden');
      // Чек по-прежнему в работе у места, а не в пуле.
      expect((await snapshot()).lines, hasLength(1));
    });

    test(
      'и пула отложенных не увидит — право закрыто с обеих сторон',
      () async {
        // Находка круга 1 задачи 9: список показывает имя кассира, отложившего
        // чек, то есть читающую половину той же возможности. Право, закрытое
        // наполовину, — не право.
        final refused = await askWire(
          SaleOps.deferredList.name,
          const {},
          token: _tokenBare,
        );

        expect(codeOf(refused), 'forbidden');
      },
    );

    test('старший с op.deferSale откладывает и видит пул', () async {
      final view = await cartWithOneLine(token: _tokenFull);

      final deferred = await askWire(SaleOps.defer.name, {
        'key': 'defer',
        'baseVersion': view.version,
        'receiptNo': view.receiptNo,
      }, token: _tokenFull);
      expect(codeOf(deferred), isNull);

      final pool = deferredListFromWireJson(
        updateOf(
          await askWire(SaleOps.deferredList.name, const {}, token: _tokenFull),
        ),
      );
      expect(pool.map((e) => e.receiptNo), [view.receiptNo]);
    });
  });

  group('раскладка прав достижима целиком, а не в трёх названных местах', () {
    /// Операции продажи, которым каталог назначил право из группы
    /// «операции». Список получен перебором самого каталога: операция,
    /// которой завтра поправят право, попадёт сюда сама.
    List<(String name, String needs)> opGuarded() => [
      for (final op in SaleOps.all)
        if (op.access case SessionAccess(needs: final needs?))
          if (allOperationKeys.contains(needs)) (op.name, needs),
    ];

    test('таких операций семь — число измерено, а не подразумевается', () {
      final guarded = opGuarded();
      expect(guarded, hasLength(7));
      expect(guarded.map((e) => e.$2).toSet(), {
        PermissionKeys.opSellDiscount,
        PermissionKeys.opEditPrice,
        PermissionKeys.opDeferSale,
      }, reason: 'на ветви продажи читателя получили ровно три ключа op.*');
    });

    test(
      'сеанс без своего ключа получает forbidden на каждой из семи',
      () async {
        // Диверсия первого рода: доказывает, что проверка **есть**.
        for (final (name, needs) in opGuarded()) {
          // Сеанс с всеми операционными правами, КРОМЕ одного нужного:
          // отказ «всем, у кого нет полного набора» такую пробу не прошёл бы,
          // потому что не хватает ровно одного названного ключа.
          final token = 'tok-without-$needs';
          sessions.byToken[token] = sessionWith(token, {
            PermissionKeys.navSale,
            ...allOperationKeys.where((k) => k != needs),
          });

          final frame = await askWire(name, anyBody(), token: token);
          expect(codeOf(frame), 'forbidden', reason: '$name без $needs');
        }
      },
    );

    test('тот же сеанс со своим ключом forbidden уже не получает', () async {
      // Диверсия второго рода, противоположная: доказывает, что проверка
      // смотрит именно на заявленный ключ, а не запрещает всем подряд.
      // Ответ по существу здесь не предмет — тела нарочно общие, и часть
      // операций честно откажет своей причиной (`cart_stale`,
      // `line_not_found`). Предмет один: `forbidden` не приходит.
      for (final (name, _) in opGuarded()) {
        final frame = await askWire(name, anyBody(), token: _tokenFull);
        expect(codeOf(frame), isNot('forbidden'), reason: name);
      }
    });

    test('тринадцать остальных операций правом op.* не закрыты', () async {
      // Обратная сторона той же таблицы: право, приписанное соседке
      // копипастой, красит эту строку.
      final plain = [
        for (final op in SaleOps.all)
          if (op.access case SessionAccess(needs: final needs?))
            if (!allOperationKeys.contains(needs)) op.name,
      ];
      expect(plain, hasLength(SaleOps.all.length - 7));

      for (final name in plain) {
        final frame = await askWire(name, anyBody(), token: _tokenBare);
        expect(codeOf(frame), isNot('forbidden'), reason: name);
      }
    });
  });

  group('цепочка целиком: галочка владельца — отказ на проводе', () {
    /// Пересобирает провод **настоящей** парой «репозиторий терминалов +
    /// вход»: сеансы выписывает `LocalAuthRepository` в тот самый
    /// `SessionRegistry`, который спрашивает сторож, а права в сеанс попадают
    /// из строк `user_permissions` — то есть ровно оттуда, куда их пишет
    /// форма управления пользователями.
    ///
    /// Пробы выше берут сеанс подделкой [SessionLookup] — законный шов
    /// (сторож принимает поиск сеанса портом по построению), но он оставляет
    /// недоказанным одно звено: что права, снятые владельцем в форме,
    /// доезжают до сеанса. Этот стенд его закрывает.
    Future<PairingInvites> realLogin() async {
      await wire.stop();
      await server.dispose();

      final registry = SessionRegistry();
      final invites = PairingInvites();
      ops = TillOperations(
        db: db,
        bootstrap: NoopBootstrap(),
        setup: NoopSetupRepository(),
        terminals: LocalTerminalRepository(db),
        deviceBindings: NoopDeviceBindingRepository(),
        auth: LocalAuthRepository(
          db: db,
          sessions: registry,
          throttle: LoginThrottle(),
        ),
        invites: invites,
        cart: cart,
      );
      server = FakeQuicServer();
      wire = TillWire(
        server,
        ops.askHandlers,
        watchHandlers: ops.watchHandlers,
        runHandlers: ops.runHandlers,
        guard: wireGuardForTill(
          db: db,
          access: {for (final op in TillOps.all) op.name: op.access},
          sessions: registry,
        ),
        onSessionClosed: ops.forgetSession,
      )..start();
      streamId = 0;
      return invites;
    }

    /// Кассир без PIN, которому владелец проставил ровно названные ключи.
    /// `setPermissions` — тот же вызов, которым это делает форма
    /// (`user_management_screen.dart`), а не запись в таблицу в обход.
    Future<int> cashierWith(String name, Set<String> allowed) async {
      final id = await db.userDao.createCashier(name: name, passwordEnc: null);
      await db.userPermissionDao.setPermissions(id, {
        for (final key in PermissionKeys.allPermissions)
          key: allowed.contains(key),
      });
      return id;
    }

    /// Вход **по проводу**: место заводится `terminals.register` по настоящему
    /// коду привязки, сеанс выписывает `auth.login`. Токен читается готовой
    /// половиной пары кодеков, а не по ключу руками.
    Future<String> loginOverWire(int userId, PairingInvites invites) async {
      final registered = bodyOf(
        await askWire(TillOps.terminalRegister.name, {
          'name': 'Место кассира',
          'code': invites.mint().code,
        }),
      );
      expect(registered['terminal'], isNotNull);

      final outcome = authOutcomeFromWireJson(
        bodyOf(
          await askWire(TillOps.authLogin.name, {'userId': userId, 'pin': ''}),
        ),
      );
      expect(outcome, isA<AuthSession>(), reason: 'вход обязан состояться');
      return (outcome as AuthSession).token;
    }

    test('снятая галочка «Продажа со скидкой» доезжает отказом', () async {
      final invites = await realLogin();
      final userId = await cashierWith('Кассир без скидки', {
        PermissionKeys.navSale,
      });
      final token = await loginOverWire(userId, invites);

      final view = await cartWithOneLine(token: token);
      final refused = await askWire(SaleOps.setDiscountPercent.name, {
        'lineId': view.lines.single.id,
        'percent': '10',
        'key': 'disc',
        'baseVersion': view.version,
        'receiptNo': view.receiptNo,
      }, token: token);

      expect(codeOf(refused), 'forbidden');
    });

    test('поставленная галочка доезжает скидкой', () async {
      // Управляющая проба той же цепочки: без неё «отказ всем» выглядел бы
      // как работающее право.
      final invites = await realLogin();
      final userId = await cashierWith('Кассир со скидкой', {
        PermissionKeys.navSale,
        PermissionKeys.opSellDiscount,
      });
      final token = await loginOverWire(userId, invites);

      final view = await cartWithOneLine(token: token);
      final discounted = cartViewFromWireJson(
        bodyOf(
          await askWire(SaleOps.setDiscountPercent.name, {
            'lineId': view.lines.single.id,
            'percent': '10',
            'key': 'disc',
            'baseVersion': view.version,
            'receiptNo': view.receiptNo,
          }, token: token),
        ),
      );

      expect(discounted.totalDiscount, greaterThan(Decimal.zero));
    });
  });

  group('красное состояние самой настройки', () {
    test('кадр без токена — unauthorized, а не forbidden', () async {
      // Без этой пробы `forbidden` выше был бы неотличим от «сеанса нет
      // вовсе»: сторож отказал бы одинаково, и таблица прав ничего не
      // доказывала бы.
      final frame = await askWire(SaleOps.setDiscountPercent.name, anyBody());
      expect(codeOf(frame), 'unauthorized');
    });

    test('неизвестный токен — тоже unauthorized', () async {
      final frame = await askWire(
        SaleOps.setDiscountPercent.name,
        anyBody(),
        token: 'tok-выдуманный',
      );
      expect(codeOf(frame), 'unauthorized');
    });

    test('без nav.sale закрыта и сама продажа', () async {
      const token = 'tok-no-sale';
      sessions.byToken[token] = sessionWith(token, allOperationKeys);

      final frame = await askWire(SaleOps.start.name, {
        'key': 'k',
        'baseVersion': 0,
      }, token: token);
      expect(codeOf(frame), 'forbidden');
    });

    test('провод действительно жив: разрешённая команда доезжает', () async {
      // Управляющая проба всей оснастки. Без неё «отказ на всё» — включая
      // сломанную сборку сторожа — выглядел бы как успех каждой пробы выше.
      final view = await cartWithOneLine();
      expect(view.lines.single.price, d('500'));
      expect(view.terminalId, _ownTerminal);
    });
  });
}

/// Сеансы по токену — то же, чем на настоящей кассе служит `SessionRegistry`.
class _Sessions implements SessionLookup {
  _Sessions(this.byToken);

  final Map<String, AuthSession> byToken;

  @override
  AuthSession? sessionFor(String token) => byToken[token];
}

/// Терминал этой кассы с известным номером — `terminals.selfEnsure` свяжет с
/// ним QUIC-сессию настоящим путём.
class _SelfTerminals extends EmptyTerminalRepository {
  _SelfTerminals(this.id);

  final int id;

  domain.Terminal get _terminal => domain.Terminal(
    id: id,
    name: 'Место-$id',
    pointMode: domain.PointMode.cashier,
  );

  @override
  Future<domain.Terminal> self() async => _terminal;

  /// Регистрация заведена при слиянии: задача 19 вырезала запись в
  /// `_sessionTerminals` из `terminals.selfEnsure` (она открывала строку
  /// самой кассы любой сессии), и настоящий путь вкладки браузера —
  /// `terminals.register` с одноразовым кодом.
  @override
  Future<TerminalEnrollment> register({
    required String name,
    String code = '',
  }) async => (terminal: _terminal, secret: 'секрет-$id');
}
