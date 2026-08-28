import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/movement/movement_controller.dart';
import 'package:telepos/presentation/common/mixins/barcode_scanner_mixin.dart';

class MovementDialog extends ConsumerWidget {
  const MovementDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const MovementDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(movementControllerProvider);
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
            Expanded(child: _MovementDialogContent()),
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
          const Icon(Icons.swap_horiz, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.movementTitleFull,
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
    MovementState state,
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
              l10n.movementProductsCount(state.productCount),
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              l10n.movementSumLabel(
                state.totalAmount?.toStringAsFixed(2) ?? "0.00",
              ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
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
    final controller = ref.read(movementControllerProvider.notifier);
    final result = await controller.save();

    if (context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.movementSavedMessage(
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
            content: Text(result.errorMessage ?? l10n.movementSaveError),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

class _MovementDialogContent extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MovementDialogContent> createState() =>
      _MovementDialogContentState();
}

class _MovementDialogContentState extends ConsumerState<_MovementDialogContent>
    with BarcodeScannerMixin {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _commentController = TextEditingController();
  final _barcodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initBarcodeScanner();
  }

  @override
  void dispose() {
    disposeBarcodeScanner();
    _fromController.dispose();
    _toController.dispose();
    _commentController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  @override
  void onBarcodeScanned(String barcode) {
    ref.read(movementControllerProvider.notifier).addByBarcode(barcode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(movementControllerProvider);
    final controller = ref.read(movementControllerProvider.notifier);

    if (_fromController.text != state.fromLocation) {
      _fromController.text = state.fromLocation;
    }
    if (_toController.text != state.toLocation) {
      _toController.text = state.toLocation;
    }
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
                _buildField(
                  l10n.movementFrom,
                  _fromController,
                  l10n.movementLocationHint,
                  Icons.logout,
                  controller.setFromLocation,
                ),
                const SizedBox(height: 16),
                _buildField(
                  l10n.movementTo,
                  _toController,
                  l10n.movementLocationHint,
                  Icons.login,
                  controller.setToLocation,
                ),
                const SizedBox(height: 16),
                _buildBarcodeInput(controller),
                const SizedBox(height: 16),
                Text(
                  l10n.movementComment,
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
                    hintText: l10n.movementCommentHintShort,
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

  Widget _buildField(
    String label,
    TextEditingController ctrl,
    String hint,
    IconData icon,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildBarcodeInput(MovementNotifier controller) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.movementAddProduct,
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
                  hintText: l10n.movementBarcodeHint,
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

  Widget _buildProductList(MovementState state, MovementNotifier controller) {
    final l10n = AppLocalizations.of(context)!;
    if (state.products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_horiz_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.movementEmptyTitle,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.movementEmptyHint,
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
                l10n.movementProductFallback(product.ucode.toString()),
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
    MovementNotifier controller,
    MovementProductInfo product,
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
                l10n.movementProductFallback(product.ucode.toString()),
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
                decoration: InputDecoration(labelText: l10n.movementPriceLabel),
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
}
