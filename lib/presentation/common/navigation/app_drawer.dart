import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/constants/enums/operating_mode.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/navigation/nav_destinations.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    this.currentRoute,
    this.onDestinationSelected,
    this.operatingMode = OperatingMode.retail,
    this.permissions = const {},
    super.key,
  });

  final String? currentRoute;

  final void Function(NavDestination)? onDestinationSelected;

  final OperatingMode operatingMode;

  final Set<String> permissions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryList = NavDestinations.primaryForModeFiltered(
      operatingMode,
      permissions,
    );
    final secondaryList = NavDestinations.secondaryForModeFiltered(
      operatingMode,
      permissions,
    );

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _DrawerHeader(theme: theme),

            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppLocalizations.of(context)!.navMain,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            ...primaryList.map(
              (dest) => _DrawerItem(
                destination: dest,
                isSelected: _isRouteSelected(dest.route),
                onTap: () => _onItemTap(context, dest),
              ),
            ),

            const Divider(height: 24),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppLocalizations.of(context)!.navAdditional,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  ...secondaryList.map(
                    (dest) => _DrawerItem(
                      destination: dest,
                      isSelected: _isRouteSelected(dest.route),
                      onTap: () => _onItemTap(context, dest),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'TelePOS',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isRouteSelected(String destRoute) {
    if (currentRoute == null) return false;
    return NavDestinations.routeMatches(currentRoute!, destRoute);
  }

  void _onItemTap(BuildContext context, NavDestination dest) {
    Navigator.of(context).pop();
    if (onDestinationSelected != null) {
      onDestinationSelected!(dest);
    } else {
      context.go(dest.route);
    }
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.point_of_sale, size: 48, color: AppColors.white),
          const SizedBox(height: 8),
          Text(
            'TelePOS',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(
        destination.getIcon(isSelected),
        color: isSelected
            ? AppColors.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        destination.getLabel(context),
        style: theme.textTheme.bodyLarge?.copyWith(
          color: isSelected
              ? AppColors.primary
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: selectedSurfaceOf(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: onTap,
    );
  }
}
