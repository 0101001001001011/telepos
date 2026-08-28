import 'package:flutter/material.dart';
import 'package:telepos/core/constants/enums/service_order_status.dart';
import 'package:telepos/l10n/app_localizations.dart';

class ServiceStatusBadge extends StatelessWidget {
  const ServiceStatusBadge({
    required this.status,
    this.compact = false,
    super.key,
  });

  final ServiceOrderStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (color, label) = _statusInfo(l10n);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (Color, String) _statusInfo(AppLocalizations l10n) {
    return switch (status) {
      ServiceOrderStatus.intake => (Colors.blue, l10n.serviceStatusIntake),
      ServiceOrderStatus.inProgress => (
        Colors.orange,
        l10n.serviceStatusInProgress,
      ),
      ServiceOrderStatus.completed => (
        Colors.green,
        l10n.serviceStatusCompleted,
      ),
      ServiceOrderStatus.closed => (Colors.grey, l10n.serviceStatusClosed),
      ServiceOrderStatus.cancelled => (Colors.red, l10n.serviceStatusCancelled),
    };
  }
}
