import 'dart:typed_data';

import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/domain/device/device_check.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/hardware/cash_drawer/cash_drawer_service.dart';
import 'package:telepos/hardware/label_printer/label_printer_service.dart';
import 'package:telepos/hardware/printer/print_utility.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';
import 'package:telepos/hardware/scales/scales_service.dart';

/// Builds the driver a check talks to from the binding **as stored right
/// now** — never from a driver captured when the process started.
///
/// In production every one of these is one of `hardware_module.dart`'s
/// `build*` functions (`lib/app/di/service_locator.dart`), the very same
/// functions its own lazy singletons are built from: one definition of "how
/// do I reach this device", two callers, no parallel path.
typedef DeviceDriverBuilder<T> = T Function(DeviceBinding binding);

/// One driver the running app already holds, and the binding it was built
/// from.
///
/// [resolve] is a callback rather than the instance itself because the live
/// drivers are `registerLazySingleton`s: asking for one *constructs* it. A
/// check whose binding has changed must not bring the old driver into
/// existence merely to decide it cannot use it.
class LiveDriver<T> {
  const LiveDriver({required this.binding, required this.resolve});

  /// The binding this driver was built from, captured when the DI graph was
  /// registered. Never updated afterwards — that staleness is the whole
  /// reason [DeviceCheckLocal] builds its own driver when it differs.
  final DeviceBinding binding;

  final T Function() resolve;
}

/// The drivers the running app already holds, per class.
///
/// Every field may be `null`: the class has no live driver in this build (the
/// receipt printer is not registered at all when nothing is bound), or the
/// live one was built from no binding, in which case there is nothing to
/// compare against and the check always builds its own.
class LiveDeviceDrivers {
  const LiveDeviceDrivers({
    this.receiptPrinter,
    this.labelPrinter,
    this.cashDrawer,
    this.scales,
  });

  final LiveDriver<PrinterManager>? receiptPrinter;
  final LiveDriver<LabelPrinterService>? labelPrinter;
  final LiveDriver<CashDrawerService>? cashDrawer;
  final LiveDriver<ScalesService>? scales;
}

/// Wraps whatever already exists in `lib/hardware/` — plan 2b, task 2's
/// answer to section 8's "проверка... с видимым результатом".
///
/// **Finding I2 (final-fix round): the check now tests the saved binding.**
/// Before this fix, this class was handed the already-resolved driver
/// singletons, and every one of those is a `registerLazySingleton` closure in
/// `hardware_module.dart` that captured the binding list resolved **once, at
/// startup** (`hardware_module.dart`'s `registerHardwareServices`). So an
/// operator who changed a scale's `comPort` from COM3 to COM5, saved, and
/// pressed «проверить» got a check against COM3 — and could be told `ok` for
/// a configuration that does not work. A green answer for a wrong setting is
/// the worst answer this contract can give, and the on-screen notice promised
/// the opposite.
///
/// The fix keeps the rule the previous comment here was protecting — this
/// class still does not know how to turn parameters into a driver, because
/// duplicating `hardware_module.dart`'s transport detection would be a
/// second, parallel path to the same driver (plan 2's "Уроки планов 1 и 2")
/// — but inverts *when* that knowledge runs. Instead of an instance, this
/// class is handed a [DeviceDriverBuilder] per class, and calls it with the
/// binding it just read and validated. `hardware_module.dart` exports the
/// same builders its own singletons use, so there is still exactly one place
/// that decides how to reach a device.
///
/// A `null` builder still means [DeviceCheckReason.driverNotLive] — "this
/// build cannot construct a driver of this class at all" — never a fabricated
/// success or a false "connection failed".
///
/// **What this buys, beyond correctness.** A check of a binding the operator
/// has just *changed* now builds and drives its own driver, so it neither
/// touches nor reconfigures the one the sale path is using — the case where
/// the two are genuinely different devices is now genuinely separate.
///
/// **What it cost, and how that is now paid (final-fix round 2).** Building a
/// rival driver introduced the opposite of the defect it fixed. When the
/// binding has *not* changed, the driver built here points at the same
/// physical endpoint as the live one, and some endpoints admit only one
/// client — a network ESC/POS printer on port 9100, an exclusive serial port.
/// With the live driver holding that endpoint open (the receipt
/// [PrinterManager] connects on the first print and stays connected), the
/// check's own connect is refused, and the operator is told
/// [DeviceCheckReason.connectionFailed] about a printer that works. That is
/// the same false failure on working hardware this whole contract was written
/// to remove, arriving from the other side: before, the check could say `ok`
/// about a configuration that does not work; after, it could say
/// `connectionFailed` about one that does. Neither is worth pressing.
///
/// So the driver is chosen, not unconditionally built. Given [LiveDeviceDrivers]
/// — the drivers the app already holds and the bindings they were built from
/// — this borrows the live driver when the saved binding still
/// `describesSameDeviceAs` the one it was built from, and builds a fresh one
/// only when they differ, which is exactly the case finding I2 existed to
/// fix. There is never a second connection to an endpoint the app is already
/// holding.
///
/// Borrowed or built, the rule afterwards is the same and is the one
/// [_checkScale] already followed: **leave the driver exactly as this call
/// found it.** A driver this check connected is disconnected again before it
/// returns; a live driver that was already connected is left connected, so a
/// diagnostic press never tears down the connection a sale is about to print
/// over. For a freshly built driver "was it already connected" is always
/// false, so that single rule covers both cases with no ownership flag.
///
/// **What borrowing costs, recorded as honestly as the cost it replaces.**
/// When the binding is unchanged the check drives the app-lifetime
/// [PrinterManager] again, and `PrintUtility.testPrint` calls `initialize()`
/// on it (`print_utility.dart:144`) before printing its page. A test page
/// requested in the middle of a sale receipt can therefore interleave with
/// it. That is inherent to one printer being asked to print two things at
/// once — the test page would queue behind or between the sale's bytes no
/// matter which object issued it — and it is the smaller harm: a smudged
/// diagnostic page an operator is standing in front of, against a wrong
/// `connectionFailed` about hardware that works, which sends them to
/// re-cable a healthy printer. Not hidden, and reachable only while a sale is
/// mid-print.
///
/// **Still open, and deliberately not fixed here: the check is correct, the
/// sale path is not.** `HardwareModule` resolves its singletons once, at
/// startup, so after an operator saves a changed binding, *sales* keep
/// printing to the old device until the app is restarted — this class is now
/// the only thing that reads the change immediately. So "the check passed and
/// printing still goes to the old printer" is a state a real operator can
/// reach. The on-screen notice says a restart is needed, so nothing lies, but
/// the honest fix is to re-resolve `HardwareModule` on save, and that is not
/// in this class's reach. Recorded rather than hidden.
///
/// **Fix round 1** added [_catalog]: `forTerminal` alone does not validate a
/// binding (`LocalDeviceBindingRepository.forTerminal` reads rows as-is —
/// only `save` validates, and a profile a saved binding relies on can be
/// edited or removed afterwards by И124's catalog editor), so a binding this
/// class previously treated as unconditionally "configured" could actually
/// be stale and invalid. See [check]'s body for what changes as a result.
class DeviceCheckLocal implements DeviceCheck {
  DeviceCheckLocal({
    required DeviceBindingRepository bindingRepository,
    required DeviceProfileCatalog catalog,
    DeviceDriverBuilder<PrinterManager>? receiptPrinterFor,
    DeviceDriverBuilder<LabelPrinterService>? labelPrinterFor,
    DeviceDriverBuilder<CashDrawerService>? cashDrawerFor,
    DeviceDriverBuilder<ScalesService>? scalesFor,
    LiveDeviceDrivers live = const LiveDeviceDrivers(),
  }) : _bindingRepository = bindingRepository,
       _catalog = catalog,
       _receiptPrinterFor = receiptPrinterFor,
       _labelPrinterFor = labelPrinterFor,
       _cashDrawerFor = cashDrawerFor,
       _scalesFor = scalesFor,
       _live = live;

  final DeviceBindingRepository _bindingRepository;

  final DeviceProfileCatalog _catalog;

  /// `null` when this build has no way to construct a receipt-printer driver
  /// at all. A check requested against this class then reports
  /// [DeviceCheckReason.driverNotLive], never a fabricated success or a false
  /// "connection failed".
  final DeviceDriverBuilder<PrinterManager>? _receiptPrinterFor;

  final DeviceDriverBuilder<LabelPrinterService>? _labelPrinterFor;

  final DeviceDriverBuilder<CashDrawerService>? _cashDrawerFor;

  final DeviceDriverBuilder<ScalesService>? _scalesFor;

  /// Empty by default, which means "build a fresh driver every time" — the
  /// behaviour before this mitigation, and the right default for a test that
  /// has not said otherwise. Production supplies a populated one from
  /// `service_locator.dart`.
  final LiveDeviceDrivers _live;

  /// The driver to talk to for [binding]: the live one when it was built from
  /// a binding describing the same device, a fresh one otherwise.
  ///
  /// [live] is consulted before [build] is called, and [LiveDriver.resolve] is
  /// only invoked once the bindings have already matched — a check of a
  /// *changed* binding must not construct the stale live singleton merely to
  /// reject it.
  static T _driverFor<T>(
    DeviceDriverBuilder<T> build,
    LiveDriver<T>? live,
    DeviceBinding binding,
  ) {
    if (live != null && live.binding.describesSameDeviceAs(binding)) {
      return live.resolve();
    }
    return build(binding);
  }

  @override
  Future<DeviceCheckOutcome> check({
    required int terminalId,
    required DeviceClass deviceClass,
  }) async {
    final List<DeviceBinding> bindings;
    try {
      bindings = await _bindingRepository.forTerminal(terminalId);
    } catch (e) {
      // Reading the binding itself failed (e.g. a database error) — this is
      // not "not configured", it is "we could not find out", so it is
      // reported as unexpectedError rather than silently treated as absent.
      return DeviceCheckOutcome.unexpectedError(
        'Не удалось прочитать привязки устройств терминала: ${safeErrorText(e)}',
      );
    }

    // A binding this terminal cannot use unambiguously — none, or more than
    // one enabled binding of the same class — is treated the same way
    // hardware_module.dart's own _resolveSingleBinding treats it: refusing
    // to guess is the safe choice (И30), so both collapse to "not
    // configured" rather than one of them being reported as a failure. An
    // unknown terminalId produces the same empty list from the repository
    // and is deliberately not distinguished — see [DeviceCheck.check]'s doc
    // comment.
    final binding = singleEnabledBindingOfClass(bindings, deviceClass);
    if (binding == null) {
      return DeviceCheckOutcome.notConfigured(deviceClass);
    }

    // `forTerminal` does not validate (only `save` does — see this class's
    // doc comment), and the profile a binding names can be edited or removed
    // after the binding was saved. A binding that would now fail
    // `validateAgainst` is a real, distinct state — "configured wrong", not
    // "not configured" and not "the device refused" — so it is reported
    // before any hardware is touched at all.
    try {
      binding.validateAgainst(_catalog);
    } on ArgumentError catch (e) {
      return DeviceCheckOutcome.invalidBinding(deviceClass, '${e.message}');
    }

    try {
      return await switch (deviceClass) {
        DeviceClass.receiptPrinter => _checkReceiptPrinter(binding),
        DeviceClass.labelPrinter => _checkLabelPrinter(binding),
        DeviceClass.cashDrawer => _checkCashDrawer(binding, bindings),
        DeviceClass.scale => _checkScale(binding),
        DeviceClass.scanner ||
        DeviceClass.customerDisplay ||
        DeviceClass.paymentTerminal => Future.value(
          DeviceCheckOutcome.notImplemented(deviceClass),
        ),
      };
    } catch (e) {
      // Every named hardware operation below already catches its own
      // exceptions and returns a typed result — but a driver this class was
      // handed by its caller (or a test double) is not obligated to, and a
      // settings screen must not crash because a port was busy either way
      // (И30). Nothing above this line may throw past here uncaught.
      return DeviceCheckOutcome.unexpectedError(
        'Непредвиденная ошибка при проверке устройства: ${safeErrorText(e)}',
      );
    }
  }

  /// Uses `PrintUtility.testPrint` (`lib/hardware/printer/print_utility.dart:130`)
  /// rather than `ReceiptPrinter.printTest`
  /// (`lib/hardware/printer/receipt_printer.dart:96`) — both exist and both
  /// do the same job (connect if needed, print a test page), but neither is
  /// on the live receipt-printing path today: `ReceiptPrintServiceImpl`
  /// (`lib/data/services/receipt_print_service_impl.dart`) talks to
  /// [PrinterManager] directly through its own `ReceiptBuilder`, and its
  /// settings-screen "test print" instead prints a full sample sale receipt.
  /// `PrintUtility.testPrint` needs only a bare [PrinterManager] — no
  /// [ReceiptPrinter]'s profile/settings collaborators — so it is the
  /// smaller dependency for this class. See task-2-report.md for this
  /// measured discrepancy.
  ///
  /// **Fix round 1:** the connect step is now done here, not left to
  /// `PrintUtility.testPrint`'s own internal connect-or-skip — the two
  /// halves of that call were previously indistinguishable from outside (a
  /// failed connect and a failed print both came back as one
  /// `TestPrintResult.error`, so [DeviceCheckReason.connectionFailed] could
  /// never actually be produced). Connecting here first, and only then
  /// calling `testPrint` (which sees `printer.isConnected == true` and skips
  /// its own connect branch entirely), makes the two real, distinct
  /// [PrinterConnectionResult] and print-phase results separately visible.
  ///
  /// **Finding I2, and its round-2 mitigation:** the [PrinterManager] comes
  /// from [_driverFor] — the app's live one when [binding] still describes the
  /// device that one was built from, a fresh instance built from [binding]
  /// when it does not. Either way this leaves the connection as it found it,
  /// so a check never closes a printer the sale path had open and never opens
  /// a second socket to one it is already holding.
  Future<DeviceCheckOutcome> _checkReceiptPrinter(DeviceBinding binding) async {
    final build = _receiptPrinterFor;
    if (build == null) {
      return DeviceCheckOutcome.driverNotLive(DeviceClass.receiptPrinter);
    }
    final printer = _driverFor(build, _live.receiptPrinter, binding);

    final wasAlreadyConnected = printer.isConnected;
    try {
      if (!wasAlreadyConnected) {
        final connectResult = await printer.connect();
        if (!connectResult.success) {
          return DeviceCheckOutcome.connectionFailed(
            connectResult.errorMessage ??
                'Не удалось подключиться к принтеру чеков',
          );
        }
      }

      final result = await PrintUtility.testPrint(printer);
      if (result.success) {
        return DeviceCheckOutcome.ok(
          'Пробный чек напечатан (${result.bytesSent ?? 0} байт)',
        );
      }
      return DeviceCheckOutcome.deviceRefused(
        result.errorMessage ?? 'Печать пробного чека не удалась',
      );
    } finally {
      // Leave it as we found it. A freshly built driver is never already
      // connected, so this always closes one this check opened; a live driver
      // the sale path had already connected is left alone.
      if (!wasAlreadyConnected) await printer.disconnect();
    }
  }

  /// **Fix round 2:** same structural fix as [_checkReceiptPrinter], applied
  /// for the same reason. `LabelPrinterService.printTestLabel` (via
  /// `printPriceLabel`) folds "not connected, and connecting failed" and
  /// "connected, but sending failed" into calls that return the same
  /// `LabelPrintResult` type — but unlike `CashDrawerService.open()`, the two
  /// phases are genuinely, structurally separate here: `connect()` is public,
  /// returns its own `LabelPrintResult`, and `printPriceLabel` only calls it
  /// when `!isConnected`. So the same fix transfers: connect here first, and
  /// only then call `printTestLabel` (which sees `isConnected == true` and
  /// skips its own connect branch), making [DeviceCheckReason.connectionFailed]
  /// reachable for label printers too, not just receipt printers.
  Future<DeviceCheckOutcome> _checkLabelPrinter(DeviceBinding binding) async {
    final build = _labelPrinterFor;
    if (build == null) {
      return DeviceCheckOutcome.driverNotLive(DeviceClass.labelPrinter);
    }
    final printer = _driverFor(build, _live.labelPrinter, binding);

    final wasAlreadyConnected = printer.isConnected;
    try {
      if (!wasAlreadyConnected) {
        final connectResult = await printer.connect();
        if (!connectResult.success) {
          return DeviceCheckOutcome.connectionFailed(
            connectResult.errorMessage ??
                'Не удалось подключиться к принтеру этикеток',
          );
        }
      }

      final result = await printer.printTestLabel();
      if (result.success) {
        return DeviceCheckOutcome.ok('Пробная этикетка напечатана');
      }
      return DeviceCheckOutcome.deviceRefused(
        result.errorMessage ?? 'Печать пробной этикетки не удалась',
      );
    } finally {
      if (!wasAlreadyConnected) await printer.disconnect();
    }
  }

  /// `printer_manager.dart:217`'s `openCashDrawer()` — measured, and turns
  /// out to return `Future<void>`, not a result: it cannot carry a reason
  /// and is not usable as this contract's driver. `cash_drawer_service.dart:52`'s
  /// `CashDrawerService.open()` is what actually returns [CashDrawerResult]
  /// with a reason, so that is what this wraps. When the bound drawer rides
  /// the receipt printer (`CashDrawerMode.viaPrinter`), `open()` needs a
  /// `viaPrinter` callback to actually push the kick command anywhere — wired
  /// here to [_receiptPrinter] when one is available, so the common
  /// "drawer.rj11.via-printer" profile gets a real check instead of an
  /// automatic "printer not connected" every time.
  ///
  /// **Fix round 1:** a via-printer drawer with no live printer driver is
  /// [DeviceCheckReason.driverNotLive], checked before calling `open()` at
  /// all — letting it fall through to `open()`'s own generic "Принтер не
  /// подключен" would have reported the same false "connection failed" the
  /// critical finding raised for the printer itself, just one layer removed.
  /// `CashDrawerResult.notSupported` (platform has no drawer support at all)
  /// is now surfaced as [DeviceCheckReason.notSupportedOnPlatform] rather
  /// than being silently folded into "device refused" — it was the one
  /// three-way hardware reason available and was previously discarded.
  /// [DeviceCheckReason.connectionFailed] is deliberately not attempted here:
  /// `CashDrawerService.open()`'s own try/catch does not preserve "the port
  /// failed to open" separately from "the pulse command failed" — inventing
  /// that split by matching on its exception text would be exactly the
  /// plausible-wrong-value class this project keeps getting bitten by, so a
  /// real, attempted-but-failed drawer open is reported as
  /// [DeviceCheckReason.deviceRefused], honestly, rather than a guessed
  /// [DeviceCheckReason.connectionFailed].
  ///
  /// **Finding I2:** both drivers come from [_driverFor] — the drawer for
  /// [binding], and, for a `viaPrinter` drawer, the receipt printer for the
  /// terminal's *own* receipt-printer binding found in [allBindings] (the
  /// kick command rides that printer's channel, so it is that binding's
  /// parameters that decide where it goes). A `viaPrinter` drawer on a
  /// terminal with no receipt-printer binding is [DeviceCheckReason.driverNotLive]:
  /// there is no channel to send the kick down, and saying "the drawer
  /// refused" would send the operator to look at the wrong device.
  ///
  /// The printer channel is connected before `open()` rather than left to
  /// fail inside it — letting `writeRaw` answer "Принтер не подключен" would
  /// report a real, distinct connection failure as a drawer refusal. Round 2:
  /// it is disconnected afterwards only if this check is what opened it, so a
  /// drawer test no longer drops a live printer connection on the floor.
  /// A standalone (serial) drawer benefits from borrowing in its own right —
  /// two `CashDrawerService`s opening the same COM port is precisely the
  /// second-client refusal the mitigation exists for.
  Future<DeviceCheckOutcome> _checkCashDrawer(
    DeviceBinding binding,
    List<DeviceBinding> allBindings,
  ) async {
    final buildDrawer = _cashDrawerFor;
    if (buildDrawer == null) {
      return DeviceCheckOutcome.driverNotLive(DeviceClass.cashDrawer);
    }
    final drawer = _driverFor(buildDrawer, _live.cashDrawer, binding);

    PrinterManager? printer;
    var printerWasAlreadyConnected = false;
    if (drawer.mode == CashDrawerMode.viaPrinter) {
      final buildPrinter = _receiptPrinterFor;
      final printerBinding = singleEnabledBindingOfClass(
        allBindings,
        DeviceClass.receiptPrinter,
      );
      if (buildPrinter == null || printerBinding == null) {
        return DeviceCheckOutcome.driverNotLive(DeviceClass.cashDrawer);
      }
      final channelPrinter = _driverFor(
        buildPrinter,
        _live.receiptPrinter,
        printerBinding,
      );
      printer = channelPrinter;

      printerWasAlreadyConnected = channelPrinter.isConnected;
      if (!printerWasAlreadyConnected) {
        final connectResult = await channelPrinter.connect();
        if (!connectResult.success) {
          await channelPrinter.disconnect();
          return DeviceCheckOutcome.connectionFailed(
            connectResult.errorMessage ??
                'Не удалось подключиться к принтеру чеков, через который '
                    'открывается денежный ящик',
          );
        }
      }
    }

    final channel = printer;
    final closeChannel = !printerWasAlreadyConnected;
    try {
      final result = await drawer.open(
        viaPrinter: channel == null
            ? null
            : (data) async {
                final printResult = await channel.writeRaw(
                  Uint8List.fromList(data),
                );
                if (!printResult.success) {
                  throw Exception(
                    printResult.errorMessage ??
                        'Не удалось отправить команду открытия ящика',
                  );
                }
              },
      );

      if (result.success) {
        return DeviceCheckOutcome.ok('Денежный ящик открыт');
      }
      if (result.notSupported) {
        return DeviceCheckOutcome.notSupportedOnPlatform(
          result.errorMessage ??
              'Денежный ящик не поддерживается на этой платформе',
        );
      }
      return DeviceCheckOutcome.deviceRefused(
        result.errorMessage ?? 'Не удалось открыть денежный ящик',
      );
    } finally {
      if (closeChannel) await channel?.disconnect();
    }
  }

  /// **Fix round 1:** leaves the scale exactly as this call found it. If the
  /// scale was already connected, this never disconnects it. If *this* call
  /// is what opened the connection, it closes it again afterwards — a
  /// diagnostic button press must not leave a serial port open and a
  /// polling `Timer` running for the rest of the process's life every time
  /// someone presses "check".
  ///
  /// **Task 3: an empty platform is not a broken scale.**
  /// `ScalesService.requestWeight` waits for a reading with `isStable` set,
  /// and returns `ScalesReading.error('Таймаут ожидания стабильного веса')`
  /// if none arrives in time. On plenty of healthy scales nothing ever
  /// stabilises with nothing on the platform, so the previous version told
  /// an operator checking an idle scale that the device had refused — the
  /// single most likely way this button was ever pressed, answered with a
  /// fault. The fix is structural, not a string match on the driver's error
  /// text (which is the plausible-wrong-value shape [_checkCashDrawer]'s
  /// comment refuses for the same reason): this listens to
  /// `ScalesService.weightStream` for the whole window, so it knows
  /// separately whether the scale was *talking at all*.
  ///
  /// Three outcomes, not two:
  /// - a stable reading — success, with the weight;
  /// - no stable reading but readings arriving — success, saying the scale
  ///   answers and the weight has not settled, which is what an unloaded
  ///   platform looks like;
  /// - nothing at all for the whole window — [DeviceCheckReason.deviceRefused],
  ///   still honest, and now actually meaning it.
  Future<DeviceCheckOutcome> _checkScale(DeviceBinding binding) async {
    final build = _scalesFor;
    if (build == null) {
      return DeviceCheckOutcome.driverNotLive(DeviceClass.scale);
    }
    final scale = _driverFor(build, _live.scales, binding);

    final wasAlreadyConnected = scale.isConnected;
    if (!wasAlreadyConnected) {
      final connectResult = await scale.connect();
      if (!connectResult.success) {
        return DeviceCheckOutcome.connectionFailed(
          connectResult.errorMessage ?? 'Не удалось подключиться к весам',
        );
      }
    }

    final heard = <ScalesReading>[];
    final subscription = scale.weightStream.listen(
      (reading) {
        if (!reading.hasError) heard.add(reading);
      },
      onError: (Object _) {},
    );

    try {
      final reading = await scale.requestWeight(
        timeout: const Duration(seconds: 5),
      );
      if (!reading.hasError) {
        return DeviceCheckOutcome.ok('Вес на весах: ${reading.weightKg} кг');
      }
      if (heard.isNotEmpty) {
        return DeviceCheckOutcome.ok(
          'Весы отвечают. Устойчивый вес за 5 с не установился — при пустой '
          'платформе это нормально. Последнее показание: '
          '${heard.last.weightKg} кг',
        );
      }
      return DeviceCheckOutcome.deviceRefused(
        'Весы подключены, но за 5 с не прислали ни одного показания. '
        'Проверьте кабель, скорость порта и протокол в настройках модели. '
        '(${reading.errorMessage ?? 'весы не дали показания'})',
      );
    } finally {
      await subscription.cancel();
      if (!wasAlreadyConnected) {
        await scale.disconnect();
      }
    }
  }
}
