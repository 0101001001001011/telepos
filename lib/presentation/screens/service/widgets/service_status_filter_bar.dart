import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/constants/enums/service_order_status.dart';
import 'package:telepos/domain/entities/service/service_order_entity.dart';
import 'package:telepos/l10n/app_localizations.dart';

class ServiceStatusFilterBar extends StatelessWidget {
  const ServiceStatusFilterBar({
    required this.selectedStatus,
    required this.onStatusChanged,
    this.orders = const [],
    super.key,
  });

  final ServiceOrderStatus? selectedStatus;
  final ValueChanged<ServiceOrderStatus?> onStatusChanged;
  final List<ServiceOrderEntity> orders;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final counts = <ServiceOrderStatus?, int>{null: orders.length};
    for (final status in ServiceOrderStatus.values) {
      counts[status] = orders.where((o) => o.status == status).length;
    }

    final filters = <(ServiceOrderStatus?, String, Color, IconData)>[
      (
        null,
        l10n.serviceFilterAll,
        Theme.of(context).colorScheme.onSurface,
        Icons.list,
      ),
      (
        ServiceOrderStatus.intake,
        l10n.serviceStatusIntake,
        Colors.blue,
        Icons.inbox,
      ),
      (
        ServiceOrderStatus.inProgress,
        l10n.serviceStatusInProgress,
        Colors.orange,
        Icons.build,
      ),
      (
        ServiceOrderStatus.completed,
        l10n.serviceStatusCompleted,
        Colors.green,
        TeleposIcons.checkCircle,
      ),
      (
        ServiceOrderStatus.closed,
        l10n.serviceStatusClosed,
        Colors.grey,
        Icons.lock,
      ),
      (
        ServiceOrderStatus.cancelled,
        l10n.serviceStatusCancelled,
        Colors.red,
        Icons.cancel,
      ),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final (status, label, color, icon) = filters[index];
          final isSelected = selectedStatus == status;
          final count = counts[status] ?? 0;

          return FilterChip(
            avatar: Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : color,
            ),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                if (count > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.3)
                          : color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : color,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            selected: isSelected,
            onSelected: (_) => onStatusChanged(status),
            selectedColor: color,
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            side: BorderSide(
              color: isSelected ? color : Theme.of(context).colorScheme.outline,
            ),
            visualDensity: VisualDensity.compact,
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        },
      ),
    );
  }
}
