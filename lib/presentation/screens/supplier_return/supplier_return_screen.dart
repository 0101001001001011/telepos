import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/mixins/barcode_scanner_mixin.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/supplier_return/supplier_return_controller.dart';
import 'package:telepos/presentation/screens/supplier_return/dialogs/supplier_return_dialog.dart';

class SupplierReturnScreen extends StatelessWidget {
  const SupplierReturnScreen({super.key});

  static Future<bool?> show(BuildContext context) async {
    final width = MediaQuery.of(context).size.width;
    final layoutType = Breakpoints.fromWidth(width);

    if (layoutType == LayoutType.mobile) {
      return Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const SupplierReturnScreen()),
      );
    } else {
      return SupplierReturnDialog.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const _SupplierReturnMobileScreen();
  }
}

class _SupplierReturnMobileScreen extends ConsumerStatefulWidget {
  const _SupplierReturnMobileScreen();

  @override
  ConsumerState<_SupplierReturnMobileScreen> createState() =>
      _SupplierReturnMobileScreenState();
}

class _SupplierReturnMobileScreenState
    extends ConsumerState<_SupplierReturnMobileScreen>
    with BarcodeScannerMixin {
  final _barcodeController = TextEditingController();
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initBarcodeScanner();
  }

  @override
  void dispose() {
    disposeBarcodeScanner();
    _barcodeController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  void onBarcodeScanned(String barcode) {
    ref.read(supplierReturnControllerProvider.notifier).addByBarcode(barcode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(supplierReturnControllerProvider);
    final controller = ref.read(supplierReturnControllerProvider.notifier);

    if (_commentController.text != state.comment) {
      _commentController.text = state.comment;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.supplierReturnTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _onCancel(context, controller, state),
        ),
        actions: [
          if (state.isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            TextButton(
              onPressed: state.canSave
                  ? () => _onSave(context, controller)
                  : null,
              child: Text(
                l10n.globalSave,
                style: TextStyle(
                  color: state.canSave ? Colors.white : Colors.white54,
                ),
              ),
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (state.error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.1),
                    child: Row(
                      children: [
                        Icon(
                          TeleposIcons.error,
                          color: Theme.of(context).colorScheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ErrorLocalizer.localize(context, state.error!),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(TeleposIcons.close, size: 18),
                          onPressed: () => controller.clearError(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSupplierSelector(state, controller),
                        const SizedBox(height: 16),

                        _buildAccountSelector(state, controller),
                        const SizedBox(height: 16),

                        _buildBarcodeInput(controller, l10n),
                        const SizedBox(height: 16),

                        if (state.products.isNotEmpty) ...[
                          _buildProductsList(state, controller, l10n),
                          const SizedBox(height: 16),
                        ],

                        _buildCommentField(controller, l10n),
                      ],
                    ),
                  ),
                ),

                if (state.products.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.supplierReturnProductsCount(
                                state.productCount,
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.supplierReturnSumLabel(
                                state.totalAmount?.toStringAsFixed(2) ?? "0.00",
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: state.canSave
                              ? () => _onSave(context, controller)
                              : null,
                          icon: const Icon(TeleposIcons.check),
                          label: Text(l10n.globalSave),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildSupplierSelector(
    SupplierReturnState state,
    SupplierReturnNotifier controller,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.supplierReturnSupplier,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showSupplierDialog(controller),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.supplierName ?? l10n.supplierReturnSelectSupplier,
                    style: TextStyle(
                      fontSize: 15,
                      color: state.supplierId == null
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSelector(
    SupplierReturnState state,
    SupplierReturnNotifier controller,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.supplierReturnAccount,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showAccountDialog(controller),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.accountName ?? l10n.supplierReturnSelectAccount,
                    style: TextStyle(
                      fontSize: 15,
                      color: state.accountId == null
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarcodeInput(
    SupplierReturnNotifier controller,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.supplierReturnAddProduct,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _barcodeController,
                decoration: InputDecoration(
                  hintText: l10n.supplierReturnBarcodeHint,
                  prefixIcon: const Icon(Icons.qr_code),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (value) => _onBarcodeEntered(controller, value),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () =>
                  _onBarcodeEntered(controller, _barcodeController.text),
              icon: const Icon(TeleposIcons.add),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductsList(
    SupplierReturnState state,
    SupplierReturnNotifier controller,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.supplierReturnProductsCount(state.productCount),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              l10n.supplierReturnSumLabel(
                state.totalAmount?.toStringAsFixed(2) ?? "0.00",
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.products.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final product = state.products[index];
              return _ReturnProductListItem(
                product: product,
                onEdit: () => _showEditProductDialog(controller, product),
                onDelete: () => controller.removeProduct(product.ucode),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCommentField(
    SupplierReturnNotifier controller,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.supplierReturnComment,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _commentController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: l10n.supplierReturnCommentHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          onChanged: controller.setComment,
        ),
      ],
    );
  }

  Future<void> _showSupplierDialog(SupplierReturnNotifier controller) async {
    final suppliers = await controller.getSuppliers();

    if (!mounted) return;

    final selected = await showDialog<SupplierItem>(
      context: context,
      builder: (context) => _SupplierSelectDialog(suppliers: suppliers),
    );

    if (selected != null) {
      controller.selectSupplier(selected.id);
    }
  }

  Future<void> _showAccountDialog(SupplierReturnNotifier controller) async {
    final accounts = await controller.getAccounts();

    if (!mounted) return;

    final selected = await showDialog<AccountItem>(
      context: context,
      builder: (context) => _AccountSelectDialog(accounts: accounts),
    );

    if (selected != null) {
      controller.selectAccount(selected.id);
    }
  }

  Future<void> _onBarcodeEntered(
    SupplierReturnNotifier controller,
    String barcode,
  ) async {
    if (barcode.isEmpty) return;

    final success = await controller.addByBarcode(barcode);
    if (success) {
      _barcodeController.clear();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.supplierReturnProductNotFound,
          ),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  Future<void> _showEditProductDialog(
    SupplierReturnNotifier controller,
    ReturnProductInfo product,
  ) async {
    final result = await showDialog<_EditResult>(
      context: context,
      builder: (context) => _EditReturnProductDialog(product: product),
    );

    if (result != null) {
      controller.updateProduct(
        ucode: product.ucode,
        quantity: result.quantity,
        price: result.price,
      );
    }
  }

  Future<void> _onSave(
    BuildContext context,
    SupplierReturnNotifier controller,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await controller.save();

    if (context.mounted) {
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.supplierReturnSavedMessage(
                result.productCount ?? 0,
                result.totalAmount?.toStringAsFixed(2) ?? "0.00",
              ),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        controller.cancel();
        if (context.mounted) context.go(AppRoutes.stockRegistry);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? l10n.globalError),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _onCancel(
    BuildContext context,
    SupplierReturnNotifier controller,
    SupplierReturnState state,
  ) {
    if (state.products.isEmpty) {
      controller.cancel();
      context.go(AppRoutes.stockRegistry);
      return;
    }

    showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dl10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(dl10n.supplierReturnCancelTitle),
          content: Text(dl10n.supplierReturnCancelMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(dl10n.globalNo),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(dl10n.supplierReturnCancelConfirm),
            ),
          ],
        );
      },
    ).then((confirmed) {
      if (confirmed == true && context.mounted) {
        controller.cancel();
        context.go(AppRoutes.stockRegistry);
      }
    });
  }
}

class _ReturnProductListItem extends StatelessWidget {
  const _ReturnProductListItem({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  final ReturnProductInfo product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.productName ??
                      AppLocalizations.of(
                        context,
                      )!.supplierReturnProductFallback(
                        product.ucode.toString(),
                      ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${product.quantity} \u00d7 ${product.price.toStringAsFixed(2)} = ${product.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: selectedSurfaceOf(context),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onEdit,
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.edit, size: 24, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onDelete,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.delete,
                  size: 24,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierSelectDialog extends StatelessWidget {
  const _SupplierSelectDialog({required this.suppliers});

  final List<SupplierItem> suppliers;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.supplierReturnSelectSupplier),
      content: SizedBox(
        width: 300,
        height: 400,
        child: suppliers.isEmpty
            ? Center(child: Text(l10n.supplierReturnNoSuppliers))
            : ListView.builder(
                itemCount: suppliers.length,
                itemBuilder: (context, index) {
                  final supplier = suppliers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.local_shipping,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(supplier.name),
                    subtitle: supplier.phone != null
                        ? Text(supplier.phone!)
                        : null,
                    onTap: () => Navigator.of(context).pop(supplier),
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

class _AccountSelectDialog extends StatelessWidget {
  const _AccountSelectDialog({required this.accounts});

  final List<AccountItem> accounts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.supplierReturnSelectAccount),
      content: SizedBox(
        width: 300,
        height: 300,
        child: accounts.isEmpty
            ? Center(child: Text(l10n.supplierReturnNoAccounts))
            : ListView.builder(
                itemCount: accounts.length,
                itemBuilder: (context, index) {
                  final account = accounts[index];
                  return ListTile(
                    title: Text(account.name),
                    subtitle: Text(
                      l10n.supplierReturnBalance(
                        account.balance.toStringAsFixed(2),
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(account),
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

class _EditResult {
  const _EditResult({required this.quantity, required this.price});
  final Decimal quantity;
  final Decimal price;
}

enum _ActiveField { quantity, price }

class _EditReturnProductDialog extends StatefulWidget {
  const _EditReturnProductDialog({required this.product});

  final ReturnProductInfo product;

  @override
  State<_EditReturnProductDialog> createState() =>
      _EditReturnProductDialogState();
}

class _EditReturnProductDialogState extends State<_EditReturnProductDialog> {
  String _quantity = '';
  String _price = '';
  _ActiveField _activeField = _ActiveField.quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.product.quantity.toString();
    _price = widget.product.price.toStringAsFixed(2);
  }

  String get _activeValue =>
      _activeField == _ActiveField.quantity ? _quantity : _price;

  set _activeValue(String v) {
    if (_activeField == _ActiveField.quantity) {
      _quantity = v;
    } else {
      _price = v;
    }
  }

  void _onDigit(String d) => setState(() {
    _activeValue = _activeValue == '0' ? d : _activeValue + d;
  });

  void _onDot() => setState(() {
    if (!_activeValue.contains('.')) {
      _activeValue = _activeValue.isEmpty ? '0.' : '$_activeValue.';
    }
  });

  void _onBackspace() => setState(() {
    if (_activeValue.isNotEmpty) {
      _activeValue = _activeValue.substring(0, _activeValue.length - 1);
    }
    if (_activeValue.isEmpty) _activeValue = '0';
  });

  void _onClear() => setState(() => _activeValue = '0');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.product.productName ??
                  l10n.supplierReturnProductFallback(
                    widget.product.ucode.toString(),
                  ),
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _FieldDisplay(
                    label: l10n.globalQuantity,
                    value: _quantity,
                    isActive: _activeField == _ActiveField.quantity,
                    onTap: () =>
                        setState(() => _activeField = _ActiveField.quantity),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FieldDisplay(
                    label: l10n.supplierReturnPriceLabel,
                    value: _price,
                    isActive: _activeField == _ActiveField.price,
                    onTap: () =>
                        setState(() => _activeField = _ActiveField.price),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _CalcKeypad(
              onDigit: _onDigit,
              onDot: _onDot,
              onBackspace: _onBackspace,
              onClear: _onClear,
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: () {
                final quantity = Decimal.tryParse(_quantity);
                final price = Decimal.tryParse(_price);
                if (quantity == null || quantity <= Decimal.zero) return;
                if (price == null || price < Decimal.zero) return;
                Navigator.of(
                  context,
                ).pop(_EditResult(quantity: quantity, price: price));
              },
              confirmLabel: l10n.globalSave,
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldDisplay extends StatelessWidget {
  const _FieldDisplay({
    required this.label,
    required this.value,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? selectedSurfaceOf(context)
              : context.semantic.canvas,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? AppColors.primary
                : Theme.of(context).colorScheme.outline,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isActive
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value.isEmpty ? '0' : value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isActive
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
    );
  }
}

class _CalcKeypad extends StatelessWidget {
  const _CalcKeypad({
    required this.onDigit,
    required this.onDot,
    required this.onBackspace,
    required this.onClear,
    required this.onCancel,
    required this.onConfirm,
    required this.confirmLabel,
  });

  final void Function(String) onDigit;
  final VoidCallback onDot;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row(context, ['7', '8', '9', 'C']),
        const SizedBox(height: 6),
        _row(context, ['4', '5', '6', '\u232b']),
        const SizedBox(height: 6),
        _row(context, ['1', '2', '3', '.']),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(flex: 2, child: _btn(context, '0', () => onDigit('0'))),
            const SizedBox(width: 6),
            Expanded(
              child: _btn(
                context,
                AppLocalizations.of(context)!.globalCancel,
                onCancel,
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _btn(
                context,
                confirmLabel,
                onConfirm,
                fontSize: 13,
                bg: AppColors.primary,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // [context] прокинут: метод передаёт его дальше в `_btn`.
  Widget _row(BuildContext context, List<String> keys) {
    return Row(
      children: keys.asMap().entries.map((e) {
        final key = e.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: e.key > 0 ? 6 : 0),
            child: _btn(
              context,
              key,
              () {
                switch (key) {
                  case 'C':
                    onClear();
                  case '\u232b':
                    onBackspace();
                  case '.':
                    onDot();
                  default:
                    onDigit(key);
                }
              },
              color: (key == 'C' || key == '\u232b')
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }

  // [context] прокинут явно: подложка клавиши берётся ролью темы, а роль
  // без контекста не достать. Пока цвет был константой, метод обходился.
  Widget _btn(
    BuildContext context,
    String label,
    VoidCallback onTap, {
    Color? color,
    Color? bg,
    double? fontSize,
  }) {
    return Material(
      color: bg ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 52,
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
