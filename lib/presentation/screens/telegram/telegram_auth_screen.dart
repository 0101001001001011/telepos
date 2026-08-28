import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/help/help_button.dart';
import 'package:telepos/presentation/controllers/telegram/telegram_setup_controller.dart';

class TelegramAuthScreen extends ConsumerStatefulWidget {
  const TelegramAuthScreen({
    super.key,
    this.embedded = false,
    this.onComplete,
    this.onSkip,
  });

  final bool embedded;

  final void Function(bool success)? onComplete;

  final VoidCallback? onSkip;

  @override
  ConsumerState<TelegramAuthScreen> createState() => _TelegramAuthScreenState();
}

class _TelegramAuthScreenState extends ConsumerState<TelegramAuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  final _storeNameController = TextEditingController();
  final _binController = TextEditingController();
  final _addressController = TextEditingController();
  final _posIdController = TextEditingController(text: 'POS-1');
  final _ownerNameController = TextEditingController();

  String _countryCode = '+7';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(telegramSetupControllerProvider.notifier).startInitialization();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _storeNameController.dispose();
    _binController.dispose();
    _addressController.dispose();
    _posIdController.dispose();
    _ownerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setupState = ref.watch(telegramSetupControllerProvider);
    final theme = Theme.of(context);

    ref.listen(telegramSetupControllerProvider, (previous, next) {
      if (next.isSetupComplete) {
        if (widget.embedded) {
          widget.onComplete?.call(true);
        } else {
          context.go(AppRoutes.initialSetup);
        }
      }
    });

    if (widget.embedded) {
      return _buildEmbeddedContent(setupState, theme);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle(setupState.setupStep)),
        leading: setupState.setupStep != TelegramSetupStep.auth
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  ref.read(telegramSetupControllerProvider.notifier).goBack();
                  _codeController.clear();
                  _passwordController.clear();
                },
              )
            : null,
        actions: const [HelpButton(screenId: 'telegram_auth')],
        bottom: setupState.setupStep == TelegramSetupStep.auth
            ? TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    text: AppLocalizations.of(context)!.telegramTabPhone,
                    icon: const Icon(Icons.phone),
                  ),
                  Tab(
                    text: AppLocalizations.of(context)!.telegramTabQr,
                    icon: const Icon(Icons.qr_code),
                  ),
                ],
              )
            : null,
      ),
      body: SafeArea(child: _buildContent(setupState, theme)),
    );
  }

  Widget _buildEmbeddedContent(TelegramSetupState setupState, ThemeData theme) {
    return Column(
      children: [
        if (setupState.setupStep == TelegramSetupStep.auth ||
            setupState.setupStep == TelegramSetupStep.initializing) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  Icons.telegram,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.telegramAuthLogin,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.telegramLoginForSync,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (setupState.setupStep == TelegramSetupStep.auth)
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  text: AppLocalizations.of(context)!.telegramTabPhone,
                  icon: const Icon(Icons.phone),
                ),
                Tab(
                  text: AppLocalizations.of(context)!.telegramTabQr,
                  icon: const Icon(Icons.qr_code),
                ),
              ],
            ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    ref.read(telegramSetupControllerProvider.notifier).goBack();
                    _codeController.clear();
                    _passwordController.clear();
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  _getAppBarTitle(setupState.setupStep),
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ],

        Expanded(child: _buildContent(setupState, theme)),

        if (setupState.setupStep == TelegramSetupStep.auth ||
            setupState.setupStep == TelegramSetupStep.initializing ||
            setupState.setupStep == TelegramSetupStep.nativeLibraryNotFound)
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton(
              onPressed: widget.onSkip,
              child: Text(AppLocalizations.of(context)!.telegramAuthSkip),
            ),
          ),
      ],
    );
  }

  String _getAppBarTitle(TelegramSetupStep step) {
    final l10n = AppLocalizations.of(context)!;
    return switch (step) {
      TelegramSetupStep.initializing => l10n.telegramInitializing,
      TelegramSetupStep.nativeLibraryNotFound => l10n.telegramErrorTdlib,
      TelegramSetupStep.auth => l10n.telegramAuthLogin,
      TelegramSetupStep.code => l10n.telegramAuthCodeStep,
      TelegramSetupStep.password => l10n.telegramAuth2fa,
      TelegramSetupStep.registration => l10n.telegramRegister,
      TelegramSetupStep.searchingChannels => l10n.telegramSearchingChannels,
      TelegramSetupStep.loadingOrganization => l10n.telegramLoadingData,
      TelegramSetupStep.organizationSetup => l10n.telegramOrgData,
      TelegramSetupStep.creatingChannels => l10n.telegramSetupChannels,
      TelegramSetupStep.keyExchange => l10n.telegramSetupEncryption,
      TelegramSetupStep.complete => l10n.telegramSetupComplete,
    };
  }

  String _localizeError(String? error) {
    if (error == null || error.isEmpty) return '';
    final l10n = AppLocalizations.of(context)!;

    final key = error.contains(':')
        ? error.substring(0, error.indexOf(':'))
        : error;
    return switch (key) {
      'error.telegram_not_initialized' => l10n.errorTelegramNotInitialized,
      'error.telegram_auth_not_initialized' =>
        l10n.errorTelegramAuthNotInitialized,
      'error.phone_send_failed' => l10n.telegramErrorPhoneSendFailed,
      'error.qr_auth_failed' => l10n.telegramErrorQrAuthFailed,
      'error.wrong_code' => l10n.telegramErrorWrongCode,
      'error.wrong_password' => l10n.telegramErrorWrongPassword,
      'error.registration_failed' => l10n.telegramErrorRegistrationFailed,
      'error.channel_search_failed' => l10n.telegramErrorChannelSearchFailed,
      'error.channel_connect_failed' => l10n.telegramErrorChannelConnectFailed,
      'error.channel_create_failed' => l10n.telegramErrorChannelCreateFailed,
      _ => error,
    };
  }

  Widget _buildContent(TelegramSetupState setupState, ThemeData theme) {
    return switch (setupState.setupStep) {
      TelegramSetupStep.initializing => _buildInitializingScreen(
        setupState,
        theme,
      ),
      TelegramSetupStep.nativeLibraryNotFound => _buildNativeLibraryErrorScreen(
        setupState,
        theme,
      ),
      TelegramSetupStep.auth => TabBarView(
        controller: _tabController,
        children: [
          _buildPhoneAuthTab(setupState, theme),
          _buildQrAuthTab(setupState, theme),
        ],
      ),
      TelegramSetupStep.code => _buildCodeInputScreen(setupState, theme),
      TelegramSetupStep.password => _buildPasswordInputScreen(
        setupState,
        theme,
      ),
      TelegramSetupStep.registration => _buildRegistrationScreen(
        setupState,
        theme,
      ),
      TelegramSetupStep.searchingChannels ||
      TelegramSetupStep.loadingOrganization => _buildSearchingScreen(
        setupState,
        theme,
      ),
      TelegramSetupStep.organizationSetup => _buildOrganizationSetupScreen(
        setupState,
        theme,
      ),
      TelegramSetupStep.creatingChannels || TelegramSetupStep.keyExchange =>
        _buildSetupProgressScreen(setupState, theme),
      TelegramSetupStep.complete => _buildSuccessScreen(theme),
    };
  }

  Widget _buildInitializingScreen(
    TelegramSetupState setupState,
    ThemeData theme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(strokeWidth: 3),
            const SizedBox(height: 32),
            Text(
              AppLocalizations.of(context)!.telegramInitializingLong,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.telegramConnecting,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNativeLibraryErrorScreen(
    TelegramSetupState setupState,
    ThemeData theme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                TeleposIcons.error,
                size: 64,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.telegramTdlibNotFound,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.telegramTdlibErrorMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.telegramForWindows,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.telegramWindowsInstructions,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref
                    .read(telegramSetupControllerProvider.notifier)
                    .startInitialization();
              },
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.errorRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneAuthTab(TelegramSetupState setupState, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.telegram, size: 48, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            AppLocalizations.of(context)!.telegramPhoneAuthTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.telegramPhoneAuthDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          DropdownButtonFormField<String>(
            value: _countryCode,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.telegramCountryCodeLabel,
              prefixIcon: const Icon(Icons.flag),
            ),
            items: const [
              DropdownMenuItem(value: '+7', child: Text('+7 (KZ/RU)')),
              DropdownMenuItem(value: '+996', child: Text('+996 (KG)')),
              DropdownMenuItem(value: '+998', child: Text('+998 (UZ)')),
              DropdownMenuItem(value: '+993', child: Text('+993 (TM)')),
              DropdownMenuItem(value: '+1', child: Text('+1 (US)')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _countryCode = value);
              }
            },
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.telegramPhoneNumber,
              prefixIcon: const Icon(Icons.phone),
              prefixText: '$_countryCode ',
              hintText: '(XXX) XXX-XX-XX',
            ),
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
              _PhoneNumberFormatter(),
            ],
            autofocus: true,
          ),
          const SizedBox(height: 8),

          if (setupState.hasError) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _localizeError(setupState.error),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: setupState.isLoading ? null : _submitPhone,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: setupState.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(AppLocalizations.of(context)!.telegramGetCode),
          ),
          const SizedBox(height: 16),

          Text(
            AppLocalizations.of(context)!.telegramTermsNotice,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQrAuthTab(TelegramSetupState setupState, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.qr_code, size: 48, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            AppLocalizations.of(context)!.telegramQrAuthTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.telegramQrAuthDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: setupState.isLoading
                  ? const SizedBox(
                      width: 200,
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : setupState.qrCodeLink != null
                  ? QrImageView(
                      data: setupState.qrCodeLink!,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    )
                  : GestureDetector(
                      onTap: _generateQrCode,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.refresh,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(
                                context,
                              )!.telegramQrTapToGenerate,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.telegramQrHowToScan,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionStep(
                    '1',
                    AppLocalizations.of(context)!.telegramQrStep1,
                  ),
                  _buildInstructionStep(
                    '2',
                    AppLocalizations.of(context)!.telegramQrStep2,
                  ),
                  _buildInstructionStep(
                    '3',
                    AppLocalizations.of(context)!.telegramQrStep3,
                  ),
                  _buildInstructionStep(
                    '4',
                    AppLocalizations.of(context)!.telegramQrStep4,
                  ),
                ],
              ),
            ),
          ),

          if (setupState.qrCodeLink != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _generateQrCode,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.telegramRefreshQr),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildCodeInputScreen(TelegramSetupState setupState, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sms, size: 48, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.telegramEnterCode,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.telegramCodeSentTo(
              setupState.phoneNumber ??
                  '$_countryCode ${_phoneController.text}',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _codeController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.telegramCodeLabel,
              prefixIcon: const Icon(Icons.lock),
              hintText: 'XXXXX',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            autofocus: true,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          if (setupState.hasError) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _localizeError(setupState.error),
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: setupState.isLoading ? null : _submitCode,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: setupState.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(AppLocalizations.of(context)!.globalConfirm),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: setupState.isLoading ? null : _resendCode,
            child: Text(AppLocalizations.of(context)!.resendCode),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordInputScreen(
    TelegramSetupState setupState,
    ThemeData theme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.security, size: 48, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.telegramAuth2fa,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.telegramPasswordDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (setupState.passwordHint != null &&
              setupState.passwordHint!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(
                context,
              )!.telegramPasswordHint(setupState.passwordHint!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 32),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.telegramPasswordLabel,
              prefixIcon: const Icon(Icons.lock),
            ),
            obscureText: true,
            autofocus: true,
          ),
          if (setupState.hasError) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _localizeError(setupState.error),
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: setupState.isLoading ? null : _submitPassword,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: setupState.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(AppLocalizations.of(context)!.loginEnter),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationScreen(
    TelegramSetupState setupState,
    ThemeData theme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_add,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.telegramRegister,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.telegramRegistrationDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _firstNameController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.telegramFirstNameLabel,
              prefixIcon: const Icon(TeleposIcons.person),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _lastNameController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.telegramLastNameLabel,
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),
          if (setupState.hasError) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _localizeError(setupState.error),
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: setupState.isLoading ? null : _register,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: setupState.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(AppLocalizations.of(context)!.telegramSignUp),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchingScreen(TelegramSetupState setupState, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final message =
        setupState.setupStep == TelegramSetupStep.loadingOrganization
        ? l10n.telegramLoadingOrgData
        : l10n.telegramSearchingExistingChannels;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(strokeWidth: 3),
            const SizedBox(height: 32),
            Text(
              message,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              setupState.existingChannelsFound
                  ? l10n.telegramFoundChannels
                  : l10n.telegramCheckingChannels,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizationSetupScreen(
    TelegramSetupState setupState,
    ThemeData theme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.store, size: 48, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.telegramOrgData,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            setupState.existingChannelsFound
                ? AppLocalizations.of(context)!.telegramOrgDataNotLoaded
                : AppLocalizations.of(context)!.telegramOrgDataFirstRun,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          TextField(
            controller: _storeNameController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.telegramStoreNameLabel,
              prefixIcon: const Icon(Icons.store),
              hintText: AppLocalizations.of(context)!.telegramStoreNameHint,
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _binController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.telegramBinLabel,
              prefixIcon: const Icon(Icons.numbers),
              hintText: '123456789012',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
            ],
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.telegramAddressLabel,
              prefixIcon: const Icon(Icons.location_on),
              hintText: AppLocalizations.of(context)!.telegramAddressHint,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _posIdController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.telegramPosIdLabel,
              prefixIcon: const Icon(Icons.point_of_sale),
              hintText: 'POS-1',
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _ownerNameController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.telegramOwnerNameLabel,
              prefixIcon: const Icon(TeleposIcons.person),
            ),
            textCapitalization: TextCapitalization.words,
          ),

          if (setupState.hasError) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _localizeError(setupState.error),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: setupState.isLoading ? null : _submitOrganization,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: setupState.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(AppLocalizations.of(context)!.globalNext),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        TeleposIcons.info,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.telegramImportantNote,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.telegramOrgDataNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submitOrganization() {
    final storeName = _storeNameController.text.trim();
    final bin = _binController.text.trim();

    if (storeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.telegramEnterStoreName),
        ),
      );
      return;
    }

    if (bin.isEmpty || bin.length < 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.telegramInvalidBinIin),
        ),
      );
      return;
    }

    ref
        .read(telegramSetupControllerProvider.notifier)
        .submitOrganizationData(
          storeName: storeName,
          bin: bin,
          address: _addressController.text.trim().isNotEmpty
              ? _addressController.text.trim()
              : null,
          posId: _posIdController.text.trim().isNotEmpty
              ? _posIdController.text.trim()
              : null,
          ownerName: _ownerNameController.text.trim().isNotEmpty
              ? _ownerNameController.text.trim()
              : null,
        );
  }

  Widget _buildSetupProgressScreen(
    TelegramSetupState setupState,
    ThemeData theme,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final stepText = switch (setupState.setupStep) {
      TelegramSetupStep.creatingChannels => l10n.telegramCreatingChannels,
      TelegramSetupStep.keyExchange => l10n.telegramSettingUpEncryption,
      _ => l10n.telegramSettingUp,
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(strokeWidth: 3),
            const SizedBox(height: 32),
            Text(
              stepText,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.telegramPleaseWait,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (setupState.hasError) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _localizeError(setupState.error),
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessScreen(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                TeleposIcons.check,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.telegramSetupDone,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.telegramSetupDoneMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                context.go(AppRoutes.initialSetup);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
              ),
              child: Text(AppLocalizations.of(context)!.globalNext),
            ),
          ],
        ),
      ),
    );
  }

  void _submitPhone() {
    final phone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.isEmpty || phone.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.enterValidPhone)),
      );
      return;
    }

    ref
        .read(telegramSetupControllerProvider.notifier)
        .startPhoneAuth(_countryCode, phone);
  }

  void _submitCode() {
    final code = _codeController.text;
    if (code.isEmpty || code.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.telegramInvalidCode),
        ),
      );
      return;
    }

    ref.read(telegramSetupControllerProvider.notifier).submitCode(code);
  }

  void _submitPassword() {
    final password = _passwordController.text;
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.telegramEnterPassword),
        ),
      );
      return;
    }

    ref.read(telegramSetupControllerProvider.notifier).submitPassword(password);
  }

  void _resendCode() {
    final phone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    ref
        .read(telegramSetupControllerProvider.notifier)
        .startPhoneAuth(_countryCode, phone);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.telegramCodeResent)),
    );
  }

  void _register() {
    final firstName = _firstNameController.text.trim();
    if (firstName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.telegramEnterName),
        ),
      );
      return;
    }

    final lastName = _lastNameController.text.trim();
    ref
        .read(telegramSetupControllerProvider.notifier)
        .register(firstName, lastName.isEmpty ? null : lastName);
  }

  void _generateQrCode() {
    ref.read(telegramSetupControllerProvider.notifier).startQrAuth();
  }
}

class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length && i < 10; i++) {
      if (i == 0) buffer.write('(');
      if (i == 3) buffer.write(') ');
      if (i == 6) buffer.write('-');
      if (i == 8) buffer.write('-');
      buffer.write(digits[i]);
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
