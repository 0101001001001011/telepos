import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/app_localizations.dart';
import '../../../domain/entities/telegram/auth_state.dart';
import '../../../telegram/auth/telegram_auth_service.dart';
import '../../../telegram/automation/auto_channel_creator.dart';
import '../../../telegram/channels/channel_registry.dart';
import '../../../telegram/channels/channel_types.dart';
import '../../../telegram/core/tdlib_logger.dart';
import '../../../telegram/core/telegram_credentials.dart';
import '../../common/help/help_button.dart';
import '../../controllers/transport/transport_controller.dart';
import 'telegram_auth_screen.dart';
import 'widgets/sync_status_widget.dart';

final _telegramAuthStatusProvider = StreamProvider<TelegramAuthState>((ref) {
  if (GetIt.I.isRegistered<TelegramAuthService>()) {
    final authService = GetIt.I<TelegramAuthService>();
    return authService.stateStream;
  }
  return const Stream.empty();
});

final _channelsProvider = FutureProvider<List<_ChannelInfo>>((ref) async {
  if (!GetIt.I.isRegistered<ChannelRegistry>()) {
    return [];
  }

  final registry = GetIt.I<ChannelRegistry>();
  await registry.restore();

  final channels = <_ChannelInfo>[];
  for (final type in SystemChannelType.values) {
    final channel = registry.get(type);
    channels.add(
      _ChannelInfo(
        type: type,
        name: channel?.title ?? _getDefaultChannelName(type),
        isConnected: channel != null,
        chatId: channel?.chatId,
      ),
    );
  }
  return channels;
});

String _getDefaultChannelName(SystemChannelType type) {
  return switch (type) {
    SystemChannelType.posSystem => 'POS-System',
    SystemChannelType.posSales => 'POS-Sales',
    SystemChannelType.posAlerts => 'POS-Alerts',
    SystemChannelType.posReports => 'POS-Reports',
    SystemChannelType.posSync => 'POS-Sync',
    SystemChannelType.posFiscal => 'POS-Fiscal',
    SystemChannelType.staffChat => 'Staff-Chat',
    SystemChannelType.posDataExchange => 'POS-DataExchange',
    SystemChannelType.posTerminalStatus => 'POS-Status',
    SystemChannelType.posBackup => 'POS-Backup',
  };
}

String _getChannelDescription(SystemChannelType type, AppLocalizations l10n) {
  return switch (type) {
    SystemChannelType.posSystem => l10n.channelDescSystemEvents,
    SystemChannelType.posSales => l10n.channelDescSales,
    SystemChannelType.posAlerts => l10n.channelDescAlerts,
    SystemChannelType.posReports => l10n.channelDescReports,
    SystemChannelType.posSync => l10n.channelDescSync,
    SystemChannelType.posFiscal => l10n.channelDescFiscal,
    SystemChannelType.staffChat => l10n.channelDescStaffChat,
    SystemChannelType.posDataExchange => l10n.channelDescDataExchange,
    SystemChannelType.posTerminalStatus => l10n.channelDescTerminalStatus,
    SystemChannelType.posBackup => l10n.channelDescBackup,
  };
}

class TelegramSettingsScreen extends ConsumerStatefulWidget {
  const TelegramSettingsScreen({super.key});

  @override
  ConsumerState<TelegramSettingsScreen> createState() =>
      _TelegramSettingsScreenState();
}

class _TelegramSettingsScreenState
    extends ConsumerState<TelegramSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _autoSyncEnabled = true;
  Duration _syncInterval = const Duration(minutes: 5);
  bool _isSyncing = false;
  bool _isRecreatingChannels = false;

  final _apiIdController = TextEditingController();
  final _apiHashController = TextEditingController();
  bool _apiConfigured = false;
  bool _savingApi = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _refreshApiStatus();
  }

  @override
  void dispose() {
    _apiIdController.dispose();
    _apiHashController.dispose();
    super.dispose();
  }

  /// The credentials store is registered only when the Telegram module is
  /// enabled, but the pair has to be enterable before that — so fall back to a
  /// standalone instance.
  TelegramCredentials _credentialsStore() =>
      GetIt.I.isRegistered<TelegramCredentials>()
      ? GetIt.I<TelegramCredentials>()
      : TelegramCredentials(logger: TdLibLogger());

  Future<void> _refreshApiStatus() async {
    final configured = await _credentialsStore().hasCredentials();
    if (!mounted) return;
    setState(() => _apiConfigured = configured);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('telegram_notifications') ?? true;
      _autoSyncEnabled = prefs.getBool('telegram_auto_sync') ?? true;
      final intervalMinutes = prefs.getInt('sync_interval') ?? 5;
      _syncInterval = Duration(minutes: intervalMinutes);
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final authStateAsync = ref.watch(_telegramAuthStatusProvider);

    final isAuthorized = authStateAsync.when(
      data: (state) => state is TelegramAuthStateAuthorized,
      loading: () => false,
      error: (_, __) => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.telegramTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: const [HelpButton(screenId: 'telegram_settings')],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildApiCredentialsSection(theme),
            const SizedBox(height: 24),

            _buildAuthSection(theme, isAuthorized, authStateAsync),
            const SizedBox(height: 24),

            _buildSyncStatusSection(theme),
            const SizedBox(height: 24),

            _buildNotificationsSection(theme),
            const SizedBox(height: 24),

            _buildSyncSettingsSection(theme),
            const SizedBox(height: 24),

            _buildChannelsSection(theme),
            const SizedBox(height: 24),

            _buildActionsSection(theme, isAuthorized),
          ],
        ),
      ),
    );
  }

  Future<void> _saveApiCredentials() async {
    final l10n = AppLocalizations.of(context)!;
    final apiId = int.tryParse(_apiIdController.text.trim());
    final apiHash = _apiHashController.text.trim();

    if (apiId == null || apiId <= 0 || apiHash.isEmpty) {
      _showApiSnack(l10n.telegramApiInvalid);
      return;
    }

    setState(() => _savingApi = true);
    try {
      await _credentialsStore().saveApiCredentials(
        apiId: apiId,
        apiHash: apiHash,
      );
      _apiIdController.clear();
      _apiHashController.clear();
      await _refreshApiStatus();
      _showApiSnack(l10n.telegramApiSaved);
    } finally {
      if (mounted) setState(() => _savingApi = false);
    }
  }

  Future<void> _clearApiCredentials() async {
    final l10n = AppLocalizations.of(context)!;
    await _credentialsStore().clearApiCredentials();
    await _refreshApiStatus();
    _showApiSnack(l10n.telegramApiCleared);
  }

  void _showApiSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildApiCredentialsSection(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.vpn_key, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  l10n.telegramApiSectionTitle,
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    _apiConfigured
                        ? l10n.telegramApiStatusConfigured
                        : l10n.telegramApiStatusMissing,
                  ),
                  backgroundColor: _apiConfigured
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.errorContainer,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.telegramApiSectionDesc,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiIdController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.telegramApiIdLabel,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiHashController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.telegramApiHashLabel,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _savingApi ? null : _saveApiCredentials,
                  icon: const Icon(TeleposIcons.save),
                  label: Text(l10n.telegramApiSave),
                ),
                const SizedBox(width: 12),
                if (_apiConfigured)
                  TextButton.icon(
                    onPressed: _savingApi ? null : _clearApiCredentials,
                    icon: const Icon(TeleposIcons.delete),
                    label: Text(l10n.telegramApiClear),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthSection(
    ThemeData theme,
    bool isAuthorized,
    AsyncValue<TelegramAuthState> authStateAsync,
  ) {
    final l10n = AppLocalizations.of(context)!;
    String? phoneNumber;
    authStateAsync.whenData((state) {
      if (state is TelegramAuthStateAuthorized) {
        phoneNumber = state.phoneNumber;
      }
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.telegram,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.telegramAuth,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _AuthStatusIndicator(
              isAuthorized: isAuthorized,
              phoneNumber: phoneNumber,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToAuth,
                icon: Icon(isAuthorized ? Icons.settings : Icons.login),
                label: Text(
                  isAuthorized ? l10n.telegramManageAccount : l10n.loginEnter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusSection(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sync, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  l10n.telegramSync,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SyncStatusWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsSection(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.telegramNotificationsSection,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(l10n.telegramNotifications),
              subtitle: Text(l10n.telegramNotificationsDesc),
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() => _notificationsEnabled = value);
                _saveSetting('telegram_notifications', value);
              },
            ),
            const Divider(),
            _buildNotificationTypeToggle(
              'notify_sales',
              l10n.telegramNotifySales,
              l10n.telegramNotifySalesDesc,
              true,
            ),
            _buildNotificationTypeToggle(
              'notify_shifts',
              l10n.telegramNotifyShifts,
              l10n.telegramNotifyShiftsDesc,
              true,
            ),
            _buildNotificationTypeToggle(
              'notify_critical',
              l10n.telegramNotifyCritical,
              l10n.telegramNotifyCriticalDesc,
              true,
            ),
            _buildNotificationTypeToggle(
              'notify_stock',
              l10n.telegramNotifyStock,
              l10n.telegramNotifyStockDesc,
              false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTypeToggle(
    String key,
    String title,
    String subtitle,
    bool defaultValue,
  ) {
    return FutureBuilder<bool>(
      future: _getNotificationSetting(key, defaultValue),
      builder: (context, snapshot) {
        final value = snapshot.data ?? defaultValue;
        return CheckboxListTile(
          title: Text(title),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          value: value,
          onChanged: _notificationsEnabled
              ? (newValue) {
                  _saveSetting(key, newValue ?? defaultValue);
                  setState(() {});
                }
              : null,
          dense: true,
        );
      },
    );
  }

  Future<bool> _getNotificationSetting(String key, bool defaultValue) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? defaultValue;
  }

  Widget _buildSyncSettingsSection(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.telegramSyncSettings,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(l10n.telegramAutoSync),
              subtitle: Text(l10n.telegramAutoSyncDesc),
              value: _autoSyncEnabled,
              onChanged: (value) {
                setState(() => _autoSyncEnabled = value);
                _saveSetting('telegram_auto_sync', value);
              },
            ),
            if (_autoSyncEnabled) ...[
              const Divider(),
              ListTile(
                title: Text(l10n.telegramSyncInterval),
                subtitle: Text(_formatInterval(_syncInterval)),
                trailing: DropdownButton<Duration>(
                  value: _syncInterval,
                  underline: const SizedBox(),
                  items: [
                    DropdownMenuItem(
                      value: const Duration(minutes: 1),
                      child: Text(l10n.telegramSyncInterval1min),
                    ),
                    DropdownMenuItem(
                      value: const Duration(minutes: 5),
                      child: Text(l10n.telegramSyncInterval5min),
                    ),
                    DropdownMenuItem(
                      value: const Duration(minutes: 15),
                      child: Text(l10n.telegramSyncInterval15min),
                    ),
                    DropdownMenuItem(
                      value: const Duration(minutes: 30),
                      child: Text(l10n.telegramSyncInterval30min),
                    ),
                    DropdownMenuItem(
                      value: const Duration(hours: 1),
                      child: Text(l10n.telegramSyncInterval1hour),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _syncInterval = value);
                      _saveSetting('sync_interval', value.inMinutes);
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChannelsSection(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final channelsAsync = ref.watch(_channelsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.forum, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  l10n.telegramSystemChannels,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () => ref.invalidate(_channelsProvider),
                  tooltip: l10n.telegramRefresh,
                ),
              ],
            ),
            const SizedBox(height: 16),
            channelsAsync.when(
              data: (channels) {
                if (channels.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        l10n.telegramChannelsNotConnected,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final connectedCount = channels
                    .where((c) => c.isConnected)
                    .length;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        l10n.telegramChannelsConnected(
                          connectedCount,
                          channels.length,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    ...channels.map((channel) => _buildChannelTile(channel)),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(
                child: Text(
                  l10n.telegramChannelsLoadError(e.toString()),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelTile(_ChannelInfo channel) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: Icon(
        channel.isConnected ? TeleposIcons.checkCircle : Icons.cancel,
        color: channel.isConnected ? Colors.green : Colors.grey,
      ),
      title: Text(channel.name),
      subtitle: Text(_getChannelDescription(channel.type, l10n)),
      trailing: channel.isConnected && channel.chatId != null
          ? Text(
              '#${channel.chatId}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            )
          : null,
      dense: true,
    );
  }

  Widget _buildActionsSection(ThemeData theme, bool isAuthorized) {
    final l10n = AppLocalizations.of(context)!;
    ref.watch(transportControllerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  l10n.telegramActionsSection,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: _isSyncing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              title: Text(l10n.telegramForceSync),
              subtitle: Text(l10n.telegramForceSyncDesc),
              trailing: const Icon(Icons.chevron_right),
              enabled: isAuthorized && !_isSyncing,
              onTap: _forceSync,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.sync_alt),
              title: Text(l10n.telegramFullSync),
              subtitle: Text(l10n.telegramFullSyncDesc),
              trailing: const Icon(Icons.chevron_right),
              enabled: isAuthorized && !_isSyncing,
              onTap: _forceFullSync,
            ),
            const Divider(),
            ListTile(
              leading: _isRecreatingChannels
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              title: Text(l10n.telegramRecreateChannels),
              subtitle: Text(l10n.telegramRecreateChannelsDesc),
              trailing: const Icon(Icons.chevron_right),
              enabled: isAuthorized && !_isRecreatingChannels,
              onTap: _recreateChannels,
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: theme.colorScheme.error),
              title: Text(
                l10n.telegramLogout,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              subtitle: Text(l10n.telegramLogoutDesc),
              trailing: const Icon(Icons.chevron_right),
              enabled: isAuthorized,
              onTap: _showLogoutConfirmation,
            ),
          ],
        ),
      ),
    );
  }

  String _formatInterval(Duration duration) {
    final l10n = AppLocalizations.of(context)!;
    if (duration.inHours > 0) {
      return l10n.telegramSyncInterval1hour;
    }
    return switch (duration.inMinutes) {
      1 => l10n.telegramSyncInterval1min,
      5 => l10n.telegramSyncInterval5min,
      15 => l10n.telegramSyncInterval15min,
      30 => l10n.telegramSyncInterval30min,
      _ => '${duration.inMinutes} min',
    };
  }

  void _navigateToAuth() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const TelegramAuthScreen()),
    );

    if (result == true && mounted) {
      ref.invalidate(_channelsProvider);
    }
  }

  Future<void> _forceSync() async {
    setState(() => _isSyncing = true);

    try {
      await ref.read(transportControllerProvider.notifier).forceSync();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.telegramSyncComplete),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.telegramSyncError}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _forceFullSync() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dl10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text('${dl10n.telegramFullSync}?'),
          content: Text(dl10n.telegramFullSyncWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(dl10n.globalCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(dl10n.globalConfirm),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isSyncing = true);

    try {
      await ref.read(transportControllerProvider.notifier).forceSyncAll();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.telegramSyncComplete),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.globalError}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _recreateChannels() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dl10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text('${dl10n.telegramRecreateChannels}?'),
          content: Text(dl10n.telegramRecreateChannelsWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(dl10n.globalCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(dl10n.globalConfirm),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isRecreatingChannels = true);

    try {
      if (GetIt.I.isRegistered<AutoChannelCreator>()) {
        final channelCreator = GetIt.I<AutoChannelCreator>();
        final prefs = await SharedPreferences.getInstance();
        final storeName = prefs.getString('store_name') ?? 'TelePOS';
        final posId = prefs.getString('pos_id') ?? 'pos-1';

        await channelCreator.createAll(storeName: storeName, posId: posId);
      }

      ref.invalidate(_channelsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.telegramChannelsRecreated,
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.globalError}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRecreatingChannels = false);
      }
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) {
        final dl10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text('${dl10n.telegramLogout}?'),
          content: Text(dl10n.telegramLogoutWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(dl10n.globalCancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await _logout();
              },
              child: Text(dl10n.loginLogout),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      if (GetIt.I.isRegistered<TelegramAuthService>()) {
        final authService = GetIt.I<TelegramAuthService>();
        await authService.logOut();
      }

      ref.invalidate(_channelsProvider);
      ref.invalidate(_telegramAuthStatusProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.telegramLogoutComplete),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.globalError}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _AuthStatusIndicator extends StatelessWidget {
  final bool isAuthorized;
  final String? phoneNumber;

  const _AuthStatusIndicator({this.isAuthorized = false, this.phoneNumber});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAuthorized
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAuthorized ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isAuthorized ? TeleposIcons.checkCircle : Icons.warning,
            color: isAuthorized ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAuthorized
                      ? AppLocalizations.of(context)!.telegramConnectedStatus
                      : AppLocalizations.of(context)!.telegramNotConnected,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isAuthorized ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isAuthorized
                      ? phoneNumber ??
                            AppLocalizations.of(context)!.telegramAccountLabel
                      : AppLocalizations.of(context)!.telegramLoginForSync,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelInfo {
  final SystemChannelType type;
  final String name;
  final bool isConnected;
  final int? chatId;

  _ChannelInfo({
    required this.type,
    required this.name,
    required this.isConnected,
    this.chatId,
  });
}
