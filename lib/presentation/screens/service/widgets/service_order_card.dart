import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/constants/enums/service_order_status.dart';
import 'package:telepos/domain/entities/service/service_order_entity.dart';
import 'package:telepos/l10n/app_localizations.dart';

class ServiceOrderCard extends StatelessWidget {
  const ServiceOrderCard({
    required this.order,
    this.onTap,
    this.needsApproval = false,
    super.key,
  });

  final ServiceOrderEntity order;
  final VoidCallback? onTap;
  final bool needsApproval;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final intakeDate = DateTime.fromMillisecondsSinceEpoch(
      order.intakeTime * 1000,
    );
    final dateStr =
        '${intakeDate.day.toString().padLeft(2, '0')}.'
        '${intakeDate.month.toString().padLeft(2, '0')}.'
        '${intakeDate.year}';
    final timeStr =
        '${intakeDate.hour.toString().padLeft(2, '0')}:'
        '${intakeDate.minute.toString().padLeft(2, '0')}';

    final statusColor = _statusColor(order.status);
    final statusLabel = _statusLabel(order.status, l10n);
    final statusIcon = _statusIcon(order.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(color: statusColor),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#${order.orderNumber}',
                              style: context.styles.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                fontFamily: 'TeleposMono',
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$dateStr  $timeStr',
                            style: context.styles.caption.copyWith(
                              fontSize: 11,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 12, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (needsApproval) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.notifications_active,
                                    size: 12,
                                    color: Colors.amber.shade800,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '!',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.amber.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.primary.withValues(
                              alpha: 0.08,
                            ),
                            child: Text(
                              _initials(order.clientDisplayName),
                              style: context.styles.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.clientDisplayName,
                                  style: AppTextStyles.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (order.deviceDescription != null &&
                                    order.deviceDescription!.isNotEmpty)
                                  Text(
                                    order.deviceDescription!,
                                    style: context.styles.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),

                          if (order.estimatedAmount != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${order.estimatedAmount}',
                                  style: AppTextStyles.body.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  l10n.currencySymbol,
                                  style: context.styles.caption.copyWith(
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),

                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),

                      if (order.isInProgress) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: null,
                            minHeight: 2,
                            backgroundColor: statusColor.withValues(alpha: 0.1),
                            color: statusColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color _statusColor(ServiceOrderStatus status) {
    return switch (status) {
      ServiceOrderStatus.intake => Colors.blue,
      ServiceOrderStatus.inProgress => Colors.orange,
      ServiceOrderStatus.completed => Colors.green,
      ServiceOrderStatus.closed => Colors.grey,
      ServiceOrderStatus.cancelled => Colors.red,
    };
  }

  String _statusLabel(ServiceOrderStatus status, AppLocalizations l10n) {
    return switch (status) {
      ServiceOrderStatus.intake => l10n.serviceStatusIntake,
      ServiceOrderStatus.inProgress => l10n.serviceStatusInProgress,
      ServiceOrderStatus.completed => l10n.serviceStatusCompleted,
      ServiceOrderStatus.closed => l10n.serviceStatusClosed,
      ServiceOrderStatus.cancelled => l10n.serviceStatusCancelled,
    };
  }

  IconData _statusIcon(ServiceOrderStatus status) {
    return switch (status) {
      ServiceOrderStatus.intake => Icons.inbox,
      ServiceOrderStatus.inProgress => Icons.build,
      ServiceOrderStatus.completed => TeleposIcons.checkCircle,
      ServiceOrderStatus.closed => TeleposIcons.lock,
      ServiceOrderStatus.cancelled => Icons.cancel_outlined,
    };
  }
}
