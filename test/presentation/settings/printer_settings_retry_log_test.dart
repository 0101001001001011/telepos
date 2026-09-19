/// Очередь, нарушившая свой контракт, оставляет след — задача 16, круг
/// правки 5.
///
/// # Что здесь доказывается
///
/// `PrintQueue.retry` обещает, что **каждый** отказ приходит значением.
/// Перехват в экране настроек стоит на случай, если реализация это
/// обещание нарушит, и его собственный комментарий говорит: экран обязан
/// пережить такую реализацию, иначе оператор теряет единственный вид на
/// очередь ровно тогда, когда она встала.
///
/// Круг правки 2 завернул текст исключения в `safeErrorText` — отсюда он
/// уезжает на экран, и нутру `SqliteException` там не место. Значит
/// оператору осталось бы слово «StateError», а причина — нигде. Круг
/// правки 4 добавил запись в журнал и **не покрыл её пробой**, объявив
/// пробу дорогой. Померено разбором и подтверждено здесь: проба стоит
/// около двух секунд, а «висящего будильника» нет вовсе — подменённая
/// очередь таймеров не заводит.
///
/// # Три утверждения разом
///
/// 1. экран **не падает**;
/// 2. на экране — безопасное имя типа, без нутра исключения;
/// 3. в журнале — само исключение.
///
/// Половина про «журнал не поднят» уехала в
/// `printer_settings_retry_no_logger_test.dart` (круг правки 6):
/// `installLogger` глобален на весь изолят, и держать обе половины в
/// одном файле значило бы опирать смысл на порядок объявления.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/domain/print/print_job.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/printer_settings_screen.dart';

void main() {
  late _CapturingLog observed;
  late _StubQueue queue;

  final job = PrintJob(
    id: 'sale-3009',
    terminalId: 1,
    posId: 1,
    payloadBytes: Uint8List.fromList(const [0x1B, 0x40]),
    createdAt: DateTime.utc(2026, 9, 7, 10),
    expiresAt: DateTime.utc(2026, 9, 7, 12),
    state: PrintJobState.failed,
    attempts: 3,
    failureReason: 'Нет бумаги',
  );

  setUp(() {
    observed = _CapturingLog();
    installLogger(Talker(observer: observed));
    queue = _StubQueue([job], StateError('очередь оторвалась'));
    GetIt.I.registerSingleton<PrintQueue>(queue);
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  Widget host() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('ru'),
    home: const Scaffold(body: PrintQueueSection(terminalId: 1)),
  );

  testWidgets('бросивший повтор не роняет экран и оставляет след', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('print_job_retry_sale-3009')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('print_queue_extend_30m')));
    await tester.pumpAndSettle();

    // 1. Экран жив. **Несущее здесь — отметка, а не `takeException`**
    //    (круг правки 6): проверено на диверсии — падение приходит
    //    раньше, чем проба доберётся сюда, и `takeException()` к этому
    //    моменту возвращает пустоту. Утверждение оставлено как дешёвая
    //    страховка от исключения, записанного **без** падения, но
    //    механизм, который его краснит, — следующая строка и проба в
    //    `printer_settings_retry_no_logger_test.dart`.
    expect(tester.takeException(), isNull);

    // 2. На экране — имя типа, без нутра.
    expect(find.textContaining('StateError'), findsWidgets);
    expect(find.textContaining('очередь оторвалась'), findsNothing);

    // 3. В журнале — само исключение.
    expect(
      observed.errors.where(
        (e) => e.contains('sale-3009') && e.contains('очередь оторвалась'),
      ),
      isNotEmpty,
      reason:
          'иначе нарушение контракта очередью не оставляет следа нигде: '
          'на экране имя типа, в журнале ничего',
    );
  });
}

/// Очередь, чей `retry` **бросает**. Таймеров не заводит вовсе — именно
/// поэтому проба не спорит со временем жизни очереди.
class _StubQueue implements PrintQueue {
  _StubQueue(this._jobs, this._boom);

  final List<PrintJob> _jobs;
  final Object _boom;

  @override
  Future<PrintSubmitOutcome> retry(
    String jobId, {
    required Duration extendBy,
  }) async => throw _boom;

  @override
  Stream<List<PrintJob>> watch({int? terminalId}) => Stream.value(_jobs);

  @override
  Future<PrintSubmitOutcome> submit(PrintJob job) async =>
      PrintSubmitOutcome.accepted(job.id);

  @override
  Future<bool> cancel(String jobId) async => true;
}

class _CapturingLog extends TalkerObserver {
  final List<String> errors = [];

  @override
  void onError(TalkerError err) => errors.add(err.generateTextMessage());

  @override
  void onException(TalkerException err) =>
      errors.add(err.generateTextMessage());

  @override
  void onLog(TalkerData log) {
    if (log.logLevel == LogLevel.error) {
      errors.add('${log.generateTextMessage()} ${log.exception ?? ''}');
    }
  }
}
