import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/settings/scroll_assist_settings.dart';
import 'package:telepos/core/theme/theme_mode_provider.dart';
import 'package:telepos/core/constants/app_constants.dart';
import 'package:telepos/data/seed/seed_data.dart';
import 'package:telepos/core/services/update/update_state.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/update/update_controller.dart';

class GeneralSettingsScreen extends ConsumerStatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  ConsumerState<GeneralSettingsScreen> createState() =>
      _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends ConsumerState<GeneralSettingsScreen> {
  ThisPosEntry? _posInfo;
  bool _isLoading = true;
  bool _blockOversell = false;
  bool _editProduct = false;
  bool _editPrice = false;
  bool _sellInDiscount = false;
  bool _cashInOut = false;
  bool _allowBigAmount = false;
  bool _isKassaPriceDecreasingBlocked = false;

  @override
  void initState() {
    super.initState();
    _loadPosInfo();
  }

  Future<void> _loadPosInfo() async {
    try {
      final db = GetIt.I<AppDatabase>();
      final pos = await db.thisPosDao.get();
      setState(() {
        _posInfo = pos;
        _blockOversell = pos?.blockOversell ?? false;
        _editProduct = pos?.editProduct ?? false;
        _editPrice = pos?.editPrice ?? false;
        _sellInDiscount = pos?.sellInDiscount ?? false;
        _cashInOut = pos?.cashInOut ?? false;
        _allowBigAmount = pos?.allowBigAmount ?? false;
        _isKassaPriceDecreasingBlocked =
            pos?.isKassaPriceDecreasingBlocked ?? false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _changeLanguage(AppLocale locale) async {
    await ref.read(localeProvider.notifier).setLocale(locale);

    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.generalSettingsLanguageChanged(locale.nativeName)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final layoutType = Breakpoints.fromWidth(width);
    final isDesktop = layoutType == LayoutType.desktop;
    final isTablet = layoutType == LayoutType.tablet;

    return Scaffold(
      backgroundColor: isDesktop ? context.semantic.canvas : null,
      appBar: isDesktop
          ? null
          : AppBar(
              title: Text(l10n.generalSettingsTitle),
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 0,
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : isDesktop
          ? _buildDesktopBody(l10n)
          : _buildMobileBody(l10n, isTablet),
    );
  }

  Widget _buildDesktopBody(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              l10n.generalSettingsTitle,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),

          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 900 ? 3 : 2;
              return _buildNavGrid(l10n, crossAxisCount);
            },
          ),
          const SizedBox(height: 24),

          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 900 ? 2 : 1;
              if (crossAxisCount == 1) {
                return Column(
                  children: [
                    _buildSectionCard(
                      title: l10n.generalSettingsPosInfo,
                      description: l10n.generalSettingsPosInfoDesc,
                      icon: Icons.point_of_sale,
                      child: _buildPosInfoContent(l10n),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: l10n.generalSettingsLanguage,
                      description: l10n.generalSettingsLanguageDesc,
                      icon: Icons.language,
                      child: _buildLanguageSelector(),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: l10n.generalSettingsTheme,
                      description: l10n.generalSettingsThemeDesc,
                      icon: Icons.palette_outlined,
                      child: _buildThemeSelector(),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: l10n.generalSettingsCurrency,
                      description: l10n.generalSettingsCurrencyDesc,
                      icon: Icons.currency_exchange,
                      child: _buildCurrencyContent(l10n),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: l10n.setSalesPolicy,
                      description: l10n.setSalesPolicyDesc,
                      icon: Icons.rule,
                      child: _buildSalesPolicyContent(),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: l10n.setScreenTouch,
                      description: l10n.setScreenTouchDesc,
                      icon: Icons.touch_app,
                      child: _buildScrollAssistContent(),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: l10n.generalSettingsAppVersion,
                      description: l10n.generalSettingsVersionDesc,
                      icon: TeleposIcons.info,
                      child: _buildVersionContent(l10n),
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildSectionCard(
                          title: l10n.generalSettingsPosInfo,
                          description: l10n.generalSettingsPosInfoDesc,
                          icon: Icons.point_of_sale,
                          child: _buildPosInfoContent(l10n),
                        ),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          title: l10n.generalSettingsCurrency,
                          description: l10n.generalSettingsCurrencyDesc,
                          icon: Icons.currency_exchange,
                          child: _buildCurrencyContent(l10n),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        _buildSectionCard(
                          title: l10n.generalSettingsLanguage,
                          description: l10n.generalSettingsLanguageDesc,
                          icon: Icons.language,
                          child: _buildLanguageSelector(),
                        ),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          title: l10n.generalSettingsTheme,
                          description: l10n.generalSettingsThemeDesc,
                          icon: Icons.palette_outlined,
                          child: _buildThemeSelector(),
                        ),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          title: l10n.setSalesPolicy,
                          description: l10n.setSalesPolicyDesc,
                          icon: Icons.rule,
                          child: _buildSalesPolicyContent(),
                        ),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          title: l10n.setScreenTouch,
                          description: l10n.setScreenTouchDesc,
                          icon: Icons.touch_app,
                          child: _buildScrollAssistContent(),
                        ),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          title: l10n.generalSettingsAppVersion,
                          description: l10n.generalSettingsVersionDesc,
                          icon: TeleposIcons.info,
                          child: _buildVersionContent(l10n),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBody(AppLocalizations l10n, bool isTablet) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 700 : double.infinity,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNavGrid(l10n, isTablet ? 3 : 2),
              const SizedBox(height: 24),

              _buildSection(
                title: l10n.generalSettingsPosInfo,
                description: l10n.generalSettingsPosInfoDesc,
                icon: Icons.point_of_sale,
                children: [
                  _buildInfoRow(
                    l10n.generalSettingsCashBoxName,
                    _posInfo?.cashBoxName ?? l10n.generalSettingsNotSpecified,
                  ),
                  _buildInfoRow(
                    l10n.generalSettingsCompany,
                    _posInfo?.companyName ?? l10n.generalSettingsNotSpecified,
                  ),
                  _buildInfoRow(
                    l10n.generalSettingsIinBin,
                    _posInfo?.iinbin ?? l10n.generalSettingsNotSpecified,
                  ),
                  _buildInfoRow(
                    l10n.generalSettingsPosId,
                    _posInfo?.id?.toString() ??
                        l10n.generalSettingsNotSpecified,
                  ),
                  _buildInfoRow(
                    l10n.generalSettingsStoreId,
                    _posInfo?.storeId?.toString() ??
                        l10n.generalSettingsNotSpecified,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSection(
                title: l10n.generalSettingsAppVersion,
                description: l10n.generalSettingsVersionDesc,
                icon: TeleposIcons.info,
                children: [
                  _buildInfoRow(
                    l10n.generalSettingsVersion,
                    AppConstants.appVersion,
                  ),
                  _buildInfoRow(
                    l10n.generalSettingsPlatform,
                    _getPlatformName(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSection(
                title: l10n.setSalesPolicy,
                description: l10n.setSalesPolicyDesc,
                icon: Icons.rule,
                children: [_buildSalesPolicyContent()],
              ),
              const SizedBox(height: 20),
              _buildSection(
                title: l10n.setScreenTouch,
                description: l10n.setScreenTouchDesc,
                icon: Icons.touch_app,
                children: [_buildScrollAssistContent()],
              ),
              const SizedBox(height: 20),
              _buildSection(
                title: l10n.generalSettingsLanguage,
                description: l10n.generalSettingsLanguageDesc,
                icon: Icons.language,
                children: [_buildLanguageSelector()],
              ),
              const SizedBox(height: 20),
              _buildSection(
                title: l10n.generalSettingsTheme,
                description: l10n.generalSettingsThemeDesc,
                icon: Icons.palette_outlined,
                children: [_buildThemeSelector()],
              ),
              const SizedBox(height: 20),
              _buildSection(
                title: l10n.generalSettingsCurrency,
                description: l10n.generalSettingsCurrencyDesc,
                icon: Icons.currency_exchange,
                children: [
                  _buildInfoRow(
                    l10n.generalSettingsCurrencySymbol,
                    _posInfo?.currencySymbol ?? '₸',
                  ),
                  _buildInfoRow(
                    l10n.generalSettingsCurrencyCode,
                    _posInfo?.currencyNameShort ?? 'KZT',
                  ),
                  _buildInfoRow(
                    l10n.generalSettingsCountry,
                    _getCountryName(_posInfo?.countryCode),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavGrid(AppLocalizations l10n, int crossAxisCount) {
    final items = [
      _NavItem(
        title: l10n.generalSettingsTransport,
        description: l10n.generalSettingsTransportSubtitle,
        icon: Icons.sync,
        color: AppColors.info,
        onTap: () => context.push(AppRoutes.transportSettings),
        permissionKey: PermissionKeys.routeToPermissionKey(
          AppRoutes.transportSettings,
        ),
      ),
      _NavItem(
        title: l10n.generalSettingsPrinter,
        description: l10n.generalSettingsPrinterSubtitle,
        icon: Icons.print,
        color: AppColors.primary,
        onTap: () => context.push(AppRoutes.printerSettings),
        permissionKey: PermissionKeys.routeToPermissionKey(
          AppRoutes.printerSettings,
        ),
      ),
      _NavItem(
        title: l10n.receiptTemplatesTitle,
        description: l10n.receiptTemplatesSubtitle,
        icon: Icons.receipt,
        color: const Color(0xFF5E35B1),
        onTap: () => context.push(AppRoutes.receiptTemplates),
      ),
      _NavItem(
        title: l10n.labelPrinterSettingsTitle,
        description: l10n.labelPrinterSettingsSubtitle,
        icon: Icons.label_outline,
        color: const Color(0xFF00897B),
        onTap: () => context.push(AppRoutes.labelPrinterSettings),
      ),
      _NavItem(
        title: l10n.generalSettingsFiscal,
        description: l10n.generalSettingsFiscalSubtitle,
        icon: Icons.receipt_long,
        color: AppColors.warning,
        onTap: () => context.push(AppRoutes.fiscalSettings),
        permissionKey: PermissionKeys.routeToPermissionKey(
          AppRoutes.fiscalSettings,
        ),
      ),
      // Пункт 8 C (2026-09-15): провайдер QR и вид оплаты 6.
      _NavItem(
        title: l10n.qrSettingsTitle,
        description: l10n.qrSettingsSubtitle,
        icon: Icons.qr_code_2,
        color: AppColors.primary,
        onTap: () => context.push(AppRoutes.qrProviderSettings),
        permissionKey: PermissionKeys.routeToPermissionKey(
          AppRoutes.qrProviderSettings,
        ),
      ),
      _NavItem(
        title: l10n.esfSettingsTitle,
        description: l10n.esfSettingsSubtitle,
        icon: Icons.description,
        color: const Color(0xFFEF6C00),
        onTap: () => context.push(AppRoutes.esfSettings),
      ),
      _NavItem(
        title: l10n.sntTitle,
        description: l10n.sntSubtitle,
        icon: Icons.local_shipping,
        color: const Color(0xFFD84315),
        onTap: () => context.push(AppRoutes.snt),
      ),
      _NavItem(
        title: l10n.esutdTitle,
        description: l10n.esutdSubtitle,
        icon: Icons.local_shipping_outlined,
        color: const Color(0xFFBF360C),
        onTap: () => context.push(AppRoutes.esutd),
      ),
      _NavItem(
        title: l10n.ismptSettingsTitle,
        description: l10n.ismptSettingsSubtitle,
        icon: Icons.qr_code_2,
        color: const Color(0xFF6A1B9A),
        onTap: () => context.push(AppRoutes.ismptSettings),
      ),
      _NavItem(
        title: l10n.reorderRulesTitle,
        description: l10n.reorderRulesSubtitle,
        icon: Icons.rule,
        color: const Color(0xFF00838F),
        onTap: () => context.push(AppRoutes.reorderRules),
      ),
      // Задача 19 плана «полнота продажи» (2026-09-07): единственный вход на
      // `/promotions`. Экран акций — 323 строки полного CRUD — существовал
      // с маршрутом, зарегистрированным в таблице, и без единого перехода
      // во всём `lib/`: `git grep -rn "AppRoutes.promotions" -- lib` давал
      // только сам роутер. Завести акцию можно было, только набрав адрес
      // руками или через SQL. Двенадцатая подсистема этой семьи; чтобы не
      // появилась тринадцатая, рядом заведён сторож
      // `test/presentation/router/route_navigation_coverage_test.dart`.
      //
      // Место — рядом с «Правилами перезаказа»: тот же класс экрана
      // (правило, которое администратор задаёт один раз и которое дальше
      // само влияет на работу кассы), тот же shell-маршрут.
      //
      // Право — `op.editPrice` через `PermissionKeys.routeToPermissionKey`,
      // как у соседей, а не своим механизмом. Довод — в
      // `permission_keys.dart`, над записью `'/promotions'`.
      _NavItem(
        title: l10n.promoTitle,
        description: l10n.promoSubtitle,
        icon: Icons.local_offer,
        color: const Color(0xFFC2185B),
        onTap: () => context.push(AppRoutes.promotions),
        permissionKey: PermissionKeys.routeToPermissionKey(
          AppRoutes.promotions,
        ),
      ),
      // Задача 12 плана «полнота продажи» (2026-09-07): единственный вход на
      // `/discount-limits`. Пункт заведён **той же работой**, что и таблица
      // пределов, — иначе `DiscountLimits` стала бы четвёртой колонкой без
      // читателя вслед за тремя `usersAllowedTo*` в `ThisPosEntries`.
      //
      // Место — рядом с «Акциями»: тот же класс экрана (правило, которое
      // администратор задаёт один раз и которое дальше само влияет на
      // работу кассы) и тот же ключ права `op.editPrice`.
      _NavItem(
        title: l10n.discountLimitsTitle,
        description: l10n.discountLimitsSubtitle,
        icon: Icons.percent,
        color: const Color(0xFF00695C),
        onTap: () => context.push(AppRoutes.discountLimits),
        permissionKey: PermissionKeys.routeToPermissionKey(
          AppRoutes.discountLimits,
        ),
      ),
      _NavItem(
        title: l10n.generalSettingsRestaurant,
        description: l10n.generalSettingsRestaurantSubtitle,
        icon: Icons.restaurant,
        color: AppColors.success,
        onTap: () => context.push(AppRoutes.restaurantSettings),
        permissionKey: PermissionKeys.routeToPermissionKey(
          AppRoutes.restaurantSettings,
        ),
      ),
      _NavItem(
        title: l10n.hwSettingsTitle,
        description: l10n.hwSettingsSubtitle,
        icon: Icons.devices,
        color: const Color(0xFF607D8B),
        onTap: () => context.push(AppRoutes.hardwareSettings),
        permissionKey: PermissionKeys.routeToPermissionKey(
          AppRoutes.hardwareSettings,
        ),
      ),
      // Рядом с оборудованием, а не с транспортами синхронизации: оператор
      // приходит сюда с планшетом в руках, то есть за рабочим местом, а не за
      // обменом данными между магазинами.
      _NavItem(
        title: l10n.terminalServiceTitle,
        description: l10n.terminalServiceSubtitle,
        icon: Icons.tablet_android,
        color: const Color(0xFF00897B),
        onTap: () => context.push(AppRoutes.terminalServiceSettings),
        permissionKey: PermissionKeys.routeToPermissionKey(
          AppRoutes.terminalServiceSettings,
        ),
      ),
      // Диагностика рядом с эмуляторами не случайно: наладчик приходит сюда
      // одним движением — включил прибор, посмотрел, что ушло.
      _NavItem(
        title: l10n.diagnosticsTitle,
        description: l10n.diagnosticsSubtitle,
        icon: Icons.monitor_heart_outlined,
        color: const Color(0xFF455A64),
        onTap: () => context.push(AppRoutes.diagnostics),
        permissionKey: PermissionKeys.routeToPermissionKey(
          AppRoutes.diagnostics,
        ),
      ),
      // Сразу за браузерными терминалами: оба — про сокеты ЭТОЙ машины, и оба
      // нужны тому, кто настраивает рабочее место, а не обмен между магазинами.
      _NavItem(
        title: l10n.emulatorSettingsTitle,
        description: l10n.emulatorSettingsHint,
        icon: Icons.developer_board,
        color: const Color(0xFF6D4C41),
        onTap: () => context.push(AppRoutes.emulatorSettings),
        permissionKey: PermissionKeys.routeToPermissionKey(
          AppRoutes.emulatorSettings,
        ),
      ),
      _NavItem(
        title: l10n.applianceTitle,
        description: l10n.applianceHubSubtitle,
        icon: Icons.dvr,
        color: const Color(0xFF455A64),
        onTap: () => context.push(AppRoutes.applianceSettings),
        permissionKey: PermissionKeys.routeToPermissionKey(
          AppRoutes.applianceSettings,
        ),
      ),
      _NavItem(
        title: l10n.accountsSettingsTitle,
        description: l10n.accountsSettingsSubtitle,
        icon: Icons.account_balance,
        color: const Color(0xFF5C6BC0),
        onTap: () => context.push(AppRoutes.accountsSettings),
        permissionKey: PermissionKeys.routeToPermissionKey(
          AppRoutes.accountsSettings,
        ),
      ),
      _NavItem(
        title: l10n.generalSettingsTelegram,
        description: l10n.generalSettingsTelegramSubtitle,
        icon: Icons.send,
        color: const Color(0xFF2AABEE),
        onTap: () => context.push(AppRoutes.telegramSettings),
        permissionKey: PermissionKeys.routeToPermissionKey(
          AppRoutes.telegramSettings,
        ),
      ),
      _NavItem(
        title: l10n.generalSettingsAppUpdate,
        description: l10n.generalSettingsAppUpdateSubtitle,
        icon: Icons.system_update,
        color: AppColors.success,
        onTap: () => _showUpdateSection(),
      ),
      _NavItem(
        title: l10n.setDemoData,
        description: l10n.setDemoDataSubtitle,
        icon: Icons.science,
        color: const Color(0xFF9C27B0),
        onTap: () => _generateSeedData(),
      ),
      _NavItem(
        title: l10n.setUsersTitle,
        description: l10n.setUsersSubtitle,
        icon: Icons.people,
        color: Theme.of(context).colorScheme.error,
        onTap: () => context.push(AppRoutes.userManagement),
        permissionKey: PermissionKeys.routeToPermissionKey(
          AppRoutes.userManagement,
        ),
      ),
      // Задача 18, закрытие И31: рядом с «Пользователи» — та же граница
      // права (settings.users), то же решение «кто и как входит в кассу».
      _NavItem(
        title: l10n.authSettingsTitle,
        description: l10n.authSettingsSubtitle,
        icon: Icons.lock_clock,
        color: Theme.of(context).colorScheme.error,
        onTap: () => context.push(AppRoutes.authSettings),
        permissionKey: PermissionKeys.routeToPermissionKey(
          AppRoutes.authSettings,
        ),
      ),
      // Задача 19 закрытия долга безопасности: тот же периметр, что и два
      // пункта над ней. `SessionRegistry.revokeAll()` существовал с задачи 9
      // без единого вызывающего в lib/ и снят задачей 21 — этот пункт ведёт
      // на экран, который зовёт `revokeSession` (не `revokeAll`, которого
      // больше нет).
      _NavItem(
        title: l10n.sessionsTitle,
        description: l10n.sessionsSubtitle,
        icon: Icons.devices_other,
        color: Theme.of(context).colorScheme.error,
        onTap: () => context.push(AppRoutes.sessions),
        permissionKey: PermissionKeys.routeToPermissionKey(AppRoutes.sessions),
      ),
      // Задача 2 работы «знакомство терминала с кассой»: тот же периметр
      // ПРАВА, что и два пункта над ней (`settings.users` —
      // `permission_keys.dart`, `_routePermissions`) — код привязки решает,
      // кто вообще заводит себе новый терминал, а не что к кассе
      // подключено. Оживляет `PairingInvites.mint()` (задача 1 положила его
      // в GetIt) — без этого пункта звать mint() было некому во всём lib/.
      //
      // `color` — не `Theme.of(context).colorScheme.error` (было так до пункта 7 финальной
      // волны правок, 2026-08-24, копипаст трёх строк выше без разбора):
      // общее право не значит общий смысл цвета — «Пользователи»/«Вход»/
      // «Сеансы» красные потому, что несут удаление и отзыв (разрушительное
      // действие), а эта плитка только показывает QR и код — ни одного
      // разрушительного действия на ней нет.
      _NavItem(
        title: l10n.pairingTitle,
        description: l10n.pairingSubtitle,
        icon: Icons.phonelink_setup,
        color: const Color(0xFF1E88E5),
        onTap: () => context.push(AppRoutes.terminalPairing),
        permissionKey: PermissionKeys.routeToPermissionKey(
          AppRoutes.terminalPairing,
        ),
      ),
    ];

    // Правка «второй порядок» закрытия долга безопасности (2026-08-22),
    // пункт 3: до этой правки хаб не проверял ни одного права (grep по
    // `hasPermission`/`routeToPermissionKey` в этом файле был пуст) —
    // администратор без `settings.users` видел плитки «Пользователи»,
    // «Вход и сеанс», «Сеансы», нажимал и молча оказывался на продаже
    // (десктопный `redirect`, `app_router.dart`, уводит на дом без слова
    // объяснения). Источник истины один и тот же, что у сторожа маршрута —
    // `PermissionKeys.routeToPermissionKey()`, тот же приём, каким
    // `NavDestinations._isAllowed` фильтрует боковое меню.
    final permissions = ref.watch(
      appStateProvider.select((s) => s.permissions),
    );
    final visibleItems = items
        .where(
          (item) =>
              item.permissionKey == null ||
              permissions.contains(item.permissionKey),
        )
        .toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: crossAxisCount >= 3 ? 2.4 : 2.0,
      ),
      itemCount: visibleItems.length,
      itemBuilder: (context, index) {
        final item = visibleItems[index];
        return _buildNavCard(item);
      },
    );
  }

  Widget _buildNavCard(_NavItem item) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      // Цвета из темы, а не константы. Константа одинакова в
                      // обеих темах: `textPrimary` (#111114) на тёмной
                      // поверхности давал **1.35:1** — названия плиток
                      // настроек были почти не видны, измерено на собранной
                      // кассе 2026-08-27. Стало 13.97.
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      // 3.0:1 константой против 6.01 из темы — подпись тоже
                      // не брала порог.
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String description,
    required IconData icon,
    required Widget child,
  }) {
    // `Material`, а не `Container` с крашеным `BoxDecoration`: карточка сама
    // должна быть Material-поверхностью. `ListTile` (и `SwitchListTile`,
    // который строит его внутри) рисует подсветку нажатия на ближайшем
    // Material-предке — крашеный `DecoratedBox` между ними закрывал её
    // собой, и нажатие по строке политики продаж не давало отклика вовсе.
    // Дефект жил с редизайна и был невидим до Flutter 3.47, где framework
    // завёл на это утверждение («ListTile background color or ink splashes
    // may be invisible»). Тот же приём уже применён рядом в `_buildNavCard`
    // — `Card` + `InkWell`. `clipBehavior` обязателен: без него подсветка
    // заходит за скруглённые углы.
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Боковые отступы строки-переключателя внутри секции.
  ///
  /// `EdgeInsets.zero` прижимал текст вплотную к краю карточки: секция
  /// (`_buildSection`/`_buildSectionCard`) своих боковых отступов содержимому
  /// не даёт, а `ListTile` по умолчанию отступает на 16 — ноль этот отступ и
  /// снимал. Заголовок секции при этом отступ имеет, поэтому строки под ним
  /// выглядели уехавшими влево. Найдено глазами на собранной кассе
  /// 2026-08-27.
  ///
  /// 16 — то же значение, что у `ListTile` по умолчанию и что в
  /// `AppTheme.listTileTheme` (`app_theme.dart`), а не подобранное число.
  static const _switchRowPadding = EdgeInsets.symmetric(
    horizontal: AppTokens.space16,
  );

  Widget _buildSalesPolicyContent() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        SwitchListTile(
          contentPadding: _switchRowPadding,
          value: _blockOversell,
          title: Text(l10n.setBlockOversell),
          subtitle: Text(
            l10n.setBlockOversellDesc,
            style: const TextStyle(fontSize: 12),
          ),
          onChanged: (v) async {
            setState(() => _blockOversell = v);
            try {
              await GetIt.I<AppDatabase>().thisPosDao.setBlockOversell(v);
            } catch (_) {}
          },
        ),
        SwitchListTile(
          contentPadding: _switchRowPadding,
          value: _editProduct,
          title: Text(l10n.setPolicyEditProduct),
          subtitle: Text(
            l10n.setPolicyEditProductDesc,
            style: const TextStyle(fontSize: 12),
          ),
          onChanged: (v) async {
            setState(() => _editProduct = v);
            try {
              await GetIt.I<AppDatabase>().thisPosDao.updateBusinessFlags(
                editProduct: v,
              );
            } catch (_) {}
          },
        ),
        SwitchListTile(
          contentPadding: _switchRowPadding,
          value: _editPrice,
          title: Text(l10n.setPolicyEditPrice),
          subtitle: Text(
            l10n.setPolicyEditPriceDesc,
            style: const TextStyle(fontSize: 12),
          ),
          onChanged: (v) async {
            setState(() => _editPrice = v);
            try {
              await GetIt.I<AppDatabase>().thisPosDao.updateBusinessFlags(
                editPrice: v,
              );
            } catch (_) {}
          },
        ),
        SwitchListTile(
          contentPadding: _switchRowPadding,
          value: _sellInDiscount,
          title: Text(l10n.setPolicyDiscounts),
          subtitle: Text(
            l10n.setPolicyDiscountsDesc,
            style: const TextStyle(fontSize: 12),
          ),
          onChanged: (v) async {
            setState(() => _sellInDiscount = v);
            try {
              await GetIt.I<AppDatabase>().thisPosDao.updateBusinessFlags(
                sellInDiscount: v,
              );
            } catch (_) {}
          },
        ),
        SwitchListTile(
          contentPadding: _switchRowPadding,
          value: _cashInOut,
          title: Text(l10n.setPolicyCashInOut),
          subtitle: Text(
            l10n.setPolicyCashInOutDesc,
            style: const TextStyle(fontSize: 12),
          ),
          onChanged: (v) async {
            setState(() => _cashInOut = v);
            try {
              await GetIt.I<AppDatabase>().thisPosDao.updateBusinessFlags(
                cashInOut: v,
              );
            } catch (_) {}
          },
        ),
        SwitchListTile(
          contentPadding: _switchRowPadding,
          value: _allowBigAmount,
          title: Text(l10n.setPolicyBigAmount),
          subtitle: Text(
            l10n.setPolicyBigAmountDesc,
            style: const TextStyle(fontSize: 12),
          ),
          onChanged: (v) async {
            setState(() => _allowBigAmount = v);
            try {
              await GetIt.I<AppDatabase>().thisPosDao.updateBusinessFlags(
                allowBigAmount: v,
              );
            } catch (_) {}
          },
        ),
        SwitchListTile(
          contentPadding: _switchRowPadding,
          value: _isKassaPriceDecreasingBlocked,
          title: Text(l10n.setPolicyBlockPriceDecrease),
          subtitle: Text(
            l10n.setPolicyBlockPriceDecreaseDesc,
            style: const TextStyle(fontSize: 12),
          ),
          onChanged: (v) async {
            setState(() => _isKassaPriceDecreasingBlocked = v);
            try {
              await GetIt.I<AppDatabase>().thisPosDao.updateBusinessFlags(
                isKassaPriceDecreasingBlocked: v,
              );
            } catch (_) {}
          },
        ),
      ],
    );
  }

  Widget _buildScrollAssistContent() {
    final l10n = AppLocalizations.of(context)!;
    final enabled = ref.watch(scrollAssistEnabledProvider);
    return SwitchListTile(
      contentPadding: _switchRowPadding,
      value: enabled,
      title: Text(l10n.setScrollAssist),
      subtitle: Text(
        l10n.setScrollAssistDesc,
        style: const TextStyle(fontSize: 12),
      ),
      onChanged: (v) => ref.read(scrollAssistEnabledProvider.notifier).set(v),
    );
  }

  Widget _buildPosInfoContent(AppLocalizations l10n) {
    return Column(
      children: [
        _buildInfoRow(
          l10n.generalSettingsCashBoxName,
          _posInfo?.cashBoxName ?? l10n.generalSettingsNotSpecified,
        ),
        _buildInfoRow(
          l10n.generalSettingsCompany,
          _posInfo?.companyName ?? l10n.generalSettingsNotSpecified,
        ),
        _buildInfoRow(
          l10n.generalSettingsIinBin,
          _posInfo?.iinbin ?? l10n.generalSettingsNotSpecified,
        ),
        _buildInfoRow(
          l10n.generalSettingsPosId,
          _posInfo?.id?.toString() ?? l10n.generalSettingsNotSpecified,
        ),
        _buildInfoRow(
          l10n.generalSettingsStoreId,
          _posInfo?.storeId?.toString() ?? l10n.generalSettingsNotSpecified,
        ),
      ],
    );
  }

  Widget _buildCurrencyContent(AppLocalizations l10n) {
    return Column(
      children: [
        _buildInfoRow(
          l10n.generalSettingsCurrencySymbol,
          _posInfo?.currencySymbol ?? '₸',
        ),
        _buildInfoRow(
          l10n.generalSettingsCurrencyCode,
          _posInfo?.currencyNameShort ?? 'KZT',
        ),
        _buildInfoRow(
          l10n.generalSettingsCountry,
          _getCountryName(_posInfo?.countryCode),
        ),
      ],
    );
  }

  Widget _buildVersionContent(AppLocalizations l10n) {
    return Column(
      children: [
        _buildInfoRow(l10n.generalSettingsVersion, AppConstants.appVersion),
        _buildInfoRow(l10n.generalSettingsPlatform, _getPlatformName()),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    String? description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (description != null)
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
        const SizedBox(height: 12),
        // `Material` по той же причине, что и в `_buildSectionCard` выше:
        // строки секции — `SwitchListTile`, подсветку нажатия закрывал
        // крашеный `DecoratedBox`. Эталон — `SettingsSection`.
        Material(
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Theme.of(context).colorScheme.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// Переключатель темы.
  ///
  /// Заведён 2026-08-27. До него `ThemeModeNotifier.setMode` **не вызывался
  /// ни из одного экрана** (проверено поиском по `lib/`): тема существовала
  /// значением, но выбрать её человек не мог никак — единственным способом
  /// получить тёмную была настройка ОС, то есть выбор случайный и не
  /// принадлежащий продукту.
  ///
  /// Устроен по образцу [_buildLanguageSelector] — тот же список, та же
  /// отметка выбранного: одинаковые вещи должны выглядеть одинаково, иначе
  /// следующий будет гадать, чем они отличаются.
  Widget _buildThemeSelector() {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.watch(themeModeProvider);

    final items = <(ThemeMode, String, IconData)>[
      (ThemeMode.light, l10n.generalSettingsThemeLight, Icons.light_mode),
      (ThemeMode.dark, l10n.generalSettingsThemeDark, Icons.dark_mode),
      (
        ThemeMode.system,
        l10n.generalSettingsThemeSystem,
        Icons.brightness_auto,
      ),
    ];

    return Column(
      children: items.map((item) {
        final (mode, label, icon) = item;
        final isSelected = current == mode;
        return InkWell(
          key: ValueKey('theme-mode-${mode.name}'),
          onTap: () => ref.read(themeModeProvider.notifier).setMode(mode),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? selectedSurfaceOf(context) : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    TeleposIcons.check,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLanguageSelector() {
    final currentLocale = ref.watch(localeProvider);

    return Column(
      children: AppLocale.values.map((locale) {
        final isSelected = currentLocale == locale;
        return InkWell(
          onTap: () => _changeLanguage(locale),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? selectedSurfaceOf(context) : null,
            ),
            child: Row(
              children: [
                Text(locale.flag, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    locale.nativeName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    TeleposIcons.check,
                    color: AppColors.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getPlatformName() {
    if (Theme.of(context).platform == TargetPlatform.windows) {
      return 'Windows';
    } else if (Theme.of(context).platform == TargetPlatform.linux) {
      return 'Linux';
    } else if (Theme.of(context).platform == TargetPlatform.macOS) {
      return 'macOS';
    } else if (Theme.of(context).platform == TargetPlatform.android) {
      return 'Android';
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      return 'iOS';
    }
    return 'Web';
  }

  String _getCountryName(int? countryCode) {
    final l10n = AppLocalizations.of(context)!;
    switch (countryCode) {
      case 0:
        return l10n.countryKazakhstan;
      case 1:
        return l10n.countryRussia;
      case 2:
        return l10n.countryKyrgyzstan;
      case 3:
        return l10n.countryUzbekistan;
      case 4:
        return l10n.countryUSA;
      case 5:
        return l10n.countryTurkmenistan;
      default:
        return l10n.generalSettingsNotSpecified;
    }
  }

  Future<void> _generateSeedData() async {
    final l10n = AppLocalizations.of(context)!;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.setDemoData),
        content: Text(l10n.setDemoDataDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.globalCancel),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'clear'),
            icon: Icon(
              TeleposIcons.delete,
              size: 18,
              color: Theme.of(context).colorScheme.error,
            ),
            label: Text(
              l10n.setDemoClearAll,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, 'generate'),
            icon: const Icon(Icons.download, size: 18),
            label: Text(l10n.setDemoLoad),
          ),
        ],
      ),
    );

    if (action == null || !mounted) return;

    if (action == 'clear') {
      await _clearAllData();
    } else if (action == 'generate') {
      await _loadDemoData();
    }
  }

  Future<void> _clearAllData() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.setClearDataTitle),
        content: Text(l10n.setClearDataContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.globalCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.setClearDeleteAll),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.setClearInProgress),
        duration: const Duration(seconds: 10),
      ),
    );

    try {
      final db = GetIt.I<AppDatabase>();
      await clearAllDemoData(db);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.setClearDone),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.setGenericError(e.toString())),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _loadDemoData() async {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.setDemoGenerating),
        duration: const Duration(seconds: 30),
      ),
    );

    try {
      final db = GetIt.I<AppDatabase>();
      final seeded = await seedIfNeeded(db);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (seeded) {
        final counts = await verifySeedData(db);
        if (!mounted) return;
        final summary = counts.entries
            .where((e) => e.value > 0)
            .map((e) => '${e.key}: ${e.value}')
            .join('\n');
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.setDemoLoadedTitle),
            content: SingleChildScrollView(
              child: Text(
                summary,
                style: const TextStyle(fontFamily: 'TeleposMono', fontSize: 12),
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.globalOk),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.setDemoAlreadyExists),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.setGenericError(e.toString())),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showUpdateSection() {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = Breakpoints.fromWidth(width) == LayoutType.desktop;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => _UpdateDialog(posVersion: AppConstants.appVersion),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx, scrollController) => _UpdateSheet(
            posVersion: AppConstants.appVersion,
            scrollController: scrollController,
          ),
        ),
      );
    }
  }
}

class _NavItem {
  const _NavItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
    this.permissionKey,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  /// `null` — плитка не ведёт на маршрут, охраняемый ключом права (действие
  /// на месте вроде проверки обновлений, или маршрут, для которого
  /// `PermissionKeys.routeToPermissionKey()` осознанно не назначен ни одной
  /// роли — правка «второй порядок» закрытия долга безопасности, 2026-08-22,
  /// пункт 3), — такая плитка видна всегда, тем же решением, каким
  /// `_intentionallyOpenRoutes` в `route_permission_coverage_test.dart`
  /// оставляет её маршрут без сторожа.
  final String? permissionKey;
}

class _UpdateDialog extends ConsumerWidget {
  const _UpdateDialog({required this.posVersion});

  final String posVersion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final updateState = ref.watch(updateProvider);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.system_update, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(l10n.settingsUpdateTitle),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: _UpdateContent(
          posVersion: posVersion,
          updateState: updateState,
          l10n: l10n,
          ref: ref,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.globalClose),
        ),
      ],
    );
  }
}

class _UpdateSheet extends ConsumerWidget {
  const _UpdateSheet({
    required this.posVersion,
    required this.scrollController,
  });

  final String posVersion;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final updateState = ref.watch(updateProvider);

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: context.semantic.canvas,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              const Icon(
                Icons.system_update,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.settingsUpdateTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _UpdateContent(
            posVersion: posVersion,
            updateState: updateState,
            l10n: l10n,
            ref: ref,
          ),
        ],
      ),
    );
  }
}

class _UpdateContent extends StatelessWidget {
  const _UpdateContent({
    required this.posVersion,
    required this.updateState,
    required this.l10n,
    required this.ref,
  });

  final String posVersion;
  final UpdateState updateState;
  final AppLocalizations l10n;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _infoTile(
          context,
          icon: TeleposIcons.info,
          label: l10n.settingsUpdateCurrentVersion,
          value: posVersion,
        ),
        const Divider(height: 24),

        _buildStatusSection(context),

        const SizedBox(height: 16),
        Row(
          children: [
            Icon(
              Icons.schedule,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.settingsUpdateAutoEnabled,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusSection(BuildContext context) {
    switch (updateState.status) {
      case UpdateStatus.idle:
      case UpdateStatus.skipped:
        return _buildCheckButton();

      case UpdateStatus.checking:
        return _buildCheckingIndicator(context);

      case UpdateStatus.available:
        return _buildAvailableSection(context);

      case UpdateStatus.downloading:
        return _buildDownloadingSection(context);

      case UpdateStatus.ready:
        return _buildReadySection(context);

      case UpdateStatus.preUpdateCheck:
        return _buildPreUpdateCheck(context);

      case UpdateStatus.installing:
        return _buildInstallingIndicator(context);

      case UpdateStatus.complete:
        return _buildCompleteSection(context);

      case UpdateStatus.failed:
        return _buildFailedSection(context);
    }
  }

  Widget _buildCheckButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => ref.read(updateProvider.notifier).checkForUpdates(),
        icon: const Icon(Icons.refresh),
        label: Text(l10n.settingsUpdateCheckBtn),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: AppColors.primary),
          foregroundColor: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildCheckingIndicator(BuildContext context) {
    return Column(
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 12),
        Text(
          l10n.settingsUpdateChecking,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // [context] прокинут явно: подложка берётся ролью темы, и без контекста
  // роль не достать. Раньше метод обходился константой.
  Widget _buildAvailableSection(BuildContext context) {
    final info = updateState.updateInfo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.new_releases,
                color: AppColors.success,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsUpdateAvailable(info?.versionString ?? ''),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (info != null)
                      Text(
                        info.fileSizeFormatted,
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

        if (info != null && info.releaseNotes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            l10n.settingsUpdateReleaseNotes,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 120),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.semantic.canvas,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: Text(
                info.releaseNotes,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => ref.read(updateProvider.notifier).downloadUpdate(),
            icon: const Icon(Icons.download),
            label: Text(l10n.settingsUpdateDownloadBtn),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadingSection(BuildContext context) {
    final progress = updateState.downloadProgress ?? 0.0;
    final percent = (progress * 100).toInt().toString();

    return Column(
      children: [
        LinearProgressIndicator(value: progress),
        const SizedBox(height: 12),
        Text(
          l10n.settingsUpdateDownloading(percent),
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildReadySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(
                TeleposIcons.checkCircle,
                color: AppColors.info,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.settingsUpdateAvailable(
                    updateState.updateInfo?.versionString ?? '',
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: updateState.canUpdate
                ? () => ref.read(updateProvider.notifier).installUpdate()
                : null,
            icon: const Icon(Icons.install_desktop),
            label: Text(l10n.settingsUpdateInstallBtn),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppColors.success,
            ),
          ),
        ),
        if (!updateState.canUpdate &&
            updateState.pendingSyncItems.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            l10n.settingsUpdateCloseShift,
            style: const TextStyle(fontSize: 12, color: AppColors.warning),
          ),
        ],
      ],
    );
  }

  Widget _buildPreUpdateCheck(BuildContext context) {
    return Column(
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 12),
        Text(
          l10n.settingsUpdateChecking,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildInstallingIndicator(BuildContext context) {
    return Column(
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 12),
        Text(
          l10n.settingsUpdateInstalling,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildCompleteSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(TeleposIcons.checkCircle, color: AppColors.success),
          const SizedBox(width: 10),
          Text(
            l10n.settingsUpdateUpToDate,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                TeleposIcons.error,
                color: Theme.of(context).colorScheme.error,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsUpdateFailed,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    if (updateState.errorMessage != null)
                      Text(
                        updateState.errorMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () =>
                ref.read(updateProvider.notifier).checkForUpdates(),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.settingsUpdateCheckBtn),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
