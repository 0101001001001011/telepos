import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/app/theme/app_colors.dart';

import 'package:telepos/domain/diagnostics/hardware_diagnostics.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/app/theme/app_typography.dart';

/// Что касса передала фискальному оператору и что он ответил.
///
/// # Почему две половины, а не одна
///
/// Очередь фискализации держит **только то, что не уехало**: ожидающие и
/// отказанные. Успешный документ из неё уходит. Экран, показывающий одну
/// очередь, на исправной кассе пуст — и эта пустота неотличима от «оператор
/// не настроен вовсе». А наладчику при запуске нужен ровно обратный ответ:
/// «да, документы уходят, вот последний».
///
/// Поэтому здесь две половины:
///
/// * **Принято оператором** — последние документы с фискальным признаком.
///   Это доказательство работы, а не отсутствия беды;
/// * **В очереди** — ожидающие и отказанные, с ключом идемпотентности,
///   числом попыток и **дословной** последней ошибкой.
///
/// # Чем это отличается от экрана нефискализованных чеков
///
/// Тот экран — рабочее место кассира: две кнопки, «повторить» и «списать»,
/// и он про **действие**. Этот — про **обмен**: что именно ушло в теле
/// запроса. Пересечение по строкам есть, назначение разное, и сливать их
/// нельзя: кнопка «списать» на диагностическом экране превратила бы разбор
/// в редактирование.
///
/// # Почему вкладка больше не знает ни базы, ни очереди
///
/// **Правка пункта «Достижимость с браузерного терминала» плана
/// `2026-09-19-hardware-diagnostics.md`.** До неё вкладка спрашивала у
/// `GetIt` две кассовых службы — `AppDatabase` и `FiscalQueueStore`, — обе
/// из `lib/data/`, которого в браузерной сборке быть не может (сторож
/// `browser_routes_test`). На планшете она поэтому говорила «фискальный
/// оператор на этой кассе не настроен»: честно, но для наладчика с планшетом
/// бесполезно, а звучало это как утверждение о кассе, а не о вкладке.
///
/// Теперь между вкладкой и кассой стоит доменный порт
/// [HardwareDiagnosticsRepository] с двумя реализациями — кассовой и по
/// проводу, — и **это тот же самый файл** на обеих поверхностях. Второй,
/// «браузерной», вкладки не заведено нарочно: две похожих разошлись бы
/// молча.
///
/// # Тело запроса показывается как есть
///
/// Без переписывания в «человеческий вид»: диагностика фискального обмена —
/// это сверка с тем, что ждёт оператор, и приглаженное представление здесь
/// врёт ровно там, где его читают. Именно этого просил заказчик 2026-09-19 —
/// «подробные данные по ОФД-передаче».
///
/// Отступы расставляет **касса** ([FiscalQueuedDocument.payloadJson]), а не
/// эта вкладка: второй форматировщик разошёлся бы с первым на первой же
/// правке, и сверять с ожиданиями оператора пришлось бы два разных текста.
///
/// # Чего эта вкладка НЕ доказывает
///
/// Что документ дошёл до КГД. Она показывает то, что кассе ответил
/// **оператор** (или что касса выдала автономно по его правилам) — дальше
/// его пути касса не видит.
/// # Пометка эмулятора — по адресу оператора, а не по выключателю
///
/// Плашка «за этим адресом эмулятор» зажигается, когда
/// [FiscalSettings.resolvedBaseUrl] ведёт на **петлю**. Не когда включён
/// встроенный эмулятор: касса, направленная на эмулятор, запущенный руками из
/// командной строки, ничем не отличается — и обязана быть помечена так же.
/// Выключатель тут не источник правды, адрес — источник. Тот же приём и тот
/// же довод, что у плашки принтера на `diagnostics_screen.dart`.
///
/// Признак берётся у `FiscalSettingsSource` — у **того же** договора, по
/// которому касса выбирает провайдера, а не у хранилища настроек экрана: при
/// невыбранном операторе они расходятся (`StoreFiscalSettingsSource` падает на
/// адрес из `ThisPos`), и читать не ту половину значило бы не пометить ровно
/// ту кассу, которую пометить важнее всего.
///
/// **Чего плашка НЕ доказывает.** Что оператор поддельный: петлёй может
/// оказаться и настоящий локальный модуль фискализации, если такой когда-нибудь
/// поставят на саму кассу. Плашка утверждает ровно то, что написано, — адрес
/// ведёт на этот же компьютер, — и дальше смотрит человек. Обратное она не
/// доказывает тем более: эмулятор, поднятый на соседней машине, для кассы
/// выглядит обычным сетевым адресом, и пометки не будет.
class FiscalDiagnosticsTab extends StatefulWidget {
  const FiscalDiagnosticsTab({super.key});

  @override
  State<FiscalDiagnosticsTab> createState() => _FiscalDiagnosticsTabState();
}

class _FiscalDiagnosticsTabState extends State<FiscalDiagnosticsTab> {
  late Future<FiscalDiagnosticsView?> _snapshot = _read();

  /// `null` — порта нет вовсе; отличается от [FiscalDiagnosticsView
  /// .configured] `false`, который означает «порт есть, оператора нет».
  ///
  /// Единственная развилка `isRegistered` этой вкладки, и она **законна**:
  /// сборка без привязанного порта существует (голый процесс
  /// `bin/telepos_backend.dart` без контейнера зависимостей).
  Future<FiscalDiagnosticsView?> _read() async {
    if (!GetIt.I.isRegistered<HardwareDiagnosticsRepository>()) return null;
    return GetIt.I<HardwareDiagnosticsRepository>().fiscal();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Плашка стоит ВЫШЕ развилки «настроен / не настроен» нарочно: касса, у
    // которой адрес оператора смотрит на петлю, обязана быть помечена в обоих
    // случаях. Именно на ненастроенной её пропустить и обиднее — там-то и
    // заканчиваются проверки шаблона чека.
    return Column(
      children: [
        FutureBuilder<FiscalDiagnosticsView?>(
          future: _snapshot,
          builder: (context, snap) => snap.data?.onLoopback == true
              ? _EmulatorBanner()
              : const SizedBox.shrink(),
        ),
        Expanded(child: _body(context, l10n)),
      ],
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n) {
    return FutureBuilder<FiscalDiagnosticsView?>(
      future: _snapshot,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        // Отказ кассы — названной причиной. Разбор целиком — в тех же
        // строках вкладки принтера: до 2026-09-19 отказ был неотличим от
        // ожидания, и наладчик ждал кадра, которого уже не будет.
        if (snapshot.hasError) {
          return _Message(text: l10n.diagnosticsAskFailed('${snapshot.error}'));
        }
        final data = snapshot.data;
        if (data == null) {
          return _Message(text: l10n.errorDiagnosticsUnavailable);
        }
        if (!data.configured) {
          return _Message(text: l10n.diagnosticsFiscalNotConfigured);
        }
        return RefreshIndicator(
          onRefresh: () async => setState(() => _snapshot = _read()),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _Section(
                title: l10n.diagnosticsFiscalAccepted,
                empty: l10n.diagnosticsFiscalAcceptedEmpty,
                children: [
                  for (final r in data.accepted) _AcceptedCard(document: r),
                ],
              ),
              const SizedBox(height: 16),
              _Section(
                title: l10n.diagnosticsFiscalQueued,
                empty: l10n.diagnosticsFiscalQueuedEmpty,
                children: [
                  for (final e in data.queued) _QueuedCard(document: e),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.empty,
    required this.children,
  });

  final String title;
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      if (children.isEmpty)
        Padding(padding: const EdgeInsets.all(8), child: Text(empty))
      else
        ...children,
    ],
  );
}

/// Документ, который оператор принял: признак — доказательство, остальное —
/// то, по чему документ ищут в кабинете оператора.
class _AcceptedCard extends StatelessWidget {
  const _AcceptedCard({required this.document});

  final FiscalAcceptedDocument document;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(l10n.diagnosticsFiscalSign(document.fiscalNo ?? '—')),
        subtitle: Text(
          '${l10n.diagnosticsFiscalOperatorDoc(document.operatorReceiptNo ?? '—')} · '
          '${l10n.diagnosticsFiscalReceiptNo(document.receiptNo ?? '—')}'
          // Автономный режим назван вслух: признак есть, но выдан не
          // оператором, а кассой по его правилам, и это разные вещи.
          '${document.offline ? ' · ${l10n.diagnosticsFiscalOffline}' : ''}',
        ),
      ),
    );
  }
}

/// Строка очереди: чем отправляли, сколько раз и чем кончилось.
class _QueuedCard extends StatelessWidget {
  const _QueuedCard({required this.document});

  final FiscalQueuedDocument document;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(document.idempotencyKey),
        subtitle: Text(
          '${document.opType} · ${l10n.diagnosticsAttempts(document.attempts)}'
          '${document.lastError == null ? '' : ' · ${document.lastError}'}',
          style: TextStyle(color: document.failed ? scheme.error : null),
        ),
        children: [
          Container(
            width: double.infinity,
            color: scheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                // Как есть, с отступами, расставленными кассой: это сверяют
                // с тем, что ждёт оператор, и приглаженный вид врёт там, где
                // его читают.
                document.payloadJson,
                style: const TextStyle(fontFamily: AppTypography.familyMono, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «За этим адресом эмулятор». Вид — тот же, что у плашки принтера на
/// `diagnostics_screen.dart`: одна беда обязана выглядеть одинаково, иначе
/// наладчик читает их как разные.
class _EmulatorBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('fiscal-diagnostics-emulator-banner'),
    width: double.infinity,
    color: AppColors.warning.withValues(alpha: 0.16),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        const Icon(Icons.developer_board, color: AppColors.warning, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            AppLocalizations.of(context)!.diagnosticsFiscalEmulatorBanner,
          ),
        ),
      ],
    ),
  );
}
