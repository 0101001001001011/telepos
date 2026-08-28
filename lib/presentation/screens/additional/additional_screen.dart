import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/platform/platform_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/di/hardware_module.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/hardware/kaspi_pos/kaspi_pos_config.dart';
import 'package:telepos/hardware/kaspi_pos/kaspi_pos_service.dart';
import 'package:telepos/presentation/controllers/update/update_controller.dart';
import 'package:telepos/core/services/update/update_state.dart';
import 'package:window_manager/window_manager.dart';

// static: это enum, значения — константные выражения без BuildContext;
// цвета остаются константами AppColors до тех пор, пока элементы не
// станут вычисляться в виджете, где context доступен.
enum AdditionalAction {
  logout(icon: Icons.logout, color: AppColors.error),
  lockCashier(icon: Icons.lock, color: AppColors.warning),
  togglePrinter(icon: Icons.print, color: AppColors.primary),
  printLastReceipt(icon: Icons.receipt_long, color: AppColors.primary),
  sync(icon: Icons.sync, color: AppColors.info),
  checkPrice(icon: Icons.qr_code_scanner, color: AppColors.primary),
  minimize(
    icon: Icons.minimize,
    color: AppColors.textSecondary,
    desktopOnly: true,
  ),
  customers(icon: Icons.people, color: AppColors.primary),
  update(icon: Icons.system_update, color: AppColors.success),
  additionalPrinter(icon: Icons.print_outlined, color: AppColors.textSecondary),
  catalog(icon: Icons.inventory, color: AppColors.primary),
  supply(icon: Icons.inventory_2, color: AppColors.primary),
  changeLanguage(icon: Icons.language, color: AppColors.primary),
  kaspiPos(icon: Icons.credit_card, color: Color(0xFFF14635));

  const AdditionalAction({
    required this.icon,
    required this.color,
    this.desktopOnly = false,
  });

  final IconData icon;
  final Color color;
  final bool desktopOnly;

  String localizedLabel(AppLocalizations l10n) {
    return switch (this) {
      AdditionalAction.logout => l10n.additionalLogout,
      AdditionalAction.lockCashier => l10n.additionalLockCashier,
      AdditionalAction.togglePrinter => l10n.additionalPrinterAction,
      AdditionalAction.printLastReceipt => l10n.additionalPrintLastReceipt,
      AdditionalAction.sync => l10n.additionalSyncAction,
      AdditionalAction.checkPrice => l10n.additionalCheckPrice,
      AdditionalAction.minimize => l10n.additionalMinimize,
      AdditionalAction.customers => l10n.additionalCustomers,
      AdditionalAction.update => l10n.additionalUpdateAction,
      AdditionalAction.additionalPrinter => l10n.additionalExtraPrinter,
      AdditionalAction.catalog => l10n.catalogTitle,
      AdditionalAction.supply => l10n.additionalSupplyAction,
      AdditionalAction.changeLanguage => l10n.additionalLanguageAction,
      AdditionalAction.kaspiPos => l10n.additionalKaspiPos,
    };
  }
}

class AdditionalScreen extends ConsumerWidget {
  const AdditionalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;
    final isTablet = screenWidth >= 600;

    final actions = AdditionalAction.values
        .where((a) => isDesktop || !a.desktopOnly)
        .toList();

    final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 2);

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              title: Text(AppLocalizations.of(context)!.additionalTitle),
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 0,
            ),
      body: Padding(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  AppLocalizations.of(context)!.additionalTitle,
                  style: AppTextStyles.h2,
                ),
              ),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: isDesktop ? 16 : 12,
                  crossAxisSpacing: isDesktop ? 16 : 12,
                  childAspectRatio: isDesktop ? 1.5 : 1.3,
                ),
                itemCount: actions.length,
                itemBuilder: (context, index) {
                  final action = actions[index];
                  return _ActionCard(
                    action: action,
                    onTap: () => _handleAction(context, ref, action),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(
    BuildContext context,
    WidgetRef ref,
    AdditionalAction action,
  ) {
    switch (action) {
      case AdditionalAction.logout:
        _showLogoutConfirmation(context);
      case AdditionalAction.lockCashier:
        _lockCashier(context);
      case AdditionalAction.togglePrinter:
        _togglePrinter(context);
      case AdditionalAction.printLastReceipt:
        _printLastReceipt(context);
      case AdditionalAction.sync:
        context.go(AppRoutes.sync);
      case AdditionalAction.checkPrice:
        _showPriceChecker(context);
      case AdditionalAction.minimize:
        _minimizeWindow(context);
      case AdditionalAction.customers:
        context.go(AppRoutes.agent);
      case AdditionalAction.update:
        _checkForUpdate(context, ref);
      case AdditionalAction.additionalPrinter:
        _showAdditionalPrinterSettings(context);
      case AdditionalAction.catalog:
        context.go(AppRoutes.catalog);
      case AdditionalAction.supply:
        context.go(AppRoutes.supply);
      case AdditionalAction.changeLanguage:
        _showLanguageSelector(context);
      case AdditionalAction.kaspiPos:
        _openKaspiPos(context);
    }
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.loginLogout),
        content: Text(AppLocalizations.of(context)!.loginLogout),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.globalCancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go(AppRoutes.login);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: AppColors.white,
            ),
            child: Text(AppLocalizations.of(context)!.loginLogout),
          ),
        ],
      ),
    );
  }

  void _lockCashier(BuildContext context) {
    context.go(AppRoutes.login);
  }

  void _togglePrinter(BuildContext context) {
    _showPrinterSettings(context);
  }

  void _showPrinterSettings(BuildContext context) {
    final factory = GetIt.I<PrinterServiceFactory>();
    final currentPrinter = factory.currentPrinter;
    final isConnected = currentPrinter?.isConnected ?? false;

    showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.printerSettings),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: Icon(
                  isConnected ? TeleposIcons.checkCircle : Icons.error,
                  color: isConnected
                      ? AppColors.success
                      : Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  isConnected
                      ? l10n.printerConnected
                      : l10n.printerDisconnected,
                ),
                subtitle: currentPrinter != null
                    ? Text(l10n.additionalPrinterEscPos)
                    : Text(l10n.additionalPrinterNotConfigured),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.wifi),
                title: Text(l10n.additionalPrinterWifi),
                subtitle: Text(l10n.additionalPrinterWifiDesc),
                onTap: () {
                  Navigator.of(context).pop();
                  _showWifiPrinterDialog(context);
                },
              ),
              if (_isMobile)
                ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(l10n.additionalPrinterBluetooth),
                  subtitle: Text(l10n.additionalPrinterBluetoothDesc),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showBluetoothPrinterDialog(context);
                  },
                ),
              if (_isDesktop)
                ListTile(
                  leading: const Icon(Icons.usb),
                  title: Text(l10n.additionalPrinterUsb),
                  subtitle: Text(l10n.additionalPrinterSystem),
                  onTap: () {
                    Navigator.of(context).pop();
                    _connectUsbPrinter(context);
                  },
                ),
            ],
          ),
          actions: [
            if (isConnected)
              TextButton(
                onPressed: () async {
                  await factory.disconnect();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.additionalPrinterDisconnected),
                      ),
                    );
                  }
                },
                child: Text(l10n.printerDisconnect),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.globalClose),
            ),
          ],
        );
      },
    );
  }

  void _showWifiPrinterDialog(BuildContext context) {
    final ipController = TextEditingController();
    final portController = TextEditingController(text: '9100');

    showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.additionalPrinterWifi),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ipController,
                decoration: InputDecoration(
                  labelText: l10n.additionalPrinterIpLabel,
                  hintText: '192.168.1.100',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: portController,
                decoration: InputDecoration(
                  labelText: l10n.printerPort,
                  hintText: '9100',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.globalCancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final ip = ipController.text.trim();
                final port = int.tryParse(portController.text) ?? 9100;

                if (ip.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.additionalPrinterEnterIp)),
                  );
                  return;
                }

                Navigator.of(context).pop();
                await _connectWifiPrinter(context, ip, port);
              },
              child: Text(l10n.printerConnect),
            ),
          ],
        );
      },
    );
  }

  Future<void> _connectWifiPrinter(
    BuildContext context,
    String ip,
    int port,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final factory = GetIt.I<PrinterServiceFactory>();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.additionalPrinterConnecting('$ip:$port'))),
    );

    final printer = factory.createWifiPrinter(host: ip, port: port);
    final result = await printer.connect();

    if (context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? l10n.additionalPrinterConnectedName(
                    result.printerInfo?.name ?? '',
                  )
                : l10n.additionalErrorWithMessage(result.errorMessage ?? ''),
          ),
          backgroundColor: result.success
              ? AppColors.success
              : Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showBluetoothPrinterDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.additionalPrinterBluetooth),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.globalLoading),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.globalCancel),
          ),
        ],
      ),
    );
  }

  Future<void> _connectUsbPrinter(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final factory = GetIt.I<PrinterServiceFactory>();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.additionalPrinterConnectingUsb)),
    );

    PrinterManager printer;
    try {
      if (PlatformInfo.isWindows) {
        printer = factory.createWindowsPrinter();
      } else if (PlatformInfo.isLinux) {
        printer = factory.createLinuxPrinter();
      } else {
        throw UnsupportedError(l10n.additionalPrinterUsbNotSupported);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.additionalErrorWithMessage('$e')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    final result = await printer.connect();

    if (context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? l10n.additionalPrinterUsbConnected
                : l10n.additionalErrorWithMessage(result.errorMessage ?? ''),
          ),
          backgroundColor: result.success
              ? AppColors.success
              : Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _printLastReceipt(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final factory = GetIt.I<PrinterServiceFactory>();
    final printer = factory.currentPrinter;

    if (printer == null || !printer.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.additionalPrinterNotConnected),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.additionalPrintingLastReceipt)));

    final db = GetIt.I<AppDatabase>();

    final lastReceiptNo = await db.saleDao.findLastReceiptNo();
    if (lastReceiptNo == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.historyEmpty),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    final sale = await db.saleDao.findByKey(
      lastReceiptNo,
      await _resolvePosId(db, lastReceiptNo),
    );
    if (sale == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.historyEmpty),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    final saleProducts = await db.saleProductDao.findBySale(
      sale.receiptNo,
      sale.posId,
    );
    final products = <ReceiptProductLine>[];
    for (final sp in saleProducts) {
      final info = await db.productInfoDao.findByUcode(sp.ucode);
      products.add(
        ReceiptProductLine(
          name: info?.name ?? l10n.historyProductUcode(sp.ucode.toString()),
          quantity: sp.quantity,
          price: sp.price,
          total: sp.quantity * sp.price,
          discountAmount: sp.priceBefore - sp.price,
        ),
      );
    }

    final salePayments = await db.paymentDao.findBySale(
      sale.receiptNo,
      sale.posId,
    );
    final payments = <ReceiptPaymentLine>[];
    for (final payment in salePayments) {
      final account = await db.accountDao.findById(payment.payeeAccountId);
      payments.add(
        ReceiptPaymentLine(
          name:
              account?.name ??
              l10n.historyAccountId(payment.payeeAccountId.toString()),
          amount: payment.amount,
          isCash: account?.type == 0,
        ),
      );
    }

    final data = SaleReceiptData(
      receiptNo: sale.receiptNo,
      posId: sale.posId,
      posName: 'POS ${sale.posId}',
      storeName: 'TelePOS',
      dateTime: DateTime.fromMillisecondsSinceEpoch(sale.time * 1000),
      cashierName: l10n.loginCashier,
      products: products,
      payments: payments,
      totalAmount: sale.amount,
      isDuplicate: true,
    );

    bool success;
    try {
      final printService = GetIt.I<ReceiptPrintService>();
      // Задание принято — чек будет; отказ очереди — единственная неудача.
      success = !(await printService.printSaleDuplicate(data)).isRejected;
    } catch (_) {
      success = false;
    }

    if (context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? l10n.additionalReceiptPrinted : l10n.historyPrintError,
          ),
          backgroundColor: success
              ? AppColors.success
              : Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<int> _resolvePosId(AppDatabase db, int receiptNo) async {
    final thisPos = await db.thisPosDao.get();
    final thisPosId = thisPos?.id;
    if (thisPosId != null) {
      final sale = await db.saleDao.findByKey(receiptNo, thisPosId);
      if (sale != null) return thisPosId;
    }
    final rows = await db
        .customSelect(
          'SELECT pos_id FROM sales WHERE receipt_no = ? ORDER BY time DESC LIMIT 1',
          variables: [Variable.withInt(receiptNo)],
        )
        .get();
    if (rows.isNotEmpty) {
      return rows.first.read<int>('pos_id');
    }
    return thisPosId ?? 0;
  }

  bool get _isDesktop {
    try {
      return PlatformInfo.isWindows ||
          PlatformInfo.isLinux ||
          PlatformInfo.isMacOS;
    } catch (_) {
      return false;
    }
  }

  bool get _isMobile {
    try {
      return PlatformInfo.isAndroid || PlatformInfo.isIOS;
    } catch (_) {
      return false;
    }
  }

  void _showPriceChecker(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const _PriceCheckerDialog(),
    );
  }

  Future<void> _minimizeWindow(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    if (!_isDesktop) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.additionalMinimizing)));
    try {
      await windowManager.minimize();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.additionalErrorWithMessage('$e')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _checkForUpdate(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _UpdateCheckDialog(),
    );
  }

  void _showAdditionalPrinterSettings(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.additionalExtraPrinterTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.additionalExtraPrinterUsedFor),
              const SizedBox(height: 8),
              Text('\u2022 ${l10n.additionalExtraPrinterLabels}'),
              Text('\u2022 ${l10n.additionalExtraPrinterKitchen}'),
              Text('\u2022 ${l10n.additionalExtraPrinterDuplicate}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.globalClose),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showPrinterSettings(context);
              },
              child: Text(l10n.navSettings),
            ),
          ],
        );
      },
    );
  }

  void _showLanguageSelector(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return SimpleDialog(
          title: Text(l10n.settingsLanguage),
          children: [
            _LanguageOption(code: 'ru', label: l10n.langRussian),
            _LanguageOption(code: 'en', label: l10n.langEnglish),
            _LanguageOption(code: 'kk', label: l10n.langKazakh),
            _LanguageOption(code: 'ky', label: l10n.langKyrgyz),
            _LanguageOption(code: 'uz', label: l10n.langUzbek),
          ],
        );
      },
    );
  }

  void _openKaspiPos(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const _KaspiPosDialog(),
    );
  }
}

class _UpdateCheckDialog extends ConsumerStatefulWidget {
  const _UpdateCheckDialog();

  @override
  ConsumerState<_UpdateCheckDialog> createState() => _UpdateCheckDialogState();
}

class _UpdateCheckDialogState extends ConsumerState<_UpdateCheckDialog> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runCheck());
  }

  Future<void> _runCheck() async {
    try {
      await ref.read(updateProvider.notifier).checkForUpdates();
    } catch (_) {}
    if (mounted) {
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final updateState = ref.watch(updateProvider);

    Widget body;
    if (_checking || updateState.status == UpdateStatus.checking) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(l10n.globalLoading),
        ],
      );
    } else if (updateState.hasUpdate) {
      final version = updateState.updateInfo?.version.toString();
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.system_update, color: AppColors.success, size: 40),
          const SizedBox(height: 12),
          Text(
            version != null
                ? '${l10n.updateAvailable} ($version)'
                : l10n.updateAvailable,
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else if (updateState.errorMessage != null) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, color: AppColors.warning, size: 40),
          const SizedBox(height: 12),
          Text(l10n.syncOffline, textAlign: TextAlign.center),
        ],
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            TeleposIcons.checkCircle,
            color: AppColors.success,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(l10n.additionalLatestVersion, textAlign: TextAlign.center),
        ],
      );
    }

    return AlertDialog(
      title: Text(l10n.additionalUpdate),
      content: SizedBox(width: 280, child: body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.globalClose),
        ),
      ],
    );
  }
}

class _PriceCheckerDialog extends StatefulWidget {
  const _PriceCheckerDialog();

  @override
  State<_PriceCheckerDialog> createState() => _PriceCheckerDialogState();
}

class _PriceCheckerDialogState extends State<_PriceCheckerDialog> {
  final _controller = TextEditingController();
  bool _searching = false;
  bool _searched = false;
  String? _productName;
  Decimal? _price;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _lookup(String value) async {
    final code = value.trim();
    if (code.isEmpty) return;

    setState(() {
      _searching = true;
      _searched = false;
      _productName = null;
      _price = null;
    });

    try {
      final db = GetIt.I<AppDatabase>();
      var product = await db.productInfoDao.findByBarcode(code);
      if (product == null) {
        final ucode = int.tryParse(code);
        if (ucode != null) {
          product = await db.productInfoDao.findByIdAndNotDeleted(ucode);
        }
      }

      Decimal? price;
      String? name;
      if (product != null) {
        name = product.name;
        final priceRow = await db.productPriceDao.findByUcode(product.ucode);
        price = priceRow?.sellingPrice;
      }

      if (mounted) {
        setState(() {
          _searching = false;
          _searched = true;
          _productName = name;
          _price = price;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _searching = false;
          _searched = true;
          _productName = null;
          _price = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    Widget? resultWidget;
    if (_searching) {
      resultWidget = const Padding(
        padding: EdgeInsets.only(top: 16),
        child: CircularProgressIndicator(),
      );
    } else if (_searched) {
      if (_productName != null) {
        resultWidget = Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _productName!,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                _price != null ? _price!.toStringAsFixed(2) : '—',
                style: AppTextStyles.h3.copyWith(color: AppColors.success),
              ),
            ],
          ),
        );
      } else {
        resultWidget = Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            l10n.saleProductNotFound,
            style: AppTextStyles.body.copyWith(color: AppColors.warning),
          ),
        );
      }
    }

    return AlertDialog(
      title: Text(l10n.additionalCheckPrice),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.additionalBarcodeLabel,
                hintText: l10n.additionalBarcodeHint,
                prefixIcon: const Icon(Icons.qr_code),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: _lookup,
            ),
            if (resultWidget != null) resultWidget,
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.globalClose),
        ),
        ElevatedButton(
          onPressed: _searching ? null : () => _lookup(_controller.text),
          child: Text(l10n.additionalCheckPrice),
        ),
      ],
    );
  }
}

class _KaspiPosDialog extends StatefulWidget {
  const _KaspiPosDialog();

  @override
  State<_KaspiPosDialog> createState() => _KaspiPosDialogState();
}

class _KaspiPosDialogState extends State<_KaspiPosDialog> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final KaspiPosService _service;

  bool _connecting = false;
  KaspiPosStatus _status = KaspiPosStatus.disconnected;
  String? _message;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: KaspiPosConfig.defaultHost);
    _portController = TextEditingController(
      text: KaspiPosConfig.defaultPort.toString(),
    );
    _service = KaspiPosService();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final l10n = AppLocalizations.of(context)!;
    final host = _hostController.text.trim();
    final port =
        int.tryParse(_portController.text.trim()) ?? KaspiPosConfig.defaultPort;

    if (!KaspiPosConfig.isValidIpAddress(host) ||
        !KaspiPosConfig.isValidPort(port)) {
      setState(() {
        _status = KaspiPosStatus.error;
        _message = l10n.kaspiInvalidIp;
      });
      return;
    }

    setState(() {
      _connecting = true;
      _status = KaspiPosStatus.connecting;
      _message = null;
    });

    _service.updateConfig(
      KaspiPosConfig(host: host, port: port, enabled: true),
    );

    final result = await _service.testConnection();

    if (mounted) {
      setState(() {
        _connecting = false;
        _status = result.success
            ? KaspiPosStatus.connected
            : KaspiPosStatus.error;
        _message = result.success
            ? (result.terminalInfo ?? l10n.kaspiConnected)
            : (result.errorMessage ?? l10n.kaspiNoConnection);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final (statusColor, statusText) = switch (_status) {
      KaspiPosStatus.connected => (AppColors.success, l10n.kaspiConnected),
      KaspiPosStatus.connecting => (AppColors.info, l10n.kaspiConnecting),
      KaspiPosStatus.error => (
        Theme.of(context).colorScheme.error,
        l10n.kaspiNoConnection,
      ),
      KaspiPosStatus.disconnected => (
        AppColors.warning,
        l10n.additionalKaspiPosNotConnected,
      ),
    };

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF14635),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.credit_card, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(l10n.additionalKaspiPosTitle),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.additionalKaspiPosDesc),
            const SizedBox(height: 16),
            TextField(
              controller: _hostController,
              decoration: InputDecoration(
                labelText: l10n.kaspiIpAddress,
                hintText: KaspiPosConfig.defaultHost,
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portController,
              decoration: InputDecoration(
                labelText: l10n.kaspiPort,
                hintText: KaspiPosConfig.defaultPort.toString(),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Text(_message ?? statusText, style: TextStyle(color: statusColor)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.globalClose),
        ),
        ElevatedButton(
          onPressed: _connecting ? null : _connect,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF14635),
          ),
          child: _connecting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(l10n.printerConnect),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action, required this.onTap});

  final AdditionalAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.semantic.canvas),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(action.icon, color: action.color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                action.localizedLabel(AppLocalizations.of(context)!),
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends ConsumerWidget {
  const _LanguageOption({required this.code, required this.label});

  final String code;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final isSelected = currentLocale.languageCode == code;

    return SimpleDialogOption(
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final changedLabel = AppLocalizations.of(
          context,
        )!.settingsLanguageChanged;
        final locale = AppLocale.fromCode(code);
        Navigator.of(context).pop();
        if (locale != null) {
          await ref.read(localeProvider.notifier).setLocale(locale);
        }
        messenger.showSnackBar(
          SnackBar(content: Text('$changedLabel: $label')),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTextStyles.body)),
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
  }
}
