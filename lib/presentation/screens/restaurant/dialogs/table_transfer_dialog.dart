import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/core/constants/enums/table_status.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/restaurant/transfer_table_use_case.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';

class TableTransferDialog extends ConsumerStatefulWidget {
  const TableTransferDialog({
    required this.currentTableId,
    required this.currentTableName,
    required this.orderId,
    super.key,
  });

  final int currentTableId;
  final String currentTableName;
  final int orderId;

  @override
  ConsumerState<TableTransferDialog> createState() =>
      _TableTransferDialogState();
}

class _TableTransferDialogState extends ConsumerState<TableTransferDialog> {
  List<RestaurantTable> _freeTables = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFreeTables();
  }

  Future<void> _loadFreeTables() async {
    try {
      final db = GetIt.I<AppDatabase>();
      final allTables = await db.restaurantTableDao.getActive();
      setState(() {
        _freeTables = allTables
            .where(
              (t) =>
                  t.id != widget.currentTableId &&
                  t.status == TableStatus.free.index,
            )
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[TableTransfer] Failed to load free tables: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _transfer(int newTableId) async {
    try {
      await GetIt.I<TransferTableUseCase>().transfer(
        widget.orderId,
        newTableId,
      );
      if (mounted) Navigator.pop(context, newTableId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final layoutType = Breakpoints.fromWidth(width);
    final crossAxisCount = switch (layoutType) {
      LayoutType.desktop => 4,
      LayoutType.tablet => 3,
      LayoutType.mobile => 2,
    };

    return AlertDialog(
      title: Text(l10n.restaurantTransferTitle),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.restaurantTransferCurrent(widget.currentTableName),
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.restaurantTransferSelectFree,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _freeTables.isEmpty
                  ? Center(
                      child: Text(
                        l10n.restaurantNoTables,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: _freeTables.length,
                      itemBuilder: (context, index) {
                        final table = _freeTables[index];
                        return _buildFreeTableCard(table);
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.globalCancel),
        ),
      ],
    );
  }

  Widget _buildFreeTableCard(RestaurantTable table) {
    return InkWell(
      onTap: () => _transfer(table.id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4CAF50), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              table.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (table.zone != null) ...[
              const SizedBox(height: 4),
              Text(
                table.zone!,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
