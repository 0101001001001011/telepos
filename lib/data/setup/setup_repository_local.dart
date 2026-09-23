import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:get_it/get_it.dart';

import 'package:telepos/app/config/local_properties.dart';
import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/core/constants/enums/operating_mode.dart';
import 'package:telepos/core/constants/enums/user_role.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/logging/setup_logger.dart';
import 'package:telepos/core/security/pin_credential.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/migrations/device_binding_migration.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/fiscal/fiscal_settings_store.dart';
import 'package:telepos/data/services/global_product_import_service.dart';
import 'package:telepos/data/sync/couchdb_sync_coordinator.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/data/tax/tax_preset_catalog.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Commits a finished wizard into this machine's database — the binding a
/// desktop till or the appliance uses.
///
/// This code ran inside the wizard's controller until the browser binding
/// needed the same wizard without a database. It is unchanged apart from
/// reading its inputs from a [SetupDraft] instead of the controller's state.
class LocalSetupRepository implements SetupRepository {
  LocalSetupRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> completeSetup(SetupDraft draft) async {
    SetupLogger.info('completeSetup: НАЧАЛО сохранения всех данных...');

    final db = _db;
    final country = CountryCode.values[draft.countryIndex];
    final operatingMode = OperatingMode.values[draft.operatingModeIndex];
    final org = draft.organization;
    final pos = draft.posConfig;
    final fiscal = draft.fiscalConfig;
    final business = draft.businessRules;
    final user = draft.firstUser;

    final companyName = (org.companyName?.trim().isNotEmpty ?? false)
        ? org.companyName!.trim()
        : ((org.legalName?.trim().isNotEmpty ?? false)
              ? org.legalName!.trim()
              : 'Организация');
    final cashBoxName = (pos.cashBoxName?.trim().isNotEmpty ?? false)
        ? pos.cashBoxName!.trim()
        : 'POS';

    SetupLogger.data('saveAllData input', {
      'country': country.name,
      'companyName': org.companyName,
      'taxId': org.taxId,
      'cashBoxName': pos.cashBoxName,
      'isVatPayer': org.isVatPayer,
      'operatingMode': operatingMode.name,

      'fiscalEnabled': fiscal.enabled,
      'fiscalType': fiscal.fiscalType.name,
    });

    // [1/9] использовался под генерацию 2048-битного RSA-ключа. Ключ больше не
    // нужен: PIN хранится как PBKDF2-свёртка с солью на каждого пользователя
    // (`PinCredential`), а не как детерминированный шифротекст под ключом,
    // лежащим в той же базе. Колонка `ThisPos.rsaPublicKey` остаётся, но новая
    // установка её не заполняет — она нужна только тем установкам, где ещё
    // лежат записи прежней схемы, и только чтобы разово их перевести.

    SetupLogger.info('completeSetup [2/9]: Создание POS account...');
    final posAccountId = await db.accountDao.createPosAccount(
      name: cashBoxName,
    );
    SetupLogger.info(
      'completeSetup [2/9]: POS account создан, id=$posAccountId',
    );

    SetupLogger.info('completeSetup [3/9]: Создание TelePOS Main account...');
    // ignore: unused_local_variable
    final _ = await db.accountDao.createTeleposMainAccount(
      name: '$companyName - Main',
    );
    SetupLogger.info('completeSetup [3/9]: TelePOS Main account создан');

    SetupLogger.info('completeSetup [3b/9]: Создание Bank (card) account...');
    // Имя приходит из мастера — он знает язык интерфейса. Здесь было
    // зашито русское «Банк (карта)», и на американской кассе счёт с этим
    // именем показывался в отчётах. Запасное имя английское, а не русское:
    // язык кассы по умолчанию тут неизвестен, и латиница читается везде.
    final bankAccountName =
        (draft.acquiringAccountName?.trim().isNotEmpty ?? false)
        ? draft.acquiringAccountName!.trim()
        : 'Bank (card)';
    final bankAccountId = await db.accountDao.createAcquiringAccount(
      name: bankAccountName,
      acquirerId: 0,
    );
    SetupLogger.info(
      'completeSetup [3b/9]: Bank account создан, id=$bankAccountId',
    );

    SetupLogger.info('completeSetup [4/9]: Сохранение ThisPos config...');
    final currency = country.defaultCurrency;
    await db.thisPosDao.insertInitialConfig(
      companyName: companyName,
      iinbin: org.taxId,
      cashBoxName: cashBoxName,
      countryCode: country.index,
      currencyCode: currency.index,
      currencySymbol: currency.symbol,
      currencyNameShort: currency.code,
      paperWidth: pos.paperWidth,
      printerHeader: pos.printerHeader ?? companyName,
      printerFooter: pos.printerFooter,
      accountId: posAccountId,
      acquiringAccountId: bankAccountId,
      rsaPublicKey: null,
      isVatPayer: org.isVatPayer,
      editProduct: business.allowProductEdit,
      editPrice: business.allowPriceEdit,
      sellUniversal: business.allowUniversalProduct,
      sellInDebt: business.allowDebtSales,
      sellInDiscount: business.allowDiscounts,
      cashInOut: business.allowCashInOut,
      sendToOfd: fiscal.enabled && fiscal.fiscalType != FiscalType.none,
      allowBigAmount: business.allowBigAmount,
      isKassaPriceDecreasingBlocked: business.blockPriceDecrease,
      discountsRoundType: business.discountsRoundType,
      weightProductRoundType: business.weightProductRoundType,
      cashbackRate: business.cashbackEnabled ? business.cashbackRate : null,
    );
    SetupLogger.info('completeSetup [4/9]: ThisPos config сохранён');

    // Finding I1 (final review, 2026-07-30): this used to also write
    // `equip.printerConnectionType.index - 1` into
    // `ThisPosEntries.printerConnectionType`/`.printerAddress`/`.printerPort`
    // — a second, incompatible int encoding of `PrinterConnectionType`
    // layered onto a column the pre-branch `printer_settings_screen.dart`
    // already wrote with its own different encoding, and which nothing
    // read either way. The wizard's printer choice is not lost: `[7b/9]`
    // below (`_createDeviceBindings`) already builds a real
    // `DeviceBinding` from the same `equip` fields, through the shared
    // narrowing logic schema v27's migration uses
    // (`inferLegacyDeviceMigration`) — that is this terminal's one live
    // printer-configuration path now. See `this_pos_tables.dart` and
    // `app_database.dart`'s `if (from < 27)` block for the column drop.

    // Ширина ленты мастера уходит в привязку принтера (`[7b/9]` ниже,
    // `_createDeviceBindings`) — единственное место, откуда её читает печать.
    // Шапка шаблона — только то, что оператор написал в мастере. Название
    // организации сюда больше не подставляется: оно и так печатается жирным
    // строкой продавца, и чек выходил с названием дважды подряд.
    await db.receiptTemplateDao.seedDefaults(
      header: pos.printerHeader,
      footer: pos.printerFooter,
    );
    SetupLogger.info(
      'completeSetup [4c/9]: дефолтный шаблон чека засеян из мастера',
    );

    SetupLogger.info(
      'completeSetup [4b/9]: Обновление operatingMode=${draft.operatingModeIndex}...',
    );
    await db.thisPosDao.updateOperatingMode(draft.operatingModeIndex);
    SetupLogger.info('completeSetup [4b/9]: operatingMode обновлён');

    final employees = draft.employees;
    if (employees.isNotEmpty) {
      SetupLogger.info(
        'completeSetup [5-6/9]: Создание ${employees.length} сотрудник(ов) из списка...',
      );
      for (var i = 0; i < employees.length; i++) {
        final emp = employees[i];
        if (emp.name == null ||
            emp.name!.isEmpty ||
            emp.pin == null ||
            emp.pin!.length < 4) {
          SetupLogger.warning(
            'completeSetup [5-6/9]: пропуск неполного сотрудника #$i',
          );
          continue;
        }
        final encPin = PinCredential.create(emp.pin!);
        if (i == 0) {
          await db.userDao.createOwner(name: emp.name!, passwordEnc: encPin);
          SetupLogger.info('completeSetup [5-6/9]: Owner "${emp.name}" создан');
        } else {
          final nextId = await db.userDao.getNextId();
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          await db.userDao.insertUser(
            UsersCompanion(
              id: Value(nextId),
              name: Value(emp.name!),
              role: Value(emp.roleIndex),
              status: const Value('active'),
              editTime: Value(now),
              passwordEnc: Value(encPin),
            ),
          );
          await _writeRoleDefaultPermissions(
            db,
            nextId,
            UserRole.fromIndex(emp.roleIndex),
          );
          SetupLogger.info(
            'completeSetup [5-6/9]: Сотрудник "${emp.name}" (role=${emp.roleIndex}) создан',
          );
        }
      }
    } else if (user.name != null &&
        user.name!.isNotEmpty &&
        user.pin != null &&
        // Пустой PIN раньше «шифровался» в блок из нулей и записывался как
        // настоящий: экран входа показывал такого пользователя с замком, а
        // ввести пустую строку с клавиатуры нельзя — учётная запись была
        // невходимой. Пустой PIN — это отсутствие PIN, и ниже создаётся
        // владелец без него.
        user.pin!.isNotEmpty) {
      SetupLogger.info(
        'completeSetup [5/9]: Создание owner user "${user.name}"...',
      );
      final encryptedPin = PinCredential.create(user.pin!);

      await db.userDao.createOwner(name: user.name!, passwordEnc: encryptedPin);
      SetupLogger.info('completeSetup [5/9]: Owner user создан');

      final secondUser = draft.secondUser;
      if (secondUser != null &&
          secondUser.name != null &&
          secondUser.name!.isNotEmpty &&
          secondUser.pin != null &&
          secondUser.pin!.isNotEmpty) {
        SetupLogger.info(
          'completeSetup [6/9]: Создание seller user "${secondUser.name}"...',
        );
        final encryptedSellerPin = PinCredential.create(secondUser.pin!);

        final sellerId = await db.userDao.createCashier(
          name: secondUser.name!,
          passwordEnc: encryptedSellerPin,
        );
        await _writeRoleDefaultPermissions(db, sellerId, UserRole.cashier);
        SetupLogger.info('completeSetup [6/9]: Seller user создан');
      } else {
        SetupLogger.info(
          'completeSetup [6/9]: Второй пользователь не задан — пропуск',
        );
      }
    } else {
      final ownerName = (org.contactName?.trim().isNotEmpty ?? false)
          ? org.contactName!.trim()
          : (companyName.isNotEmpty ? companyName : 'Администратор');
      SetupLogger.info(
        'completeSetup [5/9]: owner по умолчанию "$ownerName" (без PIN, backend-вход)',
      );
      await db.userDao.createOwner(name: ownerName, passwordEnc: null);
    }

    // Адрес торговой точки — в саму кассу, а не только в настройки ОФД.
    //
    // Раньше он записывался единственной строкой ниже, внутри ветки
    // WebKassa: касса вне Казахстана адреса не получала вовсе, и на чеке
    // его не было.
    final storeAddress = org.actualAddress ?? org.legalAddress;
    if (storeAddress != null && storeAddress.isNotEmpty) {
      await db
          .update(db.thisPosEntries)
          .write(ThisPosEntriesCompanion(storeAddress: Value(storeAddress)));
    }

    if (fiscal.enabled && fiscal.fiscalType == FiscalType.webkassa) {
      SetupLogger.info('completeSetup [7/9]: Настройка WebKassa...');
      final posConfig = await db.thisPosDao.get();
      final posId = posConfig?.id ?? 1;

      await db.webkassaReceiptDao.createConfig(
        posId: posId,
        posFactoryNo: fiscal.wkPosFactoryNo,
        taxpayerName: org.companyName,
        iinBin: org.taxId,
        address: org.actualAddress ?? org.legalAddress,
        isActive: true,
        isTaxpayer: true,
      );

      try {
        final fiscalStore = FiscalSettingsStore(
          GetIt.instance<LocalProperties>().prefs,
        );
        await fiscalStore.save(
          FiscalSettings(
            operatorType: FiscalOperatorType.webkassa,
            testMode: false,
            baseUrl: FiscalDefaults.cloudBaseUrl(
              FiscalOperatorType.webkassa,
              testMode: false,
            ),
            login: fiscal.wkAccountId,
            apiKey: fiscal.wkAccountToken,
            password: fiscal.wkPosToken,
            cashboxUniqueNumber: fiscal.wkPosFactoryNo,
            registrationNumber: fiscal.wkPosId,
            isVatPayer: org.isVatPayer,
          ),
        );
        SetupLogger.info(
          'completeSetup [7/9]: FiscalSettings (WebKassa) записаны в prefs',
        );
      } catch (e) {
        SetupLogger.warning(
          'completeSetup [7/9]: не удалось записать FiscalSettings',
          e,
        );
      }
      SetupLogger.info(
        'completeSetup [7/9]: WebKassa настроена для posId=$posId',
      );
    } else {
      SetupLogger.info(
        'completeSetup [7/9]: WebKassa/OFD не включена — пропуск',
      );
    }

    SetupLogger.info(
      'completeSetup [7b/9]: Создание устройств терминала из мастера...',
    );
    await _createDeviceBindings(draft, cashBoxName);
    SetupLogger.info('completeSetup [7b/9]: Устройства терминала созданы');

    SetupLogger.info('completeSetup [8/9]: Импорт глобального каталога...');
    await _importGlobalProducts();
    SetupLogger.info('completeSetup [8/9]: Импорт каталога завершён');

    SetupLogger.info(
      'completeSetup [9/9]: Запуск initial sync (fire-and-forget)...',
    );
    _triggerInitialSync();

    await _seedTaxFromPreset(country);

    SetupLogger.info('completeSetup: ВСЕ ШАГИ ЗАВЕРШЕНЫ УСПЕШНО');
  }

  /// Завести налоговую настройку из набора страны.
  ///
  /// # Зачем это здесь
  ///
  /// Наборы существовали и применялись ТОЛЬКО с экрана налогов. Касса,
  /// прошедшая мастер, оставалась без налоговой настройки вовсе, и ставка
  /// бралась умолчанием, зашитым в код: казахстанские 16 % в Германии, где
  /// 19, и в Польше, где 23.
  ///
  /// Заказчик 2026-09-22: «вдруг завтра поменяют и сделают 18 %, и всё,
  /// работа кассы встанет тогда в России». Набор — отправная точка, а не
  /// власть: дальше касса живёт своей настройкой, и обновление продукта её
  /// не трогает (README наборов, правило 1).
  ///
  /// # Почему в слое данных, а не в мастере
  ///
  /// Первая редакция звала это из контроллера мастера — и потянула в
  /// презентацию каталог наборов и базу. Сторожа поймали сразу в двух
  /// местах: `layering_test` нарушением И5, `browser_routes_test` тем, что
  /// браузерная сборка перестала собираться. Здесь же и страна под рукой, и
  /// база своя.
  ///
  /// # Почему отказ не роняет настройку
  ///
  /// Налог можно настроить и потом, экраном. Уронить здесь завершение
  /// мастера значило бы не пустить кассира к продаже из-за того, что он
  /// поправит за минуту.
  ///
  /// # Чего это НЕ делает
  ///
  /// Не выбирает город. В США ставка задаётся городом, набора страны там
  /// нет вовсе: такой кассе налог настраивают экраном, и мастер честно
  /// ничего не заводит.
  Future<void> _seedTaxFromPreset(CountryCode country) async {
    try {
      final catalog = await TaxPresetCatalog.load(rootBundle);
      final matching = catalog.matching(countryCode: country.isoCode);
      // Ровно один набор на страну — иначе выбор делает случай, а не
      // человек. Несколько (как у городов США) настраиваются экраном.
      if (matching.length != 1) {
        SetupLogger.info(
          'completeSetup: наборов для ${country.isoCode} — '
          '${matching.length}, налог настраивается экраном',
        );
        return;
      }
      await _db.taxSettingsDao.applyPreset(matching.single);
      SetupLogger.info(
        'completeSetup: налог заведён из набора «${matching.single.id}»',
      );
    } catch (e, stack) {
      SetupLogger.error('completeSetup: набор налога не применён', e, stack);
    }
  }

  /// Writes this new user's permission rows straight from
  /// `PermissionKeys.roleDefaults[role]` — the only place role-based
  /// defaults exist (task 12). Before this, the wizard never called
  /// `setPermissions` at all, so every non-owner user it created ended up
  /// with zero permission rows — which, under `UserPermissionDao
  /// .getAllowedKeys`'s current "empty table = allow everything" reading,
  /// was the DEFAULT path to a user with every permission, `settings.*`
  /// included.
  ///
  /// Writes only the keys the role default actually grants — an
  /// `isAllowed: true` row per key in the set, nothing for the keys it
  /// excludes. This is deliberately narrower than the create-user *form*
  /// (`user_management_screen.dart`), which writes a row for all 34 keys
  /// (`PermissionKeys.allPermissions.length` as of 2026-08-22) because a
  /// human looked at every switch and could have touched any of them; the
  /// wizard never showed a permissions screen at all, so there is nothing to
  /// record beyond "this role's default set".
  ///
  /// `owner` gets no rows, on purpose: `LocalAuthRepository._issue` grants
  /// `owner` every permission by bypassing the permission table entirely, so
  /// rows here would be data nothing reads — seeding them would only invite
  /// someone to believe access is controlled by rows that are never
  /// consulted (see `PermissionKeys.roleDefaults`'s own doc comment).
  Future<void> _writeRoleDefaultPermissions(
    AppDatabase db,
    int userId,
    UserRole role,
  ) async {
    if (role == UserRole.owner) return;

    final defaults = PermissionKeys.roleDefaults[role] ?? const <String>{};
    await db.userPermissionDao.setPermissions(userId, {
      for (final key in defaults) key: true,
    });
  }

  /// Creates this terminal's `DeviceBinding`s directly from what the wizard
  /// collected — receipt printer, scanner, cash drawer, Kaspi POS payment
  /// terminal (docs/system-architecture.md, section 8, И27).
  ///
  /// This used to write the wizard's equipment step into the installation-wide
  /// `hardware_settings` SharedPreferences blob, which nothing reads anymore
  /// (plan 2, task 3 deleted the reader — `lib/hardware/hardware_settings_provider.dart`).
  /// Leaving the write behind would have meant every brand-new installation —
  /// as opposed to one upgrading from schema v26, which schema v27's migration
  /// already handles — got no device bindings at all: no printer, silently,
  /// on a till that had never run before. That is the regression this method
  /// closes.
  ///
  /// Reuses [inferLegacyDeviceMigration] — the exact narrowing logic schema
  /// v27's migration already applies to old `Terminals` raw columns
  /// (`lib/data/database/migrations/device_binding_migration.dart`) — rather
  /// than re-deriving "which profile does this connection kind/paper width
  /// resolve to" here. The wizard's [EquipmentConfigInfo] fields are the same
  /// shape those raw columns are (same `PrinterConnectionType`/
  /// `ScannerConnectionType` enums, same "one printer for the installation"
  /// model this step hasn't been rebuilt to be per-terminal yet — see that
  /// class's own doc comment). Where a fact doesn't narrow to exactly one
  /// profile, no binding is created — an unconfigured device the operator
  /// fixes later in settings, never a guessed one (И30: that must never
  /// block a sale either).
  ///
  /// The Kaspi payment terminal is narrowed via a second, separate call: this
  /// method is the *only* place [DeviceClass.paymentTerminal] can be inferred
  /// from — `Terminals` has no payment-terminal raw columns to fall back to,
  /// so [inferLegacyDeviceMigration] only ever reads it from a blob. The
  /// small JSON map built below is never written to `SharedPreferences` — it
  /// exists purely in memory, as the shape that function's existing decode
  /// step expects, so this reuses that decode/narrow logic rather than
  /// reimplementing Kaspi's own inference. It is called separately from the
  /// printer/scanner/drawer call because a non-null blob there would make
  /// `_inferScannerBinding`/`_inferCashDrawerBinding` take the blob branch
  /// (with defaults for the keys this blob doesn't carry) instead of reading
  /// the wizard's actual raw-column-shaped answers.
  ///
  /// **Known gap inherited from task 2, not introduced here:** scales are
  /// never inferred by [inferLegacyDeviceMigration] at all — its own
  /// `LegacyDeviceSettings.terminalScalePort`/`terminalScaleBaudRate` fields
  /// are collected but no per-class function ever reads them, so a v26→v27
  /// upgrade never produces a scale binding either. This method faithfully
  /// reproduces that same gap rather than quietly fixing it out of scope.
  Future<void> _createDeviceBindings(
    SetupDraft draft,
    String cashBoxName,
  ) async {
    try {
      final eq = draft.equipment;
      final pos = draft.posConfig;
      final term = draft.paymentTerminal;
      final catalog = BuiltinDeviceProfileCatalog();

      final printerAddress = (eq.printerAddress?.isNotEmpty ?? false)
          ? eq.printerAddress
          : eq.printerName;

      final core = inferLegacyDeviceMigration(
        LegacyDeviceSettings(
          thisPosPaperWidthChars: eq.printerEnabled ? pos.paperWidth : null,
          terminalPrinterType: eq.printerEnabled
              ? eq.printerConnectionType.name
              : null,
          terminalPrinterAddress: eq.printerEnabled ? printerAddress : null,
          terminalScannerType: eq.scannerEnabled
              ? eq.scannerConnectionType.name
              : null,
          terminalDrawerViaPrinter: eq.cashDrawerEnabled
              ? eq.cashDrawerConnectedToPrinter
              : null,
        ),
        catalog: catalog,
      );

      final payment = inferLegacyDeviceMigration(
        LegacyDeviceSettings(
          hardwareSettingsBlobJson: jsonEncode({
            'kaspiEnabled': term.kaspiEnabled,
            'kaspiIp': term.kaspiTerminalIp,
            'kaspiPort': term.kaspiTerminalPort.toString(),
          }),
        ),
        catalog: catalog,
      );

      final bindings = [
        ...core.bindings,
        ...payment.bindings.where(
          (b) => b.deviceClass == DeviceClass.paymentTerminal,
        ),
      ];

      if (bindings.isEmpty) {
        SetupLogger.info(
          '_createDeviceBindings: ни один комплект настроек не сузился до '
          'единственного профиля — устройства не созданы (не ошибка)',
        );
        return;
      }

      final terminal = await _db.terminalDao.ensureSelf(
        fallbackName: cashBoxName,
      );

      for (final binding in bindings) {
        await _db
            .into(_db.terminalDeviceBindings)
            .insert(
              TerminalDeviceBindingsCompanion.insert(
                terminalId: terminal.id,
                deviceClass: binding.deviceClass.name,
                profileId: binding.profileId,
                bindingKey: binding.profileId,
                parametersJson: Value(jsonEncode(binding.parameters)),
                optionsJson: Value(jsonEncode(binding.options)),
                enabled: Value(binding.enabled),
              ),
            );
      }

      SetupLogger.info(
        '_createDeviceBindings: создано ${bindings.length} привязок для '
        'терминала #${terminal.id}: '
        '${bindings.map((b) => '${b.deviceClass.name}=${b.profileId}').join(', ')}',
      );
    } catch (e) {
      SetupLogger.warning('_createDeviceBindings: пропуск (не критично)', e);
    }
  }

  void _triggerInitialSync() {
    try {
      if (!GetIt.instance.isRegistered<CouchDbSyncCoordinator>()) {
        SetupLogger.info(
          '_triggerInitialSync: координатор не зарегистрирован — пропуск',
        );
        return;
      }
      final coordinator = GetIt.instance<CouchDbSyncCoordinator>();
      unawaited(_runInitialSync(coordinator));
    } catch (e) {
      SetupLogger.warning('_triggerInitialSync: пропуск (не критично)', e);
    }
  }

  Future<void> _runInitialSync(CouchDbSyncCoordinator coordinator) async {
    try {
      final result = await coordinator.syncNow();
      if (result.skipped) {
        SetupLogger.info(
          '_runInitialSync: пропущено (${result.skippedReason}) — офлайн/не настроено',
        );
      } else {
        SetupLogger.info(
          '_runInitialSync: ok=${result.ok}, pushed=${result.pushed}, pulled=${result.pulled}',
        );
      }
    } catch (e) {
      SetupLogger.warning(
        '_runInitialSync: ошибка синхронизации (не критично)',
        e,
      );
    }
  }

  Future<void> _importGlobalProducts() async {
    try {
      final importService = GetIt.instance<GlobalProductImportService>();

      if (!await importService.needsImport()) {
        SetupLogger.info('_importGlobalProducts: уже импортировано — пропуск');
        return;
      }

      SetupLogger.info('_importGlobalProducts: начинаем импорт каталога...');

      await importService.import(
        onProgress: (progress, message) {
          SetupLogger.info(
            '_importGlobalProducts: $message (${(progress * 100).toInt()}%)',
          );
        },
      );

      SetupLogger.info('_importGlobalProducts: импорт завершён успешно');
    } catch (e, stack) {
      SetupLogger.error(
        '_importGlobalProducts: импорт не удался (не критично)',
        e,
        stack,
      );
    }
  }
}
