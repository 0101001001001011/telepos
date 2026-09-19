import 'dart:typed_data';

import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/print/print_job_store_drift.dart';
import 'package:telepos/data/print/print_queue_local.dart';
import 'package:telepos/domain/print/print_job_store.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';

/// Регистрирует хранилище заданий печати и очередь.
///
/// **Ровно один экземпляр очереди на процесс, и это существенно.** Вся
/// неделимость задания держится на том, что писатель в принтер один
/// (`PrintQueueLocal._running`). Второй экземпляр очереди — это второй
/// писатель, то есть перемешанные чеки, и никакой замок внутри драйвера этого
/// не исправит: он охраняет сокет, а не задания. Поэтому очередь строится
/// здесь и только здесь, а `ReceiptPrintServiceImpl` берёт готовую из DI, а не
/// собирает свою.
///
/// Очередь регистрируется **ленивой**: она заводит таймер пробуждения, как
/// только у неё появляется активное задание, и таймер, заведённый в процессе,
/// который печатать не собирался, — это утечка. Первое обращение приходит либо
/// из печати, либо из [startPrintQueue].
void registerPrintQueue(GetIt getIt) {
  getIt.registerLazySingleton<PrintJobStore>(
    () => DriftPrintJobStore(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<PrintQueue>(
    () => PrintQueueLocal(
      store: getIt<PrintJobStore>(),
      transport: (payloadBytes) =>
          printToBoundPrinter(getIt, payloadBytes: payloadBytes),
      // Журнал: без него непредвиденный отказ очереди оставлял кассе одно
      // имя типа исключения — разбор в докстринге `PrintQueueLocal._logger`.
      logger: getIt.isRegistered<Talker>() ? getIt<Talker>() : null,
    ),
    // Смена длится двенадцать часов; очередь, пережившая свой `GetIt`, уносит
    // с собой таймер пробуждения. `dispose` снимает его и дожидается задания,
    // которое прямо сейчас уходит в принтер, — оборванная на середине запись
    // оставила бы строку в `printing`, из которой задание само не выйдет.
    dispose: (queue) async {
      if (queue is PrintQueueLocal) await queue.dispose();
    },
  );
}

/// Поднимает задания, застигнутые перезапуском программы на середине записи, и
/// берётся за то, что осталось в очереди с прошлого запуска.
///
/// **Зачем отдельная функция, а не строчка в [registerPrintQueue].** Регистрация
/// ленива нарочно (см. выше), поэтому без явного пробуждения задание, лежащее в
/// базе со вчерашнего дня, дождалось бы только следующей продажи: деньги взяты
/// вчера, принтер починили утром, а чек стоит, потому что никто не печатал.
/// Вызывается из фонового старта приложения, который в тестах отключён
/// (`BackgroundTaskManager.disabledForTests`) — иначе каждый виджет-тест,
/// ничего не печатающий, получал бы висящий таймер очереди.
Future<void> startPrintQueue(GetIt getIt, {Talker? logger}) async {
  if (!getIt.isRegistered<PrintQueue>()) return;
  final queue = getIt<PrintQueue>();
  if (queue is! PrintQueueLocal) return;
  try {
    await queue.start();
  } catch (e) {
    logger?.warning('PrintModule: очередь печати не поднялась: $e');
  }
}

/// Единственный путь байтов задания к железу.
///
/// Отсутствие принтера — это **ошибка транспорта, а не успех**: задание
/// остаётся в очереди и напечатается, когда принтер настроят или он вернётся.
/// Ответ `ok` при отсутствующем принтере был бы ровно тем правдоподобно-неверным
/// значением, ради которого очередь и заводилась: задание закрылось бы
/// «напечатанным», а бумаги не было бы.
///
/// **Здесь нет `connect()`, и это исправление, а не упущение.** Пока он здесь
/// стоял, одна отправка на сетевом проводе платила срок соединения дважды: свой
/// у `connect()` (`WifiPrinterManager.retryBudget`, 2500 мс) и ещё один внутри
/// `writeRaw`, который на неподключённом принтере соединяется заново. А
/// `isConnected` у недоступного принтера ложно всегда, так что платилось это на
/// каждой попытке очереди: измерено 27 с на возможность вместо написанных 17.
/// Подключение — часть записи, и правило записано в контракте
/// `PrinterManager.writeRaw`; каждая реализация его соблюдает.
Future<PrintResult> printToBoundPrinter(
  GetIt getIt, {
  required Uint8List payloadBytes,
}) async {
  if (!getIt.isRegistered<PrinterManager>()) {
    return PrintResult.error('На этом терминале не настроен чековый принтер');
  }

  return getIt<PrinterManager>().printReceipt(payloadBytes);
}
