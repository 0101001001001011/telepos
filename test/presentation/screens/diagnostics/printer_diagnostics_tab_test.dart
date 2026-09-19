/// Диагностика печати показывает **те же байты**, что ушли в порт.
///
/// # Почему это несущая проба, а не украшение
///
/// Экран диагностики существует ради одного ответа: «что касса на самом
/// деле отправила в принтер». Ответ, собранный **не из тех байтов**, хуже
/// отсутствия экрана: он выглядит ответом.
///
/// У проекта это уже случалось. Предпросмотр шаблона чека был второй,
/// независимой раскладкой и разошёлся с бумагой — перенос ссылки проверки
/// чека на экране был, а на ленте обрезался по ширине (разбор в докстринге
/// `lib/hardware/printer/escpos_text_preview.dart`). Диагностика — третье
/// место, где соблазн «нарисовать красиво» тот же, а цена выше: по ней
/// будут судить, работает ли касса.
///
/// Поэтому проба сверяет вывод экрана с [renderEscPosAsText] тех же самых
/// байтов, а диверсия «нарисовать своим форматированием» обязана её
/// покрасить.
///
/// # Что изменилось 2026-09-19
///
/// Вкладка перестала спрашивать `PrintQueue` и `ReceiptPrintService` и
/// перестала разбирать байты сама — между ней и кассой встал порт
/// `HardwareDiagnosticsRepository`, а разбор переехал в его кассовую
/// реализацию (пункт «Достижимость с браузерного терминала» плана
/// `2026-09-19-hardware-diagnostics.md`).
///
/// **Проба от этого не ослабла.** Под вкладку ставится настоящая
/// `LocalHardwareDiagnostics` над теми же подставными очередью и службой
/// печати — то есть сверяется тот же путь, каким вкладка живёт на кассе, и
/// диверсия «нарисовать своим форматированием» красит его так же. Изменился
/// только слой, где разбор произошёл; утверждение прежнее: **на экране —
/// разбор ровно тех байтов, что ушли в порт**.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/diagnostics/local_hardware_diagnostics.dart';
import 'package:telepos/domain/diagnostics/hardware_diagnostics.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/domain/print/print_job.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/hardware/printer/escpos_text_preview.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/diagnostics/printer_diagnostics_tab.dart';

/// Кусок настоящего потока ESC/POS: сброс, кодовая страница, выравнивание,
/// строки, протяжка и рез. Собран байтами, а не строкой, — экран обязан
/// уметь именно поток, а не заранее приготовленный текст.
Uint8List _receiptBytes() {
  final bytes = <int>[
    0x1B, 0x40, // ESC @ — сброс
    0x1B, 0x74, 17, // ESC t 17 — CP866
    0x1B, 0x61, 1, // ESC a 1 — по центру
  ];
  bytes.addAll('MAGAZIN\n'.codeUnits);
  bytes.addAll([0x1B, 0x61, 0]); // по левому краю
  bytes.addAll('MOLOKO        500.00\n'.codeUnits);
  bytes.addAll([0x1D, 0x56, 1]); // GS V 1 — рез
  return Uint8List.fromList(bytes);
}

PrintJob _job({
  required Uint8List payload,
  PrintJobState state = PrintJobState.printed,
  String? failureReason,
}) => PrintJob(
  id: 't1/p1/s1/sale/7001/c1',
  terminalId: 1,
  posId: 1,
  payloadBytes: payload,
  createdAt: DateTime(2026, 9, 19, 10),
  expiresAt: DateTime(2026, 9, 19, 10, 30),
  state: state,
  failureReason: failureReason,
);

void main() {
  setUp(() => GetIt.I.reset());
  tearDown(() => GetIt.I.reset());

  /// Настоящая кассовая реализация порта над подставными очередью и службой
  /// печати — тот же путь, каким вкладка живёт на кассе.
  void bindPort({PrintQueue? queue, ReceiptPaperWidth? width}) {
    GetIt.I.registerSingleton<HardwareDiagnosticsRepository>(
      LocalHardwareDiagnostics(
        terminals: _SelfTerminals(),
        queue: queue,
        printer: width == null ? null : _FixedWidthPrinter(width),
      ),
    );
  }

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: PrinterDiagnosticsTab()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('чек на экране — разбор тех же байтов, что ушли в порт', (
    tester,
  ) async {
    final payload = _receiptBytes();
    bindPort(
      queue: _FakeQueue([_job(payload: payload)]),
      width: ReceiptPaperWidth.mm80,
    );

    await mount(tester);
    // Задание свёрнуто: чек показывается по нажатию, чтобы список из сотни
    // заданий оставался списком.
    await tester.tap(find.text('t1/p1/s1/sale/7001/c1'));
    await tester.pumpAndSettle();

    final expected = renderEscPosAsText(payload, width: 48);
    expect(
      find.text(expected),
      findsOneWidget,
      reason:
          'экран обязан показывать разбор ровно тех байтов задания, а не '
          'свою раскладку: иначе диагностика отвечает на вопрос «что мы '
          'отправили» тем, чего мы не отправляли',
    );
    // Опорное утверждение: в разборе действительно есть содержимое чека —
    // иначе сверка выше была бы сверкой двух пустых строк.
    expect(expected, contains('MOLOKO'));
  });

  testWidgets('ширина берётся у привязки принтера, а не литералом', (
    tester,
  ) async {
    final payload = _receiptBytes();
    bindPort(
      queue: _FakeQueue([_job(payload: payload)]),
      width: ReceiptPaperWidth.mm58,
    );

    await mount(tester);
    await tester.tap(find.text('t1/p1/s1/sale/7001/c1'));
    await tester.pumpAndSettle();

    expect(
      find.text(renderEscPosAsText(payload, width: 32)),
      findsOneWidget,
      reason:
          'узкая лента переносит строки иначе; экран, рисующий всегда в 48 '
          'колонок, показал бы чек, которого на бумаге не было',
    );
    // Обратный полюс: широкая раскладка того же чека на экране не показана.
    expect(find.text(renderEscPosAsText(payload, width: 48)), findsNothing);
  });

  testWidgets('отказ назван причиной, а не общим словом', (tester) async {
    bindPort(
      queue: _FakeQueue([
        _job(
          payload: _receiptBytes(),
          state: PrintJobState.failed,
          failureReason: 'принтер не отвечает по адресу 127.0.0.1:8987',
        ),
      ]),
      width: ReceiptPaperWidth.mm80,
    );

    await mount(tester);

    expect(
      find.textContaining('принтер не отвечает по адресу 127.0.0.1:8987'),
      findsOneWidget,
      reason:
          '«не напечатано» без причины — то самое молчание, ради снятия '
          'которого очередь печати и заводилась',
    );
  });

  testWidgets('очереди печати нет — сказано словами, а не пустотой', (
    tester,
  ) async {
    // Порт есть, очереди нет: касса собрана, принтер не настроен.
    bindPort();

    await mount(tester);
    expect(find.textContaining('не настроена'), findsOneWidget);
  });

  testWidgets(
    'порта нет вовсе — это ДРУГАЯ фраза, а не «очередь не настроена»',
    (tester) async {
      // Ни одной привязки: голый процесс `bin/telepos_backend.dart` стоит
      // именно так. Сказать здесь «очередь печати не настроена» значило бы
      // отправить наладчика настраивать принтер там, где беда в сборке.
      await mount(tester);

      expect(find.textContaining('спросить не у кого'), findsOneWidget);
      expect(find.textContaining('не настроена'), findsNothing);
    },
  );
}

/// Рабочее место кассы: чьи задания показывать, решает **касса по себе**, а
/// не довод вкладки (докстринг `HardwareDiagnosticsRepository.watchPrinter`).
class _SelfTerminals implements TerminalRepository {
  @override
  Future<Terminal> self() async =>
      const Terminal(id: 1, name: 'Касса', pointMode: PointMode.cashier);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'проба диагностики: ${invocation.memberName} у терминалов не поднят',
  );
}

class _FakeQueue implements PrintQueue {
  _FakeQueue(this._jobs);

  final List<PrintJob> _jobs;

  @override
  Stream<List<PrintJob>> watch({int? terminalId}) => Stream.value(_jobs);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'проба диагностики: ${invocation.memberName} у очереди не поднят',
  );
}

class _FixedWidthPrinter implements ReceiptPrintService {
  _FixedWidthPrinter(this._width);

  final ReceiptPaperWidth _width;

  @override
  Future<ReceiptPaperWidth> currentPaperWidth() async => _width;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'проба диагностики: ${invocation.memberName} у печати не поднят',
  );
}
