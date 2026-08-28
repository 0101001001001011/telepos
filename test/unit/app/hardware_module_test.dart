import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/app/di/hardware_module.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/hardware/display/customer_display_manager.dart';
import 'package:telepos/hardware/display/display_config.dart';
import 'package:telepos/hardware/label_printer/label_printer_service.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';
import 'package:telepos/hardware/printer/wifi_printer.dart';

/// `registerHardwareServices` (`lib/app/di/hardware_module.dart`) resolving a
/// terminal's `DeviceBinding`s into real GetIt registrations — plan 2, task 3
/// ("Сборка устройств из контракта"). This is the read side of the plan: a
/// terminal's device bindings, built and migrated by tasks 1–2, must
/// actually drive what the app registers, and the old `hardware_settings`
/// blob must not be a second, competing source (it no longer exists at all —
/// `lib/hardware/hardware_settings_provider.dart` is deleted).
///
/// Seed data uses Kazakh and Kyrgyz Cyrillic terminal names on purpose
/// (qa-depth): if a test only ever used one plain ASCII name, "resolved the
/// terminal's own binding" and "resolved whatever binding happened to exist"
/// would be indistinguishable failures. Distinct names, distinct terminal
/// ids, distinct bindings makes them distinguishable.
void main() {
  final talker = Talker();

  /// Inserts a terminal named [name], marks it `isSelf`, and returns its id.
  /// A minimal `ThisPosEntries` row is required first: `TerminalRepository
  /// .self()` refuses (`InstallationNotConfiguredException`) unless
  /// `cashBoxName` is set, regardless of whether an `isSelf` terminal row
  /// already exists — see `LocalTerminalRepository.self()`'s doc comment.
  /// Inserting the `isSelf` row directly (rather than going through
  /// `self()`/`ensureSelf()`) is what lets this test pick the terminal's name
  /// itself instead of inheriting `cashBoxName` as a fallback.
  Future<int> seedSelfTerminal(AppDatabase db, String name) async {
    await db.thisPosDao.insertInitialConfig(
      companyName: 'ТОО ТестПОС',
      iinbin: null,
      cashBoxName: name,
      countryCode: 0,
      currencyCode: 0,
      currencySymbol: '₸',
      currencyNameShort: 'KZT',
      paperWidth: 58,
      printerHeader: null,
      printerFooter: null,
      accountId: null,
      acquiringAccountId: null,
      rsaPublicKey: null,
    );
    return db
        .into(db.terminals)
        .insert(
          TerminalsCompanion.insert(
            name: name,
            isSelf: const Value(true),
            createdAt: 0,
          ),
        );
  }

  Future<void> insertBinding(
    AppDatabase db, {
    required int terminalId,
    required String deviceClass,
    required String profileId,
    Map<String, String> parameters = const {},
    Map<String, String> options = const {},
    bool enabled = true,
  }) async {
    await db
        .into(db.terminalDeviceBindings)
        .insert(
          TerminalDeviceBindingsCompanion.insert(
            terminalId: terminalId,
            deviceClass: deviceClass,
            profileId: profileId,
            bindingKey: profileId,
            parametersJson: Value(jsonEncode(parameters)),
            optionsJson: Value(jsonEncode(options)),
            enabled: Value(enabled),
          ),
        );
  }

  /// Boots a fresh in-memory database + a fresh GetIt instance (so
  /// scenarios never share state), registers what `registerHardwareServices`
  /// needs (`Talker`, `AppDatabase`, `TerminalRepository`), and returns both
  /// so the test can register bindings before calling it.
  Future<(AppDatabase, GetIt)> newFixture() async {
    final db = AppDatabase(NativeDatabase.memory());
    final getIt = GetIt.asNewInstance();
    getIt.registerSingleton<Talker>(talker);
    getIt.registerSingleton<AppDatabase>(db);
    getIt.registerLazySingleton<TerminalRepository>(
      () => LocalTerminalRepository(db),
    );
    return (db, getIt);
  }

  tearDown(() {});

  test(
    'terminal bound to a network printer profile yields a WifiPrinterManager '
    'with that binding\'s address',
    () async {
      final (db, getIt) = await newFixture();
      final terminalId = await seedSelfTerminal(db, 'Дүкен Алматы');
      await insertBinding(
        db,
        terminalId: terminalId,
        deviceClass: 'receiptPrinter',
        profileId: 'printer.escpos.80mm',
        parameters: {'ipAddress': '10.0.5.21', 'port': '9100'},
      );

      await registerHardwareServices(getIt, logger: talker);

      expect(getIt.isRegistered<PrinterManager>(), isTrue);
      final printer = getIt<PrinterManager>();
      expect(printer, isA<WifiPrinterManager>());
      expect((printer as WifiPrinterManager).host, '10.0.5.21');
      expect(printer.port, 9100);

      await getIt.reset();
      await db.close();
    },
  );

  test(
    'terminal with no printer binding yields no printer — not a silent stub',
    () async {
      final (db, getIt) = await newFixture();
      final terminalId = await seedSelfTerminal(db, 'Дүкөн Бишкек');
      // A scanner binding exists, but deliberately no receiptPrinter binding
      // — proves the printer absence is class-specific, not "nothing
      // resolved at all".
      await insertBinding(
        db,
        terminalId: terminalId,
        deviceClass: 'scanner',
        profileId: 'scanner.camera',
      );

      await registerHardwareServices(getIt, logger: talker);

      expect(
        getIt.isRegistered<PrinterManager>(),
        isFalse,
        reason:
            'A terminal with no printer binding must get no PrinterManager '
            'at all — every printer consumer in this codebase already '
            'checks isRegistered<PrinterManager>() before use (И30), and a '
            'MockPrinterManager or platform fallback here would be a '
            'silent stub that accepts print jobs and discards them.',
      );

      await getIt.reset();
      await db.close();
    },
  );

  test(
    'two terminals with different printer bindings resolve to different '
    'printers',
    () async {
      final (dbA, getItA) = await newFixture();
      final terminalA = await seedSelfTerminal(dbA, 'Дүкен Алматы №1');
      await insertBinding(
        dbA,
        terminalId: terminalA,
        deviceClass: 'receiptPrinter',
        profileId: 'printer.escpos.80mm',
        parameters: {'ipAddress': '10.0.5.21', 'port': '9100'},
      );
      await registerHardwareServices(getItA, logger: talker);
      final printerA = getItA<PrinterManager>() as WifiPrinterManager;

      final (dbB, getItB) = await newFixture();
      final terminalB = await seedSelfTerminal(dbB, 'Дүкөн Бишкек №2');
      await insertBinding(
        dbB,
        terminalId: terminalB,
        deviceClass: 'receiptPrinter',
        profileId: 'printer.escpos.58mm-compact',
        parameters: {'ipAddress': '10.0.5.99'},
      );
      await registerHardwareServices(getItB, logger: talker);
      final printerB = getItB<PrinterManager>() as WifiPrinterManager;

      expect(
        printerA.host,
        isNot(equals(printerB.host)),
        reason:
            'Each terminal must resolve its OWN binding — this is the '
            'property the whole plan exists to establish (devices belong '
            'to the terminal, not the installation).',
      );
      expect(printerA.host, '10.0.5.21');
      expect(printerB.host, '10.0.5.99');

      await getItA.reset();
      await dbA.close();
      await getItB.reset();
      await dbB.close();
    },
  );

  test(
    'terminal with two enabled receipt printer bindings refuses to guess — '
    'no printer registered',
    () async {
      final (db, getIt) = await newFixture();
      final terminalId = await seedSelfTerminal(db, 'Дүкен Шымкент');
      await insertBinding(
        db,
        terminalId: terminalId,
        deviceClass: 'receiptPrinter',
        profileId: 'printer.escpos.80mm',
        parameters: {'ipAddress': '10.0.5.1'},
      );
      await insertBinding(
        db,
        terminalId: terminalId,
        deviceClass: 'receiptPrinter',
        profileId: 'printer.escpos.58mm-compact',
        parameters: {'ipAddress': '10.0.5.2'},
      );

      await registerHardwareServices(getIt, logger: talker);

      expect(
        getIt.isRegistered<PrinterManager>(),
        isFalse,
        reason:
            'Two enabled receipt-printer bindings on one terminal is '
            'genuinely ambiguous without a "primary" marker — this codebase '
            'refuses to guess rather than silently pick one (see '
            '_resolveSingleBinding\'s doc comment in hardware_module.dart).',
      );

      await getIt.reset();
      await db.close();
    },
  );

  test(
    'a disabled printer binding is ignored, same as no binding at all',
    () async {
      final (db, getIt) = await newFixture();
      final terminalId = await seedSelfTerminal(db, 'Дүкен Тараз');
      await insertBinding(
        db,
        terminalId: terminalId,
        deviceClass: 'receiptPrinter',
        profileId: 'printer.escpos.80mm',
        parameters: {'ipAddress': '10.0.5.21'},
        enabled: false,
      );

      await registerHardwareServices(getIt, logger: talker);

      expect(getIt.isRegistered<PrinterManager>(), isFalse);

      await getIt.reset();
      await db.close();
    },
  );

  group(
    'customer display (final review finding C2 — a settings screen that '
    'saves a binding nothing reads)',
    () {
      test(
        'a customerDisplay binding is what CustomerDisplayManager actually '
        'receives — not a hardcoded disabled config',
        () async {
          final (db, getIt) = await newFixture();
          final terminalId = await seedSelfTerminal(db, 'Дүкен Экран');
          await insertBinding(
            db,
            terminalId: terminalId,
            deviceClass: 'customerDisplay',
            profileId: 'display.serial.vfd',
            parameters: {'comPort': 'COM9'},
          );

          await registerHardwareServices(getIt, logger: talker);

          final manager = getIt<CustomerDisplayManager>();
          expect(
            manager.config.enabled,
            isTrue,
            reason:
                'before this fix, _registerDisplayService ignored bindings '
                'entirely and hardcoded enabled: false regardless of what '
                'was saved',
          );
          expect(manager.config.port, 'COM9');
          expect(manager.config.baudRate, 9600);
          expect(
            manager.config.model,
            DisplayModel.vfd20,
            reason:
                'display.serial.vfd declares displayColumns: 20 — there was '
                'no test asserting on config.model at all before this fix, '
                'which is exactly why _displayModelFor always returning '
                'vfd20 regardless of the profile went unnoticed',
          );

          await getIt.reset();
          await db.close();
        },
      );

      test(
        'no customerDisplay binding — disabled, same default as before',
        () async {
          final (db, getIt) = await newFixture();
          final terminalId = await seedSelfTerminal(db, 'Дүкен Без Экрана');
          await insertBinding(
            db,
            terminalId: terminalId,
            deviceClass: 'scanner',
            profileId: 'scanner.camera',
          );

          await registerHardwareServices(getIt, logger: talker);

          final manager = getIt<CustomerDisplayManager>();
          expect(manager.config.enabled, isFalse);

          await getIt.reset();
          await db.close();
        },
      );

      test(
        'a disabled customerDisplay binding is treated as no display at all',
        () async {
          final (db, getIt) = await newFixture();
          final terminalId = await seedSelfTerminal(db, 'Дүкен Выключенный Экран');
          await insertBinding(
            db,
            terminalId: terminalId,
            deviceClass: 'customerDisplay',
            profileId: 'display.serial.vfd',
            parameters: {'comPort': 'COM9'},
            enabled: false,
          );

          await registerHardwareServices(getIt, logger: talker);

          final manager = getIt<CustomerDisplayManager>();
          expect(manager.config.enabled, isFalse);

          await getIt.reset();
          await db.close();
        },
      );

      test(
        'the other display profile (lcd-2x20) carries its own baud rate '
        'through too — not a coincidence that vfd worked',
        () async {
          final (db, getIt) = await newFixture();
          final terminalId = await seedSelfTerminal(db, 'Дүкен LCD Экран');
          await insertBinding(
            db,
            terminalId: terminalId,
            deviceClass: 'customerDisplay',
            profileId: 'display.serial.lcd-2x20',
            parameters: {'comPort': 'COM11'},
          );

          await registerHardwareServices(getIt, logger: talker);

          final manager = getIt<CustomerDisplayManager>();
          expect(manager.config.enabled, isTrue);
          expect(manager.config.port, 'COM11');
          expect(
            manager.config.baudRate,
            2400,
            reason: 'display.serial.lcd-2x20 declares defaultBaudRate 2400',
          );
          expect(
            manager.config.model,
            DisplayModel.vfd20,
            reason: 'display.serial.lcd-2x20 also declares displayColumns: 20',
          );

          await getIt.reset();
          await db.close();
        },
      );

      test(
        'an 8-character display profile resolves to DisplayModel.led8 — '
        'proves the model is genuinely derived from the profile, not a '
        'hardcoded constant that happens to look right for the other two',
        () async {
          final (db, getIt) = await newFixture();
          final terminalId = await seedSelfTerminal(db, 'Дүкен LED Экран');
          await insertBinding(
            db,
            terminalId: terminalId,
            deviceClass: 'customerDisplay',
            profileId: 'display.serial.led8',
            parameters: {'comPort': 'COM12'},
          );

          await registerHardwareServices(getIt, logger: talker);

          final manager = getIt<CustomerDisplayManager>();
          expect(manager.config.enabled, isTrue);
          expect(manager.config.port, 'COM12');
          expect(
            manager.config.model,
            DisplayModel.led8,
            reason:
                'display.serial.led8 declares displayColumns: 8 — before '
                'this fix, _displayModelFor ignored the profile entirely '
                'and always returned DisplayModel.vfd20, so this could '
                'never be reached from any binding',
          );

          await getIt.reset();
          await db.close();
        },
      );
    },
  );

  group(
    'label printer height is an operator choice, same mechanism as width '
    '(task 5(a), plan 2b)',
    () {
      test(
        'a labelHeightMm option on the binding reaches LabelPrinterService, '
        'exactly like paperWidthMm already does',
        () async {
          final (db, getIt) = await newFixture();
          final terminalId = await seedSelfTerminal(db, 'Дүкен Этикетка');
          await insertBinding(
            db,
            terminalId: terminalId,
            deviceClass: 'labelPrinter',
            profileId: 'printer.label.zpl.104mm',
            parameters: {'ipAddress': '10.0.6.5', 'port': '9101'},
            options: {'paperWidthMm': '104', 'labelHeightMm': '60'},
          );

          await registerHardwareServices(getIt, logger: talker);

          final service = getIt<LabelPrinterService>();
          expect(
            service.labelWidthMm,
            104,
            reason: 'sanity check — width already worked before this task',
          );
          expect(
            service.labelHeightMm,
            60,
            reason:
                'before the "cheap fix" this task closes, hardware_module.dart '
                'hardcoded labelHeightMm: 40 for every installation regardless '
                'of what the operator chose here — there was no test proving '
                'the chosen value was ever actually read',
          );

          await getIt.reset();
          await db.close();
        },
      );

      test(
        'no labelHeightMm option chosen — falls back to 40, same default as '
        'before this task existed',
        () async {
          final (db, getIt) = await newFixture();
          final terminalId = await seedSelfTerminal(db, 'Дүкен Этикетка Без Высоты');
          await insertBinding(
            db,
            terminalId: terminalId,
            deviceClass: 'labelPrinter',
            profileId: 'printer.label.zpl.104mm',
            parameters: {'ipAddress': '10.0.6.6'},
          );

          await registerHardwareServices(getIt, logger: talker);

          final service = getIt<LabelPrinterService>();
          expect(service.labelHeightMm, 40);

          await getIt.reset();
          await db.close();
        },
      );
    },
  );

  // The "scannerTimeoutMs reaches BarcodeScannerService.inputTimeoutMs"
  // group that used to live here is gone (fix round 1, task 5(c), plan 2b):
  // `BarcodeScannerService` itself is deleted — it was a second, parallel
  // implementation of keyboard-wedge decoding that no production code path
  // ever started, and wiring scannerTimeoutMs into it (the previous round of
  // this task) fed a setting into a reader that never ran. The real,
  // wired-and-tested reader is `BarcodeScannerMixin`
  // (`lib/presentation/common/mixins/barcode_scanner_mixin.dart`) — covered
  // by `test/presentation/common/mixins/barcode_scanner_mixin_test.dart`.
  //
  // scannerTimeoutMs's *migration* — carrying the old `hardware_settings`
  // blob's `scannerTimeout` key forward into the new column, including for
  // an installation already sitting at v27 upgrading straight to v28 — is
  // covered separately in test/unit/data/device_migration_test.dart, not
  // here: hardware_module.dart has never been the migration's reader.
}
