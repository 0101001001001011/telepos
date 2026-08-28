import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/supply/supply_controller.dart';
import 'package:telepos/presentation/screens/supply/widgets/supply_form.dart';
import 'package:telepos/presentation/screens/supply/dialogs/supply_dialog.dart';

class SupplyScreen extends StatelessWidget {
  const SupplyScreen({super.key});

  static Future<bool?> show(BuildContext context) async {
    final width = MediaQuery.of(context).size.width;
    final layoutType = Breakpoints.fromWidth(width);

    if (layoutType == LayoutType.mobile) {
      return Navigator.of(
        context,
      ).push<bool>(MaterialPageRoute(builder: (_) => const SupplyScreen()));
    } else {
      return SupplyDialog.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SupplyMobileScreen();
  }
}

class SupplyMobileScreen extends ConsumerWidget {
  const SupplyMobileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(supplyControllerProvider);
    final controller = ref.read(supplyControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.supplyTitle),
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
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                const Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: SupplyForm(),
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
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.supplyProductCountLabel(
                                  state.productCount,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.supplyTotalLabel(
                                  state.totalAmount?.toStringAsFixed(2) ??
                                      '0.00',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
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

  Future<void> _onSave(BuildContext context, SupplyNotifier controller) async {
    final l10n = AppLocalizations.of(context)!;
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
        controller.cancel();
        if (context.mounted) context.go(AppRoutes.stockRegistry);
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

  void _onCancel(
    BuildContext context,
    SupplyNotifier controller,
    SupplyState state,
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
          title: Text(dl10n.supplyCancelConfirm),
          content: Text(dl10n.supplyCancelMessage),
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
              child: Text(dl10n.supplyYesCancel),
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
