import 'dart:async';

import 'package:decimal/decimal.dart';

import 'package:telepos/hardware/display/customer_display_manager.dart';
import 'package:telepos/hardware/display/display_config.dart';

/// Какой вызов породил строку.
///
/// Перечислением, а не строкой по-русски: подпись показывает экран, и он же
/// её переводит. Слово, зашитое здесь, казахский кассир прочитал бы
/// по-русски — сторож равенства словарей такого не ловит.
enum CustomerDisplayCall { price, total, text, welcome, change, clear }

/// Одна строка, отправленная на дисплей покупателя.
class CustomerDisplayLine {
  const CustomerDisplayLine({
    required this.at,
    required this.kind,
    required this.text,
    this.refusal,
  });

  final DateTime at;

  final CustomerDisplayCall kind;

  /// То, что кассе полагалось показать.
  ///
  /// Сумма записывается **той же записью, что уходит в порт** —
  /// `toStringAsFixed(2)`, как в `BaseDisplayManager.formatAmount`. Первая
  /// редакция писала сюда `'$amount'` и давала «1250» там, где на стекле
  /// «1250.00»: журнал становился второй раскладкой, а на второй раскладке
  /// этот проект уже обжигался предпросмотром чека.
  ///
  /// Чего здесь нет — добивки пробелами до ширины строки: это дело дисплея,
  /// и в журнале она была бы шумом.
  final String text;

  /// Причина, по которой отправка не удалась, либо `null`.
  final String? refusal;

  bool get accepted => refusal == null;
}

/// Что касса отправляла на дисплей покупателя.
///
/// # Чего эта запись НЕ доказывает
///
/// Что покупатель это увидел. Дисплей на последовательном порту обратной
/// связи не даёт: запись в порт прошла — и всё. Погасший, отключённый или
/// показывающий кашу дисплей отсюда неотличим от исправного, и подпись на
/// экране диагностики говорит именно это.
///
/// Та же граница, что у денежного ящика (`CashDrawerJournal`), и по той же
/// причине: у обоих приборов канал односторонний.
///
/// # Почему в памяти
///
/// Вопрос — «что касса показывает **сейчас**». Ответ живёт ровно столько,
/// сколько работает касса; история строк дисплея за смену никому не нужна и
/// ни одного спора не решает.
class CustomerDisplayJournal {
  CustomerDisplayJournal({this.limit = 30});

  final int limit;
  final List<CustomerDisplayLine> _lines = [];
  final StreamController<List<CustomerDisplayLine>> _changes =
      StreamController<List<CustomerDisplayLine>>.broadcast();

  /// Последние строки, новые первыми.
  List<CustomerDisplayLine> recent() => List.unmodifiable(_lines.reversed);

  /// То, что на дисплее сейчас, — последняя принятая строка.
  CustomerDisplayLine? get current {
    for (final line in _lines.reversed) {
      if (line.accepted) return line;
    }
    return null;
  }

  Stream<List<CustomerDisplayLine>> watch() async* {
    yield recent();
    yield* _changes.stream;
  }

  void record(CustomerDisplayLine line) {
    _lines.add(line);
    if (_lines.length > limit) _lines.removeRange(0, _lines.length - limit);
    if (!_changes.isClosed) _changes.add(recent());
  }

  Future<void> dispose() => _changes.close();
}

/// Дисплей, который помнит, что на него отправляли.
///
/// # Почему обёртка, а не запись внутри каждой модели
///
/// Моделей дисплея несколько (`vfd_display.dart`, `led_display.dart`,
/// `serial_port_display.dart`), и запись внутри каждой разошлась бы в первый
/// же день, когда добавят четвёртую: новый дисплей просто не попал бы в
/// журнал, и это выглядело бы как «на дисплей ничего не отправляли».
///
/// # Почему это не нарушает правило подстановки
///
/// Обёртка **ничего не заменяет**: она зовёт настоящий дисплей и передаёт его
/// ответ, а рядом записывает строку. Запрещено другое — подставить вместо
/// дисплея заглушку, которая в порт не пишет; такой подмены здесь нет, и
/// сторож `display_journal_test.dart` следит, что вызов доходит до обёрнутого.
class RecordingCustomerDisplay implements CustomerDisplayManager {
  RecordingCustomerDisplay(this._inner, this._journal);

  final CustomerDisplayManager _inner;
  final CustomerDisplayJournal _journal;

  @override
  CustomerDisplayConfig get config => _inner.config;

  @override
  bool get isConnected => _inner.isConnected;

  Future<void> _record(
    CustomerDisplayCall kind,
    String text,
    Future<void> Function() send,
  ) async {
    try {
      await send();
      _journal.record(
        CustomerDisplayLine(at: DateTime.now(), kind: kind, text: text),
      );
    } catch (e) {
      _journal.record(
        CustomerDisplayLine(
          at: DateTime.now(),
          kind: kind,
          text: text,
          refusal: '$e',
        ),
      );
      rethrow;
    }
  }

  @override
  Future<bool> connect() => _inner.connect();

  @override
  Future<void> disconnect() => _inner.disconnect();

  @override
  Future<void> clear() => _record(CustomerDisplayCall.clear, '', _inner.clear);

  @override
  Future<void> showPrice(Decimal price) => _record(
    CustomerDisplayCall.price,
    price.toStringAsFixed(2),
    () => _inner.showPrice(price),
  );

  @override
  Future<void> showTotal(Decimal total) => _record(
    CustomerDisplayCall.total,
    total.toStringAsFixed(2),
    () => _inner.showTotal(total),
  );

  @override
  Future<void> showText(String text) =>
      _record(CustomerDisplayCall.text, text, () => _inner.showText(text));

  @override
  Future<void> showWelcome() =>
      _record(CustomerDisplayCall.welcome, '', _inner.showWelcome);

  @override
  Future<void> showChange(Decimal change) => _record(
    CustomerDisplayCall.change,
    change.toStringAsFixed(2),
    () => _inner.showChange(change),
  );
}
