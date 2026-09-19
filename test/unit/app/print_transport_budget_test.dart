import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/di/print_module.dart';
import 'package:telepos/data/print/print_queue_local.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';

/// **Что стоит одна попытка очереди — в сроках соединения, а не в секундах.**
///
/// Очередь публикует границу: четыре отправки за возможность, отступы 1 + 2 + 4
/// с, итого не больше 4 × `retryBudget` + 7 с
/// ([PrintQueueLocal.defaultMaxAttemptsPerOpportunity]). Вся эта арифметика
/// держится на одном допущении: **одна отправка стоит один срок провода**.
///
/// Допущение однажды не выполнялось, и заметить это можно было только здесь, на
/// шве между DI и драйвером. `printToBoundPrinter` звал `connect()` перед
/// `printReceipt`, а `isConnected` у недоступного принтера ложно **всегда**
/// (`wifi_printer.dart`), так что на каждой попытке платились два срока: свой у
/// `connect()` и ещё один внутри `writeRaw`, который на неподключённом принтере
/// соединяется заново. По Wi-Fi это 4 × 5 + 7 = 27 с вместо написанных 17.
/// Опубликованное число выглядело точным, и по нему планировали.
///
/// **Почему счёт в сроках, а не по часам.** Тест на настоящих 2,5 с был бы
/// медленным и, под `-j 4` на загруженной машине, ещё и ненадёжным. Считается
/// то, что задаёт цену: сколько раз транспорт брался устанавливать соединение.
/// Умножение на длительность срока — арифметика, а не поведение.
void main() {
  late _BudgetPrinter printer;

  setUp(() {
    printer = _BudgetPrinter();
    GetIt.I.registerSingleton<PrinterManager>(printer);
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  group('одна попытка очереди — один срок соединения', () {
    test('недоступный принтер: транспорт соединяется ровно один раз', () async {
      final result = await printToBoundPrinter(
        GetIt.I,
        payloadBytes: Uint8List.fromList(const [0x1B, 0x40, 0x41]),
      );

      expect(
        result.success,
        isFalse,
        reason: 'принтер недоступен — «ок» здесь был бы закрытым заданием '
            'без бумаги',
      );
      expect(
        printer.connectionBudgetsSpent,
        1,
        reason:
            'два срока на одну попытку — это опубликованная граница очереди, '
            'заниженная вдвое: 4 × 2,5 + 7 = 17 с превращаются в 4 × 5 + 7 = '
            '27 с, и число остаётся на вид точным',
      );
      expect(
        printer.writes,
        1,
        reason: 'полезная нагрузка уходит не более одного раза за отправку',
      );
    });

    // Задача 33: имя и довод говорили об операторе и `PrintJob.failureReason`
    // — это `PrintQueueLocal` (`lib/data/print/print_queue_local.dart`,
    // `started.failWith(result.errorMessage)`), который здесь не исполняется.
    // Проверяется `errorMessage` результата печати.
    test('причина отказа печати приходит от записи, а не от подключения', () async {
      final result = await printToBoundPrinter(
        GetIt.I,
        payloadBytes: Uint8List.fromList(const [0x1B, 0x40]),
      );

      expect(
        result.errorMessage,
        _BudgetPrinter.writeFailure,
        reason:
            'причина от подключения назвала бы шаг, который к бумаге не '
            'ведёт',
      );
    });

    test('четыре попытки возможности стоят четыре срока, а не восемь', () async {
      for (var i = 0; i < PrintQueueLocal.defaultMaxAttemptsPerOpportunity; i++) {
        await printToBoundPrinter(
          GetIt.I,
          payloadBytes: Uint8List.fromList(const [0x1B, 0x40]),
        );
      }

      expect(
        printer.connectionBudgetsSpent,
        PrintQueueLocal.defaultMaxAttemptsPerOpportunity,
        reason:
            'по этому числу считается опубликованная граница: 17 с по Wi-Fi '
            '(2500 мс × 4 + 7 с) и 19 с по USB/serial (3000 мс × 4 + 7 с)',
      );
    });
  });
}

/// Недоступный принтер, который **считает свои сроки соединения**.
///
/// Ведёт себя как живой недоступный провод, а не как удобная заглушка:
/// [isConnected] ложно всегда (полуоткрытого сокета не бывает у принтера,
/// которого нет), [connect] тратит срок и отказывает, [writeRaw] соединяется
/// сам — как того требует контракт `PrinterManager.writeRaw` — и тоже тратит
/// срок. Принтер, у которого `isConnected` истинно, сделал бы эту проверку
/// зелёной при любой реализации транспорта, то есть бессмысленной.
class _BudgetPrinter extends BufferedPrinterManager {
  static const String connectFailure = 'Принтер 10.0.0.9:9100 не отвечает';
  static const String writeFailure =
      'Не удалось напечатать на 10.0.0.9:9100 — принтер не отвечает';

  /// Сколько раз транспорт брался устанавливать соединение. Это и есть цена
  /// попытки: каждый заход стоит целый `retryBudget` провода.
  int connectionBudgetsSpent = 0;

  int writes = 0;

  @override
  bool get isConnected => false;

  @override
  Future<PrinterConnectionResult> connect() async {
    connectionBudgetsSpent++;
    return PrinterConnectionResult.error(connectFailure);
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<PrinterStatus> getStatus() async => PrinterStatus.offline;

  @override
  Future<PrintResult> writeRaw(Uint8List data) async {
    writes++;
    // Подключение — часть записи (контракт `PrinterManager.writeRaw`), и на
    // живых проводах оно делит с ней один срок.
    connectionBudgetsSpent++;
    return PrintResult.error(writeFailure);
  }
}
