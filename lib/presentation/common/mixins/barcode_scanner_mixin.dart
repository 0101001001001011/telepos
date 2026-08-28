import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:meta/meta.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/device/terminal_device_binding_resolver.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/repositories/scanner_rules_repository.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';

/// The three ways a barcode scanner reaches this app, from
/// [BarcodeScannerMixin]'s point of view. Used to decide *whether* this
/// mixin attaches its own keyboard handler — `serialPort` and `camera` are
/// deliberately not implemented by this mixin at all (see
/// [BarcodeScannerMixin._attachIfKeyboardWedge]); they exist here only so
/// `_loadScannerSettings` can name the mode it found without pretending it
/// is `keyboardWedge`.
///
/// Moved here (task 5(c), plan 2b, fix round 1) from the now-deleted
/// `lib/hardware/scanner/barcode_scanner_service.dart` — that file's
/// `BarcodeScannerService` class was a second, parallel implementation of
/// the same keyboard-wedge decoding this mixin does, registered in GetIt but
/// never started by any production code path (confirmed: no call site
/// anywhere called `getIt<BarcodeScannerService>()`), while this mixin is
/// the actual live path six real screens attach to
/// (`sale_screen.dart`, `movement_screen.dart`, `movement_dialog.dart`,
/// `supply_form.dart`, `supplier_return_screen.dart`,
/// `supplier_return_dialog.dart`). Deleted rather than merged into: its
/// serial-port scanning code (`SerialPort`/`SerialPortReader`) was never
/// reachable either — `_attachIfKeyboardWedge` below returns early for any
/// mode other than `keyboardWedge`, so a `serialPort`-mode binding has
/// always been a dead end here too, in both implementations, before and
/// after this change. Deleting the unused class does not remove any
/// capability that was ever live; real serial-port barcode scanning remains
/// a separate, pre-existing, still-open gap.
enum ScannerMode { keyboardWedge, serialPort, camera }

mixin BarcodeScannerMixin {
  final _barcodeBuffer = StringBuffer();
  DateTime _lastKeyTime = DateTime.now();

  // Taken from the domain contract rather than declared here (plan 2b, task
  // 3): the settings screen that now *writes* these three rules shows the
  // same numbers as "по умолчанию" when a field is left blank, and two
  // copies of a default is exactly how the number an operator is shown
  // drifts away from the number the decoder uses.
  static const _defaultScannerMaxGapMs = ScannerRules.defaultScannerTimeoutMs;

  static const _defaultMinBarcodeLength = ScannerRules.defaultBarcodeMinLength;

  static const _defaultMaxBarcodeLength = ScannerRules.defaultBarcodeMaxLength;

  int _scannerMaxGapMs = _defaultScannerMaxGapMs;
  int _minBarcodeLength = _defaultMinBarcodeLength;
  int _maxBarcodeLength = _defaultMaxBarcodeLength;

  /// Test-only window into the resolved gap — [_scannerMaxGapMs] is private
  /// state with no other way to prove [_loadScannerSettings] actually wired
  /// `ThisPosEntries.scannerTimeoutMs` through to the live keyboard-wedge
  /// decoder. Not read by any production code.
  @visibleForTesting
  int get debugScannerMaxGapMs => _scannerMaxGapMs;

  void onBarcodeScanned(String barcode);

  /// Fire-and-forget on purpose: the previous, blob-backed version decided
  /// synchronously, but resolving a terminal's device binding is
  /// necessarily async (`TerminalRepository.self()`). Callers
  /// (`initState()` across several screens) call this synchronously and do
  /// not await it — the keyboard handler attaches a tick later than before,
  /// which nothing here depends on.
  void initBarcodeScanner() {
    unawaited(_attachIfKeyboardWedge());
  }

  Future<void> _attachIfKeyboardWedge() async {
    final mode = await _loadScannerSettings();
    if (mode != ScannerMode.keyboardWedge) return;
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  void disposeBarcodeScanner() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
  }

  /// Scanner mode from **this terminal's** scanner `DeviceBinding`
  /// (docs/system-architecture.md, section 8, И27), and the barcode length
  /// bounds plus the inter-character timeout from `ThisPosEntries` — all
  /// three are business rules about the value read, not device settings
  /// (И142): `barcodeMinLength`/`barcodeMaxLength` migrated there by schema
  /// v27, `scannerTimeoutMs` by schema v28 (task 5(c), plan 2b). None comes
  /// from the old installation-wide `hardware_settings` blob any more (plan
  /// 2, task 3) — that blob's `scannerTimeout` key is carried forward into
  /// `scannerTimeoutMs` once, by the v28 migration step itself
  /// (`lib/data/database/migrations/device_binding_migration.dart`'s
  /// `migrateLegacyScannerTimeoutMs`), not read from here.
  ///
  /// **Fix round 1 correction:** this mixin used to leave
  /// [_scannerMaxGapMs] at its fixed default forever, on the reasoning that
  /// a separate `BarcodeScannerService` was "the tested, wired reader" for
  /// `scannerTimeoutMs`. That was backwards — this mixin is the only
  /// implementation six real screens actually attach to (see [ScannerMode]'s
  /// doc comment for the full reasoning and why `BarcodeScannerService` is
  /// deleted, not merged into). [_scannerMaxGapMs] is now assigned here,
  /// the same way [_minBarcodeLength]/[_maxBarcodeLength] already were.
  Future<ScannerMode> _loadScannerSettings() async {
    try {
      if (!GetIt.I.isRegistered<AppDatabase>()) {
        return ScannerMode.keyboardWedge;
      }
      final db = GetIt.I<AppDatabase>();
      final pos = await db.thisPosDao.get();
      _minBarcodeLength = pos?.barcodeMinLength ?? _defaultMinBarcodeLength;
      _maxBarcodeLength = pos?.barcodeMaxLength ?? _defaultMaxBarcodeLength;
      _scannerMaxGapMs = pos?.scannerTimeoutMs ?? _defaultScannerMaxGapMs;

      if (!GetIt.I.isRegistered<TerminalRepository>()) {
        return ScannerMode.keyboardWedge;
      }
      final terminal = await GetIt.I<TerminalRepository>().self();
      final bindings = await resolveTerminalDeviceBindings(
        database: db,
        terminalId: terminal.id,
        catalog: BuiltinDeviceProfileCatalog(),
        deviceClass: DeviceClass.scanner,
      );
      if (bindings.length != 1) return ScannerMode.keyboardWedge;

      final profile = BuiltinDeviceProfileCatalog().byId(
        bindings.single.profileId,
      );
      return switch (profile?.protocol) {
        DeviceProtocol.serialScanner => ScannerMode.serialPort,
        DeviceProtocol.cameraScan => ScannerMode.camera,
        _ => ScannerMode.keyboardWedge,
      };
    } catch (_) {
      return ScannerMode.keyboardWedge;
    }
  }

  bool _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final now = DateTime.now();
    final gap = now.difference(_lastKeyTime).inMilliseconds;
    _lastKeyTime = now;

    if (gap > _scannerMaxGapMs && _barcodeBuffer.isNotEmpty) {
      _barcodeBuffer.clear();
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final barcode = _barcodeBuffer.toString();
      _barcodeBuffer.clear();

      if (barcode.length >= _minBarcodeLength &&
          barcode.length <= _maxBarcodeLength) {
        onBarcodeScanned(barcode);
        return true;
      }
      return false;
    }

    final char = event.character;
    if (char != null && RegExp(r'\d').hasMatch(char)) {
      _barcodeBuffer.write(char);
    }

    return false;
  }
}
