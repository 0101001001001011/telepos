import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/domain/network/wifi_network.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/network/network_controller.dart';

class NetworkSettingsScreen extends ConsumerStatefulWidget {
  const NetworkSettingsScreen({super.key});

  @override
  ConsumerState<NetworkSettingsScreen> createState() =>
      _NetworkSettingsScreenState();
}

class _NetworkSettingsScreenState extends ConsumerState<NetworkSettingsScreen> {
  static const Duration _pollInterval = Duration(seconds: 4);

  Timer? _pollTimer;

  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(networkControllerProvider.notifier).load();
    });
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollStatus());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    super.dispose();
  }

  Future<void> _pollStatus() async {
    if (!mounted) return;
    final state = ref.read(networkControllerProvider);
    if (state.loading || _refreshing || !state.available) return;
    await ref.read(networkControllerProvider.notifier).refreshStatus();
  }

  Future<void> _refreshNow() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(networkControllerProvider.notifier).refreshStatus();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
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
    final state = ref.watch(networkControllerProvider);

    ref.listen<NetworkState>(networkControllerProvider, (prev, next) {
      final err = next.error;
      if (err != null && err != prev?.error) {
        _snack(err, error: true);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.networkTitle),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: state.loading
                ? null
                : () => ref.read(networkControllerProvider.notifier).load(),
            icon: const Icon(Icons.refresh),
            tooltip: l10n.networkRefresh,
          ),
        ],
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : !state.available
          ? _buildUnavailable()
          : _buildBody(state),
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
            // Цвета из темы, а не из констант `AppColors`. Константы
            // одинаковы в обеих темах, и на тёмной это было не «чуть бледнее»,
            // а невидимо — измерено на собранной кассе 2026-08-27, окно в
            // тёмной теме:
            //
            // | элемент   | было (константа)      | контраст | стало   |
            // |-----------|-----------------------|----------|---------|
            // | заголовок | `textPrimary` #111114 |   1.17   |  16.1   |
            // | подпись   | `textSecondary` #707579 | 3.46   |   6.93  |
            //
            // 1.17 — то же число, которым уже назван этот класс дефекта в
            // `test/theme/app_text_styles_test.dart` («дневные чернила на
            // ночной секции»). Порог для текста — 4.5, подпись его тоже не
            // брала.
            Icon(
              Icons.wifi_off,
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
              l10n.networkUnavailableDesc,
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

  Widget _buildBody(NetworkState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEthernetCard(state),
              const SizedBox(height: 20),
              _buildWifiCard(state),
              const SizedBox(height: 20),
              _buildBluetoothCard(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEthernetCard(NetworkState state) {
    final l10n = AppLocalizations.of(context)!;
    final status = state.status;
    final ethConnected = status?.ethernetConnected ?? false;
    final hasInternet = status?.internet ?? false;
    final iface = status?.ethernetInterface;

    return _card(
      icon: Icons.settings_ethernet,
      title: l10n.networkEthernetTitle,
      description: l10n.networkEthernetDesc,
      trailing: _refreshing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              onPressed: _refreshNow,
              icon: const Icon(Icons.refresh),
              tooltip: l10n.networkRefresh,
            ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          children: [
            _statusRow(
              label: l10n.networkCableLabel,
              value: ethConnected
                  ? l10n.networkCableConnected
                  : l10n.networkCableNotConnected,
              ok: ethConnected,
            ),
            const SizedBox(height: 8),
            _statusRow(
              label: l10n.networkInternetLabel,
              value: hasInternet
                  ? l10n.networkInternetAvailable
                  : l10n.networkInternetUnavailable,
              ok: hasInternet,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _openEthernetConfig(iface),
                icon: const Icon(Icons.tune, size: 18),
                label: Text(l10n.networkEthernetConfigure),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEthernetConfig(String? iface) async {
    final l10n = AppLocalizations.of(context)!;
    if (iface == null || iface.isEmpty) {
      _snack(l10n.networkEthernetNoInterface, error: true);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => _EthernetConfigDialog(iface: iface),
    );
  }

  Widget _statusRow({
    required String label,
    required String value,
    required bool ok,
  }) {
    return Row(
      children: [
        Icon(
          ok ? TeleposIcons.checkCircle : Icons.cancel,
          size: 18,
          color: ok
              ? AppColors.success
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ok
                ? AppColors.success
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildWifiCard(NetworkState state) {
    final l10n = AppLocalizations.of(context)!;
    final status = state.status;
    final connectedSsid = (status?.wifiConnected ?? false)
        ? status?.wifiSsid
        : null;

    return _card(
      icon: Icons.wifi,
      title: l10n.networkWifiTitle,
      description: l10n.networkWifiDesc,
      trailing: state.scanningWifi
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton.icon(
              onPressed: () =>
                  ref.read(networkControllerProvider.notifier).scanWifi(),
              icon: const Icon(Icons.search, size: 18),
              label: Text(l10n.networkSearch),
            ),
      child: Column(
        children: [
          if (connectedSsid != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.wifi, size: 20, color: AppColors.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          connectedSsid,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          l10n.networkConnected,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  state.disconnecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: () => ref
                              .read(networkControllerProvider.notifier)
                              .disconnectWifi(),
                          child: Text(
                            l10n.networkDisconnect,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                ],
              ),
            ),
          if (connectedSsid != null) const Divider(height: 12),

          if (state.wifiNetworks.isEmpty && !state.scanningWifi)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.networkWifiSearchHint,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ...state.wifiNetworks
                .where((n) => n.ssid.isNotEmpty && n.ssid != connectedSsid)
                .map((n) => _buildWifiRow(n, state)),
        ],
      ),
    );
  }

  Widget _buildWifiRow(WifiNetwork network, NetworkState state) {
    final busy = state.busySsid == network.ssid;
    return InkWell(
      onTap: busy ? null : () => _onWifiTap(network),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              _wifiSignalIcon(network.signal),
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                network.ssid,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (network.isSecured)
              Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.lock,
                  size: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(width: 6),
            Text(
              '${network.signal}%',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(left: 10),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _wifiSignalIcon(int signal) {
    if (signal >= 70) return Icons.wifi;
    if (signal >= 40) return Icons.wifi_2_bar;
    return Icons.wifi_1_bar;
  }

  Future<void> _onWifiTap(WifiNetwork network) async {
    final l10n = AppLocalizations.of(context)!;
    String? password;
    if (network.isSecured) {
      password = await _askPassword(network.ssid);
      if (password == null) return;
    }
    final res = await ref
        .read(networkControllerProvider.notifier)
        .connectWifi(network.ssid, password);
    if (!mounted) return;
    if (res.success) {
      _snack(l10n.networkConnectedTo(network.ssid));
    } else {
      _snack(
        res.message.isNotEmpty
            ? res.message
            : l10n.networkConnectFailed(network.ssid),
        error: true,
      );
    }
  }

  Future<String?> _askPassword(String ssid) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    var obscure = true;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l10n.networkWifiPasswordTitle(ssid)),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: obscure,
            decoration: InputDecoration(
              labelText: l10n.networkWifiPasswordLabel,
              prefixIcon: const Icon(TeleposIcons.lock),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setLocal(() => obscure = !obscure),
              ),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.globalCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text(l10n.networkConnect),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothCard(NetworkState state) {
    final l10n = AppLocalizations.of(context)!;
    // Граница спеки 2026-08-24: Bluetooth не перенесён на провод. В браузере
    // ([NetworkState.bluetoothAvailable] — `false`) карточка остаётся на
    // экране, но названо это словами, а не пустым списком, который
    // выглядел бы как «пока ничего не нашли».
    if (!state.bluetoothAvailable) {
      return _card(
        icon: Icons.bluetooth_disabled,
        title: l10n.networkBluetoothTitle,
        description: l10n.networkBluetoothDesc,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.networkBluetoothUnavailableInBrowser,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }
    return _card(
      icon: Icons.bluetooth,
      title: l10n.networkBluetoothTitle,
      description: l10n.networkBluetoothDesc,
      trailing: state.scanningBluetooth
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton.icon(
              onPressed: () =>
                  ref.read(networkControllerProvider.notifier).scanBluetooth(),
              icon: const Icon(Icons.search, size: 18),
              label: Text(l10n.networkSearch),
            ),
      child: Column(
        children: [
          if (state.bluetoothDevices.isEmpty && !state.scanningBluetooth)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.networkBluetoothSearchHint,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ...state.bluetoothDevices.map((d) => _buildBtRow(d, state)),
        ],
      ),
    );
  }

  Widget _buildBtRow(
    ({String address, String name}) device,
    NetworkState state,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final busy = state.busyBtAddress == device.address;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.bluetooth,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name.isNotEmpty ? device.name : device.address,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  device.address,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            FilledButton(
              onPressed: state.busyBtAddress != null
                  ? null
                  : () => _onPairTap(device),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(l10n.networkConnect),
            ),
        ],
      ),
    );
  }

  Future<void> _onPairTap(({String address, String name}) device) async {
    final l10n = AppLocalizations.of(context)!;
    final res = await ref
        .read(networkControllerProvider.notifier)
        .pairBluetooth(device.address);
    if (!mounted) return;
    if (res.success) {
      _snack(
        l10n.networkPaired(
          device.name.isNotEmpty ? device.name : device.address,
        ),
      );
    } else {
      _snack(
        res.message.isNotEmpty ? res.message : l10n.networkPairFailed,
        error: true,
      );
    }
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String description,
    required Widget child,
    Widget? trailing,
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
                if (trailing != null) trailing,
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

class _EthernetConfigDialog extends ConsumerStatefulWidget {
  const _EthernetConfigDialog({required this.iface});

  final String iface;

  @override
  ConsumerState<_EthernetConfigDialog> createState() =>
      _EthernetConfigDialogState();
}

class _EthernetConfigDialogState extends ConsumerState<_EthernetConfigDialog> {
  bool _static = false;
  bool _applying = false;

  final _ipCtrl = TextEditingController();
  final _prefixCtrl = TextEditingController(text: '24');
  final _gatewayCtrl = TextEditingController();
  final _dnsCtrl = TextEditingController();

  String? _currentIp;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadDetails);
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _prefixCtrl.dispose();
    _gatewayCtrl.dispose();
    _dnsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    final details = await ref
        .read(networkControllerProvider.notifier)
        .ethernetDetails();
    if (!mounted || details == null) return;
    final addrs = details['addresses'];
    String? ip;
    if (addrs is List && addrs.isNotEmpty) {
      ip = addrs.first.toString();
    } else {
      ip = (details['ip'] ?? details['address'] ?? details['ip4']) as String?;
    }
    final mode = (details['mode'] ?? details['method']) as String?;
    if (ip != null && ip.trim().isNotEmpty) {
      setState(() => _currentIp = ip!.trim());
      final parts = ip.trim().split('/');
      if (_ipCtrl.text.isEmpty && _isIpv4(parts.first)) {
        _ipCtrl.text = parts.first;
        if (parts.length > 1) _prefixCtrl.text = parts[1];
      }
    }
    if (mode == 'manual' || mode == 'static') {
      setState(() => _static = true);
    }
  }

  bool _isIpv4(String v) {
    final parts = v.trim().split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      if (p.isEmpty || p.length > 3) return false;
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  Future<void> _apply() async {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(networkControllerProvider.notifier);

    String? ipCidr;
    String? gateway;
    String? dns;

    if (_static) {
      final ip = _ipCtrl.text.trim();
      if (ip.isEmpty) {
        _toast(l10n.networkEthernetIpRequired, error: true);
        return;
      }
      if (!_isIpv4(ip)) {
        _toast(l10n.networkEthernetInvalidIp, error: true);
        return;
      }
      final prefix = int.tryParse(_prefixCtrl.text.trim());
      if (prefix == null || prefix < 0 || prefix > 32) {
        _toast(l10n.networkEthernetInvalidPrefix, error: true);
        return;
      }
      gateway = _gatewayCtrl.text.trim();
      if (gateway.isNotEmpty && !_isIpv4(gateway)) {
        _toast(l10n.networkEthernetInvalidGateway, error: true);
        return;
      }
      dns = _dnsCtrl.text.trim();
      if (dns.isNotEmpty && !_isIpv4(dns)) {
        _toast(l10n.networkEthernetInvalidDns, error: true);
        return;
      }
      ipCidr = '$ip/$prefix';
    }

    setState(() => _applying = true);
    final res = _static
        ? await notifier.configureEthernetStatic(
            widget.iface,
            ipCidr: ipCidr!,
            gateway: (gateway != null && gateway.isEmpty) ? null : gateway,
            dns: (dns != null && dns.isEmpty) ? null : dns,
          )
        : await notifier.configureEthernetDhcp(widget.iface);
    if (!mounted) return;
    setState(() => _applying = false);

    if (res.success) {
      Navigator.of(context).pop();
      _toast(l10n.networkEthernetApplied);
    } else {
      _toast(
        res.message.isNotEmpty ? res.message : l10n.networkEthernetApplyFailed,
        error: true,
      );
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
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
    return AlertDialog(
      title: Text(l10n.networkEthernetConfigTitle),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow(l10n.networkEthernetInterface, widget.iface),
              if (_currentIp != null) ...[
                const SizedBox(height: 4),
                _infoRow(l10n.networkEthernetCurrentIp, _currentIp!),
              ],
              const SizedBox(height: 16),
              Text(
                l10n.networkEthernetMode,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(l10n.networkEthernetModeDhcp),
                    icon: const Icon(Icons.autorenew, size: 16),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.networkEthernetModeStatic),
                    icon: const Icon(Icons.edit, size: 16),
                  ),
                ],
                selected: {_static},
                onSelectionChanged: _applying
                    ? null
                    : (s) => setState(() => _static = s.first),
              ),
              if (_static) ...[
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _field(
                        controller: _ipCtrl,
                        label: l10n.networkEthernetIpLabel,
                        hint: '192.168.1.50',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _field(
                        controller: _prefixCtrl,
                        label: l10n.networkEthernetPrefixLabel,
                        hint: '24',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _gatewayCtrl,
                  label:
                      '${l10n.networkEthernetGatewayLabel} (${l10n.networkEthernetOptional})',
                  hint: '192.168.1.1',
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _dnsCtrl,
                  label:
                      '${l10n.networkEthernetDnsLabel} (${l10n.networkEthernetOptional})',
                  hint: '8.8.8.8',
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _applying ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.globalCancel),
        ),
        FilledButton(
          onPressed: _applying ? null : _apply,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: _applying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
              : Text(l10n.networkEthernetApply),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: !_applying,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
