/// Журнал очереди печати даёт **касса** — задача 16, круг правки 4.
///
/// # Девятый случай правки, закрытой кодом без пробы
///
/// Круг правки 3 добавил очереди журнал и строку в `print_module.dart`,
/// которая его подставляет. Померено разбором: удаление этой строки
/// оставляло `test/unit/` зелёным (+537). Единственный тест, вообще
/// зовущий `registerPrintQueue`, — `escpos_wire_test.dart` — `Talker` не
/// регистрирует вовсе, а пробы самой очереди строят её руками и **сами**
/// дают ей журнал. То есть проверено было «очередь умеет писать», а не
/// «касса ей об этом сказала».
///
/// Убери одну строку — и продукт вернулся бы туда, где его застал круг
/// правки 3: непредвиденный отказ очереди оставляет кассе одно имя типа
/// исключения и больше нигде ничего.
///
/// # Почему проба поведенческая, а не «поле не пусто»
///
/// Утверждать `_logger != null` значило бы проверить проводку в обход
/// того, ради чего она есть. Здесь поднимается **настоящая** регистрация
/// из `lib/app/di/print_module.dart`, база закрывается у неё под ногами
/// — и проверяется, что запись о беде дошла до журнала кассы.
library;

import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/app/di/print_module.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/print/print_queue_local.dart';
import 'package:telepos/domain/print/print_job.dart';
import 'package:telepos/domain/print/print_queue.dart';

void main() {
  late AppDatabase db;
  late _CapturingLog observed;

  PrintJob jobOf(String id) => PrintJob(
    id: id,
    terminalId: 1,
    posId: 1,
    payloadBytes: Uint8List.fromList(const [0x1B, 0x40]),
    createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
    expiresAt: DateTime.fromMillisecondsSinceEpoch(9000000),
    state: PrintJobState.queued,
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    observed = _CapturingLog();
    GetIt.I
      ..registerSingleton<AppDatabase>(db)
      ..registerSingleton<Talker>(Talker(observer: observed));
    registerPrintQueue(GetIt.I);
  });

  tearDown(() async {
    await GetIt.I.reset();
    try {
      await db.close();
    } catch (_) {
      // Проба закрывает базу сама — второе закрытие не беда.
    }
  });

  test('касса даёт очереди свой журнал, и беда в него попадает', () async {
    final queue = GetIt.I<PrintQueue>();
    expect(
      queue,
      isA<PrintQueueLocal>(),
      reason: 'страховка от вырождения: поднята та самая очередь',
    );

    // Хранилище уходит из-под очереди: запись задания бросит, и отказ
    // уйдёт в перехват сдачи.
    //
    // **`close()` как диверсия не годится, и причина не та, что казалась**
    // (уточнено кругом правки 5). Дело не в том, что drift «принимает
    // запись после закрытия»: он **игнорирует `close()` на соединении,
    // которое ещё ни разу не открывалось**, а открывалось оно или нет — в
    // точке вызова не видно. Измерено:
    //
    // | база к моменту `close()` | что делает отправка |
    // | --- | --- |
    // | ни разу не открывалась | принято, ноль записей в журнале |
    // | открывалась хотя бы раз | отказ `StateError`, одна запись |
    //
    // То есть `close()` — ненадёжная диверсия: её действие зависит от
    // невидимого на месте вызова состояния соединения. Для отказа
    // хранилища берётся `DROP TABLE` — он отказывает всегда.
    await db.customStatement('DROP TABLE print_jobs');

    final outcome = await queue.submit(jobOf('sale-1-000042'));

    expect(
      outcome.isRejected,
      isTrue,
      reason: 'страховка от вырождения: хранилище действительно отказало',
    );
    expect(
      observed.errors.where((e) => e.contains('sale-1-000042')),
      isNotEmpty,
      reason:
          'строка `logger:` в print_module.dart — единственное, что связывает '
          'очередь с журналом кассы; без неё отказ не оставляет следа нигде',
    );
  });
}

class _CapturingLog extends TalkerObserver {
  final List<String> errors = [];

  @override
  void onError(TalkerError err) => errors.add(err.generateTextMessage());

  @override
  void onException(TalkerException err) =>
      errors.add(err.generateTextMessage());

  @override
  void onLog(TalkerData log) {
    if (log.logLevel == LogLevel.error) {
      errors.add('${log.generateTextMessage()} ${log.exception ?? ''}');
    }
  }
}
