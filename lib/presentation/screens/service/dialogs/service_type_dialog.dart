import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/service/service_catalog_controller.dart';

class ServiceTypeDialog extends ConsumerStatefulWidget {
  const ServiceTypeDialog({super.key});

  static Future<List<ServiceCatalogItem>?> show(BuildContext context) {
    return showDialog<List<ServiceCatalogItem>>(
      context: context,
      builder: (_) => const ServiceTypeDialog(),
    );
  }

  @override
  ConsumerState<ServiceTypeDialog> createState() => _ServiceTypeDialogState();
}

class _ServiceTypeDialogState extends ConsumerState<ServiceTypeDialog> {
  final Set<int> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(serviceCatalogProvider);

    return AlertDialog(
      title: Text(l10n.serviceCatalogTitle),
      content: SizedBox(
        width: 400,
        height: 400,
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.items.isEmpty
            ? Center(child: Text(l10n.serviceNoOrders))
            : ListView.builder(
                itemCount: state.items.length,
                itemBuilder: (context, index) {
                  final item = state.items[index];
                  final isSelected = _selectedIds.contains(item.productUcode);

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedIds.add(item.productUcode);
                        } else {
                          _selectedIds.remove(item.productUcode);
                        }
                      });
                    },
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.price} ${l10n.currencySymbol}'
                      '${item.estimatedDurationMinutes != null ? ' / ${item.estimatedDurationMinutes} ${l10n.serviceCatalogDuration}' : ''}',
                    ),
                    secondary: item.requiresDevice
                        ? const Icon(Icons.devices, size: 20)
                        : null,
                    dense: true,
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.serviceIntakeCancel),
        ),
        FilledButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () {
                  final selected = state.items
                      .where((i) => _selectedIds.contains(i.productUcode))
                      .toList();
                  Navigator.of(context).pop(selected);
                },
          child: Text(l10n.serviceIntakeSave),
        ),
      ],
    );
  }
}
