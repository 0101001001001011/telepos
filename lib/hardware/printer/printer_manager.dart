import 'dart:typed_data';

import 'package:telepos/hardware/printer/text_formatter.dart';

abstract class PrinterManager {
  Future<PrinterConnectionResult> connect();

  Future<void> disconnect();

  bool get isConnected;

  Future<PrinterStatus> getStatus();

  /// Отдаёт [data] принтеру, **подключаясь сам, если соединения нет**.
  ///
  /// Подключение — часть записи, а не обязанность вызывающего, и это не вкус.
  /// Пока вызывающий подключался отдельно (`printToBoundPrinter` звал
  /// [connect] перед [printReceipt]), одна отправка на сетевом проводе стоила
  /// **два** срока `WifiPrinterManager.retryBudget`: свой у [connect] и ещё
  /// один внутри [writeRaw], который на неподключённом принтере соединяется
  /// заново. Опубликованная граница очереди («четыре отправки, не больше 17 с»
  /// — `PrintQueueLocal.defaultMaxAttemptsPerOpportunity`) считалась по одному
  /// сроку и потому была занижена вдвое: измерено 27 с там, где написано 17.
  /// Число, выглядящее точным и неверное, хуже отсутствующего — по нему
  /// планируют.
  ///
  /// Отсюда правило: **срок записи один, и он принадлежит [writeRaw]**. Каждая
  /// реализация обязана либо соединяться внутри (сеть и Linux делают это в
  /// пределах своего `retryBudget`), либо позвать [connect] первой же строкой
  /// (последовательный порт Windows, Bluetooth, mock — у их подключения своего
  /// бюджета нет). Реализация, отвечающая «принтер не подключен» на первой
  /// записи после запуска, не печатала бы никогда.
  ///
  /// **Полезная нагрузка уходит не более одного раза за вызов.** Повторяется
  /// только *соединение*: соединение, которое не удалось, ничего не
  /// напечатало. Повтор задания — дело очереди, потому что ключ
  /// идемпотентности живёт там (И29).
  Future<PrintResult> writeRaw(Uint8List data);

  Future<PrintResult> printText(String text);

  Future<PrintResult> printReceipt(Uint8List receiptData);

  Future<void> openCashDrawer();

  Future<void> cutPaper();

  Future<void> feedLines(int lines);

  Future<void> initialize();
}

class PrinterAutoDetectResult {
  const PrinterAutoDetectResult({
    required this.found,
    this.connectionType,
    this.address,
    this.label,
    this.note,
  });

  final bool found;

  final String? connectionType;

  final String? address;

  final String? label;

  final String? note;
}

class PrinterConnectionResult {
  const PrinterConnectionResult({
    required this.success,
    this.errorMessage,
    this.printerInfo,
  });

  final bool success;

  final String? errorMessage;

  final PrinterInfo? printerInfo;

  factory PrinterConnectionResult.ok(PrinterInfo info) {
    return PrinterConnectionResult(success: true, printerInfo: info);
  }

  factory PrinterConnectionResult.error(String message) {
    return PrinterConnectionResult(success: false, errorMessage: message);
  }
}

class PrinterInfo {
  const PrinterInfo({
    required this.name,
    required this.address,
    this.model,
    this.serialNumber,
    this.firmware,
    this.paperWidth = 58,
  });

  final String name;

  final String address;

  final String? model;

  final String? serialNumber;

  final String? firmware;

  final int paperWidth;

  int get charWidth => paperWidth == 58 ? 32 : 42;

  @override
  String toString() => 'PrinterInfo($name @ $address)';
}

class PrinterStatus {
  const PrinterStatus({
    required this.isOnline,
    required this.isPaperPresent,
    required this.isCoverClosed,
    this.errorCode,
    this.errorMessage,
  });

  final bool isOnline;

  final bool isPaperPresent;

  final bool isCoverClosed;

  final int? errorCode;

  final String? errorMessage;

  bool get isReady => isOnline && isPaperPresent && isCoverClosed;

  static const PrinterStatus ok = PrinterStatus(
    isOnline: true,
    isPaperPresent: true,
    isCoverClosed: true,
  );

  static const PrinterStatus offline = PrinterStatus(
    isOnline: false,
    isPaperPresent: false,
    isCoverClosed: false,
    errorMessage: 'Принтер недоступен',
  );

  @override
  String toString() {
    if (isReady) return 'PrinterStatus.ready';
    return 'PrinterStatus(online: $isOnline, paper: $isPaperPresent, cover: $isCoverClosed)';
  }
}

class PrintResult {
  const PrintResult({required this.success, this.errorMessage, this.bytesSent});

  final bool success;

  final String? errorMessage;

  final int? bytesSent;

  factory PrintResult.ok({int? bytesSent}) {
    return PrintResult(success: true, bytesSent: bytesSent);
  }

  factory PrintResult.error(String message) {
    return PrintResult(success: false, errorMessage: message);
  }

  @override
  String toString() {
    if (success) return 'PrintResult.ok(bytes: $bytesSent)';
    return 'PrintResult.error($errorMessage)';
  }
}

/// Отказ команды принтера, у которой в контракте нет места для результата.
///
/// [PrinterManager.initialize], [PrinterManager.cutPaper],
/// [PrinterManager.openCashDrawer] и [PrinterManager.feedLines] возвращают
/// `Future<void>`, и до 2026-07-31 они молча выбрасывали [PrintResult] неудачной
/// записи. Отказ, стёртый в значение, которое никто не читает, — это ровно тот
/// класс дефекта, из-за которого чек считался напечатанным, когда его не было.
/// Раз результат вернуть некуда, отказ выбрасывается.
class PrinterCommandException implements Exception {
  const PrinterCommandException(this.message);

  final String message;

  @override
  String toString() => 'PrinterCommandException: $message';
}

/// Общая часть транспортов ESC/POS: собирает команду и отдаёт её [writeRaw].
///
/// ## Почему здесь больше нет буфера
///
/// До 2026-07-31 каждая операция складывала байты в общий `EscPosBuffer` на
/// **1000 байт**, и `addAll` бросал `BufferOverflowException` *до того, как
/// что-либо добавил*, если полезная нагрузка не помещалась целиком.
/// `printReceipt` этот отказ ловил и возвращал ошибку — с пустым буфером, то
/// есть **до принтера не доходило ни одного байта**. Это не обрезанный чек, это
/// отсутствие чека. Измерено на настоящем пути продажи: пять позиций без QR —
/// 964 байта (запас 36); шестая позиция — 1020; те же пять позиций с фискальным
/// QR, который включён по умолчанию, — 1167. То есть обычный фискальный чек не
/// печатался, а деньги были уже взяты.
///
/// Развилка была из двух: пропускать длинную нагрузку через буфер кусками или
/// убрать буфер с дороги готового документа. Выбрано второе, и вот почему
/// куски здесь неверны:
///
/// * **И29 — задание неделимо.** Один чек — одна запись. Разбив его на N
///   вызовов [writeRaw], мы получаем N независимо падающих записей вместо
///   одной: середина ушла, хвост нет, и напечатана половина чека.
/// * **Транспорт обязан отдавать нагрузку не более одного раза.**
///   `WifiPrinterManager.writeRaw` описывает это прямо: TCP не говорит, сколько
///   байтов дошло до бумаги, поэтому повтор нагрузки печатает хвост чека, а
///   следом целый чек. Кусок, упавший посередине, повторить нельзя — и целиком
///   задание уже не собрать.
/// * **Замок на сокете берётся на один [writeRaw].** В `WifiPrinterManager` он
///   отпускается между вызовами, так что между кусками одного чека может
///   вклиниться опрос состояния или чужое задание — то самое перемешивание
///   чеков, которое раздел 8 архитектуры запрещает.
/// * **Продолжить прерванную запись умеет только один из двух проводов.**
///   На последовательном и USB-пути устройство сообщает, сколько байтов оно
///   приняло, и остаток дописывается — это продолжение того же потока. У сети
///   такого сигнала нет вовсе: `WifiPrinterManager` может лишь сообщить об
///   отказе и никогда не повторяет нагрузку. Разбиение на куски опиралось бы
///   на знание о том, где запись оборвалась, а на сетевом принтере — том
///   самом, который обязателен в мультикассовой установке (И28), — этого
///   знания нет.
///
/// ## Сколько записей на одно задание
///
/// **Ровно одна.** [printReceipt] — это один [writeRaw], чем бы ни был размер
/// документа; ветки, которая делила бы нагрузку, здесь нет. Это важно за
/// пределами файла: `PrintQueueLocal` считает свой срок как «четыре попытки ×
/// одна отправка × срок провода = не больше 17 с по Wi-Fi и 19 с по
/// USB/serial», и арифметика опирается именно на это — а вместе с ней на то,
/// что подключение входит в [writeRaw] и отдельного срока не стоит. Появись
/// здесь разбиение или отдельный `connect()` у вызывающего — число очереди
/// стало бы неверным, оставаясь на вид точным. Однажды так и было: пока
/// `printToBoundPrinter` подключался сам, попытка стоила два срока, и
/// написанные 17 секунд были измеренными 27.
///
/// Отдельно: `initialize()` и `printReceipt()`, вызванные подряд
/// (`print_utility.testPrint`), — это две записи, но это две команды, а не
/// одно задание. Чек продажи, приходящий из очереди, идёт одной.
///
/// Буфер при этом не выполнял и своей заявленной работы: `printReceipt`
/// складывал в него нагрузку и тут же сбрасывал, а `printText` при коротком
/// тексте не сбрасывал **никогда** и возвращал `PrintResult.ok` с числом
/// байтов, которые остались лежать в оперативной памяти. Поэтому
/// `esc_pos_buffer.dart` удалён целиком, а не расширен.
///
/// Имя класса осталось прежним: переименование задевает
/// `lib/app/di/hardware_module.dart`, который в этой задаче принадлежит другому
/// исполнителю. Названо в отчёте, а не умолчано.
abstract class BufferedPrinterManager implements PrinterManager {
  BufferedPrinterManager();

  /// Наибольшее задание, которое драйвер вообще берётся отдать принтеру.
  ///
  /// Это **не** предел протокола: ESC/POS никакого потолка не требует, и чек
  /// любой правдоподобной длины уходит одной записью. Это защита от документа,
  /// который не мог получиться из продажи.
  ///
  /// Число выведено из бумаги, а не из вкуса — вкусом было прежнее «1000», и
  /// стоило оно того, что обычный фискальный чек не печатался. Самый длинный
  /// рулон, встречающийся в чековых принтерах, — 80 м. При межстрочном
  /// интервале по умолчанию (30 точек при 203 dpi = 3,75 мм) это около 21 000
  /// строк, а строка чека вместе с командами выравнивания и жирности стоит
  /// порядка 50 байт. Целый рулон — примерно 1 МиБ. Задание крупнее — это не
  /// длинный чек, это ошибка формирования, и печать его извела бы весь рулон
  /// до того, как кто-нибудь заметил.
  ///
  /// Превышение **сообщается**: [printReceipt] возвращает [PrintResult.error] с
  /// размером, пределом и причиной, очередь печати записывает эту причину в
  /// задание, и оператор видит её на экране. Ни один байт при этом не уходит.
  static const int maxJobBytes = 1024 * 1024;

  final _formatter = TextFormatter();

  Future<PrinterAutoDetectResult> autoDetect() async =>
      const PrinterAutoDetectResult(found: false);

  @override
  Future<PrintResult> printText(String text) async {
    final Uint8List commands;
    try {
      commands = _formatter.format(text);
    } catch (e) {
      return PrintResult.error('Ошибка форматирования: $e');
    }
    return _send(commands, 'печать текста');
  }

  @override
  Future<PrintResult> printReceipt(Uint8List receiptData) =>
      _send(receiptData, 'печать чека');

  @override
  Future<void> initialize() =>
      _sendCommand(EscPosCommands.init, 'инициализация принтера');

  @override
  Future<void> cutPaper() =>
      _sendCommand(EscPosCommands.cutPaperPartialEscI, 'рез бумаги');

  @override
  Future<void> openCashDrawer() =>
      _sendCommand(EscPosCommands.openDrawer, 'открытие денежного ящика');

  @override
  Future<void> feedLines(int lines) =>
      _sendCommand(EscPosCommands.feedLines(lines), 'протяжка бумаги');

  /// Отдаёт [bytes] транспорту **одним вызовом** [writeRaw].
  ///
  /// Ничего не накапливает и ничего не делит: то, что пришло сюда, — это
  /// готовый документ или готовая команда, и делимости у неё нет (И29).
  Future<PrintResult> _send(List<int> bytes, String what) {
    if (bytes.isEmpty) return Future.value(PrintResult.ok(bytesSent: 0));

    if (bytes.length > maxJobBytes) {
      return Future.value(
        PrintResult.error(
          'Задание «$what» размером ${bytes.length} байт не отправлено: '
          'предел одного задания — $maxJobBytes байт, это больше целого рулона '
          'бумаги. Документ такой длины — не чек, а ошибка его формирования',
        ),
      );
    }

    return writeRaw(bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
  }

  /// То же для команд, у которых в контракте нет места для результата.
  ///
  /// Отказ выбрасывается, а не теряется: см. [PrinterCommandException].
  Future<void> _sendCommand(List<int> bytes, String what) async {
    final result = await _send(bytes, what);
    if (!result.success) {
      throw PrinterCommandException(
        result.errorMessage ??
            'Команда «$what» не выполнена, причина не '
                'названа',
      );
    }
  }
}

class EscPosCommands {
  EscPosCommands._();

  static const List<int> init = [0x1B, 0x40, 0x1B, 0x74, 17];

  static const List<int> selectCp866 = [0x1B, 0x74, 17];

  static const List<int> alignLeft = [0x1B, 0x61, 0x00];

  static const List<int> alignCenter = [0x1B, 0x61, 0x01];

  static const List<int> alignRight = [0x1B, 0x61, 0x02];

  static const List<int> sizeNormal = [0x1D, 0x21, 0x00];

  static const List<int> sizeDoubleWidth = [0x1D, 0x21, 0x10];

  static const List<int> sizeDoubleHeight = [0x1D, 0x21, 0x01];

  static const List<int> sizeDouble = [0x1D, 0x21, 0x11];

  static const List<int> boldOn = [0x1B, 0x45, 0x01];

  static const List<int> boldOff = [0x1B, 0x45, 0x00];

  static const List<int> underlineOn = [0x1B, 0x2D, 0x01];

  static const List<int> underlineOff = [0x1B, 0x2D, 0x00];

  static const List<int> italicOn = [0x1B, 0x2D, 0x01];

  static const List<int> italicOff = [0x1B, 0x2D, 0x00];

  static const List<int> inverseOn = [0x1D, 0x42, 0x01];

  static const List<int> inverseOff = [0x1D, 0x42, 0x00];

  static const List<int> newLine = [0x0A];

  /// `GS V 1` — **частичный** рез: остаётся одна точка, чек висит на ленте.
  ///
  /// Имя ничего не обещает про полноту реза, и это верно: рез действительно
  /// частичный. См. соседнюю константу — там имя обещало обратное.
  static const List<int> cutPaper = [0x1D, 0x56, 0x01];

  /// `ESC i` — **тоже частичный** рез (остаётся одна точка), по спецификации
  /// Epson.
  ///
  /// Раньше называлась `cutPaperFull`, то есть имя обещало ровно
  /// противоположное тому, что делает команда. Это тот же класс дефекта, что
  /// поле, хранившее число символов под именем, читавшимся как миллиметры, — он
  /// стоил проекту недели.
  ///
  /// **Исправлено имя, а не байты, и это выбор.** Полный рез — `GS V 0`
  /// (`[0x1D, 0x56, 0x00]`), и его здесь намеренно нет. `ESC i` проверен на
  /// установленных принтерах: бумага режется. Заменить байты значило бы
  /// поменять физическое поведение у каждого клиента ради того, чтобы сойтись с
  /// неверным именем, и объявить проверенным то, что вживую никто не смотрел.
  /// Полного реза продукт нигде и не просил: в кассе частичный удобнее — чек не
  /// падает на пол, покупатель его отрывает.
  static const List<int> cutPaperPartialEscI = [0x1B, 0x69];

  static const List<int> openDrawer = [0x1B, 0x70, 0x00, 0x14, 0x19];

  static const List<int> openDrawer2 = [0x1B, 0x70, 0x01, 0x14, 0x19];

  static const List<int> beep = [0x1B, 0x42, 0x03, 0x02];

  static List<int> feedLines(int n) => [0x1B, 0x64, n];

  static List<int> qrCode(String data, {int moduleSize = 6}) {
    if (data.isEmpty) return const [];
    final bytes = <int>[];
    final dataBytes = data.codeUnits;

    bytes.addAll([0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);

    final size = moduleSize.clamp(1, 16);
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, size]);

    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]);

    final storeLen = dataBytes.length + 3;
    bytes.addAll([
      0x1D,
      0x28,
      0x6B,
      storeLen & 0xFF,
      (storeLen >> 8) & 0xFF,
      0x31,
      0x50,
      0x30,
    ]);
    bytes.addAll(dataBytes);

    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);

    return bytes;
  }

  static List<int> lineSpacing(int n) => [0x1B, 0x33, n];

  static const List<int> lineSpacingDefault = [0x1B, 0x32];
}
