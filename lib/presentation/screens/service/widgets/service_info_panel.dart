import 'package:flutter/material.dart';
import 'package:telepos/domain/entities/service/service_order_entity.dart';
import 'package:telepos/l10n/app_localizations.dart';

class ServiceInfoPanel extends StatelessWidget {
  const ServiceInfoPanel({required this.order, super.key});

  final ServiceOrderEntity order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final intakeDate = DateTime.fromMillisecondsSinceEpoch(
      order.intakeTime * 1000,
    );
    final intakeDateStr = _formatDateTime(intakeDate);

    String? estimatedDateStr;
    if (order.estimatedCompletionTime != null) {
      final est = DateTime.fromMillisecondsSinceEpoch(
        order.estimatedCompletionTime! * 1000,
      );
      estimatedDateStr = _formatDateTime(est);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.serviceDetailInfo,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.person_outline,
              label: l10n.serviceClientName,
              value: order.clientDisplayName,
            ),
            if (order.clientPhone != null)
              _InfoRow(
                icon: Icons.phone_outlined,
                label: l10n.serviceClientPhone,
                value: order.clientPhone!,
              ),
            if (order.deviceDescription != null)
              _InfoRow(
                icon: Icons.devices_outlined,
                label: l10n.serviceIntakeDevice,
                value: order.deviceDescription!,
              ),
            if (order.serialNumber != null)
              _InfoRow(
                icon: Icons.tag,
                label: 'S/N',
                value: order.serialNumber!,
              ),
            if (order.complaint != null)
              _InfoRow(
                icon: Icons.report_problem_outlined,
                label: l10n.serviceMarkDescription,
                value: order.complaint!,
              ),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: l10n.serviceIntakeTitle,
              value: intakeDateStr,
            ),
            if (estimatedDateStr != null)
              _InfoRow(
                icon: Icons.event_outlined,
                label: l10n.serviceEstimatedDate,
                value: estimatedDateStr,
              ),
            if (order.clientNote != null) ...[
              const SizedBox(height: 8),
              Text(
                order.clientNote!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
