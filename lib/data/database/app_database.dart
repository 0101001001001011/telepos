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
import 'package:telepos/data/database/daos/payment_intent_dao.dart';
import 'package:telepos/data/database/daos/qr_provider_config_dao.dart';
import 'package:telepos/data/database/daos/payment_kind_dao.dart';
import 'package:telepos/data/database/daos/certificate_dao.dart';
import 'package:telepos/data/database/daos/credit_dao.dart';
import 'package:telepos/data/database/daos/prepayment_intake_dao.dart';
import 'package:telepos/data/database/daos/fiscal_owed_report_dao.dart';
import 'package:telepos/data/database/daos/prepayment_refund_dao.dart';
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
import 'package:telepos/data/database/tables/bonus_tables.dart';
import 'package:telepos/data/database/tables/payment_intent_tables.dart';
import 'package:telepos/data/database/tables/qr_provider_tables.dart';
import 'package:telepos/data/database/tables/payment_kind_tables.dart';
import 'package:telepos/data/database/tables/certificate_refund_tables.dart';
import 'package:telepos/data/database/tables/certificate_tables.dart';
import 'package:telepos/data/database/tables/credit_tables.dart';
import 'package:telepos/data/database/tables/prepayment_intake_tables.dart';
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/payment/payment_kind_resolver.dart';
import 'package:telepos/domain/bonus/bonus_entry_kind.dart';
import 'package:telepos/domain/fiscal/bonus_account_types.dart';
import 'package:telepos/data/database/daos/bonus_entry_dao.dart';
import 'package:telepos/data/database/tables/discount_tables.dart';
import 'package:telepos/data/database/daos/sale_discount_dao.dart';
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
    FiscalOwedReports,
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
    DiscountLimits,
    BonusEntries,
    SaleDiscounts,
    DiscountAuditEntries,
    PaymentKinds,
    PaymentIntents,
    GiftCertificates,
    CertificateRefundLinks,
    CreditContracts,
    CreditScheduleEntries,
    QrProviderConfigs,
    PrepaymentIntakes,
    PrepaymentRefunds,
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
    PaymentKindDao,
    PaymentIntentDao,
    QrProviderConfigDao,
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
    FiscalOwedReportDao,
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
    BonusEntryDao,
    SaleDiscountDao,
    CertificateDao,
    CreditDao,
    PrepaymentIntakeDao,
    PrepaymentRefundDao,
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
  int get schemaVersion => 53;

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

  /// Посев девяти системных видов оплаты — миграция v41, задача 14.
  ///
  /// `seed` (то есть `insertOrIgnore`), а не перезапись: установка,
  /// прошедшая v41 и открытая заново, придёт сюда второй раз, и
  /// перезапись **стёрла бы настройку оператора** — вернула бы
  /// выключенному сертификату включённость, а перенастроенной фискальной
  /// трактовке умолчание. Тот же довод, что у
  /// `_ensureDefaultDiscountLimit`.
  Future<void> _seedSystemPaymentKinds() async {
    for (final kind in SystemPaymentKinds.all) {
      await paymentKindDao.seed(kind);
    }
  }

  /// Вид «Сертификат» получает счёт-получатель — миграция v44, задача 21.
  ///
  /// # Почему это отдельная поправка, а не посев
  ///
  /// [_seedSystemPaymentKinds] сеет через `insertOrIgnore`, и это
  /// правильно: перезапись стёрла бы настройку оператора. Но на кассе,
  /// прошедшей v41, строка вида 5 **уже есть** — с пустым
  /// счётом-получателем, потому что рода счёта под обязательство тогда не
  /// существовало (докстринг `SystemPaymentKinds`). Посев её не тронет, и
  /// вид останется невключаемым навсегда: `PaymentKindRules` не даёт
  /// включить незачётный вид без счёта.
  ///
  /// # Почему условие такое узкое
  ///
  /// `payee_account_type IS NULL` — потому что оператор мог назвать счёт
  /// сам, и переписать его нашим значением значило бы отменить его
  /// решение. `id = 5` — потому что поправляется **системный** вид, а
  /// пользовательские виды миграция не трогает вовсе.
  ///
  /// Род, а не конкретный счёт: счёт у каждой кассы свой, и рассылать его
  /// номер в справочнике, который синхронизируется между кассами, нельзя
  /// (докстринг `PaymentKinds.payeeAccountType`). Сам счёт заводится при
  /// первом выпуске сертификата — `LocalCertificateIssuer`.
  Future<void> _pointCertificateKindAtLiabilityAccount() async {
    if (!await _tableExists('payment_kinds')) return;
    await customStatement(
      'UPDATE payment_kinds SET payee_account_type = ? '
      'WHERE id = ? AND payee_account_type IS NULL',
      [AccountType.certificateLiability, SystemPaymentKindIds.certificate],
    );
  }

  /// Выдать [newKeys] существующим пользователям **по умолчанию их роли**.
  ///
  /// # Почему без этого шага новый ключ не работает ни у кого
  ///
  /// `user_permissions` с задачи 16 — **allow-list**: пустая строка
  /// означает «запрещено», а не «разрешено». Ключ, добавленный в
  /// `PermissionKeys.allPermissions` без миграции, у каждого
  /// существующего не-владельца строки не имеет — и потому читается
  /// отказом. Новая возможность тихо не работает ни для кого, включая
  /// роль, которой она полагается по умолчанию.
  ///
  /// # Правило то же, каким мастер заводит нового пользователя
  ///
  /// Строка пишется, только если ключ есть в `roleDefaults[role]`, и
  /// только `isAllowed = true`: отсутствие ключа в умолчаниях роли
  /// остаётся **отсутствием строки**, а не запретительной записью —
  /// таблица уже allow-list. Владелец не участвует:
  /// `LocalAuthRepository._issue` выдаёт ему `allPermissions` в обход
  /// этой таблицы целиком, и строки на него были бы данными без читателя.
  ///
  /// Пользователь без роли пропускается: роли у него нет, умолчаний тоже,
  /// и выдумывать их значит выдать право по догадке.
  ///
  /// Выделено из ветки `from < 35` задачей 24: рассрочка добавляет второй
  /// ключ, и второй такой же цикл рядом был бы вторым ответом на один
  /// вопрос.
  Future<void> _grantNewPermissionKeys(Set<String> newKeys) async {
    // # Почему шаг спрашивает про таблицы, а не считает их существующими
    //
    // Он зовётся из миграции, а миграцию гоняют **фикстуры**, собранные
    // из урезанного DDL: проба подъёма с v36 держит ровно те таблицы,
    // которые ей нужны, и `users` среди них нет. Без этого вопроса шаг
    // ронял бы `SqliteException(1): no such table: users` **девятнадцать**
    // проб миграций — измерено набором сразу после того, как v45 позвала
    // его первой.
    //
    // На настоящей кассе обе таблицы есть всегда (обе заведены задолго до
    // v45), так что пропуск здесь не ослабляет выдачу права: он лишь
    // объявляет, что шаг не имеет права требовать соседей. Тот же приём и
    // тот же довод, что у [_pointCertificateKindAtLiabilityAccount].
    if (!await _tableExists('users')) return;
    if (!await _tableExists('user_permissions')) return;
    final allUsers = await userDao.findAll();
    final grants = <UserPermissionsCompanion>[];
    for (final user in allUsers) {
      if (user.role == null || user.role == UserRole.owner.index) {
        continue;
      }

      final role = UserRole.fromIndex(user.role!);
      final defaults = PermissionKeys.roleDefaults[role] ?? const <String>{};

      final existingRows = await userPermissionDao.findByUserId(user.id);
      final presentKeys = existingRows.map((row) => row.permissionKey).toSet();

      for (final key in newKeys) {
        if (presentKeys.contains(key)) continue;
        if (!defaults.contains(key)) continue;

        grants.add(
          UserPermissionsCompanion.insert(
            userId: user.id,
            permissionKey: key,
            isAllowed: const Value(true),
          ),
        );
      }
    }
    // Одним оборотом — тот же довод, что у [_seedBonusOpeningBalances] и у
    // ветки `from < 33`. Здесь ключей единицы, а не десятки, так что цена
    // меньше; но форма «строка за оборот» уже стоила шестидесяти секунд в
    // одном месте, и оставлять её рядом значит ждать, когда сюда приедет
    // десяток ключей.
    if (grants.isEmpty) return;
    await batch((b) => b.insertAll(userPermissions, grants));
  }

  /// Перестройка `Payments` под вид оплаты — миграция v41, задача 14.
  ///
  /// # Порядок обязателен, и вот почему
  ///
  /// Новый уникальный ключ — `{receiptNo, posId, seq}`. Перестроить
  /// таблицу **до** проставления `seq` нельзя: у всех строк он был бы
  /// нулём от умолчания, и первый же чек с двумя платежами уронил бы
  /// миграцию на своём же новом ключе — на кассе клиента, посреди
  /// обновления. Поэтому колонки добавляются `ALTER TABLE` (ключей не
  /// трогает), заполняются, и только потом таблица переписывается копией
  /// под новые ключи.
  ///
  /// # `kind_id` — тем самым одним выражением
  ///
  /// `CASE` собирается из `PaymentKindDerivation.sqlCase`, а не пишется
  /// рядом второй рукой. `CASE`, отставший от правила на один род счёта,
  /// — порча, которой негде покраснеть: она мигрирует меньше строк, чем
  /// нужно, и молчит.
  ///
  /// Строка, чей счёт **снесён**, остаётся без вида: подзапрос отдаёт
  /// `NULL`. Это не «наличные по умолчанию» — разбор в докстринге
  /// `Payments.kindId`.
  /// Есть ли такая таблица в базе, которую мы открываем.
  ///
  /// Нужна не из осторожности, а по замеру: **десять проб прежних
  /// миграций поднимают базу, в которой нет ни `payments`, ни
  /// `accounts`** — они сеют ровно те таблицы, про которые спрашивают. Та
  /// же беда была у `_seedBonusOpeningBalances` и решена тем же доводом:
  /// миграция обязана пережить базу, которая выглядит не так, как
  /// ожидалось, иначе одна кривая установка останавливает обновление
  /// всем.
  Future<bool> _tableExists(String name) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable.withString(name)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<void> _rebuildPaymentsWithKind(Migrator m) async {
    if (!await _tableExists('payments')) {
      // Таблицы денег нет вовсе — перестраивать нечего. Создаём её сразу
      // в новом виде и уходим: переписывать пустоту копией бессмысленно.
      await _safeCreateTable(m, payments);
      return;
    }

    await _safeAddColumn(m, payments, payments.kindId);
    await _safeAddColumn(m, payments, payments.seq);
    await _safeAddColumn(m, payments, payments.commandKey);
    await _safeAddColumn(m, payments, payments.reference);
    await _safeAddColumn(m, payments, payments.providerCode);

    if (await _tableExists('accounts')) {
      await customStatement(
        'UPDATE payments SET kind_id = ('
        'SELECT ${PaymentKindDerivation.sqlCase('a.type')} '
        'FROM accounts a WHERE a.id = payments.payee_account_id)',
      );
    }

    // `seq` внутри чека — по возрастанию `id`, то есть по порядку
    // записи. Оконная функция не нужна и намеренно не взята: подзапрос
    // читается без знания о версии sqlite, а строк на один чек — единицы.
    await customStatement(
      'UPDATE payments SET seq = ('
      'SELECT COUNT(*) FROM payments p2 '
      'WHERE p2.receipt_no = payments.receipt_no '
      'AND p2.pos_id = payments.pos_id AND p2.id < payments.id) '
      'WHERE receipt_no IS NOT NULL AND pos_id IS NOT NULL',
    );
    await customStatement(
      'UPDATE payments SET seq = ('
      'SELECT COUNT(*) FROM payments p2 '
      'WHERE p2.refund_local_id = payments.refund_local_id '
      'AND p2.id < payments.id) '
      'WHERE refund_local_id IS NOT NULL',
    );

    // Строки без чека и без возврата (`countUnsynced` их и ищет)
    // остаются с `seq = 0` — и не сталкиваются: в sqlite `NULL` в
    // уникальном ключе не равен `NULL`.
    await m.alterTable(TableMigration(payments));
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
  /// Кладёт строку умолчания предела скидки, если её ещё нет.
  ///
  /// `insertOrIgnore`, а не `insert` и не `insertOnConflictUpdate`: первый
  /// упал бы на первичном ключе при повторном заходе, второй **стёр бы
  /// назначенный владельцем предел**, вернув сто процентов молча.
  /// Стартовые остатки бонусного журнала — миграция v40, шаг 7 задачи 13.
  ///
  /// Одна запись на каждый бонусный счёт с ненулевым остатком, чтобы
  /// «остаток равен сумме журнала» держалось с первой секунды.
  ///
  /// # Три решения, каждое стоит объяснения
  ///
  /// **Счёт с нулевым остатком записи не получает.** Ноль равен пустой
  /// сумме, и запись «начислено ноль» здесь не факт о клиенте, а мусор в
  /// журнале у каждого, кто бонусами не пользовался.
  ///
  /// **Отрицательный остаток записывается [BonusEntryKind.openingDeficit],
  /// а не выравнивается в ноль.** У бонусного счёта минуса быть не должно,
  /// но в базах, прошедших через дефект возврата (задача 10), он есть.
  /// Обнулить его значило бы подарить покупателю чужие деньги молча —
  /// и сделать первую же сверку ложью в другую сторону.
  ///
  /// **`insertOrIgnore` по ключу происхождения.** Установка, поднявшаяся на
  /// v40 и откатившаяся к прежней сборке, придёт сюда второй раз: обычная
  /// вставка удвоила бы стартовые остатки всем. Номер записи берётся
  /// **постоянным** (`originEntryId = 1`... по порядку счетов), а не
  /// «максимум + 1», именно ради этого: повтор обязан попасть в тот же
  /// ключ, а не завести соседний.
  Future<void> _seedBonusOpeningBalances() async {
    // Справочника счетов нет — засевать нечего, и это не повод не
    // подняться. Тот же довод, что у `_safeAddColumn` и
    // `_safeCreateTable`: миграция обязана пережить базу, которая
    // выглядит не так, как ожидалось, — иначе одна кривая установка
    // останавливает обновление всем.
    //
    // Найдено набором, а не рассуждением: десять проб прежних миграций
    // поднимают **пустую** базу с проставленной версией схемы, и первая
    // редакция этой ветки уронила все десять — не своим дефектом, а
    // требованием к чужой фикстуре.
    final hasAccounts = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'accounts'",
    ).getSingleOrNull();
    if (hasAccounts == null) return;

    var posId = 0;
    try {
      posId = (await thisPosDao.get())?.id ?? 0;
    } catch (_) {
      // Кассу не назвали — запись родится с нулевым номером кассы, и это
      // видимое «родилась там, где кассу не назвали». Настоящие номера
      // начинаются с единицы, так что сведение их не перепутает.
    }
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Род счёта спрашивается у [BonusAccountTypes] — миграция это его
    // третий читатель, и своего списка у неё нет намеренно.
    final rows = await customSelect(
      'SELECT id, value FROM accounts '
      'WHERE type IN ${BonusAccountTypes.sqlInList}',
    ).get();

    var seq = 0;
    final entries = <BonusEntriesCompanion>[];
    for (final row in rows) {
      final raw = row.read<double?>('value') ?? 0;
      final balance = Decimal.parse(raw.toString());
      if (balance == Decimal.zero) continue;
      seq++;
      final positive = balance > Decimal.zero;
      entries.add(
        BonusEntriesCompanion.insert(
          accountId: row.read<int>('id'),
          kind: positive
              ? BonusEntryKind.opening
              : BonusEntryKind.openingDeficit,
          amount: positive ? balance : -balance,
          time: now,
          originPosId: posId,
          originEntryId: seq,
          reason: const Value(
            'стартовый остаток при переходе на журнал (v40): истории '
            'движений до этой версии не существовало',
          ),
          // Отправке не подлежит: у соседней кассы свой стартовый остаток,
          // и принять чужой значило бы сложить один остаток дважды.
          state: const Value(null),
        ),
      );
    }
    if (entries.isEmpty) return;

    // # Одним оборотом, а не строкой за оборот — и это замер, а не вкус
    //
    // Первая редакция звала `await into(bonusEntries).insert(...)` внутри
    // цикла. На кассе с пятью тысячами бонусных счетов (карта лояльности у
    // магазина, где такое вообще есть) это пять тысяч отдельных вставок,
    // каждая со своим сбросом журнала на диск.
    //
    // Замер 2026-09-19 (`migration_volume_timing_test`, база за год работы:
    // 30 000 чеков, 105 000 строк, 36 000 оплат): подъём **v39 → v51** шёл
    // **61,4 с**, а подъём **v40 → v51** — **0,97 с**. Разница в шестьдесят
    // секунд целиком приходится на эту ветку; перестройка `Payments` в v41,
    // которую докстринг ветки называл самым долгим шагом за всю историю
    // проекта, стоила **0,4 с** на тех же данных. То есть самое дорогое
    // место миграции было не там, где его искали, и узнать это чтением
    // было нельзя.
    //
    // Пакет меняет только число оборотов. Строки, их порядок, режим
    // `insertOrIgnore` (довод — в ветке `from < 39`) и содержимое те же:
    // правильность по-прежнему сторожит `migration_v40_bonus_journal_test`.
    await batch(
      (b) => b.insertAll(bonusEntries, entries, mode: InsertMode.insertOrIgnore),
    );
  }

  Future<void> _ensureDefaultDiscountLimit() async {
    await into(discountLimits).insert(
      DiscountLimitsCompanion.insert(
        role: const Value(DiscountLimitRoles.anyRole),
        maxPercentPerLine: Value(Decimal.fromInt(100)),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

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
      // Строка умолчания предела скидки — **на обоих путях**, как и уникальный
      // индекс выше. Найдено пробой экрана: `onCreate` миграций не исполняет,
      // и на свежей установке строки не было вовсе. Читатель отдал бы сто
      // процентов и там (`LocalDiscountPolicy`, ветвь «строки нет»), то есть
      // касса работала бы верно, — но экран пределов показывал бы пустое
      // поле, а I165 требует **объявленного значения**, а не пустоты, которую
      // владелец должен угадать.
      await _ensureDefaultDiscountLimit();
      // Девять системных видов оплаты — **на обоих путях**, по тому же
      // доводу, что у строки предела скидки прямо выше. `onCreate`
      // миграций не исполняет: без этой строки свежая установка получила
      // бы пустой справочник, оплата не нашла бы ни одного вида, а
      // `PaymentKindResolver` на каждой строке отвечал бы «не знаю» —
      // притом что набор остался бы зелёным, если бы пробы поднимали
      // только мигрировавшую базу. Ровно это и было измерено пробой
      // `свежая база` до правки: `SELECT COUNT(*) FROM payment_kinds` → 0.
      await _seedSystemPaymentKinds();
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
        // `TerminalDeviceBindings` carried their content instead.
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
        // fix-round-1 on this task). Unlike the
        // `terminals` columns below, this one drops cleanly: it is a lone
        // `BoolColumn` on `ThisPosEntries`, referenced by no other table,
        // view, index or trigger, so `ALTER TABLE ... DROP COLUMN` (sqlite3
        // 3.35.0+, guaranteed by `sqlite3_flutter_libs`) needs no table
        // rebuild.
        await _safeDropColumn(m, thisPosEntries, 'is_rahmet_payment_enabled');

        // Read the seven legacy `terminals` device columns as a **source**
        // before dropping them below — task 2 deliberately left this
        // ordering note here for whoever did the
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
        final grants = <UserPermissionsCompanion>[];
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
            grants.add(
              UserPermissionsCompanion.insert(
                userId: user.id,
                permissionKey: key,
                isAllowed: const Value(true),
              ),
            );
          }
        }
        // Одним оборотом, а не строкой за оборот — та же правка и тот же
        // довод, что у [_seedBonusOpeningBalances]. Замер 2026-09-19
        // (`migration_volume_timing_test`): подъём v32 → v51 шёл **4,6 с**
        // против **1,5 с** у v33 → v51, и все три секунды приходились сюда
        // — десяток кассиров на два десятка ключей это сотни отдельных
        // вставок, каждая со своим сбросом журнала на диск. Строки и их
        // содержимое прежние; сторож правильности —
        // `test/unit/data/permission_migration_test.dart`.
        if (grants.isNotEmpty) {
          await batch((b) => b.insertAll(userPermissions, grants));
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

        // Тело вынесено в [_grantNewPermissionKeys] правкой задачи 24:
        // рассрочка добавляет **второй** ключ в словарь, и второй такой же
        // цикл рядом был бы вторым ответом на вопрос «кому достаётся новый
        // ключ». Правило одно, и разъехаться ему теперь негде.
        await _grantNewPermissionKeys(newKeys);
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

      if (from < 37) {
        // Задача 2 плана «продажа с браузерного терминала». До этой версии
        // рабочее место у кассы было ровно одно, и `saleDao.findInProgress()`
        // брала `state = 0` без всякой привязки к рабочему месту — верно,
        // пока рабочих мест одно. С появлением браузерного терминала это
        // перестаёт быть так, и чеку в работе нужен владелец. Три колонки,
        // а не одна: `terminalId` — сам владелец (I156, см. докстринг
        // колонки в `sale_tables.dart`), `cartVersion` — защита от команды,
        // посчитанной от устаревшего снимка (I161), `lastCommandKey` —
        // защита от повтора последней команды (I160, докстринг колонки
        // объясняет, почему одной строки хватает и таблица-журнал не
        // нужна).
        await _safeAddColumn(m, sales, sales.terminalId);
        await _safeAddColumn(m, sales, sales.cartVersion);
        await _safeAddColumn(m, sales, sales.lastCommandKey);

        // Живому чеку в работе (state = 0) владельцем становится
        // единственный терминал самой кассы (is_self = 1) — до этой версии
        // рабочее место было одно, и это оно. Признак терминала кассы —
        // `terminals.is_self` (`TerminalDao.self()`), но DAO здесь
        // намеренно не вызывается: миграция обязана пережить случай, когда
        // is_self не проставлен ни у одной строки. Такого быть не должно,
        // но подзапрос без единственного результата просто даёт NULL — чек
        // остаётся без владельца, и это не повод падать.
        await customStatement(
          'UPDATE sales SET terminal_id = '
          '(SELECT id FROM terminals WHERE is_self = 1 LIMIT 1) '
          'WHERE state = 0',
        );
      }

      if (from < 38) {
        // Задача 15 того же плана, решение заказчика №5: набор разрешённых
        // видов оплаты — свойство рабочего места. Только `ADD COLUMN`, и
        // **никакого переноса данных нарочно**: набора видов до этой версии
        // не существовало ни у одной строки, и проставить сюда «все четыре»
        // задним числом значило бы записать решение, которого оператор не
        // принимал. Умолчание колонки — пустая строка, и пустое означает
        // «все виды» (`Terminal.allowedPaymentTypes`): существующие
        // терминалы продолжают принимать деньги ровно так же, как вчера, а
        // запрет появляется только там, где его назначили руками.
        await _safeAddColumn(m, terminals, terminals.allowedPaymentTypes);
      }

      if (from < 39) {
        // Задача 12 плана «Полнота продажи»: у ручной скидки появляется
        // объявленный предел (I165).
        //
        // **Умолчание обязано означать «как вчера».** До этой версии
        // единственным потолком скидки была арифметика — «скидка не больше
        // стоимости строки», то есть строка бесплатно была законной
        // операцией. Таблица, появившаяся со строгим умолчанием, остановила
        // бы каждую скидку на каждой кассе в день обновления: миграция сама
        // стала бы отказом, а объяснить кассиру его было бы нечем. Поэтому
        // кладётся **ровно одна** строка `role = -1` со стом процентами.
        //
        // Сто процентов записаны **значением**, а не оставлены отсутствием
        // строки: I165 говорит, что «предела нет» не существует — существует
        // объявленное значение, которое видно на экране пределов и которое
        // владелец может изменить. Пустая таблица заставила бы читателя
        // выдумывать ответ, а выдуманный ответ невозможно ни показать, ни
        // поправить.
        await _safeCreateTable(m, discountLimits);
        // `insertOrIgnore`, а не `insert` и не `insertOnConflictUpdate`.
        // Установка, прошедшая v39 и открытая заново (или откатившаяся к
        // прежней сборке и поднятая снова), придёт сюда второй раз: `insert`
        // упал бы на первичном ключе, а `insertOnConflictUpdate` **стёр бы
        // назначенный владельцем предел**, вернув сто процентов молча. Тот
        // же довод, что у `_safeAddColumn`, только для строки, а не для
        // колонки.
        await _ensureDefaultDiscountLimit();
      }

      if (from < 40) {
        // Задача 13 плана «Полнота продажи»: бонусный остаток перестаёт
        // быть одним перезаписываемым числом и получает журнал.
        //
        // **Стартовые остатки кладутся здесь же, одним оборотом с
        // таблицей.** Инвариант «остаток равен сумме журнала» обязан
        // держаться с первой секунды: пустой журнал при непустом остатке
        // — расхождение у каждого клиента, у кого бонусы есть. Первая же
        // сверка показала бы его, объяснить его было бы нечем, и сторож
        // обесценился бы в тот же день. Обесценившийся сторож отключают.
        //
        // **Историю движений из чеков не восстанавливаем.** Её там нет:
        // до v40 «кто, когда, по какому чеку» не записывалось нигде, и
        // всё, что можно было бы собрать из чеков, было бы догадкой,
        // выглядящей как запись. Честное «до v40 один стартовый остаток»
        // лучше выдуманной истории, потому что его видно.
        await _safeCreateTable(m, bonusEntries);
        await _seedBonusOpeningBalances();

        // Происхождение скидки и аудит попыток — той же версией.
        //
        // **Задним числом не заполняются, и это решение, а не пропуск.**
        // Происхождение скидок проданных чеков вывести не из чего: акций
        // в базе нет вовсе (они чистая функция от строк и `Promotions`,
        // считаемая при сборке снимка), а разность `priceBefore − price`
        // одинакова у подарка и у уступки кассира. Записать все прежние
        // скидки ручными значило бы завести историю, которая выглядит как
        // настоящая и врёт про каждый акционный подарок за всё время
        // работы кассы. Пустая таблица честнее: по ней видно, что до v40
        // происхождения не записывали.
        await _safeCreateTable(m, saleDiscounts);
        await _safeCreateTable(m, discountAuditEntries);
      }

      if (from < 41) {
        // Задача 14 плана «Полнота продажи»: у оплаты появляется вид.
        //
        // **Шаг тяжёлый по форме, но не самый дорогой — и это замер.**
        // `Payments` перестраивается копированием: sqlite не умеет менять
        // уникальные ключи через `ALTER TABLE`, а менять их обязательно —
        // `{receiptNo, posId, payeeAccountId}` запрещал две законные
        // строки на один счёт. На кассе с многолетней историей это
        // переписывание всей таблицы денег.
        //
        // Здесь до 2026-09-19 стояло «самый долгий шаг миграции за всё
        // время проекта», и это было **неверно**. Замер
        // (`migration_volume_timing_test`, 36 000 строк оплаты): ступень
        // v41 → v40 стоит **0,38 с**, а соседняя ступень v40 → v39 стоила
        // **60,4 с** — бонусный журнал, о цене которого не было сказано
        // ничего. Утверждение о цене, полученное чтением кода, держалось
        // месяц и уводило внимание не туда; поэтому здесь теперь число, а
        // не впечатление.
        //
        // Порядок обязателен: справочник **до** перестройки, иначе
        // проставлять `kind_id` будет не на что ссылаться.
        await _safeCreateTable(m, paymentKinds);
        await _seedSystemPaymentKinds();
        await _rebuildPaymentsWithKind(m);
      }

      // ── номера разведены; пустых веток здесь НЕТ, и это ответ ───────
      //
      // Пустые ветки приезжали сюда **дважды**: сначала с QR (задача
      // 22), теперь с сертификатом (задача 21). Оба раза приём был
      // честным, оба раза он разбирается здесь, потому что молча
      // выкинуть чужой намеренный код нельзя.
      //
      // Довод заглушек верен и остаётся в силе: сторож
      // `app_database_test` требует **непрерывной** цепочки `if (from <
      // N)` для всех N от 2 до `schemaVersion`, и требует справедливо —
      // поднятая версия без своей ветки даёт установке прыжок через
      // изменение схемы, которое всплывёт потом отсутствующей колонкой,
      // а не упавшей миграцией. Заглушка нужна там, где номер **занят
      // соседом, которого в дереве нет**.
      //
      // Здесь ни один такой номер не остался:
      //
      // * **v42 — аванс (задача 23), и он УЖЕ влит.** Обе заглушки —
      //   и QR, и сертификата — столкнулись здесь с настоящей веткой.
      //   Столкновение задумано их авторами, и разрешается оно в пользу
      //   настоящей: пустая ветвь поверх непустой стёрла бы правку
      //   справочника, и вид `prepayment` остался бы невключаемым.
      // * **v43 — намерения QR (задача 22), и он УЖЕ влит.** Заглушка
      //   сертификата «содержание приезжает с её ветвью» описывала
      //   ровно эту ветвь — ветвь приехала. Пустая поверх неё лишила бы
      //   таблицы `PaymentIntents` каждую кассу, доезжающую с v41 и
      //   ниже: на свежей базе таблица создаётся объявлением схемы, при
      //   обновлении — только этим шагом, и покраснело бы это не здесь,
      //   а на первой же оплате телефоном у клиента.
      // * **v44 — сертификат (задача 21), и он приезжает сейчас.**
      //   Ветвь ниже **настоящая**: своя таблица плюс одна поправка
      //   справочника. Номер назван координатором и не меняется — 42 и
      //   43 заняты влитыми соседями, цепочка 2…44 остаётся непрерывной
      //   и целиком из настоящих шагов.
      //
      // Проверяется это не чтением: непрерывность цепочки считает
      // `app_database_test`, а `migration_v44_certificates_test`
      // поднимает базу **с 43** и смотрит, что сертификатная таблица
      // появилась, счёт вида проставился, а справочник не потерял ни
      // одного вида — то есть что чужие шаги 42 и 43 проехали живыми.
      if (from < 42) {
        // Задача 23: у «Предоплаты» появляется счёт-получатель.
        //
        // **Таблиц не прибавилось, колонок не прибавилось** — правится
        // одна строка справочника. Шаг всё равно нужен: посев идёт
        // `insertOrIgnore` (и правильно — он не имеет права затирать
        // настройки оператора), значит на кассе, доехавшей до v41
        // вчера, строка вида `prepayment` осталась бы без
        // `payee_account_type`. А без него правило 4 справочника
        // (`kind_account_missing`) **отказывает включить** зачёт, и вид
        // стал бы невключаемым — окно, в которое видно, но через
        // которое ничего не проходит.
        //
        // Правятся только те поля, решения по которым оператор принять
        // не мог: их у вида до сих пор не было вовсе. `is_active`
        // **не трогается** — включение вида это решение оператора, и
        // выключенным он остаётся.
        await customStatement(
          'UPDATE payment_kinds SET payee_account_type = ?, '
          'requires_counterparty = 1 '
          'WHERE id = ? AND payee_account_type IS NULL',
          [AccountType.agentMain, SystemPaymentKindIds.prepayment],
        );
      }

      if (from < 43) {
        // Задача 22 плана «Полнота продажи»: намерения оплаты QR/СБП.
        //
        // `from < 43` срабатывает и на базе, стоящей на 42: таблицы
        // намерений у неё нет так же, как у базы на 41.
        //
        // **Только создание таблицы, ни строчки переноса** — и это не
        // лень, а единственный честный ответ. Намерений до v43 не
        // существовало нигде: ни колонкой, ни записью, ни в `Payments`.
        // Вывести их задним числом не из чего, а выдумать — значит
        // завести историю, которая выглядит настоящей и врёт про каждый
        // чек, оплаченный до этой сборки.
        //
        // Пустая таблица честнее: по ней видно, что до v43 намерения не
        // записывали. Тот же довод, что у `SaleDiscounts` в v40.
        await _safeCreateTable(m, paymentIntents);
      }

      if (from < 44) {
        // Задача 21 плана «Полнота продажи»: подарочный сертификат.
        //
        // **Номер v44, а не v42, и это не описка.** Номер миграции —
        // общий ресурс ветвей одного яруса: v42 забрала задача 23
        // (предоплата), v43 — задача 22 (QR), обе влились раньше. Номер
        // **назван координатором, а не угадан**: две работы уже взяли
        // один и тот же номер независимо, и угадывание третьей стоило бы
        // третьего столкновения.
        //
        // Шаг короткий, и это не случайность: вся тяжесть задачи 14
        // (перестройка `Payments`) уже уплачена, и сертификату досталась
        // готовая строка оплаты с `kind_id` и `reference`. Здесь только
        // своя таблица и **одна поправка справочника**.
        await _safeCreateTable(m, giftCertificates);
        await _seedSystemPaymentKinds();
        await _pointCertificateKindAtLiabilityAccount();
      }

      if (from < 45) {
        // Задача 24 плана «Полнота продажи»: рассрочка с кредитным
        // договором. **Последний вид оплаты, которого не было в дереве ни
        // одним символом** — кроме строки справочника, заведённой задачей
        // 14 выключенной и ждавшей своей работы.
        //
        // Шаг делает три вещи, и ни одна не лишняя:
        //
        // 1. **Две таблицы.** Договор и график. Переноса нет ни строчки —
        //    рассрочек до v45 не существовало нигде: ни колонкой, ни
        //    записью, ни в `Payments`. Вывести их задним числом не из
        //    чего, а выдумать значит завести историю, которая выглядит
        //    настоящей и врёт про каждый чек, проданный в долг. Пустая
        //    таблица честнее — тот же довод, что у `SaleDiscounts` в v40 и
        //    `PaymentIntents` в v43.
        //
        // 2. **Посев справочника.** Ровно по той же причине, что в v44:
        //    `seed` — это `insertOrIgnore`, и касса, доехавшая до v41
        //    вчера, строку вида `installment` уже имеет; строки нет только
        //    у той, что доезжает с ещё более старой. Вид **остаётся
        //    выключенным** — включение это решение оператора.
        //
        // 3. **Новое право `op.creditRepay`** — и это обязательный шаг, а
        //    не вежливость. `user_permissions` с задачи 16 — allow-list:
        //    ключ, добавленный в словарь без миграции, молча становится
        //    отказом для **каждого** существующего не-владельца, и
        //    погашение рассрочки не заработало бы ни у кого, включая
        //    кассира, которому оно полагается по роли. Правило записано в
        //    докстринге `PermissionKeys.allPermissions`; здесь оно
        //    исполняется по образцу ветки `from < 35`.
        await _safeCreateTable(m, creditContracts);
        await _safeCreateTable(m, creditScheduleEntries);
        await _seedSystemPaymentKinds();
        await _grantNewPermissionKeys(const {PermissionKeys.opCreditRepay});
      }

      if (from < 46) {
        // Вход в оплату по QR: настройка провайдера — адрес, имя, ключ и
        // терпение кассы.
        //
        // **Только создание таблицы.** Настройки провайдера до v46 не
        // было нигде — `HttpQrPaymentProvider` не собирал никто, и адрес
        // ему давать было некому. Выдумывать строку по умолчанию нельзя
        // вдвойне: адрес-заглушка отправил бы деньги покупателя в никуда,
        // а касса без строки честно отвечает `qr_not_configured`.
        await _safeCreateTable(m, qrProviderConfigs);
      }

      if (from < 47) {
        // Сертификат и аванс в фискальном документе — решения заказчика
        // 2026-09-14 (план `2026-09-14-sale-remaining.md`, группа A).
        //
        // Три настройки кассы одним шагом — номер закреплён за этой
        // дорожкой координатором. Умолчания стоят в объявлении колонок:
        // продажа сертификата без чека, зачёт скидкой, приём аванса с чеком.
        // Проверка таблицы — ради **частичных баз проб миграций**
        // (`migration_v41_payments_test` и соседи строят базу vN из одних
        // нужных им таблиц). У настоящей кассы обе таблицы есть с v1.
        if (await _tableExists('this_pos_entries')) {
          await _safeAddColumn(
            m,
            thisPosEntries,
            thisPosEntries.fiscalizeCertificateSale,
          );
          await _safeAddColumn(
            m,
            thisPosEntries,
            thisPosEntries.offsetFiscalLayout,
          );
          await _safeAddColumn(
            m,
            thisPosEntries,
            thisPosEntries.fiscalizePrepaymentReceipt,
          );
        }

        // Чем принят аванс — до v47 не хранилось нигде. Старым строкам
        // ничего не проставляется: выдумать «наличные» значило бы записать
        // историю, которой не было.
        if (await _tableExists('cash_operations')) {
          await _safeAddColumn(m, cashOperations, cashOperations.kindId);
        }

        // Системные «Сертификат» и «Предоплата» теряли трактовку `cash`,
        // посеянную v41: гашение и зачёт — не фискальная оплата. Правится
        // **только посевное значение** — трактовку, выбранную оператором,
        // шаг не трогает (сторож `FiscalOffsetSettings.effectiveTreatment`
        // закрывает опасные сочетания и без этого).
        await customStatement(
          'UPDATE payment_kinds SET fiscal_treatment = ? '
          "WHERE id IN (?, ?) AND fiscal_treatment = 'cash'",
          [
            FiscalTreatment.offsetNotFiscal.code,
            SystemPaymentKindIds.certificate,
            SystemPaymentKindIds.prepayment,
          ],
        );
      }

      if (from < 48) {
        // Журнал связи «возврат → сертификат» — решения заказчика
        // 2026-09-16. Номер v48 закреплён за этой дорожкой координатором
        // (v49–v52 свободны).
        //
        // **Только создание таблицы, и переноса нет ни строчки.** До v48
        // возврат товара, оплаченного сертификатом, возвращал деньги на ту
        // же бумажку (`CertificateDao.restore`), то есть никакой второй
        // бумажки не заводилось и связывать было нечего. Вывести журнал
        // задним числом не из чего: у прежних возвратов нового сертификата
        // не было вовсе, а выдумать связь значит записать историю, которая
        // выглядит настоящей и врёт про каждый возврат.
        //
        // Пустая таблица честнее — тот же довод, что у `SaleDiscounts` в
        // v40, `PaymentIntents` в v43 и `CreditContracts` в v45.
        await _safeCreateTable(m, certificateRefundLinks);
      }

      if (from < 49) {
        // Память кассы о принятых авансах — дефект живой приёмки 2026-09-18.
        // Номер следующий за v48; v50–v52 остаются свободными.
        //
        // **Только создание таблицы, переноса нет ни строчки — и это
        // названное ограничение, а не забывчивость.** У приёмов, записанных
        // до v49, ключа заявки не было вовсе: `PrepaymentIntakeRequest` его
        // не нёс, и по проводу он не ехал. Выдумать ключ задним числом
        // нельзя — не из чего: ключ это метка вкладки, а не свойство
        // проводки, и любое вычисленное здесь число совпало бы с настоящим
        // только случайно. Хуже того, выдуманный ключ **выглядел бы
        // настоящим** и молча съел бы первый же законный повторный взнос той
        // же суммы.
        //
        // Цена честности названа: заявка, начатая до подъёма и повторённая
        // после, защиты не получит. Она живёт секунды и кончается вместе с
        // перезапуском кассы, тогда как выдуманная память врала бы годами.
        //
        // Пустая таблица честнее — тот же довод, что у `CertificateRefundLinks`
        // в v48, `CreditContracts` в v45 и `PaymentIntents` в v43.
        await _safeCreateTable(m, prepaymentIntakes);
      }

      if (from < 50) {
        // Род фискального документа — замер 2026-09-19. Номер следующий
        // за v49; v51–v52 остаются свободными.
        //
        // # Что здесь чинится
        //
        // Первичным ключом `webkassa_receipts` был один `operation_id`, а
        // класть в него ходили три разные последовательности. Замер
        // показал столкновение на паре «продажа №5 и возврат №5»:
        // `UNIQUE constraint failed`, и `_persistReceipt` глотает падение
        // строкой журнала. Разбор целиком — в докстринге `FiscalDocKind`.
        //
        // # Перенос ЕСТЬ, и он выводится, а не выдумывается
        //
        // В отличие от v45–v49, здесь переносить есть что и есть из чего:
        // род старой строки однозначно читается по `is_sale`. До v50 в
        // таблицу писали ровно два рода — продажу (`is_sale = 1`) и
        // возврат товара (`is_sale = 0`); аванс не писался вовсе (это и
        // есть вторая половина той же находки). Поэтому `1` возвратам и
        // умолчание `0` всем прочим — не догадка, а полный разбор случаев.
        //
        // **Чего перенос НЕ делает:** он не возвращает строки, потерянные
        // столкновением до v50. Документ у оператора есть, локальной
        // записи не осталось, и восстановить её не из чего — выдуманная
        // строка выглядела бы настоящей.
        if (!await _tableExists('webkassa_receipts')) {
          // Таблицы документов нет вовсе — перестраивать нечего. Такое
          // бывает у урезанных фикстур миграции (v36…v38): они несут
          // только то, что мерят. Создаём сразу в новом виде и уходим —
          // тот же приём, что у `_rebuildPaymentsWithKind`.
          await _safeCreateTable(m, webkassaReceipts);
        } else {
          await _safeAddColumn(m, webkassaReceipts, webkassaReceipts.docKind);
          await customStatement(
            'UPDATE webkassa_receipts SET doc_kind = 1 WHERE is_sale = 0',
          );
          // Ключ расширяется **пересборкой таблицы**: `ALTER TABLE` в
          // sqlite первичного ключа не меняет, и без этой строки колонка
          // появилась бы, а столкновение осталось.
          await m.alterTable(TableMigration(webkassaReceipts));
        }
      }

      if (from < 51) {
        // Возврат по намерению QR — ревизия 2026-09-19, дыра 3. Номер
        // следующий за v50; v52 остаётся свободным.
        //
        // # Что здесь чинится
        //
        // `paymentIntentDao` не упоминался в `RefundUseCaseImpl` **вовсе**:
        // возврат просил провайдера вернуть деньги и уходил, не сказав об
        // этом строке намерения ни слова. Намерение, по которому деньги уже
        // у покупателя, оставалось `paid` навсегда, а член
        // `QrIntentStatus.reversed` не писал никто — замер `git grep`
        // нашёл его только в объявлении, в `switch` показа и в пробе
        // эмулятора.
        //
        // # Переноса нет, и это названное ограничение
        //
        // Сколько вернули по намерениям **до** v51, вывести не из чего.
        // Строка сторно в `Payments` несёт `terminal_transaction_id`
        // возврата — ид, который провайдер вернул **на возврат**, — и с
        // `provider_intent_id` намерения он совпадает только у нынешнего
        // адаптера и только случайно; у прежних возвратов его не
        // записывали вовсе. Выдуманное число здесь было бы неотличимо от
        // настоящего и врало бы про каждый разбор.
        //
        // Цена честности: у возвратов до v51 столбец пуст, и такое
        // намерение по-прежнему читается оплаченным. Пустая колонка видна;
        // выдуманная сумма — нет.
        await _safeAddColumn(m, paymentIntents, paymentIntents.reversedAmount);
        await _safeAddColumn(m, paymentIntents, paymentIntents.reversedAt);
      }

      if (from < 52) {
        // Долг по Z-отчёту — ревизия 2026-09-19, беда 2. Номер следующий
        // за v51.
        //
        // # Что здесь чинится
        //
        // Закрытие смены с 2026-09-19 не отправляет Z, пока документы
        // смены не у оператора, — и правильно делает. Но задержанный Z
        // **никто не досылал**: хранилища «Z должен» не было вовсе, и
        // отчёт посылало только следующее закрытие смены. Смена
        // оператора, простоявшая открытой дольше суток, отвечает кодом 12
        // на первой продаже следующего дня — то есть касса утром не
        // продаёт.
        //
        // Разбор решения — в докстринге `FiscalOwedReports` и
        // `ShiftServiceImpl.settleOwedZReport`.
        //
        // # Переноса нет, и это не пустая графа
        //
        // Долгов, накопленных **до** v52, вывести не из чего: задержка Z
        // нигде не записывалась. Прочитать её задним числом можно было бы
        // разве что по журналу приложения, а журнал живёт до перезапуска
        // и ротации. Выдуманный долг заставил бы кассу послать Z за
        // смену, которая давно закрыта чужим отчётом, — то есть завёл бы
        // ровно ту беду, от которой таблица заводится.
        //
        // **Чего перенос НЕ делает:** он не закрывает смены оператора,
        // оставшиеся открытыми до подъёма. Первая после подъёма закроется
        // обычным закрытием смены кассы.
        await _safeCreateTable(m, fiscalOwedReports);
      }

      // Выдача аванса по проводу приехала ОДНОВРЕМЕННО с долгом по
      // Z-отчёту — двумя параллельными дорожками, и обе объявили себя v52.
      // Разведено при сведении: долг остался 52, память о выданных авансах
      // стала 53. Порядок между ними не значим (таблицы независимы), но
      // номер обязан быть один на шаг: касса, поднявшаяся по одной ветке,
      // иначе считала бы себя обновлённой и второй таблицы не завела бы.
      if (from < 53) {
        // Память кассы о **выданных** авансах — выдача аванса по проводу,
        // решение заказчика 2026-09-18 «в браузере должно работать то же,
        // что в приложении». Номер следующий за v51; свободных за ним
        // координатор не резервировал.
        //
        // # Почему таблица, а не колонка рода в `prepayment_intakes`
        //
        // Разбор целиком — в докстринге `PrepaymentRefunds`; коротко: одна
        // таблица означала бы одно пространство ключей на приём и на
        // выдачу, и кадр приёма с ключом, занятым выдачей, получил бы в
        // ответ исход выдачи — «принято» без единой записанной копейки.
        //
        // # Переноса нет ни строчки, и это названное ограничение
        //
        // До v52 выдача аванса жила **только** кассовым экраном
        // (`/prepayment-refund`), и ключа заявки у неё не было вовсе:
        // `refundPrepayment` его не принимал. Выдумать ключ задним числом
        // не из чего — он метка вкладки, а не свойство проводки, — и
        // выдуманный молча съел бы первую же законную вторую выдачу той же
        // суммы.
        //
        // Цена честности та же, что у v49: заявка, начатая до подъёма и
        // повторённая после, защиты не получит. Она живёт секунды;
        // выдуманная память врала бы годами.
        await _safeCreateTable(m, prepaymentRefunds);
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
