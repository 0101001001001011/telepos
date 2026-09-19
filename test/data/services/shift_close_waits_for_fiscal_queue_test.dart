/// Z-отчёт **не обгоняет документы своей смены** — дыра 1 ревизии 2026-09-19.
///
/// # Случай из жизни
///
/// Круг повтора очереди — две минуты (`kFiscalReplayInterval`). Чек, легший
/// в очередь в последние минуты смены, ждёт своего круга; кассир в это время
/// закрывает смену, и Z-отчёт уходит оператору **первым**. Документ приезжает
/// после отчёта — а WebKassa открывает смену неявно, первым документом, —
/// значит вчерашняя выручка встаёт в сегодняшний отчёт. Ни касса, ни оператор
/// этого не заметят: сверять нечем.
///
/// # Что здесь настоящее
///
/// База, служба смены, очередь (`DriftFiscalQueueStore`), обёртка очереди
/// (`OfflineQueueingProvider`) и планировщик повтора — всё настоящее, вплоть
/// до его правила «прохода при закрытой смене кассы не делать». Подставлены
/// двое: сам оператор (`_ScriptedProvider`) и служба фискализации
/// (`_RecordingFiscal`), потому что оба здесь — не предмет проверки, а
/// собеседники.
///
/// Порядок событий пишется в **один** список: и отправка документа, и
/// Z-отчёт. Проверяется именно он — «кто раньше», а не «оба позвались».
///
/// # Чего эти пробы НЕ доказывают
///
/// Что после закрытия все документы смены у оператора. При мёртвом операторе
/// они остаются в очереди — и доказывается ровно то, что Z в этом случае
/// **не уходит**, а смена кассы всё равно закрывается.
library;

import 'dart:async';

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
import 'package:telepos/domain/fiscal/fiscal_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';

void main() {
  late AppDatabase db;
  late ShiftServiceImpl shifts;
  late DriftFiscalQueueStore store;
  late _ScriptedProvider operator_;
  late _RecordingFiscal fiscal;
  late List<String> order;
  late _Capturing observed;

  Decimal d(String v) => Decimal.parse(v);

  FiscalQueueEntry saleRow(int receiptNo) {
    final key = 'sale-1758000000-$receiptNo-1';
    return FiscalQueueEntry(
      idempotencyKey: key,
      opType: FiscalQueueOp.sale,
      payload: {
        'idempotencyKey': key,
        'localOperationId': receiptNo,
        'positions': [
          {'name': 'Хлеб', 'quantity': '1', 'price': '500', 'taxPercent': '12'},
        ],
        'payments': [
          {'kind': 'cash', 'amount': '500'},
        ],
        'occurredAt': DateTime.now().toIso8601String(),
      },
      occurredAt: DateTime.now(),
    );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    order = [];
    observed = _Capturing();
    final logger = Talker(observer: observed);
    store = DriftFiscalQueueStore(db);
    operator_ = _ScriptedProvider(order);
    fiscal = _RecordingFiscal(order);

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<FiscalQueueStore>(store);
    GetIt.I.registerSingleton<FiscalService>(fiscal);
    GetIt.I.registerSingleton<FiscalReplayScheduler>(
      FiscalReplayScheduler(
        // Настоящая обёртка очереди над подставным оператором.
        resolve: () async => OfflineQueueingProvider(
          inner: operator_,
          store: store,
          isReachable: () async => operator_.online,
        ),
        // Настоящее правило планировщика: при закрытой смене кассы прохода
        // не делать. Оно и ловит попытку переставить досылку после записи
        // закрытия.
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

    shifts = ShiftServiceImpl(db: db, logger: logger);
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  test('документ смены уезжает РАНЬШЕ её Z-отчёта', () async {
    await store.enqueue(saleRow(101));

    await shifts.onCloseShift(d('5000'));

    expect(
      order,
      ['продажа sale-1758000000-101-1', 'Z-отчёт'],
      reason:
          'до правки список был ["Z-отчёт"] — документ уезжал своим кругом '
          'через две минуты, уже в следующую смену оператора',
    );
    expect(await store.pendingCount(), 0);
  });

  test(
    'оператор недоступен: Z-отчёт не уходит, смена всё равно закрыта',
    () async {
      operator_.online = false;
      await store.enqueue(saleRow(102));

      await shifts.onCloseShift(d('5000'));

      expect(
        order,
        isEmpty,
        reason:
            'Z, ушедший раньше ждущего документа, поставил бы его в следующую '
            'смену оператора — выручка одного дня в отчёте другого',
      );
      expect(
        await store.pendingCount(),
        1,
        reason: 'документ никуда не делся: он уедет повтором, окно 72 ч',
      );
      // Выход у отказа есть, и он первый по важности: касса не заперта.
      expect(
        await db.shiftDao.findOpenedShift(),
        isNull,
        reason:
            'запрет закрытия был бы хуже беды: кассир не уходит домой, пока '
            'чинят оператора, а деньги уже взяты',
      );
      expect(
        observed.errors.where(
          (l) => l.contains('Z-отчёт оператору НЕ отправлен'),
        ),
        isNotEmpty,
        reason: 'отказ назван причиной, а не молчанием',
      );
    },
  );

  test('очередь пуста — Z уходит, как и прежде', () async {
    await shifts.onCloseShift(d('5000'));

    expect(order, ['Z-отчёт']);
    expect(
      observed.errors.where((l) => l.contains('НЕ отправлен')),
      isEmpty,
      reason: 'предупреждение на пустом месте обесценивает предупреждение',
    );
  });

  test(
    'ждущие документы названы кассиру до закрытия, отдельно от беды',
    () async {
      await store.enqueue(saleRow(103));
      await store.enqueue(
        saleRow(104)
          ..status = FiscalQueueStatus.failed
          ..lastError = 'fiscal(cashboxBlocked#7)',
      );

      final summary = await shifts.unfiscalizedAtClose();

      expect(summary.count, 1, reason: 'беда — только та строка, что failed');
      expect(summary.receiptNumbers, [104]);
      expect(
        summary.onTheWay,
        1,
        reason: 'ждущая строка — не беда, но Z её дожидается',
      );
      expect(summary.onTheWayReceipts, [103]);
      expect(summary.isEmpty, isFalse);
      expect(summary.hasFailed, isTrue);
    },
  );

  test('оператор молчит: закрытие не висит, а укладывается в предел', () async {
    // Оператор, который **не отвечает вовсе** — ни ответом, ни отказом.
    // Так выглядит мёртвая сеть до тайм-аута клиента (30 с), и без предела
    // кассир смотрел бы на кнопку «Закрыть» до полутора минут.
    operator_.hangs = true;
    await store.enqueue(saleRow(106));

    final shifts = ShiftServiceImpl(
      db: db,
      logger: Talker(observer: observed),
      flushBudget: const Duration(milliseconds: 50),
    );

    final started = DateTime.now();
    await shifts.onCloseShift(d('5000'));
    final spent = DateTime.now().difference(started);

    expect(
      spent,
      lessThan(const Duration(seconds: 5)),
      reason:
          'ожидание ограничено (`kShiftCloseFlushBudget`); сам проход '
          'продолжается в фоне',
    );
    expect(
      order,
      isEmpty,
      reason: 'недовезённое считается ждущим — Z не уходит',
    );
    expect(await db.shiftDao.findOpenedShift(), isNull);
  });

  test('строка, застрявшая у оператора отказом, Z не держит', () async {
    // Нетранзиентный отказ: проход переведёт строку в `failed`, и она
    // перестанет быть «ждущей». Держать Z-отчёт из-за неё вечно значило бы
    // запереть отчёты оператора навсегда — лечит её человек, а не время.
    operator_.refusal = FiscalResult.failure(
      'касса заблокирована',
      code: FiscalErrorCode.cashboxBlocked,
    );
    await store.enqueue(saleRow(105));

    await shifts.onCloseShift(d('5000'));

    expect(order, ['продажа sale-1758000000-105-1', 'Z-отчёт']);
    expect(await store.pendingCount(), 0);
    expect((await store.failed()).length, 1);
  });
}

/// Оператор, которого можно выключить и заставить отказать.
class _ScriptedProvider implements FiscalProvider {
  _ScriptedProvider(this.order);

  final List<String> order;
  bool online = true;
  bool hangs = false;
  FiscalResult? refusal;

  Never _never() => throw StateError('этого оператора так не зовут');

  @override
  String get id => 'scripted';

  @override
  FiscalCapabilities get capabilities => const FiscalCapabilities();

  @override
  String? validateConfig(FiscalSettings config) => null;

  @override
  Future<FiscalAuthResult> authorize(FiscalSettings config) async =>
      FiscalAuthResult.ok(token: 'T');

  @override
  Future<FiscalResult> fiscalizeSale(FiscalSaleRequest req) async {
    if (hangs) return Completer<FiscalResult>().future;
    if (!online) {
      return FiscalResult.failure('нет связи', code: FiscalErrorCode.network);
    }
    order.add('продажа ${req.idempotencyKey}');
    return refusal ??
        FiscalResult.ok(fiscalSign: 'SIGN-${req.localOperationId}');
  }

  @override
  Future<FiscalResult> fiscalizeRefund(FiscalRefundRequest req) async =>
      _never();

  @override
  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req) async =>
      _never();

  @override
  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req) async =>
      _never();

  @override
  Future<FiscalResult> moneyIn(FiscalMoneyRequest req) async => _never();

  @override
  Future<FiscalResult> moneyOut(FiscalMoneyRequest req) async => _never();

  @override
  Future<FiscalResult> openShift(FiscalShiftRequest req) async =>
      const FiscalResult(success: true);

  @override
  Future<FiscalReportResult> closeShift(FiscalShiftRequest req) async =>
      _never();

  @override
  Future<FiscalReportResult> xReport(FiscalShiftRequest req) async => _never();

  @override
  Future<FiscalResult> correctionReceipt(FiscalCorrectionRequest req) async =>
      _never();

  @override
  Future<FiscalStatus> getStatus() async => _never();
}

/// Служба фискализации, от которой здесь нужен **один** факт: позвали ли
/// Z-отчёт и когда.
class _RecordingFiscal extends RefusingFiscalService {
  _RecordingFiscal(this.order);

  final List<String> order;

  @override
  Future<bool> isEnabled() async => true;

  @override
  Future<FiscalReportResult> closeShift() async {
    order.add('Z-отчёт');
    return FiscalReportResult(
      result: FiscalResult.ok(fiscalSign: 'Z-1'),
      shiftNumber: 1,
      documentCount: 1,
    );
  }
}

class _Capturing extends TalkerObserver {
  final List<String> errors = [];

  @override
  void onError(TalkerError e) => errors.add(e.displayMessage);

  @override
  void onLog(TalkerData log) {
    if (log.logLevel == LogLevel.error) errors.add(log.displayMessage);
  }
}
