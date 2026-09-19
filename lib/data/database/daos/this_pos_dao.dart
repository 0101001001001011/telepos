import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/this_pos_tables.dart';
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';

part 'this_pos_dao.g.dart';

@DriftAccessor(tables: [ThisPosEntries])
class ThisPosDao extends DatabaseAccessor<AppDatabase> with _$ThisPosDaoMixin {
  ThisPosDao(super.db);

  Future<ThisPosEntry?> get() => (select(
    thisPosEntries,
  )..where((tp) => tp.rId.equals(true))).getSingleOrNull();

  /// Номер этой кассы — или [TillNotConfigured], если его нет.
  ///
  /// **Единая политика номера кассы, заведена кругом правки 4 задачи 7.**
  /// До неё четыре файла читали его четырьмя способами: бросок
  /// `StateError`, два умолчания `?? 0` и ранний выход с записью в
  /// журнал. Умолчание в ноль — худшее из четырёх и притом самое тихое:
  /// ноль это **настоящий** номер кассы (в тестах — сплошь и рядом), и
  /// запрос с ним не падает, а находит чужие строки. Ровно та же ошибка
  /// формы, что дала дефект круга 3 (`findInProgress` без предиката
  /// кассы), только через подстановку вместо пропуска.
  ///
  /// Политика: **ноль не подставляется нигде**. Ненастроенная касса это
  /// бросок отсюда — кроме одного места, где контракт требует отказ
  /// **значением** (`SaleInitiationUseCaseImpl` — `till_not_configured`,
  /// задача 5); там номер проверяется явно, и ноль не подставляется тоже.
  Future<int> requireId() async {
    final id = (await get())?.id;
    if (id == null) throw const TillNotConfigured();
    return id;
  }

  Future<bool> exists() async {
    final entry = await get();
    return entry != null && entry.companyName != null;
  }

  // updatePrinterConnection removed (schema v27, final review finding I1):
  // its one remaining call site (LocalSetupRepository.completeSetup) wrote
  // an unusable, second int encoding into a column that is now dropped. See
  // this_pos_tables.dart and app_database.dart's `if (from < 27)` block.

  // updateLabelPrinter removed (schema v27, second final-review round,
  // finding raised alongside C4): already had zero call sites before this
  // round — print_price_tag_dialog.dart was its only ever caller, and C4
  // repointed it at the label-printer DeviceBinding instead. Its six
  // ThisPosEntries columns are dropped in the same migration step. See
  // this_pos_tables.dart and app_database.dart's `if (from < 27)` block.

  Future<int> setBlockOversell(bool value) =>
      (update(thisPosEntries)..where((tp) => tp.rId.equals(true))).write(
        ThisPosEntriesCompanion(blockOversell: Value(value)),
      );

  Future<int> updateBusinessFlags({
    bool? editProduct,
    bool? editPrice,
    bool? sellInDiscount,
    bool? cashInOut,
    bool? allowBigAmount,
    bool? isKassaPriceDecreasingBlocked,
  }) => (update(thisPosEntries)..where((tp) => tp.rId.equals(true))).write(
    ThisPosEntriesCompanion(
      editProduct: editProduct == null
          ? const Value.absent()
          : Value(editProduct),
      editPrice: editPrice == null ? const Value.absent() : Value(editPrice),
      sellInDiscount: sellInDiscount == null
          ? const Value.absent()
          : Value(sellInDiscount),
      cashInOut: cashInOut == null ? const Value.absent() : Value(cashInOut),
      allowBigAmount: allowBigAmount == null
          ? const Value.absent()
          : Value(allowBigAmount),
      isKassaPriceDecreasingBlocked: isKassaPriceDecreasingBlocked == null
          ? const Value.absent()
          : Value(isKassaPriceDecreasingBlocked),
    ),
  );

  Future<void> upsert(ThisPosEntriesCompanion entry) async {
    final existing = await get();
    if (existing == null) {
      await into(thisPosEntries).insert(entry.copyWith(rId: const Value(true)));
    } else {
      await (update(
        thisPosEntries,
      )..where((tp) => tp.rId.equals(true))).write(entry);
    }
  }

  Future<int> updateCurrency({
    required int currencyCode,
    required String currencySymbol,
    required String currencyNameShort,
    required String currencyNameLong,
  }) => (update(thisPosEntries)..where((tp) => tp.rId.equals(true))).write(
    ThisPosEntriesCompanion(
      currencyCode: Value(currencyCode),
      currencySymbol: Value(currencySymbol),
      currencyNameShort: Value(currencyNameShort),
      currencyNameLong: Value(currencyNameLong),
    ),
  );

  Future<void> insertInitialConfig({
    int posId = 1,
    required String companyName,
    required String? iinbin,
    required String cashBoxName,
    required int? countryCode,
    required int? currencyCode,
    required String? currencySymbol,
    required String? currencyNameShort,
    required int? paperWidth,
    required String? printerHeader,
    required String? printerFooter,
    required int? accountId,
    required int? acquiringAccountId,
    required String? rsaPublicKey,
    bool isVatPayer = true,
    bool editProduct = false,
    bool editPrice = false,
    bool sellUniversal = false,
    bool minimizeCashbox = false,
    bool sellInDebt = false,
    bool sellInDiscount = true,
    bool cashInOut = true,
    bool sendToOfd = false,
    bool cancelPayment = false,
    bool deferSale = true,
    bool admitElectPayment = true,
    bool isSyncImmediately = false,
    bool isShowSaleHistory = true,
    bool isNewReportCheck = false,
    bool isKassaWholesaleEnabled = false,
    bool isSearchInGlobalProductsEnabled = false,
    bool priceCheckEnabled = false,
    bool allowBigAmount = false,
    bool isKassaPriceDecreasingBlocked = false,
    int discountsRoundType = 0,
    int weightProductRoundType = 0,
    int? cashbackRate,
  }) async {
    await upsert(
      ThisPosEntriesCompanion(
        id: Value(posId),
        companyName: Value(companyName),
        iinbin: Value(iinbin),
        cashBoxName: Value(cashBoxName),
        countryCode: Value(countryCode),
        currencyCode: Value(currencyCode),
        currencySymbol: Value(currencySymbol),
        currencyNameShort: Value(currencyNameShort),
        paperWidth: Value(paperWidth),
        printerHeader: Value(printerHeader),
        printerFooter: Value(printerFooter),
        accountId: Value(accountId),
        acquiringAccountId: Value(acquiringAccountId),
        rsaPublicKey: Value(rsaPublicKey),
        isVatPayer: Value(isVatPayer),
        editProduct: Value(editProduct),
        editPrice: Value(editPrice),
        sellUniversal: Value(sellUniversal),
        minimizeCashbox: Value(minimizeCashbox),
        sellInDebt: Value(sellInDebt),
        sellInDiscount: Value(sellInDiscount),
        cashInOut: Value(cashInOut),
        sendToOfd: Value(sendToOfd),
        cancelPayment: Value(cancelPayment),
        deferSale: Value(deferSale),
        admitElectPayment: Value(admitElectPayment),
        isSyncImmediately: Value(isSyncImmediately),
        isShowSaleHistory: Value(isShowSaleHistory),
        isNewReportCheck: Value(isNewReportCheck),
        isKassaWholesaleEnabled: Value(isKassaWholesaleEnabled),
        isSearchInGlobalProductsEnabled: Value(isSearchInGlobalProductsEnabled),
        priceCheckEnabled: Value(priceCheckEnabled),
        allowBigAmount: Value(allowBigAmount),
        isKassaPriceDecreasingBlocked: Value(isKassaPriceDecreasingBlocked),
        discountsRoundType: Value(discountsRoundType),
        weightProductRoundType: Value(weightProductRoundType),
        cashbackRate: Value(cashbackRate),
      ),
    );
  }

  /// The three И142 barcode rules, written together — see
  /// `lib/domain/repositories/scanner_rules_repository.dart` for why they are
  /// one value and not three independent setters, and why they live on this
  /// table rather than on a `DeviceBinding`.
  ///
  /// Every parameter is required *and* nullable: `null` means "unset, fall
  /// back to the decoder's default", which is a value this column really can
  /// hold, so it must be writable — a `Value.absent()`-style optional
  /// parameter would make "leave unchanged" and "clear" indistinguishable.
  Future<int> updateScannerRules({
    required int? barcodeMinLength,
    required int? barcodeMaxLength,
    required int? scannerTimeoutMs,
  }) => (update(thisPosEntries)..where((tp) => tp.rId.equals(true))).write(
    ThisPosEntriesCompanion(
      barcodeMinLength: Value(barcodeMinLength),
      barcodeMaxLength: Value(barcodeMaxLength),
      scannerTimeoutMs: Value(scannerTimeoutMs),
    ),
  );

  Future<int> updateOperatingMode(int mode) =>
      (update(thisPosEntries)..where((tp) => tp.rId.equals(true))).write(
        ThisPosEntriesCompanion(operatingMode: Value(mode)),
      );

  /// Настройки входа этой точки.
  ///
  /// Отсутствие строки `ThisPos` — это установка, которая ещё не проходила
  /// мастер. Возвращаются умолчания, а не отказ: экран входа на такой кассе
  /// всё равно не откроется, а падать здесь значило бы уронить подъём.
  Future<({bool walkUpEnabled, int sessionIdleMinutes})> authSettings() async {
    final entry = await get();
    return (
      walkUpEnabled: entry?.walkUpEnabled ?? false,
      sessionIdleMinutes: entry?.sessionIdleMinutes ?? 30,
    );
  }

  /// Сертификат и аванс в фискальном документе (v47).
  ///
  /// Нет строки `ThisPos` — умолчания поставки, а не отказ: касса без
  /// мастера всё равно не продаёт.
  Future<FiscalOffsetSettings> offsetFiscalSettings() async {
    final entry = await get();
    if (entry == null) return FiscalOffsetSettings.defaults;
    return FiscalOffsetSettings(
      fiscalizeCertificateSale: entry.fiscalizeCertificateSale,
      offsetLayout: OffsetFiscalLayout.byIndex(entry.offsetFiscalLayout),
      fiscalizePrepaymentReceipt: entry.fiscalizePrepaymentReceipt,
    );
  }

  Future<int> saveOffsetFiscalSettings(FiscalOffsetSettings s) =>
      (update(thisPosEntries)..where((tp) => tp.rId.equals(true))).write(
        ThisPosEntriesCompanion(
          fiscalizeCertificateSale: Value(s.fiscalizeCertificateSale),
          offsetFiscalLayout: Value(s.offsetLayout.index),
          fiscalizePrepaymentReceipt: Value(s.fiscalizePrepaymentReceipt),
        ),
      );

  Future<void> saveAuthSettings({
    bool? walkUpEnabled,
    int? sessionIdleMinutes,
  }) => (update(thisPosEntries)..where((tp) => tp.rId.equals(true))).write(
    ThisPosEntriesCompanion(
      walkUpEnabled: walkUpEnabled == null
          ? const Value.absent()
          : Value(walkUpEnabled),
      sessionIdleMinutes: sessionIdleMinutes == null
          ? const Value.absent()
          : Value(sessionIdleMinutes),
    ),
  );
}

/// У кассы нет своего номера: она не настроена (или настройка потеряна).
///
/// Не [WireRefusal]: это не отказ человеку в его действии, а поломка
/// установки, при которой не работает ничего связанного с чеками. Там,
/// где такой отказ обязан прийти значением, он формулируется отдельно
/// (см. докстринг [ThisPosDao.requireId]).
final class TillNotConfigured implements Exception {
  const TillNotConfigured();

  @override
  String toString() =>
      'TillNotConfigured: у кассы нет своего номера (this_pos_entries.id) — '
      'касса не настроена';
}
