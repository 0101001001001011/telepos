import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/domain/entities/wms/cell_stock_entity.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/wms/cell_stock_controller.dart';

class CellStockScreen extends ConsumerStatefulWidget {
  const CellStockScreen({super.key});

  @override
  ConsumerState<CellStockScreen> createState() => _CellStockScreenState();
}

enum _ViewMode { byCell, byProduct }

class _CellStockScreenState extends ConsumerState<CellStockScreen> {
  _ViewMode _viewMode = _ViewMode.byCell;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stockState = ref.watch(cellStockControllerProvider);
    final layout = Breakpoints.of(context);

    if (stockState.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorLocalizer.localize(context, stockState.error!)),
          ),
        );
      });
    }

    if (layout.isDesktop) {
      return _buildDesktopLayout(stockState);
    }
    return _buildMobileLayout(stockState);
  }

  Widget _buildMobileLayout(CellStockState stockState) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.wmsCellStockTitle),
        actions: [
          if (stockState.isLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildModeSelector(),
          _buildSearchBar(),
          const Divider(height: 1),
          Expanded(child: _buildStockList(stockState)),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildDesktopLayout(CellStockState stockState) {
    final l10n = AppLocalizations.of(context)!;
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
                l10n.wmsCellStockTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (stockState.isLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              FilledButton.icon(
                onPressed: _showPlaceDialog,
                icon: const Icon(Icons.add_location_alt),
                label: Text(l10n.wmsPlace),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _showPickDialog,
                icon: const Icon(Icons.remove_circle_outline),
                label: Text(l10n.wmsPick),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _showTransferDialog,
                icon: const Icon(Icons.swap_horiz),
                label: Text(l10n.wmsTransfer),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildModeSelector(),
              const SizedBox(width: 16),
              Expanded(child: _buildSearchBar()),
            ],
          ),
          const SizedBox(height: 16),
          _buildStockTable(stockState),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<_ViewMode>(
        segments: [
          ButtonSegment(
            value: _ViewMode.byCell,
            label: Text(l10n.wmsByCell),
            icon: const Icon(Icons.grid_view),
          ),
          ButtonSegment(
            value: _ViewMode.byProduct,
            label: Text(l10n.wmsByProduct),
            icon: const Icon(Icons.category),
          ),
        ],
        selected: {_viewMode},
        onSelectionChanged: (selected) {
          setState(() {
            _viewMode = selected.first;
            _searchController.clear();
          });
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    final l10n = AppLocalizations.of(context)!;
    final hintText = _viewMode == _ViewMode.byCell
        ? l10n.wmsSearchCellHint
        : l10n.wmsSearchProductHint;
    final labelText = _viewMode == _ViewMode.byCell
        ? l10n.wmsCell
        : l10n.wmsProductUcode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: _searchController,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          suffixIcon: IconButton(
            icon: const Icon(Icons.send),
            onPressed: _performSearch,
            tooltip: l10n.wmsFind,
          ),
        ),
        onSubmitted: (_) => _performSearch(),
      ),
    );
  }

  Widget _buildStockList(CellStockState stockState) {
    final l10n = AppLocalizations.of(context)!;
    final items = stockState.stockItems;
    if (items.isEmpty && !stockState.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              _viewMode == _ViewMode.byCell
                  ? l10n.wmsEnterCellIdToSearch
                  : l10n.wmsEnterUcodeToSearch,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => _buildStockCard(items[index]),
    );
  }

  Widget _buildStockCard(CellStockEntity item) {
    final l10n = AppLocalizations.of(context)!;
    final qty = item.quantity?.toString() ?? '0';
    final reserved = item.reservedQty?.toString() ?? '0';
    final available = item.availableQty.toString();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withValues(alpha: 0.2),
          child: const Icon(Icons.inventory_2, color: Colors.blue, size: 20),
        ),
        title: _viewMode == _ViewMode.byCell
            ? Text(l10n.wmsProductLabeled('${item.ucode ?? '-'}'))
            : Text(l10n.wmsCellLabeled('${item.cellId ?? '-'}')),
        subtitle: Text(
          l10n.wmsStockSummary(qty, reserved, available) +
              (item.batchId != null
                  ? '  |  ${l10n.wmsBatchLabeled('${item.batchId}')}'
                  : ''),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            available,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.success,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockTable(CellStockState stockState) {
    final l10n = AppLocalizations.of(context)!;
    final items = stockState.stockItems;
    if (items.isEmpty && !stockState.isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _viewMode == _ViewMode.byCell
                ? l10n.wmsEnterCellIdToSearch
                : l10n.wmsEnterUcodeToSearch,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          if (_viewMode == _ViewMode.byProduct)
            DataColumn(label: Text(l10n.wmsCell)),
          if (_viewMode == _ViewMode.byCell)
            DataColumn(label: Text(l10n.wmsProductUcode)),
          DataColumn(label: Text(l10n.wmsQuantityShort), numeric: true),
          DataColumn(label: Text(l10n.wmsReserved), numeric: true),
          DataColumn(label: Text(l10n.wmsAvailable), numeric: true),
          DataColumn(label: Text(l10n.wmsBatch)),
        ],
        rows: items.map((item) {
          return DataRow(
            cells: [
              if (_viewMode == _ViewMode.byProduct)
                DataCell(Text('${item.cellId ?? '-'}')),
              if (_viewMode == _ViewMode.byCell)
                DataCell(Text('${item.ucode ?? '-'}')),
              DataCell(Text('${item.quantity ?? '0'}')),
              DataCell(Text('${item.reservedQty ?? '0'}')),
              DataCell(Text(item.availableQty.toString())),
              DataCell(Text('${item.batchId ?? '-'}')),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFab() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'transfer',
          onPressed: _showTransferDialog,
          tooltip: l10n.wmsTransfer,
          child: const Icon(Icons.swap_horiz),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'pick',
          onPressed: _showPickDialog,
          tooltip: l10n.wmsPick,
          child: const Icon(Icons.remove_circle_outline),
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          heroTag: 'place',
          onPressed: _showPlaceDialog,
          tooltip: l10n.wmsPlace,
          child: const Icon(Icons.add_location_alt),
        ),
      ],
    );
  }

  void _performSearch() {
    final value = _searchController.text.trim();
    final id = int.tryParse(value);
    if (id == null) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.wmsEnterNumericId)));
      return;
    }

    final notifier = ref.read(cellStockControllerProvider.notifier);
    if (_viewMode == _ViewMode.byCell) {
      notifier.loadStockByCell(id);
    } else {
      notifier.loadStockByProduct(id);
    }
  }

  void _showPlaceDialog() {
    final l10n = AppLocalizations.of(context)!;
    final cellIdCtrl = TextEditingController();
    final ucodeCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final batchIdCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.wmsPlaceStockTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: cellIdCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.wmsCellId),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ucodeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.wmsProductUcodeField,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: l10n.wmsQuantity),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: batchIdCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.wmsBatchIdOptional),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.globalCancel),
          ),
          FilledButton(
            onPressed: () async {
              final cellId = int.tryParse(cellIdCtrl.text.trim());
              final ucode = int.tryParse(ucodeCtrl.text.trim());
              final qty = Decimal.tryParse(qtyCtrl.text.trim());
              final batchId = int.tryParse(batchIdCtrl.text.trim());

              if (cellId == null || ucode == null || qty == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(l10n.wmsFillRequiredNumericFields)),
                );
                return;
              }

              Navigator.of(ctx).pop();
              final result = await ref
                  .read(cellStockControllerProvider.notifier)
                  .placeStock(
                    cellId: cellId,
                    ucode: ucode,
                    quantity: qty,
                    batchId: batchId,
                  );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result.success
                          ? l10n.wmsStockPlaced('$cellId')
                          : result.errorMessage ?? l10n.wmsPlaceError,
                    ),
                  ),
                );
              }
            },
            child: Text(l10n.wmsPlace),
          ),
        ],
      ),
    );
  }

  void _showPickDialog() {
    final l10n = AppLocalizations.of(context)!;
    final cellIdCtrl = TextEditingController();
    final ucodeCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.wmsPickStockTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: cellIdCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.wmsCellId),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ucodeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.wmsProductUcodeField,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: l10n.wmsQuantity),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.globalCancel),
          ),
          FilledButton(
            onPressed: () async {
              final cellId = int.tryParse(cellIdCtrl.text.trim());
              final ucode = int.tryParse(ucodeCtrl.text.trim());
              final qty = Decimal.tryParse(qtyCtrl.text.trim());

              if (cellId == null || ucode == null || qty == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(l10n.wmsFillAllNumericFields)),
                );
                return;
              }

              Navigator.of(ctx).pop();
              final result = await ref
                  .read(cellStockControllerProvider.notifier)
                  .pickStock(cellId: cellId, ucode: ucode, quantity: qty);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result.success
                          ? l10n.wmsStockPicked('$cellId')
                          : result.errorMessage ?? l10n.wmsPickError,
                    ),
                  ),
                );
              }
            },
            child: Text(l10n.wmsPick),
          ),
        ],
      ),
    );
  }

  void _showTransferDialog() {
    final l10n = AppLocalizations.of(context)!;
    final fromCellIdCtrl = TextEditingController();
    final toCellIdCtrl = TextEditingController();
    final ucodeCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.wmsTransferStockTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fromCellIdCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.wmsCellIdFrom),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: toCellIdCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.wmsCellIdTo),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ucodeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.wmsProductUcodeField,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: l10n.wmsQuantity),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.globalCancel),
          ),
          FilledButton(
            onPressed: () async {
              final fromCellId = int.tryParse(fromCellIdCtrl.text.trim());
              final toCellId = int.tryParse(toCellIdCtrl.text.trim());
              final ucode = int.tryParse(ucodeCtrl.text.trim());
              final qty = Decimal.tryParse(qtyCtrl.text.trim());

              if (fromCellId == null ||
                  toCellId == null ||
                  ucode == null ||
                  qty == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(l10n.wmsFillAllNumericFields)),
                );
                return;
              }

              Navigator.of(ctx).pop();
              final result = await ref
                  .read(cellStockControllerProvider.notifier)
                  .transferStock(
                    fromCellId: fromCellId,
                    toCellId: toCellId,
                    ucode: ucode,
                    quantity: qty,
                  );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result.success
                          ? l10n.wmsStockTransferred('$fromCellId', '$toCellId')
                          : result.errorMessage ?? l10n.wmsTransferError,
                    ),
                  ),
                );
              }
            },
            child: Text(l10n.wmsTransfer),
          ),
        ],
      ),
    );
  }
}
