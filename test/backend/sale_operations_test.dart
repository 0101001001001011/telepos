/// Задача 10 плана «Продажа с браузерного терминала»: касса исполняет
/// команды корзины, пришедшие по проводу.
///
/// # Два вида двойников, и оба нужны
///
/// Половина проб ниже работает поверх **настоящей** `LocalCartService` и
/// настоящей базы в памяти: повтор, не удваивающий строку, устаревшая
/// версия и разделение корзин двух рабочих мест доказываются только тем,
/// что строка легла (или не легла) в базу.
///
/// Вторая половина работает поверх записывающего двойника
/// ([_RecordingCart]), и это не леность: доказывать надо другое — что
/// **каждая** из шестнадцати команд позвала свой метод контракта своими
/// доводами. Команда, унаследовавшая вызов соседки копипастой
/// (`sale.decrement`, зовущий `increment`), поверх настоящей реализации
/// прошла бы почти все содержательные пробы: снимок вернулся, версия
/// выросла, отказа нет. Двойник красит именно её строку.
library;

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/domain/auth/auth_session.dart';
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/product_search_result.dart';
import 'package:telepos/domain/terminal/terminal.dart' as domain;
import 'package:telepos/domain/wire/cart_codec.dart';
import 'package:telepos/domain/wire/sale_ops.dart';
import 'package:telepos/domain/wire/wire_access.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

import 'support/noop_auth.dart';

import '../data/transport/till_operations_stubs.dart';
import 'package:telepos/domain/shift/shift_status.dart';

/// Рабочее место этой QUIC-сессии — то, что она заведёт через
/// `terminals.selfEnsure`.
const _ownTerminal = 7;

/// Чужое рабочее место: существует, но эта сессия его не заводила.
const _foreignTerminal = 9;

/// Ключ сессии, каким его отдаёт `TillWire` обработчику.
const _session = 1;

void main() {
  late AppDatabase db;
  late LocalCartService realCart;
  late PairingInvites invites;

  const barcodeA = '4870001234567';
  const barcodeB = '4870007654321';

  Decimal d(String v) => Decimal.parse(v);

  /// Касса с той корзиной, которую попросили. `cart: null` — процесс, не
  /// собравший реализацию продажи вовсе (`bin/telepos_backend.dart`).
  TillOperations buildOps({CartService? cart, int selfId = _ownTerminal}) =>
      TillOperations(
        db: db,
        bootstrap: NoopBootstrap(),
        setup: NoopSetupRepository(),
        terminals: _SelfTerminals(selfId),
        deviceBindings: NoopDeviceBindingRepository(),
        auth: NoopAuth(),
        invites: invites,
        cart: cart,
      );

  /// Заводит сессии [session] рабочее место — **настоящим путём**, тем же
  /// обработчиком `terminals.register`, которым это делает браузер, а не
  /// записью в приватную карту через чёрный ход. Проба, которая обошла бы
  /// этот путь, доказывала бы работу карты, а не работу кассы.
  ///
  /// Был `terminals.selfEnsure`; сменён при слиянии — довод у стуба
  /// [_SelfTerminals] ниже.
  Future<void> bindTerminal(
    TillOperations ops, {
    int session = _session,
  }) async {
    await ops.askHandlers[TillOps.terminalRegister.name]!({
      'name': 'Вкладка $session',
      'code': invites.mint().code,
    }, session);
  }

  /// Сеанс, с которым кадр доходит до обработчика.
  ///
  /// **Задача 28:** права `op.editPrice`/`op.deferSale` проверяет корзина из
  /// довода, построенного по сеансу. До неё `ask` звал обработчик вовсе без
  /// сеанса — и это работало только потому, что корзина прав не читала. В
  /// рабочей кассе такого кадра не бывает: сторож провода не пропускает
  /// операцию продажи без сеанса. Поэтому по умолчанию сеанс есть и несёт
  /// права продажи; пробы, которым предмет — сам сеанс или его отсутствие,
  /// говорят об этом явно ([withSession] или `sessionWith`).
  AuthSession seller() => AuthSession(
    token: 't-seller',
    userId: 4,
    name: 'Айгуль',
    role: 'owner',
    permissions: const {
      PermissionKeys.navSale,
      PermissionKeys.opSellDiscount,
      PermissionKeys.opEditPrice,
      PermissionKeys.opDeferSale,
    },
    operatingMode: 0,
    pointMode: 'cashier',
    shift: ShiftStatus.open,
    issuedAt: DateTime(2026, 9, 6),
    expiresAt: DateTime(2026, 9, 7),
    terminalId: _ownTerminal,
  );

  Future<Map<String, Object?>> ask(
    TillOperations ops,
    String op,
    Map<String, Object?> body, {
    int? session = _session,
    bool withSession = true,
  }) => ops.askHandlers[op]!(body, session, withSession ? seller() : null);

  Future<void> seedProduct({
    required int ucode,
    required String barcode,
    required String price,
    String name = 'Товар',
    String? wholesalePrice,
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
            wholesalePrice: Value(
              wholesalePrice == null ? null : d(wholesalePrice),
            ),
          ),
        );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    invites = PairingInvites();

    // Смена открыта и касса названа — без этого не начинается ни один чек
    // (`SaleInitiationUseCase`), а `terminals.selfEnsure` отказывает
    // `InstallationNotConfiguredException`.
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            cashBoxName: Value('Касса-тест'),
            // Задача 9 ревизии 2026-09-19: тумблер кассы «правка цены»
            // получил читателя в команде `sale.updatePrice`, а колонка по
            // умолчанию `false`. Здесь мерится разбор кадра и ход команды,
            // а не политика, — тумблер включён, чтобы отказ политики не
            // встал на место измеряемого ответа.
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

    await seedProduct(ucode: 100, barcode: barcodeA, price: '500');
    await seedProduct(
      ucode: 200,
      barcode: barcodeB,
      price: '300',
      name: 'Второй',
    );

    final logger = Talker();
    realCart = LocalCartService(
      db: db,
      logger: logger,
      initiation: SaleInitiationUseCaseImpl(db: db, logger: logger),
      deferred: DeferredSaleServiceImpl(db: db, logger: logger),
      rounding: SaleRoundOptionUseCaseImpl(),
      findByBarcode: FindByBarcodeUseCaseImpl(db: db, logger: logger),
      searchProducts: SearchProductInfoUseCaseImpl(db: db, logger: logger),
    );
  });

  tearDown(() => db.close());

  group('рабочее место берётся из сеанса, а не из тела', () {
    test('ответ несёт место сеанса, а не то, что назвал бы терминал', () async {
      final ops = buildOps(cart: realCart);
      await bindTerminal(ops);

      final answer = await ask(ops, SaleOps.start.name, {
        'key': 'k1',
        'baseVersion': 0,
        'receiptNo': null,
      });

      expect(answer['terminalId'], _ownTerminal);
    });

    test('чужое место в теле — отказ, а не чужая корзина', () async {
      // Бриф задачи 10 говорил «поле тела игнорируется». Контракт корзины
      // (`CartService`, правило 1) требует **отвергать** — решение
      // заказчика круга правки 5 задачи 7, прямо перекрывающее бриф. Здесь
      // проверяется именно отказ: молчаливое игнорирование прячет и ошибку
      // клиента, и попытку.
      final cart = _RecordingCart();
      final ops = buildOps(cart: cart);
      await bindTerminal(ops);

      await expectLater(
        ask(ops, SaleOps.start.name, {
          'key': 'k1',
          'baseVersion': 0,
          'terminalId': _foreignTerminal,
        }),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', 'terminal_in_body'),
        ),
      );

      // Отказ до корзины, а не после: касса не тронула ничего.
      expect(cart.calls, isEmpty);
    });

    test(
      'terminalId: null в теле — тоже названное место, тоже отказ',
      () async {
        // Форма, которая прошла бы мимо проверки значения. Ключ проверяется на
        // наличие именно поэтому.
        final ops = buildOps(cart: _RecordingCart());
        await bindTerminal(ops);

        await expectLater(
          ask(ops, SaleOps.increment.name, {
            'lineId': 'l1',
            'key': 'k1',
            'baseVersion': 0,
            'terminalId': null,
          }),
          throwsA(
            isA<WireRefusal>().having(
              (r) => r.code,
              'code',
              'terminal_in_body',
            ),
          ),
        );
      },
    );

    test(
      'запрет закрыт по всему каталогу продажи, а не по списку в тесте',
      () async {
        // Перебор `SaleOps.all` — закрытого списка. Операция, добавленная в
        // каталог мимо общей обёртки (`_refusingTerminalInBody`), покрасит
        // именно эту пробу, а не пройдёт по счёту.
        final ops = buildOps(cart: _RecordingCart());
        await bindTerminal(ops);

        for (final op in SaleOps.all) {
          final body = <String, Object?>{'terminalId': _foreignTerminal};
          final asked = ops.askHandlers[op.name];
          if (asked != null) {
            await expectLater(
              asked(body, _session),
              throwsA(
                isA<WireRefusal>().having(
                  (r) => r.code,
                  'code — ${op.name}',
                  'terminal_in_body',
                ),
              ),
            );
            continue;
          }
          final watched = ops.watchHandlers[op.name]!;
          expect(
            () => watched(body, _session),
            throwsA(
              isA<WireRefusal>().having(
                (r) => r.code,
                'code — ${op.name}',
                'terminal_in_body',
              ),
            ),
          );
        }
      },
    );

    test('сессия без места — unknown_terminal, корзина не тронута', () async {
      final cart = _RecordingCart();
      final ops = buildOps(cart: cart);
      // Намеренно без `bindTerminal`: сессия ничего не заводила.

      await expectLater(
        ask(ops, SaleOps.addByBarcode.name, {
          'barcode': barcodeA,
          'key': 'k1',
          'baseVersion': 0,
        }),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', 'unknown_terminal'),
        ),
      );
      expect(cart.calls, isEmpty);
    });

    test(
      'подписка на корзину — то же место и тот же отказ без сеанса',
      () async {
        final ops = buildOps(cart: realCart);
        await bindTerminal(ops);

        final first = await ops
            .watchHandlers[SaleOps.cart.name]!(const {}, _session)
            .first;
        expect(cartViewFromWireJson(first).terminalId, _ownTerminal);

        expect(
          () => ops.watchHandlers[SaleOps.cart.name]!(const {}, 404),
          throwsA(
            isA<WireRefusal>().having(
              (r) => r.code,
              'code',
              'unknown_terminal',
            ),
          ),
        );
      },
    );
  });

  group('каждая команда зовёт свой метод своими доводами', () {
    late _RecordingCart cart;
    late TillOperations ops;

    setUp(() async {
      cart = _RecordingCart();
      ops = buildOps(cart: cart);
      await bindTerminal(ops);
    });

    /// Метка команды, общая для всех шестнадцати: разбирается одной парой
    /// кодеков (`cartCommandMetaFromWireJson`), поэтому проверяется один
    /// раз, а не в каждой строке таблицы.
    Map<String, Object?> meta() => {
      'key': 'k1',
      'baseVersion': 3,
      'receiptNo': 42,
    };

    test('таблица шестнадцати команд закрыта поимённо', () async {
      final table = <String, Map<String, Object?>>{
        SaleOps.start.name: const {},
        SaleOps.addByBarcode.name: {'barcode': barcodeA},
        SaleOps.addProduct.name: {'productId': 100, 'quantity': '2.5'},
        SaleOps.setQuantity.name: {'lineId': 'l1', 'quantity': '3'},
        SaleOps.increment.name: {'lineId': 'l1'},
        SaleOps.decrement.name: {'lineId': 'l1'},
        SaleOps.setDiscountPercent.name: {'lineId': 'l1', 'percent': '10'},
        SaleOps.setDiscountAmount.name: {'lineId': 'l1', 'amount': '50'},
        SaleOps.updatePrice.name: {'lineId': 'l1', 'price': '499.5'},
        SaleOps.setMark.name: {'lineId': 'l1', 'mark': 'DM-1'},
        SaleOps.removeLine.name: {'lineId': 'l1'},
        SaleOps.clear.name: const {},
        SaleOps.defer.name: const {},
        SaleOps.loadDeferred.name: {'deferredReceiptNo': 77},
        SaleOps.setAgent.name: {'agentId': 5},
        SaleOps.setWholesale.name: {'wholesale': true},
      };

      // Ожидаемый вызов — имя метода контракта и его доводы после
      // `terminalId`. Копипаста между соседками (decrement, зовущий
      // increment) красит свою строку.
      final expected = <String, String>{
        SaleOps.start.name: 'start(false)',
        SaleOps.addByBarcode.name: 'addByBarcode($barcodeA)',
        SaleOps.addProduct.name: 'addProduct(100, 2.5)',
        SaleOps.setQuantity.name: 'setQuantity(l1, 3)',
        SaleOps.increment.name: 'increment(l1)',
        SaleOps.decrement.name: 'decrement(l1)',
        SaleOps.setDiscountPercent.name: 'setDiscountPercent(l1, 10)',
        SaleOps.setDiscountAmount.name: 'setDiscountAmount(l1, 50)',
        SaleOps.updatePrice.name: 'updatePrice(l1, 499.5)',
        SaleOps.setMark.name: 'setMark(l1, DM-1)',
        SaleOps.removeLine.name: 'removeLine(l1)',
        SaleOps.clear.name: 'clear()',
        SaleOps.defer.name: 'defer()',
        SaleOps.loadDeferred.name: 'loadDeferred(77)',
        SaleOps.setAgent.name: 'setAgent(5)',
        SaleOps.setWholesale.name: 'setWholesale(true)',
      };

      for (final entry in table.entries) {
        cart.forget();
        await ask(ops, entry.key, {...entry.value, ...meta()});
        expect(cart.calls.single, expected[entry.key], reason: entry.key);
        expect(cart.terminals.single, _ownTerminal, reason: entry.key);
        expect(
          cart.metas.single,
          const CartCommandMeta(key: 'k1', baseVersion: 3, receiptNo: 42),
          reason: entry.key,
        );
      }

      // Таблица покрывает **все** изменяющие команды каталога: семь
      // остальных операций — две подписки, поиск, `sale.ping`,
      // `sale.editTerms` (чтение условий правки строки, задача 44) и два
      // чтения быстрых товаров (задача 45) — команд не несут. Число
      // проверяется, а не подразумевается.
      expect(table.length, SaleOps.all.length - 7);
    });

    test('поднимаемый чек — deferredReceiptNo, а не receiptNo метки', () async {
      // Ловушка, названная в докстринге `CartService.loadDeferred`: в метке
      // едет номер чека, который у места **уже есть**. Прочитай обработчик
      // `receiptNo` — и касса поднимала бы «тот чек, что и так в работе»,
      // отвечая `cart_wrong_receipt` на ровном месте.
      await ask(ops, SaleOps.loadDeferred.name, {
        'deferredReceiptNo': 77,
        ...meta(),
      });

      expect(cart.calls.single, 'loadDeferred(77)');
      expect(cart.metas.single.receiptNo, 42);
    });

    test('агент снимается пустым значением, а не пропущенным полем', () async {
      await ask(ops, SaleOps.setAgent.name, {'agentId': null, ...meta()});
      expect(cart.calls.single, 'setAgent(null)');
    });

    test('деньги едут строкой; число — отказ, а не тихое приведение', () async {
      // И159. Приняв 10.5 числом, касса записала бы в чек не то, что набрал
      // кассир, и узнать об этом было бы неоткуда.
      await expectLater(
        ask(ops, SaleOps.updatePrice.name, {
          'lineId': 'l1',
          'price': 10.5,
          ...meta(),
        }),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', 'bad_request'),
        ),
      );
      expect(cart.calls, isEmpty);
    });

    test(
      'пустой lineId — отказ до корзины, а не line_not_found из неё',
      () async {
        await expectLater(
          ask(ops, SaleOps.increment.name, {'lineId': '', ...meta()}),
          throwsA(
            isA<WireRefusal>().having((r) => r.code, 'code', 'bad_request'),
          ),
        );
        expect(cart.calls, isEmpty);
      },
    );

    test('wholesale без значения — отказ, а не розница по умолчанию', () async {
      await expectLater(
        ask(ops, SaleOps.setWholesale.name, meta()),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', 'bad_request'),
        ),
      );
      expect(cart.calls, isEmpty);
    });
  });

  group('ответы собраны парами кодеков', () {
    test('снимок корзины читается обратной половиной целиком', () async {
      final ops = buildOps(cart: realCart);
      await bindTerminal(ops);

      final started = cartViewFromWireJson(
        await ask(ops, SaleOps.start.name, {'key': 'k1', 'baseVersion': 0}),
      );
      final answer = await ask(ops, SaleOps.addByBarcode.name, {
        'barcode': barcodeA,
        'key': 'k2',
        'baseVersion': started.version,
        'receiptNo': started.receiptNo,
      });

      final view = cartViewFromWireJson(answer);
      expect(view.terminalId, _ownTerminal);
      expect(view.lines, hasLength(1));
      expect(view.lines.single.price, d('500'));
      // Итог едет строкой, а не числом — дверь `wireMoney` (И159).
      expect(answer['total'], isA<String>());
    });

    test(
      'выдача поиска приезжает в том конверте, который читает терминал',
      () async {
        final ops = buildOps(cart: realCart);
        await bindTerminal(ops);

        final answer = await ask(ops, SaleOps.search.name, {'query': 'Второй'});

        // Через готовую половину пары, а не по ключу руками: опечатка в имени
        // конверта дала бы здесь пустой список — «ничего не найдено»,
        // неотличимое от честного ответа.
        final items = searchResultsFromWireJson(answer);
        expect(items.map((e) => e.name), ['Второй']);
      },
    );

    test('пул отложенных приезжает в своём конверте', () async {
      final ops = buildOps(cart: realCart);
      await bindTerminal(ops);

      final started = cartViewFromWireJson(
        await ask(ops, SaleOps.start.name, {'key': 'k1', 'baseVersion': 0}),
      );
      final added = await ask(ops, SaleOps.addByBarcode.name, {
        'barcode': barcodeA,
        'key': 'k2',
        'baseVersion': started.version,
        'receiptNo': started.receiptNo,
      });
      final view = cartViewFromWireJson(added);
      await ask(ops, SaleOps.defer.name, {
        'key': 'k3',
        'baseVersion': view.version,
        'receiptNo': view.receiptNo,
      });

      final frame = await ops
          .watchHandlers[SaleOps.deferredList.name]!(
            const {},
            _session,
            seller(),
          )
          .first;

      final pool = deferredListFromWireJson(frame);
      expect(pool.map((e) => e.receiptNo), [view.receiptNo]);
    });
  });

  group('повтор и версия — поверх настоящей корзины и настоящей базы', () {
    late TillOperations ops;

    setUp(() async {
      ops = buildOps(cart: realCart);
      await bindTerminal(ops);
    });

    test(
      'обрыв на полпути не удваивает строку: повтор отдаёт тот же снимок',
      () async {
        final started = cartViewFromWireJson(
          await ask(ops, SaleOps.start.name, {'key': 'k1', 'baseVersion': 0}),
        );
        final body = <String, Object?>{
          'barcode': barcodeA,
          'key': 'k2',
          'baseVersion': started.version,
          'receiptNo': started.receiptNo,
        };

        final first = await ask(ops, SaleOps.addByBarcode.name, body);
        final again = await ask(ops, SaleOps.addByBarcode.name, body);

        expect(again['version'], first['version']);
        expect(cartViewFromWireJson(again).lines, hasLength(1));
        // И в базе одна строка, а не одна в ответе и две на диске.
        expect(await db.select(db.saleProducts).get(), hasLength(1));
      },
    );

    test(
      'устаревшая версия — cart_stale, а не команда поверх чужого',
      () async {
        final started = cartViewFromWireJson(
          await ask(ops, SaleOps.start.name, {'key': 'k1', 'baseVersion': 0}),
        );
        await ask(ops, SaleOps.addByBarcode.name, {
          'barcode': barcodeA,
          'key': 'k2',
          'baseVersion': started.version,
          'receiptNo': started.receiptNo,
        });

        await expectLater(
          ask(ops, SaleOps.addByBarcode.name, {
            'barcode': barcodeB,
            'key': 'k3',
            // Версия та, что была ДО предыдущей команды.
            'baseVersion': started.version,
            'receiptNo': started.receiptNo,
          }),
          throwsA(
            isA<WireRefusal>().having((r) => r.code, 'code', 'cart_stale'),
          ),
        );
      },
    );

    test('две сессии — два места, и корзины у них разные', () async {
      // Вторая сессия заводит **своё** место (`selfEnsure` отдаёт тот же
      // терминал кассы, поэтому здесь вторая касса со своим номером места).
      final other = buildOps(cart: realCart, selfId: _foreignTerminal);
      await bindTerminal(other, session: 2);

      final mine = cartViewFromWireJson(
        await ask(ops, SaleOps.start.name, {'key': 'k1', 'baseVersion': 0}),
      );
      await ask(ops, SaleOps.addByBarcode.name, {
        'barcode': barcodeA,
        'key': 'k2',
        'baseVersion': mine.version,
        'receiptNo': mine.receiptNo,
      });

      final foreign = cartViewFromWireJson(
        await ask(other, SaleOps.start.name, {
          'key': 'x1',
          'baseVersion': 0,
        }, session: 2),
      );

      expect(foreign.terminalId, _foreignTerminal);
      expect(foreign.lines, isEmpty);
    });
  });

  group('круг правки 1: опт не обходит своего права', () {
    test(
      'начало чека больше не несёт опта — тело с wholesale отвергается',
      () async {
        // Измеренный обход: `sale.setWholesale` требует `op.editPrice`,
        // `sale.start` — только `nav.sale`, а `start(wholesale: true)` давала
        // ровно тот же `view.wholesale == true`. Право было декоративным.
        //
        // Закрыто снятием довода из каталога, а не условной проверкой по телу:
        // обхода, которого нет, нельзя забыть проверить. Кадр старой формы
        // получает НАЗВАННЫЙ отказ, а не тихую розницу — иначе клиент просил
        // бы опт, получал розницу и не узнавал об этом.
        final ops = buildOps(cart: realCart);
        await bindTerminal(ops);

        await expectLater(
          ask(ops, SaleOps.start.name, {
            'wholesale': true,
            'key': 'k1',
            'baseVersion': 0,
          }),
          throwsA(
            isA<WireRefusal>().having(
              (r) => r.code,
              'code',
              'wholesale_in_start',
            ),
          ),
        );
      },
    );

    test(
      'чек с провода начинается розничным, опт даёт только своя команда',
      () async {
        final ops = buildOps(cart: realCart);
        await bindTerminal(ops);

        final started = cartViewFromWireJson(
          await ask(ops, SaleOps.start.name, {'key': 'k1', 'baseVersion': 0}),
        );
        expect(started.wholesale, isFalse, reason: 'начало чека — розница');

        final switched = cartViewFromWireJson(
          await ask(ops, SaleOps.setWholesale.name, {
            'wholesale': true,
            'key': 'k2',
            'baseVersion': started.version,
            'receiptNo': started.receiptNo,
          }),
        );
        expect(switched.wholesale, isTrue);

        // И вторая половина утверждения: дверь в опт одна, и она под своим
        // ключом. Читается из объявлений каталога, а не из памяти — операция,
        // которой поправят право, покрасит эту строку.
        expect(
          (SaleOps.setWholesale.access as SessionAccess).needs,
          PermissionKeys.opEditPrice,
        );
        expect(
          (SaleOps.start.access as SessionAccess).needs,
          PermissionKeys.navSale,
        );
      },
    );
  });

  group('круг правки 1: нулевая оптовая цена — незаданная', () {
    /// Оптовый чек с провода: два кадра, как ходит браузер, — начать и
    /// переключить.
    Future<CartView> wholesaleCart(TillOperations ops) async {
      final started = cartViewFromWireJson(
        await ask(ops, SaleOps.start.name, {'key': 'w1', 'baseVersion': 0}),
      );
      return cartViewFromWireJson(
        await ask(ops, SaleOps.setWholesale.name, {
          'wholesale': true,
          'key': 'w2',
          'baseVersion': started.version,
          'receiptNo': started.receiptNo,
        }),
      );
    }

    test('ноль в оптовой цене не раздаёт товар бесплатно', () async {
      // Ноль в `ProductPrices.wholesalePrice` — ШТАТНОЕ состояние после
      // обычного импорта каталога при отсутствующей закупочной цене. До
      // этой правки оптовый чек ставил такой строке цену 0, и цепочка
      // ничем не прерывалась: подготовка чека отдаёт сумму 0 без отказа,
      // фискальный провайдер пишет цену без проверки на ноль.
      await seedProduct(
        ucode: 300,
        barcode: '4870000000001',
        price: '500',
        name: 'Ноль в опте',
        wholesalePrice: '0',
      );
      final ops = buildOps(cart: realCart);
      await bindTerminal(ops);
      final wholesale = await wholesaleCart(ops);

      final added = cartViewFromWireJson(
        await ask(ops, SaleOps.addByBarcode.name, {
          'barcode': '4870000000001',
          'key': 'w3',
          'baseVersion': wholesale.version,
          'receiptNo': wholesale.receiptNo,
        }),
      );

      expect(added.lines.single.price, d('500'), reason: 'розничная цена');
      expect(added.total, isNot(Decimal.zero));
    });

    test('настоящая оптовая цена по-прежнему применяется', () async {
      // Управляющая проба: без неё «починка», выключившая опт целиком,
      // прошла бы предыдущую и оставила бы неработающей всю возможность.
      await seedProduct(
        ucode: 400,
        barcode: '4870000000002',
        price: '500',
        name: 'Настоящий опт',
        wholesalePrice: '400',
      );
      final ops = buildOps(cart: realCart);
      await bindTerminal(ops);
      final wholesale = await wholesaleCart(ops);

      final added = cartViewFromWireJson(
        await ask(ops, SaleOps.addByBarcode.name, {
          'barcode': '4870000000002',
          'key': 'w3',
          'baseVersion': wholesale.version,
          'receiptNo': wholesale.receiptNo,
        }),
      );

      expect(added.lines.single.price, d('400'));
    });
  });

  group('круг правки 1: смена номера места не теряет чек', () {
    test(
      'чек осиротевшего места уходит в общий пул, а не в невидимость',
      () async {
        // Путь живой: неудавшееся возобновление по секрету сразу переходит в
        // новую регистрацию на ТОЙ ЖЕ QUIC-сессии (`login_controller.dart`).
        // Измеренное последствие без спасения:
        //   чек места А: receiptNo=1;  корзина места Б: пусто
        //   Sales: receiptNo=1 terminalId=А state=0;  пул отложенных: 0
        // — номер сожжён, поднять нечем, уборка мест такую строку не тронет
        // (у неё есть отпечаток секрета).
        final invites = PairingInvites();
        final ops = TillOperations(
          db: db,
          bootstrap: NoopBootstrap(),
          setup: NoopSetupRepository(),
          terminals: LocalTerminalRepository(db),
          deviceBindings: NoopDeviceBindingRepository(),
          auth: NoopAuth(),
          invites: invites,
          cart: realCart,
        );

        Future<int> register(String name) async {
          final answer = await ask(ops, TillOps.terminalRegister.name, {
            'name': name,
            'code': invites.mint().code,
          });
          return (answer['terminal']! as Map<String, Object?>)['id']! as int;
        }

        final first = await register('Место А');
        final started = cartViewFromWireJson(
          await ask(ops, SaleOps.start.name, {'key': 'k1', 'baseVersion': 0}),
        );
        await ask(ops, SaleOps.addByBarcode.name, {
          'barcode': barcodeA,
          'key': 'k2',
          'baseVersion': started.version,
          'receiptNo': started.receiptNo,
        });

        // Та же вкладка, та же QUIC-сессия, новый номер места.
        final second = await register('Место Б');
        expect(second, isNot(first));

        final mine = cartViewFromWireJson(
          await ops.watchHandlers[SaleOps.cart.name]!(const {}, _session).first,
        );
        expect(mine.terminalId, second);
        expect(mine.lines, isEmpty, reason: 'у нового места чека нет');

        final pool = deferredListFromWireJson(
          await ops
              .watchHandlers[SaleOps.deferredList.name]!(
                const {},
                _session,
                seller(),
              )
              .first,
        );
        expect(pool.map((e) => e.receiptNo), [
          started.receiptNo,
        ], reason: 'чек виден в пуле и поднимается штатной командой');
      },
    );
  });

  group('круг правки 1: место ловится в любом написании', () {
    test('terminal_id, TerminalId и вложенный объект — тот же отказ', () async {
      // Дырой это не было (место не читается из тела ни под каким
      // написанием), но объявленный смысл запрета — «ошибка клиента
      // всплывает, а не прячется», — а на ошибшемся клиенте она пряталась.
      final ops = buildOps(cart: _RecordingCart());
      await bindTerminal(ops);

      final forms = <String, Map<String, Object?>>{
        'змеиное': {'terminal_id': 9},
        'с заглавной': {'TerminalId': 9},
        'кричащее': {'TERMINAL_ID': 9},
        'хвост из заглавных': {'terminalID': 9},
        'во вложенном объекте': {
          'meta': {'terminalId': 9},
        },
        'в списке': {
          'targets': [
            {'terminalId': 9},
          ],
        },
      };

      for (final form in forms.entries) {
        await expectLater(
          ask(ops, SaleOps.increment.name, {
            'lineId': 'l1',
            'key': 'k1',
            'baseVersion': 0,
            ...form.value,
          }),
          throwsA(
            isA<WireRefusal>().having(
              (r) => r.code,
              'code',
              'terminal_in_body',
            ),
          ),
          reason: form.key,
        );
      }
    });
  });

  group('круг правки 2: третья дверь смены номера места', () {
    test('selfEnsure места сессии не меняет — спасать нечего', () async {
      // **Проба переписана при слиянии, и утверждение сменилось на
      // противоположное.** До него здесь стояло «selfEnsure тоже спасает чек
      // прежнего места»: задача 10 нашла третью дверь смены номера места и
      // подперла её тем же спасением чека, что у `register`/`resume`.
      //
      // Задача 19 (круг правки 4) вырезала саму дверь. `selfEnsure` открывал
      // строку **самой кассы** (`isSelf`) любой сессии — операция не
      // спрашивает ни кода привязки, ни секрета, — и на этой строке сидели
      // вдвоём: черновик возврата там был общим, а проба разбора кадрами
      // провода довела это до списания денег чужим правом. Спасение чека
      // было заплатой вокруг причины; убрана причина.
      //
      // Утверждать теперь надо ровно то, что стало правдой: место сессии
      // после `selfEnsure` **прежнее**, чек остаётся в работе у него же, и
      // в общий пул ничего не уезжает. «Спасать нечего» — не отсутствие
      // проверки, а её содержание.
      final invites = PairingInvites();
      final ops = TillOperations(
        db: db,
        bootstrap: NoopBootstrap(),
        setup: NoopSetupRepository(),
        terminals: LocalTerminalRepository(db),
        deviceBindings: NoopDeviceBindingRepository(),
        auth: NoopAuth(),
        invites: invites,
        cart: realCart,
      );

      final registered = await ask(ops, TillOps.terminalRegister.name, {
        'name': 'Место А',
        'code': invites.mint().code,
      });
      final first =
          (registered['terminal']! as Map<String, Object?>)['id']! as int;

      final started = cartViewFromWireJson(
        await ask(ops, SaleOps.start.name, {'key': 'k1', 'baseVersion': 0}),
      );
      await ask(ops, SaleOps.addByBarcode.name, {
        'barcode': barcodeA,
        'key': 'k2',
        'baseVersion': started.version,
        'receiptNo': started.receiptNo,
      });

      // Та же сессия просит терминал самой кассы. Строку он отдаёт — она
      // существует и до этого вызова, — но **сессию к ней не привязывает**.
      final self = await ask(ops, TillOps.terminalSelfEnsure.name, const {});
      final second =
          ((self['terminal']! as Map<String, Object?>)['id']! as int);
      expect(second, isNot(first));

      final mine = cartViewFromWireJson(
        await ops.watchHandlers[SaleOps.cart.name]!(const {}, _session).first,
      );
      expect(
        mine.terminalId,
        first,
        reason: 'место сессии осталось прежним — selfEnsure его не меняет',
      );
      expect(
        mine.lines.single.barcode,
        barcodeA,
        reason: 'чек остался в работе у того же места, а не осиротел',
      );

      final pool = deferredListFromWireJson(
        await ops
            .watchHandlers[SaleOps.deferredList.name]!(
              const {},
              _session,
              seller(),
            )
            .first,
      );
      expect(
        pool,
        isEmpty,
        reason: 'спасать было нечего — в общий пул ничего не уезжало',
      );
    });
  });

  group('круг правки 2: продолжение опта требует того же права', () {
    /// Сеанс с названными правами. Настоящий `AuthSession`, а не подделка
    /// проверки: обработчик читает ровно то поле, которое ему отдаёт сторож.
    AuthSession sessionWith(Set<String> permissions) => AuthSession(
      token: 't',
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

    /// Откладывает оптовый чек с одной строкой и возвращает его номер.
    Future<int> deferWholesale(TillOperations ops) async {
      final started = cartViewFromWireJson(
        await ask(ops, SaleOps.start.name, {'key': 'd1', 'baseVersion': 0}),
      );
      final wholesale = cartViewFromWireJson(
        await ask(ops, SaleOps.setWholesale.name, {
          'wholesale': true,
          'key': 'd2',
          'baseVersion': started.version,
          'receiptNo': started.receiptNo,
        }),
      );
      final added = cartViewFromWireJson(
        await ask(ops, SaleOps.addByBarcode.name, {
          'barcode': '4870000000002',
          'key': 'd3',
          'baseVersion': wholesale.version,
          'receiptNo': wholesale.receiptNo,
        }),
      );
      await ask(ops, SaleOps.defer.name, {
        'key': 'd4',
        'baseVersion': added.version,
        'receiptNo': added.receiptNo,
      });
      return added.receiptNo!;
    }

    setUp(() async {
      await seedProduct(
        ucode: 400,
        barcode: '4870000000002',
        price: '500',
        name: 'Настоящий опт',
        wholesalePrice: '400',
      );
    });

    test('кассир без права правки цены оптовый чек не поднимет', () async {
      // Измеренный дефект: подъём идёт под `op.deferSale`, которое у роли
      // кассира есть по умолчанию, тогда как `op.editPrice` сознательно нет.
      // Кассир без правки цены поднимал отложенный оптовый чек и добавлял
      // строку по 400 при рознице 500.
      final ops = buildOps(cart: realCart);
      await bindTerminal(ops);
      final receiptNo = await deferWholesale(ops);

      await expectLater(
        ops.askHandlers[SaleOps.loadDeferred.name]!(
          {'deferredReceiptNo': receiptNo, 'key': 'x1', 'baseVersion': 0},
          _session,
          sessionWith({PermissionKeys.navSale, PermissionKeys.opDeferSale}),
        ),
        throwsA(isA<WireRefusal>().having((r) => r.code, 'code', 'forbidden')),
      );
    });

    test('он же с правом правки цены поднимает его', () async {
      final ops = buildOps(cart: realCart);
      await bindTerminal(ops);
      final receiptNo = await deferWholesale(ops);

      final loaded = cartViewFromWireJson(
        await ops.askHandlers[SaleOps.loadDeferred.name]!(
          {'deferredReceiptNo': receiptNo, 'key': 'x1', 'baseVersion': 0},
          _session,
          sessionWith({
            PermissionKeys.navSale,
            PermissionKeys.opDeferSale,
            PermissionKeys.opEditPrice,
          }),
        ),
      );

      expect(loaded.receiptNo, receiptNo);
      expect(loaded.wholesale, isTrue);
    });

    test('розничный чек поднимается без права правки цены', () async {
      // Управляющая проба: проверка обязана молчать на рознице, иначе она
      // закрыла бы подъём вообще всем, кому не разрешена правка цены.
      final ops = buildOps(cart: realCart);
      await bindTerminal(ops);

      final started = cartViewFromWireJson(
        await ask(ops, SaleOps.start.name, {'key': 'r1', 'baseVersion': 0}),
      );
      final added = cartViewFromWireJson(
        await ask(ops, SaleOps.addByBarcode.name, {
          'barcode': barcodeA,
          'key': 'r2',
          'baseVersion': started.version,
          'receiptNo': started.receiptNo,
        }),
      );
      await ask(ops, SaleOps.defer.name, {
        'key': 'r3',
        'baseVersion': added.version,
        'receiptNo': added.receiptNo,
      });

      final loaded = cartViewFromWireJson(
        await ops.askHandlers[SaleOps.loadDeferred.name]!(
          {'deferredReceiptNo': added.receiptNo, 'key': 'r4', 'baseVersion': 0},
          _session,
          sessionWith({PermissionKeys.navSale, PermissionKeys.opDeferSale}),
        ),
      );

      expect(loaded.receiptNo, added.receiptNo);
      expect(loaded.wholesale, isFalse);
    });

    test(
      'без сеанса оптовый чек не поднимается — закрыто по умолчанию',
      () async {
        final ops = buildOps(cart: realCart);
        await bindTerminal(ops);
        final receiptNo = await deferWholesale(ops);

        await expectLater(
          ask(ops, SaleOps.loadDeferred.name, {
            'deferredReceiptNo': receiptNo,
            'key': 'x1',
            'baseVersion': 0,
          }, withSession: false),
          throwsA(
            isA<WireRefusal>().having((r) => r.code, 'code', 'forbidden'),
          ),
        );
      },
    );

    /// Задача 10 ревизии 2026-09-19: подписка на пул тоже строит полномочия
    /// **из сеанса**, и проверяет их корзина.
    ///
    /// Эти три пробы зовут обработчик **напрямую, минуя сторожа** — ровно
    /// затем, чтобы доказать вторую защиту. Проба по проводу
    /// (`sale_permissions_test.dart`) показывает, что кадр без права
    /// получает `forbidden`, но отказывает там сторож, и она осталась бы
    /// зелёной, даже если бы корзина отдавала пул кому угодно. А экран
    /// кассы ходит именно так — в обход сторожа, которого у него нет.
    test('пул без права не отдаётся и за сторожом', () async {
      final ops = buildOps(cart: realCart);
      await bindTerminal(ops);
      await deferWholesale(ops);

      // Замыкание, а не готовое будущее: отказ бросается **при вызове
      // обработчика**, до возврата потока (так его ловит `TillWire
      // ._subscribe` и превращает в кадр). `expectLater` с готовым
      // выражением не поймал бы его вовсе — измерено, проба покраснела
      // именно так.
      await expectLater(
        () => ops
            .watchHandlers[SaleOps.deferredList.name]!(
              const {},
              _session,
              sessionWith({PermissionKeys.navSale}),
            )
            .first,
        throwsA(isA<WireRefusal>().having((r) => r.code, 'code', 'forbidden')),
      );
    });

    test('он же с правом пул получает', () async {
      final ops = buildOps(cart: realCart);
      await bindTerminal(ops);
      final receiptNo = await deferWholesale(ops);

      final pool = deferredListFromWireJson(
        await ops
            .watchHandlers[SaleOps.deferredList.name]!(
              const {},
              _session,
              sessionWith({PermissionKeys.navSale, PermissionKeys.opDeferSale}),
            )
            .first,
      );

      expect(pool.map((e) => e.receiptNo), [receiptNo]);
    });

    test('без сеанса пул закрыт — закрыто по умолчанию', () async {
      // Полномочия, которых нет, — `DiscountAuthority.none`: ни одного
      // права. Без этой пробы «сеанса нет → полный доступ» прошло бы обе
      // предыдущие.
      final ops = buildOps(cart: realCart);
      await bindTerminal(ops);
      await deferWholesale(ops);

      await expectLater(
        () => ops
            .watchHandlers[SaleOps.deferredList.name]!(const {}, _session)
            .first,
        throwsA(isA<WireRefusal>().having((r) => r.code, 'code', 'forbidden')),
      );
    });
  });

  group('круг правки 2: спасение не вешает регистрацию', () {
    test(
      'корзина, не отдающая первого кадра, не держит вторую регистрацию',
      () async {
        // Перехват глотает отказ, но не зависание: без срока вторая
        // регистрация ждала бы чужой чек вечно, и вкладка не получила бы ни
        // ответа, ни отказа.
        final invites = PairingInvites();
        final ops = TillOperations(
          db: db,
          bootstrap: NoopBootstrap(),
          setup: NoopSetupRepository(),
          terminals: LocalTerminalRepository(db),
          deviceBindings: NoopDeviceBindingRepository(),
          auth: NoopAuth(),
          invites: invites,
          cart: _SilentCart(),
          // Свой срок, а не пятисекундный умолчательный: проба меряет то, что
          // спасение возвращается по сроку, а не сколько этот срок длится.
          rescueDeadline: const Duration(milliseconds: 100),
        );

        Future<int> register(String name) async {
          final answer = await ask(ops, TillOps.terminalRegister.name, {
            'name': name,
            'code': invites.mint().code,
          });
          return (answer['terminal']! as Map<String, Object?>)['id']! as int;
        }

        await register('Место А');
        // Вторая регистрация обязана вернуться сама, по сроку спасения, а не
        // висеть. Собственный срок пробы вдвое длиннее — иначе краснела бы она,
        // а не измеряемое свойство.
        final second = await register(
          'Место Б',
        ).timeout(const Duration(seconds: 5));

        expect(second, greaterThan(0));
      },
    );
  });

  group('касса без реализации продажи', () {
    test('все операции корзины отказывают названной причиной', () async {
      final ops = buildOps();
      await bindTerminal(ops);

      // `sale.ping` — единственная, которая корзины не спрашивает вовсе:
      // она заведена ради замера круга и ничего не трогает.
      final needCart = SaleOps.all.where(
        (op) => op.name != SaleOps.salePing.name,
      );
      expect(needCart, hasLength(SaleOps.all.length - 1));

      for (final op in needCart) {
        final body = <String, Object?>{
          'key': 'k1',
          'baseVersion': 0,
          'wholesale': false,
          'barcode': barcodeA,
          'query': 'что-нибудь',
          'lineId': 'l1',
          'mark': 'DM-1',
          'productId': 100,
          'deferredReceiptNo': 1,
          'quantity': '1',
          'percent': '1',
          'amount': '1',
          'price': '1',
        };
        final asked = ops.askHandlers[op.name];
        if (asked != null) {
          await expectLater(
            asked(body, _session),
            throwsA(
              isA<WireRefusal>().having(
                (r) => r.code,
                'code — ${op.name}',
                'no_sale_module',
              ),
            ),
          );
          continue;
        }
        expect(
          () => ops.watchHandlers[op.name]!(body, _session),
          throwsA(
            isA<WireRefusal>().having(
              (r) => r.code,
              'code — ${op.name}',
              'no_sale_module',
            ),
          ),
        );
      }
    });
  });
}

/// Терминал этой кассы — с заданным номером, чтобы регистрация связала
/// сессию с **известным** местом настоящим путём.
///
/// `register` заведён при слиянии. До него пробы связывали сессию через
/// `terminals.selfEnsure`, и это перестало работать: задача 19 вырезала
/// оттуда запись в `_sessionTerminals` — она открывала строку самой кассы
/// (`isSelf`) любой сессии, без кода привязки и без секрета, и черновик
/// возврата на этой строке был общим (разбор — обработчик `selfEnsure` в
/// `till_operations.dart`). Настоящий путь вкладки браузера — и до, и
/// после того реза — это `terminals.register` с одноразовым кодом
/// (`login_controller.dart`: `self()` там, где база своя, `register()` там,
/// где базы нет).
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

  @override
  Future<TerminalEnrollment> register({
    required String name,
    String code = '',
  }) async => (terminal: _terminal, secret: 'секрет-$id');
}

/// Записывающий двойник контракта корзины.
///
/// Возвращает всем командам один и тот же снимок: содержимое ответа здесь не
/// предмет проверки — предмет в том, **какой метод** позвали и **с чем**.
class _RecordingCart implements CartService {
  final List<String> calls = [];
  final List<int> terminals = [];
  final List<CartCommandMeta> metas = [];

  /// Забывает всё разом. Три списка чистятся вместе намеренно: почищенный
  /// один из трёх — это `single` поверх остатков предыдущей строки таблицы,
  /// то есть падение не там, где ошибка.
  void forget() {
    calls.clear();
    terminals.clear();
    metas.clear();
  }

  CartView _record(int terminalId, CartCommandMeta meta, String call) {
    calls.add(call);
    terminals.add(terminalId);
    metas.add(meta);
    return CartView(
      posId: 1,
      terminalId: terminalId,
      version: 1,
      lines: const [],
      wholesale: false,
    );
  }

  @override
  Stream<CartView> watch(int terminalId) => Stream.value(
    CartView(
      posId: 1,
      terminalId: terminalId,
      version: 0,
      lines: const [],
      wholesale: false,
    ),
  );

  @override
  Stream<List<DeferredCart>> watchDeferred({required DiscountAuthority by}) =>
      Stream.value(const []);

  @override
  Future<List<ProductSearchResult>> search(String query) async {
    calls.add('search($query)');
    return const [];
  }

  @override
  Future<CartView> start({
    required int terminalId,
    required bool wholesale,
    required CartCommandMeta meta,
  }) async => _record(terminalId, meta, 'start($wholesale)');

  @override
  Future<CartView> addByBarcode(
    int terminalId,
    String barcode,
    CartCommandMeta meta,
  ) async => _record(terminalId, meta, 'addByBarcode($barcode)');

  @override
  Future<CartView> addProduct(
    int terminalId,
    int productId,
    Decimal quantity,
    CartCommandMeta meta,
  ) async => _record(terminalId, meta, 'addProduct($productId, $quantity)');

  @override
  Future<CartView> setQuantity(
    int terminalId,
    String lineId,
    Decimal quantity,
    CartCommandMeta meta,
  ) async => _record(terminalId, meta, 'setQuantity($lineId, $quantity)');

  @override
  Future<CartView> increment(
    int terminalId,
    String lineId,
    CartCommandMeta meta,
  ) async => _record(terminalId, meta, 'increment($lineId)');

  @override
  Future<CartView> decrement(
    int terminalId,
    String lineId,
    CartCommandMeta meta,
  ) async => _record(terminalId, meta, 'decrement($lineId)');

  @override
  Future<CartView> setDiscountPercent(
    int terminalId,
    String lineId,
    Decimal percent,
    CartCommandMeta meta, {
    required DiscountAuthority by,
  }) async =>
      _record(terminalId, meta, 'setDiscountPercent($lineId, $percent)');

  @override
  Future<CartView> setDiscountAmount(
    int terminalId,
    String lineId,
    Decimal amount,
    CartCommandMeta meta, {
    required DiscountAuthority by,
  }) async => _record(terminalId, meta, 'setDiscountAmount($lineId, $amount)');

  @override
  Future<CartView> updatePrice(
    int terminalId,
    String lineId,
    Decimal price,
    CartCommandMeta meta, {
    required DiscountAuthority by,
  }) async => _record(terminalId, meta, 'updatePrice($lineId, $price)');

  @override
  Future<CartView> setMark(
    int terminalId,
    String lineId,
    String mark,
    CartCommandMeta meta,
  ) async => _record(terminalId, meta, 'setMark($lineId, $mark)');

  @override
  Future<CartView> removeLine(
    int terminalId,
    String lineId,
    CartCommandMeta meta,
  ) async => _record(terminalId, meta, 'removeLine($lineId)');

  @override
  Future<CartView> clear(int terminalId, CartCommandMeta meta) async =>
      _record(terminalId, meta, 'clear()');

  @override
  Future<CartView> defer(
    int terminalId,
    CartCommandMeta meta, {
    required DiscountAuthority by,
  }) async => _record(terminalId, meta, 'defer()');

  @override
  Future<CartView> loadDeferred(
    int terminalId,
    int receiptNo,
    CartCommandMeta meta, {
    required DiscountAuthority by,
    int? deferredPosId,
  }) async => _record(terminalId, meta, 'loadDeferred($receiptNo)');

  @override
  Future<CartView> setAgent(
    int terminalId,
    int? agentId,
    CartCommandMeta meta,
  ) async => _record(terminalId, meta, 'setAgent($agentId)');

  @override
  Future<CartView> setWholesale(
    int terminalId,
    bool value,
    CartCommandMeta meta, {
    required DiscountAuthority by,
  }) async => _record(terminalId, meta, 'setWholesale($value)');
}

/// Корзина, чья подписка не отдаёт первого кадра никогда — круг правки 2.
///
/// Не выдумка: ровно так выглядит любая реализация, ждущая источник, который
/// не отвечает. Нужна затем, чтобы измерить срок спасения, а не поверить в
/// него.
class _SilentCart extends _RecordingCart {
  @override
  Stream<CartView> watch(int terminalId) => StreamController<CartView>().stream;
}
