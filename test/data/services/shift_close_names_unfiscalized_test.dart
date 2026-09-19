library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart'
    hide FiscalQueueEntry;
import 'package:telepos/data/fiscal/drift_fiscal_queue_store.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';
import 'package:telepos/data/services/shift_service_impl.dart';
import 'package:telepos/domain/services/shift_service.dart';

/// Закрытие смены **называет** нефискализованные чеки — задача 11, шаг 9.
///
/// # Решение, а не умолчание
///
/// Запретить закрытие было бы хуже беды: кассир не уходит домой, пока
/// кто-то не починит оператора, а деньги уже взяты и товар отдан.
/// Промолчать — тоже: до этой задачи чеки без документа не показывались
/// нигде, и смена закрывалась так, будто их нет. Поэтому закрытие
/// **называет число и номера**.
///
/// # Что здесь настоящее
///
/// База, служба смены, очередь фискализации (`DriftFiscalQueueStore`) —
/// всё настоящее. Проверяется не «метод позвали», а то, что число и
/// номера **сошлись со строками в базе**, и что списанная рукой строка в
/// это число не входит.
void main() {
  late AppDatabase db;
  late ShiftServiceImpl shifts;
  late DriftFiscalQueueStore store;
  late _Capturing observed;

  Decimal d(String v) => Decimal.parse(v);

  FiscalQueueEntry row(int receiptNo, {Map<String, dynamic>? writeOff}) =>
      FiscalQueueEntry(
        idempotencyKey: 'sale-$receiptNo-1',
        opType: FiscalQueueOp.sale,
        payload: {
          'idempotencyKey': 'sale-$receiptNo-1',
          'localOperationId': receiptNo,
          'positions': [
            {'name': 'Хлеб', 'quantity': '1', 'price': '500'},
          ],
          if (writeOff != null) FiscalQueueEntry.kWriteOffKey: writeOff,
        },
        occurredAt: DateTime.now(),
        status: FiscalQueueStatus.failed,
        lastError: 'Касса заблокирована',
      );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    observed = _Capturing();
    final logger = Talker(observer: observed);
    store = DriftFiscalQueueStore(db);

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<FiscalQueueStore>(store);

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

  test('сводка считает строки очереди и называет номера чеков', () async {
    await store.enqueue(row(101));
    await store.enqueue(row(102));

    final summary = await shifts.unfiscalizedAtClose();

    expect(summary.count, 2);
    expect(summary.receiptNumbers, containsAll(<int>[101, 102]));
    expect(summary.isEmpty, isFalse);
  });

  test('списанная рукой строка в число не входит', () async {
    await store.enqueue(row(101));
    await store.enqueue(
      row(
        102,
        writeOff: const {
          'at': '2026-09-08T10:00:00.000',
          'by': 'Айгуль',
          'reason': 'проведён вручную',
        },
      ),
    );

    final summary = await shifts.unfiscalizedAtClose();

    expect(
      summary.count,
      1,
      reason: 'разобранная строка не зовёт человека второй раз',
    );
    expect(summary.receiptNumbers, [101]);
  });

  test('закрытие смены называет число и номера в журнале', () async {
    await store.enqueue(row(101));
    await store.enqueue(row(102));

    await shifts.onCloseShift(d('5000'));

    final named = observed.errors.where(
      (line) => line.contains('нефискализованными чеками'),
    );
    expect(
      named,
      isNotEmpty,
      reason: 'смену закрыть можно, но не молча — задача 11, шаг 9',
    );
    expect(named.single, contains('2 шт.'));
    expect(named.single, contains('101'));
    expect(named.single, contains('102'));

    // Смена всё-таки закрыта: запрет был бы хуже беды.
    final shift = await db.shiftDao.findOpenedShift();
    expect(shift, isNull);
  });

  test('без нефискализованных чеков закрытие молчит', () async {
    await shifts.onCloseShift(d('5000'));

    expect(
      observed.errors.where((l) => l.contains('нефискализованными чеками')),
      isEmpty,
      reason: 'предупреждение на пустом месте обесценивает предупреждение',
    );
  });

  test('очередь кассе не собрана — сводка пуста, а не выдумана', () async {
    await GetIt.I.unregister<FiscalQueueStore>();

    final summary = await shifts.unfiscalizedAtClose();

    expect(summary, same(UnfiscalizedAtClose.empty));
  });
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
