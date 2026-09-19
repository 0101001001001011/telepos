/// `pay.prepaymentIntake` — приём аванса **из продукта**, а не из пробы:
/// требование заказчика 2026-09-18.
///
/// # Зачем эта проба отдельно от проб юзкейса
///
/// Те зовут `CustomerPaymentUseCase` напрямую и доказывают, что приём
/// верен. Они **не доказывают, что до приёма можно дойти с терминала** —
/// ровно этот класс дефекта дерево уже ловило: `pay.certificateIssue`
/// написана, охраняется и не вызывается ниоткуда; приём аванса до этой
/// работы был написан, верен — и недостижим из браузера вовсе.
///
/// Здесь проверяется путь: кадр провода → обработчик кассы → три строки в
/// базе (счёт покупателя, счёт кассы, проводка) и фискальный чек.
///
/// # Почему счёт кассы проверяется отдельной величиной
///
/// Потому что до этой работы его двигал **контроллер экрана**, а не
/// юзкейс, и обработчик провода контроллера не зовёт. Проба на один только
/// счёт покупателя была бы зелёной и на сломанном приёме: сальдо выросло
/// бы, а ящик сошёлся с недостачей.
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
import 'package:telepos/domain/payment/prepayment_intake.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/wire/pay_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

import 'support/bare_till_deps.dart';
import 'support/noop_auth.dart';

/// Счёт кассы: куда ложатся наличные.
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
  /// назвал. Это не поблажка кадру, а честная подстановка того, что в жизни
  /// кладёт экран: каждая проба здесь — отдельная заявка, и общий ключ
  /// превратил бы соседние пробы в повторы друг друга.
  ///
  /// Кадр может назвать ключ сам — так проверяются и повтор (тот же ключ), и
  /// кадр, собранный мимо экрана (пустая строка).
  Future<Map<String, Object?>> take(Map<String, Object?> body) async {
    final result = await ops.askHandlers[PayOps.prepaymentIntake.name]!({
      'key': 'k-${keySeq++}',
      ...body,
    }, null);
    return result;
  }

  Future<Decimal> balanceOf(int accountId) async =>
      (await db.accountDao.findById(accountId))?.value ?? Decimal.zero;

  /// Собрать кассу с приёмом аванса поверх [service].
  void bootWith(PrepaymentIntakeService service) {
    ops = TillOperations(
      db: db,
      bootstrap: BareBootstrap(),
      setup: BareSetup(),
      terminals: BareTerminals(),
      deviceBindings: BareBindings(),
      auth: NoopAuth(),
      prepaymentIntake: service,
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
    // Вид оплаты — из справочника кассы, а не из воздуха: юзкейс требует
    // род `tender` и берёт у вида вид оплаты оператора для чека.
    for (final id in const [
      SystemPaymentKindIds.cash,
      SystemPaymentKindIds.bonus,
    ]) {
      await db.paymentKindDao.put(SystemPaymentKinds.byId(id));
    }

    bootWith(CustomerPaymentUseCaseImpl(db: db, logger: Talker(), fiscal: fiscal));
  });

  tearDown(() => db.close());

  test('кадр провода доводит приём до трёх строк базы', () async {
    final answer = await take({
      'customerId': _customerId,
      // Деньги по проводу — **строкой** (I159).
      'amount': '1000',
      'tenderKindId': SystemPaymentKindIds.cash,
      'note': 'Аванс покупателя (Айгуль)',
    });

    // Ответ — тот, который увидит вкладка.
    expect(answer['balance'], '1000');
    expect(answer['operationId'], isA<int>());

    // Счёт покупателя вырос.
    expect(await balanceOf(_agentAccountId), d('1000'));

    // И счёт кассы — тоже. Это и есть та половина, которой до 2026-09-18 у
    // провода не было вовсе: её делал контроллер экрана.
    expect(
      await balanceOf(_tillAccountId),
      d('1000'),
      reason: 'деньги приняты кассой, а не только записаны покупателю',
    );

    // Проводка — то, по чему приём виден человеку в журнале.
    final operations = await db.select(db.cashOperations).get();
    expect(operations, hasLength(1));
    expect(operations.single.amount, d('1000'));
    expect(operations.single.accountId, _agentAccountId);
    expect(operations.single.kindId, SystemPaymentKindIds.cash);
    expect(operations.single.note, 'Аванс покупателя (Айгуль)');
  });

  test('ответ разбирается тем же кодеком, что его и пишет', () async {
    final answer = await take({
      'customerId': _customerId,
      'amount': '1200.500',
      'tenderKindId': SystemPaymentKindIds.cash,
    });
    final parsed = prepaymentIntakeOutcomeFromWireJson(answer);

    expect(parsed.balance, d('1200.5'));
    expect(parsed.operationId, greaterThan(0));
    expect(parsed.fiscalSign, 'ФП-7');
  });

  test('чек аванса уходит оператору при включённой настройке', () async {
    // Настройка v47 включена по умолчанию — сказано измерением, а не
    // верой: проба, полагающаяся на умолчание, зеленела бы и после его
    // смены.
    expect(
      (await db.thisPosDao.offsetFiscalSettings()).fiscalizePrepaymentReceipt,
      isTrue,
    );

    await take({
      'customerId': _customerId,
      'amount': '1000',
      'tenderKindId': SystemPaymentKindIds.cash,
    });

    expect(fiscal.prepayments, hasLength(1));
    expect(fiscal.prepayments.single.amount, d('1000'));
    expect(fiscal.prepayments.single.kind, FiscalPaymentKind.cash);
    expect(fiscal.prepayments.single.positionName, contains('Айгуль'));
  });

  test('при выключенной настройке чека нет, а деньги приняты', () async {
    await db.thisPosDao.saveOffsetFiscalSettings(
      const FiscalOffsetSettings(fiscalizePrepaymentReceipt: false),
    );

    final answer = await take({
      'customerId': _customerId,
      'amount': '1000',
      'tenderKindId': SystemPaymentKindIds.cash,
    });

    expect(fiscal.prepayments, isEmpty, reason: 'настройка выключена');
    expect(answer.containsKey('fiscalSign'), isFalse);
    // Обе стороны, а не одна: «чека нет» без «деньги приняты» — это проба,
    // которая зеленеет и на сломанном приёме.
    expect(await balanceOf(_agentAccountId), d('1000'));
    expect(await balanceOf(_tillAccountId), d('1000'));
  });

  test('долг гасится первым, чек выписывается на остаток', () async {
    await db.accountDao.updateBalance(_agentAccountId, d('-300'));

    final answer = await take({
      'customerId': _customerId,
      'amount': '1000',
      'tenderKindId': SystemPaymentKindIds.cash,
    });

    expect(answer['balance'], '700');
    // Погашение долга авансом не является — назвать его «Аванс
    // (предоплата)» значило бы соврать оператору в наименовании.
    expect(fiscal.prepayments.single.amount, d('700'));
  });

  test('зачётом аванс не вносится — отказ назван, счета не тронуты', () async {
    await expectLater(
      take({
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

    expect(await balanceOf(_agentAccountId), Decimal.zero);
    expect(await balanceOf(_tillAccountId), Decimal.zero);
  });

  test('нет счёта приёма — отказ ДО записи, а не приём наполовину', () async {
    // Касса без счёта приёма: ни своего счёта у `ThisPos`, ни строки типа
    // `pos`. Ровно то, что бывает на недонастроенной установке.
    await (db.update(db.thisPosEntries)..where((t) => t.id.equals(1))).write(
      const ThisPosEntriesCompanion(accountId: Value(null)),
    );
    await (db.delete(db.accounts)
          ..where((a) => a.id.equals(_tillAccountId)))
        .go();

    await expectLater(
      take({
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

    // Несущая часть пробы: сальдо покупателя **не выросло**. До
    // 2026-09-18 отсюда выходили молча — уже после того, как оно выросло, —
    // и покупатель считался внёсшим деньги, которых касса не видела.
    expect(
      await balanceOf(_agentAccountId),
      Decimal.zero,
      reason: '«принять нечем» не имеет права стать «принято наполовину»',
    );
    // И операции кассы не завелось: отказ идёт раньше любой записи.
    expect(await db.select(db.cashOperations).get(), isEmpty);
  });

  test('ноль и минус — названный отказ, а не «принято»', () async {
    for (final amount in const ['0', '-100']) {
      await expectLater(
        take({
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
    expect(await balanceOf(_tillAccountId), Decimal.zero);
  });

  test('покупателя нет в картотеке — свой код, тот же, что у зачёта', () async {
    await expectLater(
      take({
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

  test('касса без приёма аванса отказывает названной причиной', () async {
    ops = TillOperations(
      db: db,
      bootstrap: BareBootstrap(),
      setup: BareSetup(),
      terminals: BareTerminals(),
      deviceBindings: BareBindings(),
      auth: NoopAuth(),
    );

    await expectLater(
      take({
        'customerId': _customerId,
        'amount': '1000',
        'tenderKindId': SystemPaymentKindIds.cash,
      }),
      throwsA(
        isA<WireRefusal>().having(
          (e) => e.code,
          'code',
          prepaymentIntakeUnavailableCode,
        ),
      ),
    );
    expect(
      await balanceOf(_agentAccountId),
      Decimal.zero,
      reason: 'отказ обязан быть назван до денег, а не после',
    );
  });

  test('без фискального узла деньги всё равно приняты', () async {
    // `RefusingFiscalService` — «узла в этой сборке нет», сказанное типом.
    // Отказ оператора денег не отменяет, и отсутствие узла — тем более.
    bootWith(
      CustomerPaymentUseCaseImpl(
        db: db,
        logger: Talker(),
        fiscal: const RefusingFiscalService(),
      ),
    );

    final answer = await take({
      'customerId': _customerId,
      'amount': '1000',
      'tenderKindId': SystemPaymentKindIds.cash,
    });

    expect(answer['balance'], '1000');
    expect(answer.containsKey('fiscalSign'), isFalse);
    expect(await balanceOf(_tillAccountId), d('1000'));
  });

  test('тот же ключ — прежний исход, и ни одной новой строки', () async {
    // Дефект живой приёмки 2026-09-18 на уровне **кадра**: обработчик
    // обязан отвечать на повтор прежним исходом сам, а не полагаться на то,
    // что вкладка не пошлёт кадр дважды.
    final body = {
      'key': 'k-повтор',
      'customerId': _customerId,
      'amount': '1000',
      'tenderKindId': SystemPaymentKindIds.cash,
    };

    final first = await take(body);
    final second = await take(body);

    expect(second['operationId'], first['operationId']);
    expect(second['balance'], first['balance']);
    expect(await balanceOf(_agentAccountId), d('1000'));
    expect(await balanceOf(_tillAccountId), d('1000'));
    expect((await db.select(db.cashOperations).get()), hasLength(1));
    // И чек оператору выписан **один раз**: повтор — не вторая продажа.
    expect(fiscal.prepayments, hasLength(1));
  });

  test('кадр без ключа отказан названной причиной, и счета не тронуты', () async {
    await expectLater(
      take({
        'key': '',
        'customerId': _customerId,
        'amount': '1000',
        'tenderKindId': SystemPaymentKindIds.cash,
      }),
      throwsA(
        isA<WireRefusal>().having(
          (e) => e.code,
          'code',
          prepaymentIntakeKeyMissingCode,
        ),
      ),
    );

    expect(await balanceOf(_agentAccountId), Decimal.zero);
    expect(await balanceOf(_tillAccountId), Decimal.zero);
    expect((await db.select(db.cashOperations).get()), isEmpty);
    expect(fiscal.prepayments, isEmpty);
  });
}

/// Фискальный узел, который **записывает** просьбу выписать чек аванса.
///
/// Подделка, а не настоящий узел: эта проба про путь кадра до денег, а не
/// про разговор с оператором. Запись — затем, чтобы «чек ушёл» и «чека не
/// было» различались величиной, а не верой.
class _SpyFiscal implements FiscalService {
  final List<_Advance> prepayments = [];

  @override
  Future<bool> isEnabled() async => true;

  @override
  Future<FiscalResult> fiscalizePrepayment({
    required int operationId,
    required Decimal amount,
    required FiscalPaymentKind paymentKind,
    required String positionName,
  }) async {
    prepayments.add(
      _Advance(
        amount: amount,
        kind: paymentKind,
        positionName: positionName,
      ),
    );
    return const FiscalResult(success: true, fiscalSign: 'ФП-7');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _Advance {
  const _Advance({
    required this.amount,
    required this.kind,
    required this.positionName,
  });

  final Decimal amount;
  final FiscalPaymentKind kind;
  final String positionName;
}
