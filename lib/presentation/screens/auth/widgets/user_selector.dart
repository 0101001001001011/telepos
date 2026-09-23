import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/role_label.dart';

class UserItem {
  const UserItem({
    required this.id,
    required this.name,
    this.role,
    this.hasPassword = true,
  });

  final int id;

  final String name;

  final String? role;

  final bool hasPassword;
}

class UserSelector extends StatelessWidget {
  const UserSelector({
    required this.users,
    required this.selectedUser,
    required this.onUserSelected,
    this.enabled = true,
    super.key,
  });

  final List<UserItem> users;
  final UserItem? selectedUser;
  final void Function(UserItem?) onUserSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final user = users[index];
        final isSelected = selectedUser?.id == user.id;
        return _UserCard(
          user: user,
          isSelected: isSelected,
          onTap: enabled ? () => onUserSelected(user) : null,
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: AppColors.warning),
          const SizedBox(width: AppTheme.spacingSmall),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.authNoUsers,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.isSelected, this.onTap});

  final UserItem user;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      // `selectedSurfaceOf`, а не константа `primaryLighter`: та светлая и
      // одинакова в обеих темах, а подпись берётся из темы и в тёмной
      // становится белой — белое по светло-голубому, 1.12:1. Измерено на
      // собранной кассе 2026-08-27, имя выбранного кассира не читалось вовсе.
      color: isSelected
          ? selectedSurfaceOf(context)
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                radius: 20,
                child: Text(
                  _getInitials(user.name),
                  // `onPrimary`, а не белый: в тёмной теме `primary` — светлый
                  // синий (#6AB3F3), и белым по нему писать нечем. Схема это
                  // уже знает и держит там тёмные чернила (докстринг
                  // `AppTheme.dark`).
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user.role != null)
                      Text(
                        userRoleLabelOfKey(
                          user.role!,
                          AppLocalizations.of(context)!,
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (!user.hasPassword)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.authNoPin,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppColors.success),
                  ),
                ),
              if (isSelected)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    TeleposIcons.checkCircle,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class UserSelectorCompact extends StatelessWidget {
  const UserSelectorCompact({
    required this.users,
    required this.selectedUser,
    required this.onUserSelected,
    this.enabled = true,
    super.key,
  });

  final List<UserItem> users;
  final UserItem? selectedUser;
  final void Function(UserItem?) onUserSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          AppLocalizations.of(context)!.authNoUsersShort,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (users.length == 1) {
      final user = users.first;
      return _UserCard(user: user, isSelected: true, onTap: null);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: users.map((user) {
        final isSelected = selectedUser?.id == user.id;
        return _UserChip(
          user: user,
          isSelected: isSelected,
          onTap: enabled ? () => onUserSelected(user) : null,
        );
      }).toList(),
    );
  }
}

class _UserChip extends StatelessWidget {
  const _UserChip({required this.user, required this.isSelected, this.onTap});

  final UserItem user;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      // `selectedSurfaceOf`, а не константа `primaryLighter`: та светлая и
      // одинакова в обеих темах, а подпись берётся из темы и в тёмной
      // становится белой — белое по светло-голубому, 1.12:1. Измерено на
      // собранной кассе 2026-08-27, имя выбранного кассира не читалось вовсе.
      color: isSelected
          ? selectedSurfaceOf(context)
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundColor: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                radius: 14,
                child: Text(
                  _getInitials(user.name),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                user.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
