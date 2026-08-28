import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/app/di/hardware_module.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/setup/setup_repository_local.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/hardware/printer/bluetooth_printer.dart';
import 'package:telepos/hardware/printer/linux_printer.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';
import 'package:telepos/hardware/printer/wifi_printer.dart';
import 'package:telepos/hardware/printer/windows_printer.dart';

/// Fix round 1 (2026-07-30): before this, the setup wizard wrote its
/// equipment step into the installation-wide `hardware_settings`
/// `SharedPreferences` blob — a key `hardware_module.dart` no longer reads
/// (plan 2, task 3 deleted that reader). A brand-new till, freshly through
/// the wizard, therefore ended up with **no device bindings at all**: no
/// printer, silently. Only an installation *upgrading* from schema v26 was
/// migrated (schema v27's `_migrateDeviceBindings`). This file proves the
/// wizard's commit path (`LocalSetupRepository.completeSetup`,
/// `lib/data/setup/setup_repository_local.dart`) now creates
/// `TerminalDeviceBindings` rows directly, reusing
/// `inferLegacyDeviceMigration` (`lib/data/database/migrations/device_binding_migration.dart`)
/// — the same narrowing logic the v26→v27 migration already applies —
/// rather than re-deriving it.
void main() {
  final talker = Talker();

  /// [paperWidth] is `PosConfigInfo.paperWidth` — a **character count**
  /// (receipt-formatting column width), the same field
  /// `initial_setup_screen.dart`'s paper-width dropdown writes. The product
  /// only ever stores `32`, `42` or `48` there; it is never a millimetre
  /// value like `58`/`80`. Second-review-round finding: every call site
  /// below used to pass `58`/`80` directly — values the real wizard can
  /// never produce — which is exactly what let the missing character-to-
  /// millimetre conversion (`paperWidthMmFromCharWidth`) go unnoticed: the
  /// tests were certifying the fix against inputs the product cannot store.
  SetupDraft draftWithPrinter({
    required PrinterConnectionType connectionType,
    required String? address,
    required int paperWidth,
  }) {
    return SetupDraft(
      countryIndex: 0,
      operatingModeIndex: 0,
      organization: const OrganizationInfo(
        companyName: 'ТОО ТестПОС',
        taxId: '123456789012',
      ),
      posConfig: PosConfigInfo(cashBoxName: 'Касса-1', paperWidth: paperWidth),
      fiscalConfig: const FiscalConfigInfo(),
      businessRules: const BusinessRulesConfigInfo(),
      equipment: EquipmentConfigInfo(
        printerEnabled: true,
        printerConnectionType: connectionType,
        printerAddress: address,
      ),
      paymentTerminal: const PaymentTerminalConfigInfo(),
      employees: const [],
      firstUser: const EmployeeInfo(),
    );
  }

  Future<AppDatabase> completeSetupWith(SetupDraft draft) async {
    final db = AppDatabase(NativeDatabase.memory());
    await LocalSetupRepository(db).completeSetup(draft);
    return db;
  }

  test(
    'a fresh database plus a completed wizard run produces a printer '
    'binding matching what the wizard collected',
    () async {
      final db = await completeSetupWith(
        draftWithPrinter(
          connectionType: PrinterConnectionType.wifi,
          address: '10.20.30.40',
          paperWidth: 48,
        ),
      );

      final terminal = await db.terminalDao.self();
      expect(
        terminal,
        isNotNull,
        reason: 'completeSetup must create this machine\'s terminal once it '
            'has at least one binding to attach.',
      );

      final rows = await db.terminalDao.deviceBindingsFor(terminal!.id);
      final printerRows = rows
          .where((r) => r.deviceClass == 'receiptPrinter')
          .toList();

      expect(
        printerRows,
        hasLength(1),
        reason: 'Exactly one receipt-printer binding, matching the one '
            'unambiguous profile 80mm+wifi narrows to.',
      );
      expect(printerRows.single.profileId, 'printer.escpos.80mm');
      final params =
          jsonDecode(printerRows.single.parametersJson) as Map<String, dynamic>;
      expect(params['ipAddress'], '10.20.30.40');
      expect(printerRows.single.enabled, isTrue);

      await db.close();
    },
  );

  test(
    'the same binding, resolved through hardware_module, yields a working '
    'printer manager — not just a row in a table',
    () async {
      final db = await completeSetupWith(
        draftWithPrinter(
          connectionType: PrinterConnectionType.wifi,
          address: '10.20.30.40',
          paperWidth: 48,
        ),
      );

      final getIt = GetIt.asNewInstance();
      getIt.registerSingleton<Talker>(talker);
      getIt.registerSingleton<AppDatabase>(db);
      getIt.registerLazySingleton<TerminalRepository>(
        () => LocalTerminalRepository(db),
      );

      // Simulates the next process boot after the wizard ran — this is the
      // same function `HardwareModule.register` calls at real app startup.
      await registerHardwareServices(getIt, logger: talker);

      expect(getIt.isRegistered<PrinterManager>(), isTrue);
      final printer = getIt<PrinterManager>();
      expect(printer, isA<WifiPrinterManager>());
      expect((printer as WifiPrinterManager).host, '10.20.30.40');

      await getIt.reset();
      await db.close();
    },
  );

  test(
    'wizard values that do not resolve to a unique profile produce no '
    'binding, not a guessed one',
    () async {
      // 80mm printers also run at 58mm — the same "still ambiguous"
      // narrowing device_binding_migration.dart documents
      // (resolveReceiptPrinterProfileId's doc comment) applies here
      // unchanged, because this is the same function. paperWidth: 32 is the
      // real character-count value that converts to 58mm
      // (paperWidthMmFromCharWidth) — not the millimetre value itself.
      final db = await completeSetupWith(
        draftWithPrinter(
          connectionType: PrinterConnectionType.wifi,
          address: '10.20.30.40',
          paperWidth: 32,
        ),
      );

      final terminal = await db.terminalDao.self();
      final printerRows = terminal == null
          ? const <TerminalDeviceBinding>[]
          : (await db.terminalDao.deviceBindingsFor(terminal.id))
                .where((r) => r.deviceClass == 'receiptPrinter')
                .toList();

      expect(
        printerRows,
        isEmpty,
        reason:
            '58mm alone does not narrow between printer.escpos.80mm (which '
            'also supports 58mm) and printer.escpos.58mm-compact — no '
            'binding must be created for an ambiguous choice, exactly as '
            'the v26→v27 migration itself refuses (fix round 1: "create no '
            'binding, exactly as the migration does").',
      );

      await db.close();
    },
  );

  group(
    'C1 end-to-end (final review, most serious finding): a USB printer '
    'chosen in the wizard produces a binding AND a working printer manager '
    '— not just a row in a table',
    () {
      test(
        'a USB printer configured through the wizard produces a binding, '
        'and hardware_module resolves it to a real (non-Wi-Fi) manager',
        () async {
          // paperWidth: 48 is a REAL character-count value (32/42/48 are the
          // only ones the wizard can ever collect — see draftWithPrinter's
          // doc comment). Second-review-round finding: this test used to
          // pass 80 (a millimetre value) here, which the wizard can never
          // actually produce, and which happened to coincidentally also be
          // a valid `paperWidthsMm` entry — so this test certified the fix
          // as working while the character-to-millimetre conversion did not
          // exist at all. With a real value, the option assertion below
          // only passes if that conversion actually runs.
          final db = await completeSetupWith(
            draftWithPrinter(
              connectionType: PrinterConnectionType.usb,
              address: 'COM5',
              paperWidth: 48,
            ),
          );

          final terminal = await db.terminalDao.self();
          expect(terminal, isNotNull);
          final printerRows = (await db.terminalDao.deviceBindingsFor(terminal!.id))
              .where((r) => r.deviceClass == 'receiptPrinter')
              .toList();
          expect(
            printerRows,
            hasLength(1),
            reason:
                'before this fix, the catalogue had no USB/spooler receipt-'
                'printer profile at all, so a USB choice in the wizard '
                'silently produced no binding whatsoever — and, separately, '
                'even after that fix, an unconverted character-count '
                'paperWidth (48) failed printer.escpos.usb\'s width filter '
                '([58, 80]) and emptied the candidate set just the same',
          );
          expect(printerRows.single.profileId, 'printer.escpos.usb');
          expect(
            jsonDecode(printerRows.single.parametersJson),
            {'devicePath': 'COM5'},
          );
          expect(
            jsonDecode(printerRows.single.optionsJson),
            {'paperWidthMm': '80'},
            reason:
                'the chosen option must be the converted millimetre value '
                '(80, from character count 48) — never the raw 48 itself, '
                'which is not a value any profile\'s paperWidthMm option '
                'permits',
          );

          final getIt = GetIt.asNewInstance();
          getIt.registerSingleton<Talker>(talker);
          getIt.registerSingleton<AppDatabase>(db);
          getIt.registerLazySingleton<TerminalRepository>(
            () => LocalTerminalRepository(db),
          );

          await registerHardwareServices(getIt, logger: talker);

          expect(
            getIt.isRegistered<PrinterManager>(),
            isTrue,
            reason:
                'before this fix, hardware_module.dart hardcoded '
                "receiptType: 'wifi', so a USB binding (no ipAddress "
                'parameter) never matched the Wi-Fi branch and the '
                'Windows/Linux platform branches were unreachable from '
                'production — no PrinterManager was ever registered for a '
                'USB printer',
          );
          final printer = getIt<PrinterManager>();
          expect(
            printer,
            isNot(isA<WifiPrinterManager>()),
            reason: 'a USB-bound printer must never resolve to Wi-Fi',
          );
          expect(
            printer,
            isNot(isA<MockPrinterManager>()),
            reason:
                'a USB binding must reach a driver that can actually write to '
                'the wire — a mock here would mean the wizard produced a row '
                'and nothing else, which is the defect this test exists for',
          );

          // The driver a USB binding must produce is platform-specific, and so
          // is the field carrying the bound path (`resolvePrinterManager`,
          // lib/app/di/hardware_module.dart:329-344). The claim being proved is
          // one and the same on both: the wizard's USB choice reaches a real
          // driver holding COM5 — not Wi-Fi, not a mock. Written against
          // Windows alone it passed on the author's machine and failed the
          // Linux runner (CI run 30674462663), which made every published
          // green threshold a Windows-only measurement. Neither platform is
          // allowed to skip the assertion, so `fail` closes the else.
          if (Platform.isWindows) {
            expect(printer, isA<WindowsPrinterManager>());
            expect((printer as WindowsPrinterManager).portName, 'COM5');
          } else if (Platform.isLinux) {
            expect(printer, isA<LinuxPrinterManager>());
            expect((printer as LinuxPrinterManager).devicePath, 'COM5');
          } else {
            fail(
              'no expectation is defined for ${Platform.operatingSystem}. '
              'resolvePrinterManager answers MockPrinterManager on macOS and '
              'BluetoothPrinterManager on mobile, so this test would prove '
              'nothing there; add the branch deliberately rather than let it '
              'pass by default.',
            );
          }

          await getIt.reset();
          await db.close();
        },
      );

      test(
        'a Bluetooth printer configured through the wizard produces a '
        'binding requiring the MAC address, and resolves to a working '
        'manager once one is supplied',
        () async {
          final db = await completeSetupWith(
            draftWithPrinter(
              connectionType: PrinterConnectionType.bluetooth,
              address: 'AA:BB:CC:DD:EE:FF',
              paperWidth: 32,
            ),
          );

          final terminal = await db.terminalDao.self();
          expect(terminal, isNotNull);
          final printerRows = (await db.terminalDao.deviceBindingsFor(terminal!.id))
              .where((r) => r.deviceClass == 'receiptPrinter')
              .toList();
          expect(
            printerRows,
            hasLength(1),
            reason:
                'paperWidth: 32 (a real character-count value, converting '
                'to 58mm) must still resolve — printer.escpos.bluetooth only '
                'supports 58mm, so an unconverted 32 would have failed the '
                'width filter just like the USB case above',
          );
          expect(printerRows.single.profileId, 'printer.escpos.bluetooth');
          expect(
            jsonDecode(printerRows.single.parametersJson),
            {'macAddress': 'AA:BB:CC:DD:EE:FF'},
          );
          expect(
            jsonDecode(printerRows.single.optionsJson),
            {'paperWidthMm': '58'},
          );

          // hardware_module.dart must actually resolve this to a Bluetooth
          // manager carrying the saved MAC address — before this fix,
          // `_registerPrinterManager` hardcoded `receiptType: 'wifi'`, so
          // the Bluetooth branch of `resolvePrinterManager` (which checks
          // `receiptType == 'bluetooth'`) was unreachable from production
          // no matter what the binding contained; unlike USB/serial, there
          // is no coincidental platform-default fallback for Bluetooth on
          // desktop — the old code would have built a Windows/Linux serial
          // manager instead, silently wrong.
          final getIt = GetIt.asNewInstance();
          getIt.registerSingleton<Talker>(talker);
          getIt.registerSingleton<AppDatabase>(db);
          getIt.registerLazySingleton<TerminalRepository>(
            () => LocalTerminalRepository(db),
          );
          await registerHardwareServices(getIt, logger: talker);
          expect(getIt.isRegistered<PrinterManager>(), isTrue);
          final printer = getIt<PrinterManager>();
          expect(printer, isA<BluetoothPrinterManager>());
          expect(
            (printer as BluetoothPrinterManager).deviceAddress,
            'AA:BB:CC:DD:EE:FF',
          );
          await getIt.reset();

          await db.close();
        },
      );
    },
  );
}
