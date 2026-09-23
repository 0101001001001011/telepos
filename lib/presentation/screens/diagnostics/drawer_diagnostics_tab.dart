import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/domain/diagnostics/hardware_diagnostics.dart';
import 'package:telepos/l10n/app_localizations.dart';

/// Когда кассу просили открыть ящик и чем это кончилось.
///
/// # Почему эта вкладка вообще понадобилась
///
/// Остальные вкладки показывают то, что уже где-то лежало: задания печати — в
/// очереди, обмен с оператором — в очереди фискализации. Про ящик не лежало
/// **ничего**: касса звала порт и забывала. На стенде это было видно журналом
/// эмулятора, на живой кассе — ничем, и жалоба «ящик не открылся» не имела ни
/// одного следа, по которому её можно было бы разобрать.
///
/// # Граница знания кассы названа прямо
///
/// «Команда принята» — не «ящик открылся». Обратной связи от соленоида нет ни
/// на одном из двух путей, и подпись на экране говорит именно это. Показать
/// здесь «Открыт» было бы уютнее и было бы неправдой: касса этого не знает.
///
/// # Почему вкладка больше не знает журнала (правка пункта 4 плана)
///
/// До неё вкладка брала `CashDrawerJournal` прямо из `GetIt`. Журнал живёт в
/// `lib/hardware/`, которого в браузерной сборке быть не может (сторож
/// `browser_routes_test`, `_forbiddenWebRoots`), — и на планшете этой вкладки
/// не было вовсе, а её отсутствие наладчик читал как «у этой кассы ящика
/// нет».
///
/// Теперь между вкладкой и кассой стоит тот же порт
/// [HardwareDiagnosticsRepository], что у принтера и оператора, с двумя
/// реализациями. **Это тот же самый файл** на обеих поверхностях: второй,
/// «браузерной», копии не заведено нарочно — две похожих вкладки расходятся
/// молча, и первым это увидел бы наладчик, у которого экран кассы и экран
/// планшета показывают разное про один и тот же импульс.
///
/// # Чего эта вкладка НЕ показывает
///
/// Кто открывал ящик и зачем. Это учётный вопрос со своим журналом и своим
/// правом; здесь — только последние попытки текущего запуска кассы.
class DrawerDiagnosticsTab extends StatefulWidget {
  const DrawerDiagnosticsTab({super.key});

  @override
  State<DrawerDiagnosticsTab> createState() => _DrawerDiagnosticsTabState();
}

class _DrawerDiagnosticsTabState extends State<DrawerDiagnosticsTab> {
  /// Подписка заводится **один раз на жизнь состояния**, а не в `build`:
  /// поток, пересоздаваемый на каждой перерисовке, переоткрывал бы поток QUIC
  /// в браузере на каждый кадр.
  late final Stream<DrawerDiagnosticsView>? _kicks = _watch();

  Stream<DrawerDiagnosticsView>? _watch() {
    // Единственная развилка, оставшаяся во вкладке, и она законна: сборка без
    // порта существует (голый процесс `bin/telepos_backend.dart` без
    // контейнера зависимостей), и такой сборке вкладка говорит словами.
    if (!GetIt.I.isRegistered<HardwareDiagnosticsRepository>()) return null;
    return GetIt.I<HardwareDiagnosticsRepository>().watchDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stream = _kicks;
    if (stream == null) {
      return _Note(text: l10n.errorDiagnosticsUnavailable);
    }

    return StreamBuilder<DrawerDiagnosticsView>(
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
        // «Памяти об импульсах нет» и «ящик не звали» — разные ответы, и
        // второй на месте первого отправил бы наладчика искать обрыв в
        // проводке исправного ящика.
        if (!view.available) {
          return _Note(
            key: const ValueKey('drawer-diagnostics-unavailable'),
            text: l10n.drawerDiagnosticsUnavailable,
          );
        }
        final kicks = view.kicks;
        if (kicks.isEmpty) {
          return _Note(
            key: const ValueKey('drawer-diagnostics-empty'),
            text: l10n.drawerDiagnosticsEmpty,
          );
        }

        // Порядок задаёт касса (новые сверху): обе поверхности обязаны
        // показывать один, и сортировка здесь была бы вторым местом, где он
        // решается.
        return ListView.separated(
          key: const ValueKey('drawer-diagnostics-list'),
          padding: const EdgeInsets.all(12),
          itemCount: kicks.length + 1,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  l10n.drawerDiagnosticsCaveat,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }
            final kick = kicks[index - 1];
            final scheme = Theme.of(context).colorScheme;
            return ListTile(
              dense: true,
              leading: Icon(
                kick.accepted ? Icons.check_circle_outline : Icons.block,
                color: kick.accepted ? scheme.primary : scheme.error,
              ),
              title: Text(
                kick.accepted
                    ? l10n.drawerDiagnosticsAccepted
                    : l10n.drawerDiagnosticsRefused,
              ),
              subtitle: Text(
                '${_time(kick.at)} · ${_pathName(l10n, kick.path)}'
                '${kick.note == null ? '' : '\n${kick.note}'}',
              ),
              isThreeLine: kick.note != null,
            );
          },
        );
      },
    );
  }

  static String _time(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}:'
      '${at.second.toString().padLeft(2, '0')}';

  /// Путь переводится **здесь**, из перечня порта: по проводу он едет именем
  /// значения, а не словом по-русски. Слово, зашитое кассой, казахский
  /// наладчик прочитал бы по-русски, и сторож равенства словарей такого не
  /// ловит.
  static String _pathName(AppLocalizations l10n, DrawerKickPath path) =>
      switch (path) {
        DrawerKickPath.serialPort => l10n.drawerDiagnosticsViaSerial,
        DrawerKickPath.viaPrinter => l10n.drawerDiagnosticsViaPrinter,
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
