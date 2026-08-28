import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:telepos/l10n/app_localizations.dart';

class _ActionColors {
  _ActionColors._();
  static const bg = Color(0xFF0F0F23);
  static const divider = Color(0xFF2A2A4A);
  static const textPrimary = Color(0xFFE8E8F0);
  static const textMuted = Color(0xFF6B6B8D);
  static const payment = Color(0xFF2DBE60);
  static const preCheck = Color(0xFF3A7BFF);
  static const transfer = Color(0xFFFF8F00);
  static const split = Color(0xFF9C5BF5);
  static const merge = Color(0xFF26A69A);
  static const badgeBg = Color(0xFF3A7BFF);
}

class OrderActionBar extends StatelessWidget {
  const OrderActionBar({
    required this.total,
    required this.onPayment,
    required this.onTransfer,
    required this.onSplitBill,
    required this.onPrint,
    this.onMerge,
    this.itemCount = 0,
    super.key,
  });

  final Decimal total;
  final int itemCount;
  final VoidCallback onPayment;
  final VoidCallback onTransfer;
  final VoidCallback onSplitBill;
  final VoidCallback onPrint;

  final VoidCallback? onMerge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: _ActionColors.bg,
        border: Border(top: BorderSide(color: _ActionColors.divider, width: 1)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _ActionColors.badgeBg.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$itemCount',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _ActionColors.badgeBg,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.globalTotal,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _ActionColors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$total',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _ActionColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _ActionButton(
                    label: l10n.restaurantGoToPayment,
                    icon: Icons.payment_rounded,
                    color: _ActionColors.payment,
                    onTap: itemCount > 0 ? onPayment : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: '',
                    icon: Icons.receipt_long_outlined,
                    color: _ActionColors.preCheck,
                    onTap: onPrint,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: '',
                    icon: Icons.swap_horiz_rounded,
                    color: _ActionColors.transfer,
                    onTap: onTransfer,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: '',
                    icon: Icons.call_split_rounded,
                    color: _ActionColors.split,
                    onTap: onSplitBill,
                    compact: true,
                  ),
                ),
                if (onMerge != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      label: '',
                      icon: Icons.merge_type_rounded,
                      color: _ActionColors.merge,
                      onTap: onMerge,
                      compact: true,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final effectiveColor = enabled ? color : color.withValues(alpha: 0.3);

    return Material(
      color: effectiveColor.withValues(alpha: enabled ? 0.15 : 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: effectiveColor),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: effectiveColor,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
