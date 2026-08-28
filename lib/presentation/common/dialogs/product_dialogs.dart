import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/domain/services/currency_service.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/widgets/keyboards/num_pad.dart';

class QuickProduct {
  const QuickProduct({
    required this.id,
    required this.name,
    this.price,
    this.color,
    this.icon,
    this.children,
  });

  final int id;
  final String name;
  final Decimal? price;
  final Color? color;
  final IconData? icon;
  final List<QuickProduct>? children;

  bool get hasChildren => children != null && children!.isNotEmpty;
}

class QuickProductDialog extends StatefulWidget {
  const QuickProductDialog({
    super.key,
    required this.products,
    this.columns = 4,
  });

  final List<QuickProduct> products;
  final int columns;

  static Future<QuickProduct?> show({
    required BuildContext context,
    required List<QuickProduct> products,
    int columns = 4,
  }) {
    return showDialog<QuickProduct>(
      context: context,
      builder: (context) =>
          QuickProductDialog(products: products, columns: columns),
    );
  }

  @override
  State<QuickProductDialog> createState() => _QuickProductDialogState();
}

class _QuickProductDialogState extends State<QuickProductDialog> {
  final List<QuickProduct> _breadcrumbs = [];

  List<QuickProduct> get _currentProducts {
    if (_breadcrumbs.isEmpty) return widget.products;
    return _breadcrumbs.last.children ?? [];
  }

  void _navigateTo(QuickProduct product) {
    if (product.hasChildren) {
      setState(() => _breadcrumbs.add(product));
    } else {
      Navigator.of(context).pop(product);
    }
  }

  void _navigateBack() {
    if (_breadcrumbs.isNotEmpty) {
      setState(() => _breadcrumbs.removeLast());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.semantic.canvas),
                ),
              ),
              child: Row(
                children: [
                  if (_breadcrumbs.isNotEmpty)
                    IconButton(
                      onPressed: _navigateBack,
                      icon: const Icon(Icons.arrow_back),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () =>
                                setState(() => _breadcrumbs.clear()),
                            child: Text(
                              AppLocalizations.of(context)!.allBreadcrumb,
                              style: AppTextStyles.body.copyWith(
                                color: _breadcrumbs.isEmpty
                                    ? AppColors.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          for (int i = 0; i < _breadcrumbs.length; i++) ...[
                            const Icon(Icons.chevron_right, size: 20),
                            TextButton(
                              onPressed: () => setState(() {
                                _breadcrumbs.removeRange(
                                  i + 1,
                                  _breadcrumbs.length,
                                );
                              }),
                              child: Text(
                                _breadcrumbs[i].name,
                                style: AppTextStyles.body.copyWith(
                                  color: i == _breadcrumbs.length - 1
                                      ? AppColors.primary
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(TeleposIcons.close),
                  ),
                ],
              ),
            ),

            Flexible(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                shrinkWrap: true,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: widget.columns,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.2,
                ),
                itemCount: _currentProducts.length,
                itemBuilder: (context, index) {
                  final product = _currentProducts[index];
                  return _QuickProductTile(
                    product: product,
                    onTap: () => _navigateTo(product),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickProductTile extends StatelessWidget {
  const _QuickProductTile({required this.product, required this.onTap});

  final QuickProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: product.color ?? context.semantic.canvas,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (product.icon != null)
                Icon(product.icon, size: 24, color: AppColors.white),
              if (product.hasChildren)
                const Icon(Icons.folder, size: 24, color: AppColors.white),
              const SizedBox(height: 4),
              Text(
                product.name,
                style: context.styles.caption.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (product.price != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${product.price!.toStringAsFixed(0)} ${GetIt.I<CurrencyService>().symbol}',
                  style: context.styles.caption.copyWith(
                    color: AppColors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EditProductResult {
  const EditProductResult({
    required this.quantity,
    this.price,
    this.discount,
    this.comment,
  });

  final Decimal quantity;
  final Decimal? price;
  final Decimal? discount;
  final String? comment;
}

class EditProductDialog extends StatefulWidget {
  const EditProductDialog({
    super.key,
    required this.productName,
    required this.quantity,
    required this.price,
    this.discount,
    this.comment,
    this.canEditPrice = false,
  });

  final String productName;
  final Decimal quantity;
  final Decimal price;
  final Decimal? discount;
  final String? comment;
  final bool canEditPrice;

  static Future<EditProductResult?> show({
    required BuildContext context,
    required String productName,
    required Decimal quantity,
    required Decimal price,
    Decimal? discount,
    String? comment,
    bool canEditPrice = false,
  }) {
    return showDialog<EditProductResult>(
      context: context,
      builder: (context) => EditProductDialog(
        productName: productName,
        quantity: quantity,
        price: price,
        discount: discount,
        comment: comment,
        canEditPrice: canEditPrice,
      ),
    );
  }

  @override
  State<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<EditProductDialog> {
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  late TextEditingController _discountController;
  late TextEditingController _commentController;

  late TextEditingController _activeNumeric;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.quantity.toString(),
    );
    _priceController = TextEditingController(
      text: widget.price.toStringAsFixed(2),
    );
    _discountController = TextEditingController(
      text: widget.discount?.toStringAsFixed(2) ?? '',
    );
    _commentController = TextEditingController(text: widget.comment ?? '');
    _activeNumeric = _quantityController;
  }

  void _onKey(String d) {
    setState(() => _activeNumeric.text = _activeNumeric.text + d);
  }

  void _onDot() {
    if (_activeNumeric.text.contains('.')) return;
    final base = _activeNumeric.text.isEmpty ? '0' : _activeNumeric.text;
    setState(() => _activeNumeric.text = '$base.');
  }

  void _onBackspace() {
    final t = _activeNumeric.text;
    if (t.isEmpty) return;
    setState(() => _activeNumeric.text = t.substring(0, t.length - 1));
  }

  void _onClear() {
    setState(() => _activeNumeric.clear());
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final quantity = Decimal.parse(
        _quantityController.text.replaceAll(',', '.'),
      );
      Decimal? price;
      Decimal? discount;

      if (widget.canEditPrice && _priceController.text.isNotEmpty) {
        price = Decimal.parse(_priceController.text.replaceAll(',', '.'));
      }

      if (_discountController.text.isNotEmpty) {
        discount = Decimal.parse(_discountController.text.replaceAll(',', '.'));
      }

      Navigator.of(context).pop(
        EditProductResult(
          quantity: quantity,
          price: price,
          discount: discount,
          comment: _commentController.text.isEmpty
              ? null
              : _commentController.text,
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppLocalizations.of(context)!.editProduct,
                  style: AppTextStyles.h3,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.productName,
                  style: AppTextStyles.body.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: _quantityController,
                  readOnly: true,
                  showCursor: true,
                  onTap: () =>
                      setState(() => _activeNumeric = _quantityController),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.globalQuantity,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _priceController,
                  enabled: widget.canEditPrice,
                  readOnly: true,
                  showCursor: true,
                  onTap: widget.canEditPrice
                      ? () => setState(() => _activeNumeric = _priceController)
                      : null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.tableHeaderPrice,
                    suffixText: GetIt.I<CurrencyService>().symbol,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _discountController,
                  readOnly: true,
                  showCursor: true,
                  onTap: () =>
                      setState(() => _activeNumeric = _discountController),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.discountTitle,
                    suffixText: GetIt.I<CurrencyService>().symbol,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Center(
                  child: NumPad(
                    buttonSize: 48,
                    spacing: 8,
                    showEnter: false,
                    onKeyPressed: _onKey,
                    onBackspace: _onBackspace,
                    onClear: _onClear,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 168,
                    child: OutlinedButton(
                      onPressed: _onDot,
                      child: const Text('.', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _commentController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.labelComment,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(AppLocalizations.of(context)!.globalCancel),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: Text(AppLocalizations.of(context)!.globalSave),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PackageOption {
  const PackageOption({
    required this.id,
    required this.name,
    required this.quantity,
    this.barcode,
  });

  final int id;
  final String name;
  final Decimal quantity;
  final String? barcode;
}

class PackageDialog extends StatelessWidget {
  const PackageDialog({
    super.key,
    required this.productName,
    required this.packages,
  });

  final String productName;
  final List<PackageOption> packages;

  static Future<PackageOption?> show({
    required BuildContext context,
    required String productName,
    required List<PackageOption> packages,
  }) {
    return showDialog<PackageOption>(
      context: context,
      builder: (context) =>
          PackageDialog(productName: productName, packages: packages),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 350),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.of(context)!.selectPackage,
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: 8),
              Text(
                productName,
                style: AppTextStyles.body.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              ...packages.map(
                (pkg) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PackageTile(
                    package: pkg,
                    onTap: () => Navigator.of(context).pop(pkg),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppLocalizations.of(context)!.globalCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({required this.package, required this.onTap});

  final PackageOption package;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.semantic.canvas,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(package.name, style: AppTextStyles.body),
                    Text(
                      AppLocalizations.of(
                        context,
                      )!.packageQty(package.quantity.toString()),
                      style: context.styles.caption,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
