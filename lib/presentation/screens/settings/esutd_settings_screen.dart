import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/esutd/esutd_service.dart';
import 'package:telepos/data/esutd/esutd_settings_store.dart';
import 'package:telepos/domain/esutd/esutd_settings.dart';
import 'package:telepos/l10n/app_localizations.dart';

class EsutdSettingsScreen extends StatefulWidget {
  const EsutdSettingsScreen({super.key});

  @override
  State<EsutdSettingsScreen> createState() => _EsutdSettingsScreenState();
}

class _EsutdSettingsScreenState extends State<EsutdSettingsScreen> {
  late final EsutdSettingsStore _store;
  late EsutdSettings _settings;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiUrlController = TextEditingController();

  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _store = GetIt.I<EsutdSettingsStore>();
    _settings = _store.load();
    _emailController.text = _settings.email ?? '';
    _passwordController.text = _settings.password ?? '';
    _apiUrlController.text = _settings.apiUrl ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _apiUrlController.dispose();
    super.dispose();
  }

  EsutdSettings _collect() {
    final api = _apiUrlController.text.trim();
    return _settings.copyWith(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      apiUrl: api.isEmpty ? null : api,
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final next = _collect();

    if (next.enabled &&
        ((next.email == null || next.email!.isEmpty) ||
            (next.password == null || next.password!.isEmpty))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.esutdSettingsCredsRequired),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final ok = await _store.save(next);
    if (!mounted) return;
    setState(() => _settings = next);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? l10n.esutdSettingsSaved : l10n.esutdSettingsSaveError,
        ),
        backgroundColor: ok
            ? AppColors.success
            : Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _testLogin() async {
    final l10n = AppLocalizations.of(context)!;
    final next = _collect();
    if ((next.email == null || next.email!.isEmpty) ||
        (next.password == null || next.password!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.esutdSettingsCredsRequired),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    await _store.save(next);
    if (!mounted) return;
    setState(() {
      _settings = next;
      _testing = true;
    });

    final result = await GetIt.I<EsutdService>().login(
      email: next.email,
      password: next.password,
    );
    if (!mounted) return;
    setState(() {
      _testing = false;
      _settings = _store.load();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? l10n.esutdSettingsLoginOk
              : l10n.esutdSettingsLoginError(result.errorMessage ?? '—'),
        ),
        backgroundColor: result.success
            ? AppColors.success
            : Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = _settings;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.esutdSettingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            key: const ValueKey('esutd-settings-save'),
            onPressed: _save,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(TeleposIcons.save, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  l10n.esutdSettingsSave,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section(
                  title: l10n.esutdSettingsConnection,
                  icon: Icons.local_shipping,
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const ValueKey('esutd-enable'),
                        value: s.enabled,
                        onChanged: (v) =>
                            setState(() => _settings = s.copyWith(enabled: v)),
                        title: Text(l10n.esutdSettingsEnable),
                        subtitle: Text(l10n.esutdSettingsEnableSubtitle),
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _section(
                  title: l10n.esutdSettingsCredentials,
                  icon: Icons.vpn_key,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _field(
                        l10n.esutdSettingsEmail,
                        _emailController,
                        keyName: 'esutd-email',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _field(
                        l10n.esutdSettingsPassword,
                        _passwordController,
                        keyName: 'esutd-password',
                        obscure: true,
                      ),
                      const SizedBox(height: 16),
                      _field(
                        l10n.esutdSettingsApiUrl,
                        _apiUrlController,
                        keyName: 'esutd-apiurl',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.esutdSettingsApiUrlHint,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const ValueKey('esutd-test-login'),
                          onPressed: _testing ? null : _testLogin,
                          icon: _testing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.login, size: 18),
                          label: Text(l10n.esutdSettingsTestLogin),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                        ),
                      ),
                      if (s.hasValidSession) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              TeleposIcons.checkCircle,
                              size: 16,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n.esutdSettingsSessionActive,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Text(
                    l10n.esutdSettingsHint,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? keyName,
    TextInputType? keyboardType,
    bool obscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: keyName != null ? ValueKey(keyName) : null,
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
