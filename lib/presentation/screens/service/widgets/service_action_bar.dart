import 'package:flutter/material.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/constants/enums/service_order_status.dart';
import 'package:telepos/l10n/app_localizations.dart';

class ServiceActionBar extends StatelessWidget {
  const ServiceActionBar({
    required this.status,
    this.onProgress,
    this.onCancel,
    this.onPrintLabel,
    this.onPrintReceipt,
    this.isLoading = false,
    super.key,
  });

  final ServiceOrderStatus status;
  final VoidCallback? onProgress;
  final VoidCallback? onCancel;
  final VoidCallback? onPrintLabel;
  final VoidCallback? onPrintReceipt;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.serviceDetailActions,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_canProgress)
                  FilledButton.icon(
                    onPressed: isLoading ? null : onProgress,
                    icon: Icon(_progressIcon),
                    label: Text(_progressLabel(l10n)),
                  ),
                if (_canCancel)
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : onCancel,
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(l10n.serviceCancelConfirm),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : onPrintLabel,
                  icon: const Icon(Icons.qr_code),
                  label: Text(l10n.servicePrintLabel),
                ),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : onPrintReceipt,
                  icon: const Icon(Icons.print_outlined),
                  label: Text(l10n.servicePrintReceipt),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _canProgress =>
      status != ServiceOrderStatus.closed &&
      status != ServiceOrderStatus.cancelled;

  bool get _canCancel =>
      status != ServiceOrderStatus.closed &&
      status != ServiceOrderStatus.cancelled;

  IconData get _progressIcon {
    return switch (status) {
      ServiceOrderStatus.intake => Icons.play_arrow,
      ServiceOrderStatus.inProgress => TeleposIcons.check,
      ServiceOrderStatus.completed => TeleposIcons.lock,
      _ => Icons.arrow_forward,
    };
  }

  String _progressLabel(AppLocalizations l10n) {
    return switch (status) {
      ServiceOrderStatus.intake => l10n.serviceProgressConfirm,
      ServiceOrderStatus.inProgress => l10n.serviceStatusCompleted,
      ServiceOrderStatus.completed => l10n.serviceStatusClosed,
      _ => l10n.serviceProgressConfirm,
    };
  }
}
