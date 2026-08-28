import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/service/service_catalog_controller.dart';

class ServiceConsumablesDialog extends ConsumerStatefulWidget {
  const ServiceConsumablesDialog({
    required this.serviceProductUcode,
    required this.serviceName,
    super.key,
  });

  final int serviceProductUcode;
  final String serviceName;

  static Future<void> show(
    BuildContext context, {
    required int serviceProductUcode,
    required String serviceName,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ServiceConsumablesDialog(
        serviceProductUcode: serviceProductUcode,
        serviceName: serviceName,
      ),
    );
  }

  @override
  ConsumerState<ServiceConsumablesDialog> createState() =>
      _ServiceConsumablesDialogState();
}

class _ServiceConsumablesDialogState
    extends ConsumerState<ServiceConsumablesDialog> {
  List<_ConsumableDisplay> _consumables = [];
  bool _isLoading = true;

  final _searchController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  List<_ProductResult> _searchResults = [];
  _ProductResult? _selectedProduct;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadConsumables();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadConsumables() async {
    setState(() => _isLoading = true);
    final notifier = ref.read(serviceCatalogProvider.notifier);
    final rows = await notifier.loadConsumables(widget.serviceProductUcode);
    if (mounted) {
      setState(() {
        _consumables = rows
            .map(
              (r) => _ConsumableDisplay(
                id: r.id,
                name: r.name,
                price: r.price,
                quantity: r.quantity,
              ),
            )
            .toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _searchProducts(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final db = GetIt.I<AppDatabase>();
      final products = await db.productInfoDao.findByNamePart('%$query%');
      final items = <_ProductResult>[];
      for (final p in products) {
        if (p.isDeleted) continue;
        if (p.type == 4) continue;
        final priceRow = await db.productPriceDao.findByUcode(p.ucode);
        items.add(
          _ProductResult(
            ucode: p.ucode,
            name: p.name,
            price: priceRow?.sellingPrice ?? Decimal.zero,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _searchResults = items;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _addConsumable() async {
    if (_selectedProduct == null) return;
    final qty = Decimal.tryParse(_quantityController.text.trim());
    if (qty == null || qty <= Decimal.zero) return;

    final notifier = ref.read(serviceCatalogProvider.notifier);
    final ok = await notifier.addConsumable(
      serviceProductUcode: widget.serviceProductUcode,
      consumableUcode: _selectedProduct!.ucode,
      quantity: qty,
    );

    if (ok) {
      setState(() {
        _selectedProduct = null;
        _searchController.clear();
        _searchResults = [];
        _quantityController.text = '1';
      });
      await _loadConsumables();
    }
  }

  Future<void> _removeConsumable(int id) async {
    final notifier = ref.read(serviceCatalogProvider.notifier);
    await notifier.removeConsumable(id);
    await _loadConsumables();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.handyman, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${l10n.serviceConsumablesTitle}: ${widget.serviceName}',
              style: const TextStyle(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_consumables.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    l10n.serviceConsumablesEmpty,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _consumables.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final c = _consumables[index];
                    return ListTile(
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.inventory_2,
                          size: 16,
                          color: AppColors.info,
                        ),
                      ),
                      title: Text(c.name, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        '${c.price} x ${c.quantity} = ${c.price * c.quantity}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(TeleposIcons.close, size: 16),
                        onPressed: () => _removeConsumable(c.id),
                        visualDensity: VisualDensity.compact,
                      ),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  },
                ),
              ),

            const Divider(height: 24),

            Text(
              l10n.serviceConsumablesAdd,
              style: context.styles.caption.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            if (_selectedProduct != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedProduct!.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${_selectedProduct!.price}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(TeleposIcons.close, size: 16),
                      onPressed: () => setState(() => _selectedProduct = null),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              )
            else ...[
              TextField(
                controller: _searchController,
                onChanged: _searchProducts,
                decoration: InputDecoration(
                  hintText: l10n.serviceConsumableSearch,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              if (_isSearching)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (_searchResults.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 100),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final p = _searchResults[index];
                      return ListTile(
                        title: Text(
                          p.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                        subtitle: Text(
                          '${p.price}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => setState(() {
                          _selectedProduct = p;
                          _searchResults = [];
                          _searchController.clear();
                        }),
                        dense: true,
                        visualDensity: VisualDensity.compact,
                      );
                    },
                  ),
                ),
            ],

            if (_selectedProduct != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.serviceConsumableQuantity,
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _addConsumable,
                    icon: const Icon(TeleposIcons.add, size: 16),
                    label: Text(
                      l10n.serviceConsumablesAdd,
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.globalOk),
        ),
      ],
    );
  }
}

class _ConsumableDisplay {
  const _ConsumableDisplay({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
  });

  final int id;
  final String name;
  final Decimal price;
  final Decimal quantity;
}

class _ProductResult {
  const _ProductResult({
    required this.ucode,
    required this.name,
    required this.price,
  });

  final int ucode;
  final String name;
  final Decimal price;
}
