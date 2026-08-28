import 'dart:convert';
import 'dart:io' as io;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
// `DriftRemoteException` is what a background-isolate database throws instead
// of the sqlite error itself — see [AppDatabase.isExpectedSchemaError].
import 'package:drift/remote.dart' show DriftRemoteException;
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:telepos/core/constants/enums/user_role.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';
import 'package:telepos/data/database/migrations/device_binding_migration.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/database/daos/additional_printer_dao.dart';
import 'package:telepos/data/database/daos/agent_dao.dart';
import 'package:telepos/data/database/daos/agent_local_contact_dao.dart';
import 'package:telepos/data/database/daos/app_version_status_dao.dart';
import 'package:telepos/data/database/daos/attr_date_dao.dart';
import 'package:telepos/data/database/daos/cancelled_product_dao.dart';
import 'package:telepos/data/database/daos/cash_operation_dao.dart';
import 'package:telepos/data/database/daos/category_dao.dart';
import 'package:telepos/data/database/daos/category_restriction_dao.dart';
import 'package:telepos/data/database/daos/custom_field_dao.dart';
import 'package:telepos/data/database/daos/global_product_dao.dart';
import 'package:telepos/data/database/daos/mark_up_dao.dart';
import 'package:telepos/data/database/daos/promotion_dao.dart';
import 'package:telepos/data/database/daos/package_product_dao.dart';
import 'package:telepos/data/database/daos/payment_dao.dart';
import 'package:telepos/data/database/daos/pos_dao.dart';
import 'package:telepos/data/database/daos/product_alias_dao.dart';
import 'package:telepos/data/database/daos/product_info_dao.dart';
import 'package:telepos/data/database/daos/product_price_dao.dart';
import 'package:telepos/data/database/daos/quick_product_dao.dart';
import 'package:telepos/data/database/daos/refund_dao.dart';
import 'package:telepos/data/database/daos/report_dao.dart';
import 'package:telepos/data/database/daos/dish_ingredient_dao.dart';
import 'package:telepos/data/database/daos/dish_recipe_version_dao.dart';
import 'package:telepos/data/database/daos/dish_photo_dao.dart';
import 'package:telepos/data/database/daos/gost_loss_norm_dao.dart';
import 'package:telepos/data/database/daos/modifier_dao.dart';
import 'package:telepos/data/database/tables/dish_tables.dart';
import 'package:telepos/data/database/tables/modifier_tables.dart';
import 'package:telepos/data/database/daos/sale_dao.dart';
import 'package:telepos/data/database/daos/sale_product_dao.dart';
import 'package:telepos/data/database/daos/shift_dao.dart';
import 'package:telepos/data/database/daos/supply_dao.dart';
import 'package:telepos/data/database/daos/supplier_return_dao.dart';
import 'package:telepos/data/database/daos/supplier_return_product_dao.dart';
import 'package:telepos/data/database/daos/supply_product_dao.dart';
import 'package:telepos/data/database/daos/this_pos_dao.dart';
import 'package:telepos/data/database/daos/update_property_dao.dart';
import 'package:telepos/data/database/daos/user_dao.dart';
import 'package:telepos/data/database/daos/user_pos_settings_dao.dart';
import 'package:telepos/data/database/daos/webkassa_receipt_dao.dart';
import 'package:telepos/data/database/daos/writeoff_dao.dart';
import 'package:telepos/data/database/daos/writeoff_product_dao.dart';
import 'package:telepos/data/database/daos/inventory_dao.dart';
import 'package:telepos/data/database/daos/label_template_dao.dart';
import 'package:telepos/data/database/daos/receipt_template_dao.dart';
import 'package:telepos/data/database/tables/label_template_tables.dart';
import 'package:telepos/data/database/tables/receipt_template_tables.dart';
import 'package:telepos/data/database/daos/inventory_product_dao.dart';
import 'package:telepos/data/database/daos/movement_dao.dart';
import 'package:telepos/data/database/daos/movement_product_dao.dart';
import 'package:telepos/data/database/daos/restaurant_table_dao.dart';
import 'package:telepos/data/database/daos/restaurant_zone_dao.dart';
import 'package:telepos/data/database/daos/restaurant_order_dao.dart';
import 'package:telepos/data/database/daos/guest_split_dao.dart';
import 'package:telepos/data/database/daos/service_order_dao.dart';
import 'package:telepos/data/database/daos/service_mark_dao.dart';
import 'package:telepos/data/database/daos/service_type_dao.dart';
import 'package:telepos/data/database/daos/service_consumable_dao.dart';
import 'package:telepos/data/database/daos/service_order_photo_dao.dart';
import 'package:telepos/data/database/daos/user_permission_dao.dart';
import 'package:telepos/data/database/daos/security_event_dao.dart';
import 'package:telepos/data/database/tables/security_tables.dart';
import 'package:telepos/data/database/tables/cash_operation_tables.dart';
import 'package:telepos/data/database/tables/config_tables.dart';
import 'package:telepos/data/database/tables/custom_field_tables.dart';
import 'package:telepos/data/database/tables/nomenclature_tables.dart';
import 'package:telepos/data/database/tables/organization_tables.dart';
import 'package:telepos/data/database/tables/user_permission_tables.dart';
import 'package:telepos/data/database/tables/payment_tables.dart';
import 'package:telepos/data/database/tables/print_tables.dart';
import 'package:telepos/data/database/tables/refund_tables.dart';
import 'package:telepos/data/database/tables/sale_tables.dart';
import 'package:telepos/data/database/tables/shift_tables.dart';
import 'package:telepos/data/database/tables/supplier_return_tables.dart';
import 'package:telepos/data/database/tables/supply_tables.dart';
import 'package:telepos/data/database/tables/movement_tables.dart';
import 'package:telepos/data/database/tables/this_pos_tables.dart';
import 'package:telepos/data/database/tables/terminal_tables.dart';
import 'package:telepos/data/database/daos/terminal_dao.dart';
import 'package:telepos/data/database/tables/writeoff_tables.dart';
import 'package:telepos/data/database/tables/inventory_tables.dart';
import 'package:telepos/data/database/tables/restaurant_tables.dart';
import 'package:telepos/data/database/tables/service_order_tables.dart';
import 'package:telepos/data/database/tables/webkassa_tables.dart';
import 'package:telepos/data/database/tables/wms_tables.dart';
import 'package:telepos/data/database/daos/warehouse_dao.dart';
import 'package:telepos/data/database/daos/warehouse_zone_dao.dart';
import 'package:telepos/data/database/daos/warehouse_cell_dao.dart';
import 'package:telepos/data/database/daos/cell_stock_dao.dart';
import 'package:telepos/data/database/daos/batch_dao.dart';
import 'package:telepos/data/database/daos/serial_dao.dart';
import 'package:telepos/data/database/daos/marking_code_dao.dart';
import 'package:telepos/data/database/daos/stock_rule_dao.dart';
import 'package:telepos/data/database/daos/warranty_dao.dart';
import 'package:telepos/data/database/daos/wms_config_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    AdditionalPrinters,
    AppVersionStatuses,
    AttrDates,
    UpdateProperties,
    Categories,
    CategoryRestrictions,
    GlobalProducts,
    ProductInfos,
    ProductPrices,
    ProductInfoEditions,
    ProductPriceEditions,
    ProductAliases,
    MarkUps,
    Promotions,
    PackageProducts,
    QuickProducts,
    CancelledProducts,
    Sales,
    SaleProducts,
    SaleProductMarks,
    SaleWithdrawals,
    SaleCustomFields,
    UniversalProducts,
    Payments,
    Refunds,
    RefundProducts,
    RefundProductMarks,
    Shifts,
    Supplies,
    SupplyProducts,
    Movements,
    MovementProducts,
    SupplierReturns,
    SupplierReturnProducts,
    CashOperations,
    CashOperationCustomFields,
    Writeoffs,
    WriteoffProducts,
    Inventories,
    InventoryProducts,
    WebkassaReceipts,
    FiscalQueueEntries,
    WebkassaConfigs,
    CustomFields,
    CustomFieldItems,
    ThisPosEntries,
    LabelTemplates,
    ReceiptTemplates,
    RestaurantTables,
    RestaurantZones,
    RestaurantOrders,
    GuestSplits,
    ServiceOrders,
    ServiceMarks,
    ServiceTypes,
    ServiceConsumables,
    ServiceOrderPhotos,
    UserPermissions,
    DishIngredients,
    DishRecipeVersions,
    DishPhotos,
    GostLossNorms,
    ModifierGroups,
    ModifierOptions,
    SaleProductModifiers,
    Users,
    UserPosSettings,
    Agents,
    AgentLocalContacts,
    Accounts,
    PosEntries,
    CustomFieldClassRelations,
    Warehouses,
    WarehouseZones,
    WarehouseCells,
    CellStocks,
    Batches,
    Serials,
    SerialMovements,
    MarkingCodes,
    StockRules,
    WarrantyRecords,
    Claims,
    ClaimHistoryEntries,
    ProductComponents,
    WmsConfigs,
    Terminals,
    TerminalDeviceBindings,
    PrintJobs,
    PrintJobConfirmations,
    SecurityEvents,
  ],
  daos: [
    AdditionalPrinterDao,
    AppVersionStatusDao,
    AttrDateDao,
    UpdatePropertyDao,
    CategoryDao,
    CategoryRestrictionDao,
    GlobalProductDao,
    ProductInfoDao,
    ProductPriceDao,
    ProductAliasDao,
    MarkUpDao,
    PromotionDao,
    PackageProductDao,
    QuickProductDao,
    CancelledProductDao,
    SaleDao,
    SaleProductDao,
    RefundDao,
    PaymentDao,
    ShiftDao,
    SupplyDao,
    SupplyProductDao,
    MovementDao,
    MovementProductDao,
    SupplierReturnDao,
    SupplierReturnProductDao,
    CashOperationDao,
    WriteoffDao,
    WriteoffProductDao,
    InventoryDao,
    InventoryProductDao,
    WebkassaReceiptDao,
    UserDao,
    UserPosSettingsDao,
    AgentDao,
    AgentLocalContactDao,
    AccountDao,
    PosDao,
    ThisPosDao,
    LabelTemplateDao,
    ReceiptTemplateDao,
    CustomFieldDao,
    RestaurantTableDao,
    RestaurantZoneDao,
    RestaurantOrderDao,
    GuestSplitDao,
    ServiceOrderDao,
    ServiceMarkDao,
    ServiceTypeDao,
    ServiceConsumableDao,
    ServiceOrderPhotoDao,
    UserPermissionDao,
    ReportDao,
    DishIngredientDao,
    DishRecipeVersionDao,
    DishPhotoDao,
    GostLossNormDao,
    ModifierDao,
    WarehouseDao,
    WarehouseZoneDao,
    WarehouseCellDao,
    CellStockDao,
    BatchDao,
    SerialDao,
    MarkingCodeDao,
    StockRuleDao,
    WarrantyDao,
    WmsConfigDao,
    TerminalDao,
    SecurityEventDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Takes its executor rather than choosing one.
  ///
  /// The default used to resolve the database directory through path_provider,
  /// which is a Flutter plugin — so the backend layer could not run without a
  /// UI toolkit, and `dart run bin/telepos_backend.dart` failed before it
  /// started. Where the file lives is the composition root's decision; see
  /// `AppDatabaseConnection.create()`, used from `app/di/service_locator.dart`.
  AppDatabase(super.connection, {this.legacyHardwareSettingsBlobJson});

  /// Historical name for the same thing, kept because the tests use it —
  /// except for one deliberate difference from the constructor above:
  /// `closeStreamsSynchronously: true`.
  ///
  /// Drift's own doc comment on [DatabaseConnection] names this exact
  /// problem: "Enabling that option may be useful in test setups that throw
  /// exceptions for timers persisting after tests." Without it, cancelling a
  /// query stream (`StreamQueryStore.markAsClosed`) defers the actual
  /// cleanup by one event-loop tick through `Timer.run`, so a widget that
  /// unsubscribes and immediately resubscribes on the next frame (a
  /// `StreamBuilder` rebuild) does not pay for a full re-registration. In a
  /// `testWidgets` body that deferred tick is a *fake* one — it only fires on
  /// a further `pump()` — and any Riverpod `Notifier` that is not
  /// `autoDispose` (project rule: Notifier, NOT auto-dispose) only cancels
  /// its stream subscription when the `ProviderContainer` itself disposes,
  /// which happens on flutter_test's own automatic between-test tree
  /// teardown, *after* a test's own body has already returned — too late for
  /// any pump inside the body to reach. Left at drift's default, that throws
  /// "A Timer is still pending even after the widget tree was disposed" on
  /// every test whose widget tree renders a screen with such a subscription
  /// (found here: `LoginNotifier.watchUsers()`, `test/e2e/journeys/`) — and
  /// nondeterministically late enough that one instance of this surfaced as
  /// a ten-minute hang on the *next* test's `setUp`, not a fast failure on
  /// the test that actually caused it.
  ///
  /// `closeStreamsSynchronously: true` makes `markAsClosed` finish the
  /// cleanup immediately, inside the same synchronous call that cancels the
  /// subscription — no `Timer` is ever created, so there is nothing left
  /// pending for the invariant check to catch, for this subscription or any
  /// future one written against a database opened this way. Fixed once here
  /// rather than once per test file: every e2e/widget test opens its
  /// database through this constructor (grep `AppDatabase.forTesting` —
  /// none pass an executor that is already a `DatabaseConnection`, so the
  /// wrap below always takes effect), so this closes the whole class of
  /// failure for the 39 files that render a login-adjacent screen today and
  /// for whatever is written against this database tomorrow — not just the
  /// files a given failing run happened to reach. The constructor above
  /// (production) is untouched: the coalescing traded away here only matters
  /// for rapid `StreamBuilder`-style resubscription, which nothing in the
  /// test suite depends on, and real installations keep the default.
  AppDatabase.forTesting(
    QueryExecutor connection, {
    this.legacyHardwareSettingsBlobJson,
  }) : super(DatabaseConnection(connection, closeStreamsSynchronously: true));

  /// The JSON previously stored under SharedPreferences key
  /// `hardware_settings`, read by the composition root *before* opening this
  /// database and handed in here so migration v27 can fold it into
  /// `TerminalDeviceBindings`
  /// (`lib/data/database/migrations/device_binding_migration.dart`). A plain
  /// `String?` and nothing more — this class must never import
  /// `shared_preferences` itself: `bin/telepos_backend.dart` imports
  /// `AppDatabase` directly as a `dart run` entry point with no Flutter
  /// engine, and a transitive Flutter-plugin dependency here would break it.
  ///
  /// Supplied by the composition root — `lib/app/di/service_locator.dart`
  /// reads `hardware_settings` off `localProperties.prefs` before
  /// registering `AppDatabase` and passes it here (commit `17938ed`; see that
  /// call site's own doc comment for why it was task 3's wiring to do, not
  /// task 2's). A comment claiming "no production call site passes this
  /// today" survived here past that commit — stale since `17938ed` — which
  /// invited a reader to think this migration path was inert when it is
  /// not; corrected during final review, 2026-07-30.
  final String? legacyHardwareSettingsBlobJson;

  @override
  int get schemaVersion => 36;

  Future<void> checkpointWal() async {
    await customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  }

  static void deleteWalSidecars(String dbPath) {
    for (final suffix in const ['-wal', '-shm']) {
      try {
        final f = io.File('$dbPath$suffix');
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }

  /// Whether [error] is sqlite complaining about [needle], **whatever it is
  /// wrapped in by the time it reaches us.**
  ///
  /// This exists because every guard below used to say `on SqliteException`,
  /// and that is the one thing the application never receives. The database
  /// runs on a background isolate — `NativeDatabase.createInBackground`, see
  /// `database_connection_native.dart` — and drift wraps anything thrown there
  /// in a [DriftRemoteException] before it crosses back. `on SqliteException`
  /// therefore matched in every test (all 54 of them open the database with
  /// `NativeDatabase.memory()`, same isolate, nothing wrapped) and matched
  /// nothing in the running till.
  ///
  /// Measured 2026-08-02 on a real installation still at schema v25: upgrading
  /// died on `no such column: printer_type` — raised inside a guard written
  /// specifically to swallow exactly that, with a comment above it explaining
  /// the pre-v26 case it was handling. The intent was right and the type was
  /// wrong, and no test could tell, because no test opened the database the
  /// way the application does.
  ///
  /// Returns `false` for anything unrecognised, so an error that is *not* the
  /// expected schema complaint is rethrown rather than quietly swallowed.
  ///
  /// Public because it is the thing under test in
  /// `test/unit/data/background_isolate_migration_test.dart`, and it has to be
  /// tested against a genuinely wrapped exception rather than a hand-built one.
  static bool isExpectedSchemaError(Object error, String needle) {
    if (error is SqliteException) return error.message.contains(needle);
    if (error is DriftRemoteException) {
      final cause = error.remoteCause;
      if (cause is SqliteException) return cause.message.contains(needle);
      // drift cannot always send the original object across, in which case
      // the cause arrives as its string form. Matching that is still exact
      // enough: `no such column`/`duplicate column name`/`already exists` are
      // sqlite's own wording, not ours.
      return cause.toString().contains(needle);
    }
    return false;
  }

  Future<void> _safeAddColumn(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    try {
      await m.addColumn(table, column);
    } catch (e) {
      if (isExpectedSchemaError(e, 'duplicate column name')) {
        print(
          '[DB] Column ${column.name} already exists in ${table.actualTableName} — skipping',
        );
      } else {
        rethrow;
      }
    }
  }

  /// [_safeAddColumn]'s counterpart. Uses `ALTER TABLE ... DROP COLUMN`
  /// (sqlite3 3.35.0+; guaranteed by `sqlite3_flutter_libs` on every native
  /// platform this app ships to — proven safe against this project's actual
  /// sqlite3 build by the smoke test in
  /// `test/unit/data/device_migration_test.dart`'s `_readV26Shape`, which has
  /// used this exact mechanism since before this method existed). Catches
  /// "no such column" the same way [_safeAddColumn] catches "duplicate
  /// column name" — idempotent against a database that already had the
  /// column dropped, or a synthetic test fixture that never had it in the
  /// first place.
  Future<void> _safeDropColumn(
    Migrator m,
    TableInfo table,
    String columnName,
  ) async {
    try {
      await m.dropColumn(table, columnName);
    } catch (e) {
      if (isExpectedSchemaError(e, 'no such column')) {
        print(
          '[DB] Column $columnName already absent from ${table.actualTableName} — skipping',
        );
      } else {
        rethrow;
      }
    }
  }

  Future<void> _safeCreateTable(Migrator m, TableInfo table) async {
    try {
      await m.createTable(table);
    } catch (e) {
      if (isExpectedSchemaError(e, 'already exists')) {
        print('[DB] Table ${table.actualTableName} already exists — skipping');
      } else {
        rethrow;
      }
    }
  }

  /// Структурная гарантия того, что не более одного терминала помечен как
  /// `isSelf`. `TerminalDao.ensureSelf()` защищает себя транзакцией, но это
  /// программная осторожность, а не гарантия: этот частичный уникальный
  /// индекс делает вторую строку с isSelf=true физически невозможной на
  /// уровне БД, независимо от того, как её пытаются вставить. Нужен на обоих
  /// путях — и `onCreate` (свежая установка), и миграции v26 (апгрейд) —
  /// иначе гарантия существовала бы только для мигрировавших баз.
  Future<void> _ensureSingleSelfTerminalIndex() async {
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS terminals_single_self '
      'ON ${terminals.actualTableName}(${terminals.isSelf.name}) '
      'WHERE ${terminals.isSelf.name} = 1',
    );
  }

  /// Schema v27's data migration — folds the three legacy device-settings
  /// sources into `TerminalDeviceBindings` for every terminal already in the
  /// table, and `barcodeMinLength`/`barcodeMaxLength` (business rules, not
  /// device settings — И142) into `ThisPosEntries`.
  ///
  /// The blob and `ThisPosEntries.paperWidth`/`printerPort` are
  /// installation-wide in the old model (one machine, one blob, one
  /// `ThisPosEntries` row) — they are only ever handed to the terminal
  /// marked `isSelf`, so a second, browser-registered terminal never
  /// inherits this machine's hardware. Every terminal's own v26 raw columns
  /// (`printerType`, `scannerType`, `scalePort`, `scaleBaudRate`,
  /// `drawerViaPrinter`, `displayPort`) are always its own — see
  /// `LegacyDeviceSettings`'s doc comments
  /// (`lib/data/database/migrations/device_binding_migration.dart`) for the
  /// full per-class reasoning.
  Future<void> _migrateDeviceBindings() async {
    final pos = await thisPosDao.get();
    final allTerminals = await select(terminals).get();

    // The seven legacy per-terminal device columns
    // (`printer_type`/`printer_address`/`scanner_type`/`scale_port`/
    // `scale_baud_rate`/`drawer_via_printer`/`display_port`) are dropped from
    // the `Terminals` Dart table in this same `from < 27` block, right after
    // this method returns — the generated `Terminal` row class above
    // therefore has no typed field for any of them any more. This method
    // still needs their *last* values before they disappear, so it reads
    // them by raw SQL instead of through typed column access, which only
    // ever reflects the current (post-drop) schema.
    //
    // An install upgrading straight from before v26 never had these columns
    // at all — `terminals` was just created a few lines above, by
    // `_safeCreateTable(m, terminals)`, using the *current* (already
    // column-less) `Terminals` definition. The raw SELECT below then fails
    // with "no such column", exactly like `_safeAddColumn`/`_safeDropColumn`
    // treat their own expected failures — caught here the same way, and
    // treated as "nothing to migrate for these fields", not rethrown.
    var legacyById = <int, QueryRow>{};
    try {
      final legacyRows = await customSelect(
        'SELECT id, printer_type, printer_address, scanner_type, '
        'scale_port, scale_baud_rate, drawer_via_printer, display_port '
        'FROM ${terminals.actualTableName}',
      ).get();
      legacyById = {for (final row in legacyRows) row.read<int>('id'): row};
    } catch (e) {
      if (!isExpectedSchemaError(e, 'no such column')) rethrow;
      print(
        '[DB] Terminals has none of the seven legacy device columns — '
        'upgrading from before v26, nothing to migrate for them.',
      );
    }

    for (final terminal in allTerminals) {
      final legacyRow = legacyById[terminal.id];
      final legacy = LegacyDeviceSettings(
        hardwareSettingsBlobJson: terminal.isSelf
            ? legacyHardwareSettingsBlobJson
            : null,
        thisPosPaperWidthChars: terminal.isSelf ? pos?.paperWidth : null,
        terminalPrinterType: legacyRow?.readNullable<String>('printer_type'),
        terminalPrinterAddress: legacyRow?.readNullable<String>(
          'printer_address',
        ),
        terminalScannerType: legacyRow?.readNullable<String>('scanner_type'),
        terminalDrawerViaPrinter: legacyRow?.readNullable<bool>(
          'drawer_via_printer',
        ),
        // `scale_port`/`scale_baud_rate`/`display_port` are still read into
        // `legacyRow` above (harmless — the SELECT already names all seven
        // legacy columns) but no longer passed into `LegacyDeviceSettings`:
        // final review found they were collected and never consumed by any
        // `_infer*` function in device_binding_migration.dart. See that
        // file's `LegacyDeviceSettings` doc comment for why deleting them
        // loses nothing a real migration could have used.
      );
      final result = inferLegacyDeviceMigration(legacy);

      if (terminal.isSelf &&
          pos != null &&
          (result.barcodeMinLength != null ||
              result.barcodeMaxLength != null)) {
        await (update(thisPosEntries)..where((t) => t.rId.equals(true))).write(
          ThisPosEntriesCompanion(
            barcodeMinLength: Value(result.barcodeMinLength),
            barcodeMaxLength: Value(result.barcodeMaxLength),
          ),
        );
      }

      for (final binding in result.bindings) {
        await into(terminalDeviceBindings).insert(
          TerminalDeviceBindingsCompanion.insert(
            terminalId: terminal.id,
            deviceClass: binding.deviceClass.name,
            profileId: binding.profileId,
            // Distinguishes sibling bindings of one class on one terminal
            // (fix round 1) — DeviceBinding carries no identity field of
            // its own yet, so profileId is what's available. See the
            // TerminalDeviceBindings.bindingKey doc comment
            // (lib/data/database/tables/terminal_tables.dart) for why this
            // is enough whenever siblings have distinct profiles, and not a
            // general answer for two bindings of the same class *and*
            // profile.
            bindingKey: binding.profileId,
            parametersJson: Value(jsonEncode(binding.parameters)),
            optionsJson: Value(jsonEncode(binding.options)),
            enabled: Value(binding.enabled),
          ),
        );
      }
    }
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _ensureSingleSelfTerminalIndex();
    },

    onUpgrade: (m, from, to) async {
      if (from < to) {
        try {
          await customStatement("SELECT 1");
          print(
            '[DB] Migration $from → $to starting. '
            'Backup recommended before production migrations.',
          );
        } catch (e) {
          print('[DB] Pre-migration check failed: $e');
        }
      }
      if (from < 2) {
        await _safeAddColumn(m, productInfos, productInfos.quantity);
      }

      if (from < 3) {
        await _safeAddColumn(m, thisPosEntries, thisPosEntries.operatingMode);
        await _safeAddColumn(
          m,
          thisPosEntries,
          thisPosEntries.defaultServiceChargePercent,
        );
        await _safeAddColumn(
          m,
          thisPosEntries,
          thisPosEntries.serviceChargeEnabled,
        );

        await _safeAddColumn(m, sales, sales.orderType);
        await _safeAddColumn(m, sales, sales.serviceCharge);

        await _safeCreateTable(m, restaurantTables);
        await _safeCreateTable(m, restaurantOrders);
        await _safeCreateTable(m, guestSplits);
        await _safeCreateTable(m, serviceOrders);
        await _safeCreateTable(m, serviceMarks);
        await _safeCreateTable(m, serviceTypes);
      }

      if (from < 4) {
        await _safeAddColumn(m, categories, categories.name);
      }

      if (from < 5) {
        await _safeAddColumn(m, serviceMarks, serviceMarks.productUcode);
      }

      if (from < 6) {
        await _safeCreateTable(m, serviceConsumables);
      }

      if (from < 7) {
        await _safeCreateTable(m, serviceOrderPhotos);
        await _safeAddColumn(m, serviceMarks, serviceMarks.approvalStatus);
      }

      if (from < 8) {
        await _safeCreateTable(m, userPermissions);
      }

      if (from < 9) {
        await _safeCreateTable(m, dishIngredients);
      }

      if (from < 10) {
        await _safeAddColumn(m, dishIngredients, dishIngredients.calories);
        await _safeAddColumn(m, dishIngredients, dishIngredients.proteins);
        await _safeAddColumn(m, dishIngredients, dishIngredients.fats);
        await _safeAddColumn(m, dishIngredients, dishIngredients.carbs);
        await _safeAddColumn(
          m,
          dishIngredients,
          dishIngredients.seasonCoefficient,
        );
        await _safeCreateTable(m, dishRecipeVersions);
        await _safeCreateTable(m, dishPhotos);
        await _safeCreateTable(m, gostLossNorms);
      }

      if (from < 11) {
        await _safeCreateTable(m, movements);
        await _safeCreateTable(m, movementProducts);
        await _safeCreateTable(m, supplierReturns);
        await _safeCreateTable(m, supplierReturnProducts);
      }

      if (from < 12) {
        await _safeCreateTable(m, modifierGroups);
        await _safeCreateTable(m, modifierOptions);
        await _safeCreateTable(m, saleProductModifiers);
      }

      if (from < 13) {
        await _safeAddColumn(m, productInfos, productInfos.description);
        await _safeAddColumn(m, productInfos, productInfos.imagePath);
      }

      if (from < 14) {
        await _safeCreateTable(m, warehouses);
        await _safeCreateTable(m, warehouseZones);
        await _safeCreateTable(m, warehouseCells);
        await _safeCreateTable(m, cellStocks);
        await _safeCreateTable(m, batches);
        await _safeCreateTable(m, serials);
        await _safeCreateTable(m, serialMovements);
        await _safeCreateTable(m, markingCodes);
        await _safeCreateTable(m, stockRules);
        await _safeCreateTable(m, warrantyRecords);
        await _safeCreateTable(m, claims);
        await _safeCreateTable(m, claimHistoryEntries);
        await _safeCreateTable(m, productComponents);
        await _safeCreateTable(m, wmsConfigs);
      }

      if (from < 15) {
        await _safeAddColumn(m, wmsConfigs, wmsConfigs.expiryWarningDays);
        await _safeAddColumn(m, payments, payments.approvalCode);
        await _safeAddColumn(m, payments, payments.cardMask);
        await _safeAddColumn(m, payments, payments.terminalTransactionId);
        await _safeAddColumn(m, inventories, inventories.isFullCount);
      }

      if (from < 16) {
        await _safeAddColumn(m, productInfos, productInfos.vatRate);
        await _safeAddColumn(m, productInfos, productInfos.ntin);
        await _safeAddColumn(m, productInfos, productInfos.isMarkable);
        await _safeAddColumn(m, shifts, shifts.openingCash);
      }

      if (from < 17) {
        await _safeCreateTable(m, fiscalQueueEntries);
        await _safeAddColumn(
          m,
          webkassaReceipts,
          webkassaReceipts.registrationNumber,
        );
        await _safeAddColumn(
          m,
          webkassaReceipts,
          webkassaReceipts.originalTotal,
        );
        await _safeAddColumn(m, productInfos, productInfos.brand);
        await _safeAddColumn(m, productInfos, productInfos.manufacturer);
        await _safeAddColumn(m, productInfos, productInfos.countryOfOrigin);
      }

      if (from < 18) {
        await _safeCreateTable(m, promotions);
      }

      if (from < 19) {
        await _safeAddColumn(m, serviceOrders, serviceOrders.warrantyDays);
        await _safeAddColumn(m, serviceOrders, serviceOrders.qualityRating);
        await _safeAddColumn(m, serviceOrders, serviceOrders.qualityNote);
        await _safeAddColumn(m, serviceOrders, serviceOrders.intakeInventory);
        await _safeAddColumn(
          m,
          serviceOrderPhotos,
          serviceOrderPhotos.mediaType,
        );
        await _safeAddColumn(
          m,
          serviceTypes,
          serviceTypes.requiresIntakePhotos,
        );
        await _safeAddColumn(
          m,
          serviceTypes,
          serviceTypes.requiresRepairPhotos,
        );
        await _safeAddColumn(
          m,
          serviceTypes,
          serviceTypes.requiresQualityCheck,
        );
        await _safeAddColumn(
          m,
          serviceTypes,
          serviceTypes.requiresIntakeInventory,
        );
        await _safeAddColumn(m, thisPosEntries, thisPosEntries.blockOversell);
      }

      if (from < 20) {
        // Used to add ThisPosEntries.printerConnectionType/.printerAddress/
        // .printerPort here — final review finding I1 dropped all three
        // (schema v27's migration block further down: the only remaining
        // writer used an unusable second int encoding, and nothing read
        // them either way). An install upgrading from before v20 now simply
        // never has these columns at any point; schema v27's
        // `_safeDropColumn` calls already tolerate "no such column" for
        // exactly this case.
      }

      if (from < 21) {
        await _safeCreateTable(m, restaurantZones);
      }

      if (from < 22) {
        await _safeCreateTable(m, labelTemplates);
        // Used to add ThisPosEntries.labelPrinterConnectionType/
        // .labelPrinterAddress/.labelPrinterPort/.labelPrinterLanguage/
        // .labelWidthMm/.labelHeightMm here — second final-review round
        // dropped all six (schema v27's migration block further down): C4
        // repointed print_price_tag_dialog.dart, their only reader, at the
        // label-printer DeviceBinding instead, and their only writer
        // (ThisPosDao.updateLabelPrinter) already had zero call sites.
        // An install upgrading from before v22 now simply never has these
        // columns at any point; schema v27's `_safeDropColumn` calls
        // already tolerate a column that was never added.
      }

      if (from < 23) {
        await _safeCreateTable(m, receiptTemplates);
      }

      if (from < 24) {
        await _safeAddColumn(m, serviceMarks, serviceMarks.quantity);
      }

      if (from < 25) {
        await _safeAddColumn(m, supplyProducts, supplyProducts.serialNumbers);
      }

      if (from < 26) {
        await _safeCreateTable(m, terminals);
        await _ensureSingleSelfTerminalIndex();

        // Устройства были одни на всю установку. Переносим их в первый
        // терминал и берём его имя из названия кассы. Обратной миграции нет —
        // откат делается целиком (docs/system-architecture.md, раздел 18).
        //
        // Переносим только если установка реально сконфигурирована. Если
        // ThisPosEntries пуста или cashBoxName пуст — свежая установка
        // мигрировала раньше, чем прошёл мастер настройки. В этом случае
        // ничего не создаём: терминал 1 позже создаст ensureSelf() с
        // настоящим именем. Если бы мы вставили здесь плейсхолдер
        // 'Касса-1', ensureSelf() нашёл бы его как уже существующий self()
        // и никогда не заменил бы на настоящее имя — тихая порча данных,
        // которую оператор заметит только по названию кассы, которое он
        // никогда не вводил.
        final pos = await thisPosDao.get();
        final hasConfiguredInstallation =
            pos?.cashBoxName?.trim().isNotEmpty ?? false;
        if (hasConfiguredInstallation) {
          await into(terminals).insert(
            TerminalsCompanion.insert(
              name: pos!.cashBoxName!.trim(),
              isSelf: const Value(true),
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          );
        }
        // `ThisPosEntries.printerAddress`/`.printerConnectionType` are
        // deliberately NOT carried into the new terminal here — schema v27
        // (the `from < 27` block right below, always reached in the same
        // migration run whenever `from < 26`) is the one and only place a
        // terminal's device settings land, in `TerminalDeviceBindings`, and
        // it reads `ThisPosEntries` (`pos?.paperWidth`/`.printerPort`) itself
        // for the self terminal it just created above. Stashing
        // `printerAddress` on `Terminals.printerAddress` first, only for the
        // v27 step to read it back a moment later, made sense while that
        // column existed; it does not any more — task 5 (this task) dropped
        // it, together with the other six `Terminals` device columns, once
        // `TerminalDeviceBindings` carried their content instead. See
        // task-5-report.md.
        //
        // Net behaviour change for this one, narrow, already-historical path
        // (an install still on pre-v26 schema being upgraded straight to
        // v27): `ThisPosEntries.printerConnectionType` was already never
        // carried over (ambiguous encoding, see above) and
        // `ThisPosEntries.printerAddress` alone was never enough to produce a
        // receipt-printer binding either (the shipped catalogue's two
        // receipt-printer profiles both need the connection kind or the
        // paper width to narrow, neither of which this path ever had) — so no
        // currently-possible receipt-printer binding is lost. What IS lost
        // for this path only: the cash drawer no longer defaults to "wired
        // via the printer" (`drawer.rj11.via-printer`, which needs no
        // parameters and previously bound automatically because
        // `Terminals.drawerViaPrinter` defaulted to `true`). An operator
        // upgrading straight from before v26 now sees no cash-drawer binding
        // and configures one explicitly, rather than inheriting a silent
        // default that no longer has a column to live in.
      }

      if (from < 27) {
        await _safeCreateTable(m, terminalDeviceBindings);
        await _safeAddColumn(
          m,
          thisPosEntries,
          thisPosEntries.barcodeMinLength,
        );
        await _safeAddColumn(
          m,
          thisPosEntries,
          thisPosEntries.barcodeMaxLength,
        );

        // Rahmet removed from the product entirely (product owner, mid
        // fix-round-1 on this task — see task-2-report.md). Unlike the
        // `terminals` columns below, this one drops cleanly: it is a lone
        // `BoolColumn` on `ThisPosEntries`, referenced by no other table,
        // view, index or trigger, so `ALTER TABLE ... DROP COLUMN` (sqlite3
        // 3.35.0+, guaranteed by `sqlite3_flutter_libs`) needs no table
        // rebuild.
        await _safeDropColumn(m, thisPosEntries, 'is_rahmet_payment_enabled');

        // Read the seven legacy `terminals` device columns as a **source**
        // before dropping them below — task 2 deliberately left this
        // ordering note here (see task-2-report.md) for whoever did the
        // drop, and this is that step: task 5.
        await _migrateDeviceBindings();

        // printerType/printerAddress/scannerType/scalePort/scaleBaudRate/
        // drawerViaPrinter/displayPort on `terminals` are now dead: their
        // content lives in `TerminalDeviceBindings` (just populated above,
        // for every terminal already in this database) and every reader —
        // `TerminalRepository`/`LocalTerminalRepository`
        // (lib/data/terminal/terminal_repository_local.dart) and the HTTP
        // contract (lib/backend/terminal_routes.dart,
        // lib/domain/wire/terminal_wire.dart, lib/web/http_terminal_repository.dart)
        // — was moved onto the bindings table in the same task (task 5).
        // `ALTER TABLE ... DROP COLUMN` (sqlite3 3.35.0+, guaranteed by
        // `sqlite3_flutter_libs`) needs no table rebuild, same mechanism
        // already proven above for `is_rahmet_payment_enabled` and by the
        // smoke test in `test/unit/data/device_migration_test.dart`.
        await _safeDropColumn(m, terminals, 'printer_type');
        await _safeDropColumn(m, terminals, 'printer_address');
        await _safeDropColumn(m, terminals, 'scanner_type');
        await _safeDropColumn(m, terminals, 'scale_port');
        await _safeDropColumn(m, terminals, 'scale_baud_rate');
        await _safeDropColumn(m, terminals, 'drawer_via_printer');
        await _safeDropColumn(m, terminals, 'display_port');

        // `ThisPosEntries.printerConnectionType`/`.printerAddress`/
        // `.printerPort` — final review finding I1. Their only remaining
        // writer was `LocalSetupRepository.completeSetup`
        // (lib/data/setup/setup_repository_local.dart), storing
        // `printerConnectionType.index - 1`: a *second*, incompatible
        // int encoding of `PrinterConnectionType` layered onto the same
        // column the pre-branch `printer_settings_screen.dart` used to write
        // with its own (different) encoding — "the index-1 encoding this
        // plan documents as unusable". That write is removed in this same
        // change (see setup_repository_local.dart), which leaves these three
        // columns with no writer and — already, before that removal — no
        // reader anywhere in the codebase.
        //
        // Safe to drop without a raw-SQL "read the last value before it
        // disappears" step, unlike the seven `Terminals` columns above —
        // but not for the reason first given here (second-review-round
        // correction). The original claim was that any live value here was
        // always mirrored into the `hardware_settings` blob's
        // `receiptPrinterAddress`/`receiptPrinterPort`/`receiptPrinterType`
        // by `printer_settings_screen.dart`'s pre-branch `_saveSettings`, in
        // the same button press. That is false for a till configured
        // *only* through the setup wizard: the wizard's own blob writer,
        // pre-branch `_persistHardwareSettings`, wrote scanner/drawer/
        // scale/display/Kaspi/Rahmet keys but no `receiptPrinter*` key at
        // all — so a wizard-only till's printer address lived in these
        // `ThisPosEntries` columns and nowhere else in the blob.
        //
        // The drop is still safe, for a simpler reason: nothing has ever
        // read `ThisPosEntries.printerConnectionType`/`.printerAddress`/
        // `.printerPort`. The v26→v27 migration's receipt-printer inference
        // (`_inferReceiptPrinterBinding`,
        // lib/data/database/migrations/device_binding_migration.dart) reads
        // `Terminals.printerType`/`.printerAddress` (the HTTP-route-only v26
        // columns) and the blob — never these `ThisPosEntries` columns — so
        // it was never sourced from them regardless of who wrote them. And
        // a brand-new wizard-configured till's printer binding comes from
        // `LocalSetupRepository._createDeviceBindings`
        // (lib/data/setup/setup_repository_local.dart), which reads
        // `equip.printerConnectionType`/`.printerAddress` directly off the
        // in-memory `SetupDraft` at `completeSetup` time — never through a
        // database round-trip via `ThisPosEntries` at all. The dead write
        // this same change removes from `setup_repository_local.dart` was
        // always redundant noise alongside that already-working path, not
        // a till's only copy of a fact something depended on.
        await _safeDropColumn(m, thisPosEntries, 'printer_connection_type');
        await _safeDropColumn(m, thisPosEntries, 'printer_address');
        await _safeDropColumn(m, thisPosEntries, 'printer_port');

        // `ThisPosEntries.labelPrinterConnectionType`/`.labelPrinterAddress`/
        // `.labelPrinterPort`/`.labelPrinterLanguage`/`.labelWidthMm`/
        // `.labelHeightMm` — second final-review-round finding, raised
        // alongside C4: fixing `print_price_tag_dialog.dart` to read the
        // label-printer `DeviceBinding` instead of these columns left their
        // only writer (`ThisPosDao.updateLabelPrinter`, already zero call
        // sites before this) and only reader both dead — new dead code of
        // the exact kind finding I1 objected to, created by this same
        // change rather than inherited from an earlier one. No raw-SQL
        // pre-read needed: `updateLabelPrinter` had no call sites already,
        // so no installation has written a live value here since before
        // this branch existed, and the label-printer binding
        // `LocalDeviceBindingRepository` saves is the one live source now.
        await _safeDropColumn(
          m,
          thisPosEntries,
          'label_printer_connection_type',
        );
        await _safeDropColumn(m, thisPosEntries, 'label_printer_address');
        await _safeDropColumn(m, thisPosEntries, 'label_printer_port');
        await _safeDropColumn(m, thisPosEntries, 'label_printer_language');
        await _safeDropColumn(m, thisPosEntries, 'label_width_mm');
        await _safeDropColumn(m, thisPosEntries, 'label_height_mm');
      }

      if (from < 28) {
        // `scannerTimeoutMs` — task 5(c) of plan 2b
        // (device-discovery-and-tests). Deliberately left with no home by
        // the v27 migration (see this migration's own `scannerTimeout` row
        // in `lib/data/database/migrations/device_binding_migration.dart`'s
        // blob-key inventory): not a connection parameter any scanner
        // profile declares (И141), and — like `barcodeMinLength`/
        // `barcodeMaxLength` right above it on this same table — a business
        // rule about how to interpret what a keyboard-wedge scanner sends,
        // not a device setting (И142).
        await _safeAddColumn(
          m,
          thisPosEntries,
          thisPosEntries.scannerTimeoutMs,
        );

        // Carry the old value forward — fix round 1 correction: the first
        // version of this block left the column with no value at all,
        // reasoning that the v27 step above "already ran and didn't carry
        // it forward". True only for an installation crossing v26->v28 in
        // one launch; false for the far more common case of an installation
        // already sitting at v27, upgrading straight to v28 — for that one,
        // the `from < 27` block above does not run at all (`from` is
        // already 27), so it never had a chance to read the blob, and
        // `scannerTimeoutMs` would have silently landed on the fixed
        // default for every existing operator who had actually set a
        // scanner timeout. `legacyHardwareSettingsBlobJson` is read
        // unconditionally on every app start (`service_locator.dart`) and
        // nothing has ever cleared the `hardware_settings` SharedPreferences
        // key, so it is still available here regardless of which of the two
        // paths this installation took — [migrateLegacyScannerTimeoutMs] is
        // deliberately a standalone function, not folded into
        // [inferLegacyDeviceMigration]/`_migrateDeviceBindings()`, precisely
        // so it can run unconditionally here without re-running binding
        // inference (which would risk inserting duplicate bindings for an
        // installation that already has them from a previous v27 upgrade).
        final legacyScannerTimeoutMs = migrateLegacyScannerTimeoutMs(
          legacyHardwareSettingsBlobJson,
        );
        if (legacyScannerTimeoutMs != null) {
          final pos = await thisPosDao.get();
          if (pos != null) {
            await (update(
              thisPosEntries,
            )..where((t) => t.rId.equals(true))).write(
              ThisPosEntriesCompanion(
                scannerTimeoutMs: Value(legacyScannerTimeoutMs),
              ),
            );
          }
        }
      }

      if (from < 29) {
        // Очередь печати на диске — план 2в, задача 2. Две новые таблицы и
        // ничего больше: существующие данные не читаются и не переносятся,
        // потому что переносить нечего — до этой версии задание печати нигде
        // не сохранялось вовсе (удалённый задачей 1 `PrinterScheduler` держал
        // их в памяти процесса).
        //
        // Таблицы создаются раздельно и **связи между ними нет**: строка
        // подтверждения обязана пережить уборку самого задания, иначе
        // идемпотентность живёт ровно до первой уборки. См.
        // `lib/data/database/tables/print_tables.dart`.
        // `_safeCreateTable`, а не `m.createTable`, — как в соседних ветках
        // (v19, v20): установка, уже получившая эти таблицы на не влитой
        // ветке, не должна падать на «table already exists».
        await _safeCreateTable(m, printJobs);
        await _safeCreateTable(m, printJobConfirmations);
      }

      if (from < 30) {
        // `ThisPosEntries.rejectFromTime`/`.rejectToTime` — окно, в которое
        // печать запрещена. План 2в, задача 3.
        //
        // Ни писателя, ни читателя: грепом по всему дереву обе колонки
        // встречались только в определении таблицы и в двух мёртвых классах
        // `PrinterConfig` (`lib/hardware/printer/printer_config.dart` и
        // `lib/domain/entities/config/printer_config.dart`), удалённых в этой
        // же ветке отдельным коммитом. Ни экрана, чтобы это окно задать, ни
        // строки документации, ни инварианта в docs/system-architecture.md —
        // то есть правило, которого никто не объявлял и никто не применял.
        //
        // Предварительного чтения сырым SQL не нужно, и по той же причине,
        // что у `label_printer_*` в блоке `from < 27`: писателя не было
        // никогда, поэтому живого значения ни в одной установке здесь нет —
        // убирается заведомо пустая колонка, а не последняя копия факта.
        //
        // `ALTER TABLE ... DROP COLUMN` (sqlite3 3.35.0+, гарантируется
        // `sqlite3_flutter_libs`) перестройки таблицы не требует: обе колонки
        // одиночные, `TEXT NULL`, и не участвуют ни в индексе, ни в
        // представлении, ни в триггере. Тот же механизм уже дважды применён
        // выше и проверен дымовым тестом в
        // `test/unit/data/device_migration_test.dart`.
        await _safeDropColumn(m, thisPosEntries, 'reject_from_time');
        await _safeDropColumn(m, thisPosEntries, 'reject_to_time');
      }

      if (from < 31) {
        // Таблица `bug_reports` уходит вместе со всей подсистемой отчётов об
        // ошибках, удалённой в этом же коммите.
        //
        // Почему удаление безопасно — тем же рассуждением, что и в блоке
        // `from < 30` выше: **писателя не было никогда**. Единственный код,
        // который вообще вставлял сюда строки, — `BugReportStorageImpl`, а он
        // ни разу не создавался: грепом по всему дереву `BugReportStorageImpl(`
        // встречался только в собственном конструкторе, DI его не
        // регистрировал. Значит, в любой установке таблица заведомо пуста, и
        // уносится пустая таблица, а не последняя копия факта.
        //
        // Почему уходит вся подсистема, а не приводится в рабочий вид: в
        // `docs/system-architecture.md` нет ни одного упоминания отчётов об
        // ошибках и ни одного инварианта на них, экрана или пункта меню,
        // ведущего к отправке, тоже нет. При этом живой путь для ошибок в
        // приложении уже есть и он другой — `runZonedGuarded` и
        // `FlutterError.onError` в `lib/main.dart` сводят всё в talker и
        // дальше в RFC 5424 syslog. Подсистема была вторым, параллельным и
        // никогда не подключённым механизмом, у которого обе «отправки» были
        // заглушками: `Future.delayed(100ms)` и пометка `isSent = true` без
        // единого сетевого вызова. Хуже отсутствующего кода: она создавала
        // впечатление, что отчёты собираются и уходят.
        //
        // `deleteTable` разворачивается в `DROP TABLE IF EXISTS`, то есть
        // идемпотентна сама по себе — обёртка вроде `_safeDropColumn` здесь
        // не нужна, повторный прогон на установке без таблицы промолчит.
        await m.deleteTable('bug_reports');
      }

      if (from < 32) {
        // Две настройки входа переезжают в базу, а не в SharedPreferences, и
        // это обратное решение относительно `ListenScope` — по обратной
        // причине. Открытость порта — свойство машины: база, уехавшая на
        // другую машину, ничего о её сети не знает. Walk-up и срок сеанса —
        // свойства точки: они обязаны уехать вместе с ней.
        //
        // Обе с умолчанием, поэтому существующие установки получают
        // выключенный walk-up и тридцать минут, ничего у них не спрашивая.
        await _safeAddColumn(m, thisPosEntries, thisPosEntries.walkUpEnabled);
        await _safeAddColumn(
          m,
          thisPosEntries,
          thisPosEntries.sessionIdleMinutes,
        );
      }

      if (from < 33) {
        // Задача 15 (план «замок кассы», фаза 5). Готовит переворот умолчания
        // в `UserPermissionDao.getAllowedKeys` (задача 16): сегодня пустая
        // строка прав читается как «разрешено», значение несёт только
        // запрет (`isAllowed = false`); после переворота будет наоборот —
        // значение будет нести только разрешение. Эта миграция обязана
        // записать каждому существующему пользователю ровно то, что у него
        // действует **сегодня**, явными строками, чтобы переворот не изменил
        // ничьё поведение.
        //
        // Владелец не участвует. `LocalAuthRepository._issue` выдаёт ему
        // `PermissionKeys.allPermissions` в обход таблицы прав целиком (см.
        // ту же ветку кода и комментарий к `PermissionKeys.roleDefaults`) —
        // ни сегодня, ни после переворота задачи 16 строки в этой таблице на
        // владельца не влияют. Писать их означало бы завести данные, у
        // которых нет читателя, — то самое «мёртвый код, выглядящий живым»,
        // только в данных, а не в коде.
        //
        // # Правка Б-1 закрытия долга безопасности (2026-08-22): снято
        // исключение «уже новая модель»
        //
        // До этой правки здесь стояла развилка по содержимому строк:
        // «есть хотя бы одна `isAllowed = true` → пользователь уже заведён
        // НОВЫМ путём (задача 13), миграция его не трогает вовсе». Признак
        // был неверным: `existingRows.any((row) => row.isAllowed)` молча
        // предполагает, что раз есть хоть одна разрешающая строка, набор
        // строк ПОЛОН относительно нынешнего словаря `PermissionKeys
        // .allPermissions`, — а это не гарантировано. Форма редактирования
        // (`user_management_screen.dart`) пишет строки на ключи ТОГО билда,
        // в котором её открыли: у пользователя, отредактированного до
        // пополнения словаря новым ключом, строки на этот ключ нет вовсе, а
        // старое (до задачи 16) чтение читало отсутствие строки как
        // «разрешено» — после переворота такой ключ тихо терялся бы,
        // потому что развилка выше молчала «уже новая модель, не трогать».
        //
        // Хуже: сама причина, ради которой развилку заводили, — популяция
        // строк по ролям мастером после задачи 13 — в поле НЕ СУЩЕСТВУЕТ.
        // Мастер (`setup_repository_local.dart
        // ._writeRoleDefaultPermissions`) и форма (`user_management_screen
        // .dart`) обе пишут строки задачи 13 в ЭТОЙ ЖЕ невыпущенной ветке,
        // что и эта миграция, — то есть ни одна база, которая реально
        // проходит эту ветку НЕ УСТАНОВЛЕННОЙ версией, физически не
        // могла получить строки нового вида (задачи 13/14 попросту не
        // существовали в билде, из которого она мигрирует). Любая
        // настоящая мигрирующая база — старой модели без исключений.
        //
        // Правило стало простым и без развилки: для каждого не-владельца, на
        // КАЖДЫЙ ключ словаря — если строки нет, записать «разрешено»
        // (старое эффективное значение пустой ячейки); если строка уже
        // есть — не трогать её вовсе, независимо от того, что там записано.
        // Работает единообразно для обеих моделей, если вторая когда-нибудь
        // появится в поле: у пользователя старой модели «разрешено» — верное
        // старое эффективное значение недостающего ключа; у гипотетического
        // пользователя новой модели с частичными разрешающими строками (по
        // роли) недостающие ключи — это ровно то, что роль явно не даёт по
        // умолчанию, но поскольку такого пользователя в поле нет и быть не
        // может (см. абзац выше), этот случай не возникает — правило просто
        // не различает модели, потому что различать здесь больше нечего.
        final allUsers = await userDao.findAll();
        for (final user in allUsers) {
          if (user.role == UserRole.owner.index) continue;

          final existingRows = await userPermissionDao.findByUserId(user.id);
          final presentKeys = existingRows
              .map((row) => row.permissionKey)
              .toSet();

          for (final key in PermissionKeys.allPermissions) {
            if (presentKeys.contains(key)) {
              // Строка уже есть — оставляем как есть в обеих моделях (в
              // старой это точечный запрет, уже верный; в гипотетической
              // новой — явное значение по роли).
              continue;
            }
            await into(userPermissions).insert(
              UserPermissionsCompanion.insert(
                userId: user.id,
                permissionKey: key,
                isAllowed: const Value(true),
              ),
            );
          }
        }
      }

      if (from < 34) {
        // Задача 20 (план «замок кассы», фаза 8) — журнал событий
        // безопасности (И66–И69, docs/system-architecture.md, раздел 15).
        // До этой версии подсистемы аудита в приложении не было вовсе — ни
        // таблицы, ни строки миграции. Только `CREATE TABLE`: таблица
        // новая, переносить в неё из старой схемы нечего.
        await _safeCreateTable(m, securityEvents);
      }

      if (from < 35) {
        // Правка «второй порядок» закрытия долга безопасности (2026-08-22),
        // пункт 1: три ключа добавлены в `PermissionKeys.allPermissions`
        // (`settingsTerminalService`, `settingsLogJournal`,
        // `settingsAppliance`) для трёх маршрутов, у которых раньше не было
        // защиты никаким механизмом. Докстринг `allPermissions` называет
        // правило прямо: таблица `user_permissions` — allow-list с версии
        // задачи 16 (пустая строка = запрещено), и ключ, добавленный в
        // словарь без шага миграции, молча становится отказом для КАЖДОГО
        // существующего не-владельца — у него просто нет строки на него.
        // Администратор сегодня вычисляется как `allPermissions` минус
        // `settingsUsers` (`roleDefaults`), поэтому без этой миграции три
        // новых ключа читались бы как отказ даже для роли, которой они
        // полагаются по умолчанию.
        //
        // Правило то же самое, каким мастер первого запуска заводит нового
        // пользователя (`SetupRepositoryLocal._writeRoleDefaultPermissions`):
        // строка пишется, только если ключ есть в `roleDefaults[role]`, и
        // только `isAllowed = true` — отсутствие ключа в умолчаниях роли
        // остаётся отсутствием строки, а не запретительной записью, потому
        // что таблица уже allow-list (в отличие от версии 32→33 ниже,
        // которая писала «разрешено» на любой недостающий ключ ради старой,
        // перевёрнутой с задачи 16 семантики «пусто = разрешено»). Владелец
        // не участвует — по той же причине, что и версией раньше:
        // `LocalAuthRepository._issue` выдаёт ему `allPermissions` в обход
        // этой таблицы целиком.
        const newKeys = {
          PermissionKeys.settingsTerminalService,
          PermissionKeys.settingsLogJournal,
          PermissionKeys.settingsAppliance,
        };

        final allUsers = await userDao.findAll();
        for (final user in allUsers) {
          if (user.role == null || user.role == UserRole.owner.index) {
            continue;
          }

          final role = UserRole.fromIndex(user.role!);
          final defaults = PermissionKeys.roleDefaults[role] ?? const <String>{};

          final existingRows = await userPermissionDao.findByUserId(user.id);
          final presentKeys = existingRows
              .map((row) => row.permissionKey)
              .toSet();

          for (final key in newKeys) {
            if (presentKeys.contains(key)) continue;
            if (!defaults.contains(key)) continue;

            await into(userPermissions).insert(
              UserPermissionsCompanion.insert(
                userId: user.id,
                permissionKey: key,
                isAllowed: const Value(true),
              ),
            );
          }
        }
      }

      if (from < 36) {
        // Задача 4 плана «знакомство терминала с кассой» (шаг 2 спеки,
        // docs/internal/superpowers/specs/2026-08-23-terminal-enrolment-design.md):
        // `Terminals.secretFingerprint` — отпечаток высокоэнтропийного
        // секрета, которым терминал впредь предъявляется на новой QUIC-сессии
        // вместо повторного `terminals.register` (задача 6, ещё не сделана в
        // этой версии). Только `ADD COLUMN` — данных, которые нужно было бы
        // перенести, нет: секрета не существовало до этой версии ни у одной
        // строки, придумывать его задним числом было бы неправдой (см.
        // докстринг колонки, `terminal_tables.dart`). Строки, заведённые
        // раньше этой миграции, остаются с `secretFingerprint == NULL`
        // навсегда — до задачи 8 (удаление терминала) единственный путь
        // получить им секрет — переустановиться заново тем же путём, каким
        // заводится любой новый терминал.
        await _safeAddColumn(m, terminals, terminals.secretFingerprint);
      }
    },

    beforeOpen: (details) async {
      if (details.hadUpgrade) {
        print(
          '[DB] Migration completed: '
          'v${details.versionBefore} → v${details.versionNow}',
        );
      }

      await customStatement('PRAGMA foreign_keys = ON');

      await customStatement('PRAGMA journal_mode = WAL');

      if (details.hadUpgrade) {
        final result = await customSelect('PRAGMA integrity_check').get();
        final status = result.first.read<String>('integrity_check');
        if (status != 'ok') {
          print('[DB] WARNING: integrity check failed: $status');
        } else {
          print(
            '[DB] Integrity check passed after migration '
            'v${details.versionBefore} → v${details.versionNow}',
          );
        }
      }
    },
  );
}
