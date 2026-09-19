import 'package:telepos/domain/repositories/scanner_rules_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';

/// Правила чтения штрихкода с браузерного терминала — задача 45.
///
/// # Что было
///
/// `BarcodeScannerMixin` читал правила только при
/// `isRegistered<ScannerRulesRepository>()`, а браузер его не привязывал.
/// Длины кода и зазор между символами **молча** откатывались к зашитым — на
/// продаже и возврате разом. Где магазин настроил свои правила, сканы в
/// браузере отбрасывались без намёка на экране. Довод в разрешительном
/// списке сторожа («в браузере сканер клавиатурный») был неверен: правила
/// длины и зазора как раз и есть правила клавиатурного сканера.
///
/// # Почему не только чтение — пункт 11 ревизии 2026-09-19
///
/// Прежний довод этого файла звучал так: «правила — настройка кассы, и
/// пишутся на кассе; менять их с планшета — отдельное решение с отдельным
/// правом». Решение принято заказчиком 2026-09-18 («в браузере должно
/// работать то же, что в приложении»), и право у записи есть — то же
/// `settings.hardware`, каким заперт сам экран «Оборудование»
/// (`TillOps.scannerRulesSave`).
///
/// Поэтому класс реализует **пишущий** договор целиком. До этой правки
/// секция правил в браузере говорила `scannerRulesUnavailable` — «здесь их
/// не задать», — и владелец, у которого вместо кассы планшет, не мог
/// настроить сканер ничем.
///
/// # Чего это НЕ доказывает
///
/// Что правила применятся немедленно. Их читает `BarcodeScannerMixin` при
/// постройке экрана продажи и возврата (`ScannerRulesReader.read()`), а не
/// подпиской: рабочее место, уже стоящее на продаже, доработает на прежних
/// длинах до следующего открытия экрана. Это верно и на кассе — запись из
/// `hardware_settings_screen.dart` там ведёт себя так же.
class WtScannerRules implements ScannerRulesRepository {
  WtScannerRules(this._wire);

  final WtDispatcher _wire;

  @override
  Future<ScannerRules> read() async {
    try {
      return await _wire.ask(TillOps.scannerRules, null);
    } on WtProtocolError catch (error) {
      throw WireRefusal(error.code, error.detail);
    }
  }

  /// Отказ приходит `WireRefusal`, а не тишиной: экран настроек показывает
  /// его текст в общем списке ошибок сохранения
  /// (`hardware_settings_screen._saveSettings`), и «сохранено» без записи
  /// — ровно то молчание, ради снятия которого заведена операция.
  ///
  /// Негодную тройку (min > max) отвергает конструктор [ScannerRules] ещё
  /// **здесь**, во вкладке, — кадра не будет вовсе. Это не замена проверке
  /// кассы: ту делает разбор тела на той стороне, и подделанная вкладка её
  /// не обойдёт.
  @override
  Future<void> save(ScannerRules rules) async {
    try {
      await _wire.ask(TillOps.scannerRulesSave, rules);
    } on WtProtocolError catch (error) {
      throw WireRefusal(error.code, error.detail);
    }
  }
}
