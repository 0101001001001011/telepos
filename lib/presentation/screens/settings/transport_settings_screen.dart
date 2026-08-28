import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../telegram/data_exchange/sync_state_tracker.dart';
import '../../../domain/entities/telegram/sync_packet.dart';
import '../../../l10n/app_localizations.dart';
import '../../../transport/transport_exports.dart';
import '../../controllers/transport/transport_controller.dart';
import '../../common/widgets/transport/transport_status_panel.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';

class TransportNotificationPrefs {
  const TransportNotificationPrefs._();

  static const String keyTransportChanges = 'notify_transport_changes';
  static const String keySyncErrors = 'notify_sync_errors';
  static const String keyOfflineOnline = 'notify_offline_online';
  static const String keyQueueFull = 'notify_queue_full';

  static Future<bool> transportChangesEnabled() => _read(keyTransportChanges);

  static Future<bool> syncErrorsEnabled() => _read(keySyncErrors);

  static Future<bool> offlineOnlineEnabled() => _read(keyOfflineOnline);

  static Future<bool> queueFullEnabled() => _read(keyQueueFull);

  static Future<bool> _read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? true;
  }
}

final _syncSettingsProvider = FutureProvider<_SyncSettings>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return _SyncSettings(
    syncInterval: prefs.getInt('sync_interval') ?? 5,
    syncOnStartup: prefs.getBool('sync_on_startup') ?? true,
    syncOnConnectivity: prefs.getBool('sync_on_connectivity') ?? true,
    enableQueue: prefs.getBool('enable_queue') ?? true,
    maxQueueSize: prefs.getInt('max_queue_size') ?? 1000,
    autoCleanup: prefs.getBool('queue_auto_cleanup') ?? true,
  );
});

final _syncStateProvider = FutureProvider<SyncStateSnapshot?>((ref) async {
  final controller = ref.watch(transportControllerProvider.notifier);
  return controller.getSyncSnapshot();
});

class _SyncSettings {
  final int syncInterval;
  final bool syncOnStartup;
  final bool syncOnConnectivity;
  final bool enableQueue;
  final int maxQueueSize;
  final bool autoCleanup;

  _SyncSettings({
    required this.syncInterval,
    required this.syncOnStartup,
    required this.syncOnConnectivity,
    required this.enableQueue,
    required this.maxQueueSize,
    required this.autoCleanup,
  });
}

class TransportSettingsScreen extends ConsumerWidget {
  const TransportSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transportControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settingsTransport),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppLocalizations.of(context)!.telegramFullSync,
            onPressed: state.isSyncing
                ? null
                : () => _showFullSyncConfirmation(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacing),
        children: [
          const TransportStatusPanel(),

          const SizedBox(height: AppTheme.spacingLarge),

          _SyncTypeStatusSection(),

          const SizedBox(height: AppTheme.spacingLarge),

          _ModeSelector(
            currentMode: state.mode,
            onModeChanged: (mode) {
              ref.read(transportControllerProvider.notifier).changeMode(mode);
            },
          ),

          const SizedBox(height: AppTheme.spacingLarge),

          _SyncSettingsSection(),

          const SizedBox(height: AppTheme.spacingLarge),

          _QueueSettingsSection(),

          const SizedBox(height: AppTheme.spacingLarge),

          _NotificationSettingsSection(),
        ],
      ),
    );
  }

  void _showFullSyncConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.telegramFullSync),
        content: Text(AppLocalizations.of(ctx)!.transportFullSyncWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx)!.globalCancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(transportControllerProvider.notifier).forceSyncAll();
            },
            child: Text(AppLocalizations.of(ctx)!.telegramFullSync),
          ),
        ],
      ),
    );
  }
}

class _SyncTypeStatusSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStateAsync = ref.watch(_syncStateProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.syncStatus,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(TeleposIcons.info, size: 20),
                  onPressed: () => _showSyncInfo(context),
                  tooltip: AppLocalizations.of(context)!.transportSyncAbout,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing),
            syncStateAsync.when(
              data: (snapshot) {
                if (snapshot == null) {
                  return Text(
                    AppLocalizations.of(context)!.syncOffline,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  );
                }

                final l10n = AppLocalizations.of(context)!;
                return Column(
                  children: [
                    _SyncTypeRow(
                      type: l10n.syncProducts,
                      lastSync: _getLastSyncTime(
                        snapshot,
                        ExchangeType.product,
                      ),
                    ),
                    const Divider(height: 8),
                    _SyncTypeRow(
                      type: l10n.syncSales,
                      lastSync: _getLastSyncTime(snapshot, ExchangeType.sale),
                    ),
                    const Divider(height: 8),
                    _SyncTypeRow(
                      type: l10n.refundTitle,
                      lastSync: _getLastSyncTime(snapshot, ExchangeType.refund),
                    ),
                    const Divider(height: 8),
                    _SyncTypeRow(
                      type: l10n.shiftTitle,
                      lastSync: _getLastSyncTime(snapshot, ExchangeType.shift),
                    ),
                    const Divider(height: 8),
                    _SyncTypeRow(
                      type: l10n.syncAgents,
                      lastSync: _getLastSyncTime(snapshot, ExchangeType.agent),
                    ),
                    const Divider(height: 8),
                    _SyncTypeRow(
                      type: l10n.additionalSupply,
                      lastSync: _getLastSyncTime(snapshot, ExchangeType.supply),
                    ),
                    const Divider(height: 8),
                    _SyncTypeRow(
                      type: l10n.syncPrices,
                      lastSync: _getLastSyncTime(snapshot, ExchangeType.price),
                    ),
                    const Divider(height: 8),
                    _SyncTypeRow(
                      type: l10n.fiscalTitle,
                      lastSync: _getLastSyncTime(snapshot, ExchangeType.fiscal),
                    ),
                    const Divider(height: 8),
                    _SyncTypeRow(
                      type: l10n.navSettings,
                      lastSync: _getLastSyncTime(snapshot, ExchangeType.config),
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text(
                AppLocalizations.of(
                  context,
                )!.transportSyncStateError(e.toString()),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _getLastSyncTime(SyncStateSnapshot snapshot, ExchangeType type) {
    final timestamp = snapshot.timestamps[type];
    if (timestamp == null || timestamp == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  }

  void _showSyncInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.syncTitle),
        content: Text(AppLocalizations.of(ctx)!.transportSyncInfoDialog),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx)!.globalOk),
          ),
        ],
      ),
    );
  }
}

class _SyncTypeRow extends StatelessWidget {
  const _SyncTypeRow({required this.type, required this.lastSync});

  final String type;
  final DateTime? lastSync;

  @override
  Widget build(BuildContext context) {
    final isNeverSynced = lastSync == null;
    final diff = lastSync != null ? DateTime.now().difference(lastSync!) : null;
    final isStale = diff != null && diff.inMinutes > 10;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isNeverSynced
                ? Icons.sync_disabled
                : isStale
                ? Icons.warning_amber
                : TeleposIcons.checkCircle,
            size: 16,
            color: isNeverSynced
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : isStale
                ? AppColors.warning
                : AppColors.statusOnline,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(type)),
          Text(
            isNeverSynced
                ? AppLocalizations.of(context)!.transportSyncNever
                : _formatLastSync(diff!),
            style: TextStyle(
              color: isNeverSynced
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : isStale
                  ? AppColors.warning
                  : Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastSync(Duration diff) {
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.currentMode, required this.onModeChanged});

  final TransportMode currentMode;
  final ValueChanged<TransportMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.settingsTransport,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.transportModeDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spacing),

            _ModeOption(
              icon: Icons.cloud,
              title: AppLocalizations.of(context)!.transportModeRest,
              subtitle: AppLocalizations.of(context)!.transportModeRestDesc,
              isSelected: currentMode == TransportMode.restOnly,
              onTap: () => onModeChanged(TransportMode.restOnly),
            ),

            const SizedBox(height: 8),

            _ModeOption(
              icon: Icons.telegram,
              title: AppLocalizations.of(context)!.transportModeTelegram,
              subtitle: AppLocalizations.of(context)!.transportModeTelegramDesc,
              isSelected: currentMode == TransportMode.telegramOnly,
              onTap: () => onModeChanged(TransportMode.telegramOnly),
            ),

            const SizedBox(height: 8),

            _ModeOption(
              icon: Icons.sync_alt,
              title: AppLocalizations.of(context)!.transportModeHybrid,
              subtitle: AppLocalizations.of(context)!.transportModeHybridDesc,
              isSelected: currentMode == TransportMode.hybrid,
              onTap: () => onModeChanged(TransportMode.hybrid),
              recommended: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.recommended = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Theme.of(context).colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
          color: isSelected ? selectedSurfaceOf(context) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppColors.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? AppColors.primary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (recommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            AppLocalizations.of(
                              context,
                            )!.transportModeRecommended,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(TeleposIcons.checkCircle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _SyncSettingsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(_syncSettingsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.telegramSync,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacing),

            settingsAsync.when(
              data: (settings) => Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.timer),
                    title: Text(
                      AppLocalizations.of(context)!.telegramSyncInterval,
                    ),
                    subtitle: Text(
                      AppLocalizations.of(
                        context,
                      )!.transportSyncIntervalMinutes(settings.syncInterval),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showIntervalPicker(
                      context,
                      ref,
                      settings.syncInterval,
                    ),
                  ),

                  const Divider(),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(AppLocalizations.of(context)!.telegramAutoSync),
                    subtitle: Text(
                      AppLocalizations.of(context)!.telegramSyncData,
                    ),
                    value: settings.syncOnStartup,
                    onChanged: (value) =>
                        _saveSetting(ref, 'sync_on_startup', value),
                  ),

                  const Divider(),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(AppLocalizations.of(context)!.syncOnline),
                    subtitle: Text(
                      AppLocalizations.of(context)!.transportSyncOnConnectivity,
                    ),
                    value: settings.syncOnConnectivity,
                    onChanged: (value) =>
                        _saveSetting(ref, 'sync_on_connectivity', value),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Text(AppLocalizations.of(context)!.globalError),
            ),
          ],
        ),
      ),
    );
  }

  void _showIntervalPicker(
    BuildContext context,
    WidgetRef ref,
    int currentInterval,
  ) {
    final intervals = [1, 2, 5, 10, 15, 30, 60];

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(AppLocalizations.of(ctx)!.telegramSyncInterval),
        children: intervals
            .map(
              (minutes) => SimpleDialogOption(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('sync_interval', minutes);
                  ref.invalidate(_syncSettingsProvider);
                },
                child: ListTile(
                  title: Text(
                    AppLocalizations.of(
                      ctx,
                    )!.transportSyncIntervalOption(minutes),
                  ),
                  trailing: minutes == currentInterval
                      ? const Icon(TeleposIcons.check, color: AppColors.primary)
                      : null,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _saveSetting(WidgetRef ref, String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    ref.invalidate(_syncSettingsProvider);
  }
}

class _QueueSettingsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(_syncSettingsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.syncOffline,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacing),

            settingsAsync.when(
              data: (settings) => Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      AppLocalizations.of(context)!.transportEnableQueue,
                    ),
                    subtitle: Text(
                      AppLocalizations.of(context)!.transportEnableQueueDesc,
                    ),
                    value: settings.enableQueue,
                    onChanged: (value) =>
                        _saveSetting(ref, 'enable_queue', value),
                  ),

                  const Divider(),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.storage),
                    title: Text(
                      AppLocalizations.of(context)!.transportMaxQueueSize,
                    ),
                    subtitle: Text(
                      AppLocalizations.of(
                        context,
                      )!.transportQueueSizeStatus(settings.maxQueueSize),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showQueueSizePicker(
                      context,
                      ref,
                      settings.maxQueueSize,
                    ),
                  ),

                  const Divider(),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      AppLocalizations.of(context)!.transportAutoCleanup,
                    ),
                    subtitle: Text(
                      AppLocalizations.of(context)!.transportAutoCleanupDesc,
                    ),
                    value: settings.autoCleanup,
                    onChanged: (value) =>
                        _saveSetting(ref, 'queue_auto_cleanup', value),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Text(AppLocalizations.of(context)!.globalError),
            ),
          ],
        ),
      ),
    );
  }

  void _showQueueSizePicker(
    BuildContext context,
    WidgetRef ref,
    int currentSize,
  ) {
    final sizes = [100, 500, 1000, 5000, 10000];

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(AppLocalizations.of(ctx)!.transportMaxQueueSize),
        children: sizes
            .map(
              (size) => SimpleDialogOption(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('max_queue_size', size);
                  ref.invalidate(_syncSettingsProvider);
                },
                child: ListTile(
                  title: Text(
                    AppLocalizations.of(ctx)!.transportQueueSizeStatus(size),
                  ),
                  trailing: size == currentSize
                      ? const Icon(TeleposIcons.check, color: AppColors.primary)
                      : null,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _saveSetting(WidgetRef ref, String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    ref.invalidate(_syncSettingsProvider);
  }
}

class _NotificationSettingsSection extends StatefulWidget {
  @override
  State<_NotificationSettingsSection> createState() =>
      _NotificationSettingsState();
}

class _NotificationSettingsState extends State<_NotificationSettingsSection> {
  bool _transportChanges = true;
  bool _syncErrors = true;
  bool _offlineOnline = true;
  bool _queueFull = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _transportChanges =
          prefs.getBool(TransportNotificationPrefs.keyTransportChanges) ?? true;
      _syncErrors =
          prefs.getBool(TransportNotificationPrefs.keySyncErrors) ?? true;
      _offlineOnline =
          prefs.getBool(TransportNotificationPrefs.keyOfflineOnline) ?? true;
      _queueFull =
          prefs.getBool(TransportNotificationPrefs.keyQueueFull) ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.telegramNotifications,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacing),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.transportNotifyChanges),
              subtitle: Text(
                AppLocalizations.of(context)!.transportNotifyChangesDesc,
              ),
              value: _transportChanges,
              onChanged: (value) {
                setState(() => _transportChanges = value);
                _saveSetting(
                  TransportNotificationPrefs.keyTransportChanges,
                  value,
                );
              },
            ),

            const Divider(),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                AppLocalizations.of(context)!.transportNotifySyncErrors,
              ),
              subtitle: Text(
                AppLocalizations.of(context)!.transportNotifySyncErrorsDesc,
              ),
              value: _syncErrors,
              onChanged: (value) {
                setState(() => _syncErrors = value);
                _saveSetting(TransportNotificationPrefs.keySyncErrors, value);
              },
            ),

            const Divider(),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                AppLocalizations.of(context)!.transportNotifyOfflineOnline,
              ),
              subtitle: Text(
                AppLocalizations.of(context)!.transportNotifyConnectivityDesc,
              ),
              value: _offlineOnline,
              onChanged: (value) {
                setState(() => _offlineOnline = value);
                _saveSetting(
                  TransportNotificationPrefs.keyOfflineOnline,
                  value,
                );
              },
            ),

            const Divider(),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                AppLocalizations.of(context)!.transportNotifyQueueFull,
              ),
              subtitle: Text(
                AppLocalizations.of(context)!.transportNotifyQueueFullDesc,
              ),
              value: _queueFull,
              onChanged: (value) {
                setState(() => _queueFull = value);
                _saveSetting(TransportNotificationPrefs.keyQueueFull, value);
              },
            ),
          ],
        ),
      ),
    );
  }
}
