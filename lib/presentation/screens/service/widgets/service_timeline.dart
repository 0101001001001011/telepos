import 'package:flutter/material.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/domain/entities/service/service_mark_entity.dart';
import 'package:telepos/l10n/app_localizations.dart';

class ServiceTimeline extends StatelessWidget {
  const ServiceTimeline({
    required this.marks,
    this.onAdd,
    this.onDelete,
    this.onApproveMark,
    this.onRejectMark,
    this.canEdit = true,
    super.key,
  });

  final List<ServiceMarkEntity> marks;
  final VoidCallback? onAdd;
  final ValueChanged<int>? onDelete;
  final ValueChanged<int>? onApproveMark;
  final ValueChanged<int>? onRejectMark;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.serviceDetailTimeline,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (canEdit && onAdd != null)
                  TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(TeleposIcons.add, size: 18),
                    label: Text(l10n.serviceAddMark),
                  ),
              ],
            ),
            if (marks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    l10n.serviceNoOrders,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...marks.asMap().entries.map((entry) {
                final index = entry.key;
                final mark = entry.value;
                final isLast = index == marks.length - 1;
                return _TimelineItem(
                  mark: mark,
                  isLast: isLast,
                  onDelete: canEdit && onDelete != null && mark.id != null
                      ? () => onDelete!(mark.id!)
                      : null,
                  onApprove: onApproveMark != null && mark.id != null
                      ? () => onApproveMark!(mark.id!)
                      : null,
                  onReject: onRejectMark != null && mark.id != null
                      ? () => onRejectMark!(mark.id!)
                      : null,
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.mark,
    required this.isLast,
    this.onDelete,
    this.onApprove,
    this.onReject,
  });

  final ServiceMarkEntity mark;
  final bool isLast;
  final VoidCallback? onDelete;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final dateTime = DateTime.fromMillisecondsSinceEpoch(mark.createdAt * 1000);
    final timeStr =
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
    final dateStr =
        '${dateTime.day.toString().padLeft(2, '0')}.'
        '${dateTime.month.toString().padLeft(2, '0')}';

    final (icon, color) = _markTypeInfo(mark.markType);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 14, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: theme.dividerColor),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Opacity(
              opacity: mark.isRejected ? 0.5 : 1.0,
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _markTypeLabel(mark.markType, l10n),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (mark.isApproved && mark.approvalStatus == 1) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            TeleposIcons.checkCircle,
                            size: 14,
                            color: Colors.green,
                          ),
                        ],
                        const SizedBox(width: 8),
                        Text(
                          '$dateStr $timeStr',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        if (mark.cost != null)
                          Text(
                            '${mark.cost} ${l10n.currencySymbol}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: mark.isRejected
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        if (onDelete != null)
                          IconButton(
                            icon: const Icon(TeleposIcons.close, size: 16),
                            onPressed: onDelete,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 24,
                              minHeight: 24,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    if (mark.isPendingApproval) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.amber.shade700,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              l10n.svcPendingApproval,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.amber.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (onApprove != null)
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: IconButton(
                                icon: const Icon(TeleposIcons.check, size: 16),
                                color: Colors.green,
                                onPressed: onApprove,
                                padding: EdgeInsets.zero,
                                tooltip: l10n.svcApprove,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.green.withValues(
                                    alpha: 0.1,
                                  ),
                                ),
                              ),
                            ),
                          if (onReject != null) ...[
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: IconButton(
                                icon: const Icon(TeleposIcons.close, size: 16),
                                color: Colors.red,
                                onPressed: onReject,
                                padding: EdgeInsets.zero,
                                tooltip: l10n.svcReject,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.red.withValues(
                                    alpha: 0.1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (mark.isRejected) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.red.shade300,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          l10n.svcRejected,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    Text(mark.description, style: theme.textTheme.bodyMedium),
                    if (mark.productUcode != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ID: ${mark.productUcode}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (mark.note != null && mark.note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        mark.note!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _markTypeInfo(int markType) {
    return switch (markType) {
      0 => (Icons.search, Colors.blue),
      1 => (Icons.swap_horiz, Colors.orange),
      2 => (Icons.build_outlined, Colors.green),
      3 => (TeleposIcons.checkCircle, Colors.teal),
      5 => (Icons.handyman, Colors.deepPurple),
      _ => (Icons.note_outlined, Colors.grey),
    };
  }

  String _markTypeLabel(int markType, AppLocalizations l10n) {
    return switch (markType) {
      0 => l10n.serviceMarkDiagnostic,
      1 => l10n.serviceMarkReplacement,
      2 => l10n.serviceMarkRepair,
      3 => l10n.serviceMarkTesting,
      5 => l10n.serviceMarkConsumable,
      _ => l10n.serviceMarkOther,
    };
  }
}
