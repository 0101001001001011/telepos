import 'package:drift/drift.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';

class ThisPosEntries extends Table {
  BoolColumn get rId => boolean().withDefault(const Constant(true))();

  IntColumn get id => integer().nullable()();

  TextColumn get companyName => text().nullable()();

  IntColumn get storeId => integer().nullable()();

  TextColumn get key => text().nullable()();

  TextColumn get token => text().nullable()();

  TextColumn get iinbin => text().nullable()();

  TextColumn get cashBoxName => text().nullable()();

  IntColumn get accountId => integer().nullable()();

  TextColumn get version => text().nullable()();

  TextColumn get rsaPublicKey => text().nullable()();

  IntColumn get acquiringAccountId => integer().nullable()();

  TextColumn get lastCreatedAgent => text().nullable()();

  IntColumn get ofdSyncType => integer().nullable()();

  // ── сертификат и аванс в фискальном документе (v47) ──────────────────
  // Решения заказчика 2026-09-14; разбор — `FiscalOffsetSettings`.

  /// Фискальный чек продажи сертификата. По умолчанию выкл.
  BoolColumn get fiscalizeCertificateSale =>
      boolean().withDefault(const Constant(false))();

  /// Раскладка зачёта: индекс `OffsetFiscalLayout`, 0 — скидкой.
  IntColumn get offsetFiscalLayout =>
      integer().withDefault(const Constant(0))();

  /// Фискальный чек приёма аванса. По умолчанию вкл.
  BoolColumn get fiscalizePrepaymentReceipt =>
      boolean().withDefault(const Constant(true))();

  IntColumn get cashbackRate => integer().nullable()();

  IntColumn get discountsRoundType =>
      integer().withDefault(const Constant(0))();

  IntColumn get weightProductRoundType =>
      integer().withDefault(const Constant(0))();

  RealColumn get cashWithdrawalAmountLimit =>
      real().nullable().map(const DecimalConverter())();

  BoolColumn get limitToKztStores =>
      boolean().withDefault(const Constant(false))();

  TextColumn get printerHeader => text().nullable()();

  TextColumn get printerFooter => text().nullable()();

  IntColumn get printerLanguage => integer().nullable()();

  IntColumn get paperWidth => integer().nullable()();

  BoolColumn get printerTableView =>
      boolean().withDefault(const Constant(false))();

  // rejectFromTime/rejectToTime dropped (schema v30, план 2в, задача 3).
  // Окно, в которое печать запрещена. Ни одного инварианта за ним не стоит,
  // ни строки документации, ни одного экрана: и писателя, и читателя у пары
  // не было. Единственный код, который вообще умел её толковать, —
  // `PrinterSystemConfig.isPrintingAllowed` в
  // `lib/hardware/printer/printer_config.dart`, а тот файл осиротел вместе с
  // удалённым задачей 1 планировщиком печати и удалён в этой же ветке
  // отдельным коммитом.
  //
  // Правило хранить было бы нечего, даже если бы кто-то его читал: очередь
  // печати (`lib/data/print/print_queue_local.dart`) знает ровно два повода не
  // печатать чек — вышел срок задания и оператор его отменил (И29). «Сейчас
  // не время печатать» третьим поводом не является: деньги уже приняты, чек
  // уже существует, и отказ печатать его по часам означал бы фискальный
  // документ, которого не выдали по расписанию. См. `if (from < 30)` в
  // app_database.dart.

  BoolColumn get printVatOnReceipt =>
      boolean().withDefault(const Constant(false))();

  // printerConnectionType/printerAddress/printerPort dropped (schema v27,
  // final review finding I1): their only writer used
  // `printerConnectionType.index - 1`, a second, incompatible int encoding
  // of `PrinterConnectionType` layered onto a column the pre-branch
  // `printer_settings_screen.dart` already wrote with its own different
  // encoding — "unusable" by construction, and with no reader either way.
  // See app_database.dart's `if (from < 27)` migration block for the column
  // drop and the reasoning for why no raw-SQL historical read precedes it.

  // labelPrinterConnectionType/labelPrinterAddress/labelPrinterPort/
  // labelPrinterLanguage/labelWidthMm/labelHeightMm dropped (schema v27,
  // second final-review round, finding raised alongside C4): C4 pointed
  // `print_price_tag_dialog.dart` at the label-printer `DeviceBinding`
  // instead of these columns, which left their only writer
  // (`ThisPosDao.updateLabelPrinter`) and only reader both dead in the same
  // direction — new dead code of exactly the kind I1 objected to. Dropped
  // rather than left as an orphaned pair; see app_database.dart's
  // `if (from < 27)` block.

  BoolColumn get isVatPayer => boolean().withDefault(const Constant(true))();

  BoolColumn get blockOversell =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get editProduct => boolean().withDefault(const Constant(false))();

  BoolColumn get editPrice => boolean().withDefault(const Constant(false))();

  BoolColumn get sellUniversal =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get minimizeCashbox =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get sellInDebt => boolean().withDefault(const Constant(false))();

  BoolColumn get sellInDiscount =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get cashInOut => boolean().withDefault(const Constant(false))();

  BoolColumn get sendToOfd => boolean().withDefault(const Constant(false))();

  BoolColumn get cancelPayment =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get deferSale => boolean().withDefault(const Constant(false))();

  BoolColumn get admitElectPayment =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get isSyncImmediately =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get isShowSaleHistory =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get isNewReportCheck =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get isKassaWholesaleEnabled =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get isSearchInGlobalProductsEnabled =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get priceCheckEnabled =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get allowBigAmount =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get isKassaPriceDecreasingBlocked =>
      boolean().withDefault(const Constant(false))();

  IntColumn get usersAllowedToRefund => integer().nullable()();

  IntColumn get usersAllowedToRefundWithoutReceipt => integer().nullable()();

  IntColumn get usersAllowedToCancelProduct => integer().nullable()();

  IntColumn get usersAllowedToDecreaseProductCount => integer().nullable()();

  TextColumn get markUpFromDate => text().nullable()();

  TextColumn get markUpToDate => text().nullable()();

  IntColumn get currencyId => integer().nullable()();

  IntColumn get countryCode => integer().nullable()();

  IntColumn get currencyCode => integer().nullable()();

  TextColumn get currencyNameLong => text().nullable()();

  TextColumn get currencyNameShort => text().nullable()();

  TextColumn get currencySymbol => text().nullable()();

  TextColumn get webkassaToken => text().nullable()();

  TextColumn get webkassaHost => text().nullable()();

  IntColumn get operatingMode => integer().withDefault(const Constant(0))();

  RealColumn get defaultServiceChargePercent =>
      real().nullable().map(const DecimalConverter())();

  BoolColumn get serviceChargeEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Минимальная и максимальная длина принимаемого штрихкода. Схема v27.
  ///
  /// Не свойство сканера — сканер читает любой код одинаково, эти границы
  /// решают, какое прочитанное значение принять. Это бизнес-правило
  /// установки (docs/system-architecture.md, И142), поэтому оно живёт здесь,
  /// рядом с остальными флагами `BusinessRulesConfigInfo`
  /// (`lib/domain/setup/setup_draft.dart`), а не на `DeviceBinding`/
  /// `DeviceProfile`. Перенесены миграцией v27 из блоба `hardware_settings`
  /// (`barcodeMinLength`/`barcodeMaxLength`) —
  /// `lib/data/database/migrations/device_binding_migration.dart`. Готового
  /// столбца под них не было ни здесь, ни где-либо ещё — оба добавлены этой
  /// схемой.
  IntColumn get barcodeMinLength => integer().nullable()();

  IntColumn get barcodeMaxLength => integer().nullable()();

  /// Максимальный промежуток между символами клавиатурного сканера
  /// (keyboard-wedge), после которого накопленный буфер считается
  /// завершённым штрихкодом. Схема v28.
  ///
  /// Не свойство сканера (И141): любая HID-модель шлёт символы с этим же
  /// промежутком независимо от производителя, и промежуток не входит в
  /// адресацию устройства — он решает, когда считать разбор буфера
  /// оконченным, то есть какое прочитанное значение принять. Это то же
  /// бизнес-правило, что и `barcodeMinLength`/`barcodeMaxLength` (И142),
  /// поэтому живёт здесь же, а не на `DeviceBinding`/`DeviceProfile`.
  ///
  /// Пришло из блоба `hardware_settings` (`scannerTimeout`), который
  /// миграция v27 намеренно проигнорировала — готового дома для него не
  /// было ни в одном из трёх мест (`lib/data/database/migrations/
  /// device_binding_migration.dart`'s blob-key inventory). Задача 5(c)
  /// плана 2b (device-discovery-and-tests) — то самое решение, куда он
  /// относится, и это добавление столбца.
  IntColumn get scannerTimeoutMs => integer().nullable()();

  /// Разрешён ли вход по одному PIN, без выбора имени.
  ///
  /// Решение владельца точки, и по умолчанию **нет**: walk-up означает, что
  /// PIN один опознаёт человека, а четыре цифры на десяток кассиров рано или
  /// поздно совпадут.
  BoolColumn get walkUpEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Сколько минут сеанс кассира живёт без действий.
  IntColumn get sessionIdleMinutes =>
      integer().withDefault(const Constant(30))();

  @override
  Set<Column> get primaryKey => {rId};
}
