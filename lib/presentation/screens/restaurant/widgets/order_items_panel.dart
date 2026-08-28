import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/domain/entities/restaurant/table_order_item.dart';
import 'package:telepos/l10n/app_localizations.dart';

class _DarkTheme {
  _DarkTheme._();
  static const textPrimary = Color(0xFFE8E8F0);
  static const textSecondary = Color(0xFF9898B8);
  static const textMuted = Color(0xFF6B6B8D);
  static const divider = Color(0xFF2A2A4A);
  static const selectedStripe = Color(0xFF3A7BFF);
  static const selectedBg = Color(0xFF1E2245);
  static const qtyBadge = Color(0xFF3A7BFF);
  static const qtyBadgeText = Color(0xFFFFFFFF);
  static const deleteBg = Color(0xFFE53935);
  static const guestHeader = Color(0xFF16213E);
  static const qtyButton = Color(0xFF252545);
  static const qtyButtonIcon = Color(0xFFB0B0D0);
}

class OrderItemsPanel extends StatefulWidget {
  const OrderItemsPanel({
    required this.items,
    required this.guestCount,
    required this.selectedGuest,
    required this.onRemove,
    required this.onUpdateQuantity,
    super.key,
  });

  final List<TableOrderItem> items;
  final int guestCount;
  final int selectedGuest;
  final void Function(int saleProductId) onRemove;
  final void Function(int saleProductId, Decimal newQty) onUpdateQuantity;

  @override
  State<OrderItemsPanel> createState() => _OrderItemsPanelState();
}

class _OrderItemsPanelState extends State<OrderItemsPanel> {
  int? _selectedItemId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (widget.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: _DarkTheme.textMuted,
            ),
            const SizedBox(height: 10),
            Text(
              l10n.restaurantAddItems,
              style: const TextStyle(color: _DarkTheme.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (widget.selectedGuest > 0) {
      return _buildItemsList(widget.items, l10n);
    }

    final grouped = <int, List<TableOrderItem>>{};
    for (final item in widget.items) {
      grouped.putIfAbsent(item.guestNumber, () => []).add(item);
    }

    final sortedKeys = grouped.keys.toList()..sort();

    if (widget.guestCount <= 1) {
      return _buildItemsList(widget.items, l10n);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final guest = sortedKeys[index];
        final guestItems = grouped[guest]!;
        final guestLabel = guest == 0
            ? l10n.globalAll
            : l10n.restaurantSplitGuest(guest);

        return _GuestSection(
          label: guestLabel,
          items: guestItems,
          selectedItemId: _selectedItemId,
          onSelectItem: (id) => setState(() {
            _selectedItemId = _selectedItemId == id ? null : id;
          }),
          onRemove: widget.onRemove,
          onUpdateQuantity: widget.onUpdateQuantity,
        );
      },
    );
  }

  Widget _buildItemsList(List<TableOrderItem> items, AppLocalizations l10n) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      itemCount: items.length,
      itemBuilder: (context, index) => _OrderItemTile(
        item: items[index],
        isSelected:
            _selectedItemId ==
            (items[index].saleProductId ?? items[index].productId),
        onTap: () {
          final id = items[index].saleProductId ?? items[index].productId;
          setState(() {
            _selectedItemId = _selectedItemId == id ? null : id;
          });
        },
        onRemove: widget.onRemove,
        onUpdateQuantity: widget.onUpdateQuantity,
      ),
    );
  }
}

class _GuestSection extends StatefulWidget {
  const _GuestSection({
    required this.label,
    required this.items,
    required this.selectedItemId,
    required this.onSelectItem,
    required this.onRemove,
    required this.onUpdateQuantity,
  });

  final String label;
  final List<TableOrderItem> items;
  final int? selectedItemId;
  final ValueChanged<int> onSelectItem;
  final void Function(int saleProductId) onRemove;
  final void Function(int saleProductId, Decimal newQty) onUpdateQuantity;

  @override
  State<_GuestSection> createState() => _GuestSectionState();
}

class _GuestSectionState extends State<_GuestSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: _DarkTheme.guestHeader,
            child: Row(
              children: [
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 18,
                  color: _DarkTheme.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _DarkTheme.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _DarkTheme.divider,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.items.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: _DarkTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...widget.items.map(
            (item) => _OrderItemTile(
              item: item,
              isSelected:
                  widget.selectedItemId ==
                  (item.saleProductId ?? item.productId),
              onTap: () =>
                  widget.onSelectItem(item.saleProductId ?? item.productId),
              onRemove: widget.onRemove,
              onUpdateQuantity: widget.onUpdateQuantity,
            ),
          ),
      ],
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  const _OrderItemTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onRemove,
    required this.onUpdateQuantity,
  });

  final TableOrderItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final void Function(int saleProductId) onRemove;
  final void Function(int saleProductId, Decimal newQty) onUpdateQuantity;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.saleProductId ?? item.productId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: _DarkTheme.deleteBg),
        child: const Icon(TeleposIcons.delete, color: Colors.white, size: 22),
      ),
      onDismissed: (_) {
        if (item.saleProductId != null) onRemove(item.saleProductId!);
      },
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? _DarkTheme.selectedBg : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isSelected
                    ? _DarkTheme.selectedStripe
                    : Colors.transparent,
                width: 3,
              ),
              bottom: BorderSide(
                color: _DarkTheme.divider.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _DarkTheme.qtyBadge
                          : _DarkTheme.qtyBadge.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${item.quantity}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? _DarkTheme.qtyBadgeText
                            : _DarkTheme.qtyBadge,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _DarkTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${item.lineTotal}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _DarkTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              if (isSelected && item.saleProductId != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildQtyButton(
                      icon: Icons.remove,
                      onTap: () => onUpdateQuantity(
                        item.saleProductId!,
                        item.quantity - Decimal.one,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _DarkTheme.textPrimary,
                        ),
                      ),
                    ),
                    _buildQtyButton(
                      icon: TeleposIcons.add,
                      onTap: () => onUpdateQuantity(
                        item.saleProductId!,
                        item.quantity + Decimal.one,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'x ${item.price}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _DarkTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQtyButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _DarkTheme.qtyButton,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, size: 20, color: _DarkTheme.qtyButtonIcon),
        ),
      ),
    );
  }
}
