import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/sysd/sysd_client.dart';
import 'package:telepos/l10n/app_localizations.dart';

class ApplianceSettingsScreen extends ConsumerStatefulWidget {
  const ApplianceSettingsScreen({super.key});

  @override
  ConsumerState<ApplianceSettingsScreen> createState() =>
      _ApplianceSettingsScreenState();
}

class _ApplianceSettingsScreenState
    extends ConsumerState<ApplianceSettingsScreen> {
  final SysdClient _sysd = SysdClient();

  bool _loading = true;
  bool _available = false;
  SessionStatus? _session;
  List<DriverItem> _drivers = const [];

  String? _busy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final session = await _sysd.sessionStatus();
      final drivers = await _sysd.catalog();
      if (!mounted) return;
      setState(() {
        _session = session;
        _drivers = drivers;
        _available = true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _available = false;
        _loading = false;
      });
    }
  }

  Future<void> _toggleDriver(DriverItem item) async {
    setState(() => _busy = item.id);
    try {
      final jobId = item.installed
          ? await _sysd.removeDriver(item.id)
          : await _sysd.installDriver(item.id);
      final job = await _sysd.waitForJob(jobId);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      if (job.ok) {
        _snack(
          item.installed
              ? l10n.applianceDriverRemoved(item.title)
              : l10n.applianceDriverInstalled(item.title),
        );
      } else {
        _snack(l10n.applianceError(job.error ?? job.state), error: true);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(
        AppLocalizations.of(context)!.applianceError(e.toString()),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error
            ? Theme.of(context).colorScheme.error
            : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.applianceTitle),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: l10n.networkRefresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_available
          ? _buildUnavailable()
          : _buildBody(),
    );
  }

  Widget _buildUnavailable() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dvr_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.networkUnavailableTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.applianceUnavailableDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSystemManagementCard(),
              const SizedBox(height: 20),
              _buildNetworkCard(),
              const SizedBox(height: 20),
              _buildSessionCard(),
              const SizedBox(height: 20),
              _buildDriversCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemManagementCard() {
    final l10n = AppLocalizations.of(context)!;
    return _card(
      icon: Icons.settings_suggest,
      title: l10n.sysmTitle,
      description: l10n.sysmHubSubtitle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.push(AppRoutes.systemManagement),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(l10n.sysmOpenPanel),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkCard() {
    final l10n = AppLocalizations.of(context)!;
    return _card(
      icon: Icons.wifi,
      title: l10n.applianceNetworkTitle,
      description: l10n.applianceNetworkDesc,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.push(AppRoutes.networkSettings),
            icon: const Icon(Icons.settings_ethernet, size: 18),
            label: Text(l10n.applianceNetworkButton),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionCard() {
    final l10n = AppLocalizations.of(context)!;
    return _card(
      icon: Icons.desktop_windows,
      title: l10n.applianceDesktopTitle,
      description: l10n.applianceDesktopDesc,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Text(
                    l10n.applianceCurrentMode,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _sessionLabel(_session?.current),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.desktop_windows, size: 18),
                label: Text(l10n.applianceOpenDesktop),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(
                    TeleposIcons.info,
                    size: 15,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.applianceDesktopUnavailable,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sessionLabel(String? current) {
    final l10n = AppLocalizations.of(context)!;
    switch (current) {
      case 'kiosk':
        return l10n.applianceModeKiosk;
      case 'desktop':
        return l10n.applianceModeDesktop;
      default:
        return '—';
    }
  }

  Widget _buildDriversCard() {
    final l10n = AppLocalizations.of(context)!;
    return _card(
      icon: Icons.usb,
      title: l10n.applianceDriversTitle,
      description: l10n.applianceDriversDesc,
      child: Column(
        children: [
          if (_drivers.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                l10n.applianceDriversEmpty,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ..._drivers.map(_buildDriverRow),
        ],
      ),
    );
  }

  Widget _buildDriverRow(DriverItem item) {
    final l10n = AppLocalizations.of(context)!;
    final busy = _busy == item.id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            item.installed ? TeleposIcons.checkCircle : Icons.download_outlined,
            size: 20,
            color: item.installed
                ? AppColors.success
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  item.packages.join(', '),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (item.installed)
            TextButton(
              onPressed: _busy != null ? null : () => _toggleDriver(item),
              child: Text(
                l10n.applianceDriverRemove,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            )
          else
            FilledButton(
              onPressed: _busy != null ? null : () => _toggleDriver(item),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(l10n.applianceDriverInstall),
            ),
        ],
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String description,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.semantic.canvas),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          child,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
