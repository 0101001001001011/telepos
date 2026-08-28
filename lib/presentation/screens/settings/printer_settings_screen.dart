import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/print/print_job.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/utils/session_lost_handler.dart';
import 'package:telepos/presentation/screens/settings/hardware_settings_screen.dart'
    show DeviceBindingDraft, DeviceBindingEditor;

/// Receipt printer settings — one [DeviceClass.receiptPrinter] binding,
/// chosen from [DeviceProfileCatalog] and rendered by [DeviceBindingEditor]
/// (И31: the profile declares its fields, this screen doesn't hardcode
/// them).
///
/// **What used to live here and does not any more:**
/// - The manual connection-type selector (USB/Bluetooth/Wi-Fi/serial),
///   address/port text fields, and the 32/42/48-character paper-width radio
///   — all replaced by the chosen profile's `connectionParams` and
///   `options` (paper width is now expressed in millimetres, the unit the
///   catalog uses — `printer.escpos.80mm`/`printer.escpos.58mm-compact`
///   declare 58/80mm, not a character count).
/// - "Print a test receipt with custom content" — needs direct hardware
///   access (`lib/hardware/printer/...`), forbidden from a layering-clean
///   presentation file.
/// - The `ReceiptPrintService.isPrinterAvailable()` check button (plan 2b,
///   task 3). It answered `bool`, so the screen could only say "готов" or
///   "не подключён" — and "не подключён" was wrong for the most common real
///   case, a binding this process has not built a driver for yet. That
///   button is now [DeviceBindingEditor]'s own, driven by
///   `DeviceCheck` (`lib/domain/device/device_check.dart`), which prints a
///   test receipt through the bound printer and reports *which* of six
///   distinguishable things happened.
/// - "Auto-detect" — replaced, not dropped: [DeviceBindingEditor] now puts an
///   «искать» button beside every connection-parameter field, driven by
///   `DeviceDiscovery` (`lib/domain/device/device_discovery.dart`). Unlike
///   the old auto-detect it never binds anything by itself — it fills the
///   field and the operator still picks the profile.
/// - Direct `AppDatabase`/`ThisPosDao` reads and writes, and the
///   `hardware_settings` SharedPreferences mirror — both dead: nothing reads
///   `ThisPosEntries.printerConnectionType`/`printerAddress`/`printerPort`/
///   `paperWidth` any more (`hardware_module.dart` resolves the printer from
///   this terminal's `DeviceBinding` only), and `hardware_settings` has been
///   retired by this task.
class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() =>
      _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  bool _isLoading = true;
  int? _terminalId;

  // Nullable, not `late`: GetIt may not have these registered in every host
  // this widget can run in (a test harness that only sets up the pieces it
  // needs, a future context this screen wasn't written for). `late` would
  // throw `LateInitializationError` straight out of `build()` — a crash,
  // not a degraded state. И30 extends to the settings screen itself: a
  // missing dependency here must show "unavailable", never take the whole
  // screen down.
  DeviceProfileCatalog? _catalog;
  DeviceBindingRepository? _bindingRepo;

  final _draft = DeviceBindingDraft(deviceClass: DeviceClass.receiptPrinter);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      _catalog = GetIt.I<DeviceProfileCatalog>();
      final bindingRepo = GetIt.I<DeviceBindingRepository>();
      _bindingRepo = bindingRepo;
      final terminal = await GetIt.I<TerminalRepository>().self();
      _terminalId = terminal.id;
      final bindings = await bindingRepo.forTerminal(terminal.id);
      DeviceBinding? binding;
      for (final b in bindings) {
        if (b.deviceClass == DeviceClass.receiptPrinter) {
          binding = b;
          break;
        }
      }
      _draft.applyBinding(binding);
    } on InstallationNotConfiguredException {
      // Setup wizard hasn't run yet — nothing to load. И30: the screen must
      // still open with nothing configured.
    } on SessionLost catch (error) {
      // Same fix as `hardware_settings_screen.dart` (phase-2 fix wave, task
      // 1), applied here for symmetry — found during that task but not
      // fixed there without a separate instruction.
      //
      // Not a live gap today (corrected 2026-08-21, second round of the
      // fix wave: the first round's report described this branch as closing
      // an active defect, which overstated it). `SessionLost` is thrown by
      // exactly one implementation in the whole repository —
      // `WtDispatcher._errorFor` (`lib/web/wt_dispatcher.dart`) — and only
      // the browser binding ever wires a `WtDeviceBindingRepository`/
      // `WtTerminalRepository` behind these `GetIt` lookups
      // (`lib/web/main_web.dart`). The browser binding's route table is
      // `createSetupRouter()` (`lib/app/router/setup_router.dart`), and it
      // has no route to `PrinterSettingsScreen` at all — only
      // `HardwareSettingsScreen` has moved onto the wire so far. On desktop,
      // `GetIt.I<DeviceBindingRepository>()`/`GetIt.I<TerminalRepository>()`
      // resolve to local, in-process bindings that never throw `SessionLost`
      // in the first place. So this branch cannot run today on either
      // binding — it is here for when `PrinterSettingsScreen` gets its own
      // route in `setup_router.dart`, so that migration does not have to
      // remember to add this catch from scratch.
      handleSessionLost(context, error);
      return;
    } catch (_) {
      // Best-effort load; the screen still opens with defaults.
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    final l10n = AppLocalizations.of(context)!;
    final terminalId = _terminalId;
    final bindingRepo = _bindingRepo;
    if (terminalId == null || bindingRepo == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Мастер настройки ещё не завершён — сохранить некуда',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    final binding = _draft.toBinding();
    try {
      if (binding != null) {
        await bindingRepo.save(terminalId, binding);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.printerSettingsSaved),
          backgroundColor: AppColors.success,
        ),
      );
    } on SessionLost catch (error) {
      // Same "not reachable today" note as the `_loadSettings` catch above —
      // see there for why.
      handleSessionLost(context, error);
    } on ArgumentError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.printerSettingsSaveError(_describe(e))),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// `ArgumentError.message` alone (as thrown by
  /// `DeviceBinding.validateAgainst`) never names the offending parameter
  /// or option key — that lives in `.invalidValue`. This combines both so the
  /// operator sees which one, rather than a message that only blames "some"
  /// parameter.
  String _describe(ArgumentError e) {
    final value = e.invalidValue;
    if (value == null) return '${e.message}';
    return '${e.message}: $value';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final layoutType = Breakpoints.fromWidth(width);
    final isDesktop = layoutType == LayoutType.desktop;
    final catalog = _catalog;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.printerSettingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(TeleposIcons.save, color: Colors.white),
            label: Text(
              l10n.printerSettingsSave,
              style: const TextStyle(color: Colors.white),
            ),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 24 : 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.info.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              TeleposIcons.info,
                              size: 18,
                              color: AppColors.info,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Изменения применяются при следующем запуске кассы.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // The binding editor needs the profile catalog; the print
                      // queue does not. Collapsing the whole screen when the
                      // catalog is missing used to hide the queue too — that is
                      // exactly the case where an operator most needs to see
                      // that a receipt is still waiting.
                      if (catalog == null)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Каталог профилей устройств недоступен — настройки '
                            'принтера сейчас нельзя изменить.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        )
                      else
                        DeviceBindingEditor(
                          title: l10n.printerSettingsTitle,
                          icon: Icons.print,
                          profiles: catalog.forClass(
                            DeviceClass.receiptPrinter,
                          ),
                          draft: _draft,
                          terminalId: _terminalId,
                          onChanged: () => setState(() {}),
                        ),
                      const SizedBox(height: 24),
                      PrintQueueSection(terminalId: _terminalId),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// The print queue as an operator sees it: what is waiting, what is printing,
/// what did not print — **and why** — plus the two decisions the operator is
/// allowed to make about a stuck job (retry it for a chosen extra span, or
/// cancel it).
///
/// И31 says everything that happens is available from the interface, and
/// section 8 says a job that cannot print must become a *visible problem*
/// rather than hanging. A deadline nobody looks at makes nothing visible, so
/// this widget subscribes to [PrintQueue.watch] and redraws itself; there is
/// no "refresh" button, because a queue you have to ask about is a queue you
/// forget to ask about.
///
/// ## What this widget deliberately does not do
///
/// **It never touches `lib/hardware/` or `lib/data/`.** Everything it needs is
/// on [PrintQueue] and [PrintJob]. That is not an aesthetic rule here: the
/// transitive check in `test/architecture/layering_test.dart` pins this file by
/// name, and a button that "needs" such an import means the *contract* is
/// short, not that the rule should bend.
///
/// **It does not re-derive the state of a job.** The label comes from
/// [PrintJob.state], the explanation from [PrintJob.failureReason], and whether
/// a retry is possible is answered by [PrintQueue.retry] itself. The buttons
/// below hide themselves for states the contract refuses, but that is an
/// affordance, not the rule: the state on screen can go stale between the draw
/// and the tap (the queue may print the job in between), and when it does, the
/// contract's refusal is shown as an answer rather than swallowed. That is why
/// pressing "retry" on a receipt that has meanwhile printed says
/// «уже напечатан» instead of producing a second receipt.
///
/// **It shows three different empty-looking outcomes as three different
/// things.** «Очередь пуста», «очередь недоступна» and «очередь не читается»
/// send an operator to three different places, so they never collapse into one
/// blank list. The third is real: the store refuses to guess an unknown state
/// name and throws, so a single corrupt row makes the *whole* list unreadable
/// (`DriftPrintJobStore._stateFromStoredName`). Showing that as "nothing is
/// waiting" would be the worst possible lie — it is exactly the case where
/// something *is* waiting and nobody can see it.
class PrintQueueSection extends StatefulWidget {
  const PrintQueueSection({super.key, required this.terminalId});

  /// Whose queue to show. `null` — every terminal, which is what the screen
  /// passes before the setup wizard has run and there is no own identity yet.
  final int? terminalId;

  @override
  State<PrintQueueSection> createState() => _PrintQueueSectionState();
}

/// The answer to the operator's last button press, kept on screen instead of
/// flashing past in a snack bar.
///
/// [detail] carries text produced outside this screen's control (the queue's
/// own rejection reason) and is therefore shown **only** where nothing else
/// says anything — a rejection. For accepted and duplicate answers the
/// localised headline is the whole answer, so no untranslated text reaches the
/// screen at all.
class _QueueActionResult {
  const _QueueActionResult({
    required this.headline,
    required this.colour,
    this.detail,
  });

  final String headline;
  final Color colour;
  final String? detail;
}

/// One offered extension: how much longer, and what to call it.
typedef _Extension = ({
  Duration extendBy,
  String Function(AppLocalizations) label,
  String key,
});

class _PrintQueueSectionState extends State<PrintQueueSection> {
  /// Nullable, not `late`: a host that never registered a queue (a narrow test
  /// harness, a build without printing) must show "unavailable", not take the
  /// settings screen down with a `LateInitializationError`. Same reasoning as
  /// the catalog field on this screen's state.
  PrintQueue? _queue;

  /// Subscribed once, in [initState], and **not** rebuilt in `build`: a stream
  /// created inside `build` would be re-subscribed on every frame, and each
  /// re-subscription restarts the list at "waiting", so the queue would blink
  /// empty every time anything else on the screen changed.
  Stream<List<PrintJob>>? _jobs;

  _QueueActionResult? _lastAction;

  /// Retry is a decision about how much longer the receipt is worth printing,
  /// so the operator picks the span. A **duration**, never a moment — see
  /// [PrintQueue.retry]: an absolute deadline computed on a machine whose clock
  /// runs behind arrives already expired, and the queue would then refuse a
  /// perfectly healthy job.
  static const List<_Extension> _extensions = <_Extension>[
    (
      extendBy: Duration(minutes: 5),
      label: _extend5Label,
      key: 'print_queue_extend_5m',
    ),
    (
      extendBy: Duration(minutes: 30),
      label: _extend30Label,
      key: 'print_queue_extend_30m',
    ),
    (
      extendBy: Duration(hours: 2),
      label: _extend2hLabel,
      key: 'print_queue_extend_2h',
    ),
  ];

  static String _extend5Label(AppLocalizations l10n) =>
      l10n.printQueueExtend5Minutes;
  static String _extend30Label(AppLocalizations l10n) =>
      l10n.printQueueExtend30Minutes;
  static String _extend2hLabel(AppLocalizations l10n) =>
      l10n.printQueueExtend2Hours;

  @override
  void initState() {
    super.initState();
    if (GetIt.I.isRegistered<PrintQueue>()) {
      final queue = GetIt.I<PrintQueue>();
      _queue = queue;
      _jobs = queue.watch(terminalId: widget.terminalId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lastAction = _lastAction;
    return Column(
      key: const Key('print_queue_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.queue,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.printQueueSectionTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.printQueueSubtitle,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (lastAction != null) _buildActionResult(lastAction),
        _buildBody(l10n),
      ],
    );
  }

  Widget _buildActionResult(_QueueActionResult result) => Container(
    key: const Key('print_queue_action_result'),
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: result.colour.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          result.headline,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: result.colour,
          ),
        ),
        if (result.detail != null) ...[
          const SizedBox(height: 4),
          Text(result.detail!, style: const TextStyle(fontSize: 13)),
        ],
      ],
    ),
  );

  Widget _buildBody(AppLocalizations l10n) {
    final jobs = _jobs;
    if (jobs == null) {
      return _notice(
        key: const Key('print_queue_unavailable'),
        headline: l10n.printQueueUnavailable,
        colour: AppColors.info,
      );
    }
    return StreamBuilder<List<PrintJob>>(
      stream: jobs,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // One row the store cannot parse blows up the whole list (see the
          // class doc). Rendering an empty list here would tell the operator
          // the opposite of the truth.
          return _notice(
            key: const Key('print_queue_unreadable'),
            headline: l10n.printQueueUnreadable,
            colour: Theme.of(context).colorScheme.error,
            hint: l10n.printQueueUnreadableHint,
            detail: '${snapshot.error}',
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return const Padding(
            key: Key('print_queue_loading'),
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (data.isEmpty) {
          return _notice(
            key: const Key('print_queue_empty'),
            headline: l10n.printQueueEmpty,
            colour: Theme.of(context).colorScheme.onSurfaceVariant,
          );
        }
        return Column(
          key: const Key('print_queue_list'),
          children: [for (final job in data) _buildJob(l10n, job)],
        );
      },
    );
  }

  Widget _notice({
    required Key key,
    required String headline,
    required Color colour,
    String? hint,
    String? detail,
  }) => Container(
    key: key,
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: colour.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: colour.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headline,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colour,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(hint, style: const TextStyle(fontSize: 12)),
        ],
        if (detail != null) ...[
          const SizedBox(height: 4),
          Text(
            detail,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _buildJob(AppLocalizations l10n, PrintJob job) {
    final colour = _stateColour(job.state);
    final reason = job.failureReason;
    return Container(
      key: Key('print_job_${job.id}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _stateLabel(l10n, job.state),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colour,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            job.id,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          // The reason is the part that decides where the operator goes:
          // «нет бумаги» is a drawer in this room, «принтер не отвечает» is a
          // cable in another. It is shown verbatim because it is produced by
          // whichever driver failed — see this task's report for why that
          // string cannot be localised from here today.
          if (reason != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.printQueueReason(reason),
              style: const TextStyle(fontSize: 13),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            l10n.printQueueDeadline(_formatMoment(job.expiresAt)),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            l10n.printQueueAttempts(job.attempts),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (_canRetry(job.state) || _canCancel(job.state)) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (_canRetry(job.state))
                  OutlinedButton(
                    key: Key('print_job_retry_${job.id}'),
                    onPressed: () => _retry(job.id),
                    child: Text(l10n.printQueueRetry),
                  ),
                if (_canRetry(job.state) && _canCancel(job.state))
                  const SizedBox(width: 8),
                if (_canCancel(job.state))
                  TextButton(
                    key: Key('print_job_cancel_${job.id}'),
                    onPressed: () => _cancel(job.id),
                    child: Text(l10n.printQueueCancelJob),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// States [PrintQueue.retry] accepts. Mirrors `PrintJob.renewedUntil`; when
  /// the two disagree because the job moved on between the draw and the tap,
  /// the contract wins and its refusal reaches the screen.
  bool _canRetry(PrintJobState state) =>
      state == PrintJobState.queued ||
      state == PrintJobState.failed ||
      state == PrintJobState.expired;

  /// `PrintQueue.cancel` answers `false` for a terminal job and for one that is
  /// printing right now — half a receipt cannot be pulled back out of the
  /// printer.
  bool _canCancel(PrintJobState state) =>
      state == PrintJobState.queued || state == PrintJobState.failed;

  String _stateLabel(AppLocalizations l10n, PrintJobState state) =>
      switch (state) {
        PrintJobState.queued => l10n.printQueueStateQueued,
        PrintJobState.printing => l10n.printQueueStatePrinting,
        PrintJobState.printed => l10n.printQueueStatePrinted,
        PrintJobState.failed => l10n.printQueueStateFailed,
        PrintJobState.expired => l10n.printQueueStateExpired,
        PrintJobState.cancelled => l10n.printQueueStateCancelled,
      };

  /// Colour is the coarse second cue; the label above carries the answer.
  /// [PrintJobState.failed] and [PrintJobState.expired] are deliberately not
  /// the same colour — one retries itself, the other waits for a person.
  Color _stateColour(PrintJobState state) => switch (state) {
    PrintJobState.queued || PrintJobState.printing => AppColors.info,
    PrintJobState.printed => AppColors.success,
    PrintJobState.failed => AppColors.warningGold,
    PrintJobState.expired => Theme.of(context).colorScheme.error,
    PrintJobState.cancelled => Theme.of(context).colorScheme.onSurfaceVariant,
  };

  /// The deadline is a moment, so it is rendered by the platform's own
  /// locale-aware formatters rather than by a date pattern spelled out here —
  /// a hardcoded `dd.MM` would be one more thing that is only right in Russian.
  String _formatMoment(DateTime moment) {
    final local = moment.toLocal();
    final materialL10n = MaterialLocalizations.of(context);
    final time = materialL10n.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
    return '${materialL10n.formatMediumDate(local)} $time';
  }

  Future<void> _retry(String jobId) async {
    final l10n = AppLocalizations.of(context)!;
    final queue = _queue;
    if (queue == null) return;

    final extendBy = await showDialog<Duration>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        key: const Key('print_queue_extend_dialog'),
        title: Text(l10n.printQueueExtendTitle),
        children: [
          for (final option in _extensions)
            SimpleDialogOption(
              key: Key(option.key),
              onPressed: () => Navigator.of(dialogContext).pop(option.extendBy),
              child: Text(option.label(l10n)),
            ),
          SimpleDialogOption(
            key: const Key('print_queue_extend_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.globalCancel),
          ),
        ],
      ),
    );
    if (extendBy == null || !mounted) return;

    // `retry` never throws by contract — every refusal comes back as
    // `rejected` with a reason. The try is here because a settings screen must
    // survive an implementation that breaks its own contract; crashing would
    // take away the only view of the queue precisely when it is stuck.
    PrintSubmitOutcome outcome;
    try {
      outcome = await queue.retry(jobId, extendBy: extendBy);
    } catch (e) {
      outcome = PrintSubmitOutcome.rejected(jobId, '$e');
    }
    if (!mounted) return;
    setState(() => _lastAction = _describeOutcome(l10n, outcome));
  }

  /// One localised headline per [PrintSubmitStatus] — the whole answer for two
  /// of the three. Only [PrintSubmitStatus.rejected] carries
  /// [PrintSubmitOutcome.message] onto the screen, because there the message is
  /// the only thing that says *what* went wrong.
  _QueueActionResult _describeOutcome(
    AppLocalizations l10n,
    PrintSubmitOutcome outcome,
  ) => switch (outcome.status) {
    PrintSubmitStatus.accepted => _QueueActionResult(
      headline: l10n.printQueueRetryAccepted,
      colour: AppColors.success,
    ),
    // Not an error: this is what a correct retry of an already-printed receipt
    // looks like, and it is the whole point of the idempotency key.
    PrintSubmitStatus.duplicate => _QueueActionResult(
      headline: l10n.printQueueRetryAlreadyPrinted,
      colour: AppColors.info,
    ),
    PrintSubmitStatus.rejected => _QueueActionResult(
      headline: l10n.printQueueRetryRejected,
      colour: Theme.of(context).colorScheme.error,
      detail: outcome.message,
    ),
  };

  Future<void> _cancel(String jobId) async {
    final l10n = AppLocalizations.of(context)!;
    final queue = _queue;
    if (queue == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('print_queue_cancel_dialog'),
        title: Text(l10n.printQueueCancelTitle),
        content: Text(l10n.printQueueCancelBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.globalCancel),
          ),
          TextButton(
            key: const Key('print_queue_cancel_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.printQueueCancelConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    bool cancelled;
    try {
      cancelled = await queue.cancel(jobId);
    } catch (_) {
      cancelled = false;
    }
    if (!mounted) return;
    setState(
      () => _lastAction = cancelled
          ? _QueueActionResult(
              headline: l10n.printQueueCancelDone,
              colour: AppColors.success,
            )
          : _QueueActionResult(
              headline: l10n.printQueueCancelRefused,
              colour: Theme.of(context).colorScheme.error,
            ),
    );
  }
}
