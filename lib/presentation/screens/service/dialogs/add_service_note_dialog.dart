import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';

class ServiceNoteResult {
  const ServiceNoteResult({
    required this.description,
    required this.markType,
    this.cost,
    this.note,
    this.productUcode,
    this.approvalStatus,
    this.quantity,
  });

  final String description;
  final int markType;
  final Decimal? cost;
  final String? note;
  final int? productUcode;
  final int? approvalStatus;

  final Decimal? quantity;
}

class AddServiceNoteDialog extends StatefulWidget {
  const AddServiceNoteDialog({super.key});

  static Future<ServiceNoteResult?> show(BuildContext context) {
    return showDialog<ServiceNoteResult>(
      context: context,
      builder: (_) => const AddServiceNoteDialog(),
    );
  }

  @override
  State<AddServiceNoteDialog> createState() => _AddServiceNoteDialogState();
}

class _AddServiceNoteDialogState extends State<AddServiceNoteDialog> {
  final _searchController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _descriptionController = TextEditingController();
  final _noteController = TextEditingController();
  bool _requiresApproval = false;

  List<_CatalogItem> _searchResults = [];
  _CatalogItem? _selectedItem;
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _selectedItem != null && _descriptionController.text.trim().isNotEmpty;

  Decimal get _quantity =>
      Decimal.tryParse(_quantityController.text.trim()) ?? Decimal.one;

  Decimal get _totalCost => (_selectedItem?.price ?? Decimal.zero) * _quantity;

  int _resolveMarkType(_CatalogItem item) {
    return switch (item.productType) {
      4 => 4,
      5 => 5,
      _ => 5,
    };
  }

  String _measureLabel(int measure, AppLocalizations l10n) {
    return switch (measure) {
      1 => l10n.catalogMeasureKg,
      2 => l10n.catalogMeasureLiter,
      3 => l10n.catalogMeasureMeter,
      _ => l10n.catalogMeasurePiece,
    };
  }

  (IconData, Color) _typeIcon(int productType) {
    return switch (productType) {
      4 => (Icons.build_outlined, AppColors.primary),
      5 => (Icons.handyman, AppColors.info),
      1 => (Icons.scale, AppColors.info),
      6 => (Icons.restaurant, Colors.deepOrange),
      _ => (Icons.inventory_2, AppColors.success),
    };
  }

  Future<void> _searchCatalog(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final db = GetIt.I<AppDatabase>();
      final products = await db.productInfoDao.findByNamePart('%$query%');
      final items = <_CatalogItem>[];
      for (final p in products) {
        if (p.isDeleted) continue;
        if (p.type == 3) continue;
        final priceRow = await db.productPriceDao.findByUcode(p.ucode);
        items.add(
          _CatalogItem(
            ucode: p.ucode,
            name: p.name,
            price: priceRow?.sellingPrice ?? Decimal.zero,
            productType: p.type,
            measure: p.measure,
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

  void _selectItem(_CatalogItem item) {
    setState(() {
      _selectedItem = item;
      _searchResults = [];
      _searchController.clear();
      _descriptionController.text = item.name;
      _quantityController.text = '1';
    });
  }

  void _clearItem() {
    setState(() {
      _selectedItem = null;
      _descriptionController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.serviceAddMark),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedItem != null)
                _buildSelectedCard(l10n)
              else ...[
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _searchCatalog,
                  decoration: InputDecoration(
                    labelText: l10n.serviceConsumableSearch,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (_searchResults.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        final (icon, color) = _typeIcon(item.productType);
                        return ListTile(
                          leading: Icon(icon, size: 18, color: color),
                          title: Text(
                            item.name,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            '${item.price} ${l10n.currencySymbol} / ${_measureLabel(item.measure, l10n)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () => _selectItem(item),
                          dense: true,
                          visualDensity: VisualDensity.compact,
                        );
                      },
                    ),
                  )
                else if (_searchController.text.length >= 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        l10n.catalogNoProducts,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: 12),

              TextField(
                controller: _descriptionController,
                maxLines: 2,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: '${l10n.serviceMarkDescription} *',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              if (_selectedItem != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: l10n.serviceConsumableQuantity,
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixText: _measureLabel(
                            _selectedItem!.measure,
                            l10n,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_selectedItem!.price} × $_quantity',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_totalCost ${l10n.currencySymbol}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              SwitchListTile(
                title: const Text(
                  'Требует согласования клиента',
                  style: TextStyle(fontSize: 13),
                ),
                value: _requiresApproval,
                onChanged: (v) => setState(() => _requiresApproval = v),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const SizedBox(height: 4),

              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.serviceMarkNote,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.serviceIntakeCancel),
        ),
        FilledButton(
          onPressed: _isValid ? _submit : null,
          child: Text(l10n.serviceIntakeSave),
        ),
      ],
    );
  }

  Widget _buildSelectedCard(AppLocalizations l10n) {
    final item = _selectedItem!;
    final (icon, color) = _typeIcon(item.productType);
    final typeLabel = switch (item.productType) {
      0 => l10n.catalogTypeNormal,
      1 => l10n.catalogTypeWeight,
      2 => l10n.catalogTypeInner,
      4 => l10n.catalogTypeService,
      5 => l10n.catalogTypeConsumable,
      6 => l10n.catalogTypeDish,
      _ => '',
    };

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '$typeLabel • ${item.price} ${l10n.currencySymbol} / ${_measureLabel(item.measure, l10n)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(TeleposIcons.close, size: 16),
            onPressed: _clearItem,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (!_isValid) return;

    final item = _selectedItem!;
    final note = _noteController.text.trim();

    Navigator.of(context).pop(
      ServiceNoteResult(
        description: _descriptionController.text.trim(),
        markType: _resolveMarkType(item),
        cost: _totalCost,
        note: note.isNotEmpty ? note : null,
        productUcode: item.ucode,
        approvalStatus: _requiresApproval ? 0 : null,
        quantity: _quantity,
      ),
    );
  }
}

class _CatalogItem {
  const _CatalogItem({
    required this.ucode,
    required this.name,
    required this.price,
    required this.productType,
    required this.measure,
  });

  final int ucode;
  final String name;
  final Decimal price;
  final int productType;
  final int measure;
}
