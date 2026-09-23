import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/l10n/app_localizations.dart';

class ReportDateFilter extends StatelessWidget {
  const ReportDateFilter({
    required this.dateRange,
    required this.onChanged,
    super.key,
  });

  final DateTimeRange dateRange;
  final ValueChanged<DateTimeRange> onChanged;

  int get _selectedIndex {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(
      dateRange.start.year,
      dateRange.start.month,
      dateRange.start.day,
    );
    final diff = today.difference(start).inDays;

    if (diff == 0) return 0;
    if (diff == 6) return 1;
    if (diff == 29) return 2;
    return 3;
  }

  void _selectPreset(BuildContext context, int index) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (index) {
      case 0:
        onChanged(DateTimeRange(start: today, end: now));
      case 1:
        onChanged(
          DateTimeRange(
            start: today.subtract(const Duration(days: 6)),
            end: now,
          ),
        );
      case 2:
        onChanged(
          DateTimeRange(
            start: today.subtract(const Duration(days: 29)),
            end: now,
          ),
        );
      case 3:
        _pickCustomRange(context);
    }
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex;
    final l10n = AppLocalizations.of(context)!;
    final labels = [
      l10n.historyToday,
      l10n.repRangeDays7,
      l10n.repRangeDays30,
      l10n.repRangeCustom,
    ];
    const icons = [
      Icons.today,
      Icons.date_range,
      Icons.calendar_month,
      Icons.edit_calendar,
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = index == selected;
          return ChoiceChip(
            avatar: Icon(
              icons[index],
              size: 18,
              color: isSelected
                  ? AppColors.white
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            label: Text(labels[index]),
            selected: isSelected,
            onSelected: (_) => _selectPreset(context, index),
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(
              color: isSelected
                  ? AppColors.white
                  : Theme.of(context).colorScheme.onSurface,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            side: BorderSide(
              color: isSelected
                  ? AppColors.primary
                  : Theme.of(context).colorScheme.outline,
            ),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}
