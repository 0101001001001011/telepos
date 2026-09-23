import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/domain/diagnostics/hardware_diagnostics.dart';
import 'package:telepos/domain/print/print_job.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/app/theme/app_typography.dart';

/// Что касса **действительно отправила** в чековый принтер.
///
/// # Зачем этот экран существует
///
/// Требование заказчика 2026-09-19: «при запуске чтобы можно было всё реально
/// продиагностировать и понять, что всё работает». Сформулировано оно было
/// через эмуляцию — «когда используем эмуляцию, чеки должны выводиться на
/// экран», — но к эмуляции не привязано и привязано быть не может.
///
/// **Почему не «режим эмуляции».** Подстановка эмулятора идёт **адресом**
/// (`test/emulators/README.md`): за портом стоит `ipAddress`, и кто там
/// отвечает — прибор или процесс на петле — кассе неизвестно и знать не
/// нужно. Экран, ведущий себя иначе «в режиме эмуляции», был бы вторым
/// путём, расходящимся с настоящим молча, — ровно тем дефектом, против
/// которого весь раздел эмуляторов и написан.
///
/// **Почему это нужно и на живой кассе.** Принтер зажевал бумагу, чек не
/// вышел — первый вопрос кассира и наладчика один: «а что мы вообще
/// послали?». До этого экрана ответить было нечем: байты живут в задании
/// очереди и человеку не показываются нигде.
///
/// # Почему вкладка больше не знает ни очереди, ни байтов
///
/// **Это правка пункта «Достижимость с браузерного терминала» плана
/// `2026-09-19-hardware-diagnostics.md`**, и она не косметическая.
///
/// До неё вкладка спрашивала у `GetIt` две кассовых службы — `PrintQueue` и
/// `ReceiptPrintService` — и сама разбирала `payloadBytes` вызовом
/// `renderEscPosAsText`. Обе службы живут в `lib/domain/`+`lib/data/`, а
/// разборщик — в `lib/hardware/`, которого в браузерной сборке быть не может
/// (сторож `browser_routes_test`, `_forbiddenWebRoots`). На планшете вкладка
/// поэтому говорила «очередь печати на этом рабочем месте не настроена» —
/// честно, но бесполезно: наладчик с планшетом не видел ничего.
///
/// Теперь между вкладкой и кассой стоит один доменный порт
/// [HardwareDiagnosticsRepository] с двумя реализациями —
/// `LocalHardwareDiagnostics` на кассе и `WtHardwareDiagnostics` по проводу.
/// Вкладка не различает их ничем, и **это тот же самый файл** на обеих
/// поверхностях: второй вкладки, «браузерной», не заведено нарочно — две
/// похожих вкладки разошлись бы молча, и первым бы это увидел наладчик.
///
/// # Главное правило: на экране — ТЕ ЖЕ байты, и разбирает их КАССА
///
/// [PrintJobDiagnostics.text] — разбор `payloadBytes` **того самого**
/// задания, которое ушло (или уйдёт) в порт, сделанный единственным
/// разборщиком дерева. Не из чека в базе, не из шаблона, не своим
/// форматированием.
///
/// Разбор перенесён на кассу не ради браузера, а ради того же свойства:
/// разбери его вкладка, у текста чека на экране появился бы второй родитель.
/// Предпросмотр шаблона уже однажды был **второй раскладкой** и разошёлся с
/// бумагой — разбор в докстринге `escpos_text_preview.dart`. Равенство
/// «экран = бумага» закреплено пробой через настоящий сокет
/// (`test/unit/hardware/receipt_template_wire_test.dart`), и эта вкладка
/// обязана число раскладок **не увеличить**.
///
/// # Чего эта вкладка НЕ доказывает
///
/// Что чек вышел на бумаге. Состояние — это судьба задания в очереди кассы,
/// то есть чем кончилась **отправка**; бумаги в лотке касса не видит ни в
/// каком режиме, и делать вид, что видит, было бы хуже молчания.
class PrinterDiagnosticsTab extends StatefulWidget {
  const PrinterDiagnosticsTab({super.key});

  @override
  State<PrinterDiagnosticsTab> createState() => _PrinterDiagnosticsTabState();
}

class _PrinterDiagnosticsTabState extends State<PrinterDiagnosticsTab> {
  /// Подписка заводится **один раз на жизнь состояния**, а не в `build`:
  /// `StreamBuilder`, которому поток пересоздают на каждой перерисовке,
  /// переоткрывал бы поток QUIC в браузере на каждый кадр.
  late final Stream<PrinterDiagnosticsView>? _jobs = _watch();

  Stream<PrinterDiagnosticsView>? _watch() {
    // Единственная развилка «есть привязка / нет привязки», оставшаяся во
    // вкладке, и она **законна**: сборка без привязанного порта существует
    // (голый процесс `bin/telepos_backend.dart` без контейнера
    // зависимостей), и такой сборке вкладка говорит словами. Пустой список
    // был бы хуже: «касса ничего не печатала» и «спросить не у кого» — для
    // наладчика разные ответы, и на первом он пошёл бы искать беду в
    // принтере, которого никто не спрашивал.
    if (!GetIt.I.isRegistered<HardwareDiagnosticsRepository>()) return null;
    return GetIt.I<HardwareDiagnosticsRepository>().watchPrinter();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stream = _jobs;
    if (stream == null) {
      return _Empty(text: l10n.errorDiagnosticsUnavailable);
    }
    return StreamBuilder<PrinterDiagnosticsView>(
      stream: stream,
      builder: (context, snapshot) {
        // Отказ кассы — **названной причиной**, а не спиннером.
        //
        // Найдено живой приёмкой 2026-09-19: вкладка принтера крутилась
        // вечно, и причина («стенд: currentPaperWidth у принтера не
        // поднят») лежала в ошибке потока, которую эта ветвь молча
        // проглатывала. `snapshot.data == null` верно и когда кадра ещё
        // нет, и когда его уже не будет — два противоположных состояния
        // под одним видом. Наладчик читает спиннер как «сейчас придёт» и
        // ждёт; правильный ответ — «касса ответила отказом, вот каким».
        if (snapshot.hasError) {
          return _Empty(text: l10n.diagnosticsAskFailed('${snapshot.error}'));
        }
        final view = snapshot.data;
        if (view == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!view.available) {
          return _Empty(text: l10n.diagnosticsPrinterQueueMissing);
        }
        if (view.jobs.isEmpty) {
          return _Empty(text: l10n.diagnosticsPrinterNothingSent);
        }
        // Порядок задаёт касса (новые сверху) — обе поверхности обязаны
        // показывать один, и сортировка здесь была бы вторым местом, где он
        // решается.
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: view.jobs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _JobCard(job: view.jobs[i]),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

/// Одно задание: чем кончилось и что именно уехало.
class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});

  final PrintJobDiagnostics job;

  /// Состояние словами кассира, а не именем поля перечисления.
  ///
  /// Причина отказа приписывается **рядом**, а не вместо: «не напечатано»
  /// без причины — это то же молчание, ради снятия которого очередь и
  /// заводилась.
  String _state(AppLocalizations l10n) => switch (job.state) {
    PrintJobState.queued => l10n.diagnosticsJobQueued,
    PrintJobState.printing => l10n.diagnosticsJobPrinting,
    PrintJobState.printed => l10n.diagnosticsJobPrinted,
    PrintJobState.failed => l10n.diagnosticsJobFailed,
    PrintJobState.expired => l10n.diagnosticsJobExpired,
    PrintJobState.cancelled => l10n.diagnosticsJobCancelled,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final failed =
        job.state == PrintJobState.failed || job.state == PrintJobState.expired;
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        title: Text(job.id),
        subtitle: Text(
          '${_state(l10n)} · ${l10n.diagnosticsAttempts(job.attempts)}'
          '${job.failureReason == null ? '' : ' · ${job.failureReason}'}',
          style: TextStyle(color: failed ? scheme.error : null),
        ),
        children: [
          Container(
            width: double.infinity,
            color: scheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              // Моноширинным и без переносов: чек — это колонки, и
              // пропорциональный шрифт превратил бы диагностику в кашу
              // ровно там, где сверяют выравнивание сумм.
              child: Text(
                job.text,
                style: const TextStyle(
                  fontFamily: AppTypography.familyMono,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
