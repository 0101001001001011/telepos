import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/domain/entities/restaurant/guest_split_entry.dart';
import 'package:telepos/domain/entities/restaurant/table_order_item.dart';
import 'package:telepos/domain/usecases/restaurant/split_bill_use_case.dart';
import 'package:telepos/l10n/app_localizations.dart';

class SplitBillResult {
  const SplitBillResult({
    required this.mode,
    required this.splitCount,
    required this.amountPerGuest,
    required this.total,
  });

  final String mode;

  final int splitCount;

  final Decimal amountPerGuest;

  final Decimal total;

  bool get isEven => mode == 'even';
}

class SplitBillDialog extends ConsumerStatefulWidget {
  const SplitBillDialog({
    required this.orderId,
    required this.items,
    required this.total,
    required this.guestCount,
    super.key,
  });

  final int orderId;
  final List<TableOrderItem> items;
  final Decimal total;
  final int guestCount;

  @override
  ConsumerState<SplitBillDialog> createState() => _SplitBillDialogState();
}

class _SplitBillDialogState extends ConsumerState<SplitBillDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _splitCount;

  late Map<int, int> _itemAssignments;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _splitCount = widget.guestCount > 1 ? widget.guestCount : 2;
    _itemAssignments = {};
    for (int i = 0; i < widget.items.length; i++) {
      final gn = widget.items[i].guestNumber;
      _itemAssignments[i] = gn > 0 ? gn : 1;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Decimal get _perGuest {
    if (_splitCount <= 0) return widget.total;
    final hundred = Decimal.fromInt(100);
    final totalCents = (widget.total * hundred).toBigInt();
    final baseCents = totalCents ~/ BigInt.from(_splitCount);
    return (Decimal.fromBigInt(baseCents) / hundred).toDecimal();
  }

  Future<void> _applyEvenSplit() async {
    try {
      await GetIt.I<SplitBillUseCase>().splitEvenly(
        widget.orderId,
        _splitCount,
      );
      if (mounted) {
        Navigator.pop(
          context,
          SplitBillResult(
            mode: 'even',
            splitCount: _splitCount,
            amountPerGuest: _perGuest,
            total: widget.total,
          ),
        );
      }
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

  Future<void> _applyItemSplit() async {
    try {
      final splits = <GuestSplitEntry>[];
      for (final entry in _itemAssignments.entries) {
        final item = widget.items[entry.key];
        splits.add(
          GuestSplitEntry(
            orderId: widget.orderId,
            guestNumber: entry.value,
            saleProductId: item.productId,
            shareQuantity: item.quantity,
          ),
        );
      }
      await GetIt.I<SplitBillUseCase>().splitByItems(widget.orderId, splits);
      if (mounted) {
        Navigator.pop(
          context,
          SplitBillResult(
            mode: 'by_items',
            splitCount: _splitCount,
            amountPerGuest: widget.total,
            total: widget.total,
          ),
        );
      }
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

    return AlertDialog(
      title: Text(l10n.restaurantSplitTitle),
      content: SizedBox(
        width: 420,
        height: 400,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              tabs: [
                Tab(text: l10n.restaurantSplitEvenly),
                Tab(text: l10n.restaurantSplitByItems),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildEvenTab(l10n), _buildByItemsTab(l10n)],
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
        FilledButton(
          onPressed: () {
            if (_tabController.index == 0) {
              _applyEvenSplit();
            } else {
              _applyItemSplit();
            }
          },
          child: Text(l10n.restaurantSplitApply),
        ),
      ],
    );
  }

  Widget _buildEvenTab(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.restaurantSplitGuestCount,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.outlined(
                icon: const Icon(Icons.remove),
                onPressed: _splitCount > 2
                    ? () => setState(() => _splitCount--)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '$_splitCount',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton.outlined(
                icon: const Icon(TeleposIcons.add),
                onPressed: _splitCount < 50
                    ? () => setState(() => _splitCount++)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${l10n.globalTotal}:',
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                '${widget.total}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.restaurantSplitPerGuest(''),
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                '$_perGuest',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildByItemsTab(AppLocalizations l10n) {
    if (widget.items.isEmpty) {
      return Center(child: Text(l10n.restaurantNoItems));
    }

    final guestOptions = List.generate(_splitCount, (i) => i + 1);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: widget.items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final assigned = _itemAssignments[index] ?? 1;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'x${item.quantity}  ${item.lineTotal}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: assigned,
                isDense: true,
                underline: Container(height: 1, color: AppColors.primary),
                items: guestOptions
                    .map(
                      (g) => DropdownMenuItem(
                        value: g,
                        child: Text(
                          l10n.restaurantSplitGuest(g),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _itemAssignments[index] = v);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
