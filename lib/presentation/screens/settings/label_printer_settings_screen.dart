import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/session_lost_handler.dart';
import 'package:telepos/presentation/screens/settings/hardware_settings_screen.dart'
    show DeviceBindingDraft, DeviceBindingEditor;

/// Label printer settings — one [DeviceClass.labelPrinter] binding, chosen
/// from [DeviceProfileCatalog] and rendered by [DeviceBindingEditor] (И31).
///
/// **What used to live here and does not any more:**
/// - Manual connection-type/address/port fields and the separate
///   width/height millimetre text fields — replaced by the chosen profile's
///   `connectionParams` (`ipAddress`) and `options` (`paperWidthMm`,
///   `labelHeightMm`, both derived from `DeviceCapabilities` — see
///   `lib/domain/device/device_profile.dart`).
/// - **Label height corrected (task 5(a), plan 2b, 2026-07-30/31) — this
///   comment used to claim it "has no home any more" and named that a real
///   catalog gap.** That was true when written, and is not any more:
///   `DeviceCapabilities.labelHeightsMm` now exists alongside
///   `paperWidthsMm`, `DeviceProfile.options` derives a `labelHeightMm`
///   option from it the same way it derives `paperWidthMm`, and both label
///   printer catalogue profiles declare heights — so [DeviceBindingEditor]
///   already renders a height field here, the same generic way it renders
///   width, with no change needed in this file. A stale comment claiming
///   otherwise is worse than none, because the next reader believes it
///   instead of checking.
/// - **"Print test label" and "auto-detect" are back (plan 2b, task 3), and
///   this comment's claim that "no test action is offered here" is no longer
///   true.** It was true while the only way to reach
///   `lib/hardware/label_printer/label_printer_service.dart` was to import
///   it. Both now go through domain contracts instead:
///   `DeviceCheck` (`lib/domain/device/device_check.dart`) prints a test
///   label and reports why if it could not, and `DeviceDiscovery`
///   (`lib/domain/device/device_discovery.dart`) fills the `ipAddress`/`port`
///   fields from a subnet sweep. Both buttons live in
///   [DeviceBindingEditor], so this file gains them without gaining an
///   import.
/// - Direct `AppDatabase`/`ThisPosDao` reads and writes, and the
///   `hardware_settings` SharedPreferences mirror — both retired, same as
///   `printer_settings_screen.dart`.
class LabelPrinterSettingsScreen extends ConsumerStatefulWidget {
  const LabelPrinterSettingsScreen({super.key});

  @override
  ConsumerState<LabelPrinterSettingsScreen> createState() =>
      _LabelPrinterSettingsScreenState();
}

class _LabelPrinterSettingsScreenState
    extends ConsumerState<LabelPrinterSettingsScreen> {
  bool _isLoading = true;
  int? _terminalId;

  // Nullable, not `late` — see printer_settings_screen.dart's identical
  // fields for why: a missing GetIt registration must degrade this screen,
  // not crash it out of `build()`.
  DeviceProfileCatalog? _catalog;
  DeviceBindingRepository? _bindingRepo;

  final _draft = DeviceBindingDraft(deviceClass: DeviceClass.labelPrinter);

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
        if (b.deviceClass == DeviceClass.labelPrinter) {
          binding = b;
          break;
        }
      }
      _draft.applyBinding(binding);
    } on InstallationNotConfiguredException {
      // Setup wizard hasn't run yet — nothing to load.
    } on SessionLost catch (error) {
      // Same fix as `hardware_settings_screen.dart` (phase-2 fix wave, task
      // 1), applied here for symmetry — found during that task but not
      // fixed there without a separate instruction.
      //
      // Not a live gap today (corrected 2026-08-21, second round of the fix
      // wave: the first round's report described this branch as closing an
      // active defect, which overstated it). `SessionLost` is thrown by
      // exactly one implementation in the whole repository —
      // `WtDispatcher._errorFor` (`lib/web/wt_dispatcher.dart`) — and only
      // the browser binding ever wires a `WtDeviceBindingRepository`/
      // `WtTerminalRepository` behind these `GetIt` lookups
      // (`lib/web/main_web.dart`). The browser binding's route table is
      // `createSetupRouter()` (`lib/app/router/setup_router.dart`), and it
      // has no route to `LabelPrinterSettingsScreen` at all — only
      // `HardwareSettingsScreen` has moved onto the wire so far. On desktop,
      // `GetIt.I<DeviceBindingRepository>()`/`GetIt.I<TerminalRepository>()`
      // resolve to local, in-process bindings that never throw `SessionLost`
      // in the first place. So this branch cannot run today on either
      // binding — it is here for when `LabelPrinterSettingsScreen` gets its
      // own route in `setup_router.dart`, so that migration does not have to
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
            content: Text(l10n.settingsSetupIncompleteSave),
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
    final isDesktop = width >= 900;
    final catalog = _catalog;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.labelPrinterSettingsTitle),
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
          : catalog == null
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  l10n.labelPrinterProfileCatalogUnavailable,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            )
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
                                AppLocalizations.of(
                                  context,
                                )!.settingsRestartRequired,
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
                      DeviceBindingEditor(
                        title: l10n.labelPrinterSettingsTitle,
                        icon: Icons.label,
                        profiles: catalog.forClass(DeviceClass.labelPrinter),
                        draft: _draft,
                        terminalId: _terminalId,
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      _buildTemplatesLink(l10n),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildTemplatesLink(AppLocalizations l10n) {
    // `Material`, а не крашеный `Container`: здесь `ListTile` с `onTap` —
    // строка, по которой уходят к шаблонам этикеток, — и подсветку нажатия
    // на ней закрывал собой `DecoratedBox`. Эталон приёма —
    // `SettingsSection` (`common/widgets/settings/settings_section.dart`).
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const Icon(Icons.list_alt, color: AppColors.primary),
        title: Text(l10n.labelTemplatesManage),
        subtitle: Text(l10n.labelTemplatesManageSubtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(AppRoutes.labelTemplates),
      ),
    );
  }
}
