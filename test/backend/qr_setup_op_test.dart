/// Настройка оплаты по QR из браузера — решение заказчика 2026-09-18.
///
/// # Что здесь соединено торцами
///
/// Обе половины провода на настоящем графе: база drift, настоящая
/// `QrPaymentDesk` под настоящей `LocalPaymentService`, настоящие
/// `TillOperations`, `TillWire` со **сторожем прав** — и настоящий
/// `WtQrProviderSetup` поверх настоящего `WtDispatcher`. Подставлен один
/// QUIC (нативной библиотеки под `flutter test` нет).
///
/// # Главное утверждение — **ключ провайдера не едет в браузер**
///
/// И оно проверяется так же, как соседнее в
/// `qr_secret_never_reaches_terminal_test`: петля запоминает **каждый кадр,
/// который касса отправила браузеру**, и ключ ищется в каждом.
///
/// Проба обязана краснеть в обе стороны, поэтому у утверждения две половины:
///
/// 1. **ключ доехал до кассы и лёг в её базу** — иначе поиск в ответах был бы
///    зелен на кассе, которая ключа не сохранила вовсе;
/// 2. **ни один кадр кассы его не несёт** — при том, что кадры настройки в
///    записи есть (проверяется по имени провайдера, которое ездить **обязано**).
///
/// Без первой половины проба доказывала бы только то, что ключ никуда не
/// ездит; без указания на кадры настройки — что просматривались кадры входа.
@Tags(['architecture'])
library;

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
import 'package:telepos/domain/payment/qr_provider_setup.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_qr_provider_setup.dart';

import '../helpers/cash_drawer.dart';
import '../web/support/fake_dispatcher.dart';
import '../web/support/loopback.dart';
import 'support/bare_till_deps.dart';

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
  late QrPaymentDesk desk;

  /// Поднять обе половины провода с сеансом, несущим [permissions].
  ///
  /// [withPayments] `false` — касса без раскладки оплаты, то есть и без
  /// стойки QR: голый процесс `bin/telepos_backend.dart` стоит именно так.
  Future<WtQrProviderSetup> boot(
    Set<String> permissions, {
    bool withPayments = true,
  }) async {
    final sessions = SessionRegistry();
    final logger = Talker();
    final invites = PairingInvites();
    final cart = LocalCartService(
      db: db,
      logger: logger,
      initiation: SaleInitiationUseCaseImpl(db: db, logger: logger),
      deferred: DeferredSaleServiceImpl(db: db, logger: logger),
      rounding: SaleRoundOptionUseCaseImpl(),
      findByBarcode: FindByBarcodeUseCaseImpl(db: db, logger: logger),
      searchProducts: SearchProductInfoUseCaseImpl(db: db, logger: logger),
    );
    desk = QrPaymentDesk(db: db, logger: logger);
    final operations = TillOperations(
      db: db,
      bootstrap: BareBootstrap(),
      setup: BareSetup(),
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
      // Настоящая раскладка оплаты — и **та же стойка**, которой касса
      // звонила бы провайдеру. В этом весь смысл того, что порт снимается с
      // оплаты, а не приходит отдельным доводом: собрать кассу, у которой
      // настройку правит одна стойка, а деньги берёт другая, здесь нечем.
      payments: withPayments
          ? LocalPaymentService(
              db: db,
              checkout: LocalSaleCheckoutService(
                db: db,
                cart: cart,
                logger: logger,
              ),
              sale: SaleUseCaseImpl(db: db, logger: logger),
              logger: logger,
              fiscal: const RefusingFiscalService(),
              qr: desk,
              drawer: drawerOpens,
            )
          : null,
    );
    final session = sessions.mint(
      userId: 4,
      name: 'Владелец',
      role: 'admin',
      permissions: permissions,
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
    return WtQrProviderSetup(browser);
  }

  setUp(() async {
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
        .insert(const UsersCompanion(id: Value(4), name: Value('Владелец')));
    await db.paymentKindDao.put(
      SystemPaymentKinds.byId(SystemPaymentKindIds.qr),
    );
  });

  tearDown(() async {
    await wire.stop();
    await loop.dispose();
    await db.close();
  });

  const owner = {PermissionKeys.settingsAccounts};

  Future<void> saveFromBrowser(
    WtQrProviderSetup setup, {
    String? key,
    bool clearApiKey = false,
    String baseUrl = 'https://sbp.bank/api',
    String code = 'sbp_bank',
  }) => setup.save(
    baseUrl: baseUrl,
    code: code,
    patience: const Duration(seconds: 240),
    newApiKey: key,
    clearApiKey: clearApiKey,
  );

  test('ключ уезжает на кассу и не возвращается ни одним кадром', () async {
    final secret = 'sk-live-${DateTime.now().microsecondsSinceEpoch}-SECRET';
    final setup = await boot(owner);

    await saveFromBrowser(setup, key: secret);
    final view = await setup.read();
    await setup.setKindActive(true);
    final after = await setup.read();

    // ── ключ ДОЕХАЛ ДО КАССЫ ────────────────────────────────────────────
    //
    // Без этой половины поиск ниже был бы зелен и у кассы, которая ключа не
    // сохранила вовсе, — и проба доказывала бы только то, что ключ никуда не
    // ездит.
    final stored = await db.qrProviderConfigDao.read();
    expect(stored?.apiKey, secret, reason: 'касса ключ не сохранила');
    expect(stored?.baseUrl, 'https://sbp.bank/api');
    expect(stored?.patience, const Duration(seconds: 240));

    // Настройка видна вкладке — но о ключе ей известно ровно одно слово.
    expect(view.configured, isTrue);
    expect(view.keySet, isTrue);
    expect(view.baseUrl, 'https://sbp.bank/api');
    expect(view.code, 'sbp_bank');
    expect(view.patience, const Duration(seconds: 240));
    expect(after.kindActive, isTrue);

    // ── ключ НЕ ВЕРНУЛСЯ ────────────────────────────────────────────────
    final frames = loop.toBrowser;
    expect(
      frames.where((f) => f.contains('sbp_bank')),
      isNotEmpty,
      reason:
          'просматриваются кадры настройки, а не только кадры входа: имя '
          'провайдера ездить обязано — экран его показывает',
    );
    for (final frame in frames) {
      expect(
        frame,
        isNot(contains(secret)),
        reason: 'ключ провайдера в кадре, отправленном кассой терминалу',
      );
    }

    // Обратное направление ключ нести обязано — иначе он не дошёл бы, а
    // проба выше зеленела бы «потому что его нигде нет».
    expect(
      loop.framesFromBrowser.where((f) => f.contains(secret)),
      isNotEmpty,
      reason: 'ключ обязан ехать от вкладки к кассе — иначе задать его нечем',
    );
  });

  test('пустое поле ключа прежний не стирает, «стереть» — стирает', () async {
    final setup = await boot(owner);
    await saveFromBrowser(setup, key: 'sk-first');

    // Пересохранение адреса без ввода ключа: экран ключа не знает и вернуть
    // его не может, поэтому молча стереть настройку он не имеет права.
    await saveFromBrowser(setup, baseUrl: 'https://sbp.bank/v2');
    expect((await db.qrProviderConfigDao.read())?.apiKey, 'sk-first');
    expect((await db.qrProviderConfigDao.read())?.baseUrl, 'https://sbp.bank/v2');
    expect((await setup.read()).keySet, isTrue);

    // Стирание — отдельное намерение, а не пустая строка.
    await saveFromBrowser(setup, clearApiKey: true);
    expect((await db.qrProviderConfigDao.read())?.apiKey, isNull);
    expect((await setup.read()).keySet, isFalse);
  });

  test('настройка с браузера правит ту же стойку, что звонит провайдеру', () async {
    // Существенно именно это: до правки порт мог бы прийти отдельным
    // доводом, и касса собралась бы со **второй** стойкой — та правила бы
    // настройку, а деньги брала первая.
    final setup = await boot(owner);
    expect(await desk.open(), isNull, reason: 'до настройки звонить некому');

    await saveFromBrowser(setup, key: 'sk-live');

    final opened = await desk.open();
    expect(opened, isNotNull);
    expect(opened!.patience, const Duration(seconds: 240));
  });

  test('снятие настройки с браузера гасит стойку', () async {
    final setup = await boot(owner);
    await saveFromBrowser(setup, key: 'sk-live');
    expect(await desk.open(), isNotNull);

    await setup.clear();

    expect(await db.qrProviderConfigDao.read(), isNull);
    expect(await desk.open(), isNull);
    expect((await setup.read()).configured, isFalse);
  });

  test('вид оплаты QR включается и выключается с браузера', () async {
    final setup = await boot(owner);
    expect((await setup.read()).kindActive, isFalse);

    await setup.setKindActive(true);
    expect((await setup.read()).kindActive, isTrue);

    await setup.setKindActive(false);
    expect((await setup.read()).kindActive, isFalse);
  });

  test('без settings.accounts касса отказывает — и настройки не меняет', () async {
    final setup = await boot(const {PermissionKeys.navSale});

    await expectLater(
      saveFromBrowser(setup, key: 'sk-stolen'),
      throwsA(isA<WireRefusal>().having((e) => e.code, 'code', 'forbidden')),
    );
    await expectLater(
      setup.read(),
      throwsA(isA<WireRefusal>().having((e) => e.code, 'code', 'forbidden')),
    );
    await expectLater(
      setup.setKindActive(true),
      throwsA(isA<WireRefusal>().having((e) => e.code, 'code', 'forbidden')),
    );
    await expectLater(
      setup.clear(),
      throwsA(isA<WireRefusal>().having((e) => e.code, 'code', 'forbidden')),
    );

    expect(await db.qrProviderConfigDao.read(), isNull);
    expect(
      (await db.paymentKindDao.rowById(SystemPaymentKindIds.qr))?.isActive,
      isFalse,
    );
  });

  test('касса без стойки QR отвечает названным кодом, а не «сохранено»',
      () async {
    // Голый процесс `bin/telepos_backend.dart`: контейнера зависимостей нет,
    // раскладки оплаты нет, стойки нет. Ответить «сохранено» было бы худшим
    // из возможного — владелец ушёл бы с экрана, считая кассу настроенной.
    final setup = await boot(owner, withPayments: false);

    await expectLater(
      setup.read(),
      throwsA(
        isA<WireRefusal>().having(
          (e) => e.code,
          'code',
          qrSetupUnavailableCode,
        ),
      ),
    );
    await expectLater(
      saveFromBrowser(setup, key: 'sk-live'),
      throwsA(
        isA<WireRefusal>().having(
          (e) => e.code,
          'code',
          qrSetupUnavailableCode,
        ),
      ),
    );
    expect(await db.qrProviderConfigDao.read(), isNull);
  });

  test('кадр, собранный мимо экрана, не роняет обработчик и не ставит нулевого '
      'терпения', () async {
    // Тело кадра пишет вкладка, вкладка не наша. Мусор обязан кончиться
    // настройкой по умолчанию и названным состоянием, а не `TypeError`,
    // уехавшим на провод именем типа (И144), и не кодом, который умирает
    // раньше, чем покупатель откроет банк.
    final ask = qrProviderSaveFromWireJson(const {
      'baseUrl': 42,
      'code': null,
      'patienceSeconds': 'много',
      'newApiKey': '   ',
    });

    expect(ask.baseUrl, '');
    expect(ask.code, '');
    expect(ask.patience.inSeconds, qrPatienceDefaultSeconds);
    expect(ask.newApiKey, isNull, reason: 'пробелы — это «не набирали»');
    expect(ask.clearApiKey, isFalse);

    // И границы держит касса, а не только экран.
    expect(
      qrProviderSaveFromWireJson(const {'patienceSeconds': 1}).patience.inSeconds,
      qrPatienceDefaultSeconds,
    );
    expect(
      qrProviderSaveFromWireJson(const {
        'patienceSeconds': 99999,
      }).patience.inSeconds,
      qrPatienceDefaultSeconds,
    );
  });

  test('в кадре ответа нет поля под ключ вовсе', () {
    // Свойство **формы**, а не внимательности пишущего: `QrProviderView` поля
    // ключа не имеет, поэтому утечке неоткуда взяться — класть нечего.
    final encoded = qrProviderViewToWireJson(
      const QrProviderView(
        configured: true,
        baseUrl: 'https://sbp.bank/api',
        code: 'sbp_bank',
        keySet: true,
        patience: Duration(seconds: 240),
        kindActive: true,
      ),
    );

    expect(encoded.keys.toSet(), {
      'configured',
      'baseUrl',
      'code',
      'keySet',
      'patienceSeconds',
      'kindActive',
    });
    expect(encoded.values.whereType<String>(), isNot(contains('sk-')));

    // И разбор — та же пара, что и запись: третьего читателя формы у
    // операции нет.
    final back = qrProviderViewFromWireJson(encoded);
    expect(back.keySet, isTrue);
    expect(back.patience, const Duration(seconds: 240));
    expect(back.code, 'sbp_bank');
  });
}
