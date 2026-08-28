import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/service/service_catalog_controller.dart';
import 'package:telepos/presentation/screens/service/dialogs/service_consumables_dialog.dart';

class ServiceCatalogScreen extends ConsumerWidget {
  const ServiceCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(serviceCatalogProvider);
    final notifier = ref.read(serviceCatalogProvider.notifier);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, notifier, l10n),
        icon: const Icon(TeleposIcons.add),
        label: Text(l10n.serviceCatalogAdd),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.of(context).padding.top + 12,
              24,
              12,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go(AppRoutes.serviceQueue),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Text(l10n.serviceCatalogTitle, style: AppTextStyles.h2),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _showCreateDialog(context, notifier, l10n),
                  icon: const Icon(TeleposIcons.add, size: 18),
                  label: Text(l10n.serviceCatalogAdd),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.items.isEmpty
                ? _buildEmptyState(context, l10n, notifier)
                : _buildList(context, state, notifier, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppLocalizations l10n,
    ServiceCatalogNotifier notifier,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.build_outlined,
              size: 40,
              color: AppColors.textDisabled,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.serviceNoOrders,
            style: AppTextStyles.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _showCreateDialog(context, notifier, l10n),
            icon: const Icon(TeleposIcons.add, size: 18),
            label: Text(l10n.serviceCatalogAdd),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    ServiceCatalogState state,
    ServiceCatalogNotifier notifier,
    AppLocalizations l10n,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final item = state.items[index];
        return _ServiceItem(
          item: item,
          onEdit: () => _showEditDialog(context, item, notifier, l10n),
          onToggleQuick: () =>
              notifier.toggleQuick(item.productUcode, item.name),
          onDelete: () => _confirmDelete(context, item, notifier, l10n),
          onConsumables: () => ServiceConsumablesDialog.show(
            context,
            serviceProductUcode: item.productUcode,
            serviceName: item.name,
          ),
        );
      },
    );
  }

  Future<void> _showCreateDialog(
    BuildContext context,
    ServiceCatalogNotifier notifier,
    AppLocalizations l10n,
  ) async {
    final result = await showDialog<_ServiceFormResult>(
      context: context,
      builder: (_) => _ServiceFormDialog(l10n: l10n),
    );

    if (result != null) {
      await notifier.createServiceProduct(
        name: result.name,
        price: result.price,
        estimatedDurationMinutes: result.durationMinutes,
        warrantyDays: result.warrantyDays,
        requiresDevice: result.requiresDevice,
      );
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    ServiceCatalogItem item,
    ServiceCatalogNotifier notifier,
    AppLocalizations l10n,
  ) async {
    final result = await showDialog<_ServiceFormResult>(
      context: context,
      builder: (_) => _ServiceFormDialog(l10n: l10n, existingItem: item),
    );

    if (result != null) {
      await notifier.updateServiceMeta(
        productUcode: item.productUcode,
        estimatedDurationMinutes: result.durationMinutes,
        warrantyDays: result.warrantyDays,
        requiresDevice: result.requiresDevice,
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ServiceCatalogItem item,
    ServiceCatalogNotifier notifier,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.catalogDeleteProduct),
        content: Text(l10n.catalogConfirmDelete(item.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.globalCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: AppColors.white,
            ),
            child: Text(l10n.globalDelete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await notifier.deleteService(item.productUcode);
    }
  }
}

class _ServiceItem extends StatelessWidget {
  const _ServiceItem({
    required this.item,
    required this.onEdit,
    required this.onToggleQuick,
    required this.onDelete,
    required this.onConsumables,
  });

  final ServiceCatalogItem item;
  final VoidCallback onEdit;
  final VoidCallback onToggleQuick;
  final VoidCallback onDelete;
  final VoidCallback onConsumables;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.requiresDevice ? Icons.devices : Icons.build_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.isQuick)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.flash_on,
                              size: 14,
                              color: AppColors.warning,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${item.price} ${l10n.currencySymbol}',
                          style: context.styles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.estimatedDurationMinutes != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${item.estimatedDurationMinutes} ${l10n.serviceCatalogDuration}',
                            style: context.styles.caption,
                          ),
                        ],
                        if (item.warrantyDays != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.verified_outlined,
                            size: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${item.warrantyDays} ${l10n.serviceCatalogWarranty}',
                            style: context.styles.caption,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 20,
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                    case 'consumables':
                      onConsumables();
                    case 'quick':
                      onToggleQuick();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit, size: 18),
                        const SizedBox(width: 8),
                        Text(l10n.serviceOrderUpdated),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'consumables',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.handyman,
                          size: 18,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 8),
                        Text(l10n.serviceConsumablesTitle),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'quick',
                    child: Row(
                      children: [
                        Icon(
                          item.isQuick ? Icons.flash_off : Icons.flash_on,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.isQuick
                              ? l10n.catalogRemoveFromQuick
                              : l10n.catalogAddToQuick,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          TeleposIcons.delete,
                          size: 18,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.catalogDeleteProduct,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceFormResult {
  const _ServiceFormResult({
    required this.name,
    required this.price,
    this.durationMinutes,
    this.warrantyDays,
    this.requiresDevice = false,
  });

  final String name;
  final Decimal price;
  final int? durationMinutes;
  final int? warrantyDays;
  final bool requiresDevice;
}

class _ServiceFormDialog extends StatefulWidget {
  const _ServiceFormDialog({required this.l10n, this.existingItem});

  final AppLocalizations l10n;
  final ServiceCatalogItem? existingItem;

  @override
  State<_ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends State<_ServiceFormDialog> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _durationController = TextEditingController();
  final _warrantyController = TextEditingController();
  bool _requiresDevice = false;

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final item = widget.existingItem!;
      _nameController.text = item.name;
      _priceController.text = item.price.toString();
      _durationController.text =
          item.estimatedDurationMinutes?.toString() ?? '';
      _warrantyController.text = item.warrantyDays?.toString() ?? '';
      _requiresDevice = item.requiresDevice;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _warrantyController.dispose();
    super.dispose();
  }

  bool get _isValid {
    if (_isEditing) return true;
    return _nameController.text.trim().isNotEmpty &&
        _priceController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;

    return AlertDialog(
      title: Text(
        _isEditing ? l10n.serviceOrderUpdated : l10n.serviceCatalogAdd,
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_isEditing) ...[
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: '${l10n.catalogProductName} *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.build_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: '${l10n.catalogPrice} *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.attach_money, size: 20),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.serviceCatalogDuration,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.access_time, size: 20),
                  suffixText: l10n.serviceCatalogDuration,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _warrantyController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.serviceCatalogWarranty,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.verified_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _requiresDevice,
                onChanged: (v) => setState(() => _requiresDevice = v ?? false),
                title: Text(l10n.serviceCatalogRequiresDevice),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
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
          onPressed: _isValid
              ? () {
                  Navigator.of(context).pop(
                    _ServiceFormResult(
                      name: _nameController.text.trim(),
                      price:
                          Decimal.tryParse(_priceController.text.trim()) ??
                          Decimal.zero,
                      durationMinutes: int.tryParse(_durationController.text),
                      warrantyDays: int.tryParse(_warrantyController.text),
                      requiresDevice: _requiresDevice,
                    ),
                  );
                }
              : null,
          child: Text(l10n.serviceIntakeSave),
        ),
      ],
    );
  }
}
