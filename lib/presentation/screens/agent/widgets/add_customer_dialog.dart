import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/agent/agent_controller.dart';

class AddCustomerDialog extends ConsumerStatefulWidget {
  const AddCustomerDialog({this.initialType, super.key});

  final AgentType? initialType;

  @override
  ConsumerState<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends ConsumerState<AddCustomerDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(addCustomerProvider.notifier).reset();
      if (widget.initialType != null) {
        ref
            .read(addCustomerProvider.notifier)
            .setAgentType(widget.initialType!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(addCustomerProvider);
    final notifier = ref.read(addCustomerProvider.notifier);

    if (state.restoredAgent != null) {
      return _buildRestoreDialog(context, state, notifier);
    }

    final typeLabel = state.agentType == AgentType.supplier
        ? l10n.agentTypeSupplier
        : l10n.agentTypeCustomer;

    return AlertDialog(
      title: Text('${l10n.globalNew} $typeLabel'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.initialType == null) ...[
              SegmentedButton<AgentType>(
                segments: [
                  ButtonSegment(
                    value: AgentType.customer,
                    label: Text(l10n.agentTypeCustomer),
                    icon: const Icon(TeleposIcons.person, size: 18),
                  ),
                  ButtonSegment(
                    value: AgentType.supplier,
                    label: Text(l10n.agentTypeSupplier),
                    icon: const Icon(Icons.local_shipping, size: 18),
                  ),
                ],
                selected: {state.agentType},
                onSelectionChanged: (set) => notifier.setAgentType(set.first),
              ),
              const SizedBox(height: 16),
            ],

            TextField(
              onChanged: notifier.setName,
              decoration: InputDecoration(
                labelText: l10n.agentNameRequired,
                hintText: l10n.agentNameHint,
                errorText: state.nameError != null
                    ? ErrorLocalizer.localize(context, state.nameError!)
                    : null,
                prefixIcon: const Icon(TeleposIcons.person),
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 16),

            TextField(
              onChanged: notifier.setPhone,
              decoration: InputDecoration(
                labelText: l10n.agentPhone,
                hintText: '+7 (XXX) XXX-XX-XX',
                errorText: state.phoneError != null
                    ? ErrorLocalizer.localize(context, state.phoneError!)
                    : null,
                prefixIcon: const Icon(Icons.phone),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            TextField(
              onChanged: notifier.setBin,
              decoration: InputDecoration(
                labelText: l10n.agentBinIin,
                hintText: l10n.agentBinHint,
                errorText: state.binError != null
                    ? ErrorLocalizer.localize(context, state.binError!)
                    : null,
                prefixIcon: const Icon(Icons.badge),
                border: const OutlineInputBorder(),
                counterText: '',
              ),
              keyboardType: TextInputType.number,
              maxLength: 12,
            ),

            if (state.error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
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
                        style: AppTextStyles.body.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.globalCancel),
        ),
        ElevatedButton(
          onPressed: state.isLoading || !state.isValid
              ? null
              : () async {
                  final result = await notifier.save();
                  if (result != null && context.mounted) {
                    Navigator.of(context).pop(result);
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
          ),
          child: state.isLoading
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
    );
  }

  Widget _buildRestoreDialog(
    BuildContext context,
    AddCustomerState state,
    AddCustomerNotifier notifier,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final agent = state.restoredAgent!;

    return AlertDialog(
      title: Text(l10n.agentCustomerFound),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(TeleposIcons.info, color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.agentDeletedPhoneMsg,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.agentRestoreQuestion,
                          style: AppTextStyles.body.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  agent.name.isNotEmpty ? agent.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              title: Text(agent.name),
              subtitle: Text(agent.formattedPhone),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            notifier.reset();
            Navigator.of(context).pop();
          },
          child: Text(l10n.globalCancel),
        ),
        ElevatedButton(
          onPressed: state.isLoading
              ? null
              : () async {
                  final result = await notifier.restoreDeleted();
                  if (result != null && context.mounted) {
                    Navigator.of(context).pop(result);
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: AppColors.white,
          ),
          child: state.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
              : Text(l10n.agentRestore),
        ),
      ],
    );
  }
}
