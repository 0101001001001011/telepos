import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/settings/builtin_emulator_settings.dart';
import 'package:telepos/hardware/cash_drawer/cash_drawer_journal.dart';
import 'package:telepos/hardware/display/customer_display_journal.dart';
import 'package:telepos/hardware/kaspi_pos/payment_terminal_journal.dart';
import 'package:telepos/emulators/builtin_emulator_host.dart';
import 'package:telepos/data/startup/startup_state_repository_local.dart';
import 'package:telepos/domain/startup/startup_state_repository.dart';
import 'package:telepos/data/terminal/terminal_identity_local.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/diagnostics/hardware_diagnostics.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/data/diagnostics/local_hardware_diagnostics.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/api_server_reachability.dart';
import 'package:telepos/backend/certificate_throttle.dart';
import 'package:telepos/backend/throttled_payment_service.dart';
import 'package:telepos/domain/auth/cashier_on_duty.dart';
import 'package:telepos/domain/payment/qr_provider_setup.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/security_journal.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/domain/auth/session_admin.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/data/device/device_check_local.dart';
import 'package:telepos/data/device/device_discovery_local.dart';
import 'package:telepos/domain/device/device_check.dart';
import 'package:telepos/domain/device/device_discovery.dart';
import 'package:telepos/data/network/network_repository_local.dart';
import 'package:telepos/domain/network/network_repository.dart';
import 'package:telepos/data/repositories/scanner_rules_repository_impl.dart';
import 'package:telepos/domain/repositories/scanner_rules_repository.dart';
import 'package:telepos/domain/sale/expiry_warning.dart';
import 'package:telepos/data/sale/local_expiry_warning.dart';
import 'package:telepos/data/stock/local_stock_changes.dart';
import 'package:telepos/domain/stock/stock_changes.dart';
import 'package:telepos/data/setup/setup_repository_local.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/app/di/device_catalog_module.dart';
import 'package:telepos/domain/device/emulated_scanner_source.dart';
import 'package:telepos/emulators/emulated_scanner.dart';
import 'package:telepos/app/di/hardware_module.dart';
import 'package:telepos/app/di/print_module.dart';
import 'package:telepos/app/di/telegram_module.dart';
// The four live driver types and the binding type, imported for
// [_liveDeviceDrivers] alone — it is the one place in this file that has to
// name a hardware class rather than just register a factory for it.
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/hardware/cash_drawer/cash_drawer_service.dart';
import 'package:telepos/hardware/label_printer/label_printer_service.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';
import 'package:telepos/hardware/scales/scales_service.dart';
import 'package:telepos/data/repositories/agent_repository_impl.dart';
import 'package:telepos/data/repositories/cash_operation_repository_impl.dart';
import 'package:telepos/data/repositories/payment_repository_impl.dart';
import 'package:telepos/data/repositories/product_repository_impl.dart';
import 'package:telepos/data/repositories/refund_repository_impl.dart';
import 'package:telepos/data/repositories/sale_repository_impl.dart';
import 'package:telepos/data/repositories/shift_repository_impl.dart';
import 'package:telepos/data/repositories/supply_repository_impl.dart';
import 'package:telepos/domain/repositories/agent_repository.dart';
import 'package:telepos/domain/repositories/cash_operation_repository.dart';
import 'package:telepos/domain/repositories/payment_repository.dart';
import 'package:telepos/domain/repositories/product_repository.dart';
import 'package:telepos/domain/repositories/refund_repository.dart';
import 'package:telepos/domain/repositories/sale_repository.dart';
import 'package:telepos/domain/repositories/shift_repository.dart';
import 'package:telepos/domain/repositories/supply_repository.dart';
import 'package:telepos/app/config/app_domain_delegate.dart';
import 'package:telepos/app/config/build_config.dart';
import 'package:telepos/data/sync/couchdb_sync_coordinator.dart';
import 'package:telepos/data/sync/couchdb_deferred_claim.dart';
import 'package:telepos/domain/sale/deferred_claim_port.dart';
import 'package:telepos/data/sync/couchdb_sync_engine.dart';
import 'package:telepos/app/config/local_properties.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/database_connection.dart';
import 'package:telepos/data/services/auth_service_impl.dart';
import 'package:telepos/data/services/currency_service_impl.dart';
import 'package:telepos/domain/services/currency_service.dart';
import 'package:telepos/data/services/global_product_import_service.dart';
import 'package:telepos/app/services/data_exchange_service.dart';
import 'package:telepos/app/services/first_launch_service.dart';
import 'package:telepos/app/services/old_sale_cleanup_service.dart';
import 'package:telepos/telegram/backup/telegram_backup_service.dart';
import 'package:telepos/data/services/role_identification_service_impl.dart';
import 'package:telepos/data/services/shift_service_impl.dart';
import 'package:telepos/data/usecases/shift/assemble_shift_receipt_use_case_impl.dart';
import 'package:telepos/data/usecases/shift/custom_bank_payments_sum_use_case_impl.dart';
import 'package:telepos/data/usecases/refund/refund_initiation_use_case_impl.dart';
import 'package:telepos/data/refund/local_refund_tender_gateway.dart';
import 'package:telepos/data/usecases/refund/refund_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_history_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/can_sale_be_refunded_use_case_impl.dart';
import 'package:telepos/data/refund/local_recent_receipts.dart';
import 'package:telepos/data/refund/local_refund_receipt_printer.dart';
import 'package:telepos/data/refund/local_refund_service.dart';
import 'package:telepos/data/discount/local_discount_policy.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/payment/local_certificate_issuer.dart';
import 'package:telepos/data/payment/local_certificate_slip_printer.dart';
import 'package:telepos/data/payment/local_certificate_slip_reprinter.dart';
import 'package:telepos/domain/payment/certificate_slip_printer.dart';
import 'package:telepos/data/payment/local_credit_service.dart';
import 'package:telepos/data/payment/qr_payment_desk.dart';
import 'package:telepos/data/receipt/local_receipt_template_setup.dart';
import 'package:telepos/domain/receipt/receipt_template_setup.dart';
import 'package:telepos/data/sale/local_payment_service.dart';
import 'package:telepos/data/sale/local_quick_product_catalog.dart';
import 'package:telepos/data/sale/local_sale_checkout_service.dart';
import 'package:telepos/data/sale/local_sale_edit_terms.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/last_sale_receipt_no_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_product_creation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/domain/services/auth_service.dart';
import 'package:telepos/domain/services/role_identification_service.dart';
import 'package:telepos/domain/services/shift_service.dart';
import 'package:telepos/domain/usecases/shift/assemble_shift_receipt_use_case.dart';
import 'package:telepos/domain/usecases/sale/sale_history_service.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';
import 'package:telepos/domain/usecases/sale/can_sale_be_refunded_use_case.dart';
import 'package:telepos/domain/refund/recent_receipts.dart';
import 'package:telepos/domain/refund/refund_receipt_printer.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/discount/discount_policy.dart';
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/domain/payment/certificate_issuer.dart';
import 'package:telepos/domain/payment/credit_service.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/sale/quick_product_catalog.dart';
import 'package:telepos/domain/sale/sale_checkout_service.dart';
import 'package:telepos/domain/sale/sale_edit_terms.dart';
import 'package:telepos/domain/usecases/sale/deferred_sale_service.dart';
import 'package:telepos/domain/usecases/sale/last_sale_receipt_no_use_case.dart';
import 'package:telepos/domain/usecases/sale/sale_initiation_use_case.dart';
import 'package:telepos/domain/usecases/sale/sale_product_creation_use_case.dart';
import 'package:telepos/domain/usecases/sale/sale_round_option_use_case.dart';
import 'package:telepos/domain/usecases/shift/custom_bank_payments_sum_use_case.dart';
import 'package:telepos/domain/usecases/refund/refund_initiation_use_case.dart';
import 'package:telepos/domain/usecases/refund/refund_use_case.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import 'package:telepos/domain/usecases/payment/payment_controller.dart';
import 'package:telepos/domain/usecases/payment/customer_payment_use_case.dart';
import 'package:telepos/domain/usecases/product/find_by_barcode_use_case.dart';
import 'package:telepos/domain/usecases/product/search_product_info_use_case.dart';
import 'package:telepos/domain/usecases/product/create_product_info_use_case.dart';
import 'package:telepos/domain/usecases/product/create_product_price_use_case.dart';
import 'package:telepos/domain/usecases/product/product_info_and_price_edition_use_case.dart';
import 'package:telepos/domain/usecases/product/restore_product_info_use_case.dart';
import 'package:telepos/domain/usecases/product/mark_up_use_case.dart';
import 'package:telepos/domain/usecases/agent/bonus_service.dart';
import 'package:telepos/domain/usecases/supply/create_supply_use_case.dart';
import 'package:telepos/domain/usecases/supply/save_supply_use_case.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_operation_receipt_service.dart';
import 'package:telepos/domain/usecases/fiscal/webkassa_service.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/data/fiscal/webkassa_provider.dart';
import 'package:telepos/data/fiscal/direct_ofd_provider.dart';
import 'package:telepos/data/fiscal/kassa24_provider.dart';
import 'package:telepos/data/fiscal/fiscal_replay_scheduler.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';
import 'package:telepos/data/fiscal/drift_fiscal_queue_store.dart';
import 'package:telepos/data/fiscal/fiscal_settings_store.dart';
import 'package:telepos/domain/fiscal/fiscal_provider_registry.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/data/esf/esf_outbox_store.dart';
import 'package:telepos/data/esf/esf_settings_store.dart';
import 'package:telepos/data/esf/prefs_esf_outbox_store.dart';
import 'package:telepos/data/esf/offline_esf_provider.dart';
import 'package:telepos/data/esf/kgd_esf_provider.dart';
import 'package:telepos/data/esf/webkassa_esf_transport.dart';
import 'package:telepos/domain/esf/esf_draft_builder.dart';
import 'package:telepos/domain/esf/esf_provider_registry.dart';
import 'package:telepos/domain/esf/esf_settings.dart';
import 'package:telepos/data/ismpt/ismpt_offline_queueing_provider.dart';
import 'package:telepos/data/ismpt/ismpt_settings_store.dart';
import 'package:telepos/data/ismpt/webkassa_ismpt_provider.dart';
import 'package:telepos/domain/ismpt/ismpt_provider_registry.dart';
import 'package:telepos/domain/ismpt/ismpt_service.dart';
import 'package:telepos/data/snt/webkassa_snt_provider.dart';
import 'package:telepos/data/snt/prefs_snt_document_store.dart';
import 'package:telepos/data/esutd/esutd_service.dart';
import 'package:telepos/data/esutd/esutd_settings_store.dart';
import 'package:telepos/data/snt/snt_service.dart';
import 'package:telepos/data/snt/snt_settings_store.dart';
import 'package:telepos/domain/snt/snt_assembly.dart';
import 'package:telepos/domain/snt/snt_provider_registry.dart';
import 'package:telepos/domain/snt/snt_settings.dart';
import 'package:telepos/domain/snt/snt_store.dart';
import 'package:telepos/data/usecases/fiscal/fiscal_service_impl.dart';
import 'package:telepos/data/fiscal/drift_fiscal_offset_settings_store.dart';
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';
import 'package:telepos/data/usecases/fiscal/this_pos_fiscal_settings_source.dart';
import 'package:telepos/data/usecases/fiscal/store_fiscal_settings_source.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/core/services/update/updater_service.dart';
import 'package:telepos/data/services/receipt_print_service_impl.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/product/create_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/product/create_product_price_use_case_impl.dart';
import 'package:telepos/data/usecases/product/product_info_and_price_edition_use_case_impl.dart';
import 'package:telepos/data/usecases/product/restore_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/product/mark_up_use_case_impl.dart';
import 'package:telepos/data/usecases/agent/bonus_service_impl.dart';
import 'package:telepos/data/usecases/supply/create_supply_use_case_impl.dart';
import 'package:telepos/data/usecases/supply/save_supply_use_case_impl.dart';
import 'package:telepos/data/usecases/cash_operation/cash_in_out_controller_impl.dart';
import 'package:telepos/data/usecases/writeoff/create_writeoff_use_case_impl.dart';
import 'package:telepos/data/usecases/cogs/calculate_cogs_use_case_impl.dart';
import 'package:telepos/data/usecases/supplier_return/apply_supplier_return_cogs_use_case.dart';
import 'package:telepos/domain/usecases/cogs/calculate_cogs_use_case.dart';
import 'package:telepos/data/usecases/inventory/create_inventory_use_case_impl.dart';
import 'package:telepos/domain/usecases/writeoff/create_writeoff_use_case.dart';
import 'package:telepos/domain/usecases/inventory/create_inventory_use_case.dart';
import 'package:telepos/data/usecases/cash_operation/cash_operation_receipt_service_impl.dart';
import 'package:telepos/data/usecases/fiscal/webkassa_service_impl.dart';
import 'package:telepos/data/usecases/restaurant/manage_tables_use_case_impl.dart';
import 'package:telepos/data/usecases/restaurant/table_status_use_case_impl.dart';
import 'package:telepos/data/usecases/restaurant/create_table_order_use_case_impl.dart';
import 'package:telepos/data/usecases/restaurant/add_items_to_order_use_case_impl.dart';
import 'package:telepos/data/usecases/restaurant/close_table_order_use_case_impl.dart';
import 'package:telepos/data/usecases/restaurant/split_bill_use_case_impl.dart';
import 'package:telepos/data/usecases/restaurant/transfer_table_use_case_impl.dart';
import 'package:telepos/data/usecases/restaurant/merge_tables_use_case_impl.dart';
import 'package:telepos/data/usecases/restaurant/calculate_service_charge_use_case_impl.dart';
import 'package:telepos/data/usecases/restaurant/get_open_orders_use_case_impl.dart';
import 'package:telepos/data/usecases/service/create_service_order_use_case_impl.dart';
import 'package:telepos/data/usecases/service/update_service_order_use_case_impl.dart';
import 'package:telepos/data/usecases/service/service_order_transition_use_case_impl.dart';
import 'package:telepos/data/usecases/service/add_service_mark_use_case_impl.dart';
import 'package:telepos/data/usecases/service/approve_service_mark_use_case_impl.dart';
import 'package:telepos/data/usecases/service/link_service_to_sale_use_case_impl.dart';
import 'package:telepos/data/usecases/service/find_service_orders_use_case_impl.dart';
import 'package:telepos/data/usecases/service/service_order_receipt_use_case_impl.dart';
import 'package:telepos/data/usecases/service/manage_service_types_use_case_impl.dart';
import 'package:telepos/domain/usecases/restaurant/manage_tables_use_case.dart';
import 'package:telepos/domain/usecases/restaurant/table_status_use_case.dart';
import 'package:telepos/domain/usecases/restaurant/create_table_order_use_case.dart';
import 'package:telepos/domain/usecases/restaurant/add_items_to_order_use_case.dart';
import 'package:telepos/domain/usecases/restaurant/close_table_order_use_case.dart';
import 'package:telepos/domain/usecases/restaurant/split_bill_use_case.dart';
import 'package:telepos/domain/usecases/restaurant/transfer_table_use_case.dart';
import 'package:telepos/domain/usecases/restaurant/merge_tables_use_case.dart';
import 'package:telepos/domain/usecases/restaurant/calculate_service_charge_use_case.dart';
import 'package:telepos/domain/usecases/restaurant/get_open_orders_use_case.dart';
import 'package:telepos/domain/usecases/service/create_service_order_use_case.dart';
import 'package:telepos/domain/usecases/service/update_service_order_use_case.dart';
import 'package:telepos/domain/usecases/service/service_order_transition_use_case.dart';
import 'package:telepos/domain/usecases/service/add_service_mark_use_case.dart';
import 'package:telepos/domain/usecases/service/approve_service_mark_use_case.dart';
import 'package:telepos/domain/usecases/service/link_service_to_sale_use_case.dart';
import 'package:telepos/domain/usecases/service/find_service_orders_use_case.dart';
import 'package:telepos/domain/usecases/service/service_order_receipt_use_case.dart';
import 'package:telepos/domain/usecases/service/manage_service_types_use_case.dart';
import 'package:telepos/data/usecases/payment/customer_payment_use_case_impl.dart';
import 'package:telepos/data/usecases/payment/payment_controller_impl.dart';
import 'package:telepos/data/usecases/refund/refund_product_service_impl.dart';
import 'package:telepos/domain/repositories/warehouse_repository.dart';
import 'package:telepos/domain/repositories/warehouse_zone_repository.dart';
import 'package:telepos/domain/repositories/warehouse_cell_repository.dart';
import 'package:telepos/domain/repositories/batch_repository.dart';
import 'package:telepos/domain/repositories/serial_repository.dart';
import 'package:telepos/domain/repositories/wms_config_repository.dart';
import 'package:telepos/domain/repositories/warranty_repository.dart';
import 'package:telepos/domain/repositories/cell_stock_repository.dart';
import 'package:telepos/data/repositories/warehouse_repository_impl.dart';
import 'package:telepos/data/repositories/warehouse_zone_repository_impl.dart';
import 'package:telepos/data/repositories/warehouse_cell_repository_impl.dart';
import 'package:telepos/data/repositories/batch_repository_impl.dart';
import 'package:telepos/data/repositories/serial_repository_impl.dart';
import 'package:telepos/data/repositories/wms_config_repository_impl.dart';
import 'package:telepos/data/repositories/warranty_repository_impl.dart';
import 'package:telepos/data/repositories/cell_stock_repository_impl.dart';
import 'package:telepos/domain/usecases/wms/manage_warehouse_use_case.dart';
import 'package:telepos/domain/usecases/wms/manage_cells_use_case.dart';
import 'package:telepos/domain/usecases/wms/batch_tracking_use_case.dart';
import 'package:telepos/domain/usecases/wms/serial_tracking_use_case.dart';
import 'package:telepos/domain/usecases/wms/cell_stock_use_case.dart';
import 'package:telepos/domain/usecases/wms/claim_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_config_use_case.dart';
import 'package:telepos/data/usecases/wms/manage_warehouse_use_case_impl.dart';
import 'package:telepos/data/usecases/wms/manage_cells_use_case_impl.dart';
import 'package:telepos/data/usecases/wms/batch_tracking_use_case_impl.dart';
import 'package:telepos/data/usecases/wms/serial_tracking_use_case_impl.dart';
import 'package:telepos/data/usecases/wms/cell_stock_use_case_impl.dart';
import 'package:telepos/data/usecases/wms/claim_use_case_impl.dart';
import 'package:telepos/data/usecases/wms/wms_config_use_case_impl.dart';
import 'package:telepos/domain/usecases/stock_rule/stock_rule_use_case.dart';
import 'package:telepos/data/usecases/stock_rule/stock_rule_use_case_impl.dart';
import 'package:telepos/data/catalog/local_selling_hours.dart';
import 'package:telepos/domain/catalog/selling_hours_repository.dart';
import 'package:telepos/data/tax/preset_country_rate_hint.dart';
import 'package:telepos/domain/tax/country_rate_hint.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies({required Talker logger}) async {
  getIt.registerSingleton<Talker>(logger);

  getIt.registerSingleton<BuildConfig>(BuildConfig.fromEnvironment());

  final localProperties = await LocalProperties.create();
  getIt.registerSingleton<LocalProperties>(localProperties);

  getIt.registerLazySingleton<TerminalIdentity>(
    () => PrefsTerminalIdentity(getIt<LocalProperties>().prefs),
  );

  getIt.registerLazySingleton<CouchDbSyncEngine>(
    () => CouchDbSyncEngine(prefs: localProperties.prefs),
  );

  // Занятие и отзыв отложенных чеков соседних касс. Один объект на обоих
  // читателей: корзина (подъём) и стойка смены (очистка при закрытии).
  getIt.registerLazySingleton<DeferredClaimPort>(
    () => CouchDbDeferredClaim(getIt<CouchDbSyncCoordinator>()),
  );
  getIt.registerLazySingleton<CouchDbSyncCoordinator>(
    () => CouchDbSyncCoordinator(
      db: getIt<AppDatabase>(),
      engine: getIt<CouchDbSyncEngine>(),
    ),
  );

  if (!getIt.isRegistered<AppDatabase>()) {
    // Read once, here, before the database opens — schema v27's migration
    // (lib/data/database/migrations/device_binding_migration.dart) needs the
    // installation-wide `hardware_settings` blob as a plain `String?` to fold
    // into `TerminalDeviceBindings`, and `AppDatabase` must never import
    // `shared_preferences` itself (see `AppDatabase.legacyHardwareSettingsBlobJson`'s
    // doc comment — `bin/telepos_backend.dart` imports `AppDatabase` directly
    // with no Flutter engine). Task 2 built this parameter and left it
    // unsupplied because `SharedPreferences` was registered nowhere in get_it
    // at the time; `localProperties.prefs` (registered above) is that same
    // `SharedPreferences` instance, so this is the wiring task 3 owns.
    final legacyHardwareSettingsBlobJson = localProperties.prefs.getString(
      'hardware_settings',
    );
    getIt.registerLazySingleton<AppDatabase>(
      () => AppDatabase(
        AppDatabaseConnection.create(),
        legacyHardwareSettingsBlobJson: legacyHardwareSettingsBlobJson,
      ),
    );
  }

  getIt.registerLazySingleton<GlobalProductImportService>(
    () => GlobalProductImportService(
      getIt<AppDatabase>().globalProductDao,
      getIt<AppDatabase>().categoryDao,
      getIt<AppDatabase>().productInfoDao,
      getIt<AppDatabase>().productPriceDao,
    ),
  );

  getIt.registerLazySingleton<FirstLaunchRepository>(
    () => FirstLaunchService(
      localProperties: getIt<LocalProperties>(),
      database: getIt<AppDatabase>(),
      backupService: getIt.isRegistered<TelegramBackupService>()
          ? getIt<TelegramBackupService>()
          : null,
    ),
  );

  getIt.registerLazySingleton<SetupRepository>(
    () => LocalSetupRepository(getIt<AppDatabase>()),
  );

  // Задача 21 закрытия долга безопасности: журнал событий безопасности —
  // первые настоящие вызывающие `SecurityEventDao.record` (докстринг
  // `lib/backend/security_journal.dart`). Заведён здесь, до `TerminalRepository`
  // и `SessionRegistry`/`LocalAuthRepository` чуть ниже, потому что все они —
  // его вызывающие, и им нужен уже собранный синглтон, а не второй экземпляр
  // на каждый вызывающий (тот же довод, что и у `AppDatabase` выше: два
  // объекта одного назначения в одном процессе расходятся молча).
  getIt.registerLazySingleton<SecurityJournal>(
    () => SecurityJournal(
      getIt<AppDatabase>().securityEventDao,
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<TerminalRepository>(
    () => LocalTerminalRepository(
      getIt<AppDatabase>(),
      journal: getIt<SecurityJournal>(),
    ),
  );

  // Задача 1 знакомства терминала с кассой: тот же приём, что у
  // `SessionRegistry` выше — синглтон get_it, а не поле, которое кто-то мог
  // бы завести второй раз рядом. `ApiServer.invites` (`main.dart`) берёт
  // именно этот экземпляр вместо своего умолчания (`PairingInvites()` в
  // конструкторе), а не второй список: код, мятый экраном привязки (задача 2)
  // и код, проверяемый `/ca.crt` (`ApiServer._rootCertificate`), обязаны быть
  // одним и тем же списком — см. докстринг у поля `invites` в
  // `lib/backend/api_server.dart`, который прямо называет второй список
  // ошибкой.
  getIt.registerLazySingleton<PairingInvites>(() => PairingInvites());

  // Пункт 6 волны правок «касса говорит, что набирать» (2026-08-23): синглтон
  // get_it, тем же приёмом, что и `PairingInvites` строкой выше — экран
  // привязки читает `url` отсюда вместо настройки `TerminalServiceChoice`,
  // а `main.dart` пишет сюда после каждого исхода `ApiServer.start()`. (Было
  // «читает `listening`/`url`» — неточно с самого этого комментария:
  // `listening` не звала ни строка в `lib/`, ни в тестах, и пункт 5
  // финальной волны правок, 2026-08-24, снял его как мёртвый — `url != null`
  // уже несёт тот же бит.) См. докстринг `ApiServerReachability` — там же
  // разбор, почему настройки для этого гейта недостаточно.
  getIt.registerLazySingleton<ApiServerReachability>(
    () => ApiServerReachability(),
  );

  // Задача 9: вход собирается один раз на процесс. `SessionRegistry` и
  // `LoginThrottle` — синглтоны get_it, а не поля, которые кто-то мог бы
  // завести второй раз рядом: два реестра сеансов в одном процессе означали
  // бы вход, выписанный в одном и разыскиваемый в другом, — устройство этого
  // не допускает, потому что `ApiServer` берёт `AuthRepository` только отсюда
  // (`lib/main.dart`), и второго места, где его строят на десктопе, нет.
  //
  // Срок бездействия читается один раз ЗДЕСЬ как исходное значение процесса —
  // то же решение и по той же причине, что и подъём `AppDatabase` выше.
  //
  // Задача 18, закрытие И31: до этой задачи `sessionIdleMinutes` менять было
  // нечем (экрана не было), и абзац этот заканчивался на предыдущем
  // предложении — оставляя открытым, действует ли смена без перезапуска.
  // Теперь действует: `idleTimeout` у `SessionRegistry` не `final` — экран
  // `AuthSettingsScreen` пишет новое значение туда же, в тот же синглтон,
  // сразу после успешной записи в базу (см. докстринг `SessionRegistry
  // .idleTimeout`). Читать из базы заново на каждый вход/операцию не
  // потребовалось: мутируемое поле даёт «действует сразу» дешевле лишнего
  // запроса.
  final authSettings = await getIt<AppDatabase>().thisPosDao.authSettings();
  getIt.registerLazySingleton<SessionRegistry>(
    () => SessionRegistry(
      idleTimeout: Duration(minutes: authSettings.sessionIdleMinutes),
      journal: getIt<SecurityJournal>(),
    ),
  );
  // Задача «второй порядок» закрытия долга безопасности (2026-08-22),
  // пункт 6: та же живая касса за узким портом `SessionAdmin`, а не
  // отдельный второй экземпляр — `SessionRegistry` уже реализует его
  // (`implements ... SessionAdmin`). Тот же приём, что уже разводит
  // `SessionLookup`/`TerminalSessionCheck` рядом (`main.dart`): экран (и
  // теперь браузерный биндинг, `WtSessionAdminRepository`) получает ровно
  // два действия, а не весь реестр сеансов.
  getIt.registerLazySingleton<SessionAdmin>(() => getIt<SessionRegistry>());
  getIt.registerLazySingleton<LoginThrottle>(() => LoginThrottle());
  getIt.registerLazySingleton<AuthRepository>(
    () => LocalAuthRepository(
      db: getIt<AppDatabase>(),
      sessions: getIt<SessionRegistry>(),
      throttle: getIt<LoginThrottle>(),
      logger: getIt<Talker>(),
      securityJournal: getIt<SecurityJournal>(),
    ),
  );

  // Plan 2, task 4: the device profile catalog and the binding repository a
  // settings screen saves through — see
  // lib/domain/terminal/device_binding_repository.dart for why this is a
  // second contract rather than a new method on TerminalRepository.
  // Каталог профилей — через `buildDeviceProfileCatalog()`, а не прямым
  // `BuiltinDeviceProfileCatalog()`: со сборочным ключом `TELEPOS_EMULATORS`
  // к встроенным профилям подмешиваются виртуальные (сканер и спулер — два
  // семейства из семи, у которых нет ни адреса, ни COM-порта). В магазинной
  // сборке условие сворачивается компилятором, и второго каталога там нет
  // вовсе — измерено, см. `docs/internal/testing-notes.md`.
  getIt.registerLazySingleton<DeviceProfileCatalog>(buildDeviceProfileCatalog);

  // Источник штрихкодов эмулятора — только на кассе и только со сборочным
  // ключом. Примесь `BarcodeScannerMixin` спрашивает у GetIt, есть ли
  // фабрика, и про реализацию ничего не знает: прямой импорт притянул бы
  // `dart:io` в браузерный бандл через экран продажи.
  if (kEmulatorsEnabled) {
    getIt.registerSingleton<EmulatedScannerSourceFactory>(
      ({required String file, String refuse = ''}) =>
          EmulatedScanner(file: file, refuse: refuse),
    );
  }

  getIt.registerLazySingleton<DeviceBindingRepository>(
    () => LocalDeviceBindingRepository(
      getIt<AppDatabase>(),
      getIt<DeviceProfileCatalog>(),
    ),
  );

  // Plan 2b, task 3: the two contracts the device settings screens' "искать"
  // and "проверить" buttons call. Registered here so the *same* screen code
  // works under both bindings — the browser build registers the HTTP
  // implementations of these very interfaces under the same keys
  // (`lib/web/main_web.dart`), and the screen never learns which one it got.
  //
  // `registerFactory`, not `registerLazySingleton`, for [DeviceCheck]: a
  // check must reflect the bindings as they are when the button is pressed,
  // not as they were at the first press of the process.
  //
  // **Finding I2 (final-fix round).** `DeviceCheckLocal` used to be handed
  // the hardware *singletons* — and every one of those was built by
  // `HardwareModule` from the bindings that existed at startup. An operator
  // who changed a port, saved, and pressed «проверить» was therefore checking
  // the old port and could be told `ok` for a configuration that does not
  // work. It is now handed `hardware_module.dart`'s own `build*` functions —
  // the same ones those singletons are built from — so the check builds a
  // driver from the binding it just read out of the database. One definition
  // of "how do I reach this device", two callers.
  //
  // **Round 2 of the same finding.** Building a driver unconditionally solved
  // the stale-binding half and created its own: with the binding *unchanged*,
  // the new driver aims at the endpoint the live one is already holding, and
  // an endpoint that admits one client (a printer on port 9100, an exclusive
  // COM port) refuses it — reporting `connectionFailed` for hardware that
  // works. `live:` below is what closes that: the check borrows the live
  // driver when the saved binding still describes the device that driver was
  // built from, and builds its own only when they differ. See
  // [_liveDeviceDrivers].
  getIt.registerLazySingleton<DeviceDiscovery>(
    () => DeviceDiscoveryLocal(catalog: getIt<DeviceProfileCatalog>()),
  );

  getIt.registerFactory<DeviceCheck>(
    () => DeviceCheckLocal(
      bindingRepository: getIt<DeviceBindingRepository>(),
      catalog: getIt<DeviceProfileCatalog>(),
      receiptPrinterFor: (binding) =>
          buildReceiptPrinterManager(binding, getIt<Talker>()),
      labelPrinterFor: (binding) =>
          buildLabelPrinterService(binding, getIt<Talker>()),
      cashDrawerFor: (binding) =>
          buildCashDrawerService(binding, getIt<Talker>()),
      scalesFor: (binding) => buildScalesService(binding, getIt<Talker>()),
      live: _liveDeviceDrivers(getIt),
    ),
  );

  // Задача «сетевые настройки по проводу» (спека 2026-08-24): тот же приём,
  // что и [DeviceDiscovery]/[DeviceCheck] выше — контроллер экрана
  // (`network_controller.dart`) и обработчик операции провода
  // (`main.dart`, `_localNetwork()`) резолвят один и тот же экземпляр, не
  // строят его каждый заново.
  getIt.registerLazySingleton<NetworkRepository>(
    () => NetworkRepositoryLocal(),
  );

  // The three И142 barcode rules an operator could read and migrate but not
  // set until this task — see the contract's doc comment.
  getIt.registerLazySingleton<ScannerRulesRepository>(
    () => LocalScannerRulesRepository(getIt<AppDatabase>()),
  );
  // Задача 45: читатель правил — тот же синглтон, а не второй рядом. Его
  // просит `BarcodeScannerMixin`, и в браузере под тем же типом стоит
  // `WtScannerRules`.
  getIt.registerLazySingleton<ScannerRulesReader>(
    () => getIt<ScannerRulesRepository>(),
  );

  getIt.registerLazySingleton<AppBootstrap>(
    () => AppDomainDelegate(logger: getIt<Talker>()),
  );

  getIt.registerLazySingleton<AuthService>(
    () => AuthServiceImpl(db: getIt<AppDatabase>(), logger: getIt<Talker>()),
  );

  getIt.registerLazySingleton<RoleIdentificationService>(
    () => RoleIdentificationServiceImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<ShiftService>(
    () => ShiftServiceImpl(db: getIt<AppDatabase>(), logger: getIt<Talker>()),
  );

  getIt.registerLazySingleton<CurrencyService>(
    () =>
        CurrencyServiceImpl(db: getIt<AppDatabase>(), logger: getIt<Talker>()),
  );

  registerPrintQueue(getIt);

  getIt.registerLazySingleton<ReceiptPrintService>(
    () => ReceiptPrintServiceImpl(logger: getIt<Talker>()),
  );

  getIt.registerLazySingleton<DataExchangeService>(
    () =>
        DataExchangeService(logger: getIt<Talker>(), db: getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<OldSaleCleanupService>(
    () => OldSaleCleanupService(
      logger: getIt<Talker>(),
      db: getIt<AppDatabase>(),
      settings: CleanupSettings.autonomousMode,
    ),
  );

  getIt.registerLazySingleton<UpdaterService>(
    () => UpdaterService(database: getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<SaleRepository>(
    () => SaleRepositoryImpl(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<ShiftRepository>(
    () => ShiftRepositoryImpl(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<RefundRepository>(
    () => RefundRepositoryImpl(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<PaymentRepository>(
    () => PaymentRepositoryImpl(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<AgentRepository>(
    () => AgentRepositoryImpl(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<SupplyRepository>(
    () => SupplyRepositoryImpl(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<CashOperationRepository>(
    () => CashOperationRepositoryImpl(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<CustomBankPaymentsSumUseCase>(
    () => CustomBankPaymentsSumUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<AssembleShiftReceiptUseCase>(
    () => AssembleShiftReceiptUseCaseImpl(
      db: getIt<AppDatabase>(),
      paymentsSumUseCase: getIt<CustomBankPaymentsSumUseCase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<SaleProductCreationUseCase>(
    () => SaleProductCreationUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<SaleUseCase>(
    () => SaleUseCaseImpl(db: getIt<AppDatabase>(), logger: getIt<Talker>()),
  );

  getIt.registerLazySingleton<DeferredSaleService>(
    () => DeferredSaleServiceImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<LastSaleReceiptNoUseCase>(
    () => LastSaleReceiptNoUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<CanSaleBeRefundedUseCase>(
    () => CanSaleBeRefundedUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<SaleHistoryService>(
    () => SaleHistoryServiceImpl(
      db: getIt<AppDatabase>(),
      canSaleBeRefundedUseCase: getIt<CanSaleBeRefundedUseCase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<SaleRoundOptionUseCase>(
    () => SaleRoundOptionUseCaseImpl(),
  );

  // Часы запрета продажи. Экран настройки спрашивает их отсюда; сама
  // проверка живёт внутри корзины и строит хранилище сама — иначе договор
  // пришлось бы протаскивать доводом через весь путь продажи.
  // Подсказка ставки для мастера. Договор в домене: каталог наборов живёт
  // в слое данных, и мастеру о нём знать нельзя.
  getIt.registerLazySingleton<CountryRateHint>(
    () => const PresetCountryRateHint(),
  );

  getIt.registerLazySingleton<SellingHoursRepository>(
    () => LocalSellingHours(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<SaleInitiationUseCase>(
    () => SaleInitiationUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  // Корзина как контракт (задача 7). Регистрируется под доменным типом:
  // браузерная реализация поверх провода (задача 12) встанет сюда же, и
  // экран продажи не узнает, какая из двух под ним.
  // Пределы скидки (задача 12) — **один объект на кассу**.
  //
  // До задачи 18 читателя строила себе `LocalCartService` сама
  // (`discountPolicy ?? LocalDiscountPolicy(db)`), и снаружи его достать
  // было нечем. Экрану предел нужен **до ввода** (задача 18: кассир обязан
  // видеть, до скольки можно, прежде чем набирать), и единственная
  // альтернатива регистрации — чтение `DiscountLimits` из виджета, то есть
  // второй источник предела рядом с тем, которым касса отказывает. Второго
  // источника не заводим: и корзина, и экран берут этот.
  getIt.registerLazySingleton<DiscountPolicy>(
    () => LocalDiscountPolicy(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<LocalCartService>(
    () => LocalCartService(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
      initiation: getIt<SaleInitiationUseCase>(),
      deferred: getIt<DeferredSaleService>(),
      rounding: getIt<SaleRoundOptionUseCase>(),
      findByBarcode: getIt<FindByBarcodeUseCase>(),
      searchProducts: getIt<SearchProductInfoUseCase>(),
      discountPolicy: getIt<DiscountPolicy>(),
      // Занятие отложенного чека соседней кассы. Обмена может не быть —
      // тогда `null`, и подъём ЧУЖОГО чека отказывается: исключительность
      // негарантируема, а продать корзину дважды хуже, чем не поднять.
      // Свой отложенный чек при этом поднимается как прежде.
      claim: getIt.isRegistered<DeferredClaimPort>()
          ? getIt<DeferredClaimPort>()
          : null,
    ),
  );
  getIt.registerLazySingleton<CartService>(() => getIt<LocalCartService>());

  // Подготовка чека к оплате (задача 8). Реализация зовёт `LocalCartService`
  // по имени класса, а не через контракт: ей нужен снимок **названного**
  // чека (`viewOfReceipt`), а контракт отвечает только про чек в работе
  // рабочего места. Обе регистрации указывают на один и тот же объект —
  // иначе у кассы было бы две корзины.
  getIt.registerLazySingleton<SaleCheckoutService>(
    () => LocalSaleCheckoutService(
      db: getIt<AppDatabase>(),
      cart: getIt<LocalCartService>(),
      logger: getIt<Talker>(),
    ),
  );

  // Условия правки строки (задача 44) — настройки кассы, предел скидки и
  // валюта для диалога правки. Тот же `DiscountPolicy`, что отдан корзине
  // выше: предел, показанный кассиру, и предел, которым касса отказывает, —
  // один объект. Тот же синглтон отдаётся проводу (`main.dart`,
  // `sale.editTerms`).
  getIt.registerLazySingleton<SaleEditTermsReader>(
    () => LocalSaleEditTerms(
      db: getIt<AppDatabase>(),
      discountPolicy: getIt<DiscountPolicy>(),
      currency: getIt<CurrencyService>(),
      logger: getIt<Talker>(),
    ),
  );

  // Выпуск подарочных сертификатов (задача 21). Под доменным типом, как и
  // всё остальное здесь: `ApiServer` резолвит его для операции провода
  // `pay.certificateIssue`, и вторая копия рядом означала бы второй
  // источник правды о том, какой счёт обязательства у этой кассы.
  //
  // **Аннотации `@LazySingleton` для этого недостаточно, и это замер, а
  // не осторожность:** соседний `PaymentKindCatalogImpl` носит ту же
  // аннотацию с задачи 14, а во всём `lib/` не резолвится ни разу —
  // порождённая настройка injectable этот узел не собирает. Регистрация
  // руками здесь — единственное, что делает выпуск достижимым из
  // продукта.
  // Слип сертификата (решение заказчика 2026-09-16). Один узел на обе дороги
  // выпуска — при продаже и при возврате: две печати одного документа
  // разошлись бы молча.
  getIt.registerLazySingleton<CertificateSlipPrinter>(
    () => LocalCertificateSlipPrinter(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<CertificateIssuer>(
    () => LocalCertificateIssuer(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
      // Без этого довода выпуск не печатает ничего, и покупатель уходит с
      // пустыми руками — ровно то, что решение 2026-09-16 закрывает.
      slips: getIt<CertificateSlipPrinter>(),
    ),
  );

  // Повтор печати слипа — решение заказчика 2026-09-18. Две строки связки
  // («найти бумажку» + «отправить слип») до этого дня жили в экране
  // `CertificateIssueScreen._reprint`; с появлением планшета им понадобилась
  // вторая реализация, и порт — единственная форма, при которой вкладка не
  // печатает по своим полям. Разбор — в докстринге
  // `LocalCertificateSlipReprinter`.
  getIt.registerLazySingleton<CertificateSlipReprinter>(
    () => LocalCertificateSlipReprinter(
      certificates: getIt<CertificateIssuer>(),
      slips: getIt<CertificateSlipPrinter>(),
    ),
  );

  // Рассрочка (задача 24). Регистрируется руками по тому же доводу, что
  // и выпуск сертификата: порождённая настройка injectable этот ярус не
  // собирает, и без строки здесь `CreditService` не резолвился бы ни разу
  // — то есть экран договоров был бы мёртвым кодом, выглядящим живым.
  //
  // Раскладка оплаты (`LocalPaymentService`) свою службу заводит сама и
  // сюда не смотрит: у неё нет состояния, кроме базы, и связывать приём
  // денег с порядком регистрации значило бы завести ещё одно место, где
  // касса не берёт деньги из-за настройки. Этот узел — для **экрана и
  // погашения**.
  getIt.registerLazySingleton<CreditService>(
    () => LocalCreditService(db: getIt<AppDatabase>(), logger: getIt<Talker>()),
  );

  // Стойка QR: настройка провайдера → разговор с провайдером. **Один
  // экземпляр на кассу**, и потому здесь, а не умолчанием внутри оплаты:
  // его же зовёт разбор намерений при подъёме (`lib/main.dart`), и два
  // экземпляра держали бы два HTTP-клиента к одному провайдеру.
  //
  // До этой строки `QrPaymentCoordinator` и `HttpQrPaymentProvider` не
  // создавал никто — ни здесь, ни в `main.dart`, ни в `lib/web/`.
  getIt.registerLazySingleton<QrPaymentDesk>(
    () => QrPaymentDesk(db: getIt<AppDatabase>(), logger: getIt<Talker>()),
  );
  // Экран настройки QR на кассе (пункт 8 C, 2026-09-15) — **тот же**
  // экземпляр стойки: сохранение сбрасывает её клиента провайдера, и второй
  // экземпляр продолжал бы говорить с прежним адресом.
  getIt.registerLazySingleton<QrProviderSetupRepository>(
    () => getIt<QrPaymentDesk>(),
  );

  // Шаблон чека на кассе — решение заказчика 2026-09-18. **Та же служба
  // печати**, что печатает: шаблон кэширован внутри неё
  // (`_optionsCache`), и правка обязана сбросить кэш того экземпляра,
  // который напечатает следующий чек. Второй экземпляр службы печати
  // означал бы, что владелец правит подвал, видит правку в предпросмотре и
  // получает из принтера прежний — разбор в докстринге
  // `ReceiptTemplateSetupHost`.
  //
  // Порт регистрируется здесь, хотя на проводе его отдаёт раскладка оплаты
  // (`LocalPaymentService.receiptTemplates`), и это не два пути к шаблону:
  // `ReceiptPrintService` в контейнере — синглтон, тот же самый, который
  // раскладка получает доводом. Экрану кассы контейнер нужен потому, что он
  // резолвит **доменный порт**, а не раскладку оплаты, — ровно как
  // браузерный экран резолвит его же, только с проводом под ним.
  getIt.registerLazySingleton<ReceiptTemplateSetupRepository>(
    () => LocalReceiptTemplateSetup(
      db: getIt<AppDatabase>(),
      printer: getIt<ReceiptPrintService>(),
    ),
  );

  // Оплата как контракт (задача 14). Под доменным типом, как и корзина:
  // браузерная реализация (`WtPaymentService`) встанет сюда же, и экран
  // оплаты не узнает, какая из двух под ним.
  //
  // `BonusService` берётся лениво внутри замыкания, а не доводом снаружи:
  // начисление кэшбэка необязательно (докстринг поля в реализации), и
  // требовать его регистрации ради оплаты значило бы связать приём денег с
  // бонусной программой.
  //
  // Пункт 5 A7 (2026-09-15): под контрактом — `ThrottledPaymentService`,
  // обёртка, пропускающая проверку сертификата через **один на кассу**
  // `CertificateThrottle`. Экран оплаты самой кассы зовёт контракт мимо
  // провода и до этой строки перебирал номера и ПИНы без предела. Тот же
  // замок `main.dart` отдаёт `ApiServer`: счёт номера у кассы и у провода
  // один, а двойного счёта нет (`CertificateThrottle.guard`, «вложенный
  // вызов»). Срабатывание — в журнал безопасности (пункт 4 A7).
  // Кассир, вошедший на самой кассе: пишет экран входа, читает замок
  // сертификатов. Один экземпляр под двумя именами — узкий порт читающему,
  // запись — только экрану входа.
  getIt.registerLazySingleton<CashierOnDutyHolder>(CashierOnDutyHolder.new);
  getIt.registerLazySingleton<CashierOnDuty>(
    () => getIt<CashierOnDutyHolder>(),
  );
  getIt.registerLazySingleton<CertificateThrottle>(
    () => CertificateThrottle(
      onLocked: certificateLockJournalHandler(getIt<SecurityJournal>()),
    ),
  );
  getIt.registerLazySingleton<PaymentService>(
    () => ThrottledPaymentService(
      throttle: getIt<CertificateThrottle>(),
      // Счёт — по кассиру, вошедшему на кассе (решение заказчика
      // 2026-09-15); пишет его экран входа (`LoginNotifier._onSession`).
      cashier: getIt<CashierOnDuty>(),
      LocalPaymentService(
        db: getIt<AppDatabase>(),
        checkout: getIt<SaleCheckoutService>(),
        sale: getIt<SaleUseCase>(),
        logger: getIt<Talker>(),
        bonuses: getIt.isRegistered<BonusService>()
            ? getIt<BonusService>()
            : null,
        // Потолок возраста смены порта больше не имеет (задача 27): правило
        // `ShiftAgeRule` служба строит сама над той же базой, и «собрали без
        // порта — проверки нет» стало невозможно по построению.
        // Три действия кассы по завершении оплаты (задача 16): фискальный
        // документ, печать чека и денежный ящик. Печать и ящик жили в
        // `payment_screen.dart` — то есть на **терминале**, у которого их
        // нет; фискализация жила внутри `SaleUseCaseImpl.perform`, где её
        // исход некому было увидеть. Печать и ящик необязательны: касса без
        // принтера или без ящика продолжает торговать.
        //
        // Фискальный порт — **обязателен** (задача 3). Незарегистрированный
        // `FiscalService` больше не превращается в ноль: он превращается в
        // сказанное вслух «узла фискализации в этой сборке нет», и каждый чек
        // получает `FiscalState.fiscalModuleAbsent` с записью в журнал.
        //
        // **Отрицательная ветвь этого тернарника в собранной кассе не
        // срабатывает, и это измерено, а не предположено.**
        // `FiscalService` регистрируется ниже по этой же функции (строка
        // ~1265), безусловно, а `PaymentService` — ленивый одиночка: к
        // моменту его первого разрешения регистрация уже прошла. Ни
        // `unregister<FiscalService>`, ни `getIt.reset` в `lib/` не
        // встречаются, ранних выходов между строками 831 и 1265 нет.
        // Значит `FiscalState.fiscalModuleAbsent` сегодня достижим **только
        // из проб** (`completion_side_effects_test.dart`), и так было уже
        // после задачи 5 — задача 3 этого не сделала и не исправила.
        // Ветвь оставлена намеренно: она названа, она пишет в журнал и она
        // не крашится, а `getIt<FiscalService>()` без регистрации уронил бы
        // кассу на приёме денег. Если состояние решат считать мёртвым —
        // решение принимает владелец плана (колонка `Sales.fiscalState`,
        // задача 14, собирается хранить его код), а не эта строка.
        fiscal: getIt.isRegistered<FiscalService>()
            ? getIt<FiscalService>()
            : const RefusingFiscalService(),
        // Место для **записи о беде**, не для повтора: разбор в докстринге
        // `SaleOutcome.fiscal`.
        fiscalQueue: getIt.isRegistered<FiscalQueueStore>()
            ? getIt<FiscalQueueStore>()
            : null,
        printer: getIt.isRegistered<ReceiptPrintService>()
            ? getIt<ReceiptPrintService>()
            : null,
        drawer: () => _openCashDrawer(getIt),
        qr: getIt<QrPaymentDesk>(),
        // «Остатки изменились» — пункт 12 ревизии 2026-09-19. Один и тот же
        // одиночка, что отдаёт подписку `stock.revision` браузерным
        // терминалам и поднимает счётчик экранов самой кассы: завершение
        // продажи с **любого** рабочего места проходит через эту службу.
        stockChanges: getIt<LocalStockChanges>(),
      ),
    ),
  );

  // Сетка быстрых товаров экрана продажи (задача 8): три DAO, которые
  // читал сам виджет, ушли за контракт.
  getIt.registerLazySingleton<QuickProductCatalog>(
    () => LocalQuickProductCatalog(db: getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<RefundInitiationUseCase>(
    () => RefundInitiationUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<RefundUseCase>(
    () => RefundUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
      // Фискальный возврат — **доводом, а не поиском в `GetIt`**. До этой
      // правки возврат доставал службу сам, внутри `try`, и «в сборке нет
      // фискализации» уходило в ту же строку журнала, что и «оператор
      // отказал»: приёмка 2026-09-17 нашла стенд, полгода проводивший
      // возвраты без документа и выглядевший при этом исправным.
      //
      // Разрешается **лениво**, при первом обращении к `RefundUseCase`:
      // `FiscalService` регистрируется ниже по этой же функции, и к тому
      // моменту регистрация уже прошла. Тем же приёмом собран
      // `CustomerPaymentUseCase` дальше по файлу.
      fiscal: getIt<FiscalService>(),
      // Возврат безнала тем же путём, каким пришли деньги (задача 26).
      tenders: LocalRefundTenderGateway(
        db: getIt<AppDatabase>(),
        logger: getIt<Talker>(),
        qr: getIt<QrPaymentDesk>(),
      ),
      // Новая бумажка, выпущенная возвратом, обязана выйти на бумаге: её
      // номер (`<исходный>-R<возврат>`) живёт только на слипе.
      slips: getIt<CertificateSlipPrinter>(),
    ),
  );

  getIt.registerLazySingleton<RefundProductService>(
    () => RefundProductServiceImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  // Возврат за контрактом (задача 18). Регистрируется **доменным** типом:
  // экран и обработчики провода зовут `RefundService`, а какая под ним
  // реализация — кассовая или браузерная (задача 20) — их не касается.
  // Тот же приём и тот же порядок, что у `CartService` выше.
  // Печать чека возврата — железо и база кассы, и с задачи 20 она
  // принадлежит кассе, а не экрану: возврат, оформленный с браузерного
  // терминала, печатается здесь же (шаг 7 спеки).
  getIt.registerLazySingleton<RefundReceiptPrinter>(
    () => LocalRefundReceiptPrinter(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  // Подсказка «последние чеки» для диалога ввода номера. У браузерного
  // терминала этого контракта нет вовсе (своей операции провода у списка не
  // заведено) — диалог спрашивает его условно.
  getIt.registerLazySingleton<RecentReceipts>(
    () => LocalRecentReceipts(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<LocalRefundService>(
    () => LocalRefundService(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
      initiation: getIt<RefundInitiationUseCase>(),
      refunds: getIt<RefundUseCase>(),
      canBeRefunded: getIt<CanSaleBeRefundedUseCase>(),
      // Тот же ящик и тем же телом, что у продажи (`drawer:` у
      // `LocalPaymentService` выше): возврат с наличной частью выдаёт деньги
      // из того же ящика, в который продажа их положила. До приёмки
      // 2026-09-17 довода не было вовсе, и ящик у возврата не открывался.
      drawer: () => _openCashDrawer(getIt),
      printer: getIt<RefundReceiptPrinter>(),
    ),
  );
  getIt.registerLazySingleton<RefundService>(() => getIt<LocalRefundService>());

  getIt.registerLazySingleton<PaymentController>(
    () => PaymentControllerImpl(logger: getIt<Talker>()),
  );

  getIt.registerLazySingleton<CustomerPaymentUseCase>(
    () => CustomerPaymentUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
      fiscal: getIt<FiscalService>(),
    ),
  );

  getIt.registerLazySingleton<FindByBarcodeUseCase>(
    () => FindByBarcodeUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<SearchProductInfoUseCase>(
    () => SearchProductInfoUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<CreateProductInfoUseCase>(
    () => CreateProductInfoUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<CreateProductPriceUseCase>(
    () => CreateProductPriceUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<ProductInfoAndPriceEditionUseCase>(
    () => ProductInfoAndPriceEditionUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<RestoreProductInfoUseCase>(
    () => RestoreProductInfoUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<MarkUpUseCase>(
    () => MarkUpUseCaseImpl(db: getIt<AppDatabase>(), logger: getIt<Talker>()),
  );

  getIt.registerLazySingleton<BonusService>(() => BonusServiceImpl());

  getIt.registerLazySingleton<CreateSupplyUseCase>(
    () => CreateSupplyUseCaseImpl(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<SaveSupplyUseCase>(
    () => SaveSupplyUseCaseImpl(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<CashInOutController>(
    () => CashInOutControllerImpl(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<CashOperationReceiptService>(
    () => CashOperationReceiptServiceImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<WebKassaService>(
    () => WebKassaServiceImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
      settingsSource: getIt<FiscalSettingsSource>(),
    ),
  );

  getIt.registerLazySingleton<FiscalQueueStore>(
    () => DriftFiscalQueueStore(getIt<AppDatabase>()),
  );

  // Диагностика оборудования — план `2026-09-19-hardware-diagnostics.md`.
  //
  // Один порт на обе поверхности: этот же договор вкладки диагностики
  // спрашивают и на кассе, и в браузере (там под ним `WtHardwareDiagnostics`,
  // `lib/web/main_web.dart`). Вкладка — один и тот же файл; различие целиком
  // в том, какая реализация лежит здесь.
  //
  // `registerLazySingleton`, а не `registerFactory`: ту же самую очередь
  // печати, из которой касса печатает, диагностика обязана и читать. Второй
  // экземпляр очереди здесь означал бы экран, показывающий **чужую** очередь
  // — пустую при работающем принтере.
  //
  // `isRegistered` у трёх из четырёх сотрудников: очередь печати и служба
  // печати заводятся `print_module` только там, где есть принтер, а очередь
  // фискализации — строкой выше, но обе точки входа поднимают модули в
  // разном составе. Отсутствие названо **значением** (`available: false`,
  // `configured: false`), а не пустым списком: «касса ничего не печатала» и
  // «печатать нечем» — для наладчика разные ответы.
  getIt.registerLazySingleton<HardwareDiagnosticsRepository>(
    () => LocalHardwareDiagnostics(
      terminals: getIt<TerminalRepository>(),
      queue: getIt.isRegistered<PrintQueue>() ? getIt<PrintQueue>() : null,
      printer: getIt.isRegistered<ReceiptPrintService>()
          ? getIt<ReceiptPrintService>()
          : null,
      db: getIt<AppDatabase>(),
      fiscalQueue: getIt<FiscalQueueStore>(),
      // Ящик, дисплей и весы — пункт 4 того же плана. Все три спрашиваются
      // `isRegistered`, и у каждого свой законный повод отсутствовать:
      // журнал ящика заводится ниже по этому же файлу, журнал дисплея — в
      // `hardware_module` и только там, где дисплей вообще есть, а весы
      // регистрируются лишь при привязке (их нет на большинстве касс).
      //
      // Отсутствие названо **значением** (`available: false`,
      // `bound: false`), а не пустым списком: «ящик не звали» и «спросить
      // нечем» — для наладчика разные ответы, и на первом он пошёл бы искать
      // обрыв в проводке исправного ящика.
      //
      // Тот же экземпляр журнала, что пишет касса, а не второй: копия
      // показывала бы пустой экран при работающем ящике.
      drawerJournal: getIt.isRegistered<CashDrawerJournal>()
          ? getIt<CashDrawerJournal>()
          : null,
      displayJournal: getIt.isRegistered<CustomerDisplayJournal>()
          ? getIt<CustomerDisplayJournal>()
          : null,
      scales: getIt.isRegistered<ScalesService>()
          ? getIt<ScalesService>()
          : null,
    ),
  );

  getIt.registerLazySingleton<FiscalProviderRegistry>(
    () => FiscalProviderRegistry()
      ..register(
        FiscalOperatorType.webkassa,
        (settings) => OfflineQueueingProvider(
          inner: WebKassaProvider(settings: settings, logger: getIt<Talker>()),
          store: getIt<FiscalQueueStore>(),
          isReachable: () async => true,
          onOperatorReached: _kickFiscalReplay,
        ),
      )
      ..register(
        FiscalOperatorType.directOfd,
        (settings) => OfflineQueueingProvider(
          inner: DirectOfdProvider(settings),
          store: getIt<FiscalQueueStore>(),
          isReachable: () async => true,
          onOperatorReached: _kickFiscalReplay,
        ),
      )
      ..register(
        FiscalOperatorType.kassa24,
        (settings) => OfflineQueueingProvider(
          inner: Kassa24Provider(settings),
          store: getIt<FiscalQueueStore>(),
          isReachable: () async => true,
          onOperatorReached: _kickFiscalReplay,
        ),
      ),
  );

  getIt.registerLazySingleton<FiscalSettingsSource>(
    () => StoreFiscalSettingsSource(
      store: FiscalSettingsStore(localProperties.prefs),
      fallback: ThisPosFiscalSettingsSource(db: getIt<AppDatabase>()),
    ),
  );

  getIt.registerLazySingleton<FiscalOffsetSettingsStore>(
    () => DriftFiscalOffsetSettingsStore(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<FiscalService>(
    () => FiscalServiceImpl(
      db: getIt<AppDatabase>(),
      registry: getIt<FiscalProviderRegistry>(),
      settingsSource: getIt<FiscalSettingsSource>(),
      logger: getIt<Talker>(),
    ),
  );

  // Держатель встроенных эмуляторов. Регистрируется всегда — построение
  // ничего не открывает, — а поднимается по решению оператора
  // (`startBuiltinEmulators`). Флаг сборки `kEmulatorsEnabled` здесь ни при
  // чём: он про подставные классы, а это настоящий сокет, см.
  // `BuiltinEmulatorChoice`.
  // Память об импульсах ящика. Единственное, что у кассы о ящике вообще
  // есть: обратной связи от соленоида нет ни на одном пути.
  getIt.registerLazySingleton<CashDrawerJournal>(CashDrawerJournal.new);

  // Память об обменах с терминалом оплаты — общий на процесс экземпляр, а не
  // новый: `KaspiPosService` в контейнере не живёт, он создаётся заново на
  // каждую операцию, и запись идёт в `PaymentTerminalJournal.shared`.
  // Регистрация здесь — чтобы читатель доставал журнал тем же способом, что и
  // журналы ящика и дисплея.
  getIt.registerLazySingleton<PaymentTerminalJournal>(
    () => PaymentTerminalJournal.shared,
  );

  getIt.registerLazySingleton<BuiltinEmulatorHost>(
    () => BuiltinEmulatorHost(
      logger: getIt<Talker>(),
      // Откуда держатель узнаёт, боевая ли касса. Проводка здесь, а не внутри
      // держателя: ему запрещено трогать контейнер зависимостей — на это стоит
      // сторож, читающий его исходник. Не дать это замыкание значит запретить
      // эмулятор ОФД совсем: неизвестность читается как «касса боевая».
      fiscalSettings: () => getIt<FiscalSettingsSource>().load(),
    ),
  );

  // Круг повтора очереди фискализации. Регистрируется здесь, а **заводится**
  // в `main.dart` (`startFiscalReplay`): этот граф собирает и сквозной стенд
  // набора, и висящий периодический таймер ронял бы там `testWidgets`.
  getIt.registerLazySingleton<FiscalReplayScheduler>(
    () => FiscalReplayScheduler(
      resolve: () async {
        final settings = await getIt<FiscalSettingsSource>().load();
        final provider = getIt<FiscalProviderRegistry>().resolve(settings);
        return provider is OfflineQueueingProvider ? provider : null;
      },
      isShiftOpen: () async {
        final shift = await getIt<AppDatabase>().shiftDao.findOpenedShift();
        return shift != null && shift.isOpened;
      },
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<EsfOutboxStore>(
    () => PrefsEsfOutboxStore(localProperties.prefs),
  );

  getIt.registerLazySingleton<EsfProviderRegistry>(
    () => EsfProviderRegistry()
      ..register(
        EsfOperatorType.kgdEsf,
        (settings) => OfflineEsfProvider(
          inner: KgdEsfProvider(
            settings: settings,
            transport: WebKassaEsfTransport(
              fiscalSettings: FiscalSettingsStore(localProperties.prefs).load(),
              logger: getIt<Talker>(),
            ),
          ),
          store: getIt<EsfOutboxStore>(),
          isReachable: () async => true,
        ),
      ),
  );

  getIt.registerLazySingleton<EsfSettingsStore>(
    () => EsfSettingsStore(localProperties.prefs),
  );

  getIt.registerLazySingleton<EsfDraftBuilder>(() => const EsfDraftBuilder());

  getIt.registerLazySingleton<IsMptProviderRegistry>(
    () => IsMptProviderRegistry()
      ..register(
        IsMptBackend.live,
        () => WebKassaIsMptProvider(
          fiscalSettings: FiscalSettingsStore(localProperties.prefs).load(),
          logger: getIt<Talker>(),
        ),
      ),
  );

  getIt.registerLazySingleton<IsMptSettingsStore>(
    () => IsMptSettingsStore(localProperties.prefs),
  );

  getIt.registerLazySingleton<IsMptQueueStore>(() => InMemoryIsMptQueueStore());

  getIt.registerLazySingleton<IsMptService>(
    () => IsMptOfflineQueueingProvider(
      inner: getIt<IsMptProviderRegistry>().resolve(
        getIt<IsMptSettingsStore>().load().resolvedBackend,
      ),
      store: getIt<IsMptQueueStore>(),
      isReachable: () async => true,
    ),
  );

  getIt.registerLazySingleton<SntSettingsStore>(
    () => SntSettingsStore(localProperties.prefs),
  );
  getIt.registerLazySingleton<SntProviderRegistry>(
    () => SntProviderRegistry()
      ..register(
        SntProviderType.webkassa,
        (settings) => WebKassaSntProvider(
          fiscalSettings: FiscalSettingsStore(localProperties.prefs).load(),
          logger: getIt<Talker>(),
        ),
      ),
  );
  getIt.registerLazySingleton<SntDocumentStore>(
    () => PrefsSntDocumentStore(localProperties.prefs),
  );
  getIt.registerLazySingleton<VirtualWarehouseStore>(
    () => InMemoryVirtualWarehouseStore(),
  );
  getIt.registerLazySingleton<SntAssembly>(() => const SntAssembly());
  getIt.registerLazySingleton<SntService>(
    () => SntService(
      provider: getIt<SntProviderRegistry>().resolve(
        getIt<SntSettingsStore>().load(),
      ),
      store: getIt<SntDocumentStore>(),
      warehouse: getIt<VirtualWarehouseStore>(),
      isReachable: () async => true,
    ),
  );

  getIt.registerLazySingleton<EsutdSettingsStore>(
    () => EsutdSettingsStore(localProperties.prefs),
  );
  getIt.registerLazySingleton<EsutdService>(
    () => EsutdService(store: getIt<EsutdSettingsStore>()),
  );

  getIt.registerLazySingleton<CalculateCogsUseCase>(
    () => CalculateCogsUseCaseImpl(db: getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<ApplySupplierReturnCogsUseCase>(
    () => ApplySupplierReturnCogsUseCase(
      cogsUseCase: getIt<CalculateCogsUseCase>(),
      db: getIt<AppDatabase>(),
    ),
  );

  getIt.registerLazySingleton<CreateWriteoffUseCase>(
    () => CreateWriteoffUseCaseImpl(cogsUseCase: getIt<CalculateCogsUseCase>()),
  );

  getIt.registerLazySingleton<CreateInventoryUseCase>(
    () => CreateInventoryUseCaseImpl(),
  );

  getIt.registerLazySingleton<ManageTablesUseCase>(
    () => ManageTablesUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<TableStatusUseCase>(
    () => TableStatusUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<CreateTableOrderUseCase>(
    () => CreateTableOrderUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<AddItemsToOrderUseCase>(
    () => AddItemsToOrderUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<CloseTableOrderUseCase>(
    () => CloseTableOrderUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<SplitBillUseCase>(
    () =>
        SplitBillUseCaseImpl(db: getIt<AppDatabase>(), logger: getIt<Talker>()),
  );

  getIt.registerLazySingleton<TransferTableUseCase>(
    () => TransferTableUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<MergeTablesUseCase>(
    () => MergeTablesUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<CalculateServiceChargeUseCase>(
    () => CalculateServiceChargeUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<GetOpenOrdersUseCase>(
    () => GetOpenOrdersUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<CreateServiceOrderUseCase>(
    () => CreateServiceOrderUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<UpdateServiceOrderUseCase>(
    () => UpdateServiceOrderUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<ServiceOrderTransitionUseCase>(
    () => ServiceOrderTransitionUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<AddServiceMarkUseCase>(
    () => AddServiceMarkUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<ApproveServiceMarkUseCase>(
    () => ApproveServiceMarkUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<LinkServiceToSaleUseCase>(
    () => LinkServiceToSaleUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<FindServiceOrdersUseCase>(
    () => FindServiceOrdersUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<ServiceOrderReceiptUseCase>(
    () => ServiceOrderReceiptUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<ManageServiceTypesUseCase>(
    () => ManageServiceTypesUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<WarehouseRepository>(
    () => WarehouseRepositoryImpl(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<WarehouseZoneRepository>(
    () => WarehouseZoneRepositoryImpl(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<WarehouseCellRepository>(
    () => WarehouseCellRepositoryImpl(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<BatchRepository>(
    () => BatchRepositoryImpl(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<SerialRepository>(
    () => SerialRepositoryImpl(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<WmsConfigRepository>(
    () => WmsConfigRepositoryImpl(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<WarrantyRepository>(
    () => WarrantyRepositoryImpl(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<CellStockRepository>(
    () => CellStockRepositoryImpl(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<ManageWarehouseUseCase>(
    () => ManageWarehouseUseCaseImpl(getIt<WarehouseRepository>()),
  );
  getIt.registerLazySingleton<ManageCellsUseCase>(
    () => ManageCellsUseCaseImpl(
      getIt<WarehouseZoneRepository>(),
      getIt<WarehouseCellRepository>(),
    ),
  );
  getIt.registerLazySingleton<BatchTrackingUseCase>(
    () => BatchTrackingUseCaseImpl(getIt<BatchRepository>()),
  );
  getIt.registerLazySingleton<SerialTrackingUseCase>(
    () => SerialTrackingUseCaseImpl(getIt<SerialRepository>()),
  );
  getIt.registerLazySingleton<CellStockUseCase>(
    () => CellStockUseCaseImpl(
      getIt<CellStockRepository>(),
      getIt<WarehouseCellRepository>(),
    ),
  );
  getIt.registerLazySingleton<ClaimUseCase>(
    () => ClaimUseCaseImpl(
      getIt<WarrantyRepository>(),
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );
  getIt.registerLazySingleton<WmsConfigUseCase>(
    () => WmsConfigUseCaseImpl(getIt<WmsConfigRepository>()),
  );
  // «Остатки изменились» — пункт 12 ревизии 2026-09-19. Один экземпляр под
  // тремя именами: собственным (его просит `LocalPaymentService`, которому
  // нужна запись), читающим договором (`StockRevision` на экранах кассы) и
  // пишущим. Второй экземпляр означал бы два счётчика на одну кассу, и
  // половина рабочих мест не узнавала бы об изменении.
  getIt.registerLazySingleton<LocalStockChanges>(LocalStockChanges.new);
  getIt.registerLazySingleton<StockChanges>(() => getIt<LocalStockChanges>());
  getIt.registerLazySingleton<StockChangeSink>(
    () => getIt<LocalStockChanges>(),
  );
  // Пункт 11 ревизии 2026-09-19: «партия просрочена?» одним договором.
  // Экран продажи спрашивает его, а не два складских юзкейса напрямую, — и
  // ровно поэтому тот же вопрос достижим с планшета (`WtExpiryWarning`).
  getIt.registerLazySingleton<ExpiryWarningReader>(
    () => LocalExpiryWarning(
      batches: getIt<BatchTrackingUseCase>(),
      wmsConfig: getIt<WmsConfigUseCase>(),
    ),
  );
  getIt.registerLazySingleton<StockRuleUseCase>(
    () => StockRuleUseCaseImpl(
      getIt<AppDatabase>().stockRuleDao,
      getIt<AppDatabase>().productInfoDao,
    ),
  );

  // Startup state behind a contract, so the splash screen does not have to
  // know a database exists. The browser binding registers an HTTP
  // implementation of the same interface.
  getIt.registerLazySingleton<StartupStateRepository>(
    () => LocalStartupStateRepository(getIt<AppDatabase>()),
  );

  await HardwareModule.register(getIt);

  final localProps = getIt<LocalProperties>();
  if (localProps.telegramEnabled) {
    await _registerTelegramModule(getIt, logger);
  } else {
    logger.info('Telegram module disabled — skipping registration');
  }
}

/// The live hardware drivers a [DeviceCheck] may borrow, paired with the
/// bindings they were built from.
///
/// Returns an empty set — meaning "always build a fresh driver", the
/// behaviour before this mitigation — when [LiveDeviceBindings] was never
/// registered. That is a real case, not a defensive shrug: `registerHardwareServices`
/// is what registers it, and the browser build (`lib/web/main_web.dart`) and
/// plenty of tests register only the pieces they need. Building fresh is
/// always *correct*; borrowing is the optimisation that avoids a second
/// connection, so its absence costs nothing but the mitigation.
///
/// Each driver is included only when its binding is non-null *and* its
/// singleton is registered. A null binding means nothing is bound (or two
/// things are, which И30 refuses to choose between) — there is then no
/// endpoint the live driver is known to hold, and nothing to compare a saved
/// binding against.
///
/// The `resolve` callbacks are `getIt<T>()` calls left uninvoked on purpose:
/// these are lazy singletons, so calling one *constructs* the driver. A check
/// of a binding that has changed must not bring the stale driver into
/// existence just to reject it — `DeviceCheckLocal` only invokes `resolve`
/// after the bindings have already matched.
LiveDeviceDrivers _liveDeviceDrivers(GetIt getIt) {
  if (!getIt.isRegistered<LiveDeviceBindings>()) {
    return const LiveDeviceDrivers();
  }
  final live = getIt<LiveDeviceBindings>();

  LiveDriver<T>? driver<T extends Object>(DeviceBinding? binding) {
    if (binding == null || !getIt.isRegistered<T>()) return null;
    return LiveDriver<T>(binding: binding, resolve: () => getIt<T>());
  }

  return LiveDeviceDrivers(
    receiptPrinter: driver<PrinterManager>(live.receiptPrinter),
    labelPrinter: driver<LabelPrinterService>(live.labelPrinter),
    cashDrawer: driver<CashDrawerService>(live.cashDrawer),
    scales: driver<ScalesService>(live.scale),
  );
}

/// Завести повтор очереди фискализации: первый проход сейчас и круг
/// `kFiscalReplayInterval`.
///
/// Раньше здесь был `replayPendingFiscal` — один проход из
/// `configureDependencies`, и строка, легшая в очередь после подъёма кассы,
/// ждала перезапуска. Зовёт `main.dart`, а не сборка зависимостей: сквозной
/// стенд набора собирает тот же граф, и таймер там не нужен.
void startFiscalReplay() {
  if (getIt.isRegistered<FiscalReplayScheduler>()) {
    getIt<FiscalReplayScheduler>().start();
  }
}

/// Поднимает встроенные эмуляторы, которые оператор включил раньше.
///
/// Зовёт `main.dart`, а не сборка зависимостей, — по той же причине, что и
/// [startFiscalReplay]: сквозной стенд набора собирает тот же граф, и
/// настоящий серверный сокет там не нужен.
///
/// Почему при запуске, а не только по щелчку на экране: привязка прибора
/// переживает перезагрузку, а сокет — нет. Касса, включённая утром, иначе
/// смотрела бы на порт, которого никто не слушает, и «принтер не отвечает»
/// стало бы загадкой вместо ответа.
Future<void> startBuiltinEmulators(SharedPreferences prefs) async {
  if (!getIt.isRegistered<BuiltinEmulatorHost>()) return;
  final choice = BuiltinEmulatorChoice.read(prefs);
  final host = getIt<BuiltinEmulatorHost>();
  for (final kind in choice.enabled) {
    try {
      await host.start(kind);
    } on Object catch (e) {
      // Занятый порт не имеет права уронить запуск кассы: продажа важнее
      // измерительного прибора. Отказ виден в журнале и на экране настроек.
      getIt<Talker>().warning('[эмулятор] ${kind.name} не поднялся: $e');
    }
  }
}

/// Живой документ дошёл до оператора — связь есть, повтор не ждёт круга.
/// До [startFiscalReplay] ничего не делает (см. `FiscalReplayScheduler.kick`).
void _kickFiscalReplay() {
  if (getIt.isRegistered<FiscalReplayScheduler>()) {
    getIt<FiscalReplayScheduler>().kick();
  }
}

Future<void> _registerTelegramModule(GetIt getIt, Talker logger) async {
  try {
    final appDir = await _getAppDirectory();
    final telegramDir = '$appDir/telegram';

    await Future.delayed(Duration.zero);

    TelegramModule.register(
      getIt,
      sessionsDir: '$telegramDir/sessions',
      registryPath: '$telegramDir/channel_registry.json',
      queuePath: '$telegramDir/message_queue.json',
    );

    logger.info('TelegramModule registered');
  } catch (e) {
    logger.warning('TelegramModule registration failed: $e');
  }
}

Future<String> _getAppDirectory() async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  } catch (e) {
    return '.';
  }
}

/// Открыть денежный ящик кассы — задача 16.
///
/// Тело перенесено из `payment_screen._openCashDrawer` без изменения
/// порядка: отдельный ящик на последовательном порту пробуется первым,
/// запасной путь — команда через принтер (`ESC p`), и она же единственная
/// на кассе, где ящик подключён к принтеру.
///
/// Живёт **здесь**, а не в `LocalPaymentService`: `CashDrawerService`
/// тянет `flutter_libserialport`, то есть `dart:ffi`, а `lib/data/sale/`
/// обязан оставаться собираемым для веба. Сборка кассы знает про железо,
/// оплата — только про порт [CashDrawerOpener].
Future<bool> _openCashDrawer(GetIt getIt) async {
  final logger = getIt<Talker>();

  /// Запись в журнал — **здесь**, а не в `CashDrawerService`, потому что
  /// путей два и выбирает между ними эта функция. Внутри службы виден только
  /// свой путь, и запасной проход через принтер в журнал не попал бы вовсе —
  /// то есть на кассе, где ящик воткнут в принтер (самый частый случай),
  /// журнал был бы пуст всегда.
  void note(CashDrawerPath path, bool accepted, [String? why]) {
    if (!getIt.isRegistered<CashDrawerJournal>()) return;
    getIt<CashDrawerJournal>().record(
      CashDrawerKick(
        at: DateTime.now(),
        path: path,
        accepted: accepted,
        note: why,
      ),
    );
  }

  try {
    if (getIt.isRegistered<CashDrawerService>()) {
      final drawer = getIt<CashDrawerService>();
      if (drawer.mode == CashDrawerMode.serialPort) {
        final result = await drawer.open();
        note(CashDrawerPath.serialPort, result.success, result.errorMessage);
        if (result.success) return true;
        logger.warning(
          'Cash drawer serial open failed, falling back to printer: '
          '${result.errorMessage}',
        );
      }
    }
  } catch (e, stack) {
    note(CashDrawerPath.serialPort, false, '$e');
    logger.warning('Cash drawer service error (non-blocking): $e', e, stack);
  }
  if (!getIt.isRegistered<ReceiptPrintService>()) {
    note(CashDrawerPath.viaPrinter, false, 'служба печати не зарегистрирована');
    return false;
  }
  final viaPrinter = await getIt<ReceiptPrintService>().openCashDrawer();
  note(
    CashDrawerPath.viaPrinter,
    viaPrinter,
    viaPrinter ? null : 'принтер не принял команду ESC p',
  );
  return viaPrinter;
}
