/// `pay.prepaymentRefund` — выдача аванса **из продукта**, а не из пробы:
/// решение заказчика 2026-09-18 «в браузере должно работать то же, что в
/// приложении».
///
/// # Зачем эта проба отдельно от проб юзкейса
///
/// `test/data/payment/prepayment_refund_test.dart` зовёт
/// `CustomerPaymentUseCase.refundPrepayment` напрямую и доказывает, что
/// выдача верна. Она **не доказывает, что до выдачи можно дойти с
/// терминала** — а до этой работы дойти было нельзя ничем: юзкейс заведён
/// 2026-09-19 целиком, экран под ним только кассовый, операции провода не
/// существовало. Кассир с планшетом мог взять аванс и не мог его отдать.
///
/// Здесь проверяется путь: кадр провода → обработчик кассы → три строки в
/// базе (счёт покупателя, счёт кассы, проводка) и документ возврата у
/// оператора.
///
/// # Почему счёт кассы проверяется отдельной величиной
///
/// Тот же довод, что у приёма: проба на один только счёт покупателя была бы
/// зелёной и на сломанной выдаче — сальдо упало бы, а ящик сошёлся с
/// излишком.
///
/// # Чего эта проба НЕ доказывает
///
/// - **Что право охраняет операцию достижимо.** Это доказывает
///   `prepayment_refund_permissions_test.dart` — кадром через настоящего
///   сторожа. Здесь обработчик зовётся напрямую, сторож не участвует вовсе.
/// - **Что в ящике есть наличные.** Касса знает сальдо счёта выдачи, а не
///   содержимое ящика; сторожа на это нет ни у одной выдачи денег в дереве.
/// - **Что работает ВТОРАЯ линия заслона повтора** — та, что ловит
///   `UNIQUE constraint` от двух кадров, доехавших одновременно. Измерено
///   диверсией: со снятой первой линией проба «тот же ключ» краснеет
///   отказом `prepayment_refund_exceeds_balance`, то есть до вставки ключа
///   дело не доходит вовсе — аванс кончается раньше. Структурно ключ
///   проверен вставкой в `migration_v52_prepayment_refunds_test.dart`;
///   ветвь `catch` в `_payOutMoney`, превращающая его падение в повтор,
///   детерминированной пробы **не имеет**: чтобы до неё дойти, нужно, чтобы
///   первая линия прочла пустую память, а вторая уже была занята, — то есть
///   нужна настоящая гонка, а проба, ждущая гонки, мерцает. Ровно тот же
///   предел у приёма (`_writeMoney`), и он здесь назван, а не спрятан.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/usecases/payment/customer_payment_use_case_impl.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';
import 'package:telepos/domain/payment/prepayment_intake.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/wire/pay_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

import 'support/bare_till_deps.dart';
import 'support/noop_auth.dart';

/// Счёт кассы: откуда уходят выданные наличные.
const _tillAccountId = 11;

/// Расчётный счёт покупателя: там живёт аванс.
const _agentAccountId = 14;

const _customerId = 5;

void main() {
  late AppDatabase db;
  late _SpyFiscal fiscal;
  late TillOperations ops;

  Decimal d(String v) => Decimal.parse(v);

  /// Порядковый номер заявки — вторая половина подставляемого ключа.
  var keySeq = 0;

  /// Послать кадр обработчику.
  ///
  /// Ключ повтора подставляется **новым на каждый вызов**, если кадр его не
  /// назвал: каждая проба здесь — отдельная заявка, и общий ключ превратил бы
  /// соседние пробы в повторы друг друга. Кадр может назвать ключ сам — так
  /// проверяются и повтор (тот же ключ), и кадр, собранный мимо экрана
  /// (пустая строка).
  Future<Map<String, Object?>> payOut(Map<String, Object?> body) async {
    return ops.askHandlers[PayOps.prepaymentRefund.name]!({
      'key': 'r-${keySeq++}',
      ...body,
    }, null);
  }

  Future<Decimal> balanceOf(int accountId) async =>
      (await db.accountDao.findById(accountId))?.value ?? Decimal.zero;

  /// Собрать кассу с выдачей аванса поверх [service].
  void bootWith(PrepaymentRefundService service) {
    ops = TillOperations(
      db: db,
      bootstrap: BareBootstrap(),
      setup: BareSetup(),
      terminals: BareTerminals(),
      deviceBindings: BareBindings(),
      auth: NoopAuth(),
      prepaymentRefund: service,
    );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    fiscal = _SpyFiscal();

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
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(_tillAccountId),
            type: AccountType.pos,
            name: const Value('Касса'),
            // В ящике заведомо больше, чем выдают: проба про выдачу аванса, а
            // не про пустую кассу.
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
            // Аванс, внесённый вперёд. Третий знак — **не украшение**: в
            // двойной точности 2000.005 не представима, и `double` где-нибудь
            // по дороге превратил бы её в 2000.004999…
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
    for (final id in const [
      SystemPaymentKindIds.cash,
      SystemPaymentKindIds.bonus,
    ]) {
      await db.paymentKindDao.put(SystemPaymentKinds.byId(id));
    }

    bootWith(
      CustomerPaymentUseCaseImpl(db: db, logger: Talker(), fiscal: fiscal),
    );
  });

  tearDown(() => db.close());

  test('кадр провода доводит выдачу до трёх строк базы', () async {
    final answer = await payOut({
      'customerId': _customerId,
      // Деньги по проводу — **строкой** (I159), и третьим знаком: 1200.005 в
      // двойной точности не представима.
      'amount': '1200.005',
      'tenderKindId': SystemPaymentKindIds.cash,
      'note': 'Выдача аванса покупателю (Айгуль)',
    });

    // Ответ — тот, который увидит вкладка. 2000.005 − 1200.005 = 800 ровно,
    // и это тот самый разряд, который `double` теряет.
    expect(answer['balance'], '800');
    expect(answer['operationId'], isA<int>());

    // Счёт покупателя уменьшился.
    expect(await balanceOf(_agentAccountId), d('800'));

    // И счёт кассы — тоже: деньги ушли из ящика, а не только списались у
    // покупателя.
    expect(
      await balanceOf(_tillAccountId),
      d('8799.995'),
      reason: 'деньги выданы кассой, а не только списаны покупателю',
    );

    // Проводка — то, по чему выдача видна человеку в журнале.
    final operations = await db.select(db.cashOperations).get();
    expect(operations, hasLength(1));
    expect(operations.single.amount, d('1200.005'));
    expect(operations.single.accountId, _agentAccountId);
    expect(operations.single.kindId, SystemPaymentKindIds.cash);
    expect(
      operations.single.type,
      CashInOutType.expense.index,
      reason: 'род проводки — расход: приход на минус прибавил бы к выручке '
          'отрицательное число',
    );
    expect(operations.single.note, 'Выдача аванса покупателю (Айгуль)');
  });

  test('ответ разбирается тем же кодеком, что его и пишет', () async {
    final answer = await payOut({
      'customerId': _customerId,
      'amount': '1200.005',
      'tenderKindId': SystemPaymentKindIds.cash,
    });
    final parsed = prepaymentRefundOutcomeFromWireJson(answer);

    expect(parsed.balance, d('800'));
    expect(parsed.operationId, greaterThan(0));
    expect(parsed.fiscalSign, 'ФП-9');
  });

  test('документ возврата уходит оператору при включённой настройке', () async {
    // Настройка одна на приём и на выдачу — сказано измерением, а не верой.
    expect(
      (await db.thisPosDao.offsetFiscalSettings()).fiscalizePrepaymentReceipt,
      isTrue,
    );

    await payOut({
      'customerId': _customerId,
      'amount': '1000',
      'tenderKindId': SystemPaymentKindIds.cash,
      'intakeOperationId': 77,
    });

    expect(fiscal.refunds, hasLength(1));
    expect(fiscal.refunds.single.amount, d('1000'));
    expect(fiscal.refunds.single.kind, FiscalPaymentKind.cash);
    expect(fiscal.refunds.single.positionName, contains('Айгуль'));
    expect(
      fiscal.refunds.single.intakeOperationId,
      77,
      reason: 'основание названо кассиром и доезжает до оператора как есть',
    );
  });

  test('основание необязательно: без него документ всё равно выписан', () async {
    // Страховка от вырождения соседней пробы: «не назван» — законный случай,
    // а не отказ. Аванс это пул, и сходить за чужим чеком касса не имеет
    // права.
    await payOut({
      'customerId': _customerId,
      'amount': '1000',
      'tenderKindId': SystemPaymentKindIds.cash,
    });

    expect(fiscal.refunds, hasLength(1));
    expect(fiscal.refunds.single.intakeOperationId, isNull);
  });

  test('при выключенной настройке документа нет, а деньги выданы', () async {
    await db.thisPosDao.saveOffsetFiscalSettings(
      const FiscalOffsetSettings(fiscalizePrepaymentReceipt: false),
    );

    final answer = await payOut({
      'customerId': _customerId,
      'amount': '1000',
      'tenderKindId': SystemPaymentKindIds.cash,
    });

    expect(fiscal.refunds, isEmpty, reason: 'настройка выключена');
    expect(answer.containsKey('fiscalSign'), isFalse);
    // Обе стороны, а не одна: «документа нет» без «деньги выданы» — проба,
    // которая зеленеет и на сломанной выдаче.
    expect(await balanceOf(_agentAccountId), d('1000.005'));
    expect(await balanceOf(_tillAccountId), d('9000'));
  });

  test('аванса меньше, чем просят — свой код, и счета не тронуты', () async {
    await expectLater(
      payOut({
        'customerId': _customerId,
        'amount': '5000',
        'tenderKindId': SystemPaymentKindIds.cash,
      }),
      throwsA(
        isA<WireRefusal>().having(
          (e) => e.code,
          'code',
          prepaymentRefundExceedsBalanceCode,
        ),
      ),
    );

    expect(await balanceOf(_agentAccountId), d('2000.005'));
    expect(await balanceOf(_tillAccountId), d('10000'));
    expect(await db.select(db.cashOperations).get(), isEmpty);
  });

  test('зачётом аванс не выдаётся — отказ назван, счета не тронуты', () async {
    // Выдать аванс бонусом значило бы переложить обязательство, а не вернуть
    // деньги.
    await expectLater(
      payOut({
        'customerId': _customerId,
        'amount': '1000',
        'tenderKindId': SystemPaymentKindIds.bonus,
      }),
      throwsA(
        isA<WireRefusal>().having(
          (e) => e.code,
          'code',
          prepaymentTenderInvalidCode,
        ),
      ),
    );

    expect(await balanceOf(_agentAccountId), d('2000.005'));
    expect(await balanceOf(_tillAccountId), d('10000'));
  });

  test('нет счёта выдачи — отказ ДО записи, а не выдача наполовину', () async {
    await (db.update(db.thisPosEntries)..where((t) => t.id.equals(1))).write(
      const ThisPosEntriesCompanion(accountId: Value(null)),
    );
    await (db.delete(db.accounts)..where((a) => a.id.equals(_tillAccountId)))
        .go();

    await expectLater(
      payOut({
        'customerId': _customerId,
        'amount': '1000',
        'tenderKindId': SystemPaymentKindIds.cash,
      }),
      throwsA(
        isA<WireRefusal>().having(
          (e) => e.code,
          'code',
          prepaymentTillAccountMissingCode,
        ),
      ),
    );

    // Несущая часть пробы: сальдо покупателя **не упало**. «Выдавать нечем»
    // не имеет права стать «выдано наполовину».
    expect(await balanceOf(_agentAccountId), d('2000.005'));
    expect(await db.select(db.cashOperations).get(), isEmpty);
  });

  test('ноль и минус — названный отказ, а не «выдано»', () async {
    for (final amount in const ['0', '-100']) {
      await expectLater(
        payOut({
          'customerId': _customerId,
          'amount': amount,
          'tenderKindId': SystemPaymentKindIds.cash,
        }),
        throwsA(
          isA<WireRefusal>().having(
            (e) => e.code,
            'code',
            prepaymentAmountInvalidCode,
          ),
        ),
        reason: 'сумма $amount',
      );
    }
    expect(await balanceOf(_tillAccountId), d('10000'));
  });

  test('покупателя нет в картотеке — тот же код, что у зачёта', () async {
    await expectLater(
      payOut({
        'customerId': 999,
        'amount': '1000',
        'tenderKindId': SystemPaymentKindIds.cash,
      }),
      throwsA(
        isA<WireRefusal>().having(
          (e) => e.code,
          'code',
          'loyalty_customer_unknown',
        ),
      ),
    );
  });

  test('касса без выдачи аванса отказывает названной причиной', () async {
    ops = TillOperations(
      db: db,
      bootstrap: BareBootstrap(),
      setup: BareSetup(),
      terminals: BareTerminals(),
      deviceBindings: BareBindings(),
      auth: NoopAuth(),
    );

    await expectLater(
      payOut({
        'customerId': _customerId,
        'amount': '1000',
        'tenderKindId': SystemPaymentKindIds.cash,
      }),
      throwsA(
        isA<WireRefusal>().having(
          (e) => e.code,
          'code',
          prepaymentRefundUnavailableCode,
        ),
      ),
    );
    expect(
      await balanceOf(_agentAccountId),
      d('2000.005'),
      reason: 'отказ обязан быть назван до денег, а не после',
    );
  });

  test('без фискального узла деньги всё равно выданы', () async {
    // `RefusingFiscalService` — «узла в этой сборке нет», сказанное типом.
    // Отказ оператора денег не отменяет, и отсутствие узла — тем более.
    bootWith(
      CustomerPaymentUseCaseImpl(
        db: db,
        logger: Talker(),
        fiscal: const RefusingFiscalService(),
      ),
    );

    final answer = await payOut({
      'customerId': _customerId,
      'amount': '1000',
      'tenderKindId': SystemPaymentKindIds.cash,
    });

    expect(answer['balance'], '1000.005');
    expect(answer.containsKey('fiscalSign'), isFalse);
    expect(await balanceOf(_tillAccountId), d('9000'));
  });

  test('тот же ключ — прежний исход, и ни одной новой строки', () async {
    // Ровно та беда, ради которой ключ и заведён: провод рвётся **после**
    // того, как деньги выданы, вкладка видит отказ, кассир жмёт «Выдать»
    // второй раз. Обработчик обязан ответить прежним исходом сам, а не
    // полагаться на то, что вкладка не пошлёт кадр дважды.
    final body = {
      'key': 'r-повтор',
      'customerId': _customerId,
      'amount': '1200.005',
      'tenderKindId': SystemPaymentKindIds.cash,
    };

    final first = await payOut(body);
    final second = await payOut(body);

    expect(second['operationId'], first['operationId']);
    expect(second['balance'], first['balance']);
    // Несущая часть: из ящика ушло **один раз**.
    expect(await balanceOf(_agentAccountId), d('800'));
    expect(await balanceOf(_tillAccountId), d('8799.995'));
    expect(await db.select(db.cashOperations).get(), hasLength(1));
    // И документ оператору выписан один раз: повтор — не второй возврат.
    expect(fiscal.refunds, hasLength(1));
    // Фискальный признак доезжает и до повтора: он дописан в память заявки
    // после похода к оператору.
    expect(second['fiscalSign'], 'ФП-9');
  });

  test('ключ приёма и ключ выдачи не путаются между собой', () async {
    // **Довод за отдельную таблицу памяти.** Одно пространство ключей на два
    // действия означало бы, что выдача с ключом, уже занятым приёмом,
    // получит в ответ исход приёма — «выдано» без единой выданной копейки.
    //
    // Проба ставит заведомо одинаковые ключи и требует, чтобы обе операции
    // сходили за деньгами по-настоящему.
    final intakeOps = TillOperations(
      db: db,
      bootstrap: BareBootstrap(),
      setup: BareSetup(),
      terminals: BareTerminals(),
      deviceBindings: BareBindings(),
      auth: NoopAuth(),
      prepaymentIntake: CustomerPaymentUseCaseImpl(
        db: db,
        logger: Talker(),
        fiscal: fiscal,
      ),
      prepaymentRefund: CustomerPaymentUseCaseImpl(
        db: db,
        logger: Talker(),
        fiscal: fiscal,
      ),
    );

    const sameKey = 'одинаковый-ключ';
    final accepted = await intakeOps.askHandlers[PayOps.prepaymentIntake
        .name]!({
      'key': sameKey,
      'customerId': _customerId,
      'amount': '1000',
      'tenderKindId': SystemPaymentKindIds.cash,
    }, null);
    expect(accepted['balance'], '3000.005');

    final paidOut = await intakeOps.askHandlers[PayOps.prepaymentRefund
        .name]!({
      'key': sameKey,
      'customerId': _customerId,
      'amount': '500',
      'tenderKindId': SystemPaymentKindIds.cash,
    }, null);

    expect(
      paidOut['balance'],
      '2500.005',
      reason: 'выдача обязана состояться, а не ответить исходом приёма',
    );
    expect(paidOut['operationId'], isNot(accepted['operationId']));
    expect(await db.select(db.cashOperations).get(), hasLength(2));
  });

  test('два кадра одной заявки разом — деньги уходят один раз', () async {
    // Ближайшее к настоящей гонке, что можно написать без мерцания: оба
    // кадра пущены одновременно, а утверждение верно **обеими** линиями
    // заслона — и той, что прочла память, и той, что упёрлась в ключ.
    // Какая из двух сработала, проба не знает и знать не может; она знает,
    // что из ящика ушло один раз.
    final body = {
      'key': 'r-гонка',
      'customerId': _customerId,
      'amount': '500',
      'tenderKindId': SystemPaymentKindIds.cash,
    };

    final answers = await Future.wait([payOut(body), payOut(body)]);

    expect(answers[1]['operationId'], answers[0]['operationId']);
    expect(await balanceOf(_agentAccountId), d('1500.005'));
    expect(await balanceOf(_tillAccountId), d('9500'));
    expect(await db.select(db.cashOperations).get(), hasLength(1));
  });

  test('кадр без ключа отказан названной причиной, и счета не тронуты', () async {
    await expectLater(
      payOut({
        'key': '',
        'customerId': _customerId,
        'amount': '1000',
        'tenderKindId': SystemPaymentKindIds.cash,
      }),
      throwsA(
        isA<WireRefusal>().having(
          (e) => e.code,
          'code',
          prepaymentRefundKeyMissingCode,
        ),
      ),
    );

    expect(await balanceOf(_agentAccountId), d('2000.005'));
    expect(await balanceOf(_tillAccountId), d('10000'));
    expect(await db.select(db.cashOperations).get(), isEmpty);
    expect(fiscal.refunds, isEmpty);
  });
}

/// Фискальный узел, который **записывает** просьбу выписать документ
/// возврата аванса.
///
/// Подделка, а не настоящий узел: эта проба про путь кадра до денег, а не про
/// разговор с оператором. Запись — затем, чтобы «документ ушёл» и «документа
/// не было» различались величиной, а не верой.
class _SpyFiscal implements FiscalService {
  final List<_Refund> refunds = [];

  @override
  Future<bool> isEnabled() async => true;

  @override
  Future<FiscalResult> fiscalizePrepaymentRefund({
    required int operationId,
    required int? intakeOperationId,
    required Decimal amount,
    required FiscalPaymentKind paymentKind,
    required String positionName,
  }) async {
    refunds.add(
      _Refund(
        amount: amount,
        kind: paymentKind,
        positionName: positionName,
        intakeOperationId: intakeOperationId,
      ),
    );
    return const FiscalResult(success: true, fiscalSign: 'ФП-9');
  }

  @override
  Future<FiscalResult> fiscalizePrepayment({
    required int operationId,
    required Decimal amount,
    required FiscalPaymentKind paymentKind,
    required String positionName,
  }) async => const FiscalResult(success: true, fiscalSign: 'ФП-7');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _Refund {
  const _Refund({
    required this.amount,
    required this.kind,
    required this.positionName,
    required this.intakeOperationId,
  });

  final Decimal amount;
  final FiscalPaymentKind kind;
  final String positionName;
  final int? intakeOperationId;
}
