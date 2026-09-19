import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:telepos/domain/device/emulated_scanner_source.dart';
import 'package:telepos/emulators/emulated_device_profile_catalog.dart';

/// HID-сканер, у которого отняли HID и подставили файл.
///
/// Первое из двух семейств, которое **нечем** адресовать: клавиатурный сканер
/// находит сама операционная система, он не слушает порт и не отвечает по
/// сети. Подставить между ним и кассой нечего — поэтому здесь виртуальный
/// профиль, а не адрес и не петля.
///
/// # Как «сканировать»
///
/// Дописать строку в файл, названный параметром привязки
/// [kEmulatedFileParam]:
///
/// ```
/// echo 4870204370014 >> /tmp/telepos/scanner.txt
/// ```
///
/// Каждая новая строка — один скан. Файл читается **с конца**: строки,
/// лежавшие в нём на момент запуска, не «сканируются» задним числом — иначе
/// первый же запуск стенда высыпал бы в кассу весь вчерашний журнал.
///
/// # Отказы
///
/// Параметр привязки [kEmulatedRefuseParam]:
///
/// | Значение | Что происходит |
/// | --- | --- |
/// | `notFound` | файла нет — [start] отдаёт причину, а не молчит |
/// | `unreadable` | чтение падает при каждой попытке |
///
/// **Отказы наши и выдуманные:** у HID-клавиатуры нет протокола с кодами
/// ошибок, которые можно было бы снять с документации. Следствие для
/// продукта: читатель обязан пережить *любую* неудачу источника, а не наш
/// список.
///
/// # Чего он НЕ доказывает
///
/// * **Что сканер прочитал штрихкод** — ни оптики, ни декодера символогии
///   здесь нет; строку назвали руками.
/// * **Что клавиатурный клин работает.** Настоящий сканер идёт через
///   `HardwareKeyboard`, и межсимвольный зазор (`scannerTimeoutMs`) — самая
///   хрупкая часть того пути. Эмулятор отдаёт готовую строку и этот путь
///   **обходит**; проверяется им приёмник штрихкода, а не клин.
/// * **Что правила длины применены.** Их применяет читатель
///   (`barcode_scanner_mixin.dart`), а не источник.
class EmulatedScanner implements EmulatedScannerSource {
  EmulatedScanner({required this.file, this.refuse = '', Duration? poll})
    : _poll = poll ?? const Duration(milliseconds: 200);

  final String file;

  final String refuse;

  final Duration _poll;

  final _controller = StreamController<String>.broadcast();

  Timer? _timer;
  int _offset = 0;
  String _tail = '';

  /// Штрихкоды, «просканированные» с момента [start].
  @override
  Stream<String> get barcodes => _controller.stream;

  bool get isRunning => _timer != null;

  /// Причина отказа, если запуск не удался, иначе `null`.
  ///
  /// Отказ приходит **значением**, а не исключением: источник штрихкодов не
  /// имеет права уронить экран продажи (И144).
  @override
  Future<String?> start() async {
    if (refuse == 'notFound') {
      return 'Эмулятор сканера: файла «$file» нет (отказ «notFound»)';
    }
    final target = File(file);
    if (refuse != 'unreadable') {
      try {
        await target.parent.create(recursive: true);
        if (!await target.exists()) {
          await target.writeAsString('', flush: true);
        }
        _offset = await target.length();
      } catch (e) {
        return 'Эмулятор сканера: файл «$file» не открылся: $e';
      }
    }
    _timer = Timer.periodic(_poll, (_) => unawaited(_tick()));
    return null;
  }

  Future<void> _tick() async {
    if (refuse == 'unreadable') {
      _controller.addError(
        StateError('Эмулятор сканера: чтение «$file» отказано («unreadable»)'),
      );
      return;
    }
    try {
      final target = File(file);
      final length = await target.length();
      if (length < _offset) {
        // Файл усечён (стенд перезапущен) — читаем с начала, а не отдаём
        // мусор из середины строки.
        _offset = 0;
        _tail = '';
      }
      if (length == _offset) return;
      final handle = await target.open();
      try {
        await handle.setPosition(_offset);
        final bytes = await handle.read(length - _offset);
        _offset = length;
        _tail += utf8.decode(bytes, allowMalformed: true);
      } finally {
        await handle.close();
      }
      final parts = _tail.split(RegExp(r'\r?\n'));
      _tail = parts.removeLast();
      for (final line in parts) {
        final code = line.trim();
        if (code.isNotEmpty) _controller.add(code);
      }
    } catch (e) {
      _controller.addError(e);
    }
  }

  /// Дверь остановки. Без неё стенд оставляет за собой висящий таймер, а
  /// после трёх запусков — три читателя одного файла.
  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _controller.close();
  }
}
