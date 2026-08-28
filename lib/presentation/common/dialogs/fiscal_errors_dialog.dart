import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';

class FiscalError {
  const FiscalError({
    required this.receiptNo,
    required this.date,
    required this.errorCode,
    required this.errorMessage,
    this.canRetry = true,
  });

  final int receiptNo;
  final DateTime date;
  final String errorCode;
  final String errorMessage;
  final bool canRetry;
}

enum FiscalErrorAction { retry, cancel, close }

class FiscalErrorsDialog extends StatefulWidget {
  const FiscalErrorsDialog({super.key, required this.errors, this.title});

  final List<FiscalError> errors;
  final String? title;

  static Future<FiscalErrorAction?> show({
    required BuildContext context,
    required List<FiscalError> errors,
    String? title,
  }) {
    return showDialog<FiscalErrorAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => FiscalErrorsDialog(errors: errors, title: title),
    );
  }

  @override
  State<FiscalErrorsDialog> createState() => _FiscalErrorsDialogState();
}

class _FiscalErrorsDialogState extends State<FiscalErrorsDialog> {
  final Set<int> _selectedErrors = {};
  bool _selectAll = false;

  void _toggleSelectAll(bool? value) {
    setState(() {
      _selectAll = value ?? false;
      if (_selectAll) {
        _selectedErrors.addAll(
          widget.errors.where((e) => e.canRetry).map((e) => e.receiptNo),
        );
      } else {
        _selectedErrors.clear();
      }
    });
  }

  void _toggleError(int receiptNo, bool? value) {
    setState(() {
      if (value == true) {
        _selectedErrors.add(receiptNo);
      } else {
        _selectedErrors.remove(receiptNo);
      }
      _selectAll =
          _selectedErrors.length ==
          widget.errors.where((e) => e.canRetry).length;
    });
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final retryableErrors = widget.errors.where((e) => e.canRetry).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: Theme.of(context).colorScheme.error,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title ??
                              AppLocalizations.of(context)!.fiscalErrors,
                          style: AppTextStyles.h3,
                        ),
                        Text(
                          AppLocalizations.of(
                            context,
                          )!.errorsCount(widget.errors.length),
                          style: context.styles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (retryableErrors.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: context.semantic.canvas),
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(value: _selectAll, onChanged: _toggleSelectAll),
                    Text(
                      AppLocalizations.of(
                        context,
                      )!.selectAllCount(retryableErrors.length),
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),

            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: widget.errors.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final error = widget.errors[index];
                  return _ErrorTile(
                    error: error,
                    isSelected: _selectedErrors.contains(error.receiptNo),
                    onChanged: error.canRetry
                        ? (value) => _toggleError(error.receiptNo, value)
                        : null,
                    formatDateTime: _formatDateTime,
                  );
                },
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.semantic.canvas)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(FiscalErrorAction.close),
                      child: Text(AppLocalizations.of(context)!.globalClose),
                    ),
                  ),
                  if (_selectedErrors.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pop(FiscalErrorAction.retry),
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          AppLocalizations.of(
                            context,
                          )!.retryCount(_selectedErrors.length),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({
    required this.error,
    required this.isSelected,
    required this.onChanged,
    required this.formatDateTime,
  });

  final FiscalError error;
  final bool isSelected;
  final ValueChanged<bool?>? onChanged;
  final String Function(DateTime) formatDateTime;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (error.canRetry)
            Checkbox(value: isSelected, onChanged: onChanged)
          else
            const SizedBox(width: 48),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      AppLocalizations.of(
                        context,
                      )!.receiptHash(error.receiptNo),
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        error.errorCode,
                        style: context.styles.caption.copyWith(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  error.errorMessage,
                  style: context.styles.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(formatDateTime(error.date), style: context.styles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
