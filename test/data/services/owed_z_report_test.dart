/// Задержанный Z-отчёт **досылается**, и досылается в своё окно — через
/// эмулятор WebKassa на настоящем сокете.
///
/// # Что мерялось и что чинится
///
/// Ревизия 2026-09-19, беда 2. Закрытие смены с той же даты не отправляет
/// Z, пока документы смены не у оператора, — и это верно: отчёт, ушедший
/// раньше них, поставил бы вчерашнюю выручку в сегодняшний отчёт
/// оператора. Хвост остался: **досылать задержанный Z было некому**.
/// Хранилища «Z должен» не существовало вовсе, отчёт посылало только
/// следующее закрытие смены, а смена оператора старше суток отвечает
/// кодом 12 на первой продаже следующего дня.
///
/// # Почему через сокет, а не списком вызовов
///
/// Соседняя проба (`shift_close_waits_for_fiscal_queue_test`) меряет
/// **порядок вызовов** подставным оператором, и для своего вопроса это
/// верно. Здесь вопрос другой и списком не меряется: «не захватил ли
/// вчерашний отчёт сегодняшние документы». Ответ на него знает только
/// оператор — он считает документы своей смены сам, — и читается он из
/// тела ответа `/api/v4/ZReport`, а не из нашего намерения. Поэтому
/// оператор здесь настоящий эмулятор на сокете, а подставлена только
/// `FiscalService`: она тут посредник, а не предмет проверки, и её
/// `closeShift` ходит в тот же сокет тем же `WebKassaProvider`.
///
/// # Чего эти пробы НЕ доказывают
///
/// * Что настоящая WebKassa считает смену так же, как эмулятор. Его
///   арифметика снята с нашего понимания протокола — общее ограничение
///   всех проб этой линии.
/// * Что код 12 больше не случится: при операторе, недоступном и утром,
///   долг остаётся висеть. Доказывается, что он **записан, назван и будет
///   погашен сам**, а не потерян молча.
/// * Что долг переживает перезапуск **процесса**: база здесь в памяти.
///   Проверяется, что он живёт в базе, а не в экземпляре службы, — новая
///   служба над той же базой его видит.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart' hide FiscalQueueEntry;
import 'package:telepos/data/fiscal/drift_fiscal_queue_store.dart';
import 'package:telepos/data/fiscal/fiscal_replay_scheduler.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';
import 'package:telepos/data/services/shift_service_impl.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';

import '../fiscal/support/webkassa_rig.dart';

void main() {
  late WebKassaRig rig;
  late AppDatabase db;
  late DriftFiscalQueueStore store;
  late OfflineQueueingProvider queued;
  late ShiftServiceImpl shifts;
  late Talker logger;

  Decimal d(String v) => Decimal.parse(v);

  /// Строка очереди ровно того вида, какой кладёт `OfflineQueueingProvider`.
  FiscalQueueEntry saleRow(String key, {String amount = '100'}) {
    final req = rigSale(key, amount: amount);
    return FiscalQueueEntry(
      idempotencyKey: key,
      opType: FiscalQueueOp.sale,
      payload: req.toJson(),
      occurredAt: req.occurredAt,
    );
  }

  Future<void> openTillShift() async {
    await db
        .into(db.shifts)
        .insert(
          ShiftsCompanion(
            userId: const Value(4),
            openTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
            isOpened: const Value(true),
            isSynced: const Value(false),
          ),
        );
  }

  /// Пути, дошедшие до оператора, в порядке прихода. Записи пульта
  /// (`/_emul/*`) в журнал не попадают, а `delayed` здесь не бывает.
  List<String> hits() => [for (final e in rig.state.journal) e.path];

  Map<String, Object?>? zResponse() {
    for (final e in rig.state.journal) {
      if (e.path == '/api/v4/ZReport' && e.outcome == 'ok') {
        return (e.response['Data'] as Map?)?.cast<String, Object?>() ??
            e.response;
      }
    }
    return null;
  }

  setUp(() async {
    rig = await startWebKassaRig();
    await rig.warm();

    db = AppDatabase.forTesting(NativeDatabase.memory());
    logger = Talker(settings: TalkerSettings(enabled: false));
    store = DriftFiscalQueueStore(db);
    queued = OfflineQueueingProvider(
      inner: rig.provider,
      store: store,
      isReachable: () async => true,
    );

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<FiscalQueueStore>(store);
    GetIt.I.registerSingleton<FiscalService>(_SocketFiscal(rig));
    GetIt.I.registerSingleton<FiscalReplayScheduler>(
      FiscalReplayScheduler(
        resolve: () async => queued,
        isShiftOpen: () async {
          final shift = await db.shiftDao.findOpenedShift();
          return shift != null && shift.isOpened;
        },
        logger: logger,
      ),
    );

    await db
        .into(db.users)
        .insert(const UsersCompanion(id: Value(4), name: Value('Айгуль')));
    await openTillShift();

    shifts = ShiftServiceImpl(
      db: db,
      logger: logger,
      flushBudget: const Duration(seconds: 5),
    );
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
    await rig.stop();
  });

  test('Z, задержанный вчера, уходит при открытии смены — и только после документов', () async {
    // --- вчерашний день -------------------------------------------------
    // Один чек доехал живым, второй лёг в очередь: связь оборвалась.
    await queued.fiscalizeSale(rigSale('sale-day1-a', amount: '100'));
    await rig.console('/_emul/kill', {'count': 9});
    await store.enqueue(saleRow('sale-day1-b', amount: '100'));

    final closingShift = (await db.shiftDao.findOpenedShift())!.id;
    await shifts.onCloseShift(d('5000'));

    expect(
      hits(),
      isNot(contains('/api/v4/ZReport')),
      reason: 'документы смены ещё не у оператора — Z уходить не имеет права',
    );
    final owed = await shifts.owedZReport();
    expect(owed, isNotNull, reason: 'отчёт не забыт, а записан долгом');
    expect(owed!.shiftId, closingShift);
    expect(owed.documentsWaiting, 1);

    // Долг живёт в базе, а не в экземпляре службы.
    final another = ShiftServiceImpl(db: db, logger: logger);
    expect((await another.owedZReport())?.shiftId, closingShift);

    // --- утро -----------------------------------------------------------
    await rig.console('/_emul/kill', {'count': 0});
    rig.state.journal.clear();

    await shifts.onOpenShift(4);

    final order = hits();
    // ignore: avoid_print
    print('утро: $order');
    expect(
      order,
      contains('/api/v4/ZReport'),
      reason: 'долг погашен досылкой, а не следующим закрытием смены',
    );
    expect(
      order.indexOf('/api/v4/check'),
      lessThan(order.indexOf('/api/v4/ZReport')),
      reason:
          'вчерашний документ обязан приехать ДО вчерашнего отчёта — иначе '
          'он встанет в сегодняшнюю смену оператора',
    );
    expect(await shifts.owedZReport(), isNull, reason: 'долг погашен');
    expect(await store.pendingCount(), 0);

    // --- Z посчитал вчерашнее и только вчерашнее ------------------------
    final z = zResponse();
    expect(z, isNotNull);
    expect(
      z!['ControlSum'],
      '200',
      reason: 'оба вчерашних чека по 100 — и ни одного сегодняшнего',
    );
    final zShift = z['ShiftNumber'];

    // Сегодняшняя продажа попадает уже в НОВУЮ смену оператора.
    await queued.fiscalizeSale(rigSale('sale-day2-a', amount: '777'));
    expect(
      rig.state.cashboxes[kRigCashbox]!.shiftNumber,
      greaterThan(zShift as int),
    );
    expect(rig.state.cashboxes[kRigCashbox]!.sellTotal, d('777'));
  });

  test('оператор недоступен и утром: долг остаётся, попытка сосчитана', () async {
    await rig.console('/_emul/kill', {'count': 99});
    await store.enqueue(saleRow('sale-day1-b'));
    await shifts.onCloseShift(d('5000'));
    expect(await shifts.owedZReport(), isNotNull);

    rig.state.journal.clear();
    await shifts.onOpenShift(4);

    expect(
      hits(),
      isNot(contains('/api/v4/ZReport')),
      reason: 'вчерашний документ не доехал — отчёт по-прежнему ждёт его',
    );
    final owed = await shifts.owedZReport();
    expect(owed, isNotNull);
    expect(owed!.attempts, 1, reason: 'попытка названа, а не забыта');
    expect(owed.lastError, contains('не доехали'));
    // Касса при этом открыта и работает: запирать её из-за вчерашнего
    // отчёта нельзя.
    expect((await db.shiftDao.findOpenedShift())?.isOpened, isTrue);
  });

  test('второй долг поверх первого не заводится — смена оператора одна', () async {
    await rig.console('/_emul/kill', {'count': 99});
    await store.enqueue(saleRow('sale-day1-b'));
    await shifts.onCloseShift(d('5000'));
    final first = await shifts.owedZReport();

    await openTillShift();
    await store.enqueue(saleRow('sale-day2-b'));
    await shifts.onCloseShift(d('5000'));

    final rows = await db.select(db.fiscalOwedReports).get();
    expect(
      rows.where((r) => r.settledAt == null),
      hasLength(1),
      reason: 'один незакрытый отчёт оператора — один долг',
    );
    expect((await shifts.owedZReport())!.shiftId, first!.shiftId);
  });

  test('Z следующего закрытия гасит долг — след остаётся', () async {
    await rig.console('/_emul/kill', {'count': 99});
    await store.enqueue(saleRow('sale-day1-b'));
    await shifts.onCloseShift(d('5000'));
    expect(await shifts.owedZReport(), isNotNull);

    // Оператор вернулся; следующая смена закрывается с пустой очередью.
    // Строка вчерашнего дня разобрана человеком (экран нефискализованных
    // чеков) — здесь это просто её отсутствие в очереди.
    await rig.console('/_emul/kill', {'count': 0});
    await store.remove('sale-day1-b');
    await openTillShift();
    // Живой чек открывает смену оператора: Z по закрытой смене ответил бы
    // кодом 13, и проба мерила бы отказ, а не погашение.
    await queued.fiscalizeSale(rigSale('sale-day2-a'));
    await shifts.onCloseShift(d('5000'));

    expect(hits(), contains('/api/v4/ZReport'));
    expect(await shifts.owedZReport(), isNull);
    final rows = await db.select(db.fiscalOwedReports).get();
    expect(
      rows,
      hasLength(1),
      reason: 'погашенная строка не удаляется: у расхождения остаётся след',
    );
    expect(rows.single.settledBy, contains('закрытия смены'));
  });

  test('долга нет — открытие смены оператора не трогает', () async {
    rig.state.journal.clear();
    await shifts.onOpenShift(4);

    expect(
      hits(),
      isEmpty,
      reason:
          'досылка на пустом месте послала бы Z за смену, которой не было, '
          'и закрыла бы сегодняшнюю',
    );
  });
}

/// Служба фискализации, чей `closeShift` идёт в **настоящий сокет**
/// эмулятора тем же `WebKassaProvider`, что и вся касса.
///
/// Подставлена именно она, а не провайдер: здесь она посредник между
/// службой смены и оператором, и её собственного поведения проба не
/// проверяет. Всё, что ниже неё, — настоящее.
class _SocketFiscal extends RefusingFiscalService {
  _SocketFiscal(this.rig);

  final WebKassaRig rig;

  @override
  Future<bool> isEnabled() async => true;

  @override
  Future<FiscalResult> openShift() =>
      rig.provider.openShift(const FiscalShiftRequest());

  @override
  Future<FiscalReportResult> closeShift() =>
      rig.provider.closeShift(const FiscalShiftRequest());
}
