import 'dart:async';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/device/device_check_local.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/domain/device/device_check.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/hardware/cash_drawer/cash_drawer_service.dart';
import 'package:telepos/hardware/label_printer/label_printer_service.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';
import 'package:telepos/hardware/scales/scales_service.dart';

/// The one and only catalog `save()` would validate against in production —
/// shared across every test so a binding's `profileId`/`parameters` are
/// values the system can actually produce, per qa-depth's rule zero.
final _catalog = BuiltinDeviceProfileCatalog();

/// In-memory [DeviceBindingRepository] — seed data per terminal, exactly the
/// shape `LocalDeviceBindingRepository` would hand back (rows as saved, not
/// re-validated — see that class's doc comment), so the check under test
/// cannot tell it apart from the real thing.
class _FakeDeviceBindingRepository implements DeviceBindingRepository {
  /// [throwOnRead] set at construction, never mutated afterwards — matches
  /// `LocalDeviceBindingRepository`'s own all-final shape, and satisfies the
  /// `must_be_immutable` the interface's `@immutable` annotation calls for.
  _FakeDeviceBindingRepository({this.throwOnRead = false});

  final Map<int, List<DeviceBinding>> _byTerminal = {};

  /// Makes [forTerminal] throw, simulating a database error rather than
  /// "nothing configured" — the two must be reported differently.
  final bool throwOnRead;

  @override
  Future<List<DeviceBinding>> forTerminal(int terminalId) async {
    if (throwOnRead) {
      throw Exception('база данных недоступна');
    }
    return _byTerminal[terminalId] ?? const <DeviceBinding>[];
  }

  @override
  Stream<List<DeviceBinding>> watchForTerminal(int terminalId) =>
      Stream.fromFuture(forTerminal(terminalId));

  @override
  Future<void> save(int terminalId, DeviceBinding binding) async {
    final list = _byTerminal.putIfAbsent(terminalId, () => <DeviceBinding>[]);
    list.removeWhere((b) => b.deviceClass == binding.deviceClass);
    list.add(binding);
  }
}

/// A [PrinterManager] whose every call is canned — no serial port, no
/// socket, no OS printer spooler touched. Deterministic on every platform
/// this suite runs on, which the real `WindowsPrinterManager`/
/// `LinuxPrinterManager`/network managers are not.
class _FakePrinterManager implements PrinterManager {
  _FakePrinterManager({
    this.connectSucceeds = true,
    this.printSucceeds = true,
    this.printErrorMessage,
  });

  /// Fix round 1: previously `connect()` always succeeded, which meant
  /// `DeviceCheckReason.connectionFailed` could never actually be produced
  /// by any test — the exact "unreachable reason" finding.
  final bool connectSucceeds;
  final bool printSucceeds;
  final String? printErrorMessage;

  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Future<PrinterConnectionResult> connect() async {
    if (!connectSucceeds) {
      return PrinterConnectionResult.error('Порт занят другим приложением');
    }
    _connected = true;
    return PrinterConnectionResult.ok(
      const PrinterInfo(name: 'Fake', address: 'fake://test'),
    );
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<PrinterStatus> getStatus() async =>
      _connected ? PrinterStatus.ok : PrinterStatus.offline;

  @override
  Future<PrintResult> writeRaw(Uint8List data) async {
    if (!printSucceeds) {
      return PrintResult.error(printErrorMessage ?? 'Ошибка записи');
    }
    return PrintResult.ok(bytesSent: data.length);
  }

  @override
  Future<PrintResult> printText(String text) async =>
      writeRaw(Uint8List.fromList(text.codeUnits));

  @override
  Future<PrintResult> printReceipt(Uint8List receiptData) async {
    if (!printSucceeds) {
      return PrintResult.error(printErrorMessage ?? 'Печать не удалась');
    }
    return PrintResult.ok(bytesSent: receiptData.length);
  }

  @override
  Future<void> openCashDrawer() async {}

  @override
  Future<void> cutPaper() async {}

  @override
  Future<void> feedLines(int lines) async {}

  @override
  Future<void> initialize() async {}
}

/// Overrides `printTestLabel` directly rather than letting the real
/// `LabelPrinterService` reach a socket or a device file — the point of this
/// test is what `DeviceCheckLocal` does with the result, not whether a label
/// printer driver itself works (that belongs to that class's own tests).
///
/// Fix round 2: `connect()` is now overridden too (previously only
/// `printTestLabel` was), with its own `connectSucceeds` flag independent of
/// [_printResult] — needed to prove `DeviceCheckReason.connectionFailed` is
/// reachable for label printers the same way it already was for receipt
/// printers, distinct from a connected-but-refused [_printResult].
class _FakeLabelPrinterService extends LabelPrinterService {
  _FakeLabelPrinterService({this.connectSucceeds = true, LabelPrintResult? printResult})
    : _printResult = printResult ?? LabelPrintResult.success();

  final bool connectSucceeds;
  final LabelPrintResult _printResult;

  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Future<LabelPrintResult> connect() async {
    if (!connectSucceeds) {
      return LabelPrintResult.failure('Порт занят другим приложением');
    }
    _connected = true;
    return LabelPrintResult.success();
  }

  @override
  Future<LabelPrintResult> printTestLabel() async => _printResult;
}

/// The one case a canned result cannot stand in for: an exception raised
/// *inside* the hardware layer, past whatever try/catch that layer has of
/// its own. `open()` overridden to throw synchronously proves
/// `DeviceCheckLocal.check` catches it — removing that class's own catch
/// turns this red without touching this fake at all.
///
/// Constructed with `mode: CashDrawerMode.serialPort` on purpose: a
/// `viaPrinter`-mode drawer with no printer driver is now intercepted by
/// `DeviceCheckLocal`'s own `driverNotLive` pre-check *before* `open()` is
/// ever called (fix round 1) — using `serialPort` mode here means this fake
/// is actually reached, so the test still proves what it claims to.
class _ThrowingCashDrawerService extends CashDrawerService {
  _ThrowingCashDrawerService() : super(mode: CashDrawerMode.serialPort);

  @override
  Future<CashDrawerResult> open({
    Future<void> Function(List<int> data)? viaPrinter,
    int pin = 2,
  }) async {
    throw Exception('порт занят другим процессом');
  }
}

/// Overrides `isConnected`/`requestWeight` so the real serial-port logic
/// (`dart:io` `File.open`) is never reached in a test.
class _FakeScalesService extends ScalesService {
  _FakeScalesService(this._reading);

  final ScalesReading _reading;

  @override
  bool get isConnected => true;

  @override
  Future<ScalesReading> requestWeight({
    Duration timeout = const Duration(seconds: 10),
  }) async => _reading;
}

/// A scale that is plainly alive — it streams readings — but never produces
/// a *stable* one, which is what a healthy scale with nothing on its
/// platform looks like. `requestWeight` therefore times out and returns an
/// error, exactly as the real `ScalesService` does.
///
/// The distinction this fake exists to prove: "no stable reading" and "the
/// scale said nothing at all" are different facts, and only the second is a
/// fault (plan 2b, task 3).
class _UnsettledScalesService extends ScalesService {
  final _controller = StreamController<ScalesReading>.broadcast();

  @override
  Stream<ScalesReading> get weightStream => _controller.stream;

  @override
  bool get isConnected => true;

  @override
  Future<ScalesReading> requestWeight({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _controller.add(
      ScalesReading(weight: Decimal.parse('0.002'), status: ScalesStatus.unstable),
    );
    // Let the listener registered before this call actually receive it —
    // a broadcast controller delivers asynchronously.
    await Future<void>.delayed(Duration.zero);
    return ScalesReading.error('Таймаут ожидания стабильного веса');
  }
}

const _terminalId = 1;

DeviceBinding _binding(
  DeviceClass deviceClass,
  String profileId, {
  Map<String, String> parameters = const {},
  Map<String, String> options = const {},
}) => DeviceBinding(
  deviceClass: deviceClass,
  profileId: profileId,
  parameters: parameters,
  options: options,
);

void main() {
  group('DeviceCheckLocal', () {
    test('a successful check reports success', () async {
      final bindings = _FakeDeviceBindingRepository()
        ..save(
          _terminalId,
          _binding(DeviceClass.receiptPrinter, 'printer.escpos.usb'),
        );
      final check = DeviceCheckLocal(
        bindingRepository: bindings,
        catalog: _catalog,
        receiptPrinterFor: (_) => _FakePrinterManager(printSucceeds: true),
      );

      final outcome = await check.check(
        terminalId: _terminalId,
        deviceClass: DeviceClass.receiptPrinter,
      );

      expect(outcome.succeeded, isTrue);
      expect(outcome.reason, DeviceCheckReason.ok);
      expect(outcome.message, isNotEmpty);
    });

    test(
      'a failing check reports the reason, not merely "failed"',
      () async {
        final bindings = _FakeDeviceBindingRepository()
          ..save(
            _terminalId,
            _binding(DeviceClass.receiptPrinter, 'printer.escpos.usb'),
          );
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
          receiptPrinterFor: (_) => _FakePrinterManager(
            printSucceeds: false,
            printErrorMessage: 'Нет бумаги',
          ),
        );

        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.receiptPrinter,
        );

        expect(outcome.succeeded, isFalse);
        expect(outcome.reason, DeviceCheckReason.deviceRefused);
        expect(
          outcome.message,
          contains('Нет бумаги'),
          reason:
              'the operator needs the actual reason, not just "failed" — '
              'this is the whole point of the contract',
        );
      },
    );

    test(
      'a printer that cannot be connected to at all reports '
      'connectionFailed — distinct from deviceRefused, which requires an '
      'actual connection first (fix round 1: this reason was previously '
      'unreachable)',
      () async {
        final bindings = _FakeDeviceBindingRepository()
          ..save(
            _terminalId,
            _binding(DeviceClass.receiptPrinter, 'printer.escpos.usb'),
          );
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
          receiptPrinterFor: (_) => _FakePrinterManager(connectSucceeds: false),
        );

        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.receiptPrinter,
        );

        expect(outcome.succeeded, isFalse);
        expect(outcome.reason, DeviceCheckReason.connectionFailed);
        expect(outcome.reason, isNot(DeviceCheckReason.deviceRefused));
      },
    );

    test(
      'an unconfigured device reports notConfigured, distinguishable from '
      'a failure',
      () async {
        final bindings = _FakeDeviceBindingRepository(); // nothing saved
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
        );

        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.scale,
        );

        expect(outcome.succeeded, isFalse);
        expect(outcome.reason, DeviceCheckReason.notConfigured);
        expect(outcome.reason, isNot(DeviceCheckReason.deviceRefused));
        expect(outcome.reason, isNot(DeviceCheckReason.connectionFailed));
      },
    );

    test(
      'an unknown terminal id is reported exactly like "nothing bound" — '
      'defined behaviour, not an accident: task 4 needs the HTTP binding to '
      'agree with this one on invalid input',
      () async {
        final bindings = _FakeDeviceBindingRepository()
          ..save(
            _terminalId,
            _binding(
              DeviceClass.scale,
              'scale.cas.pd2',
              parameters: {'comPort': 'COM3'},
            ),
          );
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
        );

        final outcome = await check.check(
          // Never saved, on purpose — not even close to _terminalId.
          terminalId: 999999,
          deviceClass: DeviceClass.scale,
        );

        expect(outcome.reason, DeviceCheckReason.notConfigured);
      },
    );

    test(
      'a binding whose profile no longer validates reports invalidBinding — '
      'distinct from notConfigured (something IS bound) and from a real '
      'device failure (nothing was attempted against hardware)',
      () async {
        final bindings = _FakeDeviceBindingRepository()
          ..save(
            _terminalId,
            // A real, existing profile id — just for the wrong class,
            // exactly what a profile edited/removed out from under a saved
            // binding would look like at read time.
            const DeviceBinding(
              deviceClass: DeviceClass.receiptPrinter,
              profileId: 'scale.cas.pd2',
            ),
          );
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
        );

        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.receiptPrinter,
        );

        expect(outcome.succeeded, isFalse);
        expect(outcome.reason, DeviceCheckReason.invalidBinding);
        expect(outcome.reason, isNot(DeviceCheckReason.notConfigured));
        expect(outcome.reason, isNot(DeviceCheckReason.deviceRefused));
        expect(outcome.message, contains('DeviceClass.scale'));
      },
    );

    test(
      'a receipt printer that is bound but has no live driver in this '
      'process reports driverNotLive, never a false connectionFailed — the '
      'critical fix round 1 finding: HardwareModule.register runs once, at '
      'startup, so a binding added afterwards has nothing built for it yet',
      () async {
        final bindings = _FakeDeviceBindingRepository()
          ..save(
            _terminalId,
            _binding(DeviceClass.receiptPrinter, 'printer.escpos.usb'),
          );
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
          // No receiptPrinter supplied.
        );

        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.receiptPrinter,
        );

        expect(outcome.succeeded, isFalse);
        expect(outcome.reason, DeviceCheckReason.driverNotLive);
        expect(outcome.reason, isNot(DeviceCheckReason.connectionFailed));
        expect(outcome.reason, isNot(DeviceCheckReason.notConfigured));
      },
    );

    test(
      'a label printer that is bound but has no live driver reports '
      'driverNotLive',
      () async {
        final bindings = _FakeDeviceBindingRepository()
          ..save(
            _terminalId,
            _binding(
              DeviceClass.labelPrinter,
              'printer.label.zpl.104mm',
              parameters: {'ipAddress': '10.0.0.20'},
            ),
          );
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
        );

        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.labelPrinter,
        );

        expect(outcome.reason, DeviceCheckReason.driverNotLive);
      },
    );

    test(
      'a label printer that cannot be connected to at all reports '
      'connectionFailed — distinct from deviceRefused (fix round 2: the '
      'same structural fix as the receipt printer, because '
      'LabelPrinterService.connect() is public and genuinely separate from '
      'the print/send step, unlike CashDrawerService.open())',
      () async {
        final bindings = _FakeDeviceBindingRepository()
          ..save(
            _terminalId,
            _binding(
              DeviceClass.labelPrinter,
              'printer.label.zpl.104mm',
              parameters: {'ipAddress': '10.0.0.20'},
            ),
          );
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
          labelPrinterFor: (_) => _FakeLabelPrinterService(
            connectSucceeds: false,
          ),
        );

        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.labelPrinter,
        );

        expect(outcome.succeeded, isFalse);
        expect(outcome.reason, DeviceCheckReason.connectionFailed);
        expect(outcome.reason, isNot(DeviceCheckReason.deviceRefused));
      },
    );

    test(
      'a label printer that connects but fails to print reports '
      'deviceRefused with the reason, not merely "failed"',
      () async {
        final bindings = _FakeDeviceBindingRepository()
          ..save(
            _terminalId,
            _binding(
              DeviceClass.labelPrinter,
              'printer.label.zpl.104mm',
              parameters: {'ipAddress': '10.0.0.20'},
            ),
          );
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
          labelPrinterFor: (_) => _FakeLabelPrinterService(
            printResult: LabelPrintResult.failure('Нет плёнки'),
          ),
        );

        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.labelPrinter,
        );

        expect(outcome.succeeded, isFalse);
        expect(outcome.reason, DeviceCheckReason.deviceRefused);
        expect(outcome.message, contains('Нет плёнки'));
        expect(outcome.reason, isNot(DeviceCheckReason.connectionFailed));
      },
    );

    test(
      'a scale that is bound but has no live driver reports driverNotLive',
      () async {
        final bindings = _FakeDeviceBindingRepository()
          ..save(
            _terminalId,
            _binding(
              DeviceClass.scale,
              'scale.cas.pd2',
              parameters: {'comPort': 'COM3'},
            ),
          );
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
        );

        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.scale,
        );

        expect(outcome.reason, DeviceCheckReason.driverNotLive);
      },
    );

    test(
      'a check that throws inside the hardware layer becomes a reported '
      'outcome, not an escaping exception',
      () async {
        final bindings = _FakeDeviceBindingRepository()
          ..save(
            _terminalId,
            _binding(
              DeviceClass.cashDrawer,
              'drawer.rj11.standalone',
              parameters: {'comPort': 'COM7'},
            ),
          );
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
          cashDrawerFor: (_) => _ThrowingCashDrawerService(),
        );

        // If the exception escaped, this `await` itself would throw and the
        // test would fail with an uncaught error — not a normal assertion
        // failure. Reaching the expectations below is the proof.
        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.cashDrawer,
        );

        expect(outcome.succeeded, isFalse);
        expect(outcome.reason, DeviceCheckReason.unexpectedError);
        expect(outcome.message, isNotEmpty);
      },
    );

    test(
      'a database failure reading bindings is reported too, and is not '
      'confused with "not configured"',
      () async {
        final bindings = _FakeDeviceBindingRepository(throwOnRead: true);
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
        );

        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.receiptPrinter,
        );

        expect(outcome.succeeded, isFalse);
        expect(outcome.reason, DeviceCheckReason.unexpectedError);
        expect(outcome.reason, isNot(DeviceCheckReason.notConfigured));
      },
    );

    test(
      'a device class with no check implemented reports that honestly, '
      'even when a binding exists — never a fabricated success',
      () async {
        final bindings = _FakeDeviceBindingRepository()
          ..save(_terminalId, _binding(DeviceClass.scanner, 'scanner.usb.hid'));
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
        );

        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.scanner,
        );

        expect(outcome.succeeded, isFalse);
        expect(outcome.reason, DeviceCheckReason.notImplemented);
        expect(outcome.reason, isNot(DeviceCheckReason.notConfigured));
      },
    );

    test(
      'seed: checking one class does not report another class\'s result — '
      'proves dispatch checked the right device, not merely something',
      () async {
        final bindings = _FakeDeviceBindingRepository()
          ..save(
            _terminalId,
            _binding(DeviceClass.receiptPrinter, 'printer.escpos.usb'),
          )
          ..save(
            _terminalId,
            _binding(
              DeviceClass.labelPrinter,
              'printer.label.zpl.104mm',
              parameters: {'ipAddress': '10.0.0.20'},
            ),
          );
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
          receiptPrinterFor: (_) => _FakePrinterManager(
            printSucceeds: false,
            printErrorMessage: 'Крышка открыта',
          ),
          labelPrinterFor: (_) => _FakeLabelPrinterService(
            printResult: LabelPrintResult.success(),
          ),
        );

        final printerOutcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.receiptPrinter,
        );
        final labelOutcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.labelPrinter,
        );

        expect(printerOutcome.reason, DeviceCheckReason.deviceRefused);
        expect(printerOutcome.message, contains('Крышка открыта'));
        expect(labelOutcome.reason, DeviceCheckReason.ok);
      },
    );

    test(
      'a drawer wired via the receipt printer uses the printer channel and '
      'reports success',
      () async {
        final bindings = _FakeDeviceBindingRepository()
          ..save(
            _terminalId,
            _binding(DeviceClass.cashDrawer, 'drawer.rj11.via-printer'),
          )
          // The kick command rides the receipt printer's channel, so a
          // via-printer drawer is only usable on a terminal that has a
          // receipt printer bound — seeded here because that is the only
          // shape this configuration can really have (finding I2: the
          // printer is now built from *that* binding, not from a startup
          // singleton).
          ..save(
            _terminalId,
            _binding(DeviceClass.receiptPrinter, 'printer.escpos.usb'),
          );
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
          receiptPrinterFor: (_) => _FakePrinterManager(printSucceeds: true),
          cashDrawerFor: (_) => CashDrawerService(mode: CashDrawerMode.viaPrinter),
        );

        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.cashDrawer,
        );

        expect(outcome.succeeded, isTrue);
        expect(outcome.reason, DeviceCheckReason.ok);
      },
    );

    test(
      'a drawer bound via printer with no printer driver available reports '
      'driverNotLive, not a crash and not a false deviceRefused',
      () async {
        final bindings = _FakeDeviceBindingRepository()
          ..save(
            _terminalId,
            _binding(DeviceClass.cashDrawer, 'drawer.rj11.via-printer'),
          )
          // A receipt printer IS bound — so the only thing missing is a way
          // to build a driver for it, which is what this test is about.
          ..save(
            _terminalId,
            _binding(DeviceClass.receiptPrinter, 'printer.escpos.usb'),
          );
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
          cashDrawerFor: (_) => CashDrawerService(mode: CashDrawerMode.viaPrinter),
          // No receiptPrinterFor supplied — the drawer rides the printer
          // channel, and this build cannot construct that channel.
        );

        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.cashDrawer,
        );

        expect(outcome.succeeded, isFalse);
        expect(outcome.reason, DeviceCheckReason.driverNotLive);
      },
    );

    test(
      'a cash drawer the hardware layer says is not supported on this '
      'platform reports notSupportedOnPlatform, not a generic deviceRefused',
      () async {
        final bindings = _FakeDeviceBindingRepository()
          ..save(
            _terminalId,
            _binding(DeviceClass.cashDrawer, 'drawer.rj11.via-printer'),
          )
          ..save(
            _terminalId,
            _binding(DeviceClass.receiptPrinter, 'printer.escpos.usb'),
          );
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
          // A printer IS supplied so the driverNotLive pre-check does not
          // intercept — this exercises CashDrawerService.dummy()'s own
          // notSupported branch inside open() itself.
          receiptPrinterFor: (_) => _FakePrinterManager(),
          cashDrawerFor: (_) => CashDrawerService.dummy(),
        );

        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.cashDrawer,
        );

        expect(outcome.succeeded, isFalse);
        expect(outcome.reason, DeviceCheckReason.notSupportedOnPlatform);
        expect(outcome.reason, isNot(DeviceCheckReason.deviceRefused));
      },
    );

    test('a scale check reports a stable reading as success', () async {
      final bindings = _FakeDeviceBindingRepository()
        ..save(
          _terminalId,
          _binding(
            DeviceClass.scale,
            'scale.cas.pd2',
            parameters: {'comPort': 'COM3'},
          ),
        );
      final check = DeviceCheckLocal(
        bindingRepository: bindings,
        catalog: _catalog,
        scalesFor: (_) => _FakeScalesService(
          ScalesReading(status: ScalesStatus.stable, weight: Decimal.one),
        ),
      );

      final outcome = await check.check(
        terminalId: _terminalId,
        deviceClass: DeviceClass.scale,
      );

      expect(outcome.succeeded, isTrue);
      expect(outcome.reason, DeviceCheckReason.ok);
    });

    test(
      'a scale that answers with an error reading reports deviceRefused '
      'with the reading\'s message',
      () async {
        final bindings = _FakeDeviceBindingRepository()
          ..save(
            _terminalId,
            _binding(
              DeviceClass.scale,
              'scale.cas.pd2',
              parameters: {'comPort': 'COM3'},
            ),
          );
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
          scalesFor: (_) => _FakeScalesService(
            ScalesReading.error('Таймаут ожидания стабильного веса'),
          ),
        );

        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.scale,
        );

        expect(outcome.succeeded, isFalse);
        expect(outcome.reason, DeviceCheckReason.deviceRefused);
        expect(outcome.message, contains('Таймаут'));
        expect(
          outcome.message,
          contains('не прислали ни одного показания'),
          reason: 'a scale that said nothing at all must be described as such '
              '— the driver\'s bare "таймаут стабильного веса" reads as a '
              'fault even when the platform is simply empty',
        );
      },
    );

    test(
      'a healthy scale with nothing on the platform is not reported as a '
      'fault: readings arrive, none stabilises, and that is success',
      () async {
        final bindings = _FakeDeviceBindingRepository()
          ..save(
            _terminalId,
            _binding(
              DeviceClass.scale,
              'scale.cas.pd2',
              parameters: {'comPort': 'COM3'},
            ),
          );
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
          scalesFor: (_) => _UnsettledScalesService(),
        );

        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.scale,
        );

        expect(
          outcome.reason,
          DeviceCheckReason.ok,
          reason: 'the scale demonstrably answered — telling the operator it '
              'refused would send them to check a working device',
        );
        expect(outcome.message, contains('при пустой платформе это нормально'));
        expect(
          outcome.message,
          contains('0.002'),
          reason: 'the actual reading heard is shown, so the operator can see '
              'the scale really is talking',
        );
      },
    );

    test('a scale with no port configured reports connectionFailed', () async {
      final bindings = _FakeDeviceBindingRepository()
        ..save(
          _terminalId,
          _binding(
            DeviceClass.scale,
            'scale.cas.pd2',
            parameters: {'comPort': 'COM3'},
          ),
        );
      final check = DeviceCheckLocal(
        bindingRepository: bindings,
        catalog: _catalog,
        // Real ScalesService, constructed with no port — connect() fails
        // fast with no dart:io touched (see ScalesService.connect's own
        // guard clause). The binding's own comPort parameter is only used
        // for validateAgainst here, same as everywhere else in this suite —
        // DeviceCheckLocal never cross-checks it against the driver.
        scalesFor: (_) => ScalesService(),
      );

      final outcome = await check.check(
        terminalId: _terminalId,
        deviceClass: DeviceClass.scale,
      );

      expect(outcome.succeeded, isFalse);
      expect(outcome.reason, DeviceCheckReason.connectionFailed);
    });

    test(
      'a scale check leaves the scale exactly as it found it — connects and '
      'disconnects again if it opened the connection itself, so a '
      'diagnostic button press does not leave a serial port open and a '
      'polling timer running forever',
      () async {
        final bindings = _FakeDeviceBindingRepository()
          ..save(
            _terminalId,
            _binding(
              DeviceClass.scale,
              'scale.cas.pd2',
              parameters: {'comPort': 'COM3'},
            ),
          );
        final scale = _DisconnectTrackingScalesService(
          ScalesReading(status: ScalesStatus.stable, weight: Decimal.one),
        );
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
          scalesFor: (_) => scale,
        );

        await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.scale,
        );

        expect(
          scale.disconnectCallCount,
          1,
          reason:
              'the check itself connected (isConnected started false), so '
              'it must disconnect again afterwards',
        );
      },
    );

    // ---- Finding I2 -----------------------------------------------------
    //
    // The defect: the check used to be handed the driver singletons
    // `HardwareModule` built at *startup*, from the bindings that existed
    // then. An operator who moved a scale from COM3 to COM5, saved, and
    // pressed «проверить» was therefore checking COM3 — and could be told
    // `ok` for a configuration that does not work. These two tests fail if
    // the check ever silently goes back to a driver built from anything but
    // the binding it just read.

    test(
      'the check builds its driver from the binding as saved now, not from '
      'the one this process started with (finding I2): a scale moved to '
      'COM5 is checked on COM5',
      () async {
        final bindings = _FakeDeviceBindingRepository()
          ..save(
            _terminalId,
            _binding(
              DeviceClass.scale,
              'scale.cas.pd2',
              // The operator has already saved the new port.
              parameters: {'comPort': _savedPort},
            ),
          );

        final portsAsked = <String?>[];
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
          scalesFor: (binding) {
            portsAsked.add(binding.parameters['comPort']);
            return _PortAwareScalesService(binding.parameters['comPort']);
          },
        );

        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.scale,
        );

        expect(
          portsAsked,
          [_savedPort],
          reason:
              'the driver must be built from the stored binding exactly '
              'once — a builder called with anything else (the startup '
              'binding, a default) is the defect this test exists for',
        );
        expect(
          outcome.reason,
          DeviceCheckReason.ok,
          reason:
              'only the saved port answers; a check that reverted to the '
              'startup port ($_startupPort) would report connectionFailed '
              'here, so a green result cannot come from the wrong device',
        );
        expect(outcome.message, isNot(contains(_startupPort)));
      },
    );

    test(
      'a check that talked to the process-start configuration instead of the '
      'saved one is visibly wrong, not silently green (finding I2, the '
      'negative half)',
      () async {
        final bindings = _FakeDeviceBindingRepository()
          ..save(
            _terminalId,
            _binding(
              DeviceClass.scale,
              'scale.cas.pd2',
              parameters: {'comPort': _startupPort},
            ),
          );

        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
          scalesFor: (binding) =>
              _PortAwareScalesService(binding.parameters['comPort']),
        );

        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.scale,
        );

        // Same fake, same code path, opposite stored value: this is the
        // control that proves the assertion above is about *which* port was
        // used and not about the fake always succeeding.
        expect(outcome.reason, DeviceCheckReason.connectionFailed);
        expect(outcome.message, contains(_startupPort));
      },
    );

    test(
      'the receipt-printer driver is built from the saved binding too — the '
      'class where a stale, startup-built manager was most likely to answer '
      'for a printer the operator had already moved (finding I2)',
      () async {
        final bindings = _FakeDeviceBindingRepository()
          ..save(
            _terminalId,
            _binding(
              DeviceClass.receiptPrinter,
              'printer.escpos.80mm',
              parameters: {'ipAddress': '192.168.1.77', 'port': '9100'},
            ),
          );

        final addressesAsked = <String?>[];
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
          receiptPrinterFor: (binding) {
            addressesAsked.add(binding.parameters['ipAddress']);
            return _FakePrinterManager();
          },
        );

        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.receiptPrinter,
        );

        expect(addressesAsked, ['192.168.1.77']);
        expect(outcome.reason, DeviceCheckReason.ok);
      },
    );
  });

  // Finding I2 fixed the check answering for the binding the *process*
  // started with. Building a driver unconditionally to do that introduced the
  // mirror-image defect: with the binding unchanged, the fresh driver aims at
  // the endpoint the live driver is already holding, and an endpoint that
  // admits one client refuses it -- connectionFailed about hardware that
  // works. Both halves are asserted here, because only both together make the
  // check worth pressing: an unchanged binding must borrow, a changed one
  // must still build.
  group('an unchanged binding borrows the live driver (I2 round 2)', () {
    test(
      'a receipt printer whose binding has not changed is checked over the '
      'live connection - no second socket is opened to a port that admits '
      'one client, and the check answers ok instead of connectionFailed',
      () async {
        const stored = DeviceBinding(
          deviceClass: DeviceClass.receiptPrinter,
          profileId: 'printer.escpos.80mm',
          parameters: {'ipAddress': '192.168.1.77', 'port': '9100'},
        );
        final bindings = _FakeDeviceBindingRepository()
          ..save(_terminalId, stored);

        // One endpoint, one client - a networked ESC/POS printer on 9100.
        final endpoint = _ExclusiveEndpoint();
        // The app's live driver, holding the port because a sale printed over
        // it a moment ago.
        final livePrinter = _EndpointPrinterManager(endpoint);
        await livePrinter.connect();
        expect(livePrinter.isConnected, isTrue);

        var builtRivals = 0;
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
          receiptPrinterFor: (binding) {
            builtRivals++;
            return _EndpointPrinterManager(endpoint);
          },
          live: LiveDeviceDrivers(
            receiptPrinter: LiveDriver(
              binding: stored,
              resolve: () => livePrinter,
            ),
          ),
        );

        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.receiptPrinter,
        );

        expect(
          outcome.reason,
          DeviceCheckReason.ok,
          reason:
              'the printer works and is already connected - the only way to '
              'get connectionFailed here is by building a rival driver and '
              'having the endpoint refuse its second connect, which is the '
              'false failure this mitigation exists to remove. Message was: '
              '${outcome.message}',
        );
        expect(
          builtRivals,
          0,
          reason:
              'the saved binding still describes the device the live driver '
              'was built from, so nothing should have been constructed',
        );
        expect(
          endpoint.openCount,
          1,
          reason:
              'exactly the one connection the live driver already had - a '
              'second open against the same endpoint is the defect',
        );
      },
    );

    test(
      'the live connection survives the check - a diagnostic press must not '
      'disconnect the printer the sale path is about to print over',
      () async {
        const stored = DeviceBinding(
          deviceClass: DeviceClass.receiptPrinter,
          profileId: 'printer.escpos.80mm',
          parameters: {'ipAddress': '192.168.1.77', 'port': '9100'},
        );
        final bindings = _FakeDeviceBindingRepository()
          ..save(_terminalId, stored);

        final endpoint = _ExclusiveEndpoint();
        final livePrinter = _EndpointPrinterManager(endpoint);
        await livePrinter.connect();

        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
          receiptPrinterFor: (_) => _EndpointPrinterManager(endpoint),
          live: LiveDeviceDrivers(
            receiptPrinter: LiveDriver(
              binding: stored,
              resolve: () => livePrinter,
            ),
          ),
        );

        await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.receiptPrinter,
        );

        expect(
          livePrinter.isConnected,
          isTrue,
          reason:
              'this check did not open the connection, so it must not close '
              'it - leave the driver exactly as it was found',
        );
        expect(endpoint.closeCount, 0);
      },
    );

    test(
      'a binding the operator changed still builds a fresh driver, and never '
      'resolves the stale live one - the mitigation must not undo finding I2',
      () async {
        const stored = DeviceBinding(
          deviceClass: DeviceClass.scale,
          profileId: 'scale.cas.pd2',
          parameters: {'comPort': _savedPort},
        );
        final bindings = _FakeDeviceBindingRepository()
          ..save(_terminalId, stored);

        var liveResolved = 0;
        final portsBuilt = <String?>[];
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
          scalesFor: (binding) {
            portsBuilt.add(binding.parameters['comPort']);
            return _PortAwareScalesService(binding.parameters['comPort']);
          },
          live: LiveDeviceDrivers(
            scales: LiveDriver(
              // What the app started with: the port before the operator
              // changed it.
              binding: const DeviceBinding(
                deviceClass: DeviceClass.scale,
                profileId: 'scale.cas.pd2',
                parameters: {'comPort': _startupPort},
              ),
              resolve: () {
                liveResolved++;
                return _PortAwareScalesService(_startupPort);
              },
            ),
          ),
        );

        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.scale,
        );

        expect(portsBuilt, [_savedPort]);
        expect(outcome.reason, DeviceCheckReason.ok);
        expect(
          liveResolved,
          0,
          reason:
              'the live drivers are lazy singletons - asking for one builds '
              'it. A check of a changed binding must not bring the stale '
              'driver into existence merely to reject it',
        );
      },
    );

    test(
      'a changed *option* builds a fresh driver too - label size reaches the '
      'driver, so comparing only parameters would test the old size',
      () async {
        final stored = _binding(
          DeviceClass.labelPrinter,
          'printer.label.epl.58mm',
          parameters: {'ipAddress': '192.168.1.90', 'port': '9100'},
          options: {'paperWidthMm': '58'},
        );
        final bindings = _FakeDeviceBindingRepository()
          ..save(_terminalId, stored);

        var built = 0;
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
          labelPrinterFor: (_) {
            built++;
            return _FakeLabelPrinterService();
          },
          live: LiveDeviceDrivers(
            labelPrinter: LiveDriver(
              // Same profile, same address - only the label width differs,
              // and that is an input buildLabelPrinterService reads.
              binding: _binding(
                DeviceClass.labelPrinter,
                'printer.label.epl.58mm',
                parameters: {'ipAddress': '192.168.1.90', 'port': '9100'},
                options: {'paperWidthMm': '40'},
              ),
              resolve: () => _FakeLabelPrinterService(),
            ),
          ),
        );

        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.labelPrinter,
        );

        expect(outcome.reason, DeviceCheckReason.ok);
        expect(
          built,
          1,
          reason:
              'the live driver prints 40mm labels and the binding now says '
              '58mm - borrowing it would check the width the operator just '
              'changed away from',
        );
      },
    );

    test(
      'with no live driver declared at all, behaviour is unchanged: build '
      'fresh, every time',
      () async {
        const stored = DeviceBinding(
          deviceClass: DeviceClass.scale,
          profileId: 'scale.cas.pd2',
          parameters: {'comPort': _savedPort},
        );
        final bindings = _FakeDeviceBindingRepository()
          ..save(_terminalId, stored);

        var built = 0;
        final check = DeviceCheckLocal(
          bindingRepository: bindings,
          catalog: _catalog,
          scalesFor: (binding) {
            built++;
            return _PortAwareScalesService(binding.parameters['comPort']);
          },
        );

        final outcome = await check.check(
          terminalId: _terminalId,
          deviceClass: DeviceClass.scale,
        );

        expect(built, 1);
        expect(outcome.reason, DeviceCheckReason.ok);
      },
    );
  });
}

/// An endpoint that admits exactly one client at a time - a network ESC/POS
/// printer listening on 9100, or an exclusive serial port. The whole point of
/// the mitigation is that the check never becomes the second client.
class _ExclusiveEndpoint {
  bool _held = false;
  int openCount = 0;
  int closeCount = 0;

  bool open() {
    if (_held) return false;
    _held = true;
    openCount++;
    return true;
  }

  void close() {
    if (!_held) return;
    _held = false;
    closeCount++;
  }
}

/// A [PrinterManager] backed by an [_ExclusiveEndpoint]: its `connect()`
/// genuinely fails when another instance is already holding the endpoint,
/// which is what a real printer on port 9100 does and what turned a working
/// printer into `connectionFailed`.
class _EndpointPrinterManager implements PrinterManager {
  _EndpointPrinterManager(this._endpoint);

  final _ExclusiveEndpoint _endpoint;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Future<PrinterConnectionResult> connect() async {
    if (!_endpoint.open()) {
      return PrinterConnectionResult.error(
        'Порт 9100 занят другим подключением',
      );
    }
    _connected = true;
    return PrinterConnectionResult.ok(
      const PrinterInfo(name: 'Endpoint', address: '192.168.1.77:9100'),
    );
  }

  @override
  Future<void> disconnect() async {
    if (!_connected) return;
    _connected = false;
    _endpoint.close();
  }

  @override
  Future<PrinterStatus> getStatus() async =>
      _connected ? PrinterStatus.ok : PrinterStatus.offline;

  @override
  Future<PrintResult> writeRaw(Uint8List data) async =>
      PrintResult.ok(bytesSent: data.length);

  @override
  Future<PrintResult> printText(String text) async =>
      writeRaw(Uint8List.fromList(text.codeUnits));

  @override
  Future<PrintResult> printReceipt(Uint8List receiptData) async =>
      PrintResult.ok(bytesSent: receiptData.length);

  @override
  Future<void> openCashDrawer() async {}

  @override
  Future<void> cutPaper() async {}

  @override
  Future<void> feedLines(int lines) async {}

  @override
  Future<void> initialize() async {}
}

/// The port the binding says today, after the operator saved a change.
const _savedPort = 'COM5';

/// The port this process started with — what a driver captured at startup
/// would still be talking to.
const _startupPort = 'COM3';

/// A scale that only answers on [_savedPort]. Nothing here inspects the
/// binding: the driver knows only the port it was constructed with, exactly
/// like the real `ScalesService`, so the only way a check reaches a working
/// scale is by having been built from the stored value.
class _PortAwareScalesService extends ScalesService {
  _PortAwareScalesService(String? port) : super(port: port);

  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Future<ScalesConnectResult> connect() async {
    if (port != _savedPort) {
      return ScalesConnectResult.failure('Порт $port не отвечает');
    }
    _connected = true;
    return ScalesConnectResult.success();
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<ScalesReading> requestWeight({
    Duration timeout = const Duration(seconds: 10),
  }) async => ScalesReading(status: ScalesStatus.stable, weight: Decimal.one);
}

/// Tracks whether/how often `disconnect()` was called, without touching any
/// real serial port. `isConnected` starts `false` like a fresh, never-opened
/// [ScalesService] and flips to `true` after `connect()` — mirroring the
/// real class's behaviour closely enough for [DeviceCheckLocal]'s
/// connect-if-needed logic to exercise its own disconnect-afterwards path.
class _DisconnectTrackingScalesService extends ScalesService {
  _DisconnectTrackingScalesService(this._reading);

  final ScalesReading _reading;
  bool _connected = false;
  int disconnectCallCount = 0;

  @override
  bool get isConnected => _connected;

  @override
  Future<ScalesConnectResult> connect() async {
    _connected = true;
    return ScalesConnectResult.success();
  }

  @override
  Future<void> disconnect() async {
    disconnectCallCount++;
    _connected = false;
  }

  @override
  Future<ScalesReading> requestWeight({
    Duration timeout = const Duration(seconds: 10),
  }) async => _reading;
}
