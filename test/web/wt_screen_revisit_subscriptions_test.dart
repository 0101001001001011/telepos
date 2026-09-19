/// Сколько подписок копится, когда кассир ходит по экранам, — замер
/// приёмки 2026-09-17.
///
/// # Что видела приёмка
///
/// `stand/state` показывал рост живых подписок при переходах между
/// экранами: 5 → 6 → 13 за сессию, без единой закрытой вкладки. Гипотеза
/// приёмки — «экраны не снимают подписки провода при уходе».
///
/// # Что измерено здесь
///
/// Гипотеза **не подтвердилась**, и подтвердиться не могла: снятие есть, но
/// кассе оно невидимо по построению транспорта.
///
/// 1. Вкладка отменяет `StreamSubscription`, и `WtDispatcher` закрывает
///    свой поток (`_exchange`, `onCancel: shutDown`). После отмены касса
///    больше не доставляет этой подписке ничего — проба это утверждает
///    напрямую.
/// 2. **Кадра «отписаться» в этом проводе не существует вовсе** — родов
///    кадра шесть, и такого среди них нет (`wire_frame.dart`; решение
///    задокументировано в `TillSubscriptions`). Закрытие потока касса
///    намеренно игнорирует (`till_wire.dart`, `case StreamClosed(): break`
///    — оно приходит сразу за вопросом и об уходе терминала не говорит).
/// 3. Значит запись о брошенной подписке уходит из счёта **только по первой
///    неудачной доставке**. У молчащего источника — пустая корзина,
///    неизменный черновик возврата — такой доставки не случается, и
///    брошенная подписка остаётся в счёте сколь угодно долго.
///
/// Отсюда: `liveSubscriptions` — число записей в карте, а не число
/// подписок, которые кому-то что-то доставляют. Рост 5 → 6 → 13 — это
/// **счёт мёртвых**, а не утечка. Имя величины обещает второе, отдаёт
/// первое — расхождение имени и смысла и породило вопрос приёмки.
///
/// # Почему проба про оба экрана сразу
///
/// Приёмка назвала продажу и возврат. У них разные источники и разное
/// поведение счёта — и именно на этой разнице видно, что дело в источнике,
/// а не в экране: после записи в корзину брошенные подписки продажи из
/// счёта уходят, а брошенные подписки возврата, чей источник молчит,
/// остаются на месте.
///
/// # Проба всё-таки краснеет
///
/// Замер, доказывающий «дефекта нет», обязан уметь покраснеть — иначе он
/// доказывает лишь сам себя. Диверсия: `WtDispatcher._exchange`,
/// `onCancel: shutDown` → `onCancel: () {}` (вкладка перестаёт закрывать
/// поток на уходе). Красное: `Expected: <0>, Actual: <3>` — три подписки
/// остаются в счёте и **после** записи, потому что доставка в них
/// удаётся. Вот как выглядела бы настоящая утечка, и она выглядит не так,
/// как рост 5 → 6 → 13.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';

import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/web/wt_cart_service.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_refund_service.dart';

import '../backend/support/recording_refund.dart';
import 'support/fake_dispatcher.dart';
import 'support/loopback.dart';

const _terminalId = 1;

void main() {
  late AppDatabase db;
  late Loopback loop;
  late TillWire wire;
  late WtCartService cart;
  late WtRefundService refunds;

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

    final logger = Talker(settings: TalkerSettings(useConsoleLogs: false));
    final sessions = SessionRegistry();
    final invites = PairingInvites();
    final operations = TillOperations(
      db: db,
      bootstrap: _NoopBootstrap(),
      setup: _NoopSetup(),
      terminals: LocalTerminalRepository(db),
      deviceBindings: LocalDeviceBindingRepository(
        db,
        BuiltinDeviceProfileCatalog(),
      ),
      auth: LocalAuthRepository(
        db: db,
        sessions: sessions,
        throttle: LoginThrottle(),
      ),
      invites: invites,
      cart: LocalCartService(
        db: db,
        logger: logger,
        initiation: SaleInitiationUseCaseImpl(db: db, logger: logger),
        deferred: DeferredSaleServiceImpl(db: db, logger: logger),
        rounding: SaleRoundOptionUseCaseImpl(),
        findByBarcode: FindByBarcodeUseCaseImpl(db: db, logger: logger),
        searchProducts: SearchProductInfoUseCaseImpl(db: db, logger: logger),
      ),
      refund: RecordingRefund(),
    );
    final session = sessions.mint(
      userId: 4,
      name: 'Айгуль',
      role: 'cashier',
      permissions: const {PermissionKeys.navSale, PermissionKeys.opRefund},
      operatingMode: 0,
      pointMode: 'cashier',
      shiftOpen: true,
      terminalId: _terminalId,
    );
    wire = TillWire(
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

    final browser = WtDispatcher(loop, tokens: FakeTokens(session.token));
    await browser.ask<TerminalRegisterRequest, TerminalEnrollment>(
      TillOps.terminalRegister,
      (name: 'Вкладка', code: invites.mint().code),
    );
    cart = WtCartService(browser);
    refunds = WtRefundService(browser);
  });

  tearDown(() async {
    await wire.stop();
    await loop.dispose();
    await db.close();
  });

  /// Запись в корзину — единственный способ заставить кассу **писать** в
  /// подписки продажи. Именно попытка записи и снимает с учёта брошенные.
  Future<void> writeToCart(int receiptNo) => db
      .into(db.sales)
      .insert(
        SalesCompanion.insert(
          receiptNo: receiptNo,
          posId: 1,
          userId: 4,
          amount: Decimal.zero,
          time: 1700000000,
          terminalId: const Value(_terminalId),
        ),
      );

  test('заход и уход с экрана продажи: вкладка снимает подписку, касса — нет', () async {
    final views = <CartView>[];

    // Три круга «зашёл — ушёл», как их делает кассир.
    for (var visit = 0; visit < 3; visit++) {
      final subscription = cart.watch(_terminalId).listen(views.add);
      await settleLoopback();
      expect(
        wire.liveSubscriptions,
        visit + 1,
        reason:
            'круг $visit: в счёте кассы — новая подписка плюс все брошенные '
            'прежде. Растёт ровно линейно, по одной на заход, и это уже '
            'половина ответа приёмке',
      );
      await subscription.cancel();
      await settleLoopback();
    }

    expect(
      wire.liveSubscriptions,
      3,
      reason:
          'счёт кассы обязан показывать ТРИ брошенные подписки — это и есть '
          'измеряемое свойство: отписка кассе невидима, и запись уходит из '
          'карты только по неудачной доставке (`till_subscriptions.dart`)',
    );

    final seenBefore = views.length;

    // Касса пишет в корзину — первая же доставка и разбирает мёртвых.
    await writeToCart(9001);
    await settleLoopback();

    expect(
      wire.liveSubscriptions,
      0,
      reason:
          'после первой записи в брошенные потоки счёт обязан обнулиться: '
          'живых подписок на продаже нет ни одной',
    );
    expect(
      views.length,
      seenBefore,
      reason:
          'УШЕДШИЙ ЭКРАН ПОЛУЧИЛ ОБНОВЛЕНИЕ. Отмена подписки на стороне '
          'вкладки обязана закрывать поток немедленно — `WtDispatcher.'
          '_exchange`, `onCancel: shutDown`.',
    );
  });

  test('открытый экран продажи обновления получает — контроль замера выше', () async {
    final views = <CartView>[];
    final subscription = cart.watch(_terminalId).listen(views.add);
    await settleLoopback();
    final seenBefore = views.length;

    await writeToCart(9002);
    await settleLoopback();

    expect(
      views.length,
      greaterThan(seenBefore),
      reason:
          'без этого контроля «ушедший экран ничего не получил» значило бы '
          'лишь, что касса не пишет вовсе',
    );
    expect(wire.liveSubscriptions, 1);

    await subscription.cancel();
  });

  test('молчащий источник держит брошенные подписки в счёте сколь угодно долго', () async {
    // Возврат: его черновик в этой пробе не меняется ни разу — ровно то
    // состояние, в котором кассир ходит по экранам, ничего не возвращая.
    final drafts = <RefundView>[];
    for (var visit = 0; visit < 3; visit++) {
      final subscription = refunds.watch(_terminalId).listen(drafts.add);
      await settleLoopback();
      await subscription.cancel();
      await settleLoopback();
    }

    expect(
      wire.liveSubscriptions,
      3,
      reason: 'три брошенные подписки возврата — в счёте',
    );

    // Запись в КОРЗИНУ подписок возврата не касается: у них свой источник.
    await writeToCart(9003);
    await settleLoopback();

    expect(
      wire.liveSubscriptions,
      3,
      reason:
          'ИМЕННО ЗДЕСЬ ВИДНО, ЧТО РОСТ — СЧЁТ МЁРТВЫХ, А НЕ УТЕЧКА '
          'ЭКРАНОВ: подписки возврата брошены вкладкой, их источник молчит, '
          'и касса не узнает об уходе, пока ей нечего слать. Чинить это в '
          'экранах нечем — они своё уже сделали.',
    );
  });
}

class _NoopBootstrap implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async =>
      AppInitStatus.success;
}

class _NoopSetup implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {}
}
