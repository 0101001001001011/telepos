/// Пересменка на рабочем месте не отдаёт чужой черновик возврата — круг
/// правки 1 задачи 19, находка C1.
///
/// **Проба разбора, которая проходила целиком до этой правки:**
///
/// ```
/// старший (оба права)        → refund.startWithoutReceipt → OkFrame
/// младший (только op.refund) → refund.startWithoutReceipt → forbidden ← право работает
/// тот же младший             → refund.addProduct (10 шт)  → OkFrame
/// тот же младший             → refund.complete            → OkFrame   ← деньги ушли
/// ```
///
/// Черновик лежит под ключом рабочего места и только его: пользователя не
/// помнит, выход переживает. Значит право `op.refundWithoutReceipt` охраняло
/// **только первое нажатие**, а роль, которой возврат без чека закрыт
/// сознательно, наполняла чужой безчековый черновик каталожным товаром и
/// отдавала по нему деньги.
///
/// Здесь всё настоящее: настоящая база, настоящий `LocalRefundService` с
/// настоящими юзкейсами, настоящий `SessionRegistry`, настоящий сторож,
/// настоящий `TillWire` над `FakeQuicServer`. Вход идёт **по проводу**
/// (`auth.login`) — иначе проба не касалась бы того самого места, где
/// заведена правка.
library;

import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/constants/enums/user_role.dart';
import 'package:telepos/core/security/pin_credential.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/refund/local_refund_service.dart';
import 'package:telepos/data/usecases/refund/refund_product_service_impl.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/data/usecases/sale/can_sale_be_refunded_use_case_impl.dart';
import 'package:telepos/data/usecases/refund/refund_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/refund/refund_use_case_impl.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/wire/refund_codec.dart';
import 'package:telepos/domain/wire/refund_ops.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_frame.dart';
import 'package:telepos/domain/wire/wire_guard.dart';

import '../data/transport/fake_quic_server.dart';

const _posId = 1;
const _cashAccountId = 7;
const _seniorId = 1;
const _juniorId = 2;

class _NoopSetup implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {}
}

class _NoopBootstrap implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async =>
      AppInitStatus.success;
}

void main() {
  late AppDatabase db;
  late FakeQuicServer server;
  late SessionRegistry sessions;
  late PairingInvites invites;
  late TillOperations operations;
  late TillWire wire;
  var streamId = 4;

  Future<WireFrame> call(
    String op,
    Map<String, Object?> body, {
    String? token,
    int sessionId = 1,
  }) async {
    final before = server.sentFrames.length;
    server.emitStreamOpened(sessionId: sessionId, streamId: ++streamId);
    server.emitStreamData(
      sessionId: sessionId,
      streamId: streamId,
      message: jsonEncode({
        'op': op,
        'body': body,
        if (token != null) 'token': token,
      }),
    );
    server.emitStreamClosed(sessionId: sessionId, streamId: streamId);
    // Кадр СВОЕГО обмена: подписка refund.view остаётся живой и
    // дописывает свои кадры после, так что «последний» принадлежал бы уже не
    // этому вызову.
    for (var i = 0; i < 200 && server.sentFrames.length <= before; i++) {
      // Не микрозадача: настоящий вход считает PBKDF2 и отвечает через
      // настоящее время, а не через оборот цикла.
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return WireFrame.decode(server.sentFrames[before]);
  }

  /// Вкладка заводит своё рабочее место — тем же путём, что браузер.
  Future<int> registerTerminal({
    int sessionId = 1,
    String name = 'Планшет у входа',
  }) async {
    final frame = await call(TillOps.terminalRegister.name, {
      'name': name,
      'code': invites.mint().code,
    }, sessionId: sessionId);
    return ((frame as OkFrame).body['terminal']! as Map)['id']! as int;
  }

  /// Вход **по проводу**, той же операцией, что зовёт браузерная вкладка.
  Future<String> loginAs(int userId, {int sessionId = 1}) async {
    final frame = await call(TillOps.authLogin.name, {
      'pin': '1234',
      'userId': userId,
    }, sessionId: sessionId);
    expect(frame, isA<OkFrame>(), reason: 'вход $userId обязан состояться');
    final session = (frame as OkFrame).body['session']! as Map;
    return session['token']! as String;
  }

  CartCommandMeta meta(String key, {int? draftNo, int baseVersion = 0}) =>
      CartCommandMeta(key: key, baseVersion: baseVersion, receiptNo: draftNo);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = FakeQuicServer();
    sessions = SessionRegistry();
    invites = PairingInvites();
    streamId = 4;

    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(_posId),
            accountId: Value(_cashAccountId),
            // Круг правки 4: без имени кассы `self()` отказывается отдавать
            // строку вовсе, и проба блокера 1 мерила бы ненастроенную кассу.
            cashBoxName: Value('Касса-1'),
          ),
        );
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(_cashAccountId),
            type: 0,
            value: Value(Decimal.zero),
          ),
        );
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: const Value(_seniorId),
            name: const Value('Старший'),
            role: Value(UserRole.administrator.index),
            status: const Value('active'),
            passwordEnc: Value(PinCredential.create('1234')),
          ),
        );
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: const Value(_juniorId),
            name: const Value('Младший'),
            role: Value(UserRole.cashier.index),
            status: const Value('active'),
            passwordEnc: Value(PinCredential.create('1234')),
          ),
        );
    // Права берутся не из роли, а из таблицы прав пользователя
    // (`LocalAuthRepository._issue` → `userPermissionDao.getAllowedKeys`) —
    // значит и сеять их надо туда, иначе оба войдут без единого права и
    // проба выродится в «всем всё запрещено».
    for (final key in const [
      PermissionKeys.opRefund,
      PermissionKeys.opRefundWithoutReceipt,
    ]) {
      await db.userPermissionDao.setPermission(_seniorId, key, true);
    }
    await db.userPermissionDao.setPermission(
      _juniorId,
      PermissionKeys.opRefund,
      true,
    );

    await db
        .into(db.shifts)
        .insert(
          const ShiftsCompanion(
            userId: Value(_seniorId),
            openTime: Value(1000),
            isOpened: Value(true),
            isSynced: Value(false),
          ),
        );
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(100),
            barcode: 4870001234567,
            name: 'Молоко 3.2%',
            type: 0,
            measure: 0,
            quantity: Value(Decimal.parse('100')),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            ucode: const Value(100),
            barcode: 4870001234567,
            sellingPrice: Value(Decimal.parse('500')),
          ),
        );

    final logger = Talker();
    // `RefundUseCaseImpl` достаёт `RefundProductService` из `GetIt` сам —
    // сегодняшняя форма продукта, а не выбор пробы (тот же довод, что в
    // `local_refund_service_test.dart`).
    if (GetIt.I.isRegistered<RefundProductService>()) await GetIt.I.reset();
    GetIt.I.registerSingleton<RefundProductService>(
      RefundProductServiceImpl(db: db, logger: logger),
    );

    operations = TillOperations(
      db: db,
      bootstrap: _NoopBootstrap(),
      setup: _NoopSetup(),
      terminals: LocalTerminalRepository(db),
      deviceBindings: LocalDeviceBindingRepository(
        db,
        BuiltinDeviceProfileCatalog(),
      ),
      // **Настоящий вход, а не подделка — круг правки 5.** Подделка звала
      // `SessionRegistry.mint` напрямую, мимо `LocalAuthRepository._issue`,
      // где жило исключение круга 3 (`exclusiveTerminal`), — и денежные пробы
      // этого файла тот путь не проходили вовсе.
      //
      // Права **не** берутся из роли: `_issue` читает роль только у
      // `UserRole.owner`, всем остальным права даёт
      // `userPermissionDao.getAllowedKeys`. Роли ниже расставлены для
      // правдоподобия строки пользователя, а решает посев в таблицу прав
      // (см. `setPermission` в `setUp`).
      auth: LocalAuthRepository(
        db: db,
        sessions: sessions,
        throttle: LoginThrottle(),
      ),
      invites: invites,
      refund: LocalRefundService(
        db: db,
        logger: logger,
        initiation: RefundInitiationUseCaseImpl(db: db, logger: logger),
        refunds: RefundUseCaseImpl(
          db: db,
          logger: logger,
          fiscal: const RefusingFiscalService(),
        ),
        canBeRefunded: CanSaleBeRefundedUseCaseImpl(db: db, logger: logger),
        drawer: () async => true,
      ),
    );

    wire = TillWire(
      server,
      operations.askHandlers,
      watchHandlers: operations.watchHandlers,
      guard: wireGuardForTill(
        db: db,
        access: {for (final op in TillOps.all) op.name: op.access},
        sessions: sessions,
        // Круг правки 4: без этого довода сторож здесь собирался **не так,
        // как на настоящей кассе**, и денежные пробы не видели правку круга
        // 3 вовсе — снятие сверки не красило ни одной из них.
        boundTerminalId: operations.terminalForSessionKey,
      ),
    )..start();
  });

  tearDown(() async {
    await wire.stop();
    await server.dispose();
    await GetIt.I.reset();
    await db.close();
  });

  test('младший не наследует безчековый черновик старшего — ни наполнить, ни '
      'завершить, ни начать свой', () async {
    await registerTerminal();

    // Старший, у которого оба права, заводит возврат без чека и кладёт в
    // него товар.
    final seniorToken = await loginAs(_seniorId);
    final started = RefundOps.startWithoutReceipt.decode(
      ((await call(
                RefundOps.startWithoutReceipt.name,
                refundCommandMetaToWireJson(meta('s1')),
                token: seniorToken,
              ))
              as OkFrame)
          .body,
    );
    expect(started.started, isTrue);
    expect(started.byReceipt, isFalse);

    final filled = RefundOps.addProduct.decode(
      ((await call(
                RefundOps.addProduct.name,
                refundLineRequestToWireJson(
                  RefundLineRequest(
                    productId: 100,
                    quantity: Decimal.one,
                    meta: meta('s2', draftNo: started.draftNo),
                  ),
                ),
                token: seniorToken,
              ))
              as OkFrame)
          .body,
    );
    expect(filled.lines, hasLength(1));

    final stockBefore = await _stock(db);
    final tillBefore = await _balance(db);

    // Пересменка: за то же рабочее место садится младший — вход идёт по
    // проводу, той же операцией, что и у старшего.
    final juniorToken = await loginAs(_juniorId);

    // 1. Наполнить чужой черновик нечем — его больше нет.
    final add = await call(
      RefundOps.addProduct.name,
      refundLineRequestToWireJson(
        RefundLineRequest(
          productId: 100,
          quantity: Decimal.parse('10'),
          meta: meta('j1', draftNo: started.draftNo, baseVersion: 1),
        ),
      ),
      token: juniorToken,
    );
    expect(add, isA<ErrorFrame>());
    expect((add as ErrorFrame).code, 'refund_not_started');

    // 2. Завершить — тоже нечего.
    final complete = await call(
      RefundOps.complete.name,
      refundCommandMetaToWireJson(
        meta('j2', draftNo: started.draftNo, baseVersion: 1),
      ),
      token: juniorToken,
    );
    expect(complete, isA<ErrorFrame>());
    expect((complete as ErrorFrame).code, 'refund_not_started');

    // 3. Начать свой — упирается в право на первом же шаге, как и задумано.
    final start = await call(
      RefundOps.startWithoutReceipt.name,
      refundCommandMetaToWireJson(meta('j3')),
      token: juniorToken,
    );
    expect(start, isA<ErrorFrame>());
    expect((start as ErrorFrame).code, WireDenied.forbidden);
    expect(start.detail, contains(PermissionKeys.opRefundWithoutReceipt));

    // Деньги и товар не двинулись ни на копейку — правило нуля.
    expect(await _stock(db), stockBefore);
    expect(await _balance(db), tillBefore);

    // И черновика у места действительно нет — подписка младшего это видит.
    final view = await call(
      RefundOps.view.name,
      RefundOps.view.encode(null),
      token: juniorToken,
    );
    expect(RefundOps.view.decode((view as UpdateFrame).body).started, isFalse);
  });

  test('порядок входов уборку не обходит: младший вошёл первым — старший его '
      'сеанс гасит', () async {
    // Круг правки 2, C1. Уборка по входу — событие ОДНОКРАТНОЕ, а
    // требование покомандное, и обходилась она очерёдностью: личность
    // рабочего места живёт в общем для вкладок хранилище, токен — в своём
    // у каждой, значит две вкладки одного места делят номер штатным путём.
    //
    // Проба разбора, проходившая целиком до правки:
    //   Б: младший входит ПЕРВЫМ  → уборка отработала вхолостую
    //   А: старший входит, начинает возврат без чека → черновик на месте
    //   Б: младший addProduct → Ok, complete → Ok, касса 0 → −500
    //
    // Симптом тот же, право то же, но токен — **собственный** младшего, а
    // не «чужая незакрытая вкладка».
    await registerTerminal();

    // Вкладка Б: младший входит первым, своим PIN-ом.
    final juniorToken = await loginAs(_juniorId);

    // Вкладка А: старший входит на то же место — и заводит возврат.
    final seniorToken = await loginAs(_seniorId);
    final started = RefundOps.startWithoutReceipt.decode(
      ((await call(
                RefundOps.startWithoutReceipt.name,
                refundCommandMetaToWireJson(meta('s1')),
                token: seniorToken,
              ))
              as OkFrame)
          .body,
    );
    expect(started.started, isTrue);

    final stockBefore = await _stock(db);
    final tillBefore = await _balance(db);

    // Вкладка Б: команды младшего его же токеном. Сеанса больше нет —
    // выдача старшему погасила чужой сеанс того же места.
    for (final frame in [
      await call(
        RefundOps.addProduct.name,
        refundLineRequestToWireJson(
          RefundLineRequest(
            productId: 100,
            quantity: Decimal.parse('10'),
            meta: meta('j1', draftNo: started.draftNo),
          ),
        ),
        token: juniorToken,
      ),
      await call(
        RefundOps.complete.name,
        refundCommandMetaToWireJson(
          meta('j2', draftNo: started.draftNo, baseVersion: 1),
        ),
        token: juniorToken,
      ),
    ]) {
      expect(frame, isA<ErrorFrame>());
      expect((frame as ErrorFrame).code, WireDenied.unauthorized);
    }

    expect(await _stock(db), stockBefore);
    expect(await _balance(db), tillBefore);

    // Черновик старшего при этом цел — гашение чужого сеанса не отменяет
    // его работу.
    final view = RefundOps.view.decode(
      ((await call(
                RefundOps.view.name,
                RefundOps.view.encode(null),
                token: seniorToken,
              ))
              as UpdateFrame)
          .body,
    );
    expect(view.started, isTrue);
    expect(view.draftNo, started.draftNo);
  });

  test('две вкладки одного кассира друг друга не гасят', () async {
    // Обратная половина правила «за местом один человек»: F5 и второе окно
    // одного и того же человека законны, и различать их незачем. Без этой
    // пробы гашение могло бы выродиться в «выдача гасит всё подряд», и
    // кассир выбивал бы сам себя каждым входом.
    await registerTerminal();
    final first = await loginAs(_seniorId);
    final second = await loginAs(_seniorId);

    expect(first, isNot(second), reason: 'токены всё-таки разные');

    final frame = await call(
      RefundOps.startWithoutReceipt.name,
      refundCommandMetaToWireJson(meta('s1')),
      token: first,
    );
    expect(
      frame,
      isA<OkFrame>(),
      reason: 'первый токен обязан остаться живым — человек тот же',
    );
  });

  test('перепривязка места после входа не доводит до чужих денег', () async {
    // Круг правки 4: у C1 не было ни одной ДЕНЕЖНОЙ пробы — снятие сверки
    // красило только `session_terminal_binding_test`, где деньги не
    // считаются. Здесь тот же путь доведён до баланса кассы.
    //
    // Младший заводит своё место Б и входит на нём; старший — своё место А
    // и заводит там возврат без чека. Дальше младший переставляет свою
    // сессию на А штатным `resume` (операция открытая, сеанса не требует) и
    // пробует чужой черновик своим действующим токеном.
    final b = await registerTerminal(name: 'Место Б');
    final juniorToken = await loginAs(_juniorId);
    expect(b, isNotNull);

    final registered =
        (await call(TillOps.terminalRegister.name, {
              'name': 'Место А',
              'code': invites.mint().code,
            }, sessionId: 2))
            as OkFrame;
    final a = (registered.body['terminal']! as Map)['id']! as int;
    final secret = registered.body['secret']! as String;

    final seniorToken = await loginAs(_seniorId, sessionId: 2);
    final started = RefundOps.startWithoutReceipt.decode(
      ((await call(
                RefundOps.startWithoutReceipt.name,
                refundCommandMetaToWireJson(meta('s1')),
                token: seniorToken,
                sessionId: 2,
              ))
              as OkFrame)
          .body,
    );
    expect(started.started, isTrue);

    final stockBefore = await _stock(db);
    final tillBefore = await _balance(db);

    // Сессия младшего переставляет своё место на А.
    expect(
      await call(TillOps.terminalResume.name, {
        'terminalId': a,
        'secret': secret,
      }, token: juniorToken),
      isA<OkFrame>(),
    );

    // И тем же токеном идёт за чужими деньгами.
    for (final frame in [
      await call(
        RefundOps.addProduct.name,
        refundLineRequestToWireJson(
          RefundLineRequest(
            productId: 100,
            quantity: Decimal.parse('10'),
            meta: meta('j1', draftNo: started.draftNo),
          ),
        ),
        token: juniorToken,
      ),
      await call(
        RefundOps.complete.name,
        refundCommandMetaToWireJson(
          meta('j2', draftNo: started.draftNo, baseVersion: 1),
        ),
        token: juniorToken,
      ),
    ]) {
      expect(frame, isA<ErrorFrame>());
      expect((frame as ErrorFrame).code, 'terminal_changed');
    }

    expect(await _stock(db), stockBefore, reason: 'товар не сдвинулся');
    expect(await _balance(db), tillBefore, reason: 'касса не сдвинулась');
  });

  test('двое по проводу на строке самой кассы: черновик не делится, касса не '
      'двигается', () async {
    // **Блокер 1 круга правки 4, доведённый до денег.** Строку `isSelf`
    // раздавал любой сессии открытый `terminals.selfEnsure` — ни кода
    // привязки, ни секрета, — а круг 3 вдобавок снял для неё правило «за
    // местом один человек». Вдвоём на одной строке означало общий черновик
    // возврата, и кадрами провода это давало:
    //
    //   сессия 1: selfEnsure + вход младшего  → токен на строке кассы
    //   сессия 2: selfEnsure + вход старшего  → сеанс младшего ЖИВ
    //   сессия 2: refund.startWithoutReceipt  → черновик заведён
    //   сессия 1 (у младшего НЕТ opRefundWithoutReceipt):
    //             addProduct 10×500 → Ok, complete → Ok, amount 5000
    //   остаток 100 → 110, касса 0 → −5000
    //
    // Причина вырезана: `selfEnsure` места не привязывает, поэтому вход по
    // проводу на строку кассы невозможен, и оба исключения (круга 2 и
    // круга 3) сняты.
    final stockBefore = await _stock(db);
    final tillBefore = await _balance(db);

    // **Две настоящие QUIC-сессии, оба входа, чужой черновик и деньги.**
    // Прежняя редакция этой пробы двоих не сажала: она останавливалась на
    // первом отказе входа, и неподвижная касса в ней была свойством тела
    // запроса, а не охраны. Здесь ход идёт до конца независимо от того, где
    // именно он упрётся, — а утверждается **исход**: чужой черновик не
    // завершён и касса не двинулась. Так проба отличает «дыра закрыта» от
    // «дыра недостижима этим телом».
    final selfOne =
        (await call(TillOps.terminalSelfEnsure.name, const {})) as OkFrame;
    expect(
      selfOne.body['terminal'],
      isNotNull,
      reason: 'сама операция отвечает как прежде — проба не вырождена',
    );
    await call(TillOps.terminalSelfEnsure.name, const {}, sessionId: 2);

    final juniorLogin = await call(TillOps.authLogin.name, {
      'pin': '1234',
      'userId': _juniorId,
    });
    final seniorLogin = await call(TillOps.authLogin.name, {
      'pin': '1234',
      'userId': _seniorId,
    }, sessionId: 2);

    final juniorToken = _tokenOrNull(juniorLogin);
    final seniorToken = _tokenOrNull(seniorLogin);

    // Старший заводит безчековый черновик — если вход на строку кассы вообще
    // состоялся.
    int? draftNo;
    if (seniorToken != null) {
      final started = await call(
        RefundOps.startWithoutReceipt.name,
        refundCommandMetaToWireJson(meta('s1')),
        token: seniorToken,
        sessionId: 2,
      );
      if (started is OkFrame) {
        draftNo = RefundOps.startWithoutReceipt.decode(started.body).draftNo;
      }
    }

    // Младший — у которого `op.refundWithoutReceipt` НЕТ — идёт за чужими
    // деньгами своим действующим токеном.
    WireFrame? completed;
    if (juniorToken != null) {
      await call(
        RefundOps.addProduct.name,
        refundLineRequestToWireJson(
          RefundLineRequest(
            productId: 100,
            quantity: Decimal.parse('10'),
            meta: meta('j1', draftNo: draftNo),
          ),
        ),
        token: juniorToken,
      );
      completed = await call(
        RefundOps.complete.name,
        refundCommandMetaToWireJson(
          meta('j2', draftNo: draftNo, baseVersion: 1),
        ),
        token: juniorToken,
      );
    }

    // Деньги — первым утверждением: `expect` бросает на первом же
    // расхождении, и если бы первым стоял род кадра, разбирающий увидел бы
    // «OkFrame вместо не-OkFrame» и не увидел бы, на сколько увели кассу.
    expect(await _balance(db), tillBefore, reason: 'касса не сдвинулась');
    expect(await _stock(db), stockBefore, reason: 'товар не сдвинулся');
    expect(
      completed,
      isNot(isA<OkFrame>()),
      reason:
          'младший завершил чужой безчековый возврат — право '
          'op.refundWithoutReceipt охраняет только первое нажатие',
    );
  });

  test(
    'законный путь цел: тот же кассир доводит свой возврат без чека до денег',
    () async {
      // Обратная половина. Без неё первая проба проходила бы и у кассы,
      // которая ломает возврат всем и всегда.
      await registerTerminal();
      final seniorToken = await loginAs(_seniorId);

      final started = RefundOps.startWithoutReceipt.decode(
        ((await call(
                  RefundOps.startWithoutReceipt.name,
                  refundCommandMetaToWireJson(meta('s1')),
                  token: seniorToken,
                ))
                as OkFrame)
            .body,
      );
      await call(
        RefundOps.addProduct.name,
        refundLineRequestToWireJson(
          RefundLineRequest(
            productId: 100,
            quantity: Decimal.one,
            meta: meta('s2', draftNo: started.draftNo),
          ),
        ),
        token: seniorToken,
      );

      final stockBefore = await _stock(db);
      final tillBefore = await _balance(db);

      final done = await call(
        RefundOps.complete.name,
        refundCommandMetaToWireJson(
          meta('s3', draftNo: started.draftNo, baseVersion: 1),
        ),
        token: seniorToken,
      );

      expect(done, isA<OkFrame>());
      final outcome = RefundOps.complete.decode((done as OkFrame).body);
      expect(outcome.amount, Decimal.parse('500'));
      // Проверяется не «строка записана», а что товар вернулся на остаток, а
      // деньги ушли из кассы ровно на сумму возврата.
      expect(await _stock(db), stockBefore + Decimal.one);
      expect(await _balance(db), tillBefore - Decimal.parse('500'));
    },
  );

  test(
    'неверный PIN чужую работу не сносит — уборка идёт по состоявшемуся входу',
    () async {
      // Иначе любой, кто дотянулся до кассы, сносил бы чужие черновики
      // неверным PIN-ом, не входя вовсе.
      await registerTerminal();
      final seniorToken = await loginAs(_seniorId);
      final started = RefundOps.startWithoutReceipt.decode(
        ((await call(
                  RefundOps.startWithoutReceipt.name,
                  refundCommandMetaToWireJson(meta('s1')),
                  token: seniorToken,
                ))
                as OkFrame)
            .body,
      );

      // Пользователя 99 нет — настоящий `LocalAuthRepository` отвечает
      // отказом ровно как на неверный PIN.
      final rejected = await call(TillOps.authLogin.name, {
        'pin': '0000',
        'userId': 99,
      });
      expect(rejected, isA<OkFrame>(), reason: 'отказ входа едет значением');

      final view = RefundOps.view.decode(
        ((await call(
                  RefundOps.view.name,
                  RefundOps.view.encode(null),
                  token: seniorToken,
                ))
                as UpdateFrame)
            .body,
      );
      expect(view.started, isTrue);
      expect(view.draftNo, started.draftNo);
      expect(view.lines, isEmpty);
    },
  );
}

/// Токен из ответа входа — или `null`, если вход не состоялся.
///
/// Не бросает: двухсессионная проба выше обязана дойти до утверждения о
/// деньгах независимо от того, на каком шаге ход упрётся, — иначе она
/// доказывала бы «отказали раньше», а не «денег не тронули».
String? _tokenOrNull(WireFrame frame) {
  if (frame is! OkFrame) return null;
  final session = frame.body['session'];
  return session is Map ? session['token'] as String? : null;
}

Future<Decimal> _stock(AppDatabase db) async =>
    (await db.productInfoDao.findByUcode(100))!.quantity ?? Decimal.zero;

Future<Decimal> _balance(AppDatabase db) async =>
    (await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(_cashAccountId))).getSingle()).value ??
    Decimal.zero;
