import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/constants/enums/operating_mode.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/help/help_button.dart';
import 'package:telepos/presentation/common/help/help_service.dart';
import 'package:telepos/presentation/common/navigation/app_drawer.dart';
import 'package:telepos/core/settings/nav_collapsed_provider.dart';
import 'package:telepos/presentation/common/navigation/nav_destinations.dart';
import 'package:telepos/presentation/common/navigation/tg_app_bar.dart';
import 'package:telepos/presentation/common/navigation/tg_bottom_bar.dart';
import 'package:telepos/presentation/common/navigation/tg_nav_column.dart';
import 'package:telepos/presentation/common/widgets/status_bar.dart';
import 'package:telepos/presentation/common/widgets/storage_warning.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';
import 'package:telepos/presentation/controllers/update/update_controller.dart';
import 'package:telepos/presentation/dialogs/update_dialog.dart';
import 'package:telepos/core/services/update/update_state.dart';

class AdaptiveScaffold extends ConsumerWidget {
  const AdaptiveScaffold({
    required this.child,
    required this.currentRoute,
    this.title,
    this.actions,
    this.floatingActionButton,
    super.key,
  });

  final Widget child;

  final String currentRoute;

  final String? title;

  final List<Widget>? actions;

  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layoutType = Breakpoints.of(context);
    final orientation = MediaQuery.orientationOf(context);
    final mode = ref.watch(operatingModeProvider);
    final permissions = ref.watch(
      appStateProvider.select((s) => s.permissions),
    );

    ref.listen<UpdateState>(updateProvider, (previous, next) {
      if (previous?.status != UpdateStatus.available &&
          next.status == UpdateStatus.available &&
          next.updateInfo != null) {
        UpdateDialog.show(
          context,
          updateInfo: next.updateInfo!,
          onUpdate: () {
            Navigator.of(context).pop();
            final notifier = ref.read(updateProvider.notifier);
            notifier.downloadUpdate().then((_) {
              final state = ref.read(updateProvider);
              if (state.status == UpdateStatus.ready) {
                notifier.installUpdate();
              }
            });
          },
          onLater: () {
            Navigator.of(context).pop();
            ref.read(updateProvider.notifier).skipUpdate();
          },
        );
      }
    });

    void onLock() {
      ref.read(appStateProvider.notifier).logout();
    }

    final gatedChild = _ShiftClosedGate(
      currentRoute: currentRoute,
      child: child,
    );

    return switch (layoutType) {
      LayoutType.desktop => _DesktopScaffold(
        currentRoute: currentRoute,
        title: title,
        actions: actions,
        floatingActionButton: floatingActionButton,
        operatingMode: mode,
        permissions: permissions,
        onLock: onLock,
        child: gatedChild,
      ),
      LayoutType.tablet => _TabletScaffold(
        currentRoute: currentRoute,
        title: title,
        actions: actions,
        floatingActionButton: floatingActionButton,
        isLandscape: orientation == Orientation.landscape,
        operatingMode: mode,
        permissions: permissions,
        onLock: onLock,
        child: gatedChild,
      ),
      LayoutType.mobile => _MobileScaffold(
        currentRoute: currentRoute,
        title: title,
        actions: actions,
        floatingActionButton: floatingActionButton,
        operatingMode: mode,
        permissions: permissions,
        onLock: onLock,
        child: gatedChild,
      ),
    };
  }
}

const Set<String> _shiftGatedRoutes = {
  '/sale',
  '/refund',
  '/catalog',
  '/stock-registry',
  '/inventory',
  '/movement',
  '/supplier-return',
  '/supplier-order',
  '/cash-operation',
  '/wms',
  '/tables',
  '/service-queue',
};

class _ShiftClosedGate extends ConsumerWidget {
  const _ShiftClosedGate({required this.child, required this.currentRoute});

  final Widget child;
  final String currentRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_shiftGatedRoutes.contains(currentRoute)) return child;
    final isOpen = ref.watch(shiftControllerProvider.select((s) => s.isOpen));
    if (isOpen) return child;

    final l10n = AppLocalizations.of(context)!;
    return Stack(
      children: [
        IgnorePointer(child: child),
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.55),
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_clock,
                      size: 56,
                      color: AppColors.warning,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.shiftClosedGateTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.shiftClosedGateMessage,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.go('/shift'),
                        icon: const Icon(Icons.play_circle_outline),
                        label: Text(l10n.shiftClosedGateOpen),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Широкий экран: шапка, колонка слева, волосок, содержимое.
///
/// Здесь стоял `DesktopTabBar` — горизонтальная полоса вкладок, залитая
/// акцентом во всю ширину. Спека описывала широкий экран как «рельс,
/// разделитель, содержимое» и об этой ветке не знала: левой колонки на
/// ширине от 1200 не было вовсе, а именно эту ширину заказчик и смотрел в
/// браузере. Полоса заменена на ту же колонку, что и на планшете в альбомной
/// ориентации: назначения, их порядок и фильтрация по правам — прежние, до
/// вызова `context.go` включительно.
class _DesktopScaffold extends StatelessWidget {
  const _DesktopScaffold({
    required this.child,
    required this.currentRoute,
    required this.operatingMode,
    required this.permissions,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.onLock,
  });

  final Widget child;
  final String currentRoute;
  final OperatingMode operatingMode;
  final Set<String> permissions;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final VoidCallback? onLock;

  @override
  Widget build(BuildContext context) {
    final currentDest = NavDestinations.fromRoute(currentRoute, operatingMode);
    final displayTitle = title ?? currentDest?.getLabel(context) ?? 'TelePOS';

    return Scaffold(
      // Заголовок здесь простой текст, без часов и точки связи: на широком
      // экране внизу стоит полная `StatusBar`, и повторять то же самое в
      // шапке значило бы показать время дважды.
      appBar: TgAppBar(
        title: Text(displayTitle),
        actions: [
          const StorageWarningChip(),
          IconButton(
            icon: const Icon(TeleposIcons.lock),
            tooltip: AppLocalizations.of(context)!.navLockScreen,
            onPressed: onLock,
          ),
          HelpButton(screenId: HelpService.routeToScreenId(currentRoute)),
          ...?actions,
        ],
      ),
      body: Column(
        children: [
          const StorageWarningBanner(),
          Expanded(
            child: Row(
              children: [
                _ShellNavColumn(
                  currentRoute: currentRoute,
                  operatingMode: operatingMode,
                  permissions: permissions,
                ),
                const TgVerticalHairline(),
                Expanded(child: child),
              ],
            ),
          ),
          const StatusBar(),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Левая колонка оболочки: список основных назначений, меню дополнительных
/// внизу.
///
/// Одна на обе широкие ветки — десктоп и планшет в альбомной. Пока колонка
/// была рельсом внутри `_TabletScaffold`, десктоп жил с горизонтальной
/// полосой, и «оболочка на широком экране» означала две разные оболочки.
class _ShellNavColumn extends ConsumerWidget {
  const _ShellNavColumn({
    required this.currentRoute,
    required this.operatingMode,
    required this.permissions,
  });

  final String currentRoute;
  final OperatingMode operatingMode;
  final Set<String> permissions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCollapsed = ref.watch(navCollapsedProvider);
    final l10n = AppLocalizations.of(context)!;

    return TgNavColumn(
      destinations: NavDestinations.primaryForModeFiltered(
        operatingMode,
        permissions,
      ),
      currentRoute: currentRoute,
      isCollapsed: isCollapsed,
      onSelected: (dest) => context.go(dest.route),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(
            height: AppTokens.hairlineOf(context),
            thickness: AppTokens.hairlineOf(context),
            color: context.semantic.hairline,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space8,
              vertical: AppTokens.space4,
            ),
            // Свёрнутая колонка ставит кнопки столбиком: рядом они не
            // помещаются в `navColumnCollapsedWidth`, и `Row` обрезал бы
            // вторую молча.
            child: Flex(
              direction: isCollapsed ? Axis.vertical : Axis.horizontal,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.min,
              children: [
                _SecondaryMenuButton(
                  currentRoute: currentRoute,
                  operatingMode: operatingMode,
                  permissions: permissions,
                  onSelected: (dest) => context.go(dest.route),
                ),
                IconButton(
                  key: const ValueKey('nav-collapse-toggle'),
                  // `menu_open` — канонический значок сворачивания панели:
                  // гамбургер со стрелкой, то есть «меню» и направление в
                  // одном знаке. Пара `keyboard_double_arrow_left/right`,
                  // стоявшая здесь сначала, говорила только направление и
                  // читалась как перемотка.
                  //
                  // Зеркалится, а не подменяется вторым значком: у стрелки
                  // меняется только направление, и `Transform.flip` держит
                  // это одним смыслом. Иконки «menu_close» в Material нет.
                  icon: Transform.flip(
                    flipX: isCollapsed,
                    child: const Icon(Icons.menu_open),
                  ),
                  iconSize: AppTokens.iconSizeNav,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  tooltip: isCollapsed
                      ? l10n.navExpandMenu
                      : l10n.navCollapseMenu,
                  onPressed: () =>
                      ref.read(navCollapsedProvider.notifier).toggle(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabletScaffold extends StatelessWidget {
  const _TabletScaffold({
    required this.child,
    required this.currentRoute,
    required this.isLandscape,
    required this.operatingMode,
    required this.permissions,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.onLock,
  });

  final Widget child;
  final String currentRoute;
  final bool isLandscape;
  final OperatingMode operatingMode;
  final Set<String> permissions;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final VoidCallback? onLock;

  @override
  Widget build(BuildContext context) {
    final currentDest = NavDestinations.fromRoute(currentRoute, operatingMode);
    final displayTitle = title ?? currentDest?.getLabel(context) ?? 'TelePOS';

    if (isLandscape) {
      return Scaffold(
        appBar: TgAppBar(
          title: StatusBarAppBarTitle(title: displayTitle),
          actions: [
            const StorageWarningChip(),
            IconButton(
              icon: const Icon(TeleposIcons.lock),
              tooltip: AppLocalizations.of(context)!.navLockScreen,
              onPressed: onLock,
            ),
            HelpButton(screenId: HelpService.routeToScreenId(currentRoute)),
            ...?actions,
          ],
        ),
        body: Row(
          children: [
            _ShellNavColumn(
              currentRoute: currentRoute,
              operatingMode: operatingMode,
              permissions: permissions,
            ),
            const TgVerticalHairline(),
            Expanded(child: child),
          ],
        ),
        floatingActionButton: floatingActionButton,
      );
    }

    return Scaffold(
      appBar: TgAppBar(
        title: StatusBarAppBarTitle(title: displayTitle),
        actions: [
          const StorageWarningChip(),
          IconButton(
            icon: const Icon(TeleposIcons.lock),
            tooltip: AppLocalizations.of(context)!.navLockScreen,
            onPressed: onLock,
          ),
          HelpButton(screenId: HelpService.routeToScreenId(currentRoute)),
          _SecondaryMenuButton(
            currentRoute: currentRoute,
            operatingMode: operatingMode,
            permissions: permissions,
            onSelected: (dest) => context.go(dest.route),
          ),
          ...?actions,
        ],
      ),
      body: child,
      bottomNavigationBar: _buildBottomNav(context),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget? _buildBottomNav(BuildContext context) {
    final primaryList = NavDestinations.primaryForModeFiltered(
      operatingMode,
      permissions,
    );

    // Панель из одного пункта — не панель, а украшение: переходить некуда.
    if (primaryList.length < 2) return null;

    return TgBottomBar(
      destinations: primaryList,
      currentRoute: currentRoute,
      onSelected: (dest) => context.go(dest.route),
    );
  }
}

class _MobileScaffold extends StatelessWidget {
  const _MobileScaffold({
    required this.child,
    required this.currentRoute,
    required this.operatingMode,
    required this.permissions,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.onLock,
  });

  final Widget child;
  final String currentRoute;
  final OperatingMode operatingMode;
  final Set<String> permissions;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final VoidCallback? onLock;

  @override
  Widget build(BuildContext context) {
    final currentDest = NavDestinations.fromRoute(currentRoute, operatingMode);
    final displayTitle = title ?? currentDest?.getLabel(context) ?? 'TelePOS';
    final primaryList = NavDestinations.primaryForModeFiltered(
      operatingMode,
      permissions,
    );

    return Scaffold(
      appBar: TgAppBar(
        title: StatusBarAppBarTitle(title: displayTitle),
        actions: [
          const StorageWarningChip(),
          IconButton(
            icon: const Icon(TeleposIcons.lock),
            tooltip: AppLocalizations.of(context)!.navLockScreen,
            onPressed: onLock,
          ),
          HelpButton(screenId: HelpService.routeToScreenId(currentRoute)),
          ...?actions,
        ],
      ),
      drawer: AppDrawer(
        currentRoute: currentRoute,
        operatingMode: operatingMode,
        permissions: permissions,
        onDestinationSelected: (dest) => context.go(dest.route),
      ),
      body: child,
      // Панель из одного пункта — не панель, а украшение: переходить некуда.
      bottomNavigationBar: primaryList.length < 2
          ? null
          : TgBottomBar(
              destinations: primaryList,
              currentRoute: currentRoute,
              onSelected: (dest) => context.go(dest.route),
            ),
      floatingActionButton: floatingActionButton,
    );
  }
}

class _SecondaryMenuButton extends StatelessWidget {
  const _SecondaryMenuButton({
    this.currentRoute,
    this.operatingMode = OperatingMode.retail,
    this.permissions = const {},
    this.onSelected,
  });

  final String? currentRoute;
  final OperatingMode operatingMode;
  final Set<String> permissions;
  final void Function(NavDestination)? onSelected;

  @override
  Widget build(BuildContext context) {
    final secondary = NavDestinations.secondaryForModeFiltered(
      operatingMode,
      permissions,
    );
    final hasSelectedSecondary = secondary.any((d) => d.route == currentRoute);

    return PopupMenuButton<NavDestination>(
      icon: Icon(
        Icons.more_vert,
        color: hasSelectedSecondary ? AppColors.primary : null,
      ),
      tooltip: AppLocalizations.of(context)!.navMore,
      onSelected: onSelected,
      itemBuilder: (context) => secondary.map((dest) {
        final isSelected = currentRoute == dest.route;
        return PopupMenuItem(
          value: dest,
          child: ListTile(
            leading: Icon(
              dest.getIcon(isSelected),
              color: isSelected
                  ? AppColors.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            title: Text(
              dest.getLabel(context),
              style: TextStyle(
                color: isSelected
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        );
      }).toList(),
    );
  }
}
