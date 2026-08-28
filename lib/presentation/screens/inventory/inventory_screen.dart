import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/common/widgets/keyboards/num_pad.dart';
import 'package:telepos/presentation/controllers/inventory/inventory_controller.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _barcodeController = TextEditingController();

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryControllerProvider);
    final controller = ref.read(inventoryControllerProvider.notifier);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1200;

    if (isDesktop) {
      return _buildDesktopLayout(state, controller);
    }

    return _buildMobileLayout(state, controller);
  }

  Widget _buildMobileLayout(
    InventoryState state,
    InventoryNotifier controller,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.inventoryTitle),
        actions: [
          if (!state.isActive)
            TextButton(
              onPressed: () => controller.startNew(),
              child: Text(
                AppLocalizations.of(context)!.inventoryStart,
                style: const TextStyle(color: Colors.white),
              ),
            )
          else
            TextButton(
              onPressed: state.canComplete ? () => _onComplete(context) : null,
              child: Text(
                AppLocalizations.of(context)!.inventoryFinish,
                style: TextStyle(
                  color: state.canComplete ? Colors.white : Colors.white54,
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
          if (state.isActive) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _barcodeController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.inventoryScanHint,
                  prefixIcon: const Icon(Icons.qr_code_scanner),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    controller.scanProduct(value);
                    _barcodeController.clear();
                  }
                },
              ),
            ),
            Expanded(
              child: state.products.isEmpty
                  ? Center(
                      child: Text(
                        AppLocalizations.of(context)!.inventoryScanProducts,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: state.products.length,
                      itemBuilder: (context, index) {
                        final p = state.products[index];
                        return _buildProductCard(p, controller);
                      },
                    ),
            ),
          ] else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.inventoryPressStart,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: _buildCountModeToggle(context, state, controller),
                    ),
                  ],
                ),
              ),
            ),
          if (state.products.isNotEmpty)
            Container(
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
                    AppLocalizations.of(
                      context,
                    )!.inventoryProductCount(state.productCount),
                  ),
                  Text(
                    AppLocalizations.of(
                      context,
                    )!.inventoryDiscrepancies(state.discrepancyCount),
                    style: TextStyle(
                      color: state.discrepancyCount > 0
                          ? Theme.of(context).colorScheme.error
                          : AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(
    InventoryState state,
    InventoryNotifier controller,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory, size: 28),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.inventoryTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (!state.isActive)
                ElevatedButton.icon(
                  onPressed: () => controller.startNew(),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(AppLocalizations.of(context)!.inventoryStart),
                )
              else ...[
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _barcodeController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.inventoryScanHint,
                      prefixIcon: const Icon(Icons.qr_code_scanner),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        controller.scanProduct(value);
                        _barcodeController.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: state.canComplete
                      ? () => _onComplete(context)
                      : null,
                  icon: const Icon(TeleposIcons.check),
                  label: Text(AppLocalizations.of(context)!.inventoryFinish),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          if (state.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
              child: Text(
                ErrorLocalizer.localize(context, state.error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (state.products.isNotEmpty) ...[
            _buildProductsTable(state, controller),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${AppLocalizations.of(context)!.inventoryProductCount(state.productCount)}  |  ',
                ),
                Text(
                  AppLocalizations.of(
                    context,
                  )!.inventoryDiscrepancies(state.discrepancyCount),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: state.discrepancyCount > 0
                        ? Theme.of(context).colorScheme.error
                        : AppColors.success,
                  ),
                ),
              ],
            ),
          ] else if (state.isActive)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Text(
                  AppLocalizations.of(context)!.inventoryScanProducts,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.inventoryPressStart,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: _buildCountModeToggle(context, state, controller),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCountModeToggle(
    BuildContext context,
    InventoryState state,
    InventoryNotifier controller,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: state.isFullCount,
      onChanged: state.isActive
          ? null
          : (value) => controller.setFullCount(value),
      title: Text(l10n.inventoryFullCount),
      subtitle: Text(
        l10n.inventoryFullCountSubtitle,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildProductCard(
    InventoryProductItem product,
    InventoryNotifier controller,
  ) {
    final diffColor = product.difference > Decimal.zero
        ? AppColors.success
        : product.difference < Decimal.zero
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(product.name),
        subtitle: Text(
          '${AppLocalizations.of(context)!.inventoryExpected}: ${product.expectedQty}  |  ${AppLocalizations.of(context)!.inventoryActual}: ${product.actualQty}',
        ),
        trailing: Text(
          product.difference > Decimal.zero
              ? '+${product.difference}'
              : '${product.difference}',
          style: TextStyle(
            color: diffColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onTap: () => _showEditQtyDialog(product, controller),
      ),
    );
  }

  Widget _buildProductsTable(
    InventoryState state,
    InventoryNotifier controller,
  ) {
    return DataTable(
      columns: [
        DataColumn(label: Text(AppLocalizations.of(context)!.inventoryProduct)),
        DataColumn(
          label: Text(AppLocalizations.of(context)!.inventoryExpectedQty),
          numeric: true,
        ),
        DataColumn(
          label: Text(AppLocalizations.of(context)!.inventoryActualQty),
          numeric: true,
        ),
        DataColumn(
          label: Text(AppLocalizations.of(context)!.inventoryDiscrepancy),
          numeric: true,
        ),
      ],
      rows: state.products.map((p) {
        final diffColor = p.difference > Decimal.zero
            ? AppColors.success
            : p.difference < Decimal.zero
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.onSurface;

        return DataRow(
          cells: [
            DataCell(
              Text(p.name),
              onTap: () => _showEditQtyDialog(p, controller),
            ),
            DataCell(Text(p.expectedQty.toString())),
            DataCell(Text(p.actualQty.toString())),
            DataCell(
              Text(
                p.difference > Decimal.zero
                    ? '+${p.difference}'
                    : '${p.difference}',
                style: TextStyle(color: diffColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  void _showEditQtyDialog(
    InventoryProductItem product,
    InventoryNotifier controller,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _EditQtyDialog(
        product: product,
        onSave: (qty) => controller.setActualQty(product.ucode, qty),
      ),
    );
  }

  Future<void> _onComplete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.inventoryFinishQuestion),
        content: Text(
          AppLocalizations.of(ctx)!.inventoryDiscrepancies(
            ref.read(inventoryControllerProvider).discrepancyCount,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(ctx)!.globalCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppLocalizations.of(ctx)!.inventoryFinish),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final result = await ref
          .read(inventoryControllerProvider.notifier)
          .complete();
      if (result.success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.inventoryCompleted}. ${AppLocalizations.of(context)!.inventoryProductCount(result.productCount)}, '
              '${AppLocalizations.of(context)!.inventoryDiscrepancies(result.discrepancyCount)}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        ref.read(inventoryControllerProvider.notifier).reset();
      }
    }
  }
}

class _EditQtyDialog extends StatefulWidget {
  const _EditQtyDialog({required this.product, required this.onSave});

  final InventoryProductItem product;
  final void Function(Decimal qty) onSave;

  @override
  State<_EditQtyDialog> createState() => _EditQtyDialogState();
}

class _EditQtyDialogState extends State<_EditQtyDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.product.actualQty.toString(),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final qty = Decimal.tryParse(_controller.text);
    if (qty != null) {
      widget.onSave(qty);
    }
    Navigator.of(context).pop();
  }

  void _onKey(String d) {
    final text = _controller.text == '0' ? '' : _controller.text;
    _controller.text = text + d;
  }

  void _onDot() {
    if (_controller.text.contains('.')) return;
    final base = _controller.text.isEmpty ? '0' : _controller.text;
    _controller.text = '$base.';
  }

  void _onBackspace() {
    final t = _controller.text;
    if (t.isEmpty) return;
    _controller.text = t.substring(0, t.length - 1);
  }

  void _onClear() => _controller.clear();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            readOnly: true,
            showCursor: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.inventoryActualLabel,
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          NumPad(
            buttonSize: 48,
            spacing: 8,
            showEnter: true,
            onKeyPressed: _onKey,
            onBackspace: _onBackspace,
            onClear: _onClear,
            onEnter: _save,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 168,
            child: OutlinedButton(
              onPressed: _onDot,
              child: const Text('.', style: TextStyle(fontSize: 20)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.globalCancel),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(AppLocalizations.of(context)!.globalOk),
        ),
      ],
    );
  }
}
