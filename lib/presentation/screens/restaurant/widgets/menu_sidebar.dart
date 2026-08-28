import 'package:flutter/material.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';

class MenuSidebar extends StatelessWidget {
  const MenuSidebar({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelectCategory,
    super.key,
  });

  final List<QuickProduct> categories;
  final int? selectedCategoryId;
  final ValueChanged<int?> onSelectCategory;

  static const _categoryColors = [
    Color(0xFF3A7BFF),
    Color(0xFF00BFA5),
    Color(0xFFFF6D3A),
    Color(0xFF9C5BF5),
    Color(0xFFE91E63),
    Color(0xFF43A047),
    Color(0xFFFF8F00),
    Color(0xFF5C6BC0),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      children: [
        _buildCategoryChip(
          label: l10n.globalAll,
          selected: selectedCategoryId == null,
          accentColor: _categoryColors[0],
          onTap: () => onSelectCategory(null),
        ),
        for (int i = 0; i < categories.length; i++) ...[
          const SizedBox(width: 8),
          _buildCategoryChip(
            label: categories[i].name ?? '#${categories[i].id}',
            selected: selectedCategoryId == categories[i].id,
            accentColor: _categoryColors[(i + 1) % _categoryColors.length],
            onTap: () => onSelectCategory(categories[i].id),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool selected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        constraints: const BoxConstraints(minHeight: 38),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accentColor : const Color(0xFFEEF0F4),
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF4A5568),
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
