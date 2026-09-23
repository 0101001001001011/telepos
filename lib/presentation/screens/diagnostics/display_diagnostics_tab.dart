import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/domain/diagnostics/hardware_diagnostics.dart';
import 'package:telepos/l10n/app_localizations.dart';

/// Что касса отправляла на дисплей покупателя.
///
/// # Чего эта вкладка НЕ доказывает
///
/// Что покупатель это увидел. Канал односторонний: запись в порт прошла — и
/// всё. Погасший или отключённый дисплей отсюда неотличим от исправного, и
/// подпись говорит это прямо — та же граница, что у денежного ящика.
///
/// # Почему вкладка больше не знает журнала (правка пункта 4 плана)
///
/// `CustomerDisplayJournal` живёт в `lib/hardware/`, которого в браузерной
/// сборке быть не может, — и на планшете этой вкладки не было вовсе.
/// Теперь между вкладкой и кассой стоит порт
/// [HardwareDiagnosticsRepository] с двумя реализациями, а **файл вкладки
/// один на обе поверхности**: две похожих вкладки расходятся молча.
///
/// # Ни одного правила эта вкладка не решает
///
/// Ни того, что показывать текущим («последняя принятая» —
/// [DisplayDiagnosticsView.current], считает журнал кассы), ни того, в каком
/// виде записана сумма (той же записью, что ушла в порт). Реши вкладка хоть
/// что-нибудь из этого сама, правило жило бы в двух местах — а на второй
/// раскладке суммы журнал уже обжигался, показывая «1250» там, где на стекле
/// «1250.00».
class DisplayDiagnosticsTab extends StatefulWidget {
  const DisplayDiagnosticsTab({super.key});

  @override
  State<DisplayDiagnosticsTab> createState() => _DisplayDiagnosticsTabState();
}

class _DisplayDiagnosticsTabState extends State<DisplayDiagnosticsTab> {
  /// Подписка — один раз на жизнь состояния, не в `build`: иначе поток QUIC
  /// переоткрывался бы на каждую перерисовку.
  late final Stream<DisplayDiagnosticsView>? _lines = _watch();

  Stream<DisplayDiagnosticsView>? _watch() {
    // Единственная законная развилка: сборка без порта существует, и ей
    // вкладка говорит словами.
    if (!GetIt.I.isRegistered<HardwareDiagnosticsRepository>()) return null;
    return GetIt.I<HardwareDiagnosticsRepository>().watchDisplay();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final stream = _lines;
    if (stream == null) {
      return _Note(text: l10n.errorDiagnosticsUnavailable);
    }

    return StreamBuilder<DisplayDiagnosticsView>(
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
          return _Note(text: l10n.diagnosticsAskFailed('${snapshot.error}'));
        }
        final view = snapshot.data;
        if (view == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!view.available) {
          return _Note(
            key: const ValueKey('display-diagnostics-unavailable'),
            text: l10n.displayDiagnosticsUnavailable,
          );
        }
        final lines = view.lines;
        if (lines.isEmpty) {
          return _Note(
            key: const ValueKey('display-diagnostics-empty'),
            text: l10n.displayDiagnosticsEmpty,
          );
        }

        final current = view.current;

        return ListView.builder(
          key: const ValueKey('display-diagnostics-list'),
          padding: const EdgeInsets.all(12),
          itemCount: lines.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              // Отдельной карточкой — то, что на стекле сейчас: остальные
              // строки уже сменились, и читать их как текущее состояние
              // значило бы принять историю за настоящее.
              return Card(
                key: const ValueKey('display-diagnostics-current'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.displayDiagnosticsCurrent,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        current == null ? '—' : _shown(l10n, current),
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              );
            }
            if (index == 1) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 12,
                ),
                child: Text(
                  l10n.displayDiagnosticsCaveat,
                  style: theme.textTheme.bodySmall,
                ),
              );
            }

            final line = lines[index - 2];
            final scheme = theme.colorScheme;
            return ListTile(
              dense: true,
              leading: Icon(
                line.accepted ? Icons.check_circle_outline : Icons.block,
                color: line.accepted ? scheme.primary : scheme.error,
              ),
              title: Text(_shown(l10n, line)),
              subtitle: Text(
                '${_time(line.at)} · ${_callName(l10n, line.kind)}'
                '${line.refusal == null ? '' : '\n${line.refusal}'}',
              ),
              isThreeLine: line.refusal != null,
            );
          },
        );
      },
    );
  }

  /// Текст без содержания (приветствие, очистка) показывается своим именем —
  /// пустая строка в списке выглядела бы потерянной записью.
  static String _shown(AppLocalizations l10n, DisplayLineDiagnostics line) =>
      line.text.isEmpty ? _callName(l10n, line.kind) : line.text;

  static String _time(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}:'
      '${at.second.toString().padLeft(2, '0')}';

  /// Подпись вызова переводится **здесь**, из перечня порта: по проводу он
  /// едет именем значения. Слово, зашитое кассой, казахский наладчик
  /// прочитал бы по-русски.
  static String _callName(AppLocalizations l10n, DisplayCallKind call) =>
      switch (call) {
        DisplayCallKind.price => l10n.displayDiagnosticsCallPrice,
        DisplayCallKind.total => l10n.displayDiagnosticsCallTotal,
        DisplayCallKind.change => l10n.displayDiagnosticsCallChange,
        DisplayCallKind.text => l10n.displayDiagnosticsCallText,
        DisplayCallKind.welcome => l10n.displayDiagnosticsCallWelcome,
        DisplayCallKind.clear => l10n.displayDiagnosticsCallClear,
      };
}

class _Note extends StatelessWidget {
  const _Note({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ),
  );
}
