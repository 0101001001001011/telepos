import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/platform/local_file.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/service/service_intake_controller.dart';
import 'package:telepos/presentation/screens/service/dialogs/assign_technician_dialog.dart';
import 'package:telepos/presentation/screens/service/dialogs/client_lookup_dialog.dart';
import 'package:telepos/presentation/screens/service/dialogs/prepayment_dialog.dart';
import 'package:telepos/presentation/screens/service/dialogs/service_type_dialog.dart';
import 'package:telepos/presentation/screens/service/widgets/quick_services_grid.dart';

class ServiceIntakeScreen extends ConsumerStatefulWidget {
  const ServiceIntakeScreen({super.key});

  @override
  ConsumerState<ServiceIntakeScreen> createState() =>
      _ServiceIntakeScreenState();
}

class _ServiceIntakeScreenState extends ConsumerState<ServiceIntakeScreen> {
  final _clientNameController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(serviceIntakeProvider);
    final notifier = ref.read(serviceIntakeProvider.notifier);
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.serviceIntakeTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            notifier.reset();
            context.go(AppRoutes.serviceQueue);
          },
        ),
      ),
      body: state.isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _buildClientSection(l10n, state, notifier),
                              const SizedBox(height: 12),
                              _buildItemsSection(l10n, state, notifier),
                              const SizedBox(height: 12),
                              _buildPhotosSection(l10n, state, notifier),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: [
                              _buildServicesSection(l10n, state, notifier),
                              const SizedBox(height: 12),
                              _buildParametersSection(l10n, state, notifier),
                              const SizedBox(height: 12),
                              _buildDeliverySection(l10n, state, notifier),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildClientSection(l10n, state, notifier),
                        const SizedBox(height: 12),
                        _buildItemsSection(l10n, state, notifier),
                        const SizedBox(height: 12),
                        _buildPhotosSection(l10n, state, notifier),
                        const SizedBox(height: 12),
                        _buildServicesSection(l10n, state, notifier),
                        const SizedBox(height: 12),
                        _buildParametersSection(l10n, state, notifier),
                        const SizedBox(height: 12),
                        _buildDeliverySection(l10n, state, notifier),
                      ],
                    ),
            ),
      bottomNavigationBar: _buildBottomBar(l10n, state, notifier),
    );
  }

  Widget _buildClientSection(
    AppLocalizations l10n,
    ServiceIntakeState state,
    ServiceIntakeNotifier notifier,
  ) {
    final theme = Theme.of(context);

    if (state.clientFromLookup) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.serviceIntakeClient,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.15,
                      ),
                      child: const Icon(
                        TeleposIcons.person,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.clientName ?? '',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (state.clientPhone != null)
                            Text(
                              state.clientPhone!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(TeleposIcons.close, size: 18),
                      onPressed: () {
                        notifier.updateClient();
                        _clientNameController.clear();
                        _clientPhoneController.clear();
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.serviceIntakeClient,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final result = await ClientLookupDialog.show(context);
                    if (result != null) {
                      notifier.updateClient(
                        agentId: result.agentId,
                        name: result.name,
                        phone: result.phone,
                        fromLookup: true,
                      );
                      if (result.address != null) {
                        notifier.setDeliveryAddress(result.address);
                        _addressController.text = result.address!;
                      }
                    }
                  },
                  icon: const Icon(Icons.person_search, size: 16),
                  label: Text(
                    l10n.serviceClientOrSearch,
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _clientNameController,
                    onChanged: (v) {
                      notifier.updateClient(
                        name: v.trim().isEmpty ? null : v.trim(),
                      );
                    },
                    decoration: InputDecoration(
                      labelText: l10n.serviceClientQuickName,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _clientPhoneController,
                    onChanged: (v) {
                      notifier.updateClient(
                        name: _clientNameController.text.trim().isEmpty
                            ? null
                            : _clientNameController.text.trim(),
                        phone: v.trim().isEmpty ? null : v.trim(),
                      );
                    },
                    decoration: InputDecoration(
                      labelText: l10n.serviceClientQuickPhone,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection(
    AppLocalizations l10n,
    ServiceIntakeState state,
    ServiceIntakeNotifier notifier,
  ) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.serviceIntakeItems,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (state.items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        l10n.serviceItemCount(state.items.length),
                        style: context.styles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showAddItemDialog(notifier),
                  icon: const Icon(TeleposIcons.add, size: 18),
                  label: Text(l10n.serviceItemAdd),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            if (state.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 32,
                        color: AppColors.textDisabled,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.serviceItemEmpty,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...state.items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.semantic.canvas,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '${idx + 1}',
                            style: context.styles.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (item.description != null &&
                                item.description!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  item.description!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (item.serialNumber != null &&
                                item.serialNumber!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'S/N: ${item.serialNumber}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(TeleposIcons.close, size: 16),
                        onPressed: () => notifier.removeItem(idx),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddItemDialog(ServiceIntakeNotifier notifier) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final serialCtrl = TextEditingController();
    final l10n = AppLocalizations.of(context)!;

    final result = await showDialog<IntakeItem>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.serviceItemAdd),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: '${l10n.serviceItemName} *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.category_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.serviceItemDescription,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: serialCtrl,
                decoration: InputDecoration(
                  labelText: l10n.serviceItemSerial,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.qr_code_2, size: 20),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.serviceIntakeCancel),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop(
                IntakeItem(
                  name: name,
                  description: descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                  serialNumber: serialCtrl.text.trim().isEmpty
                      ? null
                      : serialCtrl.text.trim(),
                ),
              );
            },
            child: Text(l10n.serviceIntakeSave),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    descCtrl.dispose();
    serialCtrl.dispose();

    if (result != null) {
      notifier.addItem(result);
    }
  }

  Widget _buildPhotosSection(
    AppLocalizations l10n,
    ServiceIntakeState state,
    ServiceIntakeNotifier notifier,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.serviceIntakePhotos,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _pickPhoto(notifier),
                  icon: const Icon(Icons.add_a_photo, size: 18),
                  label: Text(l10n.globalAdd),
                ),
              ],
            ),
            if (state.intakePhotoPaths.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    l10n.serviceIntakePhotosHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: state.intakePhotoPaths.asMap().entries.map((entry) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: localImage(
                          entry.value,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => notifier.removeIntakePhoto(entry.key),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              TeleposIcons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto(ServiceIntakeNotifier notifier) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image != null) {
      notifier.addIntakePhoto(image.path);
    }
  }

  Widget _buildServicesSection(
    AppLocalizations l10n,
    ServiceIntakeState state,
    ServiceIntakeNotifier notifier,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.serviceIntakeServices,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final selected = await ServiceTypeDialog.show(context);
                    if (selected != null && selected.isNotEmpty) {
                      for (final item in selected) {
                        notifier.addService(
                          ServiceTypeItem(
                            serviceTypeId: item.id,
                            productUcode: item.productUcode,
                            name: item.name,
                            price: item.price,
                            estimatedMinutes: item.estimatedDurationMinutes,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.list_alt, size: 16),
                  label: Text(
                    l10n.serviceCatalogTitle,
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),

            QuickServicesGrid(
              crossAxisCount: 3,
              onServiceTap: (item) {
                notifier.addService(
                  ServiceTypeItem(
                    productUcode: item.ucode,
                    name: item.name,
                    price: item.price,
                  ),
                );
              },
            ),

            if (state.selectedServices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    l10n.serviceNoOrders,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...state.selectedServices.asMap().entries.map((entry) {
                final index = entry.key;
                final service = entry.value;
                return ListTile(
                  leading: const Icon(Icons.build_outlined, size: 18),
                  title: Text(service.name),
                  subtitle: Text(
                    '${service.price} ${l10n.currencySymbol}'
                    '${service.estimatedMinutes != null ? ' / ${service.estimatedMinutes} ${l10n.serviceCatalogDuration}' : ''}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: () => notifier.removeService(index),
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                );
              }),
            if (state.selectedServices.isNotEmpty) ...[
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.serviceTotalCost,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${state.servicesTotal} ${l10n.currencySymbol}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParametersSection(
    AppLocalizations l10n,
    ServiceIntakeState state,
    ServiceIntakeNotifier notifier,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.serviceDetailActions,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.engineering_outlined, size: 20),
              title: Text(l10n.serviceAssignTechnician),
              subtitle: state.assigneeName != null
                  ? Text(state.assigneeName!)
                  : null,
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () async {
                final result = await AssignTechnicianDialog.show(context);
                if (result != null) {
                  notifier.setAssignee(result.id, name: result.name);
                }
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            ListTile(
              leading: const Icon(Icons.payments_outlined, size: 20),
              title: Text(l10n.servicePrepayment),
              subtitle: state.prepaymentAmount != null
                  ? Text('${state.prepaymentAmount} ${l10n.currencySymbol}')
                  : null,
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () async {
                final amount = await PrepaymentDialog.show(
                  context,
                  currentAmount: state.prepaymentAmount,
                );
                if (amount != null) {
                  notifier.setPrepayment(amount);
                }
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            ListTile(
              leading: const Icon(Icons.event_outlined, size: 20),
              title: Text(l10n.serviceEstimatedDate),
              subtitle: state.estimatedCompletionDate != null
                  ? Text(
                      '${state.estimatedCompletionDate!.day.toString().padLeft(2, '0')}.'
                      '${state.estimatedCompletionDate!.month.toString().padLeft(2, '0')}.'
                      '${state.estimatedCompletionDate!.year}',
                    )
                  : null,
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: state.estimatedCompletionDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  notifier.setEstimatedDate(date);
                }
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliverySection(
    AppLocalizations l10n,
    ServiceIntakeState state,
    ServiceIntakeNotifier notifier,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.serviceIntakeDelivery,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              value: state.needsPickup,
              onChanged: (v) => notifier.setNeedsPickup(v ?? false),
              title: Text(l10n.serviceNeedsPickup),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              value: state.needsDelivery,
              onChanged: (v) => notifier.setNeedsDelivery(v ?? false),
              title: Text(l10n.serviceNeedsDelivery),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (state.needsPickup || state.needsDelivery) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _addressController,
                onChanged: (v) => notifier.setDeliveryAddress(v),
                decoration: InputDecoration(
                  labelText: l10n.serviceDeliveryAddress,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    AppLocalizations l10n,
    ServiceIntakeState state,
    ServiceIntakeNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (state.error != null)
              Expanded(
                child: Text(
                  state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (state.error == null) const Spacer(),
            OutlinedButton(
              onPressed: () {
                notifier.reset();
                context.go(AppRoutes.serviceQueue);
              },
              child: Text(l10n.serviceIntakeCancel),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: state.isValid && !state.isSaving
                  ? () async {
                      final orderId = await notifier.save();
                      if (orderId != null && mounted) {
                        notifier.reset();
                        context.go(
                          AppRoutes.serviceDetail.replaceFirst(
                            ':orderId',
                            '$orderId',
                          ),
                        );
                      }
                    }
                  : null,
              icon: const Icon(TeleposIcons.save),
              label: Text(l10n.serviceIntakeSave),
            ),
          ],
        ),
      ),
    );
  }
}
