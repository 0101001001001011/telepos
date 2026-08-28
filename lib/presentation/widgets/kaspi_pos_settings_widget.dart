import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../hardware/kaspi_pos/kaspi_pos_config.dart';
import '../../hardware/kaspi_pos/kaspi_pos_service.dart';
import '../../l10n/app_localizations.dart';

class KaspiPosSettingsWidget extends StatefulWidget {
  const KaspiPosSettingsWidget({
    required this.service,
    required this.onConfigChanged,
    super.key,
  });

  final KaspiPosService service;

  final ValueChanged<KaspiPosConfig> onConfigChanged;

  @override
  State<KaspiPosSettingsWidget> createState() => _KaspiPosSettingsWidgetState();
}

class _KaspiPosSettingsWidgetState extends State<KaspiPosSettingsWidget> {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late bool _enabled;

  bool _isTesting = false;
  KaspiPosTestResult? _testResult;

  @override
  void initState() {
    super.initState();
    final config = widget.service.config;
    _hostController = TextEditingController(text: config.host);
    _portController = TextEditingController(text: config.port.toString());
    _enabled = config.enabled;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _onConfigChanged() {
    final port =
        int.tryParse(_portController.text) ?? KaspiPosConfig.defaultPort;
    final newConfig = widget.service.config.copyWith(
      host: _hostController.text,
      port: port,
      enabled: _enabled,
    );
    widget.service.updateConfig(newConfig);
    widget.onConfigChanged(newConfig);
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    _onConfigChanged();

    final result = await widget.service.testConnection();

    setState(() {
      _isTesting = false;
      _testResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.credit_card, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.kaspiTerminal,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _enabled,
                  onChanged: (value) {
                    setState(() => _enabled = value);
                    _onConfigChanged();
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _hostController,
              decoration: InputDecoration(
                labelText: l10n.kaspiIpAddress,
                hintText: KaspiPosConfig.defaultHost,
                prefixIcon: const Icon(Icons.router),
                border: const OutlineInputBorder(),
                errorText:
                    _hostController.text.isNotEmpty &&
                        !KaspiPosConfig.isValidIpAddress(_hostController.text)
                    ? l10n.kaspiInvalidIp
                    : null,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              enabled: _enabled,
              onChanged: (_) {
                setState(() {});
                _onConfigChanged();
              },
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _portController,
              decoration: InputDecoration(
                labelText: l10n.kaspiPort,
                hintText: KaspiPosConfig.defaultPort.toString(),
                prefixIcon: const Icon(Icons.settings_ethernet),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              enabled: _enabled,
              onChanged: (_) => _onConfigChanged(),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                FilledButton.icon(
                  onPressed: _enabled && !_isTesting ? _testConnection : null,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.wifi_tethering),
                  label: Text(_isTesting ? l10n.kaspiTesting : l10n.kaspiTest),
                ),
                const SizedBox(width: 16),
                Expanded(child: _buildStatusIndicator(theme)),
              ],
            ),

            if (_testResult != null) ...[
              const SizedBox(height: 12),
              _buildTestResultDetails(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(ThemeData theme) {
    return StreamBuilder<KaspiPosStatus>(
      stream: widget.service.statusStream,
      initialData: widget.service.status,
      builder: (context, snapshot) {
        final l10n = AppLocalizations.of(context)!;
        final status = snapshot.data ?? KaspiPosStatus.disconnected;

        IconData icon;
        Color color;
        String text;

        switch (status) {
          case KaspiPosStatus.disconnected:
            icon = Icons.link_off;
            color = theme.colorScheme.onSurfaceVariant;
            text = l10n.kaspiDisconnected;
            break;
          case KaspiPosStatus.connecting:
            icon = Icons.sync;
            color = theme.colorScheme.primary;
            text = l10n.kaspiConnecting;
            break;
          case KaspiPosStatus.connected:
            icon = TeleposIcons.checkCircle;
            color = Colors.green;
            text = l10n.kaspiConnected;
            break;
          case KaspiPosStatus.error:
            icon = Icons.error;
            color = theme.colorScheme.error;
            text = l10n.kaspiNoConnection;
            break;
        }

        return Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(text, style: TextStyle(color: color)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTestResultDetails(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final result = _testResult!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: result.success
            ? Colors.green.withValues(alpha: 0.1)
            : theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.success ? TeleposIcons.checkCircle : Icons.error,
                color: result.success ? Colors.green : theme.colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                result.success ? l10n.kaspiTestPassed : l10n.kaspiTestFailed,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: result.success
                      ? Colors.green
                      : theme.colorScheme.error,
                ),
              ),
            ],
          ),
          if (result.latencyMs != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.kaspiLatency(result.latencyMs.toString()),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (result.terminalInfo != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.kaspiTerminalInfo(result.terminalInfo!),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (result.errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              result.errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
