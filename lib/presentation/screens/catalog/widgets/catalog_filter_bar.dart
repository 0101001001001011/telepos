import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/l10n/app_localizations.dart';

class CatalogFilterBar extends StatelessWidget {
  const CatalogFilterBar({
    required this.selectedType,
    required this.onTypeChanged,
    required this.includeDeleted,
    required this.onToggleDeleted,
    super.key,
  });

  final int? selectedType;
  final ValueChanged<int?> onTypeChanged;
  final bool includeDeleted;
  final VoidCallback onToggleDeleted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final filters = <(int?, String)>[
      (null, l10n.catalogFilterAll),
      (0, l10n.catalogFilterProducts),
      (1, l10n.catalogFilterWeighted),
      (4, l10n.catalogFilterServices),
      (5, l10n.catalogFilterConsumable),
      (3, l10n.catalogFilterPackages),
      (2, l10n.catalogFilterInner),
      (6, l10n.catalogFilterDish),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...filters.map((f) {
            final (type, label) = f;
            final isSelected = selectedType == type;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) => onTypeChanged(type),
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                showCheckmark: false,
              ),
            );
          }),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(l10n.catalogShowDeleted),
            selected: includeDeleted,
            onSelected: (_) => onToggleDeleted(),
            selectedColor: Theme.of(
              context,
            ).colorScheme.error.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              color: includeDeleted
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: includeDeleted ? FontWeight.w600 : FontWeight.normal,
            ),
            side: BorderSide(
              color: includeDeleted
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.outline,
            ),
            showCheckmark: true,
            checkmarkColor: Theme.of(context).colorScheme.error,
          ),
        ],
      ),
    );
  }
}
