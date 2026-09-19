import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/controllers/settings/fiscal_settings_controller.dart';
import 'package:telepos/presentation/screens/settings/widgets/fiscal_offset_settings_section.dart';

class FiscalSettingsScreen extends ConsumerStatefulWidget {
  const FiscalSettingsScreen({super.key});

  @override
  ConsumerState<FiscalSettingsScreen> createState() =>
      _FiscalSettingsScreenState();
}

class _FiscalSettingsScreenState extends ConsumerState<FiscalSettingsScreen> {
  final _baseUrlController = TextEditingController();
  final _localModuleController = TextEditingController();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _cashboxController = TextEditingController();
  final _rnmController = TextEditingController();
  final _keyPathController = TextEditingController();
  final _vatRateController = TextEditingController();

  bool _controllersPrimed = false;

  @override
  void dispose() {
    _baseUrlController.dispose();
    _localModuleController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    _apiKeyController.dispose();
    _cashboxController.dispose();
    _rnmController.dispose();
    _keyPathController.dispose();
    _vatRateController.dispose();
    super.dispose();
  }

  void _primeControllers(FiscalSettings s) {
    if (_controllersPrimed) return;
    _controllersPrimed = true;
    _baseUrlController.text = s.baseUrl ?? '';
    _localModuleController.text = s.localModuleUrl ?? '';
    _loginController.text = s.login ?? '';
    _passwordController.text = s.password ?? '';
    _apiKeyController.text = s.apiKey ?? '';
    _cashboxController.text = s.cashboxUniqueNumber ?? '';
    _rnmController.text = s.registrationNumber ?? '';
    _keyPathController.text = s.directOfdKeyPath ?? '';
    _vatRateController.text = s.vatRatePercent.toString();
  }

  FiscalSettingsController get _ctrl =>
      ref.read(fiscalSettingsControllerProvider.notifier);

  void _syncFromControllers() {
    final s = ref.read(fiscalSettingsControllerProvider).settings;
    _ctrl.update(
      s.copyWith(
        baseUrl: _baseUrlController.text.trim(),
        localModuleUrl: _localModuleController.text.trim(),
        login: _loginController.text.trim(),
        password: _passwordController.text,
        apiKey: _apiKeyController.text.trim(),
        cashboxUniqueNumber: _cashboxController.text.trim(),
        registrationNumber: _rnmController.text.trim(),
        directOfdKeyPath: _keyPathController.text.trim(),
        vatRatePercent: _parseVat(_vatRateController.text),
      ),
    );
  }

  Decimal _parseVat(String raw) {
    final v = Decimal.tryParse(raw.trim().replaceAll(',', '.'));
    return v ?? FiscalDefaults.vatRatePercent;
  }

  /// Сколько чеков ждут человека. Ноль — и предлагать нечего.
  Future<int> _unfiscalizedWaiting() async {
    if (!GetIt.I.isRegistered<FiscalQueueStore>()) return 0;
    try {
      return await GetIt.I<FiscalQueueStore>().failedCount();
    } catch (_) {
      return 0;
    }
  }

  Future<void> _save() async {
    _syncFromControllers();
    final ok = await _ctrl.save();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final state = ref.read(fiscalSettingsControllerProvider);
    if (ok) {
      // Единственное исключение из «автоматического повтора не бывает», и
      // оно **не тихое**: человек только что поправил ровно то, из-за чего
      // оператор отказывал. Повтор всё равно нажимает он сам — здесь ему
      // лишь называют число и дают дорогу к экрану.
      final waiting = await _unfiscalizedWaiting();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.fiscalSettingsSaved),
          backgroundColor: AppColors.success,
          action: waiting == 0
              ? null
              : SnackBarAction(
                  label: l10n.unfiscalizedTitle,
                  textColor: Colors.white,
                  onPressed: () =>
                      context.push(AppRoutes.unfiscalizedReceipts),
                ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.validationError ?? l10n.fiscalSettingsSaveError(''),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(fiscalSettingsControllerProvider);
    final settings = state.settings;

    if (!state.loading) {
      _primeControllers(settings);
    }

    final width = MediaQuery.of(context).size.width;
    final isDesktop = Breakpoints.fromWidth(width) == LayoutType.desktop;
    final operator = settings.operatorType;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fiscalSettingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Единственный вход на экран нефискализованных чеков: кто
          // настраивает оператора, тот и разбирает его отказы — и ключ
          // права у обоих экранов один (`settings.fiscal`).
          IconButton(
            key: const ValueKey('fiscal-unfiscalized'),
            tooltip: l10n.unfiscalizedTitle,
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.push(AppRoutes.unfiscalizedReceipts),
          ),
          TextButton(
            onPressed: _save,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(TeleposIcons.save, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  l10n.fiscalSettingsSave,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 24 : 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection(
                        title: l10n.fiscalSettingsOperator,
                        icon: Icons.receipt_long,
                        child: _buildOperatorSelector(operator),
                      ),
                      const SizedBox(height: 24),

                      if (operator != FiscalOperatorType.none) ...[
                        _buildSection(
                          title: l10n.setFiscalConnection,
                          icon: Icons.vpn_key,
                          child: _buildConnection(settings),
                        ),
                        const SizedBox(height: 24),
                      ],

                      _buildSection(
                        title: l10n.fiscalSettingsVatSettings,
                        icon: Icons.calculate,
                        child: _buildVatSettings(settings),
                      ),
                      const SizedBox(height: 24),

                      // Рядом с настройками оператора, а не в них: лежат
                      // строкой `ThisPos` и сохраняются сразу (решения
                      // заказчика 2026-09-14, дорожка A).
                      _buildSection(
                        title: l10n.fiscalOffsetSection,
                        icon: Icons.card_giftcard,
                        child: const FiscalOffsetSettingsSection(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSection({
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
        // `Material`, а не крашеный `Container`: секция сама обязана быть
        // Material-поверхностью, иначе `SwitchListTile` внутри (строки 279,
        // 416, 430) рисует подсветку нажатия на Material-предке ВЫШЕ этой
        // рамки, и её закрывает собой `DecoratedBox` контейнера. Отклика на
        // нажатие не было с редизайна; Flutter 3.47 завёл на это утверждение
        // и сделал дефект видимым. Эталон приёма — `SettingsSection`
        // (`lib/presentation/common/widgets/settings/settings_section.dart`),
        // на который этот экран ещё не переведён.
        Material(
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Theme.of(context).colorScheme.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ],
    );
  }

  Widget _buildOperatorSelector(FiscalOperatorType selected) {
    return Column(
      children: FiscalOperatorType.values.map((type) {
        final isSelected = selected == type;
        return InkWell(
          key: ValueKey('fiscal-operator-${type.id}'),
          onTap: () {
            _syncFromControllers();
            _ctrl.selectOperator(type);
            _baseUrlController.text =
                ref.read(fiscalSettingsControllerProvider).settings.baseUrl ??
                '';
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 20,
                  color: isSelected
                      ? AppColors.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    type.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildConnection(FiscalSettings settings) {
    final l10n = AppLocalizations.of(context)!;
    final operator = settings.operatorType;
    final isWebkassa = operator == FiscalOperatorType.webkassa;
    final isKassa24 = operator == FiscalOperatorType.kassa24;
    final isDirect = operator == FiscalOperatorType.directOfd;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const ValueKey('fiscal-testmode'),
          value: settings.testMode,
          onChanged: (v) {
            _syncFromControllers();
            final s = ref.read(fiscalSettingsControllerProvider).settings;
            _ctrl.update(s.copyWith(testMode: v));
            final wasDefault =
                s.baseUrl == null ||
                s.baseUrl ==
                    FiscalDefaults.cloudBaseUrl(operator, testMode: !v);
            if (wasDefault) {
              final url =
                  FiscalDefaults.cloudBaseUrl(operator, testMode: v) ?? '';
              _baseUrlController.text = url;
              _ctrl.update(
                ref
                    .read(fiscalSettingsControllerProvider)
                    .settings
                    .copyWith(baseUrl: url),
              );
            }
          },
          title: Text(l10n.setFiscalTestMode),
          subtitle: Text(settings.testMode ? 'TEST' : 'PROD'),
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.primary,
        ),
        const Divider(),

        if (isWebkassa || isKassa24) ...[
          _field(
            l10n.setFiscalLogin,
            _loginController,
            hint: l10n.setFiscalLoginHint,
            keyName: 'fiscal-login',
          ),
          const SizedBox(height: 16),
          _field(
            l10n.setFiscalPassword,
            _passwordController,
            obscure: true,
            keyName: 'fiscal-password',
          ),
          const SizedBox(height: 16),
        ],

        if (isWebkassa) ...[
          _field(
            'X-API-Key',
            _apiKeyController,
            obscure: true,
            keyName: 'fiscal-apikey',
          ),
          const SizedBox(height: 16),
        ],

        _field(
          l10n.setFiscalCashboxSerial,
          _cashboxController,
          hint: l10n.setFiscalCashboxSerialHint,
          keyName: 'fiscal-cashbox',
        ),
        const SizedBox(height: 16),

        _field(l10n.setFiscalRnm, _rnmController, keyName: 'fiscal-rnm'),
        const SizedBox(height: 16),

        if (isDirect) ...[
          _field(
            l10n.setFiscalKeyPath,
            _keyPathController,
            keyName: 'fiscal-keypath',
          ),
          const SizedBox(height: 16),
        ],

        _field(
          l10n.fiscalSettingsOfdHost,
          _baseUrlController,
          hint: l10n.fiscalSettingsOfdHostHint,
          keyboardType: TextInputType.url,
          keyName: 'fiscal-baseurl',
        ),
        const SizedBox(height: 16),

        _field(
          l10n.setFiscalOfflineModule,
          _localModuleController,
          hint: FiscalDefaults.localModuleUrl,
          keyboardType: TextInputType.url,
          keyName: 'fiscal-localmodule',
        ),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    bool obscure = false,
    TextInputType? keyboardType,
    String? keyName,
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
          obscureText: obscure,
          enableSuggestions: !obscure,
          autocorrect: !obscure,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
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

  Widget _buildVatSettings(FiscalSettings settings) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        SwitchListTile(
          key: const ValueKey('fiscal-vatpayer'),
          value: settings.isVatPayer,
          onChanged: (v) {
            _syncFromControllers();
            final s = ref.read(fiscalSettingsControllerProvider).settings;
            _ctrl.update(s.copyWith(isVatPayer: v));
          },
          title: Text(l10n.fiscalSettingsVatPayer),
          subtitle: Text(l10n.fiscalSettingsVatPayerSubtitle),
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.primary,
        ),
        const Divider(),
        SwitchListTile(
          key: const ValueKey('fiscal-printvat'),
          value: settings.printVatOnReceipt,
          onChanged: settings.isVatPayer
              ? (v) {
                  _syncFromControllers();
                  final s = ref.read(fiscalSettingsControllerProvider).settings;
                  _ctrl.update(s.copyWith(printVatOnReceipt: v));
                }
              : null,
          title: Text(l10n.fiscalSettingsPrintVat),
          subtitle: Text(l10n.fiscalSettingsPrintVatSubtitle),
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.primary,
        ),
        if (settings.isVatPayer) ...[
          const Divider(),
          _field(
            l10n.setFiscalVatRate,
            _vatRateController,
            hint: '12',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            keyName: 'fiscal-vatrate',
          ),
        ],
      ],
    );
  }
}
