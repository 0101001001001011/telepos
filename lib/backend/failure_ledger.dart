/// Счёт неудач по строковому ключу с ленивой уборкой — общий счётчик
/// ограничителей кассы.
///
/// # Откуда взялся (2026-09-13)
///
/// До этого дня счёт жил двумя картами внутри `LoginThrottle`
/// (`_failures`/`_touchedAt`) и уборкой `_forget()` там же, а
/// `buildWireDeniedJournalHandler` (`security_journal.dart`) повторял приём
/// своей картой со ссылкой «тот же приём». Второй ограничитель —
/// `CertificateThrottle`, перебор номеров и ПИНов сертификатов — стал бы
/// третьей копией тех же двадцати строк. Счёт вынесен сюда, и оба
/// ограничителя ведут его одним кодом; различаются они только тем, **что
/// делают со счётом**: вход задерживает ответ (`LoginThrottle` — «задержка, не
/// замок», разбор там), сертификат отказывает названной причиной
/// (`CertificateThrottle`, разбор там).
///
/// # Что здесь есть и чего нет
///
/// - Счёт растёт **синхронно** ([add]) — вызывающий обязан звать его до
///   первого `await`, иначе параллельные попытки прочтут один и тот же счёт
///   (пункт 2 второго круга задачи 7, докстринг `LoginThrottle`).
/// - Уборка ленивая ([forgetStale]) — на обращении, без будильника: запись,
///   по которой дольше [staleAfter] не было неудач, стирается. Приём
///   `SessionRegistry._forget()`.
/// - [clear] — полный сброс ключа (успешный вход у `LoginThrottle`),
///   [giveBack] — возврат **одной** своей единицы, не трогающий чужих
///   (успешная проверка сертификата: она не стирает неудачи других сеансов).
/// - Часов истечения нет: срок записи — только [staleAfter] от последней
///   неудачи. Что считать «запертым», решает владелец.
library;

import 'package:meta/meta.dart' show visibleForTesting;

class FailureLedger {
  FailureLedger({required this.staleAfter, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// Сколько запись живёт без новых неудач по ключу.
  final Duration staleAfter;
  final DateTime Function() _clock;

  final Map<String, int> _failures = {};
  final Map<String, DateTime> _touchedAt = {};

  DateTime now() => _clock();

  /// Счёт неудач по ключу; `0`, если записи нет.
  int countOf(String key) => _failures[key] ?? 0;

  /// Когда по ключу в последний раз была неудача.
  DateTime? touchedAt(String key) => _touchedAt[key];

  /// Одна неудача по ключу. Синхронно — см. докстринг библиотеки.
  void add(String key, DateTime at) {
    _failures[key] = countOf(key) + 1;
    _touchedAt[key] = at;
  }

  /// Стереть ключ целиком.
  void clear(String key) {
    _failures.remove(key);
    _touchedAt.remove(key);
  }

  /// Вернуть одну единицу, не трогая время последней неудачи: чужие
  /// неудачи по тому же ключу остаются и стареют со своего срока.
  void giveBack(String key) {
    final count = _failures[key];
    if (count == null) return;
    if (count <= 1) {
      clear(key);
    } else {
      _failures[key] = count - 1;
    }
  }

  /// Стереть записи, по которым дольше [staleAfter] не было неудач.
  void forgetStale() {
    final now = _clock();
    final stale = _touchedAt.entries
        .where((e) => now.difference(e.value) >= staleAfter)
        .map((e) => e.key)
        .toList();
    stale.forEach(clear);
  }

  @visibleForTesting
  int get size => _failures.length;
}
