import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/domain/usecases/writeoff/create_writeoff_use_case.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/writeoff/writeoff_controller.dart';

class WriteoffScreen extends ConsumerStatefulWidget {
  const WriteoffScreen({super.key});

  @override
  ConsumerState<WriteoffScreen> createState() => _WriteoffScreenState();
}

class _WriteoffScreenState extends ConsumerState<WriteoffScreen> {
  final _barcodeController = TextEditingController();
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _barcodeController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(writeoffControllerProvider);
    final controller = ref.read(writeoffControllerProvider.notifier);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1200;

    if (isDesktop) {
      return _buildDesktopContent(state, controller);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.writeoffTitle),
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
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: state.canSave ? () => _onSave(context) : null,
              child: Text(
                AppLocalizations.of(context)!.globalSave,
                style: TextStyle(
                  color: state.canSave ? Colors.white : Colors.white54,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (state.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
              child: Text(
                ErrorLocalizer.localize(context, state.error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildForm(state, controller),
            ),
          ),
          if (state.products.isNotEmpty) _buildTotalBar(state),
        ],
      ),
    );
  }

  Widget _buildDesktopContent(
    WriteoffState state,
    WriteoffNotifier controller,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(TeleposIcons.delete, size: 28),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.writeoffTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: state.canSave ? () => _onSave(context) : null,
                icon: const Icon(TeleposIcons.check),
                label: Text(AppLocalizations.of(context)!.globalSave),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildForm(state, controller),
          if (state.products.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildProductsTable(state),
            const SizedBox(height: 16),
            _buildTotalRow(state),
          ],
        ],
      ),
    );
  }

  Widget _buildForm(WriteoffState state, WriteoffNotifier controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.writeoffReason,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<WriteoffReason>(
          value: state.reason,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: WriteoffReason.values.map((r) {
            return DropdownMenuItem(
              value: r,
              child: Text(_reasonLabel(context, r)),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) controller.setReason(v);
          },
        ),
        const SizedBox(height: 16),

        Text(
          AppLocalizations.of(context)!.writeoffProduct,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _barcodeController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.writeoffScanHint,
            prefixIcon: const Icon(Icons.qr_code_scanner),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              controller.addProductByBarcode(value);
              _barcodeController.clear();
            }
          },
        ),
        const SizedBox(height: 16),

        if (state.products.isNotEmpty &&
            MediaQuery.of(context).size.width < 1200)
          ...state.products.map((p) => _buildProductCard(p, controller)),

        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!.cashCommentOptional,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _commentController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.writeoffCommentHint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: controller.setComment,
        ),
      ],
    );
  }

  Widget _buildProductCard(
    WriteoffProductItem product,
    WriteoffNotifier controller,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(product.name),
        subtitle: Text(
          '${product.quantity} x ${product.price} = ${product.amount}',
        ),
        trailing: IconButton(
          icon: Icon(
            TeleposIcons.close,
            color: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => controller.removeProduct(product.ucode),
        ),
      ),
    );
  }

  Widget _buildProductsTable(WriteoffState state) {
    return DataTable(
      columns: [
        DataColumn(label: Text(AppLocalizations.of(context)!.writeoffProduct)),
        DataColumn(
          label: Text(AppLocalizations.of(context)!.globalQuantity),
          numeric: true,
        ),
        DataColumn(
          label: Text(AppLocalizations.of(context)!.globalPrice),
          numeric: true,
        ),
        DataColumn(
          label: Text(AppLocalizations.of(context)!.globalAmount),
          numeric: true,
        ),
        const DataColumn(label: Text('')),
      ],
      rows: state.products.map((p) {
        return DataRow(
          cells: [
            DataCell(Text(p.name)),
            DataCell(Text(p.quantity.toString())),
            DataCell(Text(p.price.toStringAsFixed(2))),
            DataCell(Text(p.amount.toStringAsFixed(2))),
            DataCell(
              IconButton(
                icon: const Icon(TeleposIcons.close, size: 18),
                onPressed: () => ref
                    .read(writeoffControllerProvider.notifier)
                    .removeProduct(p.ucode),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildTotalBar(WriteoffState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppLocalizations.of(context)!.supplyProducts(state.productCount),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            '${AppLocalizations.of(context)!.globalTotal}: ${state.totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(WriteoffState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '${AppLocalizations.of(context)!.supplyProducts(state.productCount)}  |  ',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          '${AppLocalizations.of(context)!.globalTotal}: ${state.totalAmount.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _reasonLabel(BuildContext context, WriteoffReason reason) =>
      switch (reason) {
        WriteoffReason.breakage => AppLocalizations.of(
          context,
        )!.writeoffReasonBreakage,
        WriteoffReason.expired => AppLocalizations.of(
          context,
        )!.writeoffReasonExpired,
        WriteoffReason.spoilage => AppLocalizations.of(
          context,
        )!.writeoffReasonDamage,
        WriteoffReason.loss => AppLocalizations.of(context)!.writeoffReasonLoss,
        WriteoffReason.other => AppLocalizations.of(
          context,
        )!.writeoffReasonOther,
      };

  void _onCancel(
    BuildContext context,
    WriteoffNotifier controller,
    WriteoffState state,
  ) {
    if (state.products.isEmpty) {
      controller.reset();
      context.go(AppRoutes.stockRegistry);
      return;
    }
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.writeoffCancelQuestion),
        content: Text(AppLocalizations.of(ctx)!.supplyDataLost),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(ctx)!.globalNo),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppLocalizations.of(ctx)!.globalYes),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && context.mounted) {
        controller.reset();
        context.go(AppRoutes.stockRegistry);
      }
    });
  }

  Future<void> _onSave(BuildContext context) async {
    final result = await ref.read(writeoffControllerProvider.notifier).save();
    if (context.mounted) {
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.writeoffSaved}. ${AppLocalizations.of(context)!.supplyProducts(result.productCount)}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        ref.read(writeoffControllerProvider.notifier).reset();
        context.go(AppRoutes.stockRegistry);
      }
    }
  }
}
