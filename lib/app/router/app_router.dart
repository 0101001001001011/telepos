import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/navigation/adaptive_scaffold.dart';
import 'package:telepos/presentation/common/navigation/nav_destinations.dart';
import 'package:telepos/presentation/screens/auth/login_screen.dart';
import 'package:telepos/presentation/screens/payment/payment_screen.dart';
import 'package:telepos/presentation/screens/refund/refund_screen.dart';
import 'package:telepos/presentation/screens/sale/sale_screen.dart';
import 'package:telepos/presentation/screens/agent/agent_screen.dart';
import 'package:telepos/presentation/screens/history/history_screen.dart';
import 'package:telepos/presentation/screens/setup/initial_setup_screen.dart';
import 'package:telepos/presentation/screens/setup/restore_or_new_screen.dart';
import 'package:telepos/presentation/screens/shift/shift_screen.dart';
import 'package:telepos/presentation/screens/shift/shift_history_screen.dart';
import 'package:telepos/presentation/screens/splash/splash_screen.dart';
import 'package:telepos/presentation/screens/additional/additional_screen.dart';
import 'package:telepos/presentation/screens/sync/sync_screen.dart';
import 'package:telepos/presentation/screens/settings/general_settings_screen.dart';
import 'package:telepos/presentation/screens/diagnostics/diagnostics_screen.dart';
import 'package:telepos/presentation/screens/settings/emulator_settings_screen.dart';
import 'package:telepos/presentation/screens/settings/terminal_service_settings_screen.dart';
import 'package:telepos/presentation/screens/settings/transport_settings_screen.dart';
import 'package:telepos/presentation/screens/settings/printer_settings_screen.dart';
import 'package:telepos/presentation/screens/settings/label_printer_settings_screen.dart';
import 'package:telepos/presentation/screens/label/label_templates_screen.dart';
import 'package:telepos/presentation/screens/label/label_template_editor_screen.dart';
import 'package:telepos/presentation/screens/settings/receipt/receipt_templates_screen.dart';
import 'package:telepos/presentation/screens/settings/receipt/receipt_template_editor_screen.dart';
import 'package:telepos/presentation/screens/certificate/certificate_issue_screen.dart';
import 'package:telepos/presentation/screens/prepayment/prepayment_refund_screen.dart';
import 'package:telepos/presentation/screens/credit/credit_contracts_screen.dart';
import 'package:telepos/presentation/screens/fiscal/unfiscalized_receipts_screen.dart';
import 'package:telepos/presentation/screens/settings/esf_outbox_screen.dart';
import 'package:telepos/presentation/screens/settings/esf_settings_screen.dart';
import 'package:telepos/presentation/screens/settings/fiscal_settings_screen.dart';
import 'package:telepos/presentation/screens/settings/qr_payment_setup_screen.dart';
import 'package:telepos/presentation/screens/settings/esutd_screen.dart';
import 'package:telepos/presentation/screens/settings/esutd_settings_screen.dart';
import 'package:telepos/presentation/screens/settings/snt_screen.dart';
import 'package:telepos/presentation/screens/settings/snt_settings_screen.dart';
import 'package:telepos/presentation/screens/settings/ismpt_settings_screen.dart';
import 'package:telepos/presentation/screens/settings/system_terminal_screen.dart';
import 'package:telepos/presentation/screens/stock/reorder_rules_screen.dart';
import 'package:telepos/presentation/screens/settings/restaurant_settings_screen.dart';
import 'package:telepos/presentation/screens/settings/accounts_settings_screen.dart';
import 'package:telepos/presentation/screens/settings/auth_settings_screen.dart';
import 'package:telepos/presentation/screens/settings/sessions_screen.dart';
import 'package:telepos/presentation/screens/settings/terminal_pairing_screen.dart';
import 'package:telepos/presentation/screens/settings/hardware_settings_screen.dart';
import 'package:telepos/presentation/screens/settings/appliance_settings_screen.dart';
import 'package:telepos/presentation/screens/settings/system_management_screen.dart';
import 'package:telepos/presentation/screens/settings/log_journal_screen.dart';
import 'package:telepos/presentation/screens/settings/network_settings_screen.dart';
import 'package:telepos/presentation/screens/settings/user_management_screen.dart';
import 'package:telepos/presentation/screens/reports/reports_screen.dart';
import 'package:telepos/presentation/screens/cash_operation/cash_operation_screen.dart';
import 'package:telepos/presentation/screens/supply/supply_screen.dart';
import 'package:telepos/presentation/screens/supply/dialogs/supply_dialog.dart';
import 'package:telepos/presentation/screens/writeoff/writeoff_screen.dart';
import 'package:telepos/presentation/screens/inventory/inventory_screen.dart';
import 'package:telepos/presentation/screens/stock_registry/stock_registry_screen.dart';
import 'package:telepos/presentation/screens/movement/movement_screen.dart';
import 'package:telepos/presentation/screens/movement/dialogs/movement_dialog.dart';
import 'package:telepos/presentation/screens/supplier_return/supplier_return_screen.dart';
import 'package:telepos/presentation/screens/supplier_return/dialogs/supplier_return_dialog.dart';
import 'package:telepos/presentation/screens/supplier_order/supplier_order_screen.dart';
import 'package:telepos/presentation/screens/markup/markup_settings_screen.dart';
import 'package:telepos/presentation/screens/promotion/promotions_screen.dart';
import 'package:telepos/presentation/screens/settings/discount_limits_screen.dart';
import 'package:telepos/presentation/screens/customer_display/customer_display_screen.dart';
import 'package:telepos/presentation/screens/telegram/telegram_auth_screen.dart';
import 'package:telepos/presentation/screens/telegram/staff_chat_screen.dart';
import 'package:telepos/presentation/screens/telegram/telegram_settings_screen.dart';
import 'package:telepos/presentation/screens/restaurant/table_map_screen.dart';
import 'package:telepos/presentation/screens/restaurant/table_detail_screen.dart';
import 'package:telepos/presentation/screens/restaurant/orders_screen.dart';
import 'package:telepos/presentation/screens/service/service_queue_screen.dart';
import 'package:telepos/presentation/screens/service/service_intake_screen.dart';
import 'package:telepos/presentation/screens/service/service_detail_screen.dart';
import 'package:telepos/presentation/screens/service/service_catalog_screen.dart';
import 'package:telepos/presentation/screens/catalog/catalog_screen.dart';
import 'package:telepos/presentation/screens/wms/wms_dashboard_screen.dart';
import 'package:telepos/presentation/screens/wms/warehouse_management_screen.dart';
import 'package:telepos/presentation/screens/wms/batch_tracking_screen.dart';
import 'package:telepos/presentation/screens/wms/serial_tracking_screen.dart';
import 'package:telepos/presentation/screens/wms/claims_screen.dart';
import 'package:telepos/presentation/screens/wms/cell_stock_screen.dart';
import 'package:telepos/presentation/screens/wms/marking_codes_screen.dart';
import 'package:telepos/presentation/screens/settings/wms_settings_screen.dart';

import 'app_routes.dart';

final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// The full route table: every screen the product has.
///
/// This file imports all of them, which is why nothing but an entry point may
/// import it — a screen that reaches in here for a path constant drags the
/// whole application behind it. Path constants live in `app_routes.dart`.
///
/// The browser binding uses `setup_router.dart` instead, and grows toward this
/// one screen by screen. See docs/ARCHITECTURE.md.
GoRouter createRouter() {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    routes: _buildRoutes(),
  );
}

List<RouteBase> _buildRoutes() {
  return [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.initialSetup,
      builder: (context, state) => const InitialSetupScreen(),
    ),
    GoRoute(
      path: AppRoutes.restoreOrNew,
      builder: (context, state) => const RestoreOrNewScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.payment,
      builder: (context, state) => const PaymentScreen(),
    ),
    GoRoute(
      path: AppRoutes.networkSettings,
      builder: (context, state) => const NetworkSettingsScreen(),
    ),
    GoRoute(
      path: AppRoutes.customerDisplay,
      builder: (context, state) => const CustomerDisplayScreen(),
    ),

    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return AdaptiveScaffold(currentRoute: state.uri.path, child: child);
      },
      routes: [
        GoRoute(
          path: AppRoutes.sale,
          pageBuilder: (context, state) =>
              const NoTransitionPage(
                child: SaleScreen(shiftClose: ShiftCloseHere(_openShift)),
              ),
        ),
        GoRoute(
          path: AppRoutes.refund,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: RefundScreen()),
        ),
        GoRoute(
          path: AppRoutes.shift,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ShiftScreen()),
        ),
        GoRoute(
          path: AppRoutes.shiftHistory,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ShiftHistoryScreen()),
        ),
        GoRoute(
          path: AppRoutes.history,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HistoryScreen()),
        ),
        GoRoute(
          path: AppRoutes.catalog,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CatalogScreen()),
        ),
        GoRoute(
          path: AppRoutes.reports,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ReportsScreen()),
        ),
        GoRoute(
          path: AppRoutes.agent,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AgentScreen()),
        ),
        GoRoute(
          path: AppRoutes.supply,
          pageBuilder: (context, state) => NoTransitionPage(
            child: _AdaptiveStockOperationPage(
              mobile: const SupplyScreen(),
              showDialog: SupplyDialog.show,
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.stockRegistry,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: StockRegistryScreen()),
        ),
        GoRoute(
          path: AppRoutes.supplierOrder,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SupplierOrderScreen()),
        ),
        GoRoute(
          path: AppRoutes.markupSettings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: MarkUpSettingsScreen()),
        ),
        GoRoute(
          path: AppRoutes.promotions,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: PromotionsScreen()),
        ),
        GoRoute(
          path: AppRoutes.discountLimits,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: DiscountLimitsScreen()),
        ),
        GoRoute(
          path: AppRoutes.movement,
          pageBuilder: (context, state) => NoTransitionPage(
            child: _AdaptiveStockOperationPage(
              mobile: const MovementScreen(),
              showDialog: MovementDialog.show,
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.supplierReturn,
          pageBuilder: (context, state) => NoTransitionPage(
            child: _AdaptiveStockOperationPage(
              mobile: const SupplierReturnScreen(),
              showDialog: SupplierReturnDialog.show,
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.cashOperation,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CashOperationScreen()),
        ),
        GoRoute(
          path: AppRoutes.settings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: GeneralSettingsScreen()),
        ),
        GoRoute(
          path: AppRoutes.terminalServiceSettings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: TerminalServiceSettingsScreen()),
        ),
        GoRoute(
          path: AppRoutes.diagnostics,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: DiagnosticsScreen()),
        ),
        GoRoute(
          path: AppRoutes.emulatorSettings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: EmulatorSettingsScreen()),
        ),
        GoRoute(
          path: AppRoutes.transportSettings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: TransportSettingsScreen()),
        ),
        GoRoute(
          path: AppRoutes.printerSettings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: PrinterSettingsScreen()),
        ),
        GoRoute(
          path: AppRoutes.labelPrinterSettings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: LabelPrinterSettingsScreen()),
        ),
        GoRoute(
          path: AppRoutes.labelTemplates,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: LabelTemplatesScreen()),
        ),
        GoRoute(
          path: AppRoutes.labelTemplateEdit,
          pageBuilder: (context, state) {
            final args = state.extra is LabelTemplateEditorArgs
                ? state.extra as LabelTemplateEditorArgs
                : const LabelTemplateEditorArgs();
            return NoTransitionPage(
              child: LabelTemplateEditorScreen(args: args),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.receiptTemplates,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ReceiptTemplatesScreen()),
        ),
        GoRoute(
          path: AppRoutes.receiptTemplateEdit,
          pageBuilder: (context, state) {
            final args = state.extra is ReceiptTemplateEditorArgs
                ? state.extra as ReceiptTemplateEditorArgs
                : const ReceiptTemplateEditorArgs();
            return NoTransitionPage(
              child: ReceiptTemplateEditorScreen(args: args),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.fiscalSettings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: FiscalSettingsScreen()),
        ),
        GoRoute(
          path: AppRoutes.qrProviderSettings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: QrPaymentSetupScreen()),
        ),
        GoRoute(
          path: AppRoutes.unfiscalizedReceipts,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: UnfiscalizedReceiptsScreen()),
        ),
        // Выпуск сертификата и повтор печати его слипа — дыра 1 ревизии
        // 2026-09-19. До этой строки `op.issueCertificate` охранял
        // операцию, которой кассир не мог вызвать ничем: право было, путь
        // отсутствовал. Разбор выбора места — в докстринге
        // `AppRoutes.certificateIssue`.
        GoRoute(
          path: AppRoutes.certificateIssue,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CertificateIssueScreen()),
        ),
        // Выдача аванса деньгами — дыра 2 ревизии 2026-09-19. Юзкейс
        // `CustomerPaymentUseCase.refundPrepayment` был заведён целиком и
        // до этой строки не звался ни одним экраном. Разбор выбора места —
        // в докстринге `AppRoutes.prepaymentRefund`.
        GoRoute(
          path: AppRoutes.prepaymentRefund,
          pageBuilder: (context, state) => NoTransitionPage(
            child: PrepaymentRefundScreen(
              // Покупатель едет параметром запроса, тем же приёмом и с тем
              // же умолчанием, что у `/credit-contracts` ниже: отсутствующий
              // или нечисловой — ноль, и касса ответит «покупатель не
              // найден» до всякой записи. Выдумывать покупателя нельзя — с
              // его счёта уходят деньги.
              agentLocalId:
                  int.tryParse(state.uri.queryParameters['agentId'] ?? '') ?? 0,
              agentName: state.uri.queryParameters['agentName'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.creditContracts,
          pageBuilder: (context, state) => NoTransitionPage(
            child: CreditContractsScreen(
              // Покупатель едет параметром запроса. Отсутствующий или
              // нечисловой — ноль: экран покажет «живых договоров нет», а
              // не упадёт разбором. Выдумывать покупателя нельзя — по нему
              // принимают деньги.
              agentLocalId:
                  int.tryParse(state.uri.queryParameters['agentId'] ?? '') ?? 0,
              agentName: state.uri.queryParameters['agentName'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.esfSettings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: EsfSettingsScreen()),
        ),
        GoRoute(
          path: AppRoutes.esfOutbox,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: EsfOutboxScreen()),
        ),
        GoRoute(
          path: AppRoutes.snt,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SntScreen()),
        ),
        GoRoute(
          path: AppRoutes.sntSettings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SntSettingsScreen()),
        ),
        GoRoute(
          path: AppRoutes.esutd,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: EsutdScreen()),
        ),
        GoRoute(
          path: AppRoutes.esutdSettings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: EsutdSettingsScreen()),
        ),
        GoRoute(
          path: AppRoutes.ismptSettings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: IsMptSettingsScreen()),
        ),
        GoRoute(
          path: AppRoutes.reorderRules,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ReorderRulesScreen()),
        ),
        GoRoute(
          path: AppRoutes.restaurantSettings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: RestaurantSettingsScreen()),
        ),
        GoRoute(
          path: AppRoutes.hardwareSettings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HardwareSettingsScreen()),
        ),
        GoRoute(
          path: AppRoutes.applianceSettings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ApplianceSettingsScreen()),
        ),
        GoRoute(
          path: AppRoutes.systemManagement,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SystemManagementScreen()),
        ),
        GoRoute(
          path: AppRoutes.systemTerminal,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SystemTerminalScreen()),
        ),
        GoRoute(
          path: AppRoutes.logJournal,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: LogJournalScreen()),
        ),
        GoRoute(
          path: AppRoutes.accountsSettings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AccountsSettingsScreen()),
        ),
        GoRoute(
          path: AppRoutes.userManagement,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: UserManagementScreen()),
        ),
        GoRoute(
          path: AppRoutes.authSettings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AuthSettingsScreen()),
        ),
        GoRoute(
          path: AppRoutes.sessions,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SessionsScreen()),
        ),
        GoRoute(
          path: AppRoutes.terminalPairing,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: TerminalPairingScreen()),
        ),
        GoRoute(
          path: AppRoutes.sync,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SyncScreen()),
        ),
        GoRoute(
          path: AppRoutes.writeoff,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: WriteoffScreen()),
        ),
        GoRoute(
          path: AppRoutes.inventory,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: InventoryScreen()),
        ),
        GoRoute(
          path: AppRoutes.additional,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AdditionalScreen()),
        ),
        GoRoute(
          path: AppRoutes.staffChat,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: StaffChatScreen()),
        ),
        GoRoute(
          path: AppRoutes.telegramSettings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: TelegramSettingsScreen()),
        ),
        GoRoute(
          path: AppRoutes.telegramSetup,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: TelegramAuthScreen()),
        ),

        GoRoute(
          path: AppRoutes.tables,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: TableMapScreen()),
        ),
        GoRoute(
          path: AppRoutes.tableDetail,
          pageBuilder: (context, state) {
            final tableId =
                int.tryParse(state.pathParameters['tableId'] ?? '') ?? 0;
            return NoTransitionPage(child: TableDetailScreen(tableId: tableId));
          },
        ),

        GoRoute(
          path: AppRoutes.orders,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: OrdersScreen()),
        ),
        GoRoute(
          path: AppRoutes.orderDetail,
          pageBuilder: (context, state) {
            final orderId =
                int.tryParse(state.pathParameters['orderId'] ?? '') ?? 0;
            return NoTransitionPage(child: TableDetailScreen(orderId: orderId));
          },
        ),

        GoRoute(
          path: AppRoutes.serviceQueue,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ServiceQueueScreen()),
        ),
        GoRoute(
          path: AppRoutes.serviceIntake,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ServiceIntakeScreen()),
        ),
        GoRoute(
          path: AppRoutes.serviceDetail,
          pageBuilder: (context, state) {
            final orderId =
                int.tryParse(state.pathParameters['orderId'] ?? '') ?? 0;
            return NoTransitionPage(
              child: ServiceDetailScreen(orderId: orderId),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.serviceCatalog,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ServiceCatalogScreen()),
        ),

        GoRoute(
          path: AppRoutes.wmsDashboard,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: WmsDashboardScreen()),
        ),
        GoRoute(
          path: AppRoutes.wmsWarehouses,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: WarehouseManagementScreen()),
        ),
        GoRoute(
          path: AppRoutes.wmsBatches,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: BatchTrackingScreen()),
        ),
        GoRoute(
          path: AppRoutes.wmsSerials,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SerialTrackingScreen()),
        ),
        GoRoute(
          path: AppRoutes.wmsCellStock,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CellStockScreen()),
        ),
        GoRoute(
          path: AppRoutes.wmsClaims,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ClaimsScreen()),
        ),
        GoRoute(
          path: AppRoutes.wmsMarking,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: MarkingCodesScreen()),
        ),
        GoRoute(
          path: AppRoutes.wmsSettings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: WmsSettingsScreen()),
        ),
      ],
    ),
  ];
}

class _AdaptiveStockOperationPage extends StatefulWidget {
  const _AdaptiveStockOperationPage({
    required this.mobile,
    required this.showDialog,
  });

  final Widget mobile;

  final Future<bool?> Function(BuildContext context) showDialog;

  @override
  State<_AdaptiveStockOperationPage> createState() =>
      _AdaptiveStockOperationPageState();
}

class _AdaptiveStockOperationPageState
    extends State<_AdaptiveStockOperationPage> {
  bool _dialogLaunched = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = Breakpoints.of(context) == LayoutType.mobile;

    if (isMobile) {
      return widget.mobile;
    }

    if (!_dialogLaunched) {
      _dialogLaunched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await widget.showDialog(context);
        if (mounted) context.go(AppRoutes.stockRegistry);
      });
    }

    return const ColoredBox(
      color: Colors.black12,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(Ref ref) {
    ref.listen<bool>(
      appStateProvider.select((s) => s.isLoggedIn),
      (_, __) => notifyListeners(),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthNotifier(ref);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: authNotifier,
    // Сторож таблицы маршрутов (задача 17, security-debt-closure). До задачи
    // 17 здесь проверялось только «вошёл — не вошёл» —
    // `PermissionKeys.routeToPermissionKey()` существовала (задача 12,
    // написана для браузерной таблицы, `setup_router.dart`), но десктопный
    // `redirect` её не звал вовсе: мёртвый код ровно там, где решался бы
    // вопрос. Настоящей защитой было «скрыть пункт меню»
    // (`nav_destinations.dart`, тем же ключом), а не маршрут — прямой переход
    // по адресу, набранный вручную, вставленный из `context.go` вручную
    // собранной строкой или пришедший из `AdditionalScreen` (её плитки не
    // сверяют право с тем, что видно в боковом меню), проходил у любого
    // вошедшего невозбранно.
    //
    // `permissionKey == null` пропускается молча — не умолчанием, а решением,
    // измеренным обходом `_buildRoutes()` (задача 17 закрытия
    // долга безопасности, правка «маршрут → ключ», следом за ней, и правка
    // «второй порядок» закрытия долга безопасности, 2026-08-22, пункт 1).
    // Число покрытых маршрутов менялось пять раз и посчитано заново каждый
    // раз, а не унаследовано текстом отчёта — читай счёт в
    // `route_permission_coverage_test.dart`, а не здесь: на 2026-08-27
    // `routeToPermissionKey()` покрывает 33 из 75 маршрутов,
    // зарегистрированных в `_buildRoutes()` (`grep -c 'path: AppRoutes\.'`
    // этого файла) — 15 `nav.*` (те же, что фильтрует пункт меню,
    // `NavDestinations`, тем же ключом), 8 `settings.*` (правка «маршрут →
    // ключ»), `/auth-settings` и `/sessions` (задачи 18/19, ключ
    // `settingsUsers`), `/terminal-service-settings`, `/log-journal`,
    // `/appliance-settings` (правка «второй порядок», пункт 1),
    // `/telegram-setup` (финальная волна, блокер 2 — было ошибочно названо
    // «нет ключа права ни для одной роли», хотя `settingsTelegram` уже
    // существовал для соседнего `/telegram-settings`), `/terminal-pairing`
    // (задача 2 работы «знакомство терминала с кассой», 2026-08-23, тот же
    // ключ `settingsUsers` — этот 75-й маршрут поднял оба числа с 74/32 до
    // 75/33, но докстринг здесь не обновили тогда же, отсюда и расхождение,
    // записанное в `docs/internal/ROADMAP.md` и закрытое этой правкой) и 3
    // параметрических, наследующих ключ родителя по префиксу. Полнота
    // проверяется тестом-сторожем
    // (`test/presentation/router/route_permission_coverage_test.dart`),
    // который обходит **все** маршруты `_buildRoutes()` и требует для
    // каждого либо ключ, либо запись в `AppRoutes.publicRoutes`, либо явное
    // имя в списке намеренно открытых — новый маршрут без решения красит
    // именно этот тест, а не остаётся тихим пробелом. Часть маршрутов (WMS,
    // документы ЕСФ/СНТ/ЕСУТД, складские операции, системные экраны,
    // закрытые другим механизмом — `ownerOnlyScaffold`, не ключом) вообще не
    // имеет соответствующего ключа права ни для одной роли — они в списке
    // намеренно открытых тем же тестом, а не пропущены случайно.
    redirect: (context, state) {
      final appState = ref.read(appStateProvider);
      final currentPath = state.uri.path;

      if (AppRoutes.publicRoutes.contains(currentPath)) {
        return null;
      }

      if (!appState.isLoggedIn) {
        return AppRoutes.login;
      }

      final permissionKey = PermissionKeys.routeToPermissionKey(currentPath);
      if (permissionKey != null && !appState.hasPermission(permissionKey)) {
        return _homeRoute(appState);
      }

      return null;
    },
    routes: _buildRoutes(),
  );
});

/// Куда сторож выше уводит вошедшего без права на запрошенный маршрут.
///
/// Не фиксированный адрес: `UserRole.user` (`PermissionKeys.roleDefaults`) не
/// держит `nav.sale` вовсе, и увод на `/sale` для этой роли завернул бы
/// `redirect` на себя же — `GoRouter` считает такие циклы ошибкой после
/// нескольких попыток вместо того, чтобы просто показать что-то. Взято то же
/// множество, каким уже отфильтрован пункт бокового меню
/// (`NavDestinations.primaryForModeFiltered`, тот же ключ права, тот же
/// режим торговли) — первое, что эта роль по-настоящему может открыть.
///
/// `AppRoutes.additional` — конечная защёлка на случай роли без единого
/// nav.*-права вовсе (в `PermissionKeys.roleDefaults` такой сегодня нет, но
/// таблица прав — allow-list, который заводится вручную, и пустой набор для
/// нового пользователя, которому никто ничего не отметил, — законное
/// состояние): у этого маршрута нет ключа права ни здесь, ни в боковом меню,
/// тем же решением, каким исполнен весь класс маршрутов без ключа выше.
String _homeRoute(AppState appState) {
  final primary = NavDestinations.primaryForModeFiltered(
    appState.operatingMode,
    appState.permissions,
  );
  if (primary.isNotEmpty) return primary.first.route;

  final any = NavDestinations.allForModeFiltered(
    appState.operatingMode,
    appState.permissions,
  );
  if (any.isNotEmpty) return any.first.route;

  return AppRoutes.additional;
}

/// Переход диалога просроченной смены — задача 37. Живёт в таблице, у которой
/// экран смены есть, а не в экране продажи, общем с браузером.
void _openShift(BuildContext context) => context.go(AppRoutes.shift);
