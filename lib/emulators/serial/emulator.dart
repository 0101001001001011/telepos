/// Эмулятор весов и дисплея покупателя — приборы, которые говорят по
/// COM-порту.
///
/// # Механизм подстановки: **петля операционной системы**
///
/// Подстановка идёт **адресом**: весы и дисплей адресуются именем порта
/// (`comPort` в привязке устройства), и эмулятор садится на второй конец.
/// Чем бывает этот второй конец:
///
/// * пара виртуальных портов ОС — Windows: com0com, `COM8 ↔ COM9`; касса
///   берёт `COM8`, эмулятор `COM9`. Linux/macOS: `socat -d -d pty,raw,echo=0
///   pty,raw,echo=0` печатает два пути `/dev/pts/N`;
/// * **обычный файл** — с 2026-09-19, когда касса научилась принимать путь
///   файла как порт (`serial_port_path.dart`). Так работает встроенный
///   эмулятор: ставить com0com не нужно. **Цена названа там же:** файл — не
///   поток, у него есть длина и смещение, поэтому обрыв связи и чтение
///   вперёд записи файлом не проверяются. Пара портов ОС остаётся более
///   строгой проверкой, и живые прогоны идут через неё.
///
/// Подставить сюда свой `ScalesService` значило бы снять с проверки ровно
/// то, что вероятнее всего сломано: разбор строки весов. Он уже стоил
/// проекту двух денежных дефектов — потерянного знака и съеденной старшей
/// цифры (`_parseMassaK` читал неустоявшиеся `  12.345` как **2.345 кг**).
///
/// # Чего этот эмулятор НЕ доказывает
///
/// * **Что весы взвесили.** Груза нет; число называют пультом.
/// * **Что настоящие весы шлют именно эти строки.** Форматы сняты с
///   **нашего** `ScalesService.parseLine`, то есть с нашего понимания чужого
///   протокола.
/// * **Что дисплей показал.** Экрана нет; видны байты и их разбор.
/// * **Что скорость порта верна.** Через com0com/socat скорость ничего не
///   значит — настоящий прибор на 4800 при 9600 молчал бы.
///
/// # Дверь остановки
///
/// `Ctrl-C` и `POST /_emul/stop` на управляющем порту. Порт закрывается
/// явно: незакрытый COM-порт на Windows остаётся занятым до конца сеанса,
/// и следующий запуск стенда падает на «доступ запрещён».
///
/// # Запуск
///
/// ```
/// dart run test/emulators/serial/emulator.dart --port COM9 --role scale --control 8899
/// dart run test/emulators/serial/emulator.dart --port /dev/pts/4 --role display
/// dart run test/emulators/serial/emulator.dart --stop --control 8899
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:telepos/hardware/serial/serial_port_path.dart';
import 'package:telepos/hardware/paper_charset.dart';

/// Строка весов в трёх диалектах, которые разбирает продукт.
///
/// Числа собираются **строками**, а не через `double`: эмулятор, сложивший
/// `double`, внесёт свою ошибку и покраснеет на исправном коде — эмулятор
/// WebKassa на этом уже стоял сторожем.
String scaleLine({
  required String dialect,
  required String weight,
  required bool stable,
  bool overload = false,
  String unit = 'kg',
}) {
  switch (dialect) {
    case 'cas':
      if (overload) return 'OL,GS,      0.000$unit\r\n';
      final status = stable ? 'ST' : 'US';
      return '$status,GS,${weight.padLeft(9)}$unit\r\n';
    case 'massaK':
      if (overload) {
        // У этого диалекта маркера перегрузки в продукте нет и придумывать
        // его нельзя: ложная «перегрузка» останавливает продажу. Эмулятор
        // молчит ровно так же, как молчали бы настоящие весы.
        return '';
      }
      return '${stable ? r'$' : ' '}${weight.padLeft(9)}\r\n';
    default:
      if (overload) return 'OL\r\n';
      return '${stable ? '' : '~'}$weight $unit\r\n';
  }
}

/// Разбор потока дисплея покупателя.
///
/// Наш `CustomerDisplayManager` шлёт печатный текст с управляющими байтами
/// позиционирования; здесь они называются, а не проглатываются.
String renderDisplay(List<int> bytes) {
  final out = StringBuffer();
  final line = StringBuffer();
  for (final b in bytes) {
    if (b == 0x0C) {
      if (line.isNotEmpty) {
        out.writeln('  │ $line');
        line.clear();
      }
      out.writeln('  [очистка экрана]');
    } else if (b == 0x0D || b == 0x0A) {
      out.writeln('  │ $line');
      line.clear();
    } else if (b == 0x1B) {
      out.write('  [ESC]');
    } else if (b < 0x20) {
      out.write('  [0x${b.toRadixString(16).padLeft(2, '0')}]');
    } else {
      line.write(b < 0x80 ? String.fromCharCode(b) : _cp866Char(b));
    }
  }
  if (line.isNotEmpty) out.writeln('  │ $line');
  return out.toString();
}

/// CP866 → знак, **той же таблицей, какой продукт кодирует**
/// (`hardware/paper_charset.dart`).
///
/// Своя таблица здесь была восьмой в дереве и обрывалась на `0xEF`: `Ё`, `№`
/// и всё за ними читались точкой. Разборщик, читающий поток не так, как его
/// пишут, красит верное и зеленит неверное.
String _cp866Char(int b) => decodePaperByte(b, PaperCharset.cp866);

class SerialEmulator {
  SerialEmulator({
    required this.portPath,
    required this.role,
    this.dialect = 'cas',
    this.echo = true,
    this.continuous = false,
  });

  final String portPath;

  /// `scale` или `display`.
  final String role;

  final String dialect;

  final bool echo;

  /// Сыпать вес непрерывно, не дожидаясь запроса `W`.
  ///
  /// # Зачем это понадобилось и почему это не выдумка
  ///
  /// Через пару COM-портов обмен двусторонний: касса шлёт `W`, эмулятор
  /// отвечает. Через **файл** так не выходит — измерено: периодический опрос
  /// `ScalesService._pollWeight` ничего не пишет, только читает, и обе стороны
  /// ждут друг друга вечно (первая редакция пробы висела ровно до тайм-аута в
  /// 10 секунд).
  ///
  /// Непрерывная выдача — не подгонка под стенд: так работает половина
  /// рыночных весов, потоком строк без запроса, и опрос кассы рассчитан ровно
  /// на них. То есть файл эмулирует **потоковые** весы, а пара портов — весы
  /// по запросу; вместе они покрывают обе повадки, и ни одна не выдумана.
  final bool continuous;

  RandomAccessFile? _file;
  bool _busy = false;
  Timer? _poll;
  HttpServer? _control;

  final List<Map<String, Object?>> journal = [];

  /// Что «лежит на весах». Строка, а не число: см. [scaleLine].
  String weight = '0.500';
  bool stable = true;
  bool overload = false;

  /// Отказы. Все выдуманы: протокола с кодами ошибок у COM-порта нет.
  ///
  /// | Отказ | Что происходит | Что открывает в продукте |
  /// | --- | --- | --- |
  /// | `silent` | весы не отвечают вовсе | «весы не отвечают» ≠ «вес не устоялся» |
  /// | `neverSettles` | шлёт только неустоявшийся вес | вторую половину той же развилки |
  /// | `overload` | шлёт `OL` | немедленный выход без ожидания тайм-аута |
  /// | `garbage` | шлёт строку не того формата | `parseLine` возвращает `null` |
  String refuse = '';

  int get controlPort => _control?.port ?? 0;

  /// Открывает порт. Отказ приходит **значением**: пары портов может не
  /// быть, и это самая частая причина, по которой стенд не поднимается.
  Future<String?> open() async {
    try {
      _file = await openSerialPort(portPath, mode: FileMode.append);
    } catch (e) {
      return 'Порт «$portPath» не открылся: $e\n'
          'Если это имя COM — пары виртуальных портов, похоже, нет: '
          'Windows — com0com, Linux/macOS — socat -d -d pty,raw,echo=0 '
          'pty,raw,echo=0. Если это путь файла — проверьте каталог.';
    }
    _poll = Timer.periodic(const Duration(milliseconds: 120), (_) {
      // Строго по очереди и не внахлёст: `RandomAccessFile` не терпит двух
      // одновременных действий и бросает «An async operation is currently
      // pending» — измерено, первая редакция непрерывной выдачи падала ровно
      // так. У настоящего порта этой беды нет: там читает и пишет драйвер.
      if (_busy) return;
      _busy = true;
      unawaited(() async {
        try {
          await _tick();
          if (continuous && role == 'scale') await _answerWeight();
        } finally {
          _busy = false;
        }
      }());
    });
    return null;
  }

  Future<void> _tick() async {
    final file = _file;
    if (file == null) return;
    try {
      final bytes = await file.read(256);
      if (bytes.isEmpty) return;
      if (role == 'display') {
        _log('display', 'принято ${bytes.length} байт', rendered: renderDisplay(bytes));
        return;
      }
      for (final b in bytes) {
        // 'W' — запросить вес, 'T' — тара. Ровно то, что шлёт
        // `ScalesService._getWeightRequestCommand`.
        if (b == 0x57 || b == 0x4E) {
          await _answerWeight();
        } else if (b == 0x54) {
          weight = '0.000';
          _log('tare', 'тара: вес обнулён');
        }
      }
    } catch (e) {
      _log('error', 'чтение порта не удалось: $e');
    }
  }

  Future<void> _answerWeight() async {
    final file = _file;
    if (file == null) return;
    if (refuse == 'silent') {
      _log('silent', 'запрос веса оставлен без ответа: отказ «silent»');
      return;
    }
    final String line;
    if (refuse == 'garbage') {
      line = 'ЭТО НЕ ВЕС\r\n';
    } else {
      line = scaleLine(
        dialect: dialect,
        weight: weight,
        stable: refuse == 'neverSettles' ? false : stable,
        overload: refuse == 'overload' || overload,
      );
    }
    if (line.isEmpty) {
      _log('mute', 'диалект $dialect не умеет сказать «перегрузка» — молчит');
      return;
    }
    await file.writeFrom(line.codeUnits);
    await file.flush();
    _log(
      'weight',
      'отдано «${line.trim()}» — ${refuse.isEmpty ? "исправен" : "отказ «$refuse»"}',
    );
  }

  void _log(String kind, String why, {String? rendered}) {
    journal.add({
      'at': DateTime.now().toIso8601String(),
      'kind': kind,
      'why': why,
      if (rendered != null) 'rendered': rendered,
    });
    if (echo) {
      stdout.writeln('[$kind] $why');
      if (rendered != null) stdout.write(rendered);
    }
  }

  Future<void> startControl(String host, int port) async {
    _control = await HttpServer.bind(host, port);
    unawaited(() async {
      final server = _control;
      if (server == null) return;
      await for (final request in server) {
        Map<String, Object?> body = const {};
        if (request.method == 'POST') {
          final raw = await utf8.decoder.bind(request).join();
          if (raw.trim().isNotEmpty) {
            try {
              body = (jsonDecode(raw) as Map).cast<String, Object?>();
            } catch (_) {}
          }
        }
        Object? answer;
        switch (request.uri.path) {
          case '/_emul/weight':
            weight = (body['weight'] as String?) ?? weight;
            stable = (body['stable'] as bool?) ?? stable;
            overload = (body['overload'] as bool?) ?? overload;
            answer = _state();
          case '/_emul/fault':
            refuse = (body['refuse'] as String?) ?? '';
            answer = _state();
          case '/_emul/reset':
            refuse = '';
            overload = false;
            stable = true;
            weight = '0.500';
            journal.clear();
            answer = _state();
          case '/_emul/state':
            answer = _state();
          case '/_emul/journal':
            answer = journal;
          case '/_emul/stop':
            request.response
              ..statusCode = 200
              ..write(jsonEncode({'stopping': true}));
            await request.response.close();
            await stop();
            return;
          default:
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
            continue;
        }
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(answer));
        await request.response.close();
      }
    }());
  }

  Map<String, Object?> _state() => {
    'port': portPath,
    'role': role,
    'dialect': dialect,
    'weight': weight,
    'stable': stable,
    'overload': overload,
    'refuse': refuse,
    'journal': journal.length,
  };

  /// Дверь остановки. **Порт закрывается явно:** незакрытый COM-порт на
  /// Windows остаётся занятым, и следующий запуск падает на «доступ
  /// запрещён» — уже случалось.
  Future<void> stop() async {
    _poll?.cancel();
    _poll = null;
    try {
      await _file?.close();
    } catch (_) {}
    _file = null;
    await _control?.close(force: true);
    _control = null;
  }
}
