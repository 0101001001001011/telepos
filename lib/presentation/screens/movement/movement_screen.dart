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
import 'package:telepos/presentation/controllers/movement/movement_controller.dart';
import 'package:telepos/presentation/screens/movement/dialogs/movement_dialog.dart';

class MovementScreen extends StatelessWidget {
  const MovementScreen({super.key});

  static Future<bool?> show(BuildContext context) async {
    final width = MediaQuery.of(context).size.width;
    final layoutType = Breakpoints.fromWidth(width);

    if (layoutType == LayoutType.mobile) {
      return Navigator.of(
        context,
      ).push<bool>(MaterialPageRoute(builder: (_) => const MovementScreen()));
    } else {
      return MovementDialog.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const _MovementMobileScreen();
  }
}

class _MovementMobileScreen extends ConsumerStatefulWidget {
  const _MovementMobileScreen();

  @override
  ConsumerState<_MovementMobileScreen> createState() =>
      _MovementMobileScreenState();
}

class _MovementMobileScreenState extends ConsumerState<_MovementMobileScreen>
    with BarcodeScannerMixin {
  final _barcodeController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
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
    _fromController.dispose();
    _toController.dispose();
    _commentController.dispose();
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.movementTitle),
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
                        _buildLocationField(
                          label: l10n.movementFrom,
                          controller: _fromController,
                          hint: l10n.movementLocationHint,
                          icon: Icons.logout,
                          onChanged: controller.setFromLocation,
                        ),
                        const SizedBox(height: 16),

                        _buildLocationField(
                          label: l10n.movementTo,
                          controller: _toController,
                          hint: l10n.movementLocationHint,
                          icon: Icons.login,
                          onChanged: controller.setToLocation,
                        ),
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
                              l10n.movementProductsCount(state.productCount),
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.movementSumLabel(
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

  Widget _buildLocationField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required ValueChanged<String> onChanged,
  }) {
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
          controller: controller,
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

  Widget _buildBarcodeInput(
    MovementNotifier controller,
    AppLocalizations l10n,
  ) {
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
    MovementState state,
    MovementNotifier controller,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.movementProductsCount(state.productCount),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              l10n.movementSumLabel(
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
              return _ProductListItem(
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
    MovementNotifier controller,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            hintText: l10n.movementCommentHint,
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

  Future<void> _onBarcodeEntered(
    MovementNotifier controller,
    String barcode,
  ) async {
    if (barcode.isEmpty) return;

    final success = await controller.addByBarcode(barcode);
    if (success) {
      _barcodeController.clear();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.movementProductNotFound),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  Future<void> _showEditProductDialog(
    MovementNotifier controller,
    MovementProductInfo product,
  ) async {
    final result = await showDialog<_EditResult>(
      context: context,
      builder: (context) => _EditProductDialog(product: product),
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
    MovementNotifier controller,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await controller.save();

    if (context.mounted) {
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
    MovementNotifier controller,
    MovementState state,
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
          title: Text(dl10n.movementCancelTitle),
          content: Text(dl10n.movementCancelMessage),
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
              child: Text(dl10n.movementCancelConfirm),
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

class _ProductListItem extends StatelessWidget {
  const _ProductListItem({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  final MovementProductInfo product;
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
                      )!.movementProductFallback(product.ucode.toString()),
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

class _EditResult {
  const _EditResult({required this.quantity, required this.price});
  final Decimal quantity;
  final Decimal price;
}

enum _ActiveField { quantity, price }

class _EditProductDialog extends StatefulWidget {
  const _EditProductDialog({required this.product});

  final MovementProductInfo product;

  @override
  State<_EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<_EditProductDialog> {
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
                  l10n.movementProductFallback(widget.product.ucode.toString()),
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
                    label: l10n.movementPriceLabel,
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
