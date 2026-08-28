import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/startup/startup_state_repository_local.dart';
import 'package:telepos/domain/startup/startup_state_repository.dart';
import 'package:telepos/data/terminal/terminal_identity_local.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/api_server_reachability.dart';
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
import 'package:telepos/data/setup/setup_repository_local.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
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
import 'package:telepos/app/config/async_config.dart';
import 'package:telepos/app/config/build_config.dart';
import 'package:telepos/data/sync/couchdb_sync_coordinator.dart';
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
import 'package:telepos/data/usecases/refund/refund_use_case_impl.dart';
import 'package:telepos/data/usecases/refund/clear_refund_use_case_impl.dart';
import 'package:telepos/data/usecases/refund/on_refund_customer_use_case_impl.dart';
import 'package:telepos/data/usecases/refund/on_refund_payments_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/cancel_product_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_component_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_history_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_debt_amount_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_validation_service_impl.dart';
import 'package:telepos/data/usecases/sale/can_sale_be_refunded_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/find_sale_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/last_sale_receipt_no_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_product_creation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/persist_sale_products_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_receipt_product_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/universal_product_use_case_impl.dart';
import 'package:telepos/domain/services/auth_service.dart';
import 'package:telepos/domain/services/role_identification_service.dart';
import 'package:telepos/domain/services/shift_service.dart';
import 'package:telepos/domain/usecases/shift/assemble_shift_receipt_use_case.dart';
import 'package:telepos/domain/usecases/sale/cancel_product_use_case.dart';
import 'package:telepos/domain/usecases/sale/sale_component_use_case.dart';
import 'package:telepos/domain/usecases/sale/sale_history_service.dart';
import 'package:telepos/domain/usecases/sale/sale_debt_amount_use_case.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';
import 'package:telepos/domain/usecases/sale/sale_validation_service.dart';
import 'package:telepos/domain/usecases/sale/can_sale_be_refunded_use_case.dart';
import 'package:telepos/domain/usecases/sale/deferred_sale_service.dart';
import 'package:telepos/domain/usecases/sale/find_sale_use_case.dart';
import 'package:telepos/domain/usecases/sale/last_sale_receipt_no_use_case.dart';
import 'package:telepos/domain/usecases/sale/sale_initiation_use_case.dart';
import 'package:telepos/domain/usecases/sale/sale_product_creation_use_case.dart';
import 'package:telepos/domain/usecases/sale/persist_sale_products_use_case.dart';
import 'package:telepos/domain/usecases/sale/sale_receipt_product_service.dart';
import 'package:telepos/domain/usecases/sale/sale_round_option_use_case.dart';
import 'package:telepos/domain/usecases/sale/universal_product_use_case.dart';
import 'package:telepos/domain/usecases/shift/custom_bank_payments_sum_use_case.dart';
import 'package:telepos/domain/usecases/refund/refund_initiation_use_case.dart';
import 'package:telepos/domain/usecases/refund/refund_use_case.dart';
import 'package:telepos/domain/usecases/refund/clear_refund_use_case.dart';
import 'package:telepos/domain/usecases/refund/on_refund_customer_use_case.dart';
import 'package:telepos/domain/usecases/refund/on_refund_payments_use_case.dart';
import 'package:telepos/domain/usecases/refund/refund_component_use_case.dart';
import 'package:telepos/domain/usecases/refund/refund_receipt_use_case.dart';
import 'package:telepos/domain/usecases/refund/refund_receipt_product_service.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import 'package:telepos/domain/usecases/refund/find_refund_use_case.dart';
import 'package:telepos/domain/usecases/refund/refund_validation_service.dart';
import 'package:telepos/domain/usecases/payment/payment_controller.dart';
import 'package:telepos/domain/usecases/payment/cash_account_use_case.dart';
import 'package:telepos/domain/usecases/payment/debt_use_case.dart';
import 'package:telepos/domain/usecases/payment/purchase_with_cash_use_case.dart';
import 'package:telepos/domain/usecases/payment/account_visible_to_pos_use_case.dart';
import 'package:telepos/domain/usecases/payment/payment_sequences.dart';
import 'package:telepos/domain/usecases/payment/denomination_service.dart';
import 'package:telepos/domain/usecases/payment/customer_payment_use_case.dart';
import 'package:telepos/domain/usecases/product/find_by_alias_use_case.dart';
import 'package:telepos/domain/usecases/product/find_by_barcode_use_case.dart';
import 'package:telepos/domain/usecases/product/find_product_by_code_use_case.dart';
import 'package:telepos/domain/usecases/product/search_product_info_use_case.dart';
import 'package:telepos/domain/usecases/product/find_product_by_mark_use_case.dart';
import 'package:telepos/domain/usecases/product/create_product_info_use_case.dart';
import 'package:telepos/domain/usecases/product/create_product_price_use_case.dart';
import 'package:telepos/domain/usecases/product/create_product_info_and_price_use_case.dart';
import 'package:telepos/domain/usecases/product/product_info_and_price_edition_use_case.dart';
import 'package:telepos/domain/usecases/product/restore_product_info_use_case.dart';
import 'package:telepos/domain/usecases/product/kassa_price_decreasing_blocked_use_case.dart';
import 'package:telepos/domain/usecases/product/mark_up_use_case.dart';
import 'package:telepos/domain/usecases/product/is_category_blocked_use_case.dart';
import 'package:telepos/domain/usecases/product/is_product_info_blocked_use_case.dart';
import 'package:telepos/domain/usecases/product/reserved_barcode_use_case.dart';
import 'package:telepos/domain/usecases/agent/create_agent_use_case.dart';
import 'package:telepos/domain/usecases/agent/persist_agent_use_case.dart';
import 'package:telepos/domain/usecases/agent/edit_agent_use_case.dart';
import 'package:telepos/domain/usecases/agent/restore_agent_use_case.dart';
import 'package:telepos/domain/usecases/agent/agent_validation_service.dart';
import 'package:telepos/domain/usecases/agent/search_agent_use_case.dart';
import 'package:telepos/domain/usecases/agent/find_agent_by_phone_use_case.dart';
import 'package:telepos/domain/usecases/agent/agent_last_id_use_case.dart';
import 'package:telepos/domain/usecases/agent/agent_balance_service.dart';
import 'package:telepos/domain/usecases/agent/bonus_service.dart';
import 'package:telepos/domain/usecases/agent/loyalty_sms_service.dart';
import 'package:telepos/domain/usecases/supply/create_supply_use_case.dart';
import 'package:telepos/domain/usecases/supply/supply_product_use_case.dart';
import 'package:telepos/domain/usecases/supply/save_supply_use_case.dart';
import 'package:telepos/domain/usecases/supply/get_supplies_history_use_case.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_operation_receipt_service.dart';
import 'package:telepos/domain/usecases/fiscal/webkassa_service.dart';
import 'package:telepos/domain/usecases/fiscal/fisc_errors_service.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/data/fiscal/webkassa_provider.dart';
import 'package:telepos/data/fiscal/direct_ofd_provider.dart';
import 'package:telepos/data/fiscal/kassa24_provider.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';
import 'package:telepos/data/fiscal/drift_fiscal_queue_store.dart';
import 'package:telepos/data/fiscal/fiscal_settings_store.dart';
import 'package:telepos/domain/fiscal/fiscal_provider_registry.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
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
import 'package:telepos/data/usecases/fiscal/this_pos_fiscal_settings_source.dart';
import 'package:telepos/data/usecases/fiscal/store_fiscal_settings_source.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/core/services/update/updater_service.dart';
import 'package:telepos/data/services/receipt_print_service_impl.dart';
import 'package:telepos/data/usecases/refund/refund_component_use_case_impl.dart';
import 'package:telepos/data/usecases/product/find_by_alias_use_case_impl.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/find_product_by_code_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/product/find_product_by_mark_use_case_impl.dart';
import 'package:telepos/data/usecases/product/create_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/product/create_product_price_use_case_impl.dart';
import 'package:telepos/data/usecases/product/create_product_info_and_price_use_case_impl.dart';
import 'package:telepos/data/usecases/product/product_info_and_price_edition_use_case_impl.dart';
import 'package:telepos/data/usecases/product/restore_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/product/kassa_price_decreasing_blocked_use_case_impl.dart';
import 'package:telepos/data/usecases/product/mark_up_use_case_impl.dart';
import 'package:telepos/data/usecases/product/is_category_blocked_use_case_impl.dart';
import 'package:telepos/data/usecases/product/is_product_info_blocked_use_case_impl.dart';
import 'package:telepos/data/usecases/product/reserved_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/agent/create_agent_use_case_impl.dart';
import 'package:telepos/data/usecases/agent/persist_agent_use_case_impl.dart';
import 'package:telepos/data/usecases/agent/edit_agent_use_case_impl.dart';
import 'package:telepos/data/usecases/agent/restore_agent_use_case_impl.dart';
import 'package:telepos/data/usecases/agent/agent_validation_service_impl.dart';
import 'package:telepos/data/usecases/agent/search_agent_use_case_impl.dart';
import 'package:telepos/data/usecases/agent/find_agent_by_phone_use_case_impl.dart';
import 'package:telepos/data/usecases/agent/agent_last_id_use_case_impl.dart';
import 'package:telepos/data/usecases/agent/agent_balance_service_impl.dart';
import 'package:telepos/data/usecases/agent/bonus_service_impl.dart';
import 'package:telepos/data/usecases/agent/loyalty_sms_service_impl.dart';
import 'package:telepos/data/usecases/supply/create_supply_use_case_impl.dart';
import 'package:telepos/data/usecases/supply/supply_product_use_case_impl.dart';
import 'package:telepos/data/usecases/supply/save_supply_use_case_impl.dart';
import 'package:telepos/data/usecases/supply/get_supplies_history_use_case_impl.dart';
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
import 'package:telepos/data/usecases/fiscal/fisc_errors_service_impl.dart';
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
import 'package:telepos/data/usecases/payment/payment_sequences_impl.dart';
import 'package:telepos/data/usecases/payment/denomination_service_impl.dart';
import 'package:telepos/data/usecases/payment/customer_payment_use_case_impl.dart';
import 'package:telepos/data/usecases/payment/payment_controller_impl.dart';
import 'package:telepos/data/usecases/payment/cash_account_use_case_impl.dart';
import 'package:telepos/data/usecases/payment/debt_use_case_impl.dart';
import 'package:telepos/data/usecases/payment/purchase_with_cash_use_case_impl.dart';
import 'package:telepos/data/usecases/payment/account_visible_to_pos_use_case_impl.dart';
import 'package:telepos/data/usecases/refund/find_refund_use_case_impl.dart';
import 'package:telepos/data/usecases/refund/refund_validation_service_impl.dart';
import 'package:telepos/data/usecases/refund/refund_receipt_use_case_impl.dart';
import 'package:telepos/data/usecases/refund/refund_receipt_product_service_impl.dart';
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

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies({required Talker logger}) async {
  getIt.registerSingleton<Talker>(logger);

  getIt.registerSingleton<BuildConfig>(BuildConfig.fromEnvironment());

  getIt.registerSingleton<AsyncConfig>(AsyncConfig.fromEnvironment());

  final localProperties = await LocalProperties.create();
  getIt.registerSingleton<LocalProperties>(localProperties);

  getIt.registerLazySingleton<TerminalIdentity>(
    () => PrefsTerminalIdentity(getIt<LocalProperties>().prefs),
  );

  getIt.registerLazySingleton<CouchDbSyncEngine>(
    () => CouchDbSyncEngine(prefs: localProperties.prefs),
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
  getIt.registerLazySingleton<DeviceProfileCatalog>(
    () => BuiltinDeviceProfileCatalog(),
  );

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

  getIt.registerLazySingleton<UniversalProductUseCase>(
    () => UniversalProductUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<PersistSaleProductsUseCase>(
    () => PersistSaleProductsUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<SaleUseCase>(
    () => SaleUseCaseImpl(db: getIt<AppDatabase>(), logger: getIt<Talker>()),
  );

  getIt.registerLazySingleton<CancelProductUseCase>(
    () => CancelProductUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<SaleComponentUseCase>(
    () => SaleComponentUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<SaleReceiptProductService>(
    () => SaleReceiptProductServiceImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<FindSaleUseCase>(
    () =>
        FindSaleUseCaseImpl(db: getIt<AppDatabase>(), logger: getIt<Talker>()),
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

  getIt.registerLazySingleton<SaleDebtAmountUseCase>(
    () => SaleDebtAmountUseCaseImpl(),
  );

  getIt.registerLazySingleton<SaleRoundOptionUseCase>(
    () => SaleRoundOptionUseCaseImpl(),
  );

  getIt.registerLazySingleton<SaleValidationService>(
    () => SaleValidationServiceImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<SaleInitiationUseCase>(
    () => SaleInitiationUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
      shiftService: getIt<ShiftService>(),
    ),
  );

  getIt.registerLazySingleton<RefundInitiationUseCase>(
    () => RefundInitiationUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<RefundUseCase>(
    () => RefundUseCaseImpl(db: getIt<AppDatabase>(), logger: getIt<Talker>()),
  );

  getIt.registerLazySingleton<ClearRefundUseCase>(
    () => ClearRefundUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<OnRefundCustomerUseCase>(
    () => OnRefundCustomerUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<OnRefundPaymentsUseCase>(
    () => OnRefundPaymentsUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<RefundComponentUseCase>(
    () => RefundComponentUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<RefundReceiptUseCase>(
    () => RefundReceiptUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<RefundReceiptProductService>(
    () => RefundReceiptProductServiceImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<RefundProductService>(
    () => RefundProductServiceImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<FindRefundUseCase>(
    () => FindRefundUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<RefundValidationService>(
    () => RefundValidationServiceImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<PaymentController>(
    () => PaymentControllerImpl(logger: getIt<Talker>()),
  );

  getIt.registerLazySingleton<CashAccountUseCase>(
    () => CashAccountUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<DebtUseCase>(() => DebtUseCaseImpl());

  getIt.registerLazySingleton<PurchaseWithCashUseCase>(
    () => PurchaseWithCashUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<AccountVisibleToPosUseCase>(
    () => AccountVisibleToPosUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<PaymentSequences>(() => PaymentSequencesImpl());

  getIt.registerLazySingleton<DenominationService>(
    () => DenominationServiceImpl(),
  );

  getIt.registerLazySingleton<CustomerPaymentUseCase>(
    () => CustomerPaymentUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<FindByAliasUseCase>(
    () => FindByAliasUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<FindByBarcodeUseCase>(
    () => FindByBarcodeUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<FindProductByCodeUseCase>(
    () => FindProductByCodeUseCaseImpl(
      db: getIt<AppDatabase>(),
      findByAliasUseCase: getIt<FindByAliasUseCase>(),
      findByBarcodeUseCase: getIt<FindByBarcodeUseCase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<SearchProductInfoUseCase>(
    () => SearchProductInfoUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<FindProductByMarkUseCase>(
    () => FindProductByMarkUseCaseImpl(
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

  getIt.registerLazySingleton<CreateProductInfoAndPriceUseCase>(
    () => CreateProductInfoAndPriceUseCaseImpl(
      db: getIt<AppDatabase>(),
      createProductInfoUseCase: getIt<CreateProductInfoUseCase>(),
      createProductPriceUseCase: getIt<CreateProductPriceUseCase>(),
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

  getIt.registerLazySingleton<KassaPriceDecreasingBlockedUseCase>(
    () => KassaPriceDecreasingBlockedUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<MarkUpUseCase>(
    () => MarkUpUseCaseImpl(db: getIt<AppDatabase>(), logger: getIt<Talker>()),
  );

  getIt.registerLazySingleton<IsCategoryBlockedUseCase>(
    () => IsCategoryBlockedUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<IsProductInfoBlockedUseCase>(
    () => IsProductInfoBlockedUseCaseImpl(
      db: getIt<AppDatabase>(),
      isCategoryBlockedUseCase: getIt<IsCategoryBlockedUseCase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<ReservedBarcodeUseCase>(
    () => ReservedBarcodeUseCaseImpl(),
  );

  getIt.registerLazySingleton<CreateAgentUseCase>(
    () => CreateAgentUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<PersistAgentUseCase>(
    () => PersistAgentUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<EditAgentUseCase>(
    () =>
        EditAgentUseCaseImpl(db: getIt<AppDatabase>(), logger: getIt<Talker>()),
  );

  getIt.registerLazySingleton<RestoreAgentUseCase>(
    () => RestoreAgentUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<AgentValidationService>(
    () => AgentValidationServiceImpl(),
  );

  getIt.registerLazySingleton<SearchAgentUseCase>(
    () => SearchAgentUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<FindAgentByPhoneUseCase>(
    () => FindAgentByPhoneUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<AgentLastIdUseCase>(
    () => AgentLastIdUseCaseImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<AgentBalanceService>(
    () => AgentBalanceServiceImpl(
      db: getIt<AppDatabase>(),
      logger: getIt<Talker>(),
    ),
  );

  getIt.registerLazySingleton<BonusService>(() => BonusServiceImpl());

  getIt.registerLazySingleton<LoyaltySmsService>(() => LoyaltySmsServiceImpl());

  getIt.registerLazySingleton<CreateSupplyUseCase>(
    () => CreateSupplyUseCaseImpl(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<SupplyProductUseCase>(
    () => SupplyProductUseCaseImpl(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<SaveSupplyUseCase>(
    () => SaveSupplyUseCaseImpl(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<GetSuppliesHistoryUseCase>(
    () => GetSuppliesHistoryUseCaseImpl(getIt<AppDatabase>()),
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

  getIt.registerLazySingleton<FiscalProviderRegistry>(
    () => FiscalProviderRegistry()
      ..register(
        FiscalOperatorType.webkassa,
        (settings) => OfflineQueueingProvider(
          inner: WebKassaProvider(settings: settings, logger: getIt<Talker>()),
          store: getIt<FiscalQueueStore>(),
          isReachable: () async => true,
        ),
      )
      ..register(
        FiscalOperatorType.directOfd,
        (settings) => OfflineQueueingProvider(
          inner: DirectOfdProvider(settings),
          store: getIt<FiscalQueueStore>(),
          isReachable: () async => true,
        ),
      )
      ..register(
        FiscalOperatorType.kassa24,
        (settings) => OfflineQueueingProvider(
          inner: Kassa24Provider(settings),
          store: getIt<FiscalQueueStore>(),
          isReachable: () async => true,
        ),
      ),
  );

  getIt.registerLazySingleton<FiscalSettingsSource>(
    () => StoreFiscalSettingsSource(
      store: FiscalSettingsStore(localProperties.prefs),
      fallback: ThisPosFiscalSettingsSource(db: getIt<AppDatabase>()),
    ),
  );

  getIt.registerLazySingleton<FiscalService>(
    () => FiscalServiceImpl(
      db: getIt<AppDatabase>(),
      registry: getIt<FiscalProviderRegistry>(),
      settingsSource: getIt<FiscalSettingsSource>(),
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

  getIt.registerLazySingleton<FiscErrorsService>(
    () => FiscErrorsServiceImpl(
      db: getIt<AppDatabase>(),
      webKassaService: getIt<WebKassaService>(),
      logger: getIt<Talker>(),
    ),
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

  unawaited(replayPendingFiscal(logger: logger));
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

Future<void> replayPendingFiscal({Talker? logger}) async {
  try {
    if (!getIt.isRegistered<FiscalProviderRegistry>() ||
        !getIt.isRegistered<FiscalSettingsSource>()) {
      return;
    }
    final settings = await getIt<FiscalSettingsSource>().load();
    final provider = getIt<FiscalProviderRegistry>().resolve(settings);
    if (provider is! OfflineQueueingProvider) return;
    final report = await provider.replay();
    logger?.info(
      'Fiscal replay: fiscalized=${report.fiscalized} deduped=${report.deduped} '
      'failed=${report.failed} remaining=${report.remaining} '
      'stoppedOnNetwork=${report.stoppedOnNetwork}',
    );
  } catch (e, st) {
    logger?.handle(e, st, 'Fiscal replay failed (ignored)');
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
