/// Нарезка потока байт обратно на кадры.
///
/// # Почему это вообще нужно
///
/// Поток QUIC — это байты, а не сообщения. Касса пишет в один поток кадр за
/// кадром (`sendOn` на той же паре «сессия, поток»), и ни одно звено между ней
/// и браузером не обязано сохранять границы записей: два кадра приезжают одной
/// выдачей `ReadableStream`, а один кадр — двумя. Без нарезки подписка на два
/// обновления показала бы одно нечитаемое, а разорванный кадр был бы назван
/// отказом ровно в тот момент, когда он ещё едет.
///
/// # Почему по скобкам, а не по длине впереди
///
/// Длины впереди на проводе нет, и это измерено, а не предположено:
/// `rk_quic` на стороне кассы кладёт в поток голый UTF-8 (`stream_send`
/// пишет `payload.as_bytes()`), а на приёме читает поток до конца
/// (`read_to_end` → `String::from_utf8`). Договориться о длине означало бы
/// менять обе половины разом; нарезка по скобкам не требует от кассы ничего и
/// работает с тем, что она уже шлёт.
///
/// Разделителем-переводом строки обойтись нельзя по той же причине: его никто
/// не пишет, а требовать его — та же правка обеих половин.
library;

/// Собирает кадры из кусков, приходящих из потока.
///
/// Один экземпляр на один поток: состояние здесь — это незавершённый кадр, и
/// делить его между обменами нечем.
final class WireFrameSplitter {
  String _pending = '';

  static const int _leftBrace = 0x7b; // {
  static const int _rightBrace = 0x7d; // }
  static const int _quote = 0x22; // "
  static const int _backslash = 0x5c; // \

  /// Добавляет кусок и отдаёт все кадры, ставшие целыми.
  ///
  /// Пустой список означает «кадр ещё едет», а не «ничего не пришло»: разница
  /// в том, что во втором случае ждать нечего.
  List<String> add(String chunk) {
    _pending += chunk;
    final frames = <String>[];

    while (true) {
      final start = _firstMeaningful(_pending);
      if (start == null) {
        // Одни пробелы между кадрами — сор, а не начало следующего.
        _pending = '';
        break;
      }
      if (_pending.codeUnitAt(start) != _leftBrace) {
        // Отвечает не тот, кого спрашивали: страница HTML, портал гостевого
        // Wi-Fi, чужой сервис на порту. Копить это в ожидании закрывающей
        // скобки значило бы висеть до предела простоя, ничего не сказав.
        // Отдаём как есть — назовёт отказ сам разбор кадра.
        frames.add(_pending.substring(start));
        _pending = '';
        break;
      }
      final end = _endOfObject(_pending, start);
      if (end == null) {
        _pending = _pending.substring(start);
        break;
      }
      frames.add(_pending.substring(start, end));
      _pending = _pending.substring(end);
    }

    return frames;
  }

  /// Хвост, который так и не стал кадром.
  ///
  /// Зовётся при закрытии потока. Молча выброшенный хвост означал бы обмен,
  /// который просто не ответил, — а он ответил половиной, и это разные
  /// состояния: первое похоже на медленную кассу, второе на сломанную.
  String? drain() {
    final tail = _pending.trim();
    _pending = '';
    return tail.isEmpty ? null : tail;
  }

  /// Первый знак, не являющийся пробельным, или `null`, если таких нет.
  static int? _firstMeaningful(String text) {
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) > 0x20) return i;
    }
    return null;
  }

  /// Конец объекта, начинающегося в [start], — позиция ЗА закрывающей
  /// скобкой. `null`, если объект ещё не закрылся.
  ///
  /// Скобки внутри строк не считаются: имя терминала «Касса {1}» — обычное
  /// имя, а не диверсия, и счётчик, не знающий про строки, обрубил бы кадр по
  /// нему.
  static int? _endOfObject(String text, int start) {
    var depth = 0;
    var inString = false;
    var escaped = false;

    for (var i = start; i < text.length; i++) {
      final unit = text.codeUnitAt(i);

      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (unit == _backslash) {
          escaped = true;
        } else if (unit == _quote) {
          inString = false;
        }
        continue;
      }

      switch (unit) {
        case _quote:
          inString = true;
        case _leftBrace:
          depth++;
        case _rightBrace:
          depth--;
          if (depth == 0) return i + 1;
      }
    }

    return null;
  }
}
