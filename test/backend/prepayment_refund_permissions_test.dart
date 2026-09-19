/// Выдача аванса с планшета достижима **тем путём, каким пойдёт кассир** —
/// решение заказчика 2026-09-18.
///
/// # Почему проба идёт по проводу, а не зовёт обработчик
///
/// Соседний `prepayment_refund_op_test.dart` зовёт обработчик напрямую и
/// доказывает, что выдача верна. `pay_ops_access_test.dart` доказывает, что
/// право **объявлено** в каталоге. Ни одна из двух не отвечает на вопрос «а
/// получит ли кассир без права отказ, если сядет за браузер» — между ними
/// лежит ровно то место, где в этом дереве уже один раз пропало целое
/// требование: код привязки терминала был написан, охранял корень и не
/// звался ниоткуда, и 3518 зелёных тестов не заметили, что войти нельзя.
///
/// Поэтому здесь единственный путь: кадр в `TillWire` через настоящий
/// `WireGuard`, собранный тем же `wireGuardForTill` и тем же словарём
/// `{for (final op in TillOps.all) op.name: op.access}`, каким его собирает
/// `ApiServer` (`TillOps.all` включает `...PayOps.all`). Обработчик
/// настоящий, юзкейс настоящий, база настоящая в памяти. Ни один обработчик
/// здесь не зовётся напрямую ни разу.
///
/// # Деньги меряются третьим знаком
///
/// 2000.005 и 1200.005 в двойной точности не представимы. Проба, считающая
/// круглыми тысячами, зеленела бы и на `double`.
///
/// # Чего эта проба НЕ доказывает
///
/// - **Что экран вкладки эту операцию зовёт.** Это доказывает
///   `test/web/prepayment_refund_reachable_test.dart` — звенья цепочки от
///   точки входа до маршрута.
/// - **Что в ящике есть наличные.** Касса знает сальдо счёта выдачи, а не
///   содержимое ящика.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/data/usecases/payment/customer_payment_use_case_impl.dart';
import 'package:telepos/domain/auth/auth_session.dart';
import 'package:telepos/domain/auth/session_lookup.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/payment/prepayment_intake.dart';
import 'package:telepos/domain/shift/shift_status.dart';
import 'package:telepos/domain/wire/pay_ops.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_frame.dart';

import 'support/bare_till_deps.dart';
import 'support/noop_auth.dart';

import '../data/transport/fake_quic_server.dart';

const _session = 1;
const _tillAccountId = 11;
const _agentAccountId = 14;
const _customerId = 5;

/// Два сеанса — разными строками, а не одним токеном с подменой прав: сторож
/// ищет сеанс **по токену**, и подмена содержимого под одним ключом
/// проверяла бы карту, а не поиск.
const _tokenBare = 'tok-bare';
const _tokenFull = 'tok-full';

void main() {
  late AppDatabase db;
  late TillOperations ops;
  late FakeQuicServer server;
  late TillWire wire;

  Decimal d(String v) => Decimal.parse(v);

  var streamId = 0;

  AuthSession sessionWith(String token, Set<String> permissions) => AuthSession(
    token: token,
    userId: 4,
    name: 'Айгуль',
    role: 'cashier',
    permissions: permissions,
    operatingMode: 0,
    pointMode: 'cashier',
    shift: ShiftStatus.open,
    issuedAt: DateTime(2026, 9, 18),
    expiresAt: DateTime(2026, 9, 19),
    terminalId: 7,
  );

  /// Один обмен по проводу целиком: открыть поток, положить кадр, закрыть
  /// свою половину — ровно так, как это делает браузер.
  ///
  /// Ждёт **появления кадра**, а не фиксированную паузу: обработчик ходит в
  /// настоящую базу, и пауза, подобранная под сегодняшнюю скорость, стала бы
  /// мерцанием набора под нагрузкой.
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

  String? codeOf(WireFrame frame) => frame is ErrorFrame ? frame.code : null;

  Map<String, Object?> bodyOf(WireFrame frame) {
    expect(frame, isA<OkFrame>(), reason: 'ожидался ответ, пришло $frame');
    return (frame as OkFrame).body;
  }

  Future<Decimal> balanceOf(int accountId) async =>
      (await db.accountDao.findById(accountId))?.value ?? Decimal.zero;

  Map<String, Object?> refundBody(String key) => {
    'key': key,
    'customerId': _customerId,
    'amount': '1200.005',
    'tenderKindId': SystemPaymentKindIds.cash,
  };

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());

    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            accountId: Value(_tillAccountId),
            cashBoxName: Value('Касса-тест'),
          ),
        );
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(_tillAccountId),
            type: AccountType.pos,
            name: const Value('Касса'),
            value: Value(Decimal.parse('10000')),
            visibleToPos: const Value(true),
          ),
        );
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(_agentAccountId),
            type: AccountType.agentMain,
            name: const Value('Расчёты с Айгуль'),
            value: Value(Decimal.parse('2000.005')),
            visibleToPos: const Value(false),
          ),
        );
    await db
        .into(db.agents)
        .insert(
          const AgentsCompanion(
            localId: Value(_customerId),
            name: Value('Айгуль'),
            phone: Value(77015550000),
            mainAccountId: Value(_agentAccountId),
          ),
        );
    await db.paymentKindDao.put(
      SystemPaymentKinds.byId(SystemPaymentKindIds.cash),
    );

    ops = TillOperations(
      db: db,
      bootstrap: BareBootstrap(),
      setup: BareSetup(),
      terminals: BareTerminals(),
      deviceBindings: BareBindings(),
      auth: NoopAuth(),
      invites: PairingInvites(),
      // Узел без фискального оператора: проба про право и про деньги, а не
      // про разговор с КГД. Отказ оператора денег не отменяет, и его
      // отсутствие — тем более.
      prepaymentRefund: CustomerPaymentUseCaseImpl(
        db: db,
        logger: Talker(),
        fiscal: const RefusingFiscalService(),
      ),
    );

    server = FakeQuicServer();
    wire = TillWire(
      server,
      ops.askHandlers,
      watchHandlers: ops.watchHandlers,
      runHandlers: ops.runHandlers,
      // Тот же сторож и тот же словарь доступа, что у настоящей кассы:
      // `ApiServer.access` — это буквально то же выражение, а `TillOps.all`
      // включает `...PayOps.all`.
      guard: wireGuardForTill(
        db: db,
        access: {for (final op in TillOps.all) op.name: op.access},
        sessions: _Sessions({
          // Кассир по умолчанию: продажа открыта, ни одного `op.*`.
          _tokenBare: sessionWith(_tokenBare, {PermissionKeys.navSale}),
          // Старший: продажа и право двигать счёт расчётов.
          _tokenFull: sessionWith(_tokenFull, {
            PermissionKeys.navSale,
            PermissionKeys.opCreditRepay,
          }),
        }),
      ),
      onSessionClosed: ops.forgetSession,
    )..start();

    streamId = 0;
  });

  tearDown(() async {
    await wire.stop();
    await server.dispose();
    await db.close();
  });

  test('кассир без op.creditRepay получает forbidden по проводу', () async {
    final refused = await askWire(
      PayOps.prepaymentRefund.name,
      refundBody('r-1'),
      token: _tokenBare,
    );

    expect(codeOf(refused), 'forbidden');
  });

  test('отказал сторож, а не юзкейс: деньги не тронуты вовсе', () async {
    // Отличает «право проверено ДО обработчика» от «обработчик сходил в базу
    // и передумал». Обе величины, а не одна: сломанная выдача могла бы
    // списать у покупателя и не тронуть ящик.
    await askWire(
      PayOps.prepaymentRefund.name,
      refundBody('r-2'),
      token: _tokenBare,
    );

    expect(await balanceOf(_agentAccountId), d('2000.005'));
    expect(await balanceOf(_tillAccountId), d('10000'));
    expect(await db.select(db.cashOperations).get(), isEmpty);
  });

  test('без сеанса вовсе — unauthorized, а не forbidden', () async {
    // Разные беды разными словами: «ты не вошёл» и «тебе не положено»
    // ведут кассира в разные места.
    final refused = await askWire(
      PayOps.prepaymentRefund.name,
      refundBody('r-3'),
    );

    expect(codeOf(refused), 'unauthorized');
  });

  test('с правом выдача доходит до денег — и они уходят из ящика', () async {
    // Страховка от вырождения: запрет, не пропускающий никого, выглядит так
    // же зелено, как запрет, не останавливающий никого.
    final answer = await askWire(
      PayOps.prepaymentRefund.name,
      refundBody('r-4'),
      token: _tokenFull,
    );

    expect(bodyOf(answer)['balance'], '800');
    expect(await balanceOf(_agentAccountId), d('800'));
    expect(await balanceOf(_tillAccountId), d('8799.995'));
    expect(await db.select(db.cashOperations).get(), hasLength(1));
  });

  test('оборванный ответ и повтор: деньги уходят один раз', () async {
    // Наблюдённая беда 2026-09-18 в её настоящем виде: вкладка послала кадр,
    // ответ до неё не доехал, кассир нажал снова. Оба кадра идут **по
    // проводу**, с тем же ключом, какой послал бы неправленый экран.
    final first = bodyOf(
      await askWire(
        PayOps.prepaymentRefund.name,
        refundBody('r-оборвался'),
        token: _tokenFull,
      ),
    );
    final second = bodyOf(
      await askWire(
        PayOps.prepaymentRefund.name,
        refundBody('r-оборвался'),
        token: _tokenFull,
      ),
    );

    expect(second['operationId'], first['operationId']);
    expect(second['balance'], first['balance']);
    expect(
      await balanceOf(_tillAccountId),
      d('8799.995'),
      reason: 'повтор не имеет права выпустить из ящика вторые 1200.005',
    );
    expect(await db.select(db.cashOperations).get(), hasLength(1));
  });

  test('кадр без ключа отказан названной причиной, деньги не тронуты', () async {
    final refused = await askWire(PayOps.prepaymentRefund.name, {
      ...refundBody('r-5'),
      'key': '',
    }, token: _tokenFull);

    expect(codeOf(refused), prepaymentRefundKeyMissingCode);
    expect(await balanceOf(_agentAccountId), d('2000.005'));
    expect(await balanceOf(_tillAccountId), d('10000'));
  });
}

class _Sessions implements SessionLookup {
  _Sessions(this._byToken);
  final Map<String, AuthSession> _byToken;
  @override
  AuthSession? sessionFor(String token) => _byToken[token];
}
