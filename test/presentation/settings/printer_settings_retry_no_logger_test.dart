/// Перехват повтора не роняет экран, **когда журнал не поднят** — задача
/// 16, круг правки 6.
///
/// # Почему это отдельный файл
///
/// `installLogger` ставит глобальный признак на весь изолят, и снять его
/// нечем. Пока эта проба жила в одном файле с той, что журнал ставит,
/// её смысл держался на **порядке объявления** — а порядок это не
/// утверждение, это соглашение. Разбор проверил хрупкость: перестановка
/// красила файл громко и по адресу (страховка `isLoggerReady, isFalse`
/// сработала), то есть дефекта не было. Но предел был, и снимается он
/// дёшево — отдельным файлом, где журнал не ставит никто.
///
/// # Что доказывается
///
/// `talker` — `late`, его назначает точка входа. Круг правки 4 позвал его
/// в перехвате **без** `isLoggerReady`, и перехват, чей собственный
/// комментарий обещает пережить сломанный контракт очереди, сам ронял
/// экран: исход не присваивался, отметка не ставилась, оператор не видел
/// ничего.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/domain/print/print_job.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/printer_settings_screen.dart';

void main() {
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
    GetIt.I.registerSingleton<PrintQueue>(
      _ThrowingQueue([job], StateError('очередь оторвалась')),
    );
  });

  tearDown(() async => GetIt.I.reset());

  testWidgets('журнал не поднят — экран всё равно жив и отвечает', (
    tester,
  ) async {
    expect(
      isLoggerReady,
      isFalse,
      reason:
          'страховка от вырождения: в этом файле журнал не ставит никто, '
          'и признак глобален на весь изолят',
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: const Scaffold(body: PrintQueueSection(terminalId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('print_job_retry_sale-3009')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('print_queue_extend_30m')));
    await tester.pumpAndSettle();

    // **Несущее утверждение — это.** Без `isLoggerReady` перехват падает
    // на `LateInitializationError` до присваивания исхода, и отметка не
    // появляется вовсе: оператор теряет единственный вид на очередь ровно
    // тогда, когда она встала.
    expect(
      find.textContaining('StateError'),
      findsWidgets,
      reason: 'отметка об исходе обязана появиться и без журнала',
    );
  });
}

/// Очередь, чей `retry` **бросает**. Таймеров не заводит вовсе — поэтому
/// проба не спорит со временем жизни очереди и идёт около секунды.
class _ThrowingQueue implements PrintQueue {
  _ThrowingQueue(this._jobs, this._boom);

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
