import 'dart:async';
import 'dart:convert';

import 'package:get_it/get_it.dart';

import 'package:telepos/core/net/loopback.dart';
import 'package:telepos/hardware/cash_drawer/cash_drawer_journal.dart';
import 'package:telepos/hardware/display/customer_display_journal.dart';
import 'package:telepos/hardware/scales/scales_service.dart';
import 'package:telepos/data/database/app_database.dart' hide FiscalQueueEntry;
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';
import 'package:telepos/domain/diagnostics/hardware_diagnostics.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/hardware/printer/escpos_text_preview.dart';

/// Диагностика оборудования на кассе — та половина порта, у которой приборы
/// действительно есть.
///
/// # Почему разбор байтов живёт здесь, а не во вкладке
///
/// Потому что здесь он живёт **один раз на всё дерево**. [renderEscPosAsText]
/// — единственный разборщик ESC/POS в проекте, и он же собирает предпросмотр
/// шаблона чека. Отдай эта реализация байты, а рисуй их вкладка, — у текста
/// чека на экране появился бы второй родитель, и разошлись бы они молча:
/// ровно это уже случилось однажды с предпросмотром (докстринг
/// `lib/hardware/printer/escpos_text_preview.dart`) и стоило круга правок.
///
/// Разбор целиком — в докстринге `lib/domain/diagnostics/hardware_diagnostics
/// .dart`.
///
/// # Ширина ленты — у привязки, а не константой
///
/// Спрашивается у [ReceiptPrintService.currentPaperWidth] — той самой
/// привязки принтера, по которой собирались байты. Литерал здесь дал бы чек,
/// который на экране переносится не там, где на бумаге.
///
/// Спрашивается **один раз на подписку**, а не на каждое событие очереди:
/// ширина — свойство прибора, и читать привязку в такт чужим печатям значило
/// бы ходить в базу на каждый чек.
///
/// # Порядок задаётся здесь, а не вкладкой
///
/// Новые сверху. Обе поверхности — кассовая вкладка и планшет — обязаны
/// показывать один порядок, а сортировка на экране была бы вторым местом,
/// где он решается, и первая же правка одного оставила бы второе позади.
///
/// # Чего это НЕ доказывает
///
/// Что чек вышел на бумаге. [PrintJobDiagnostics.state] — состояние задания
/// в очереди кассы, то есть то, чем кончилась **отправка**. Бумаги в лотке
/// касса не видит ни в каком режиме.
class LocalHardwareDiagnostics implements HardwareDiagnosticsRepository {
  LocalHardwareDiagnostics({
    required this.terminals,
    this.queue,
    this.printer,
    this.db,
    this.fiscalQueue,
    this.drawerJournal,
    this.displayJournal,
    this.scales,
    this.scalesFrameInterval = const Duration(milliseconds: 300),
  });

  /// Чьи задания показывать — решает **касса по себе**, а не довод метода.
  ///
  /// Разбор в докстринге [HardwareDiagnosticsRepository.watchPrinter]:
  /// рабочее место, названное телом кадра, дало бы планшету чужие чеки.
  final TerminalRepository terminals;

  /// `null` — очереди печати на этой кассе нет вовсе (голый процесс
  /// `bin/telepos_backend.dart`). Тогда [watchPrinter] отдаёт **названное**
  /// состояние `available: false`, а не пустой список: «касса пока ничего не
  /// печатала» и «печатать нечем» — разные ответы.
  final PrintQueue? queue;

  /// `null` — службы печати нет; тогда ширина берётся узкой, тем же доводом,
  /// что у `BoundReceiptPaperWidth`: узкий чек читается на любой ленте,
  /// широкий на узкой ломается переносами.
  final ReceiptPrintService? printer;

  /// `null` — базы нет; принятых оператором документов не прочесть.
  final AppDatabase? db;

  /// `null` — очереди фискализации нет.
  final FiscalQueueStore? fiscalQueue;

  /// Память об импульсах ящика. `null` — её на этой кассе нет вовсе, и
  /// [watchDrawer] отдаёт **названное** `available: false`, а не пустой
  /// список.
  final CashDrawerJournal? drawerJournal;

  /// Память о строках дисплея покупателя. `null` — тем же доводом.
  final CustomerDisplayJournal? displayJournal;

  /// Живой порт весов. `null` либо порт не указан — весы не привязаны.
  final ScalesService? scales;

  /// Окно прореживания кадров весов — не чаще одного кадра в окно.
  ///
  /// Доводом, а не константой, и не ради настройки: проба, ждущая настоящие
  /// 300 мс, мерила бы **длину окна**, а не то, что прореживание вообще есть.
  /// Разбор самого решения — в докстринге
  /// [HardwareDiagnosticsRepository.watchScales].
  final Duration scalesFrameInterval;

  @override
  Stream<PrinterDiagnosticsView> watchPrinter() async* {
    final source = queue;
    if (source == null) {
      // Одно значение и конец потока — законно и отличается от подписки,
      // которая никогда ничего не пришлёт: вкладка получает названное
      // состояние сразу, а не остаётся со спиннером навсегда (И144).
      yield const PrinterDiagnosticsView(available: false, jobs: []);
      return;
    }
    final width = await _paperWidth();
    final self = await terminals.self();
    yield* source.watch(terminalId: self.id).map((jobs) {
      final ordered = [...jobs]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return PrinterDiagnosticsView(
        available: true,
        jobs: [
          for (final job in ordered)
            PrintJobDiagnostics(
              id: job.id,
              state: job.state,
              attempts: job.attempts,
              createdAt: job.createdAt,
              failureReason: job.failureReason,
              // ТЕ ЖЕ байты, тем же единственным разборщиком.
              text: renderEscPosAsText(
                job.payloadBytes,
                width: width.charWidth,
              ),
            ),
        ],
      );
    });
  }

  Future<ReceiptPaperWidth> _paperWidth() async {
    final service = printer;
    if (service == null) return ReceiptPaperWidth.mm58;
    return service.currentPaperWidth();
  }

  /// Ведёт ли адрес оператора на этот же компьютер.
  ///
  /// Считается **здесь**, на кассе: вкладка одна на обе поверхности, а разбор
  /// адреса требует `dart:io`, которого в браузерной сборке нет. Довод целиком
  /// — на [FiscalDiagnosticsView.onLoopback].
  ///
  /// Отказ чтения настроек — не повод зажечь плашку: «не знаю» и «за адресом
  /// эмулятор» разные ответы. Локальный модуль перебивает адрес сервера у
  /// самого провайдера (`WebKassaProvider._baseUrl` смотрит на него первым),
  /// поэтому смотреть надо туда же, иначе пометится не тот адрес.
  Future<bool> _operatorOnLoopback() async {
    if (!GetIt.I.isRegistered<FiscalSettingsSource>()) return false;
    try {
      final settings = await GetIt.I<FiscalSettingsSource>().load();
      final url = settings.hasLocalModule
          ? settings.localModuleUrl
          : settings.resolvedBaseUrl;
      if (url == null || url.isEmpty) return false;
      final host = Uri.tryParse(url)?.host;
      return host != null && host.isNotEmpty && isLoopbackHost(host);
    } on Object {
      return false;
    }
  }

  @override
  Future<FiscalDiagnosticsView> fiscal() async {
    final base = db;
    final store = fiscalQueue;
    if (base == null || store == null) {
      return const FiscalDiagnosticsView(
        configured: false,
        accepted: [],
        queued: [],
      );
    }
    final accepted = await base.webkassaReceiptDao.recentReceipts();
    final queued = [...await store.pending(), ...await store.failed()];
    return FiscalDiagnosticsView(
      configured: true,
      onLoopback: await _operatorOnLoopback(),
      accepted: [
        for (final row in accepted)
          FiscalAcceptedDocument(
            fiscalNo: row.fiscalNo,
            operatorReceiptNo: row.wkReceiptNo,
            // Строкой, а не числом: в колонке базы это `int`, но на экране
            // и в кабинете оператора это **номер документа**, а не величина
            // — складывать и сравнивать его никто не будет. Число на проводе
            // означало бы, что принимающая половина обязана выбрать формат
            // показа, то есть завести второе место, где номер превращается в
            // текст.
            receiptNo: row.receiptNo?.toString(),
            // `null` в колонке означает «не автономный»: автономный режим
            // проставляется явно, а старые строки его не знали вовсе.
            offline: row.wkOfflineMode ?? false,
          ),
      ],
      queued: [
        for (final entry in queued)
          FiscalQueuedDocument(
            idempotencyKey: entry.idempotencyKey,
            opType: entry.opType.name,
            attempts: entry.attempts,
            failed: entry.status == FiscalQueueStatus.failed,
            lastError: entry.lastError,
            // Форматирует **касса**, и с отступами: этот текст сверяют с тем,
            // что ждёт оператор. Второй форматировщик во вкладке разошёлся бы
            // с первым ровно там, где его читают.
            payloadJson: const JsonEncoder.withIndent(
              '  ',
            ).convert(entry.payload),
          ),
      ],
    );
  }

  // ── ящик, дисплей, весы ────────────────────────────────────────────────
  //
  // Пункт 4 плана `2026-09-19-hardware-diagnostics.md`. Все три жили в
  // памяти процесса кассы и на планшет не ехали вовсе; вкладок там не было.
  //
  // Работы здесь нет ни строки: журналы ведёт касса сама
  // (`CashDrawerJournal`, `CustomerDisplayJournal`), показание разбирает
  // `ScalesService` тем же разборщиком, которым касса продаёт весовой товар.
  // Эта реализация только **переводит кассовые типы в портовые** — и перевод
  // обязан быть исчерпывающим `switch`-ем, а не `default`-ом: новый путь
  // ящика или новый вызов дисплея должны ронять сборку здесь, а не
  // показывать наладчику неверное слово.

  @override
  Stream<DrawerDiagnosticsView> watchDrawer() {
    final journal = drawerJournal;
    if (journal == null) {
      // Одно значение и конец потока — то же устройство, что у
      // [watchPrinter] без очереди: вкладка получает названное состояние
      // сразу, а не остаётся со спиннером навсегда (И144).
      return Stream.value(
        const DrawerDiagnosticsView(available: false, kicks: []),
      );
    }
    return journal.watch().map(
      (kicks) => DrawerDiagnosticsView(
        available: true,
        kicks: [for (final kick in kicks) _kick(kick)],
      ),
    );
  }

  static DrawerKickDiagnostics _kick(CashDrawerKick kick) =>
      DrawerKickDiagnostics(
        at: kick.at,
        path: switch (kick.path) {
          CashDrawerPath.serialPort => DrawerKickPath.serialPort,
          CashDrawerPath.viaPrinter => DrawerKickPath.viaPrinter,
        },
        // `accepted`, а не `opened`, и это одно и то же слово на обеих
        // сторонах провода: обратной связи от соленоида нет ни на одном пути.
        accepted: kick.accepted,
        note: kick.note,
      );

  @override
  Stream<DisplayDiagnosticsView> watchDisplay() {
    final journal = displayJournal;
    if (journal == null) {
      return Stream.value(
        const DisplayDiagnosticsView(available: false, lines: []),
      );
    }
    return journal.watch().map((lines) {
      // «Что на стекле сейчас» спрашивается **у журнала**, а не считается
      // обходом списка: правило «последняя принятая» живёт одно, в
      // `CustomerDisplayJournal.current`. Посчитай его ещё и здесь, правило
      // оказалось бы в двух местах и разошлось бы на первой же правке.
      final current = journal.current;
      return DisplayDiagnosticsView(
        available: true,
        lines: [for (final line in lines) _line(line)],
        current: current == null ? null : _line(current),
      );
    });
  }

  static DisplayLineDiagnostics _line(CustomerDisplayLine line) =>
      DisplayLineDiagnostics(
        at: line.at,
        kind: switch (line.kind) {
          CustomerDisplayCall.price => DisplayCallKind.price,
          CustomerDisplayCall.total => DisplayCallKind.total,
          CustomerDisplayCall.text => DisplayCallKind.text,
          CustomerDisplayCall.welcome => DisplayCallKind.welcome,
          CustomerDisplayCall.change => DisplayCallKind.change,
          CustomerDisplayCall.clear => DisplayCallKind.clear,
        },
        // Текст **как его записала касса**: сумму журнал пишет той же
        // записью, что ушла в порт, и переписывать её здесь значило бы
        // завести вторую раскладку строки дисплея.
        text: line.text,
        refusal: line.refusal,
      );

  /// Показание весов, прореженное **до провода**.
  ///
  /// Решение о частоте кадров и все три рассмотренных устройства — в
  /// докстринге [HardwareDiagnosticsRepository.watchScales]. Здесь — как оно
  /// сделано:
  ///
  /// 1. первым кадром идёт то, что уже известно (`lastReading`), иначе
  ///    вкладка, открытая при неподвижном грузе, висела бы пустой до первого
  ///    шевеления чаши — а его может не случиться вовсе;
  /// 2. `distinct` снимает повторы: неподвижные весы шлют одно и то же по
  ///    нескольку раз в секунду бесконечно;
  /// 3. [thinnedFrames] режет остаток окном и **не теряет последний кадр**.
  ///
  /// Порядок именно такой: прореживание после снятия повторов. Наоборот —
  /// хвостовой кадр окна мог бы оказаться повтором уже показанного, и
  /// правило «не повторяться» выполнялось бы через раз.
  @override
  Stream<ScalesDiagnosticsView> watchScales() {
    final service = scales;
    final port = service?.port;
    if (service == null || port == null || port.isEmpty) {
      // «Весов нет» — состояние кассы, а не беда: весы стоят далеко не на
      // каждой. Пустое показание при `bound: true` было бы неотличимо от
      // весов с оборванным проводом.
      return Stream.value(const ScalesDiagnosticsView(bound: false));
    }

    Stream<ScalesDiagnosticsView> views() async* {
      yield _scalesView(service, service.lastReading);
      yield* service.weightStream.map(
        (reading) => _scalesView(service, reading),
      );
    }

    return thinnedFrames(views().distinct(_sameOnScreen), scalesFrameInterval);
  }

  static ScalesDiagnosticsView _scalesView(
    ScalesService service,
    ScalesReading? reading,
  ) => ScalesDiagnosticsView(
    bound: true,
    port: service.port,
    baudRate: service.baudRate,
    protocol: service.protocol.name,
    connected: service.isConnected,
    reading: reading == null ? null : _reading(reading),
  );

  static ScalesReadingDiagnostics _reading(ScalesReading reading) =>
      ScalesReadingDiagnostics(
        // Три знака — разрешение прибора. `Decimal` печатает 1.250 как
        // «1.25», и вкладка, зовущая `toString`, теряла бы граммы молча.
        weight: reading.weight.toStringAsFixed(3),
        unit: reading.unit.name,
        // Порядок ветвей — не оформление. Зашкал **вперёд** беды и вперёд
        // устойчивости: перегруженные весы умеют присылать «стабильно», и
        // слово «стабильно» на зашкале — прямая неправда.
        status: switch (reading) {
          final r when r.isOverload => ScalesReadingStatus.overload,
          final r when r.hasError => ScalesReadingStatus.failed,
          final r when r.isStable => ScalesReadingStatus.stable,
          _ => ScalesReadingStatus.unstable,
        },
        errorMessage: reading.errorMessage,
      );

  /// Два кадра **неотличимы на экране**.
  ///
  /// Сравниваются ровно те величины, которые вкладка показывает, и ни одной
  /// сверх: сравни здесь объекты целиком, повтор перестал бы сниматься от
  /// любого невидимого поля — скажем, от признака «вес введён руками», — и
  /// правило «не повторяться» тихо перестало бы работать вовсе.
  static bool _sameOnScreen(ScalesDiagnosticsView a, ScalesDiagnosticsView b) =>
      a.bound == b.bound &&
      a.port == b.port &&
      a.baudRate == b.baudRate &&
      a.protocol == b.protocol &&
      a.connected == b.connected &&
      (a.reading == null) == (b.reading == null) &&
      a.reading?.weight == b.reading?.weight &&
      a.reading?.unit == b.reading?.unit &&
      a.reading?.status == b.reading?.status &&
      a.reading?.errorMessage == b.reading?.errorMessage;
}

/// Прореживание кадров подписки: первый сразу, дальше не чаще [window], и
/// **последний не теряется никогда**.
///
/// # Почему не «отбрасывать лишнее» и не `Stream.periodic`
///
/// Потому что отброшенным оказался бы ровно тот кадр, ради которого вкладку
/// и открывают. Взвешивание кончается тем, что вес **устанавливается** и
/// прибор замолкает: последнее показание окна — это и есть установившийся
/// вес, число, по которому продают товар. Прореживание без хвоста показало
/// бы предпоследний вес и называло его устоявшимся — то есть врало бы именно
/// в той цифре, за которой пришли.
///
/// Поэтому окно **закрывается досылкой**: если за время окна пришёл новый
/// кадр, он уйдёт по истечении окна, даже когда источник после этого умолк
/// навсегда.
///
/// # Чего это НЕ делает
///
/// Не снимает повторов: два одинаковых кадра подряд для него разные кадры.
/// Повторы снимает `distinct` перед ним, и у двух правил разные вопросы —
/// «одно и то же?» и «не слишком ли часто?».
///
/// Не обещает и равномерности: кадры идут по источнику, а не по таймеру, и
/// молчащий прибор не порождает ни одного. Именно это и нужно —
/// простаивающая вкладка обязана стоить ноль кадров.
Stream<T> thinnedFrames<T>(Stream<T> source, Duration window) {
  StreamSubscription<T>? subscription;
  Timer? timer;
  late StreamController<T> out;
  T? held;
  var hasHeld = false;
  var windowOpen = false;
  var sourceDone = false;

  void closeIfDrained() {
    if (sourceDone && !hasHeld && !out.isClosed) {
      timer?.cancel();
      timer = null;
      out.close();
    }
  }

  void onWindowEnd() {
    if (hasHeld) {
      final value = held as T;
      held = null;
      hasHeld = false;
      if (!out.isClosed) out.add(value);
      // Новое окно открывается только после досылки: иначе за досылкой сразу
      // же мог бы уйти следующий кадр, и предел «не чаще окна» нарушался бы
      // ровно там, где поток плотнее всего.
      timer = Timer(window, onWindowEnd);
      closeIfDrained();
    } else {
      windowOpen = false;
      timer = null;
      closeIfDrained();
    }
  }

  out = StreamController<T>(
    onListen: () {
      subscription = source.listen(
        (value) {
          if (out.isClosed) return;
          if (windowOpen) {
            // Держим только последнее: промежуточные показания движущейся
            // чаши никому не нужны, нужно то, на котором она остановилась.
            held = value;
            hasHeld = true;
            return;
          }
          windowOpen = true;
          out.add(value);
          timer = Timer(window, onWindowEnd);
        },
        onError: (Object error, StackTrace stack) {
          if (!out.isClosed) out.addError(error, stack);
        },
        onDone: () {
          sourceDone = true;
          closeIfDrained();
        },
      );
    },
    onCancel: () async {
      timer?.cancel();
      timer = null;
      await subscription?.cancel();
    },
  );

  return out.stream;
}
