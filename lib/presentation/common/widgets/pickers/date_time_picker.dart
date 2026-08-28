import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';

enum DateTimePickerMode { date, time, dateTime, dateRange }

class DateTimePicker extends StatelessWidget {
  const DateTimePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.mode = DateTimePickerMode.date,
    this.firstDate,
    this.lastDate,
    this.label,
    this.hint,
    this.enabled = true,
    this.showClearButton = false,
    this.format,
  });

  final DateTime? value;

  final ValueChanged<DateTime?> onChanged;

  final DateTimePickerMode mode;

  final DateTime? firstDate;

  final DateTime? lastDate;

  final String? label;

  final String? hint;

  final bool enabled;

  final bool showClearButton;

  final String Function(DateTime)? format;

  String _formatDate(DateTime date) {
    if (format != null) return format!(date);

    return switch (mode) {
      DateTimePickerMode.date =>
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
      DateTimePickerMode.time =>
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
      DateTimePickerMode.dateTime =>
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} '
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
      DateTimePickerMode.dateRange =>
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
    };
  }

  String _defaultHintFor(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (mode) {
      DateTimePickerMode.date => l10n.datePlaceholder,
      DateTimePickerMode.time => l10n.timePlaceholder,
      DateTimePickerMode.dateTime => l10n.dateTimePlaceholder,
      DateTimePickerMode.dateRange => l10n.selectPeriod,
    };
  }

  IconData get _icon {
    return switch (mode) {
      DateTimePickerMode.date => Icons.calendar_today,
      DateTimePickerMode.time => Icons.access_time,
      DateTimePickerMode.dateTime => Icons.event,
      DateTimePickerMode.dateRange => Icons.date_range,
    };
  }

  Future<void> _showPicker(BuildContext context) async {
    if (!enabled) return;

    final now = DateTime.now();
    final effectiveFirstDate = firstDate ?? DateTime(2000);
    final effectiveLastDate = lastDate ?? DateTime(2100);
    final initialDate = value ?? now;

    switch (mode) {
      case DateTimePickerMode.date:
        final date = await showDatePicker(
          context: context,
          initialDate: initialDate.isBefore(effectiveFirstDate)
              ? effectiveFirstDate
              : (initialDate.isAfter(effectiveLastDate)
                    ? effectiveLastDate
                    : initialDate),
          firstDate: effectiveFirstDate,
          lastDate: effectiveLastDate,
        );
        if (date != null) onChanged(date);
        break;

      case DateTimePickerMode.time:
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(initialDate),
        );
        if (time != null) {
          onChanged(
            DateTime(
              initialDate.year,
              initialDate.month,
              initialDate.day,
              time.hour,
              time.minute,
            ),
          );
        }
        break;

      case DateTimePickerMode.dateTime:
        final date = await showDatePicker(
          context: context,
          initialDate: initialDate.isBefore(effectiveFirstDate)
              ? effectiveFirstDate
              : (initialDate.isAfter(effectiveLastDate)
                    ? effectiveLastDate
                    : initialDate),
          firstDate: effectiveFirstDate,
          lastDate: effectiveLastDate,
        );
        if (date != null && context.mounted) {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(initialDate),
          );
          if (time != null) {
            onChanged(
              DateTime(date.year, date.month, date.day, time.hour, time.minute),
            );
          }
        }
        break;

      case DateTimePickerMode.dateRange:
        final range = await showDateRangePicker(
          context: context,
          firstDate: effectiveFirstDate,
          lastDate: effectiveLastDate,
          initialDateRange: value != null
              ? DateTimeRange(start: value!, end: value!)
              : null,
        );
        if (range != null) {
          onChanged(range.start);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(label!, style: context.styles.caption),
          ),
        InkWell(
          onTap: enabled ? () => _showPicker(context) : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: enabled
                  ? Theme.of(context).colorScheme.surface
                  : context.semantic.canvas,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderPrimary),
            ),
            child: Row(
              children: [
                Icon(
                  _icon,
                  size: 20,
                  color: enabled
                      ? AppColors.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value != null
                        ? _formatDate(value!)
                        : (hint ?? _defaultHintFor(context)),
                    style: AppTextStyles.body.copyWith(
                      color: value != null
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (showClearButton && value != null && enabled)
                  IconButton(
                    onPressed: () => onChanged(null),
                    icon: const Icon(TeleposIcons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class DateRangePicker extends StatelessWidget {
  const DateRangePicker({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.label,
    this.enabled = true,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final void Function(DateTime? start, DateTime? end) onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? label;
  final bool enabled;

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Future<void> _showPicker(BuildContext context) async {
    if (!enabled) return;

    final effectiveFirstDate = firstDate ?? DateTime(2000);
    final effectiveLastDate = lastDate ?? DateTime(2100);

    final range = await showDateRangePicker(
      context: context,
      firstDate: effectiveFirstDate,
      lastDate: effectiveLastDate,
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate!, end: endDate!)
          : null,
    );

    if (range != null) {
      onChanged(range.start, range.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(label!, style: context.styles.caption),
          ),
        InkWell(
          onTap: enabled ? () => _showPicker(context) : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: enabled
                  ? Theme.of(context).colorScheme.surface
                  : context.semantic.canvas,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderPrimary),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.date_range,
                  size: 20,
                  color: enabled
                      ? AppColors.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    startDate != null && endDate != null
                        ? '${_formatDate(startDate!)} — ${_formatDate(endDate!)}'
                        : AppLocalizations.of(context)!.selectPeriod,
                    style: AppTextStyles.body.copyWith(
                      color: startDate != null
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (startDate != null && enabled)
                  IconButton(
                    onPressed: () => onChanged(null, null),
                    icon: const Icon(TeleposIcons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
