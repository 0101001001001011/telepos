/// Ключ провайдера QR **уезжает провайдеру и не уезжает терминалу**.
///
/// # Почему проба, а не заявление
///
/// «В ответе нет ключа» — утверждение о коде, который пишут люди, и первый
/// же удобный `...settings.toJson()` в кодеке сделает его ложным без
/// единого красного теста. Поэтому здесь касса и браузер соединены торцами
/// на настоящем графе — `TillOperations`, `TillWire`, `WtDispatcher`,
/// `WtPaymentService`, `LocalPaymentService`, `QrPaymentDesk`,
/// `HttpQrPaymentProvider` и эмулятор провайдера на сокете, — и **каждый
/// кадр, который касса отправила браузеру**, записывается и
/// просматривается.
///
/// # Проба обязана краснеть в обе стороны
///
/// Поиск ключа в ответах зелен и у кассы, которая ключ не читает вовсе.
/// Поэтому вторая половина утверждения — **провайдер ключ получил**: каждый
/// запрос к эмулятору нёс `authorization: Bearer <ключ>`. Без неё проба
/// доказывала бы только то, что ключ никуда не ездит.
library;

import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rk_quic/rk_quic.dart';
import 'package:talker/talker.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart' hide Terminal;
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/payment/qr_payment_desk.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/sale/local_payment_service.dart';
import 'package:telepos/data/sale/local_sale_checkout_service.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_use_case_impl.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/payment/qr_provider_settings.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_payment_service.dart';

import '../emulators/sbp/emulator.dart';
import '../web/support/fake_dispatcher.dart';
import '../web/support/loopback.dart';
import '../helpers/cash_drawer.dart';

const _barcode = '4870001234567';

/// Петля, которая помнит **всё, что касса отправила браузеру**.
class _RecordingLoop extends Loopback {
  final toBrowser = <String>[];

  @override
  Future<RkQuicStatus> sendOn(int sessionId, int streamId, String message) {
    toBrowser.add(message);
    return super.sendOn(sessionId, streamId, message);
  }
}

void main() {
  late AppDatabase db;
  late _RecordingLoop loop;
  late TillWire wire;
  late LocalCartService cart;
  late SbpEmulator emulator;

  Decimal d(String v) => Decimal.parse(v);

  CartCommandMeta mv(CartView v, String key) =>
      CartCommandMeta(key: key, baseVersion: v.version, receiptNo: v.receiptNo);

  Future<WtPaymentService> boot() async {
    final sessions = SessionRegistry();
    final logger = Talker();
    final invites = PairingInvites();
    cart = LocalCartService(
      db: db,
      logger: logger,
      initiation: SaleInitiationUseCaseImpl(db: db, logger: logger),
      deferred: DeferredSaleServiceImpl(db: db, logger: logger),
      rounding: SaleRoundOptionUseCaseImpl(),
      findByBarcode: FindByBarcodeUseCaseImpl(db: db, logger: logger),
      searchProducts: SearchProductInfoUseCaseImpl(db: db, logger: logger),
    );
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
      payments: LocalPaymentService(
        db: db,
        checkout: LocalSaleCheckoutService(db: db, cart: cart, logger: logger),
        sale: SaleUseCaseImpl(db: db, logger: logger),
        logger: logger,
        fiscal: const RefusingFiscalService(),
        qr: QrPaymentDesk(
          db: db,
          logger: logger,
          timeout: const Duration(milliseconds: 700),
        ),
        drawer: drawerOpens,
      ),
    );
    final session = sessions.mint(
      userId: 4,
      name: 'Айгуль',
      role: 'cashier',
      permissions: const {PermissionKeys.navSale},
      operatingMode: 0,
      pointMode: 'cashier',
      shiftOpen: true,
      terminalId: 1,
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
    return WtPaymentService(browser);
  }

  Future<CartView> receipt() async {
    final terminal = (await db.select(db.terminals).get())
        .where((t) => t.name == 'Вкладка')
        .single
        .id;
    var view = await cart.start(
      terminalId: terminal,
      wholesale: false,
      meta: const CartCommandMeta(key: 'c1', baseVersion: 0, receiptNo: null),
    );
    view = await cart.addByBarcode(terminal, _barcode, mv(view, 'c2'));
    return cart.setQuantity(terminal, view.lines.single.id, d('2'), mv(view, 'c3'));
  }

  setUp(() async {
    emulator = SbpEmulator(echo: false);
    await emulator.start('127.0.0.1', 0);
    await emulator.startControl('127.0.0.1', 0);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    loop = _RecordingLoop();
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            accountId: Value(11),
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
            userId: Value(4),
            openTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
            isOpened: Value(true),
            isSynced: Value(false),
          ),
        );
    for (final (id, type) in [
      (11, AccountType.pos),
      (12, AccountType.customBank),
    ]) {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: Value(id),
              type: type,
              name: Value('Счёт $id'),
              value: Value(Decimal.zero),
              visibleToPos: const Value(true),
            ),
          );
    }
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(100),
            barcode: int.parse(_barcode),
            name: 'Товар',
            type: 0,
            measure: 0,
            quantity: Value(Decimal.fromInt(100)),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            ucode: const Value(100),
            barcode: int.parse(_barcode),
            sellingPrice: Value(Decimal.fromInt(500)),
          ),
        );
    await db.paymentKindDao.put(
      SystemPaymentKinds.byId(SystemPaymentKindIds.qr).copyWith(isActive: true),
    );
  });

  tearDown(() async {
    await wire.stop();
    await loop.dispose();
    await db.close();
    await emulator.stop();
  });

  test('ключ едет провайдеру в каждом запросе и ни в одном кадре терминалу',
      () async {
    final secret = 'sk-live-${DateTime.now().microsecondsSinceEpoch}-SECRET';
    await db.qrProviderConfigDao.save(
      QrProviderSettings(
        baseUrl: emulator.baseUrl,
        code: 'sbp_emul',
        apiKey: secret,
      ),
      at: DateTime.now(),
    );
    final payments = await boot();
    final view = await receipt();

    // Попытка 1: код показан и отменён кассиром.
    final first = await payments.startQr(1, d('1000'), mv(view, 'a1'));
    expect(first.phase, QrTenderPhase.waiting);
    final cancelled = await payments.cancelQr(1, first.intentKey);
    expect(cancelled.phase, QrTenderPhase.cashierCancelled);

    // Попытка 2: код показан, второй на тот же чек отвергнут, покупатель
    // заплатил, чек закрыт этими деньгами.
    final second = await payments.startQr(1, d('1000'), mv(view, 'a2'));
    await expectLater(
      payments.startQr(1, d('500'), mv(view, 'a3')),
      throwsA(
        isA<WtProtocolError>().having((e) => e.code, 'code', 'qr_intent_live'),
      ),
    );
    emulator.confirm(emulator.byKey[second.intentKey]!);
    final paid = await payments.pollQr(1, second.intentKey);
    // Готовность QR (2026-09-15) — ещё один ответ кассы о провайдере; его
    // кадр проверяется ниже вместе с остальными.
    expect(await payments.qrUnavailableReason(), isNull);
    expect(paid.phase, QrTenderPhase.paid);
    final outcome = await payments.complete(
      1,
      PaymentRequest(type: PaymentType.cash, qrIntentKey: second.intentKey),
      mv(view, 'pay'),
    );
    expect(outcome.paid, d('1000'));

    // ── провайдер ключ ПОЛУЧИЛ ────────────────────────────────────────────
    expect(
      emulator.authorizations,
      isNotEmpty,
      reason: 'касса не звала провайдера — искать ключ в ответах бессмысленно',
    );
    expect(
      emulator.authorizations,
      everyElement('Bearer $secret'),
      reason: 'каждый запрос к провайдеру обязан нести ключ настройки кассы',
    );

    // ── терминал ключа НЕ получил ─────────────────────────────────────────
    final frames = loop.toBrowser;
    expect(
      frames.where((f) => f.contains(second.intentKey)),
      isNotEmpty,
      reason: 'просматриваются кадры QR, а не только кадры входа',
    );
    final providerIds = emulator.byId.keys.toList();
    expect(providerIds, hasLength(2));
    for (final frame in frames) {
      expect(frame, isNot(contains(secret)), reason: 'ключ провайдера в кадре');
      expect(
        frame,
        isNot(contains('127.0.0.1:${emulator.port}')),
        reason: 'адрес провайдера в кадре',
      );
      expect(frame, isNot(contains('sbp_emul')), reason: 'имя провайдера');
      // Ид намерения провайдера не едет **полем** — но едет внутри кода для
      // покупателя, и это не утечка, а назначение кода: нагрузку QR
      // собирает провайдер, и телефон покупателя обязан прочитать в ней,
      // куда платить (измерено первым прогоном этой пробы: эмулятор кладёт
      // `id=SBP…` в `payload`, как кладёт свой ид любой настоящий QR).
      // Поэтому ид ищется в кадре **без** нагрузки кода.
      final withoutPayload = frame.replaceAll(
        RegExp(r'"qrPayload":"[^"]*"'),
        '',
      );
      for (final id in providerIds) {
        expect(
          withoutPayload,
          isNot(contains(id)),
          reason: 'ид намерения провайдера полем кадра',
        );
      }
    }
  });

  test('настройку провайдера читает один класс, и он не на проводе', () {
    // Сторож исходника — вторая половина: проба выше ловит утечку, которая
    // случилась, этот — второго читателя, который её сделает возможной.
    // Комментарии не считаются: ссылка в докстринге ничего не читает.
    final readers = <String>{};
    final namedOnWire = <String>[];
    const wireRoots = [
      'lib/backend/',
      'lib/domain/wire/',
      'lib/web/',
      'lib/presentation/',
    ];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      final code = entity
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      if (code.contains('qrProviderConfigDao')) readers.add(path);
      if (wireRoots.any(path.startsWith) &&
          (code.contains('QrProviderSettings') ||
              code.contains('qrProviderConfigDao') ||
              code.contains('QrPaymentDesk'))) {
        namedOnWire.add(path);
      }
    }
    expect(
      readers,
      {'lib/data/payment/qr_payment_desk.dart'},
      reason: 'второй читатель настройки провайдера — второй путь для ключа',
    );
    expect(namedOnWire, isEmpty);
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
