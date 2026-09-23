import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/domain/diagnostics/hardware_diagnostics.dart';
import 'package:telepos/l10n/app_localizations.dart';

/// Сколько показывают весы — живьём.
///
/// Требование заказчика 2026-09-19 дословно: «если весы, то поле ввода веса».
/// Поле здесь **только на чтение**, и это не упрощение: вес задаётся весами,
/// а на эмуляторе — его пультом. Поле, в которое можно вписать вес руками,
/// было бы вторым источником веса в кассе, и первая же продажа по нему ушла
/// бы мимо прибора.
///
/// # Почему вкладка больше не знает `ScalesService` (правка пункта 4 плана)
///
/// Служба весов живёт в `lib/hardware/`, которого в браузерной сборке быть
/// не может, — и на планшете этой вкладки не было вовсе. Теперь между
/// вкладкой и прибором стоит порт [HardwareDiagnosticsRepository] с двумя
/// реализациями, а файл вкладки **один на обе поверхности**.
///
/// # Кадры прорежены, и прореживает их касса
///
/// `ScalesService` опрашивает порт каждые 200 мс; кадр на каждое показание
/// был бы потоком ради вкладки, которую смотрят минуту. Прореживание живёт
/// **в кассовой реализации порта**, до провода: повторы сняты, остаток режется
/// окном, последний кадр досылается всегда. Разбор решения — в докстринге
/// [HardwareDiagnosticsRepository.watchScales].
///
/// Вкладка об этом не знает ничего и знать не должна: прореживай она сама,
/// кассовая поверхность показывала бы одну частоту, планшет другую.
///
/// # Чего эта вкладка НЕ доказывает
///
/// Что весы верны. Касса читает то, что прибор о себе сообщил; поверка — дело
/// поверителя, и «0.120 kg» здесь означает «весы прислали 120 г», а не «на
/// чаше 120 г».
///
/// И **частоту прибора она тоже не показывает**: кадры прорежены, и считать
/// по ним, как часто отвечают весы, нельзя.
///
/// # Почему «весы не привязаны» сказано словами
///
/// Пустое поле на кассе без весов неотличимо от весов, молчащих из-за
/// оборванного провода. Это ровно тот случай, когда пустота отвечает «ничего
/// нет» на два противоположных вопроса.
class ScalesDiagnosticsTab extends StatefulWidget {
  const ScalesDiagnosticsTab({super.key});

  @override
  State<ScalesDiagnosticsTab> createState() => _ScalesDiagnosticsTabState();
}

class _ScalesDiagnosticsTabState extends State<ScalesDiagnosticsTab> {
  /// Подписка — один раз на жизнь состояния: поток весов живёт ровно столько,
  /// сколько открыта вкладка, и пересоздавать его на каждую перерисовку
  /// значило бы переоткрывать поток QUIC по кадру.
  late final Stream<ScalesDiagnosticsView>? _readings = _watch();

  Stream<ScalesDiagnosticsView>? _watch() {
    if (!GetIt.I.isRegistered<HardwareDiagnosticsRepository>()) return null;
    return GetIt.I<HardwareDiagnosticsRepository>().watchScales();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final stream = _readings;
    if (stream == null) {
      return _Note(text: l10n.errorDiagnosticsUnavailable);
    }

    return StreamBuilder<ScalesDiagnosticsView>(
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
        if (!view.bound) {
          return _Note(
            key: const ValueKey('scales-diagnostics-unbound'),
            text: l10n.scalesDiagnosticsUnbound,
          );
        }

        final reading = view.reading;

        return ListView(
          key: const ValueKey('scales-diagnostics-live'),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    Text(
                      l10n.scalesDiagnosticsWeight,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      key: const ValueKey('scales-diagnostics-weight'),
                      // Вес приезжает **готовой строкой с тремя знаками**:
                      // три знака — разрешение прибора, а `Decimal` печатает
                      // 1.250 как «1.25», и вкладка, форматирующая сама,
                      // теряла бы граммы молча. Форматирует касса, там же,
                      // где `ScalesReading.toString`.
                      reading == null
                          ? '—'
                          : '${reading.weight} ${reading.unit}',
                      style: theme.textTheme.displaySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      // Сочетание «зашкал/беда/устойчивость» разобрала
                      // касса, в том порядке приоритета, в каком его
                      // разбирала эта вкладка: перегруженные весы умеют
                      // присылать «стабильно». Второй разбор здесь был бы
                      // вторым ответом.
                      switch (reading) {
                        null => l10n.scalesDiagnosticsSilent,
                        final r when r.status == ScalesReadingStatus.overload =>
                          l10n.scalesDiagnosticsOverload,
                        final r when r.status == ScalesReadingStatus.failed =>
                          r.errorMessage ?? l10n.scalesDiagnosticsSilent,
                        final r when r.status == ScalesReadingStatus.stable =>
                          l10n.scalesDiagnosticsStable,
                        _ => l10n.scalesDiagnosticsSettling,
                      },
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.usb),
              title: Text(l10n.scalesDiagnosticsPort),
              subtitle: Text(
                '${view.port ?? '—'} · ${view.baudRate} '
                '${l10n.scalesDiagnosticsBaudSuffix} · ${view.protocol}\n'
                '${view.connected ? l10n.scalesDiagnosticsConnected : l10n.scalesDiagnosticsDisconnected}',
              ),
              isThreeLine: true,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.scalesDiagnosticsCaveat,
              style: theme.textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
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
