import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/presentation/common/mixins/barcode_scanner_mixin.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/product/kassa_price_decreasing_blocked_use_case.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/screens/sale/sale_hardware.dart';
import 'package:telepos/presentation/screens/sale/widgets/product_search.dart';
import 'package:telepos/presentation/screens/sale/widgets/quick_products_grid.dart';
import 'package:telepos/presentation/screens/sale/widgets/sale_action_buttons.dart';
import 'package:telepos/presentation/screens/sale/widgets/sale_items_list.dart';
import 'package:telepos/presentation/screens/sale/widgets/sale_items_table.dart';
import 'package:telepos/presentation/screens/sale/widgets/sale_total_panel.dart';

class SaleScreen extends ConsumerStatefulWidget {
  const SaleScreen({super.key});

  @override
  ConsumerState<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends ConsumerState<SaleScreen>
    with BarcodeScannerMixin {
  bool _showQuickProducts = false;

  late final SaleHardware _hardware;

  @override
  void initState() {
    super.initState();
    initBarcodeScanner();
    _hardware = SaleHardware();
    _hardware.showWelcomeOnDisplay();
  }

  @override
  void dispose() {
    disposeBarcodeScanner();
    _hardware.disposeDisplay();
    super.dispose();
  }

  @override
  void onBarcodeScanned(String barcode) {
    ref.read(saleControllerProvider.notifier).addByBarcode(barcode);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Decimal>(saleControllerProvider.select((s) => s.total), (
      previous,
      next,
    ) {
      if (next > Decimal.zero) {
        _hardware.showTotalOnDisplay(next);
      } else {
        _hardware.showWelcomeOnDisplay();
      }
    });

    ref.listen<String?>(saleControllerProvider.select((s) => s.error), (
      previous,
      next,
    ) {
      if (next == kShiftOverAgeError && previous != kShiftOverAgeError) {
        _showShiftOverAgeDialog();
      }
    });

    ref.listen<String?>(saleControllerProvider.select((s) => s.warning), (
      previous,
      next,
    ) {
      if (next != null && next != previous) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.saleExpiredBatchWarning(next),
            ),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 3),
          ),
        );
        ref.read(saleControllerProvider.notifier).clearWarning();
      }
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1200;
    final isTablet = screenWidth >= 900 && screenWidth < 1200;

    if (isDesktop) {
      return _DesktopLayout(
        showQuickProducts: _showQuickProducts,
        onToggleQuickProducts: () {
          setState(() {
            _showQuickProducts = !_showQuickProducts;
          });
        },
        onPay: _handlePay,
        onQuantity: _showQuantityDialog,
        onEdit: _showEditDialog,
        onDefer: _handleDefer,
        onMark: _showMarkDialog,
        onWeigh: _handleWeigh,
        onPrintLabel: _handlePrintLabel,
        showWeigh: _hardware.isScalesConfigured,
        showPrintLabel: _hardware.isLabelPrinterConfigured,
      );
    }

    if (isTablet) {
      return _TabletLayout(
        showQuickProducts: _showQuickProducts,
        onToggleQuickProducts: () {
          setState(() {
            _showQuickProducts = !_showQuickProducts;
          });
        },
        onPay: _handlePay,
        onQuantity: _showQuantityDialog,
        onEdit: _showEditDialog,
        onDefer: _handleDefer,
        onMark: _showMarkDialog,
        onWeigh: _handleWeigh,
        onPrintLabel: _handlePrintLabel,
        showWeigh: _hardware.isScalesConfigured,
        showPrintLabel: _hardware.isLabelPrinterConfigured,
      );
    }

    return _MobileLayout(
      onPay: _handlePay,
      onQuickProducts: () => QuickProductsDialog.show(context),
      onQuantity: _showQuantityDialog,
      onEdit: _showEditDialog,
      onDefer: _handleDefer,
      onMark: _showMarkDialog,
      onWeigh: _handleWeigh,
      onPrintLabel: _handlePrintLabel,
      showWeigh: _hardware.isScalesConfigured,
      showPrintLabel: _hardware.isLabelPrinterConfigured,
    );
  }

  Future<void> _showShiftOverAgeDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final goToShift = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.shiftOverAgeTitle),
        content: Text(l10n.shiftOverAgeMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.globalClose),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.shiftClose),
          ),
        ],
      ),
    );
    if (goToShift == true && mounted) {
      context.go('/shift');
    }
  }

  Future<void> _handlePay() async {
    final state = ref.read(saleControllerProvider);
    if (state.isEmpty) return;

    final result = await context.push<bool>('/payment');

    if (result == true && mounted) {
      await ref.read(saleControllerProvider.notifier).startNewSale();
    }
  }

  Future<void> _handleWeigh() async {
    final state = ref.read(saleControllerProvider);
    if (state.selectedItem == null) return;

    if (!_hardware.isScalesConfigured) {
      _showQuantityDialog();
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.saleWeighingPlaceItem),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final weight = await _hardware.readWeightKg();
    if (!mounted) return;

    if (weight != null && weight > Decimal.zero) {
      ref.read(saleControllerProvider.notifier).updateQuantity(weight);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.saleWeightKg('$weight')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.saleWeightReadFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _showQuantityDialog();
    }
  }

  Future<void> _handlePrintLabel() async {
    final state = ref.read(saleControllerProvider);
    final item = state.selectedItem;
    if (item == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    final error = await _hardware.printPriceLabel(
      productName: item.name,
      barcode: item.barcode ?? '',
      price: item.price,
    );
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(error ?? l10n.salePriceLabelSent),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showQuantityDialog() {
    final state = ref.read(saleControllerProvider);
    if (state.selectedItem == null) return;

    final l10n = AppLocalizations.of(context)!;
    final item = state.selectedItem!;

    showDialog(
      context: context,
      builder: (ctx) => _QuantityCalculatorDialog(
        title: '${l10n.globalQuantity}: ${item.name}',
        initialValue: item.quantity.toString(),
        onConfirm: (value) {
          final quantity = Decimal.tryParse(value);
          if (quantity != null && quantity > Decimal.zero) {
            ref.read(saleControllerProvider.notifier).updateQuantity(quantity);
          }
        },
      ),
    );
  }

  Future<void> _showEditDialog() async {
    final state = ref.read(saleControllerProvider);
    if (state.selectedItem == null) return;

    final item = state.selectedItem!;
    final pos = await GetIt.I<AppDatabase>().thisPosDao.get();
    if (!mounted) return;

    void showBlocked() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Действие запрещено настройками POS (Настройки → Политика продаж)',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }

    showDialog<void>(
      context: context,
      builder: (_) => _EditItemDialog(
        itemName: item.name,
        price: item.price,
        discount: item.discount,
        onSave: (price, discount) async {
          if (price != null && price != item.price) {
            if (!(pos?.editPrice ?? false)) {
              showBlocked();
            } else {
              if (pos?.isKassaPriceDecreasingBlocked ?? false) {
                final validation =
                    await GetIt.I<KassaPriceDecreasingBlockedUseCase>()
                        .validatePriceChange(
                          ucode: item.productId,
                          newPrice: price,
                        );
                if (!validation.isAllowed) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          validation.reason ??
                              'Снижение цены запрещено настройками POS',
                        ),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                } else {
                  ref.read(saleControllerProvider.notifier).updatePrice(price);
                }
              } else {
                ref.read(saleControllerProvider.notifier).updatePrice(price);
              }
            }
          } else if (price != null) {
            ref.read(saleControllerProvider.notifier).updatePrice(price);
          }

          if (discount != null) {
            if (discount > Decimal.zero && !(pos?.sellInDiscount ?? false)) {
              showBlocked();
            } else {
              ref
                  .read(saleControllerProvider.notifier)
                  .setDiscountAmount(discount);
            }
          }
        },
      ),
    );
  }

  void _handleDefer() {
    final state = ref.read(saleControllerProvider);
    if (state.isEmpty) return;

    ref.read(saleControllerProvider.notifier).deferSale();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.saleHeld),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showMarkDialog() {
    final state = ref.read(saleControllerProvider);
    if (state.selectedItem == null) return;

    _showInputDialog(
      title: AppLocalizations.of(context)!.saleDataMatrix,
      initialValue: state.selectedItem!.mark ?? '',
      onSubmit: (value) {
        if (value.isNotEmpty) {
          ref.read(saleControllerProvider.notifier).setMark(value);
        }
      },
    );
  }

  void _showInputDialog({
    required String title,
    required String initialValue,
    required void Function(String) onSubmit,
  }) {
    final controller = TextEditingController(text: initialValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            ),
          ),
          onSubmitted: (value) {
            onSubmit(value);
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.globalCancel),
          ),
          ElevatedButton(
            onPressed: () {
              onSubmit(controller.text);
              Navigator.of(context).pop();
            },
            child: Text(AppLocalizations.of(context)!.globalOk),
          ),
        ],
      ),
    ).then((_) {
      controller.dispose();
    });
  }
}

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.showQuickProducts,
    required this.onToggleQuickProducts,
    required this.onPay,
    required this.onQuantity,
    required this.onEdit,
    required this.onDefer,
    required this.onMark,
    required this.onWeigh,
    required this.onPrintLabel,
    required this.showWeigh,
    required this.showPrintLabel,
  });

  final bool showQuickProducts;
  final VoidCallback onToggleQuickProducts;
  final VoidCallback onPay;
  final VoidCallback onQuantity;
  final VoidCallback onEdit;
  final VoidCallback onDefer;
  final VoidCallback onMark;
  final VoidCallback onWeigh;
  final VoidCallback onPrintLabel;
  final bool showWeigh;
  final bool showPrintLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              children: [
                const ProductSearch(autofocus: true),
                const SizedBox(height: AppTheme.spacing),

                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(
                        AppTheme.borderRadius,
                      ),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: const SaleItemsTable(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacing),

          Expanded(
            flex: 4,
            child: Column(
              children: [
                SaleActionButtons(
                  compact: showQuickProducts,
                  onQuickProducts: onToggleQuickProducts,
                  onDeferredList: () => _showDeferredDialog(context),
                  onQuantity: onQuantity,
                  onEdit: onEdit,
                  onDefer: onDefer,
                  onMark: onMark,
                  onWeigh: onWeigh,
                  onPrintLabel: onPrintLabel,
                  showWeigh: showWeigh,
                  showPrintLabel: showPrintLabel,
                ),
                const SizedBox(height: 6),

                if (showQuickProducts)
                  Expanded(
                    child: QuickProductsGrid(
                      crossAxisCount: 3,
                      onClose: onToggleQuickProducts,
                      compact: true,
                    ),
                  )
                else
                  const Spacer(),

                const SizedBox(height: 6),
                _PayButtonLarge(onPressed: onPay),
                const SizedBox(height: 6),
                const SaleTotalPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _showDeferredDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => const _DeferredSalesDialog(),
    );
  }
}

class _EditItemDialog extends StatefulWidget {
  const _EditItemDialog({
    required this.itemName,
    required this.price,
    required this.discount,
    required this.onSave,
  });

  final String itemName;
  final Decimal price;
  final Decimal discount;
  final void Function(Decimal? price, Decimal? discount) onSave;

  @override
  State<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<_EditItemDialog> {
  late final TextEditingController _priceController = TextEditingController(
    text: widget.price.toString(),
  );
  late final TextEditingController _discountController = TextEditingController(
    text: widget.discount.toString(),
  );

  @override
  void dispose() {
    _priceController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text('${l10n.globalEdit}: ${widget.itemName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _priceController,
            decoration: InputDecoration(
              labelText: l10n.globalPrice,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              ),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _discountController,
            decoration: InputDecoration(
              labelText: l10n.globalDiscount,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              ),
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
          onPressed: () {
            widget.onSave(
              Decimal.tryParse(_priceController.text),
              Decimal.tryParse(_discountController.text),
            );
            Navigator.of(context).pop();
          },
          child: Text(l10n.globalSave),
        ),
      ],
    );
  }
}

class _DeferredSalesDialog extends ConsumerWidget {
  const _DeferredSalesDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final deferredAsync = ref.watch(_deferredSalesProvider);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.history, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(l10n.actionDeferredList),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 300,
        child: deferredAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (sales) {
            if (sales.isEmpty) {
              return Center(
                child: Text(
                  l10n.saleNoDeferredSales,
                  style: AppTextStyles.body.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return ListView.builder(
              itemCount: sales.length,
              itemBuilder: (context, index) {
                final sale = sales[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.warning.withValues(alpha: 0.1),
                    child: Text(
                      '${sale.receiptNo}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text('${l10n.saleReceiptNo} ${sale.receiptNo}'),
                  subtitle: Text(sale.amount.toStringAsFixed(2)),
                  trailing: IconButton(
                    icon: const Icon(Icons.restore, color: AppColors.primary),
                    onPressed: () {
                      ref
                          .read(saleControllerProvider.notifier)
                          .loadDeferredSale(sale.receiptNo);
                      Navigator.of(context).pop();
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.globalCancel),
        ),
      ],
    );
  }
}

final _deferredSalesProvider = FutureProvider.autoDispose<List<Sale>>((
  ref,
) async {
  final db = GetIt.I<AppDatabase>();
  return db.saleDao.findByState(3);
});

class _TabletLayout extends StatelessWidget {
  const _TabletLayout({
    required this.showQuickProducts,
    required this.onToggleQuickProducts,
    required this.onPay,
    required this.onQuantity,
    required this.onEdit,
    required this.onDefer,
    required this.onMark,
    required this.onWeigh,
    required this.onPrintLabel,
    required this.showWeigh,
    required this.showPrintLabel,
  });

  final bool showQuickProducts;
  final VoidCallback onToggleQuickProducts;
  final VoidCallback onPay;
  final VoidCallback onQuantity;
  final VoidCallback onEdit;
  final VoidCallback onDefer;
  final VoidCallback onMark;
  final VoidCallback onWeigh;
  final VoidCallback onPrintLabel;
  final bool showWeigh;
  final bool showPrintLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 65,
            child: Column(
              children: [
                const ProductSearch(autofocus: true),
                const SizedBox(height: AppTheme.spacing),

                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(
                        AppTheme.borderRadius,
                      ),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: const SaleItemsTable(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacing),

          Expanded(
            flex: 35,
            child: Column(
              children: [
                SaleActionButtons(
                  compact: showQuickProducts,
                  onQuickProducts: onToggleQuickProducts,
                  onDeferredList: () =>
                      _DesktopLayout._showDeferredDialog(context),
                  onQuantity: onQuantity,
                  onEdit: onEdit,
                  onDefer: onDefer,
                  onMark: onMark,
                  onWeigh: onWeigh,
                  onPrintLabel: onPrintLabel,
                  showWeigh: showWeigh,
                  showPrintLabel: showPrintLabel,
                ),
                const SizedBox(height: 6),

                if (showQuickProducts)
                  Expanded(
                    child: QuickProductsGrid(
                      crossAxisCount: 2,
                      onClose: onToggleQuickProducts,
                      compact: true,
                    ),
                  )
                else
                  const Spacer(),

                const SizedBox(height: 6),
                _PayButtonLarge(onPressed: onPay),
                const SizedBox(height: 6),
                const SaleTotalPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PayButtonLarge extends ConsumerWidget {
  const _PayButtonLarge({this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasItems = ref.watch(
      saleControllerProvider.select((s) => s.isNotEmpty),
    );
    final isEnabled = hasItems && onPressed != null;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: isEnabled ? AppColors.success : context.semantic.canvas,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.payment,
                  size: 22,
                  color: isEnabled
                      ? AppColors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Text(
                  AppLocalizations.of(context)!.payBtn,
                  style: AppTextStyles.h3.copyWith(
                    color: isEnabled
                        ? AppColors.white
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.onPay,
    required this.onQuickProducts,
    required this.onQuantity,
    required this.onEdit,
    required this.onDefer,
    required this.onMark,
    required this.onWeigh,
    required this.onPrintLabel,
    required this.showWeigh,
    required this.showPrintLabel,
  });

  final VoidCallback onPay;
  final VoidCallback onQuickProducts;
  final VoidCallback onQuantity;
  final VoidCallback onEdit;
  final VoidCallback onDefer;
  final VoidCallback onMark;
  final VoidCallback onWeigh;
  final VoidCallback onPrintLabel;
  final bool showWeigh;
  final bool showPrintLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacing),
          child: const ProductSearch(),
        ),

        Expanded(
          child: Stack(
            children: [
              const SaleItemsList(),
              Positioned(
                right: AppTheme.spacing,
                bottom: AppTheme.spacing,
                child: SaleActionsFab(
                  onQuickProducts: onQuickProducts,
                  onQuantity: onQuantity,
                  onEdit: onEdit,
                  onDefer: onDefer,
                  onMark: onMark,
                  onWeigh: onWeigh,
                  onPrintLabel: onPrintLabel,
                  showWeigh: showWeigh,
                  showPrintLabel: showPrintLabel,
                ),
              ),
            ],
          ),
        ),

        SaleTotalPanel(compact: true, onPay: onPay),
      ],
    );
  }
}

class _QuantityCalculatorDialog extends StatefulWidget {
  const _QuantityCalculatorDialog({
    required this.title,
    required this.initialValue,
    required this.onConfirm,
  });

  final String title;
  final String initialValue;
  final void Function(String value) onConfirm;

  @override
  State<_QuantityCalculatorDialog> createState() =>
      _QuantityCalculatorDialogState();
}

class _QuantityCalculatorDialogState extends State<_QuantityCalculatorDialog> {
  String _display = '';

  @override
  void initState() {
    super.initState();
    _display = widget.initialValue;
  }

  void _onDigit(String digit) {
    setState(() {
      if (_display == '0') {
        _display = digit;
      } else {
        _display += digit;
      }
    });
  }

  void _onDot() {
    setState(() {
      if (!_display.contains('.')) {
        _display = _display.isEmpty ? '0.' : '$_display.';
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_display.isNotEmpty) {
        _display = _display.substring(0, _display.length - 1);
      }
      if (_display.isEmpty) _display = '0';
    });
  }

  void _onClear() {
    setState(() => _display = '0');
  }

  void _onConfirm() {
    widget.onConfirm(_display);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.semantic.canvas,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Text(
                _display.isEmpty ? '0' : _display,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(height: 16),

            _buildRow(['7', '8', '9', 'C']),
            const SizedBox(height: 6),
            _buildRow(['4', '5', '6', '⌫']),
            const SizedBox(height: 6),
            _buildRow(['1', '2', '3', '.']),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _CalcButton(label: '0', onTap: () => _onDigit('0')),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _CalcButton(
                    label: l10n.globalCancel,
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _CalcButton(
                    label: 'OK',
                    backgroundColor: AppColors.primary,
                    color: Colors.white,
                    onTap: _onConfirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      children: keys
          .map(
            (key) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: keys.indexOf(key) > 0 ? 6 : 0),
                child: _CalcButton(
                  label: key,
                  onTap: () {
                    switch (key) {
                      case 'C':
                        _onClear();
                      case '⌫':
                        _onBackspace();
                      case '.':
                        _onDot();
                      default:
                        _onDigit(key);
                    }
                  },
                  color: (key == 'C' || key == '⌫')
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CalcButton extends StatelessWidget {
  const _CalcButton({
    required this.label,
    required this.onTap,
    this.color,
    this.backgroundColor,
    this.fontSize,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;
  final Color? backgroundColor;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize ?? 20,
              fontWeight: FontWeight.w600,
              color: color ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
