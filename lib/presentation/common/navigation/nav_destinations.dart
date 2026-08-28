import 'package:flutter/material.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/constants/enums/operating_mode.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/l10n/app_localizations.dart';

class NavDestination {
  const NavDestination({
    required this.route,
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.isPrimary = false,
    this.permissionKey,
  });

  final String route;

  final String label;

  final IconData icon;

  final IconData? selectedIcon;

  final bool isPrimary;

  final String? permissionKey;

  IconData getIcon(bool selected) => selected ? (selectedIcon ?? icon) : icon;

  String getLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return label;

    return switch (route) {
      '/sale' => l10n.navSale,
      '/refund' => l10n.navRefund,
      '/shift' => l10n.navShift,
      '/history' => l10n.navHistory,
      '/tables' => l10n.navTables,
      '/orders' => l10n.navOrders,
      '/service-queue' => l10n.navQueue,
      '/service-intake' => l10n.navIntake,
      '/catalog' => l10n.navCatalog,
      '/reports' => l10n.navReports,
      '/agent' => l10n.navAgents,
      '/supply' => l10n.navSupply,
      '/stock-registry' => l10n.navStock,
      '/cash-operation' => l10n.navCash,
      '/settings' => l10n.navSettings,
      '/sync' => l10n.navSync,
      '/wms' => l10n.navWmsDashboard,
      '/wms-warehouses' => l10n.navWmsWarehouses,
      '/wms-batches' => l10n.navWmsBatches,
      '/wms-serials' => l10n.navWmsSerials,
      '/wms-cell-stock' => l10n.navWmsCellStock,
      '/wms-claims' => l10n.navWmsClaims,
      '/wms-marking' => l10n.navWmsMarking,
      '/wms-settings' => l10n.navWmsSettings,
      _ => label,
    };
  }
}

class NavDestinations {
  NavDestinations._();

  static const sale = NavDestination(
    route: '/sale',
    label: 'Продажа',
    icon: TeleposIcons.sale,
    isPrimary: true,
    permissionKey: PermissionKeys.navSale,
  );

  static const refund = NavDestination(
    route: '/refund',
    label: 'Возврат',
    icon: TeleposIcons.refund,
    isPrimary: true,
    permissionKey: PermissionKeys.navRefund,
  );

  static const shift = NavDestination(
    route: '/shift',
    label: 'Смена',
    icon: TeleposIcons.shift,
    isPrimary: true,
    permissionKey: PermissionKeys.navShift,
  );

  static const history = NavDestination(
    route: '/history',
    label: 'История',
    icon: TeleposIcons.history,
    isPrimary: true,
    permissionKey: PermissionKeys.navHistory,
  );

  static const tables = NavDestination(
    route: '/tables',
    label: 'Столы',
    icon: TeleposIcons.tables,
    isPrimary: true,
    permissionKey: PermissionKeys.navTables,
  );

  static const orders = NavDestination(
    route: '/orders',
    label: 'Заказы',
    icon: TeleposIcons.orders,
    isPrimary: true,
    permissionKey: PermissionKeys.navOrders,
  );

  static const serviceQueue = NavDestination(
    route: '/service-queue',
    label: 'Очередь',
    icon: TeleposIcons.serviceQueue,
    isPrimary: true,
    permissionKey: PermissionKeys.navServiceQueue,
  );

  static const serviceIntake = NavDestination(
    route: '/service-intake',
    label: 'Приём',
    icon: TeleposIcons.serviceIntake,
    isPrimary: true,
    permissionKey: PermissionKeys.navServiceIntake,
  );

  static const wmsDashboard = NavDestination(
    route: '/wms',
    label: 'Склад WMS',
    icon: TeleposIcons.warehouse,
    isPrimary: true,
  );

  static const wmsWarehouses = NavDestination(
    route: '/wms-warehouses',
    label: 'Склады',
    icon: TeleposIcons.warehouses,
    isPrimary: true,
  );

  static const wmsBatches = NavDestination(
    route: '/wms-batches',
    label: 'Партии',
    icon: TeleposIcons.batches,
    isPrimary: true,
  );

  static const wmsSerials = NavDestination(
    route: '/wms-serials',
    label: 'Серии',
    icon: TeleposIcons.serials,
    isPrimary: true,
  );

  static const wmsCellStock = NavDestination(
    route: '/wms-cell-stock',
    label: 'Ячейки',
    icon: TeleposIcons.cellStock,
    isPrimary: true,
  );

  static const wmsClaims = NavDestination(
    route: '/wms-claims',
    label: 'Рекламации',
    icon: TeleposIcons.claims,
    isPrimary: true,
  );

  static const wmsMarking = NavDestination(
    route: '/wms-marking',
    label: 'Маркировка',
    icon: TeleposIcons.marking,
    isPrimary: true,
  );

  static const wmsSettings = NavDestination(
    route: '/wms-settings',
    label: 'Настройки WMS',
    icon: TeleposIcons.wmsSettings,
  );

  static const agent = NavDestination(
    route: '/agent',
    label: 'Контрагенты',
    icon: TeleposIcons.agent,
    permissionKey: PermissionKeys.navAgent,
  );

  static const supply = NavDestination(
    route: '/supply',
    label: 'Приёмка',
    icon: TeleposIcons.supply,
    permissionKey: PermissionKeys.navSupply,
  );

  static const stockRegistry = NavDestination(
    route: '/stock-registry',
    label: 'Склад',
    icon: TeleposIcons.warehouse,
    isPrimary: true,
    permissionKey: PermissionKeys.navSupply,
  );

  static const cashOperation = NavDestination(
    route: '/cash-operation',
    label: 'Касса',
    icon: TeleposIcons.cashOperation,
    isPrimary: true,
    permissionKey: PermissionKeys.navCashOperation,
  );

  static const settings = NavDestination(
    route: '/settings',
    label: 'Настройки',
    icon: TeleposIcons.settings,
    permissionKey: PermissionKeys.navSettings,
  );

  static const catalog = NavDestination(
    route: '/catalog',
    label: 'Каталог',
    icon: TeleposIcons.catalog,
    isPrimary: true,
    permissionKey: PermissionKeys.navCatalog,
  );

  static const reports = NavDestination(
    route: '/reports',
    label: 'Отчёты',
    icon: TeleposIcons.reports,
    isPrimary: true,
    permissionKey: PermissionKeys.navReports,
  );

  static const sync = NavDestination(
    route: '/sync',
    label: 'Синхронизация',
    icon: TeleposIcons.sync,
    permissionKey: PermissionKeys.navSync,
  );

  static const List<NavDestination> _retailAll = [
    sale,
    refund,
    shift,
    history,
    catalog,
    reports,
    agent,
    stockRegistry,
    cashOperation,
    settings,
    sync,
  ];

  static const List<NavDestination> _restaurantAll = [
    tables,
    orders,
    sale,
    shift,
    history,
    catalog,
    reports,
    agent,
    cashOperation,
    settings,
    sync,
  ];

  static const List<NavDestination> _serviceAll = [
    serviceQueue,
    serviceIntake,
    sale,
    shift,
    history,
    catalog,
    reports,
    agent,
    cashOperation,
    settings,
    sync,
  ];

  static const List<NavDestination> _warehouseAll = [
    wmsDashboard,
    wmsWarehouses,
    wmsBatches,
    wmsSerials,
    wmsCellStock,
    wmsMarking,
    wmsClaims,
    catalog,
    reports,
    agent,
    wmsSettings,
    settings,
    sync,
  ];

  static List<NavDestination> allForMode([
    OperatingMode mode = OperatingMode.retail,
  ]) {
    return switch (mode) {
      OperatingMode.retail => _retailAll,
      OperatingMode.restaurant => _restaurantAll,
      OperatingMode.service => _serviceAll,
      OperatingMode.warehouse => _warehouseAll,
    };
  }

  static const List<NavDestination> all = _retailAll;

  static List<NavDestination> primaryForMode([
    OperatingMode mode = OperatingMode.retail,
  ]) => allForMode(mode).where((d) => d.isPrimary).toList();

  static List<NavDestination> secondaryForMode([
    OperatingMode mode = OperatingMode.retail,
  ]) => allForMode(mode).where((d) => !d.isPrimary).toList();

  static List<NavDestination> get primary => primaryForMode();

  static List<NavDestination> get secondary => secondaryForMode();

  static bool _isAllowed(NavDestination d, Set<String> permissions) =>
      d.permissionKey == null || permissions.contains(d.permissionKey);

  static List<NavDestination> allForModeFiltered(
    OperatingMode mode,
    Set<String> permissions,
  ) => allForMode(mode).where((d) => _isAllowed(d, permissions)).toList();

  static List<NavDestination> primaryForModeFiltered(
    OperatingMode mode,
    Set<String> permissions,
  ) => allForModeFiltered(mode, permissions).where((d) => d.isPrimary).toList();

  static List<NavDestination> secondaryForModeFiltered(
    OperatingMode mode,
    Set<String> permissions,
  ) =>
      allForModeFiltered(mode, permissions).where((d) => !d.isPrimary).toList();

  static bool routeMatches(String currentRoute, String destRoute) {
    if (currentRoute == destRoute) return true;
    if (currentRoute.startsWith('$destRoute/')) return true;
    return false;
  }

  static NavDestination? fromRoute(
    String route, [
    OperatingMode mode = OperatingMode.retail,
  ]) {
    try {
      return allForMode(mode).firstWhere((d) => routeMatches(route, d.route));
    } catch (_) {
      return null;
    }
  }

  static int primaryIndexOf(
    String route, [
    OperatingMode mode = OperatingMode.retail,
  ]) {
    final primaryList = primaryForMode(mode);
    for (var i = 0; i < primaryList.length; i++) {
      if (routeMatches(route, primaryList[i].route)) return i;
    }
    return 0;
  }

  static int indexOf(
    String route, [
    OperatingMode mode = OperatingMode.retail,
  ]) {
    final items = allForMode(mode);
    for (var i = 0; i < items.length; i++) {
      if (routeMatches(route, items[i].route)) return i;
    }
    return 0;
  }

  static String defaultRoute([OperatingMode mode = OperatingMode.retail]) {
    return switch (mode) {
      OperatingMode.retail => '/sale',
      OperatingMode.restaurant => '/tables',
      OperatingMode.service => '/service-queue',
      OperatingMode.warehouse => '/wms',
    };
  }
}
