/// Ревизия остатков пересекает рабочие места — пункт 12 ревизии 2026-09-19.
///
/// # Что доказывается
///
/// Что **продажа, проведённая одним рабочим местом, доезжает до другого**.
/// До этой работы предел был назван прямо в коде `StockRevision`: счётчик
/// живёт в контейнере одного экрана, и чужая продажа его не поднимает. В
/// магазине с кассой и двумя планшетами остаток на соседнем экране
/// устаревал молча — а «молча» здесь хуже ошибки: цифра выглядит свежей.
///
/// # Почему по проводу, а не вызовом обработчика
///
/// Тем же доводом, что `sale_permissions_test.dart`. Здесь кадр проходит
/// настоящий `wireGuardForTill`, собранный тем же выражением
/// `{for (final op in TillOps.all) op.name: op.access}`, каким его собирает
/// `ApiServer`, и подписку заводит настоящий `WtStockChanges`.
///
/// # Чего эти пробы НЕ доказывают
///
/// - Что экран перечитает остаток: это `StockRevision` и подписанные на
///   него (`catalog_controller.dart`, `sale_controller.dart`).
/// - Что доедет **инвентаризация и перемещение**: их проводят экраны
///   кассы мимо `PaymentService`, и до кассы как процесса они не доходят.
///   Названо в докстринге `StockRevision`, не закрыто.
/// - Что доедет продажа **соседней кассы**: у неё свой процесс и своя
///   база. Это синхронизация (пункт 18), а не подписка.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart' hide Terminal;
import 'package:telepos/data/stock/local_stock_changes.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/stock/stock_changes.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_stock_changes.dart';

import '../data/transport/till_operations_stubs.dart';
import 'support/fake_dispatcher.dart';
import 'support/loopback.dart';

void main() {
  late AppDatabase db;
  late Loopback loop;
  late TillWire wire;
  late SessionRegistry sessions;
  late PairingInvites invites;
  late LocalStockChanges tillStock;

  Future<WtDispatcher> browser(Set<String> permissions) async {
    final session = sessions.mint(
      userId: 4,
      name: 'Айгуль',
      role: 'cashier',
      permissions: permissions,
      operatingMode: 0,
      pointMode: 'cashier',
      shiftOpen: true,
      terminalId: 1,
    );
    final dispatcher = WtDispatcher(loop, tokens: FakeTokens(session.token));
    await dispatcher.ask<TerminalRegisterRequest, TerminalEnrollment>(
      TillOps.terminalRegister,
      (name: 'Вкладка', code: invites.mint().code),
    );
    return dispatcher;
  }

  Future<TillWire> start({StockChanges? stockChanges}) async {
    final operations = TillOperations(
      db: db,
      bootstrap: NoopBootstrap(),
      setup: NoopSetupRepository(),
      terminals: LocalTerminalRepository(db),
      invites: invites,
      deviceBindings: NoopDeviceBindingRepository(),
      auth: LocalAuthRepository(
        db: db,
        sessions: sessions,
        throttle: LoginThrottle(),
      ),
      stockChanges: stockChanges,
    );
    return TillWire(
      loop,
      operations.askHandlers,
      watchHandlers: operations.watchHandlers,
      runHandlers: operations.runHandlers,
      guard: wireGuardForTill(
        db: db,
        access: {for (final op in TillOps.all) op.name: op.access},
        sessions: sessions,
      ),
    )..start();
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    loop = Loopback();
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            cashBoxName: Value('Касса-петля'),
          ),
        );
    await db
        .into(db.users)
        .insert(const UsersCompanion(id: Value(4), name: Value('Айгуль')));

    sessions = SessionRegistry();
    invites = PairingInvites();
    tillStock = LocalStockChanges();
    wire = await start(stockChanges: tillStock);
  });

  tearDown(() async {
    await wire.stop();
    await loop.dispose();
    await tillStock.dispose();
    await db.close();
  });

  test('первый кадр несёт текущий номер, а не ждёт события', () async {
    // Иначе вкладка, подписавшаяся после того, как остаток уже двигали,
    // не узнала бы номера вовсе — и подписка выглядела бы живой, ничего не
    // сказав. Род `Watch` на проводе обязан нести текущее значение первым.
    tillStock.stockChanged();
    tillStock.stockChanged();

    final stream = WtStockChanges(
      await browser({PermissionKeys.navSale}),
    ).watch();

    expect(await stream.first, 2);
  });

  test('изменение на кассе доезжает до вкладки', () async {
    final seen = <int>[];
    final sub = WtStockChanges(await browser({PermissionKeys.navSale}))
        .watch()
        .listen(seen.add);

    // Ждём первого кадра, чтобы подписка точно завелась: иначе событие
    // кассы ушло бы раньше, чем подписчик появился, и проба мерила бы
    // гонку, а не провод.
    await _until(() => seen.isNotEmpty);
    expect(seen, [0], reason: 'предпосылка: остаток ещё не двигали');

    tillStock.stockChanged();
    await _until(() => seen.length >= 2);
    expect(seen, [0, 1]);

    tillStock.stockChanged();
    await _until(() => seen.length >= 3);
    expect(seen, [0, 1, 2], reason: 'номер растёт, а не мигает');

    await sub.cancel();
  });

  test('две вкладки узнают об одном изменении обе', () async {
    // Это и есть починка: рабочих мест у кассы много, и продажа одного
    // обязана дойти до **каждого**, а не до того, кто её провёл.
    final first = <int>[];
    final second = <int>[];
    final subA = WtStockChanges(await browser({PermissionKeys.navSale}))
        .watch()
        .listen(first.add);
    final subB = WtStockChanges(await browser({PermissionKeys.navCatalog}))
        .watch()
        .listen(second.add);

    await _until(() => first.isNotEmpty && second.isNotEmpty);

    tillStock.stockChanged();

    await _until(() => first.length >= 2 && second.length >= 2);
    expect(first.last, 1);
    expect(
      second.last,
      1,
      reason: 'второе рабочее место — с другим правом, и тоже узнало',
    );

    await subA.cancel();
    await subB.cancel();
  });

  test('без сеанса — отказ, а не тишина', () async {
    // Подписка без сеанса обязана отказать значением. Молчащая подписка
    // неотличима на вкладке от кассы, где остаток не двигали, и кассир
    // доверял бы старой цифре.
    final dispatcher = WtDispatcher(loop, tokens: FakeTokens(null));

    await expectLater(
      WtStockChanges(dispatcher).watch(),
      emitsError(isA<Object>()),
    );
  });

  test('касса без продажи отказывает названной причиной', () async {
    await wire.stop();
    wire = await start();
    final stream = WtStockChanges(
      await browser({PermissionKeys.navSale}),
    ).watch();

    await expectLater(
      stream,
      emitsError(
        isA<WireRefusal>().having((r) => r.code, 'code', 'no_sale_module'),
      ),
    );
  });
}

/// Ждёт условия, а не фиксированную паузу: кадры идут через петлю и
/// микрозадачи, и пауза, подобранная под сегодняшнюю скорость, стала бы
/// мерцанием набора под нагрузкой.
Future<void> _until(bool Function() ready) async {
  for (var i = 0; i < 400 && !ready(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
