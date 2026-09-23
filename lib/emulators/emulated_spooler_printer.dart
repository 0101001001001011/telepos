import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:telepos/emulators/emulated_device_profile_catalog.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';

/// Печать через спулер операционной системы, у которой отняли спулер и
/// подставили файл.
///
/// Второе из двух семейств, которое **нечем** адресовать: очередь печати
/// выбирается по имени, а не по адресу, и подставить туда чужой процесс
/// нельзя. Сетевой принтер сюда не относится — у него есть `ipAddress`, и он
/// эмулируется настоящим сокетом (`lib/emulators/escpos/emulator.dart`),
/// то есть механизмом «адресом»: подставляется не наш класс, а адрес, куда
/// касса идёт своим `WifiPrinterManager`. С 2026-09-19 тот сокет поднимается
/// и изнутри приложения — точка подстановки от этого не сдвинулась.
///
/// # Что он делает
///
/// Дописывает байты ESC/POS в файл, названный параметром привязки
/// [kEmulatedFileParam]. Файл разбирается и рисуется человеку тем же
/// разборщиком, что и сетевой поток: `dart run
/// test/emulators/escpos/emulator.dart --render <файл>` (обёртка над
/// `lib/emulators/escpos/render.dart`). То есть глаз видит
/// то же, что увидел бы на бумаге, — а не «печать прошла успешно».
///
/// # Что он умеет отказать
///
/// Параметр привязки [kEmulatedRefuseParam] — и это не украшение. До
/// эмулятора ветки `connectionFailed`, `deviceRefused` и `unexpectedError` в
/// `DeviceCheckLocal._checkReceiptPrinter` требовали настоящего принтера с
/// выдернутым кабелем, открытой крышкой и кончившейся бумагой соответственно;
/// ни одна не проходилась ни одной живой проверкой.
///
/// | Значение | Что происходит | Какую ветку продукта открывает |
/// | --- | --- | --- |
/// | `offline` | `connect()` возвращает неудачу | `connectionFailed` |
/// | `outOfPaper` | `getStatus()` без бумаги | `deviceRefused` |
/// | `coverOpen` | `getStatus()` с открытой крышкой | `deviceRefused` |
/// | `writeFails` | `writeRaw()` возвращает ошибку | `deviceRefused` |
/// | `throws` | драйвер выбрасывает исключение | `unexpectedError` |
///
/// Список отказов **наш и выдуманный**: у спулера операционной системы нет
/// протокола, коды которого можно было бы снять с документации. Следствие для
/// продукта прямое — разбор обязан обрабатывать *любую* неудачу, а не наш
/// список.
///
/// # Чего он НЕ доказывает
///
/// * **Что чек напечатан физически.** Бумаги здесь нет; «печать прошла»
///   означает «файл записан».
/// * **Что спулер Windows/CUPS ведёт себя так же** — ни очереди, ни драйвера
///   принтера, ни его собственных тайм-аутов здесь нет.
/// * **Что байты ESC/POS верны для конкретной модели.** Кодовая страница,
///   ширина ленты и реакция на `ESC i` у каждой модели своя.
class EmulatedSpoolerPrinter extends BufferedPrinterManager {
  EmulatedSpoolerPrinter({required this.file, this.refuse = ''});

  /// Файл, в который уходит поток. Родительский каталог создаётся при первой
  /// записи: стенд поднимают в пустом каталоге чаще, чем помнят про `mkdir`.
  final String file;

  /// Названный отказ, пусто — эмулятор работает. См. таблицу в докстринге
  /// класса.
  final String refuse;

  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Future<PrinterConnectionResult> connect() async {
    if (refuse == 'throws') {
      throw StateError('Эмулятор спулера: отказ «throws» при подключении');
    }
    if (refuse == 'offline') {
      _connected = false;
      return PrinterConnectionResult.error(
        'Эмулятор спулера: очередь печати «$file» недоступна (отказ «offline»)',
      );
    }
    _connected = true;
    return PrinterConnectionResult.ok(
      PrinterInfo(name: 'Эмулятор спулера', address: file),
    );
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<PrinterStatus> getStatus() async {
    if (refuse == 'throws') {
      throw StateError('Эмулятор спулера: отказ «throws» при опросе состояния');
    }
    return PrinterStatus(
      isOnline: refuse != 'offline',
      isPaperPresent: refuse != 'outOfPaper',
      isCoverClosed: refuse != 'coverOpen',
      errorMessage: switch (refuse) {
        'outOfPaper' => 'Эмулятор спулера: бумага кончилась',
        'coverOpen' => 'Эмулятор спулера: крышка открыта',
        'offline' => 'Эмулятор спулера: принтер не в сети',
        _ => null,
      },
    );
  }

  @override
  Future<PrintResult> writeRaw(Uint8List data) async {
    if (refuse == 'throws') {
      throw StateError('Эмулятор спулера: отказ «throws» при записи');
    }
    if (refuse == 'writeFails') {
      return PrintResult.error(
        'Эмулятор спулера: задание отвергнуто (отказ «writeFails»)',
      );
    }
    if (!_connected) {
      return PrintResult.error(
        'Эмулятор спулера: запись без подключения — так же, как настоящий '
        'драйвер, эмулятор не открывает очередь сам',
      );
    }
    try {
      final target = File(file);
      await target.parent.create(recursive: true);
      await target.writeAsBytes(data, mode: FileMode.append, flush: true);
      return PrintResult.ok(bytesSent: data.length);
    } catch (e) {
      return PrintResult.error(
        'Эмулятор спулера: запись в «$file» не удалась: $e',
      );
    }
  }
}
