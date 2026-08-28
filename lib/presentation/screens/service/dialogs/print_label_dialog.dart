import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:telepos/l10n/app_localizations.dart';

class PrintLabelDialog extends StatelessWidget {
  const PrintLabelDialog({
    required this.orderNumber,
    required this.qrData,
    this.onPrint,
    super.key,
  });

  final String orderNumber;
  final String qrData;
  final VoidCallback? onPrint;

  static Future<void> show(
    BuildContext context, {
    required String orderNumber,
    required String qrData,
    VoidCallback? onPrint,
  }) {
    return showDialog(
      context: context,
      builder: (_) => PrintLabelDialog(
        orderNumber: orderNumber,
        qrData: qrData,
        onPrint: onPrint,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.servicePrintLabel),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                children: [
                  Text(
                    '#$orderNumber',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 160,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    qrData,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFamily: 'TeleposMono',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.serviceIntakeCancel),
        ),
        FilledButton.icon(
          onPressed: () {
            onPrint?.call();
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.print),
          label: Text(l10n.servicePrintLabel),
        ),
      ],
    );
  }
}
