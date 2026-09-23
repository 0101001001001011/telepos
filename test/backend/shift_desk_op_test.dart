/// Смена с браузерного терминала — решение заказчика 2026-09-18.
///
/// # Что здесь соединено торцами
///
/// Обе половины провода на настоящем графе: база drift, настоящая
/// `LocalShiftDesk` над настоящей `ShiftServiceImpl`, настоящие
/// `TillOperations`, `TillWire` со **сторожем прав** — и настоящий
/// `WtShiftDesk` поверх настоящего `WtDispatcher`. Подставлен один QUIC
/// (нативной библиотеки под `flutter test` нет) и часы правила возраста.
///
/// # Три утверждения, каждое — про измеренный дефект
///
/// 1. **смену можно закрыть с планшета, и деньги ложатся туда, куда
///    ложились с кассы.** Замерено живьём в тот же день: смена старше суток
///    запирает продажу окном «закройте смену на кассе», а с планшета закрыть
///    её было нечем.
/// 2. **вкладка задаёт одно число — пересчитанные деньги, и `null` значит
///    «не считали», а не ноль.** Ноль в ящике — законный результат
///    пересчёта, и подменить им «не считали» значит записать недостачу на
///    всю выручку смены. Проверяется обеими сторонами: с числом расхождение
///    пишется, без числа — не пишется вовсе.
/// 3. **значок состояния смены честен.** Дом терминала показывал «Смена
///    открыта» зелёным значком и при просроченной смене: состояние приезжало
///    один раз в `AuthSession` при входе. Здесь проверяется, что подписка
///    говорит `overAge` тем же правилом, каким касса запирает продажу, —
///    и что единицы **секунды**, а не миллисекунды.
@Tags(['architecture'])
library;

import 'package:decimal/decimal.dart';
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
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/shift/shift_age_rule.dart';
import 'package:telepos/domain/cash/cash_operation_kind.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/shift/shift_desk.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_shift_desk.dart';

import '../web/support/fake_dispatcher.dart';
import '../web/support/loopback.dart';
import 'support/bare_till_deps.dart';

void main() {
  late AppDatabase db;
  late Loopback loop;
  late TillWire wire;

  /// Поднять обе половины провода с сеансом, несущим [permissions].
  Future<WtShiftDesk> boot(Set<String> permissions, {int userId = 4}) async {
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
    );
    final session = sessions.mint(
      userId: userId,
      name: 'Кассир',
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
    await browser.ask<TerminalRegisterRequest, TerminalEnrollment>(
      TillOps.terminalRegister,
      (name: 'Планшет', code: invites.mint().code),
    );
    return WtShiftDesk(browser);
  }

  /// Секунды эпохи — **та же единица, в которой живёт `Shifts.openTime`**.
  int secondsAgo(Duration ago) =>
      (DateTime.now().subtract(ago).millisecondsSinceEpoch) ~/ 1000;

  /// Открыть смену прямо в базе, как это сделала бы касса.
  Future<int> openShiftAt(int openTimeSeconds, {Decimal? openingCash}) async {
    return db
        .into(db.shifts)
        .insert(
          ShiftsCompanion.insert(
            userId: 4,
            openTime: openTimeSeconds,
            isOpened: true,
            isSynced: false,
            openingCash: Value(openingCash ?? Decimal.zero),
          ),
        );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    loop = Loopback();
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
        .insert(const UsersCompanion(id: Value(4), name: Value('Кассир')));
    // Счёт кассы с известным остатком: «системный итог» читается именно с
    // него, и без строки проба мерила бы ноль против ноля.
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(11),
            type: 0,
            name: const Value('Касса'),
            value: Value(Decimal.parse('7000.00')),
          ),
        );
  });

  tearDown(() async {
    await wire.stop();
    await loop.dispose();
    await db.close();
  });

  const cashier = {PermissionKeys.navShift};

  test('смена закрывается с планшета: деньги, время и расхождение', () async {
    final openedAt = secondsAgo(const Duration(hours: 3));
    final shiftId = await openShiftAt(
      openedAt,
      openingCash: Decimal.parse('1000.00'),
    );
    final desk = await boot(cashier);

    final before = await desk.watch().first;
    expect(before.open, isTrue);
    // ── СЕКУНДЫ, НЕ МИЛЛИСЕКУНДЫ ────────────────────────────────────────
    //
    // Проверяется не «поле непусто», а порядок величины: при множителе в
    // тысячу это число было бы в тысячу раз больше, и просроченная смена
    // выглядела бы свежей. Ошибка в единицах уже стоила получаса разбора.
    expect(before.openedAtSeconds, openedAt);
    expect(
      before.openedAtSeconds!,
      lessThan(DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1),
      reason: 'время открытия приехало не в секундах',
    );
    expect(before.overAge, isFalse, reason: 'смене три часа');
    expect(before.systemTotal, Decimal.parse('7000.00'));
    expect(before.openingCash, Decimal.parse('1000.00'));
    // Ожидается: начало 1000 + наличной выручки нет − возвратов нет −
    // изъятий нет.
    expect(before.expectedCash, Decimal.parse('1000.00'));

    // Кассир пересчитал ящик: в нём 1200.
    await desk.close(counted: Decimal.parse('1200.00'));

    // ── деньги легли в смену ────────────────────────────────────────────
    final closed = await db.shiftDao.findById(shiftId);
    expect(closed!.isOpened, isFalse);
    expect(closed.cashInPosOnShiftClose, Decimal.parse('1200.00'));
    expect(
      closed.closeTime,
      isNotNull,
      reason: 'время закрытия не записано',
    );
    // Тот же порядок величины: секунды.
    expect(
      closed.closeTime!,
      closeTo(DateTime.now().millisecondsSinceEpoch ~/ 1000, 60),
    );

    // ── и расхождение записано кассовой операцией ───────────────────────
    //
    // 1200 насчитано − 1000 ожидалось = 200 излишка. Без этой проверки
    // закрытие с планшета выглядело бы работающим и **теряло бы деньги**:
    // расхождение, записанное с кассы и не записанное с планшета, не
    // ловится ни инвентаризацией, ни отчётом смены.
    final ops = await db.select(db.cashOperations).get();
    // Род, а не примечание: примечание — свободный текст для человека,
    // и опираться на его написание значило бы ломать пробу переводом.
    final surplus = ops
        .where((o) => o.type == kCashOpReconciliationOverage)
        .toList();
    expect(surplus, hasLength(1));
    expect(surplus.single.amount, Decimal.parse('200.00'));
    expect(surplus.single.userId, 4);

    // Подписка сказала о закрытии сама — без нового вопроса.
    final after = await desk.watch().first;
    expect(after.open, isFalse);
  });

  test('наличный возврат уменьшает «должно быть», а выручка увеличивает', () async {
    // # Зачем эта проба заведена
    //
    // Первая редакция `LocalShiftDesk._salesTotals` брала оплаты одним
    // запросом (`receipt_no IS NOT NULL`) и делила их по знаку. Возвраты в
    // такую выборку не попадают вовсе: строка оплаты возврата ссылается на
    // `refund_local_id`, а не на `receipt_no`. «Должно быть» выходило
    // завышенным ровно на сумму наличных возвратов, и ровно на столько же
    // врало расхождение — закрытие смены писало бы недостачу там, где всё
    // сошлось. Набор при этом был зелен: в его смене возвратов не было.
    final openedAt = secondsAgo(const Duration(hours: 2));
    await openShiftAt(openedAt, openingCash: Decimal.parse('1000.00'));

    // Продали на 500 наличными...
    await db
        .into(db.payments)
        .insert(
          PaymentsCompanion.insert(
            userId: 4,
            receiptNo: const Value(1),
            payeeAccountId: 11,
            amount: Decimal.parse('500.00'),
            time: openedAt + 10,
          ),
        );
    // ...и вернули 200 наличными.
    await db
        .into(db.payments)
        .insert(
          PaymentsCompanion.insert(
            userId: 4,
            refundLocalId: const Value(1),
            payeeAccountId: 11,
            amount: Decimal.parse('-200.00'),
            time: openedAt + 20,
          ),
        );

    final desk = await boot(cashier);
    final view = await desk.watch().first;

    // 1000 начало + 500 выручки − 200 возврата = 1300.
    expect(
      view.expectedCash,
      Decimal.parse('1300.00'),
      reason:
          'наличный возврат не вычтен из «должно быть» — расхождение при '
          'закрытии смены соврёт ровно на его сумму',
    );

    // И то же число доезжает до записи расхождения: в ящике ровно столько,
    // сколько должно быть, — значит ни излишка, ни недостачи.
    await desk.close(counted: Decimal.parse('1300.00'));
    final ops = await db.select(db.cashOperations).get();
    expect(
      ops.where((o) => isReconciliation(o.type)),
      isEmpty,
      reason: 'касса записала расхождение там, где всё сошлось',
    );
  });

  test('не считали — расхождения нет, и касса берёт ОЖИДАНИЕ', () async {
    final shiftId = await openShiftAt(
      secondsAgo(const Duration(hours: 2)),
      openingCash: Decimal.parse('1000.00'),
    );
    final desk = await boot(cashier);

    // `null`, а не ноль. Эта половина и есть смысл того, что поле
    // необязательно: ноль означал бы «ящик пуст» и записал бы недостачу
    // 1000 на ровном месте.
    await desk.close();

    final closed = await db.shiftDao.findById(shiftId);
    expect(closed!.isOpened, isFalse);
    // ── 1000, а не 7000. Это правка 2026-09-22 ──────────────────────────
    //
    // Стояло `7000.00` — остаток счёта кассы, который эта проба нарочно
    // завела расходящимся с объявлением смены (счёт 7000, объявлено 1000).
    // Закрытие брало остаток, а расхождение считается от `expectedCash`:
    // два разных ответа на один вопрос. На смене с подъёмными они
    // расходились ровно на подъёмные, и закрытие без пересчёта записывало
    // в наличные смены чужое число — оно же уходило в Z-отчёт.
    //
    // Верно — ожидание: начало 1000 + выручки нет − возвратов нет.
    expect(
      closed.cashInPosOnShiftClose,
      Decimal.parse('1000.00'),
      reason:
          'без пересчёта касса обязана взять то самое «должно быть», с '
          'которым сличает пересчёт, а не остаток счёта',
    );

    final ops = await db.select(db.cashOperations).get();
    expect(
      ops.where((o) => isReconciliation(o.type)),
      isEmpty,
      reason:
          'расхождение записано без пересчёта — касса утверждает «сошлось» '
          'там, где никто не проверял',
    );
  });

  test('ноль в ящике — это пересчёт, а не «не считали»', () async {
    await openShiftAt(
      secondsAgo(const Duration(hours: 2)),
      openingCash: Decimal.parse('1000.00'),
    );
    final desk = await boot(cashier);

    await desk.close(counted: Decimal.zero);

    // Ящик пуст при ожидаемой тысяче — недостача на всю тысячу, и она
    // обязана быть записана. Прими касса ноль за «не считали», запись
    // пропала бы, а деньги — нет.
    final ops = await db.select(db.cashOperations).get();
    final shortage = ops
        .where((o) => o.type == kCashOpReconciliationShortage)
        .toList();
    expect(shortage, hasLength(1));
    // Сумма ПОЛОЖИТЕЛЬНА, сторону несёт род. Стояло `-1000.00` под родом
    // «изъятие»: отчёт по изъятиям вычитал недостачу вместо того, чтобы
    // её прибавить, а на экране смены она показывалась зелёным внесением.
    expect(shortage.single.amount, Decimal.parse('1000.00'));
    expect(shortage.single.type, kCashOpReconciliationShortage);

    // И остаток счёта кассы сведён с пересчётом: строку журнала писали и
    // раньше, а баланс не двигали — журнал и остаток расходились навсегда,
    // и следующая смена стартовала с денег, которых в ящике нет.
    final account = await db.accountDao.findById(11);
    expect(
      account!.value,
      Decimal.zero,
      reason: 'ящик пересчитан пустым — остаток счёта обязан это увидеть',
    );
  });

  test('просроченная смена названа просроченной — тем же правилом', () async {
    // Сутки и одна минута: предел `ShiftAgeRule.limit` со сравнением `>=`.
    await openShiftAt(secondsAgo(const Duration(hours: 24, minutes: 1)));
    final desk = await boot(cashier);

    final view = await desk.watch().first;
    expect(view.open, isTrue);
    expect(
      view.overAge,
      isTrue,
      reason:
          'значок на доме терминала показал бы зелёную галочку при смене, '
          'которая уже заперла продажу',
    );
    // И то же самое правило, а не похожее: продажа запирается ровно им.
    expect(await ShiftAgeRule(db: db).isOverAge(), isTrue);

    // Предел проверяется и снизу — иначе `overAge: true` мог бы означать
    // «всегда true», и проба была бы зелена ни о чём.
    await (db.update(db.shifts)).write(
      ShiftsCompanion(openTime: Value(secondsAgo(const Duration(hours: 23)))),
    );
    expect((await desk.watch().first).overAge, isFalse);
  });

  test('закрывать нечего — названный отказ, а не тихое «готово»', () async {
    final desk = await boot(cashier);
    await expectLater(
      desk.close(counted: Decimal.parse('100.00')),
      throwsA(
        isA<WireRefusal>().having((e) => e.code, 'code', shiftNotOpenCode),
      ),
      reason:
          'кассовая служба при отсутствии смены пишет в журнал и молча '
          'возвращается — по проводу это прочлось бы как «закрыл», и кассир '
          'решил бы, что теперь можно продавать',
    );
  });

  test('смена открывается на кассира из сеанса, а не из тела', () async {
    // Сеанс выписан на пользователя 4; в теле кадра пользователя нет вовсе
    // (`shift.open` возит только деньги) — проверяется, что касса взяла
    // его из сеанса.
    final desk = await boot(cashier, userId: 4);
    await desk.open(openingCash: Decimal.parse('500.00'));

    final shift = await db.shiftDao.findOpenedShift();
    expect(shift, isNotNull);
    expect(shift!.userId, 4, reason: 'смена открыта не на того кассира');
    expect(shift.openingCash, Decimal.parse('500.00'));
    // Секунды, не миллисекунды.
    expect(
      shift.openTime,
      closeTo(DateTime.now().millisecondsSinceEpoch ~/ 1000, 60),
    );

    // Вторую открыть нечем: `findOpenedShift` читает `getSingleOrNull()`, и
    // две открытые смены — не состояние, а падение.
    await expectLater(
      desk.open(),
      throwsA(
        isA<WireRefusal>().having((e) => e.code, 'code', shiftAlreadyOpenCode),
      ),
    );
  });

  test('без права nav.shift не открывается ни одна из трёх', () async {
    final desk = await boot(const {});
    await expectLater(
      desk.close(),
      throwsA(isA<WireRefusal>().having((e) => e.code, 'code', 'forbidden')),
    );
    await expectLater(
      desk.open(),
      throwsA(isA<WireRefusal>().having((e) => e.code, 'code', 'forbidden')),
    );
    await expectLater(
      desk.watch().first,
      throwsA(anything),
      reason: 'подписка состояния смены открылась без права',
    );
  });
}
