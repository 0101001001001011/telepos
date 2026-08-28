import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';

class GuestSelector extends StatelessWidget {
  const GuestSelector({
    required this.guestCount,
    required this.selectedGuest,
    required this.onSelectGuest,
    required this.onAddGuest,
    super.key,
  });

  final int guestCount;
  final int selectedGuest;
  final ValueChanged<int> onSelectGuest;
  final VoidCallback onAddGuest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          const SizedBox(width: 8),
          _buildChip(
            context,
            label: l10n.globalAll,
            selected: selectedGuest == 0,
            onTap: () => onSelectGuest(0),
          ),
          for (int i = 1; i <= guestCount; i++) ...[
            const SizedBox(width: 6),
            _buildChip(
              context,
              label: '$i',
              selected: selectedGuest == i,
              onTap: () => onSelectGuest(i),
            ),
          ],
          const SizedBox(width: 6),
          SizedBox(
            width: 36,
            height: 36,
            child: IconButton.outlined(
              icon: const Icon(TeleposIcons.add, size: 16),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onPressed: onAddGuest,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // [context] прокинут явно: подложка берётся ролью темы, и без контекста
  // роль не достать. Раньше метод обходился константой.
  Widget _buildChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 36),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? AppColors.white
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
