/// Schema v27's data migration: translates the three legacy device-settings
/// sources — the `hardware_settings` blob (`SharedPreferences`),
/// `ThisPosEntries.paperWidth`/`printerPort`, and the v26 `Terminals` raw
/// columns — into `DeviceBinding`s (docs/system-architecture.md, section 8,
/// И141/И142). See `lib/data/database/app_database.dart`'s `from < 27` block
/// for where this is called, and task-2-report.md for the reasoning behind
/// every mapping decision below.
///
/// Deliberately pure Dart — no `shared_preferences`, no `drift`.
/// `AppDatabase` (lib/data/database/app_database.dart) is imported by
/// `bin/telepos_backend.dart`, a plain `dart run` entry point with no
/// Flutter engine; nothing this file touches may pull in a Flutter plugin.
/// The composition root reads the blob and hands this migration a plain
/// `String?` — see `AppDatabase.legacyHardwareSettingsBlobJson`.
///
/// **Every live `hardware_settings` blob key, accounted for.** The original
/// version of this inventory claimed sixteen keys, taken only from
/// `HardwareSettingsProvider` (`lib/hardware/hardware_settings_provider.dart`).
/// That was wrong — final review, 2026-07-30: the printer, label and scale
/// settings screens each wrote directly into the same `hardware_settings`
/// string, bypassing `HardwareSettingsProvider` entirely, so its parsed
/// shape was never the full set of keys actually live in the blob. Verified
/// against git history at `764b52d` (the last commit before this plan
/// started touching those screens). The table below is the corrected,
/// complete inventory — a key missing from it is a key this migration
/// forgot, not one it deliberately dropped:
///
/// | Key | Disposition |
/// |---|---|
/// | `barcodeMinLength`, `barcodeMaxLength` | Not a device setting at all (И142) — `ThisPosEntries` business rules. |
/// | `scannerMode` | Scanner binding selection — [_inferScannerBinding]. |
/// | `drawerMode`, `drawerPort` | Cash drawer binding — [_inferCashDrawerBinding]. |
/// | `kaspiEnabled`, `kaspiIp`, `kaspiPort` | Payment terminal binding (`payment.kaspi.pos`) — [_inferPaymentTerminalBinding]. |
/// | `rahmetEnabled`, `rahmetMerchant`, `rahmetTerminal` | **Deliberately ignored.** Rahmet is being removed from the product entirely (product owner, mid fix-round-1 on this task — see task-2-report.md). Migrating a payment integration that is about to stop existing would create a binding pointing at a catalogue profile the wider removal is about to delete. That wider removal — `lib/hardware/rahmet/*`, the payment widget, setup-draft fields, the permission entry, localisation strings, `ThisPosEntries.isRahmetPaymentEnabled`, the catalogue profile itself — is a separate, already-dispatched task with its own ownership; this migration only stops *reading* these three keys, nothing else. |
/// | `scannerTimeout` | **Now carried forward, from schema v28 (task 5(c), plan 2b, fix round 1).** Not a connection parameter any scanner profile declares (И141), and — same as the barcode-length pair right above this row — a business rule about how to interpret a keyboard-wedge scanner's input, not a device setting (И142). Lands on `ThisPosEntries.scannerTimeoutMs`. Read by [migrateLegacyScannerTimeoutMs], called from `app_database.dart`'s `from < 28` step directly (not from [inferLegacyDeviceMigration]/this function — see that function's doc comment for why: it must work whether an installation crosses v27 and v28 in the same launch or crossed v27 in an earlier one, and must not re-run binding inference either way). |
/// | `displayEnabled`, `displayModel`, `displayPort`, `displayBaudRate` | **Deliberately ignored by this migration** — the customer-display class never resolves to one profile from these facts (`displayModel`'s taxonomy doesn't correspond to either catalogue profile's name). This no longer means the display goes unconfigured, though: the settings screen now saves a real `customerDisplay` binding directly through `DeviceBindingRepository` (`lib/presentation/screens/settings/hardware_settings_screen.dart`), which `hardware_module.dart`'s `_registerDisplayService` reads — a second, live path this migration does not need to cover. |
/// | `receiptPrinterType`, `receiptPrinterAddress`, `receiptPrinterPort` | **The correction's central case.** Written directly by `printer_settings_screen.dart`'s pre-branch `_saveSettings`, in the same call as (and always in sync with) that screen's write to `ThisPosEntries.printerConnectionType`/`.printerAddress`/`.printerPort` — so this blob copy carries the same facts as those now-dropped columns, except this one was actually reachable and they were not (only the HTTP route ever wrote them, so they read `null` on any till that never had a browser terminal). [_inferReceiptPrinterBinding] now reads this blob copy first, falling back to the v26 `Terminals.printerType`/`.printerAddress` columns only when the blob has nothing. See [_transportPredicateForPrinterConnectionKind] for why `receiptPrinterType` (a `PrinterConnectionType.name` string: `usb`/`bluetooth`/`wifi`/`serial`) now selects a *transport*, not a protocol: every receipt-printer profile in the catalogue speaks ESC/POS, so protocol alone stopped being able to tell wifi from usb the moment USB/Bluetooth/serial profiles existed (docs/system-architecture.md, section 8). |
/// | `labelHost`, `labelPort`, `labelLanguage`, `labelWidthMm`, `labelHeightMm` | Label-printer binding — [_inferLabelPrinterBinding]. Written directly by `label_printer_settings_screen.dart`'s pre-branch `_saveSettings`. `labelLanguage` (`'zpl'`/`'tspl'`/`'epl'`) narrows the catalogue's two label-printer profiles uniquely for `zpl`/`epl`; `tspl` has no catalogue profile at all (no shipped TSPL-speaking model), so it produces no binding — a genuine gap, not a guess. |
/// | `scaleEnabled`, `scalePort`, `scaleBaudRate`, `scaleProtocol` | Scale binding attempt — [_inferScaleBinding]. Written directly by the pre-branch `hardware_settings_screen.dart`'s own scale section — a different file from `HardwareSettingsProvider`, and never covered by its sixteen-key model at all. Only `scaleProtocol == 'cas'` has any catalogue match, and even then the catalogue's two CAS profiles (`scale.cas.pd2`, `scale.cas.er-plus`) share the same `defaultBaudRate` — genuinely indistinguishable from these facts, so no binding is ever produced, even for `'cas'`. Recorded here rather than silently absent, per the rule this whole table exists to satisfy: a key deliberately not carried must be distinguishable from one simply forgotten. |
/// | `customerScreenEnabled`, `customerScreenMonitor` | Not a `DeviceBinding` at all — the graphic customer screen on a second monitor is a window this process opens, not a peripheral. Lives in `CustomerScreenChoice`/`kCustomerScreenPrefsKey` (`lib/core/settings/customer_screen_settings.dart`), outside this migration entirely. |
library;

import 'dart:convert';

import 'package:meta/meta.dart';

import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/terminal/device_binding.dart';

/// Everything one terminal's migration decision needs, read off a v26
/// database before the columns it names are gone. [hardwareSettingsBlobJson]
/// is installation-wide in the old model (one machine, one blob) — the
/// caller passes it only for the terminal marked `isSelf`, `null` for every
/// other terminal, so a browser-registered second terminal never inherits
/// this machine's hardware.
@immutable
class LegacyDeviceSettings {
  const LegacyDeviceSettings({
    this.hardwareSettingsBlobJson,
    this.thisPosPaperWidthChars,
    this.terminalPrinterType,
    this.terminalPrinterAddress,
    this.terminalScannerType,
    this.terminalDrawerViaPrinter,
  });

  /// Raw JSON string previously stored under SharedPreferences key
  /// `hardware_settings` — `null` if there was none, or if this terminal
  /// isn't the one the blob belonged to.
  final String? hardwareSettingsBlobJson;

  /// `ThisPosEntries.paperWidth` / `PosConfigInfo.paperWidth` — installation-
  /// wide, so only meaningful for the self terminal (same scoping rule as
  /// the blob).
  ///
  /// **This is a character count (receipt-formatting column width), not a
  /// millimetre width.** The only values the product ever stores here are
  /// `32`, `42` and `48` (see `initial_setup_screen.dart`'s paper-width
  /// dropdown and the pre-branch `printer_settings_screen.dart`); the
  /// catalogue's `paperWidthsMm` is expressed in millimetres (`58`/`80`/...).
  /// Named `...Chars` rather than the bare `thisPosPaperWidth` this field
  /// used to be — a final-review finding: the old name gave no hint that a
  /// unit conversion was needed before comparing it against
  /// `DeviceCapabilities.paperWidthsMm`, and for a while nothing did the
  /// conversion, silently emptying the candidate set for every real value
  /// (32/42/48 matches no profile's declared millimetre widths). Convert
  /// with [paperWidthMmFromCharWidth] — never compare this field to
  /// `paperWidthsMm` directly.
  final int? thisPosPaperWidthChars;

  /// `Terminals.printerType` (v26) — the *name* of a `PrinterConnectionType`
  /// value, written only by the clean, single-writer `TerminalDevices` path
  /// (`lib/domain/terminal/terminal.dart`), unlike
  /// `ThisPosEntries.printerConnectionType`'s two incompatible int
  /// encodings. Not ambiguous by construction — see
  /// [resolveReceiptPrinterProfileId] for how it, together with the
  /// millimetre width converted from [thisPosPaperWidthChars], narrows the
  /// receipt-printer profile. Used only as a fallback now:
  /// [_inferReceiptPrinterBinding] prefers the blob's own `receiptPrinterType`
  /// when present (see the blob-key inventory above).
  final String? terminalPrinterType;

  final String? terminalPrinterAddress;

  /// `Terminals.scannerType` (v26) — name of a `ScannerConnectionType`
  /// value (`none`/`usb`/`bluetooth`/`camera`).
  final String? terminalScannerType;

  /// `Terminals.drawerViaPrinter` (v26) — unlike the printer/scanner raw
  /// columns, this one is a plain bool with only two states, so it carries
  /// no encoding ambiguity at all.
  final bool? terminalDrawerViaPrinter;

  // `terminalScalePort`/`terminalScaleBaudRate`/`terminalDisplayPort` used to
  // live here, collected by the v26→v27 migration call site
  // (`AppDatabase._migrateDeviceBindings`) and never read by any function in
  // this file — a final-review finding (2026-07-30): a field that is
  // gathered but never consumed makes the migration look more complete than
  // it is. Removed rather than wired to a guess: the scale class has the
  // same "genuinely ambiguous" problem from the blob source too (see
  // [_inferScaleBinding] and the blob-key inventory's `scaleProtocol` row —
  // the catalogue's two CAS profiles share a baud rate, so a COM port and a
  // baud rate cannot tell them apart regardless of which source supplies
  // them), and the customer-display class has no catalogue profile that
  // resolves from a bare port string at all. Consuming these v26 raw
  // columns would not have produced a binding either way, so deleting them
  // loses nothing a real migration could have used.
}

/// What [inferLegacyDeviceMigration] decided for one terminal, plus the two
/// business-rule values that don't belong to any binding (И142).
@immutable
class LegacyDeviceMigrationResult {
  const LegacyDeviceMigrationResult({
    required this.bindings,
    this.barcodeMinLength,
    this.barcodeMaxLength,
  });

  /// Already validated against [catalog] — every entry here is safe to
  /// persist as-is; nothing further needs checking by the caller.
  final List<DeviceBinding> bindings;

  final int? barcodeMinLength;
  final int? barcodeMaxLength;
}

/// Infers device bindings and business-rule values for one terminal from its
/// legacy settings. A class whose old raw value does not resolve to exactly
/// one profile contributes nothing to the result — never a guessed binding.
/// See the per-class functions below for the reasoning behind each, and the
/// blob-key inventory at the top of this file for which of the sixteen
/// `hardware_settings` keys feed into which class (or into neither, and
/// why).
///
/// Every per-class function here currently contributes at most one binding.
/// `TerminalDeviceBindings` (`lib/data/database/tables/terminal_tables.dart`)
/// nonetheless supports more than one binding of the same class per
/// terminal — a till running two label printers, or several peripherals at
/// an unattended point, is an ordinary case this migration's *sources*
/// simply never produce more than one value for (each old field is a single
/// value, not a list). The plural shape is schema-level readiness, not
/// something this migration exercises today.
LegacyDeviceMigrationResult inferLegacyDeviceMigration(
  LegacyDeviceSettings legacy, {
  DeviceProfileCatalog? catalog,
}) {
  final cat = catalog ?? BuiltinDeviceProfileCatalog();
  final blob = _decodeBlob(legacy.hardwareSettingsBlobJson);

  final bindings = <DeviceBinding>[];

  final drawer = _inferCashDrawerBinding(blob, legacy, cat);
  if (drawer != null) bindings.add(drawer);

  final scanner = _inferScannerBinding(blob, legacy, cat);
  if (scanner != null) bindings.add(scanner);

  final payment = _inferPaymentTerminalBinding(blob, cat);
  if (payment != null) bindings.add(payment);

  final printer = _inferReceiptPrinterBinding(blob, legacy, cat);
  if (printer != null) bindings.add(printer);

  final label = _inferLabelPrinterBinding(blob, cat);
  if (label != null) bindings.add(label);

  // Scale is deliberately attempted, not silently skipped — see
  // [_inferScaleBinding]'s doc comment for why it never actually produces a
  // binding today, and the blob-key inventory's `scaleProtocol` row for why
  // that is a documented gap rather than an unread key.
  final scale = _inferScaleBinding(blob, cat);
  if (scale != null) bindings.add(scale);

  return LegacyDeviceMigrationResult(
    bindings: bindings,
    // Same guard, same reason as [migrateLegacyScannerTimeoutMs] — see
    // [_intOrNull]. This function is called from `onUpgrade` too.
    barcodeMinLength: _intOrNull(blob?['barcodeMinLength']),
    barcodeMaxLength: _intOrNull(blob?['barcodeMaxLength']),
  );
}

/// Recovers `scannerTimeout` from the old `hardware_settings` blob for
/// schema v28's `ThisPosEntries.scannerTimeoutMs` column (task 5(c), plan
/// 2b, fix round 1). Deliberately **not** folded into
/// [inferLegacyDeviceMigration]/[LegacyDeviceMigrationResult]: that function
/// also (re)infers device bindings and is only ever called from the `from <
/// 27` migration step, which does not run again for an installation already
/// sitting at v27 — exactly the common case for this v28 bump. This
/// extracts only the one business-rule value, so `app_database.dart`'s `from
/// < 28` step can call it unconditionally regardless of whether the v27 step
/// ran in the same upgrade pass or a previous one, without re-running
/// binding inference (which would risk inserting duplicate bindings for an
/// installation that already has them).
///
/// `null` if the blob is absent, malformed, or never had a `scannerTimeout`
/// key — every one of those means "nothing to carry forward", not "reset to
/// zero".
int? migrateLegacyScannerTimeoutMs(String? hardwareSettingsBlobJson) {
  final blob = _decodeBlob(hardwareSettingsBlobJson);
  return _intOrNull(blob?['scannerTimeout']);
}

/// [value] if it really is an `int`, otherwise `null`.
///
/// **Finding M3.** These reads used to be `as int?` casts, and they sit
/// *outside* [_decodeBlob]'s try/catch, in functions `app_database.dart`
/// calls from `onUpgrade`. A blob whose `scannerTimeout` held a string or a
/// double would therefore throw a `TypeError` inside the migration, and the
/// database would not open at all — a dead till, for a value nothing forces
/// to be an int (the blob is free-form JSON). The only historical writer
/// always wrote an `int`, so no value this system has produced can trigger
/// it; that is an argument for the crash being unreachable today, not for
/// keeping a whole class of failure alive to save one line.
///
/// A value of an unexpected type is *skipped*, exactly like an absent key or
/// a malformed blob: "nothing to carry forward" is the honest reading of a
/// setting that was never stored in a usable shape, and it is the same
/// answer [_decodeBlob] already gives for JSON it cannot parse.
int? _intOrNull(Object? value) => value is int ? value : null;

Map<String, dynamic>? _decodeBlob(String? json) {
  if (json == null || json.isEmpty) return null;
  try {
    final decoded = jsonDecode(json);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {
    // Malformed JSON is the same as "no blob" — HardwareSettingsProvider.load
    // (lib/hardware/hardware_settings_provider.dart) treats it identically.
  }
  return null;
}

/// Builds a binding and validates it against [catalog] in one step, so every
/// caller below gets "missing required parameter" / "value not permitted"
/// treated exactly like "no such binding" — the same principle as an
/// ambiguous profile choice: an invalid binding is not created, full stop.
DeviceBinding? _tryBuild(
  DeviceProfileCatalog catalog,
  DeviceClass deviceClass,
  String profileId, {
  Map<String, String> parameters = const {},
  Map<String, String> options = const {},
}) {
  final binding = DeviceBinding(
    deviceClass: deviceClass,
    profileId: profileId,
    parameters: parameters,
    options: options,
  );
  try {
    binding.validateAgainst(catalog);
    return binding;
  } on ArgumentError {
    return null;
  }
}

/// Cash drawer — `drawerMode`/`drawerPort` (blob) or `drawerViaPrinter`
/// (`Terminals`, v26). Unlike printer/scanner, this one is genuinely
/// unambiguous either way: `drawer.rj11.via-printer` takes no parameters at
/// all, and `drawer.rj11.standalone` needs exactly one (`comPort`), which
/// `drawerMode == 1` pairs with `drawerPort` directly — the two catalogue
/// profiles sharing `DeviceProtocol.escPos` does *not* make this ambiguous,
/// because `drawerMode` (not the protocol) is what picks between them.
///
/// The blob is the live source and takes precedence when present. If the
/// blob says "standalone" but carries no usable port, that's a data gap
/// (falls through to the `Terminals` source), not an ambiguity — the two are
/// deliberately not conflated.
DeviceBinding? _inferCashDrawerBinding(
  Map<String, dynamic>? blob,
  LegacyDeviceSettings legacy,
  DeviceProfileCatalog catalog,
) {
  if (blob != null) {
    final mode = blob['drawerMode'] as int? ?? 0;
    if (mode == 1) {
      final port = (blob['drawerPort'] as String?)?.trim();
      final fromBlob = (port != null && port.isNotEmpty)
          ? _tryBuild(
              catalog,
              DeviceClass.cashDrawer,
              'drawer.rj11.standalone',
              parameters: {'comPort': port},
            )
          : null;
      if (fromBlob != null) return fromBlob;
      // Falls through to the Terminals source below — genuinely no port
      // data in the blob, not an ambiguous value.
    } else {
      return _tryBuild(catalog, DeviceClass.cashDrawer, 'drawer.rj11.via-printer');
    }
  }

  final viaPrinter = legacy.terminalDrawerViaPrinter;
  if (viaPrinter == null) return null;
  if (viaPrinter) {
    return _tryBuild(catalog, DeviceClass.cashDrawer, 'drawer.rj11.via-printer');
  }
  // `false` means standalone, but `Terminals` carries no drawer COM port
  // column of its own — nothing to supply the profile's required `comPort`.
  return null;
}

/// Scanner — `scannerMode` (blob: 0 keyboard-wedge / 1 serial / 2 camera) or
/// `scannerType` (`Terminals`, v26: `none`/`usb`/`bluetooth`/`camera`).
///
/// `scanner.usb.hid` and `scanner.bluetooth.hid` both declare
/// `DeviceProtocol.hidKeyboard` — the textbook shared-protocol ambiguity
/// named in the brief: keyboard-wedge (blob mode 0, or `Terminals`
/// `usb`/`bluetooth`) cannot tell which model without a MAC address, which
/// neither source carries. Camera is unambiguous either way — exactly one
/// profile speaks `DeviceProtocol.cameraScan`. Serial (blob mode 1) is now
/// unambiguous by protocol (`scanner.serial`, the only
/// `DeviceProtocol.serialScanner` profile) but the blob's 16 keys carry no
/// COM port for the scanner — [_tryBuild] refuses it for the missing
/// required `comPort`, same "no binding rather than a guess" outcome via the
/// existing validation path rather than a special case here.
DeviceBinding? _inferScannerBinding(
  Map<String, dynamic>? blob,
  LegacyDeviceSettings legacy,
  DeviceProfileCatalog catalog,
) {
  if (blob != null) {
    final mode = blob['scannerMode'] as int? ?? 0;
    return switch (mode) {
      2 => _tryBuild(catalog, DeviceClass.scanner, 'scanner.camera'),
      1 => _tryBuild(catalog, DeviceClass.scanner, 'scanner.serial'),
      _ => null, // 0 = keyboard-wedge: ambiguous, see doc comment.
    };
  }

  if (legacy.terminalScannerType == 'camera') {
    return _tryBuild(catalog, DeviceClass.scanner, 'scanner.camera');
  }
  return null; // none/usb/bluetooth/null: unconfigured or ambiguous.
}

/// Payment terminal — `kaspiEnabled`/`kaspiIp`/`kaspiPort` (blob only;
/// `Terminals` has no payment-terminal columns). Maps to exactly one
/// catalogue profile by construction (`payment.kaspi.pos` is the only
/// `DeviceProtocol.kaspiPos` profile).
///
/// `rahmetEnabled`/`rahmetMerchant`/`rahmetTerminal` are deliberately **not**
/// read — Rahmet is being removed from the product entirely (product owner,
/// mid fix-round-1; see the blob-key inventory at the top of this file and
/// task-2-report.md). This function used to also migrate a Rahmet binding
/// here, and — before that — the fact that both integrations could be
/// enabled at once was this migration's original justification for
/// `TerminalDeviceBindings` allowing more than one binding per class. That
/// justification is gone with Rahmet, but the plural-binding shape itself
/// stays (see `lib/data/database/tables/terminal_tables.dart`): the schema
/// is still on an unmerged branch, so keeping it costs nothing now and
/// would cost another schema version plus a data migration later, and two
/// bindings of one class is an ordinary case on its own — two label
/// printers, or several peripherals at an unattended point — not something
/// invented to justify itself.
DeviceBinding? _inferPaymentTerminalBinding(
  Map<String, dynamic>? blob,
  DeviceProfileCatalog catalog,
) {
  if (blob == null) return null;
  if (!(blob['kaspiEnabled'] as bool? ?? false)) return null;

  final ip = (blob['kaspiIp'] as String?)?.trim();
  final port = (blob['kaspiPort'] as String?)?.trim();
  return _tryBuild(
    catalog,
    DeviceClass.paymentTerminal,
    'payment.kaspi.pos',
    parameters: {
      if (ip != null && ip.isNotEmpty) 'ipAddress': ip,
      if (port != null && port.isNotEmpty) 'port': port,
    },
  );
}

/// Label printer — `labelHost`/`labelPort`/`labelLanguage`/`labelWidthMm`/
/// `labelHeightMm` (blob only; neither `Terminals` nor `ThisPosEntries` ever
/// had a per-terminal label-printer column reachable from here). Written
/// directly by `label_printer_settings_screen.dart`'s pre-branch
/// `_saveSettings` (see the blob-key inventory at the top of this file).
///
/// `labelLanguage` (a string: `'zpl'`/`'tspl'`/`'epl'`) maps to exactly one
/// catalogue profile for `zpl`/`epl` — the catalogue has exactly one profile
/// per language — and to none for `tspl`, which no shipped profile speaks: a
/// genuine gap, not a guess.
DeviceBinding? _inferLabelPrinterBinding(
  Map<String, dynamic>? blob,
  DeviceProfileCatalog catalog,
) {
  if (blob == null) return null;
  final language = blob['labelLanguage'] as String?;
  final protocol = switch (language) {
    'zpl' => DeviceProtocol.zpl,
    'epl' => DeviceProtocol.epl,
    // 'tspl', absent, or unrecognised: no catalogue profile speaks it (or
    // the fact is simply unknown) — either way nothing narrows to exactly
    // one profile below.
    _ => null,
  };
  if (protocol == null) return null;

  final matches = catalog
      .forClass(DeviceClass.labelPrinter)
      .where((p) => p.protocol == protocol)
      .toList(growable: false);
  // Refuses rather than guesses if the catalogue ever ships two profiles for
  // the same label language — not true today (one profile per language) but
  // this must not silently pick one if that changes.
  if (matches.length != 1) return null;
  final profileId = matches.single.id;

  final host = (blob['labelHost'] as String?)?.trim();
  final port = (blob['labelPort'] as num?)?.toInt();
  final widthMm = (blob['labelWidthMm'] as num?)?.toInt();
  final heightMm = (blob['labelHeightMm'] as num?)?.toInt();

  return _tryBuild(
    catalog,
    DeviceClass.labelPrinter,
    profileId,
    parameters: {
      if (host != null && host.isNotEmpty) 'ipAddress': host,
      if (port != null) 'port': port.toString(),
    },
    options: {
      if (widthMm != null) 'paperWidthMm': widthMm.toString(),
      if (heightMm != null) 'labelHeightMm': heightMm.toString(),
    },
  );
}

/// Scale — `scaleEnabled`/`scalePort`/`scaleBaudRate`/`scaleProtocol` (blob
/// only). Written directly by the pre-branch `hardware_settings_screen.dart`'s
/// own scale section — a different file from `HardwareSettingsProvider`, and
/// never covered by its sixteen-key model at all (see the blob-key inventory
/// at the top of this file).
///
/// **This never actually produces a binding today, and that is the honest,
/// checked-in answer, not an oversight.** `scaleProtocol == 'generic'` or
/// `'massaK'` has no catalogue profile at all. `scaleProtocol == 'cas'` DOES
/// have catalogue profiles — `scale.cas.pd2` and `scale.cas.er-plus` — but
/// both declare the same `defaultBaudRate` (9600), so `scaleBaudRate` cannot
/// tell them apart, and neither can `scalePort` (a COM port picks a wire,
/// not a model). The function is still called on every migration run,
/// rather than left out, so that the moment a distinguishing fact exists — a
/// specific model name added to the blob, or the catalogue narrowing to one
/// CAS profile — this starts producing bindings without anyone having to
/// remember it exists and wire it in.
DeviceBinding? _inferScaleBinding(
  Map<String, dynamic>? blob,
  DeviceProfileCatalog catalog,
) {
  if (blob == null) return null;
  if (!(blob['scaleEnabled'] as bool? ?? false)) return null;
  if ((blob['scaleProtocol'] as String?) != 'cas') {
    return null; // 'generic'/'massaK'/unset: no catalogue profile speaks it.
  }

  final port = (blob['scalePort'] as String?)?.trim();
  final baudRate = (blob['scaleBaudRate'] as num?)?.toInt();

  final profile = _narrowToUniqueProfile(catalog.forClass(DeviceClass.scale), [
    (p) => p.protocol == DeviceProtocol.casScale,
    baudRate == null
        ? null
        : (p) => p.capabilities.defaultBaudRate == baudRate,
  ]);
  // Both CAS profiles share a baud rate — see doc comment above. This is
  // expected to be null every time until the catalogue can distinguish them.
  if (profile == null) return null;

  return _tryBuild(
    catalog,
    DeviceClass.scale,
    profile.id,
    parameters: {if (port != null && port.isNotEmpty) 'comPort': port},
  );
}

/// Narrows [candidates] by every fact in [facts] that actually applies, and
/// refuses only if the survivors are still not unique once every applicable
/// fact has narrowed them — the general shape a "pick a profile from old
/// raw values" ladder should take (fix round 1, task-2-report.md concern:
/// "narrow candidates by every fact the source provides; refuse only if the
/// survivors are still not unique").
///
/// A `null` entry in [facts] means the source doesn't carry that fact at
/// all — it narrows nothing, which is different from "no candidate passes
/// it". This is what keeps the rule honest: an unknown fact must not be
/// treated as if it ruled everything out, and a known fact that leaves more
/// than one candidate standing must not be treated as if it picked one.
DeviceProfile? _narrowToUniqueProfile(
  List<DeviceProfile> candidates,
  Iterable<bool Function(DeviceProfile)?> facts,
) {
  var survivors = candidates;
  for (final fact in facts) {
    if (fact == null) continue;
    survivors = survivors.where(fact).toList(growable: false);
  }
  return survivors.length == 1 ? survivors.single : null;
}

/// Which *transport* old `PrinterConnectionType` value [connectionKind]
/// implies, expressed as a predicate over a profile's declared
/// `connectionParams` rather than its `protocol`.
///
/// **Why this is not a protocol check any more.** Before this fix, every
/// shipped receipt-printer profile spoke networked ESC/POS, so matching on
/// `DeviceProtocol.escPos` doubled as matching on "networked" by accident.
/// That stopped being true the moment USB, Bluetooth and serial ESC/POS
/// profiles were added (docs/system-architecture.md, section 8: ESC/POS is
/// one *protocol* running over four different *transports*) — every
/// receipt-printer profile in the catalogue now shares
/// `DeviceProtocol.escPos`, so a protocol comparison can no longer tell wifi
/// from usb at all. The transport is instead read off *which connection
/// parameter a profile declares*: a networked profile needs `ipAddress`, a
/// Bluetooth profile needs `macAddress`, a serial profile needs `comPort`,
/// and the USB/spooler profile needs none of those three (its own
/// `devicePath` parameter is optional).
///
/// An unrecognised [connectionKind] (a stored value no `PrinterConnectionType`
/// name matches) narrows the candidate set to nothing, the same "refuse
/// rather than guess" outcome as an unmatched profile — it must not be
/// treated as "this fact doesn't apply" (that is what passing `null` for
/// [connectionKind] itself means, one level up in
/// [resolveReceiptPrinterProfileId]).
bool Function(DeviceProfile) _transportPredicateForPrinterConnectionKind(
  String connectionKind,
) {
  bool hasParam(DeviceProfile p, String key) =>
      p.connectionParams.any((c) => c.key == key);

  return switch (connectionKind) {
    'wifi' => (p) => hasParam(p, 'ipAddress'),
    'bluetooth' => (p) => hasParam(p, 'macAddress'),
    'serial' => (p) => hasParam(p, 'comPort'),
    'usb' =>
      (p) =>
          !hasParam(p, 'ipAddress') &&
          !hasParam(p, 'macAddress') &&
          !hasParam(p, 'comPort'),
    _ => (_) => false,
  };
}

/// Picks a receipt-printer profile id, narrowing the catalogue's
/// `DeviceClass.receiptPrinter` candidates by every fact available: the
/// transport implied by the old connection kind (see
/// [_transportPredicateForPrinterConnectionKind]), then the paper width the
/// installation actually runs — `ThisPosEntries.paperWidth` is not just a
/// value to carry into the chosen binding, it is itself a discriminator
/// between profiles' supported widths, and refusing to use it because a
/// *different* fact was ambiguous would be throwing away information the
/// source has.
///
/// **This does not resolve every width, on any transport.**
/// `printer.escpos.80mm` and `printer.escpos.usb`/`printer.escpos.serial`
/// all support `[58, 80]`; only `printer.escpos.58mm-compact` and
/// `printer.escpos.bluetooth` support `[58]` alone. Width `80` narrows to
/// exactly one profile within a transport that has been narrowed already,
/// but width `58` never narrows anything on its own — the wider models also
/// run at 58mm. That is correctly still ambiguous under "narrow by every
/// fact, refuse only if still not unique": nothing in this migration's
/// sources says whether a 58mm-configured installation owns a dual-width
/// printer set to 58mm or a 58mm-only model, so no binding is created for
/// that value either — see task-2-report.md, fix round 1, for why the
/// original "58mm binds to the 58mm-compact profile" example could not be
/// implemented against the real catalogue without inventing a preference
/// rule nobody asked for. The same reasoning now also means **paper width
/// alone, with no connection kind at all, never narrows to a unique
/// profile** — every width the catalogue supports is now supported by more
/// than one transport's profile.
@visibleForTesting
String? resolveReceiptPrinterProfileId(
  DeviceProfileCatalog catalog, {
  String? connectionKind,
  int? paperWidthMm,
}) {
  final profile = _narrowToUniqueProfile(
    catalog.forClass(DeviceClass.receiptPrinter),
    [
      connectionKind == null
          ? null
          : _transportPredicateForPrinterConnectionKind(connectionKind),
      paperWidthMm == null
          ? null
          : (p) => p.capabilities.paperWidthsMm.contains(paperWidthMm),
    ],
  );
  return profile?.id;
}

/// Converts the character-count paper width the product actually stores
/// (`ThisPosEntries.paperWidth` / `PosConfigInfo.paperWidth` — always `32`,
/// `42` or `48`, never a millimetre value) into the millimetre width the
/// printer catalogue's `DeviceCapabilities.paperWidthsMm` is expressed in.
///
/// **Second-fix-round finding, the one that mattered.** This conversion did
/// not exist at all until now: [resolveReceiptPrinterProfileId] compared the
/// raw character count directly against `paperWidthsMm` (`[58, 80]`, ...),
/// so the predicate emptied the candidate set for every value the product
/// can actually hold (`32`/`42`/`48` never appear in any profile's
/// millimetre list) — the receipt-printer profile never resolved on any
/// configured till, upgrading or freshly wizarded, regardless of transport.
/// The two tests that were supposed to certify the USB/Bluetooth/serial fix
/// passed only because they injected impossible values (`58`/`80`) straight
/// into `PosConfigInfo.paperWidth`/`ThisPosEntries.paperWidth` instead of the
/// character counts those fields actually hold.
///
/// The mapping itself already existed, once, at
/// `lib/data/setup/setup_repository_local.dart` (used only for seeding the
/// default receipt template's width) — reused here rather than re-derived,
/// so the rule is written in exactly one place.
int paperWidthMmFromCharWidth(int charWidth) => charWidth >= 42 ? 80 : 58;

/// Receipt printer — prefers the blob's own `receiptPrinterType`/
/// `receiptPrinterAddress`/`receiptPrinterPort` (written directly by
/// `printer_settings_screen.dart`'s pre-branch `_saveSettings`, live on any
/// till that ever opened that screen) over the v26 `Terminals.printerType`/
/// `.printerAddress` columns (written only by the HTTP route, `null` on any
/// till that never had a browser terminal) — see the blob-key inventory at
/// the top of this file for the finding this corrects.
DeviceBinding? _inferReceiptPrinterBinding(
  Map<String, dynamic>? blob,
  LegacyDeviceSettings legacy,
  DeviceProfileCatalog catalog,
) {
  final connectionKind =
      (blob?['receiptPrinterType'] as String?) ?? legacy.terminalPrinterType;
  // The one conversion point: everything downstream of this line deals only
  // in millimetres, matching what DeviceCapabilities.paperWidthsMm declares.
  final paperWidthMm = legacy.thisPosPaperWidthChars == null
      ? null
      : paperWidthMmFromCharWidth(legacy.thisPosPaperWidthChars!);
  final profileId = resolveReceiptPrinterProfileId(
    catalog,
    connectionKind: connectionKind,
    paperWidthMm: paperWidthMm,
  );
  if (profileId == null) return null;

  final address =
      (blob?['receiptPrinterAddress'] as String?) ?? legacy.terminalPrinterAddress;
  final port = (blob?['receiptPrinterPort'] as num?)?.toInt();

  return _buildReceiptPrinterBinding(
    catalog: catalog,
    profileId: profileId,
    connectionKind: connectionKind,
    address: address,
    printerPort: port,
    paperWidthMm: paperWidthMm,
  );
}

/// Maps [address] to the connection-parameter key [connectionKind]'s
/// transport actually declares — `ipAddress` for wifi, `macAddress` for
/// Bluetooth, `comPort` for serial, `devicePath` for usb/spooler — and
/// `ThisPosEntries.paperWidth`/the blob's `labelWidthMm`-equivalent to the
/// profile's `paperWidthMm` option, for a [profileId] already chosen by
/// [resolveReceiptPrinterProfileId]. Also exposed directly for testing
/// (`buildReceiptPrinterBindingForTesting`) so the option/parameter mapping
/// can be proven independently of whichever profile a given scenario's
/// facts happen to narrow to.
///
/// An unrecognised or absent [connectionKind] maps [address] to no
/// parameter at all rather than guessing a key — the profile's own
/// `validateAgainst` would refuse an unrecognised key anyway, but the point
/// here is that nothing upstream can say which key is *right*, and guessing
/// one is exactly the class of defect this whole plan exists to remove.
DeviceBinding? _buildReceiptPrinterBinding({
  required DeviceProfileCatalog catalog,
  required String profileId,
  String? connectionKind,
  String? address,
  int? printerPort,
  int? paperWidthMm,
}) {
  final parameters = <String, String>{};
  if (address != null && address.isNotEmpty) {
    switch (connectionKind) {
      case 'wifi':
        parameters['ipAddress'] = address;
      case 'bluetooth':
        parameters['macAddress'] = address;
      case 'serial':
        parameters['comPort'] = address;
      case 'usb':
        parameters['devicePath'] = address;
      default:
        break;
    }
  }
  if (connectionKind == 'wifi' && printerPort != null) {
    parameters['port'] = printerPort.toString();
  }

  return _tryBuild(
    catalog,
    DeviceClass.receiptPrinter,
    profileId,
    parameters: parameters,
    options: {
      if (paperWidthMm != null) 'paperWidthMm': paperWidthMm.toString(),
    },
  );
}

/// Test-only entry point for [_buildReceiptPrinterBinding] — see that
/// function's doc comment for why it needs one.
@visibleForTesting
DeviceBinding? buildReceiptPrinterBindingForTesting({
  required DeviceProfileCatalog catalog,
  required String profileId,
  String? connectionKind,
  String? address,
  int? printerPort,
  int? paperWidthMm,
}) => _buildReceiptPrinterBinding(
  catalog: catalog,
  profileId: profileId,
  connectionKind: connectionKind,
  address: address,
  printerPort: printerPort,
  paperWidthMm: paperWidthMm,
);
