import 'package:flutter/material.dart';
import 'package:telepos/core/constants/enums/service_order_status.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/service/widgets/service_status_badge.dart';

class ConfirmStatusResult {
  const ConfirmStatusResult({this.confirmed = false, this.comment});
  final bool confirmed;
  final String? comment;
}

class ConfirmStatusDialog extends StatefulWidget {
  const ConfirmStatusDialog({
    required this.currentStatus,
    required this.nextStatus,
    this.isCancel = false,
    super.key,
  });

  final ServiceOrderStatus currentStatus;
  final ServiceOrderStatus nextStatus;
  final bool isCancel;

  static Future<ConfirmStatusResult?> show(
    BuildContext context, {
    required ServiceOrderStatus currentStatus,
    required ServiceOrderStatus nextStatus,
    bool isCancel = false,
  }) {
    return showDialog<ConfirmStatusResult>(
      context: context,
      builder: (_) => ConfirmStatusDialog(
        currentStatus: currentStatus,
        nextStatus: nextStatus,
        isCancel: isCancel,
      ),
    );
  }

  @override
  State<ConfirmStatusDialog> createState() => _ConfirmStatusDialogState();
}

class _ConfirmStatusDialogState extends State<ConfirmStatusDialog> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        widget.isCancel
            ? l10n.serviceCancelConfirm
            : l10n.serviceProgressConfirm,
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ServiceStatusBadge(status: widget.currentStatus),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    Icons.arrow_forward,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                ServiceStatusBadge(status: widget.nextStatus),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.serviceMarkNote,
                border: const OutlineInputBorder(),
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
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              ConfirmStatusResult(
                confirmed: true,
                comment: _commentController.text.trim().isNotEmpty
                    ? _commentController.text.trim()
                    : null,
              ),
            );
          },
          style: widget.isCancel
              ? FilledButton.styleFrom(backgroundColor: Colors.red)
              : null,
          child: Text(
            widget.isCancel
                ? l10n.serviceCancelConfirm
                : l10n.serviceProgressConfirm,
          ),
        ),
      ],
    );
  }
}
