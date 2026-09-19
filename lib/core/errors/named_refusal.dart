/// Отказ, у которого есть **код** — названная причина, а не авария.
///
/// # Зачем интерфейс, а не `is WireRefusal || is WtProtocolError`
///
/// Живая приёмка 2026-09-13: касса ответила
/// `WtProtocolError(debt_customer_required: …)`, а кассир прочёл
/// «Ошибка сохранения: minified:du». `safeErrorText` для всего, кроме
/// `SqliteException`, отдавал `runtimeType.toString()`, а в dart2js это имя
/// минифицировано. Код, ради которого отказ назван, терялся на пути от
/// исключения к строке — и восстановить его дальше было уже нечем.
///
/// Интерфейс живёт в `lib/core`, потому что его читает `safeErrorText`
/// (`lib/core` не импортирует ни `lib/domain`, ни `lib/web`), а реализуют
/// его `WireRefusal` (`lib/domain/wire`) и `WtProtocolError` (`lib/web`).
/// Проверка `is NamedRefusal` не зависит от имени типа — значит минификация
/// её не ломает.
abstract interface class NamedRefusal {
  /// Код причины — тот же, что у `ErrorFrame.code`. По нему словарь
  /// (`saleRefusalErrorKeys` → `ErrorLocalizer`) находит фразу для кассира.
  String get code;

  /// Текст причины, написанный кассой для человека.
  ///
  /// Безопасен по построению (I144): его пишет обработчик, а не база. На
  /// экран он попадает **только** для кодов, чей ключ объявлен «с текстом»
  /// (`withMessage: true`), — и никогда для кода, которого нет в словаре.
  String get reasonText;
}
