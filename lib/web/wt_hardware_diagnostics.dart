import 'package:telepos/domain/diagnostics/hardware_diagnostics.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';

/// Диагностика оборудования с планшета — пункт «Достижимость с браузерного
/// терминала» плана `2026-09-19-hardware-diagnostics.md`.
///
/// # Что здесь закрыто
///
/// Решение заказчика 2026-09-18: «в браузере должно работать то же, что в
/// приложении». Экран диагностики был заведён только в десктопной таблице
/// маршрутов, а его вкладки читали кассу напрямую — `PrintQueue`,
/// `ReceiptPrintService`, `AppDatabase`, `FiscalQueueStore`. Три из четырёх
/// живут в `lib/data/` и `lib/hardware/` и в браузерную сборку не собираются
/// вовсе. Наладчик, у которого вместо кассы планшет, не мог увидеть ни
/// одного байта, ушедшего в принтер.
///
/// Это **вторая реализация того же порта**
/// ([HardwareDiagnosticsRepository]), а не второй путь к приборам: очередь
/// печати и очередь фискализации по-прежнему одни, у кассы; планшет только
/// спрашивает.
///
/// # Раскладки чека здесь нет ни строки — и это главное свойство
///
/// [PrintJobDiagnostics.text] приезжает **готовым**: его разобрала касса
/// своим единственным на всё дерево разборщиком ([renderEscPosAsText]). В
/// этом файле нет ни `ESC`, ни `GS`, ни ширины ленты, ни выравнивания —
/// ничего, из чего чек состоит.
///
/// Разбор, почему выбрано именно так, а не «касса шлёт байты, вкладка
/// разбирает», — в докстринге
/// `lib/domain/diagnostics/hardware_diagnostics.dart`. Коротко: разбор во
/// вкладке был бы **вторым местом, где рождается текст чека на экране**,
/// ровно того рода, из-за которого две раскладки уже разошлись однажды
/// (докстринг `escpos_text_preview.dart`) и предпросмотр показывал не то,
/// что выходило из принтера.
///
/// Тем же правилом едет и тело запроса к оператору: касса форматирует его с
/// отступами, вкладка показывает строку.
///
/// # Правил и отбора здесь нет ни строки
///
/// Чьи задания показывать, в каком порядке, что считать «настроено» — всё
/// это решает касса. Реши вкладка хоть что-нибудь сама, у диагностики
/// появился бы второй свод правил, живущий в браузере, и первая же правка
/// кассового порядка оставила бы планшет показывать другой.
class WtHardwareDiagnostics implements HardwareDiagnosticsRepository {
  const WtHardwareDiagnostics(this._wire);

  final WtDispatcher _wire;

  /// Отказ провода становится [WireRefusal] **с тем же кодом** — тем же
  /// приёмом, что у `WtReceiptTemplateSetup` и `WtShiftDesk`.
  ///
  /// Иначе экрану пришлось бы знать два типа исключения: кассовая реализация
  /// того же порта бросает `WireRefusal`, и договор обязан быть один на обе.
  Future<T> _named<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on WtProtocolError catch (error) {
      throw WireRefusal(error.code, error.detail);
    }
  }

  /// Рабочего места вкладка не называет и назвать не может: у операции пустое
  /// тело. Чьи задания показывать, решает касса по себе — разбор в докстринге
  /// [HardwareDiagnosticsRepository.watchPrinter].
  @override
  Stream<PrinterDiagnosticsView> watchPrinter() =>
      _wire.watch(TillOps.diagnosticsPrinter, null);

  @override
  Future<FiscalDiagnosticsView> fiscal() =>
      _named(() => _wire.ask(TillOps.diagnosticsFiscal, null));

  /// Импульсы ящика. Тело пустое по тому же запрету: чьи импульсы
  /// показывать, решает касса по себе.
  @override
  Stream<DrawerDiagnosticsView> watchDrawer() =>
      _wire.watch(TillOps.diagnosticsDrawer, null);

  @override
  Stream<DisplayDiagnosticsView> watchDisplay() =>
      _wire.watch(TillOps.diagnosticsDisplay, null);

  /// Показание весов — **прореженное кассой**, а не здесь.
  ///
  /// Ни одного правила прореживания в этом файле нет, и это то же свойство,
  /// что «раскладки чека здесь нет ни строки». Прореживай браузерная
  /// половина сама, кадры резались бы **после** того, как их провезли по
  /// проводу, — то есть ровно та работа, ради экономии которой прореживание
  /// и заведено, оказалась бы проделанной полностью. А кассовая вкладка,
  /// читающая тот же порт напрямую, получала бы другую частоту, чем планшет:
  /// две поверхности показывали бы разное про один прибор.
  ///
  /// Разбор решения о частоте — в докстринге
  /// [HardwareDiagnosticsRepository.watchScales].
  @override
  Stream<ScalesDiagnosticsView> watchScales() =>
      _wire.watch(TillOps.diagnosticsScales, null);
}
