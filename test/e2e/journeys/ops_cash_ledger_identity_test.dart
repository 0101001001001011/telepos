/// Денежное тождество кассы: журнал, ожидание и ящик — одно число.
///
/// # Что измерено 2026-09-22
///
/// Пробный проход главы 7 показал: кассир кладёт в ящик 200 $, панель с
/// подписью «Expected in register» показывает 0.00. Разбор нашёл не один
/// дефект, а шесть сцепленных в одной модели.
///
/// **Тождество, которое обязано держаться в каждый момент смены:**
///
/// ```
/// ящик = подъёмные
///      + наличная выручка − наличные возвраты
///      + внесения         − (изъятия + дивиденды)
/// ```
///
/// Три числа обязаны быть равны этому и друг другу:
///
/// * `systemTotal` — остаток счёта кассы, «сколько в ящике по журналу»;
/// * `expectedCash` — «должно быть», с чем сличают пересчёт;
/// * `cashEnd` Z-отчёта — «Total in drawer» на бумаге.
///
/// # Шесть дефектов, которые этот сторож держит закрытыми
///
/// 1. Объявленные подъёмные не доезжали до счёта кассы: `onOpenShift` писал
///    их в строку смены и **не трогал счёт**. Отсюда 0.00 на панели.
/// 2. Внесение наличных не входило в «должно быть» ВООБЩЕ. Докстринг
///    `_cashTotals` оправдывал это словами «в „должно быть“ они уже вошли
///    выручкой» — неправда: внесение строки оплаты не создаёт. Внесли
///    100 $ — и на закрытии ложный излишек 100 $.
/// 3. Сведение при закрытии писало строку «излишек/недостача» **мимо
///    баланса**: `cashOperationDao.insert` остаток счёта не двигает. Журнал
///    и остаток расходились навсегда.
/// 4. Закрытие без пересчёта записывало `systemTotal`, тогда как экран
///    сличал с `expectedCash`, — два разных ответа про одно.
/// 5. Сборка Z-отчёта не передавала `openingCash` вовсе, и в строке
///    «Opening float» печатался остаток ПРОШЛОЙ смены.
/// 6. Экраны показывают `state.difference` (от остатка счёта), а стол смены
///    записывает расхождение от `expectedCash`. Числа расходились ровно на
///    подъёмные: пересчитав ящик верно, кассир видел бы «излишек +200».
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/cash/cash_operation_kind.dart';
import 'package:telepos/data/shift/local_shift_desk.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();
  late ProviderContainer container;

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDownAll(() => h.tearDown());

  setUp(() async {
    await h.db.delete(h.db.shifts).go();
    await h.db.delete(h.db.cashOperations).go();
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  Future<void> settle() async {
    for (var i = 0; i < 25; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (!container.read(shiftControllerProvider).isLoading) return;
    }
  }

  Future<int> posAccountId() async {
    final db = GetIt.I<AppDatabase>();
    final fromPos = (await db.thisPosDao.get())?.accountId;
    if (fromPos != null) return fromPos;
    return (await db.accountDao.findByType(AccountType.pos)).first.id;
  }

  Future<Decimal> ledger() async {
    final db = GetIt.I<AppDatabase>();
    final account = await db.accountDao.findById(await posAccountId());
    return account?.value ?? Decimal.zero;
  }

  /// Правая часть тождества, собранная из слагаемых состояния.
  Decimal identity(ShiftState s) =>
      s.openingCash +
      s.cashSalesTotal -
      s.cashRefundsTotal +
      s.investmentTotal -
      (s.expenseTotal + s.dividendTotal);

  Future<void> expectAgreement(String at) async {
    final s = container.read(shiftControllerProvider);
    expect(
      s.expectedCash,
      identity(s),
      reason: 'ожидание обязано быть суммой слагаемых смены ($at)',
    );
    expect(
      await ledger(),
      s.expectedCash,
      reason: 'остаток счёта кассы обязан совпадать с ожиданием ($at)',
    );
  }

  test(
    'подъёмные доезжают до журнала кассы, а не только до строки смены',
    () async {
      final notifier = container.read(shiftControllerProvider.notifier);
      await settle();

      await notifier.openShift(d('200'), userId: 1);
      await settle();

      final s = container.read(shiftControllerProvider);
      expect(s.isOpen, isTrue);
      expect(s.openingCash, d('200'), reason: 'объявление сохранено');
      expect(
        s.systemTotal,
        d('200'),
        reason: 'панель «в ящике по журналу» обязана видеть подъёмные',
      );
      await expectAgreement('сразу после открытия');

      // Строка сведения обязана быть СВОЕГО рода — «пересчёт при
      // открытии», а не «излишек смены». При открытии ожидания ещё нет,
      // сравнивать не с чем, и подписать первое внесение в новую кассу
      // излишком значило бы обвинить деньги, которые кассир положил.
      final ops = await GetIt.I<AppDatabase>()
          .select(GetIt.I<AppDatabase>().cashOperations)
          .get();
      expect(ops, hasLength(1));
      expect(ops.single.type, kCashOpOpeningCountOverage);
      expect(ops.single.amount, d('200'));
      expect(
        ops.single.note,
        isNull,
        reason: 'примечание — свободный текст, которому негде перевестись: '
            'на английской кассе русская проза видна подписью под операцией',
      );
    },
  );

  test('внесение наличных входит в ожидание', () async {
    final notifier = container.read(shiftControllerProvider.notifier);
    await settle();
    await notifier.openShift(d('200'), userId: 1);
    await settle();

    final cash = GetIt.I<CashInOutController>();
    final made = await cash.createInvestment(
      amount: d('100'),
      accountId: await posAccountId(),
    );
    expect(
      made.success,
      isTrue,
      reason: 'операция обязана пройти, иначе проба меряет отказ, а не суммы',
    );
    await notifier.refresh();
    await settle();

    final s = container.read(shiftControllerProvider);
    expect(s.investmentTotal, d('100'));
    expect(
      s.expectedCash,
      d('300'),
      reason: 'внесение кладёт деньги в ящик — ожидание обязано вырасти',
    );
    await expectAgreement('после внесения');
  });

  test('изъятие уменьшает и ожидание, и журнал одинаково', () async {
    final notifier = container.read(shiftControllerProvider.notifier);
    await settle();
    await notifier.openShift(d('200'), userId: 1);
    await settle();

    final cash = GetIt.I<CashInOutController>();
    // Род «Другое» требует комментария — это правило продукта, и первая
    // редакция этой пробы на нём молча получала отказ, показывая ожидание
    // в 200 вместо 150. Исход операции проверяется, чтобы отказ нельзя
    // было спутать с несчитанным слагаемым.
    final made = await cash.createExpense(
      amount: d('50'),
      accountId: await posAccountId(),
      expenseType: ExpenseType.other,
      note: 'на хозяйственные нужды',
    );
    expect(made.success, isTrue, reason: 'изъятие обязано пройти');
    await notifier.refresh();
    await settle();

    final s = container.read(shiftControllerProvider);
    expect(s.expectedCash, d('150'));
    await expectAgreement('после изъятия');
  });

  test('расхождение на экране считается от того же числа, что записывает '
      'закрытие', () async {
    final notifier = container.read(shiftControllerProvider.notifier);
    await settle();
    await notifier.openShift(d('200'), userId: 1);
    await settle();

    notifier.selectTab(1);
    notifier.setManualTotal(d('200'));
    final s = container.read(shiftControllerProvider);
    expect(
      s.difference,
      Decimal.zero,
      reason:
          'пересчитали ровно подъёмные — расхождения нет. Экраны показывают '
          'именно `difference`, и до правки оно равнялось +200',
    );
    expect(
      s.difference,
      s.reconciliation,
      reason: 'два ответа на один вопрос — это дефект, а не запас',
    );
  });

  test('обе реализации формулы отвечают одним числом', () async {
    // У формулы ожидания ДВЕ реализации по построению: `ShiftState`
    // .expectedCash для местного экрана и `LocalShiftDesk.read` для
    // провода. Сверять каждую с константой мало — расходятся они друг с
    // другом, молча и на первой же правке одной из них. Ровно это и
    // случилось с внесениями: у стола смены их не было ни слагаемым, ни
    // в разборе типов, и докстринг оправдывал пропуск неверным доводом.
    final notifier = container.read(shiftControllerProvider.notifier);
    await settle();
    await notifier.openShift(d('200'), userId: 1);
    await settle();

    final cash = GetIt.I<CashInOutController>();
    final account = await posAccountId();
    expect(
      (await cash.createInvestment(amount: d('70'), accountId: account))
          .success,
      isTrue,
    );
    expect(
      (await cash.createExpense(
        amount: d('25'),
        accountId: account,
        expenseType: ExpenseType.salary,
      )).success,
      isTrue,
    );
    await notifier.refresh();
    await settle();

    final onScreen = container.read(shiftControllerProvider).expectedCash;
    // Стол смены собирается прямо здесь, а не берётся из DI: кассовое DI
    // его не регистрирует — он живёт на стороне провода, — и проба обязана
    // спросить ту самую реализацию, которой отвечает браузерный терминал.
    final desk = LocalShiftDesk(db: GetIt.I<AppDatabase>(), actorUserId: 1);
    final overWire = (await desk.watch().first).expectedCash;

    expect(onScreen, d('245'), reason: '200 + 70 − 25');
    expect(
      overWire,
      onScreen,
      reason: 'экран кассы и браузерный терминал обязаны называть кассиру '
          'одно и то же «должно быть»',
    );
    expect(
      await ledger(),
      onScreen,
      reason: 'и журнал кассы — то же число (И175)',
    );
  });

  test('недостача при закрытии двигает остаток счёта, а не только журнал', () async {
    final db = GetIt.I<AppDatabase>();
    final notifier = container.read(shiftControllerProvider.notifier);
    await settle();
    await notifier.openShift(d('200'), userId: 1);
    await settle();

    notifier.selectTab(1);
    notifier.setManualTotal(d('195'));
    expect(container.read(shiftControllerProvider).difference, d('-5'));

    await notifier.closeShift();
    await settle();

    expect(
      await ledger(),
      d('195'),
      reason:
          'после сведения журнал обязан показывать пересчитанное: иначе '
          'следующая смена стартует с остатка, которого в ящике нет',
    );

    final ops = await db.cashOperationDao.findByState(1);
    expect(
      ops.where((o) => o.amount == d('5')),
      isNotEmpty,
      reason: 'недостача обязана остаться видимой строкой в журнале',
    );
  });
}
