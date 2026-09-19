/// Браузерная половина приёма аванса — требование заказчика 2026-09-18.
///
/// # Что здесь соединено торцами
///
/// Обе половины провода тем же стендом, что и `wt_payment_service_test`:
/// настоящая база drift, настоящий `CustomerPaymentUseCaseImpl`, настоящие
/// `TillOperations`, `TillWire` со **сторожем прав** — и настоящий
/// `WtPrepaymentIntakeService` поверх настоящего `WtDispatcher`. Подставлен
/// один QUIC (нативной библиотеки под `flutter test` нет).
///
/// Проверяется не «поля переложились», а три вещи, которых ни кассовый
/// набор, ни проба обработчика не видят **по построению**:
///
/// 1. деньги, принятые из браузера, доходят до **обоих** счетов кассы;
/// 2. право `op.creditRepay` отказывает **браузеру**, а не только сторожу
///    в отдельно взятом тесте;
/// 3. отказ кассы доезжает до вкладки `WireRefusal`'ом с тем же кодом —
///    то есть договор один на обе реализации контракта.
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
import 'package:telepos/data/database/app_database.dart' hide Terminal;
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/data/usecases/payment/customer_payment_use_case_impl.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/payment/prepayment_intake.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_payment_service.dart';

import '../backend/support/bare_till_deps.dart';
import 'support/fake_dispatcher.dart';
import 'support/loopback.dart';

const _tillAccountId = 11;
const _agentAccountId = 14;
const _customerId = 5;

void main() {
  late AppDatabase db;
  late Loopback loop;
  late TillWire wire;

  Decimal d(String v) => Decimal.parse(v);

  Future<Decimal> balanceOf(int accountId) async =>
      (await db.accountDao.findById(accountId))?.value ?? Decimal.zero;

  /// Поднять обе половины провода с сеансом, несущим [permissions].
  Future<WtPrepaymentIntakeService> boot(Set<String> permissions) async {
    final sessions = SessionRegistry();
    final invites = PairingInvites();
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
      // Тот же юзкейс, что стоит под кассовым диалогом. Фискального узла в
      // этой пробе нет, и это сказано типом, а не забыто: проба про
      // достижимость приёма, а не про разговор с оператором.
      prepaymentIntake: CustomerPaymentUseCaseImpl(
        db: db,
        logger: Talker(),
        fiscal: const RefusingFiscalService(),
      ),
    );
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

    // Рабочее место сессия называет сама, тем же путём, каким это делает
    // настоящая вкладка.
    await browser.ask<TerminalRegisterRequest, TerminalEnrollment>(
      TillOps.terminalRegister,
      (name: 'Вкладка', code: invites.mint().code),
    );
    return WtPrepaymentIntakeService(browser);
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    loop = Loopback();
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            accountId: Value(_tillAccountId),
            cashBoxName: Value('Касса-1'),
          ),
        );
    await db
        .into(db.users)
        .insert(const UsersCompanion(id: Value(4), name: Value('Айгуль')));
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(_tillAccountId),
            type: AccountType.pos,
            name: const Value('Касса'),
            value: Value(Decimal.zero),
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
            value: Value(Decimal.zero),
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
  });

  tearDown(() async {
    await wire.stop();
    await loop.dispose();
    await db.close();
  });

  const allowed = {
    PermissionKeys.navSale,
    PermissionKeys.opCreditRepay,
  };

  test('взнос из браузера доходит до обоих счетов кассы', () async {
    final intake = await boot(allowed);

    final outcome = await intake.acceptPrepayment(
      PrepaymentIntakeRequest(
        key: 'k-oba-scheta',
        customerId: _customerId,
        amount: d('1000'),
        tenderKindId: SystemPaymentKindIds.cash,
      ),
    );

    expect(outcome.balance, d('1000'));
    expect(outcome.operationId, greaterThan(0));

    // Сальдо покупателя — и счёт кассы. Вторая величина существенна: до
    // 2026-09-18 её двигал контроллер кассового экрана, которого у
    // браузера нет.
    expect(await balanceOf(_agentAccountId), d('1000'));
    expect(await balanceOf(_tillAccountId), d('1000'));
  });

  test('кассир без op.creditRepay не проходит — и денег не двигает', () async {
    final intake = await boot(const {PermissionKeys.navSale});

    await expectLater(
      intake.acceptPrepayment(
        PrepaymentIntakeRequest(
          key: 'k-bez-prava',
          customerId: _customerId,
          amount: d('1000'),
          tenderKindId: SystemPaymentKindIds.cash,
        ),
      ),
      throwsA(isA<WireRefusal>().having((e) => e.code, 'code', 'forbidden')),
    );

    expect(await balanceOf(_agentAccountId), Decimal.zero);
    expect(await balanceOf(_tillAccountId), Decimal.zero);
  });

  test('отказ кассы доезжает WireRefusal-ом с тем же кодом', () async {
    final intake = await boot(allowed);

    await expectLater(
      intake.acceptPrepayment(
        PrepaymentIntakeRequest(
          key: 'k-chuzhoj',
          customerId: 999,
          amount: d('1000'),
          tenderKindId: SystemPaymentKindIds.cash,
        ),
      ),
      throwsA(
        isA<WireRefusal>().having(
          (e) => e.code,
          'code',
          'loyalty_customer_unknown',
        ),
      ),
    );
  });

  test('ноль отказан кассой, а не вкладкой', () async {
    // Существенно именно то, что отказ **приехал**: проверка суммы на
    // экране избавляет от круга, но запрет держит касса.
    final intake = await boot(allowed);

    await expectLater(
      intake.acceptPrepayment(
        PrepaymentIntakeRequest(
          key: 'k-nol',
          customerId: _customerId,
          amount: Decimal.zero,
          tenderKindId: SystemPaymentKindIds.cash,
        ),
      ),
      throwsA(
        isA<WireRefusal>().having(
          (e) => e.code,
          'code',
          prepaymentAmountInvalidCode,
        ),
      ),
    );
    expect(await balanceOf(_tillAccountId), Decimal.zero);
  });

  /// Ключ повтора — дефект живой приёмки 2026-09-18.
  ///
  /// # Почему пробы здесь, а не в кассовом наборе
  ///
  /// Потому что беда живёт **в проводе**, и только здесь обе его половины
  /// соединены торцами. Кассовый набор зовёт юзкейс напрямую и повтора не
  /// видит по построению: у кассира перед ящиком нет провода, способного
  /// проглотить ответ.
  ///
  /// Наблюдённый путь: провод рвётся
  /// (`stream_failed: WebTransportError: Connection lost`) **после** того,
  /// как касса приняла деньги; ответ до вкладки не доезжает, экран
  /// показывает отказ, и кассир жмёт «Принять» второй раз. Второе нажатие —
  /// это тот же самый вызов с тем же ключом, и меряется ровно он.
  group('повтор заявки', () {
    Future<int> cashOperationCount() async =>
        (await db.select(db.cashOperations).get()).length;

    test('тот же ключ денег второй раз не принимает', () async {
      final intake = await boot(allowed);

      Future<PrepaymentIntakeOutcome> submit() => intake.acceptPrepayment(
        PrepaymentIntakeRequest(
          key: 'k-повтор',
          customerId: _customerId,
          amount: d('1000'),
          tenderKindId: SystemPaymentKindIds.cash,
        ),
      );

      final first = await submit();
      final second = await submit();

      // Сальдо покупателя — **тысяча, а не две**. Это и есть та величина,
      // ради которой всё: до правки она удваивалась, ящик сходился с
      // первой суммой, и расхождение жило до сверки сальдо.
      expect(await balanceOf(_agentAccountId), d('1000'));
      // Счёт кассы тоже: удвоенный приём двигал бы и его.
      expect(await balanceOf(_tillAccountId), d('1000'));
      // Второй строки журнала нет вовсе. Проверка сальдо этого не ловит:
      // две проводки по 500 дали бы ту же тысячу.
      expect(await cashOperationCount(), 1);

      // Кассиру повтор обязан выглядеть успехом — он им и является,
      // просто уже случившимся. Исход тот же до поля.
      expect(second.operationId, first.operationId);
      expect(second.balance, first.balance);
      expect(second.fiscalSign, first.fiscalSign);
      expect(second.fiscalError, first.fiscalError);
    });

    test('другой ключ принимает деньги честно', () async {
      // Обратный полюс, без которого первая проба зеленела бы и у кассы,
      // разучившейся принимать аванс вовсе.
      final intake = await boot(allowed);

      for (final key in const ['k-первый', 'k-второй']) {
        await intake.acceptPrepayment(
          PrepaymentIntakeRequest(
            key: key,
            customerId: _customerId,
            amount: d('1000'),
            tenderKindId: SystemPaymentKindIds.cash,
          ),
        );
      }

      expect(await balanceOf(_agentAccountId), d('2000'));
      expect(await balanceOf(_tillAccountId), d('2000'));
      expect(await cashOperationCount(), 2);
    });

    test('повтор не зависит от суммы в кадре — ключ главнее', () async {
      // Кадр, собранный мимо экрана: тот же ключ, другая сумма. Касса
      // обязана ответить **прежним исходом**, а не принять разницу: ключ
      // говорит «это та же заявка», и спорить с ним содержимым кадра
      // значило бы завести второй источник правды о повторе.
      final intake = await boot(allowed);

      final first = await intake.acceptPrepayment(
        PrepaymentIntakeRequest(
          key: 'k-та-же',
          customerId: _customerId,
          amount: d('1000'),
          tenderKindId: SystemPaymentKindIds.cash,
        ),
      );
      final second = await intake.acceptPrepayment(
        PrepaymentIntakeRequest(
          key: 'k-та-же',
          customerId: _customerId,
          amount: d('7777'),
          tenderKindId: SystemPaymentKindIds.cash,
        ),
      );

      expect(second.balance, first.balance);
      expect(await balanceOf(_agentAccountId), d('1000'));
      expect(await cashOperationCount(), 1);
    });

    test('память переживает перезапуск кассы', () async {
      // Ключ, живущий в памяти процесса, не защищает ровно в том случае,
      // ради которого заведён: обрыв провода и перезапуск кассы ходят
      // парой. Здесь провод поднимается заново поверх **той же базы**.
      final first = await (await boot(allowed)).acceptPrepayment(
        PrepaymentIntakeRequest(
          key: 'k-переживший',
          customerId: _customerId,
          amount: d('1000'),
          tenderKindId: SystemPaymentKindIds.cash,
        ),
      );

      await wire.stop();
      final second = await (await boot(allowed)).acceptPrepayment(
        PrepaymentIntakeRequest(
          key: 'k-переживший',
          customerId: _customerId,
          amount: d('1000'),
          tenderKindId: SystemPaymentKindIds.cash,
        ),
      );

      expect(second.operationId, first.operationId);
      expect(await balanceOf(_agentAccountId), d('1000'));
      expect(await cashOperationCount(), 1);
    });

    test('кадр без ключа отказан ДО первой записи', () async {
      // Вкладка, собравшая кадр мимо экрана. Принять его значило бы
      // вернуть дефект целиком: повтор такого кадра опознать нечем.
      final intake = await boot(allowed);

      await expectLater(
        intake.acceptPrepayment(
          PrepaymentIntakeRequest(
            key: '',
            customerId: _customerId,
            amount: d('1000'),
            tenderKindId: SystemPaymentKindIds.cash,
          ),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (e) => e.code,
            'code',
            prepaymentIntakeKeyMissingCode,
          ),
        ),
      );

      // «До первой записи» — это про счета и журнал, а не про слово
      // «отказ» в ответе.
      expect(await balanceOf(_agentAccountId), Decimal.zero);
      expect(await balanceOf(_tillAccountId), Decimal.zero);
      expect(await cashOperationCount(), 0);
    });

    test('одновременные повторы: деньги списываются один раз', () async {
      // Три вызова стартуют до того, как первый успел что-либо записать.
      //
      // **Чем именно они разводятся, замерено, а не предположено:** drift
      // ставит транзакции одной связи в очередь, поэтому здесь срабатывает
      // первый заслон — чтение памяти *внутри* транзакции, которое второму
      // и третьему вызову достаётся уже заполненным. Второй заслон
      // (уникальный ключ таблицы) этой пробой не достаётся вовсе, и он
      // меряется структурно — `migration_v49_prepayment_intakes_test.dart`,
      // «ключ не даёт запомнить одну заявку дважды».
      //
      // Проба всё равно нужна: она доказывает, что чтение стоит именно
      // внутри транзакции. Вынесенное наружу, оно пропустило бы все три.
      final intake = await boot(allowed);

      Future<PrepaymentIntakeOutcome> submit() => intake.acceptPrepayment(
        PrepaymentIntakeRequest(
          key: 'k-одновременно',
          customerId: _customerId,
          amount: d('1000'),
          tenderKindId: SystemPaymentKindIds.cash,
        ),
      );

      final outcomes = await Future.wait([submit(), submit(), submit()]);

      expect(await balanceOf(_agentAccountId), d('1000'));
      expect(await balanceOf(_tillAccountId), d('1000'));
      expect(await cashOperationCount(), 1);
      expect(
        outcomes.map((o) => o.operationId).toSet(),
        hasLength(1),
        reason: 'все три ответа обязаны называть одну и ту же проводку',
      );
    });
  });
}
