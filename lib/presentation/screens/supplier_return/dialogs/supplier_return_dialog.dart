import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/mixins/barcode_scanner_mixin.dart';
import 'package:telepos/presentation/controllers/supplier_return/supplier_return_controller.dart';

class SupplierReturnDialog extends ConsumerWidget {
  const SupplierReturnDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SupplierReturnDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supplierReturnControllerProvider);
    final screenSize = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: math.min(1024.0, screenSize.width - 48),
        constraints: BoxConstraints(maxHeight: screenSize.height - 80),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(context),
            Divider(height: 1, color: Theme.of(context).colorScheme.outline),
            Expanded(child: _SupplierReturnDialogContent()),
            Divider(height: 1, color: Theme.of(context).colorScheme.outline),
            _buildFooter(context, ref, state),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: selectedSurfaceOf(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment_return, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.supplierReturnTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(TeleposIcons.close),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            onPressed: () => Navigator.of(context).pop(false),
            tooltip: AppLocalizations.of(context)!.globalClose,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    WidgetRef ref,
    SupplierReturnState state,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: Row(
        children: [
          if (state.products.isNotEmpty) ...[
            Text(
              l10n.supplierReturnProductsCount(state.productCount),
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              l10n.supplierReturnSumLabel(
                state.totalAmount?.toStringAsFixed(2) ?? "0.00",
              ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
          ],
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(l10n.globalCancel),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: state.canSave && !state.isSaving
                ? () => _onSave(context, ref)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: state.isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : Text(l10n.globalSave),
          ),
        ],
      ),
    );
  }

  Future<void> _onSave(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(supplierReturnControllerProvider.notifier);
    final result = await controller.save();

    if (context.mounted) {
      final l10n = AppLocalizations.of(context)!;
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
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? l10n.supplierReturnSaveError),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

class _SupplierReturnDialogContent extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SupplierReturnDialogContent> createState() =>
      _SupplierReturnDialogContentState();
}

class _SupplierReturnDialogContentState
    extends ConsumerState<_SupplierReturnDialogContent>
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 400,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSupplierField(state, controller),
                const SizedBox(height: 16),
                _buildAccountField(state, controller),
                const SizedBox(height: 16),
                _buildBarcodeInput(controller),
                const SizedBox(height: 16),
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
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  onChanged: controller.setComment,
                ),
              ],
            ),
          ),
        ),
        VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outline),
        Expanded(child: _buildProductList(state, controller)),
      ],
    );
  }

  Widget _buildSupplierField(
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

  Widget _buildAccountField(
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

  Widget _buildBarcodeInput(SupplierReturnNotifier controller) {
    final l10n = AppLocalizations.of(context)!;
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
                onSubmitted: (value) async {
                  final success = await controller.addByBarcode(value);
                  if (success) _barcodeController.clear();
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () async {
                final success = await controller.addByBarcode(
                  _barcodeController.text,
                );
                if (success) _barcodeController.clear();
              },
              icon: const Icon(TeleposIcons.add),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductList(
    SupplierReturnState state,
    SupplierReturnNotifier controller,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (state.products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_return_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.supplierReturnEmptyTitle,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.supplierReturnEmptyHint,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: state.products.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final product = state.products[index];
        return ListTile(
          dense: true,
          title: Text(
            product.productName ??
                l10n.supplierReturnProductFallback(product.ucode.toString()),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${product.quantity} \u00d7 ${product.price.toStringAsFixed(2)} = ${product.amount.toStringAsFixed(2)}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.primary),
                  onPressed: () => _showEditProductDialog(controller, product),
                ),
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  icon: Icon(
                    Icons.delete,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => controller.removeProduct(product.ucode),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditProductDialog(
    SupplierReturnNotifier controller,
    ReturnProductInfo product,
  ) async {
    final qtyCtrl = TextEditingController(text: product.quantity.toString());
    final priceCtrl = TextEditingController(
      text: product.price.toStringAsFixed(2),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(
            product.productName ??
                l10n.supplierReturnProductFallback(product.ucode.toString()),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: l10n.globalQuantity),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.supplierReturnPriceLabel,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.globalCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.globalSave),
            ),
          ],
        );
      },
    );

    final qtyText = qtyCtrl.text.trim();
    final priceText = priceCtrl.text.trim();
    qtyCtrl.dispose();
    priceCtrl.dispose();

    if (saved != true) return;

    final quantity = Decimal.tryParse(qtyText);
    final price = Decimal.tryParse(priceText);
    if (quantity == null || quantity <= Decimal.zero) return;
    if (price == null || price < Decimal.zero) return;

    controller.updateProduct(
      ucode: product.ucode,
      quantity: quantity,
      price: price,
    );
  }

  Future<void> _showSupplierDialog(SupplierReturnNotifier controller) async {
    final suppliers = await controller.getSuppliers();
    if (!mounted) return;

    final selected = await showDialog<SupplierItem>(
      context: context,
      builder: (context) {
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
                      final s = suppliers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.1,
                          ),
                          child: const Icon(
                            Icons.local_shipping,
                            size: 20,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text(s.name),
                        subtitle: s.phone != null ? Text(s.phone!) : null,
                        onTap: () => Navigator.of(context).pop(s),
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
      },
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
      builder: (context) {
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
                      final a = accounts[index];
                      return ListTile(
                        title: Text(a.name),
                        subtitle: Text(
                          l10n.supplierReturnBalance(
                            a.balance.toStringAsFixed(2),
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(a),
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
      },
    );

    if (selected != null) {
      controller.selectAccount(selected.id);
    }
  }
}
