import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/supply/supply_controller.dart';
import 'package:telepos/presentation/screens/supply/widgets/supply_form.dart';

class SupplyDialog extends ConsumerWidget {
  const SupplyDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SupplyDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supplyControllerProvider);
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
            Expanded(child: _buildContent(context)),
            Divider(height: 1, color: Theme.of(context).colorScheme.outline),
            _buildFooter(context, ref, state),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: selectedSurfaceOf(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.supplyTitle,
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
            tooltip: l10n.globalClose,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 400,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: SupplyForm(),
          ),
        ),
        VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outline),
        Expanded(child: SupplyProductListPlaceholder()),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, WidgetRef ref, SupplyState state) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
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
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(supplyControllerProvider.notifier);
    final result = await controller.save();

    if (context.mounted) {
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.supplySavedSuccess(
                result.productCount ?? 0,
                result.totalAmount?.toStringAsFixed(2) ?? '0.00',
              ),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? l10n.supplySaveError),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

class SupplyProductListPlaceholder extends ConsumerStatefulWidget {
  const SupplyProductListPlaceholder({super.key});

  @override
  ConsumerState<SupplyProductListPlaceholder> createState() =>
      _SupplyProductListPlaceholderState();
}

class _SupplyProductListPlaceholderState
    extends ConsumerState<SupplyProductListPlaceholder> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(supplyControllerProvider);
    final controller = ref.read(supplyControllerProvider.notifier);

    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? state.products
        : state.products.where((p) {
            final name = (p.productName ?? '').toLowerCase();
            final barcode = (p.barcode ?? '').toLowerCase();
            final ucode = p.ucode.toString();
            return name.contains(query) ||
                barcode.contains(query) ||
                ucode.contains(query);
          }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: l10n.supplySearchProduct,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(TeleposIcons.close),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shopping_basket_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.supplyAddProductsHint,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.supplyScanOrSearch,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        product.productName ?? '#${product.ucode}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${product.quantity} × ${product.price.toStringAsFixed(2)}'
                        ' = ${product.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          TeleposIcons.delete,
                          color: Theme.of(context).colorScheme.error,
                          size: 20,
                        ),
                        onPressed: () =>
                            controller.removeProduct(product.ucode),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selectedSurfaceOf(context),
            border: Border(
              top: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.supplyProductCountLabel(state.productCount),
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                l10n.supplyTotalLabel(
                  state.totalAmount?.toStringAsFixed(2) ?? '0.00',
                ),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
