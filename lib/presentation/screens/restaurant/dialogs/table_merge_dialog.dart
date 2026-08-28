import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/constants/enums/table_status.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/restaurant/merge_tables_use_case.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';

class TableMergeDialog extends ConsumerStatefulWidget {
  const TableMergeDialog({
    required this.targetTableId,
    required this.targetTableName,
    required this.targetOrderId,
    super.key,
  });

  final int targetTableId;
  final String targetTableName;

  final int targetOrderId;

  @override
  ConsumerState<TableMergeDialog> createState() => _TableMergeDialogState();
}

class _OccupiedOrder {
  const _OccupiedOrder({
    required this.tableId,
    required this.tableName,
    required this.orderId,
    this.zone,
  });

  final int tableId;
  final String tableName;
  final int orderId;
  final String? zone;
}

class _TableMergeDialogState extends ConsumerState<TableMergeDialog> {
  List<_OccupiedOrder> _sources = [];
  final Set<int> _selectedOrderIds = {};
  bool _isLoading = true;
  bool _merging = false;

  @override
  void initState() {
    super.initState();
    _loadOccupiedTables();
  }

  Future<void> _loadOccupiedTables() async {
    try {
      final db = GetIt.I<AppDatabase>();
      final allTables = await db.restaurantTableDao.getActive();
      final occupied = allTables
          .where(
            (t) =>
                t.id != widget.targetTableId &&
                t.status == TableStatus.occupied.index,
          )
          .toList();

      final sources = <_OccupiedOrder>[];
      for (final t in occupied) {
        final order = await db.restaurantOrderDao.findOpenByTable(t.id);
        if (order != null && order.id != widget.targetOrderId) {
          sources.add(
            _OccupiedOrder(
              tableId: t.id,
              tableName: t.name,
              orderId: order.id,
              zone: t.zone,
            ),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _sources = sources;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[TableMerge] Failed to load occupied tables: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _merge(AppLocalizations l10n) async {
    if (_selectedOrderIds.isEmpty || _merging) return;
    setState(() => _merging = true);
    try {
      final orderIds = <int>[widget.targetOrderId, ..._selectedOrderIds];
      await GetIt.I<MergeTablesUseCase>().merge(orderIds, widget.targetTableId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _merging = false);
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
      title: Text(l10n.restaurantMergeTitle),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.restaurantMergeTarget(widget.targetTableName),
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.restaurantMergeSelectSources,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _sources.isEmpty
                  ? Center(
                      child: Text(
                        l10n.restaurantMergeNoOpenTables,
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
                      itemCount: _sources.length,
                      itemBuilder: (context, index) {
                        final src = _sources[index];
                        final selected = _selectedOrderIds.contains(
                          src.orderId,
                        );
                        return _buildSourceCard(src, selected);
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _merging ? null : () => Navigator.pop(context),
          child: Text(l10n.globalCancel),
        ),
        ElevatedButton(
          onPressed: _selectedOrderIds.isEmpty || _merging
              ? null
              : () => _merge(l10n),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
          ),
          child: _merging
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
              : Text(l10n.restaurantMergeConfirm(_selectedOrderIds.length)),
        ),
      ],
    );
  }

  Widget _buildSourceCard(_OccupiedOrder src, bool selected) {
    return InkWell(
      onTap: () {
        setState(() {
          if (selected) {
            _selectedOrderIds.remove(src.orderId);
          } else {
            _selectedOrderIds.add(src.orderId);
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE3F2FD) : const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFFF8F00),
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected)
              const Icon(
                TeleposIcons.checkCircle,
                size: 18,
                color: AppColors.primary,
              ),
            Text(
              src.tableName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (src.zone != null) ...[
              const SizedBox(height: 4),
              Text(
                src.zone!,
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
