import 'package:meta/meta.dart';

import 'package:telepos/domain/device/device_class.dart';

/// "Print a test receipt", "open the drawer", "weigh something", "print a
/// test label" — with a **visible result** — docs/system-architecture.md,
/// section 8, "Всё настраивается из интерфейса": "проверка... с видимым
/// результатом".
///
/// The result is deliberately not a `bool`. An operator who presses "check"
/// and sees "failed" learns nothing actionable — they need to know it was
/// out of paper, the port was refused, or nothing answered. A check that can
/// only say yes or no is not worth the button; see [DeviceCheckOutcome].
///
/// **И30 applies here as much as anywhere in section 8:** this contract runs
/// only when a person presses a button on a settings screen. Nothing in a
/// sale may call it, wait on it, or depend on its result — a device check is
/// diagnostic, never a gate.
abstract interface class DeviceCheck {
  /// Checks the device bound to [deviceClass] on terminal [terminalId].
  ///
  /// Never throws, with one deliberate exception: `WtDeviceCheck`
  /// (`lib/web/wt_device_check.dart`) lets `SessionLost`
  /// (`lib/domain/wire/session_lost.dart`) escape rather than folding it into
  /// [DeviceCheckOutcome.unexpectedError] — an expired session is not a
  /// device problem, and telling the operator to check a cable when the
  /// fix is to log back in sends them to the wrong screen. Every other
  /// cause — a missing binding, a hardware refusal, an exception raised
  /// deep inside the hardware layer, an unreachable till — is still
  /// reported back as an outcome, never as an escaping exception. A
  /// settings screen must not crash because a port was busy.
  ///
  /// **Defined behaviour for an unknown [terminalId]** (fix round 1, plan
  /// 2b: task 4 puts this contract over HTTP, and both the local and HTTP
  /// implementations must react identically to invalid input, so this is
  /// specified rather than left to whatever each implementation's storage
  /// happens to do): a terminal id nothing has ever bound anything to and a
  /// terminal id that does not exist at all are indistinguishable from this
  /// contract's point of view — both produce zero bindings, so both report
  /// [DeviceCheckReason.notConfigured]. This contract deliberately does not
  /// check terminal existence itself (that is `TerminalRepository`'s job,
  /// not this one's) — inventing a distinct "unknown terminal" reason here
  /// would need a second lookup this contract has no other reason to make,
  /// and "nothing is bound" is exactly, literally true in both cases.
  Future<DeviceCheckOutcome> check({
    required int terminalId,
    required DeviceClass deviceClass,
  });
}

/// Why a check succeeded or failed, machine-readable, plus [message] — text
/// already fit to show on screen as-is.
///
/// [DeviceCheckReason.notConfigured] is not a kind of failure: "no printer is
/// bound to this terminal" and "the printer refused" are different answers
/// with different operator actions attached (go bind one / check the paper),
/// and collapsing them into one "failed" result is exactly the
/// plausible-wrong-value class this project keeps getting bitten by. See
/// docs/system-architecture.md, И30/И31.
///
/// Fix round 1 added three more non-`ok` states after review found the
/// original six still collapsed genuinely different situations into one
/// reason, or discarded information a driver actually provided:
///
/// - [invalidBinding] — a binding exists but no longer validates against the
///   catalog (a profile edited or removed after the binding was saved). This
///   is not [notConfigured] (something *is* bound) and not [deviceRefused]
///   (nothing was attempted against real hardware) — it is a configuration
///   error, and the operator's fix is to re-pick a profile, not to check
///   cables.
/// - [driverNotLive] — a binding exists and validates, but this build cannot
///   drive a device of that class at all (no hardware layer for it here, or,
///   for a `viaPrinter` cash drawer, no receipt printer to send the kick
///   through). Reporting this as [connectionFailed] — "принтер не подключён"
///   — is false: the device may be perfectly reachable, the process just has
///   no way to try, and sending an operator to check cables on a working
///   printer is worse than saying nothing.
/// - [notSupportedOnPlatform] — the hardware layer itself says the
///   operation has no meaning here (e.g. `CashDrawerResult.notSupported` on
///   a non-desktop build), as opposed to being attempted and refused.
enum DeviceCheckReason {
  /// The check ran and the device did what was asked.
  ok,

  /// No single enabled binding of the requested [DeviceClass] exists on this
  /// terminal — nothing was attempted, because there is nothing configured
  /// to attempt it against. Distinct from every other reason below,
  /// including [invalidBinding] (something *is* bound, just not usably).
  notConfigured,

  /// A binding exists but fails to validate against the device profile
  /// catalog — an unknown profile id, a class mismatch, a missing required
  /// parameter, most likely because the profile it names was edited or
  /// removed after the binding was saved. The operator's fix is in device
  /// settings, not in the wiring.
  invalidBinding,

  /// The binding is valid, but this build has no way to construct a driver
  /// for it, so nothing was attempted. The fix is not "check the cable" —
  /// see this enum's doc comment for why this must not be reported as
  /// [connectionFailed].
  ///
  /// **Not producible in the shipped app, and that is worth saying plainly.**
  /// Since finding I2, `service_locator.dart` supplies `DeviceCheckLocal` with
  /// a driver builder for every one of the four checked classes
  /// unconditionally, so the `null`-builder branches that return this reason
  /// cannot be taken on a real till. The one remaining live route is a
  /// `viaPrinter` cash drawer on a terminal with no receipt-printer binding —
  /// a *missing binding*, not a missing driver.
  ///
  /// So: if this ever appears in a log from a real installation, it is
  /// evidence that the DI graph was assembled differently than
  /// `service_locator.dart` assembles it — not a diagnosis of the operator's
  /// hardware, and not something to send them to fix. It is kept, rather than
  /// deleted, because the alternative for a genuinely absent driver is
  /// reporting [connectionFailed] about a device nothing tried to reach, and
  /// because tests and other bindings (the browser build wires this contract
  /// over HTTP) may legitimately construct a check without builders. A reason
  /// nothing can produce is exactly the shape this branch spent two reviews
  /// hunting, so it is documented here instead of left to be rediscovered.
  driverNotLive,

  /// The device could not be reached at all: the port refused to open, the
  /// host did not answer, the connection attempt itself failed. Only
  /// reported when a connection was actually attempted against a live
  /// driver — never as a stand-in for "no driver was available to try".
  connectionFailed,

  /// The device was reached but refused or failed the operation — out of
  /// paper, cover open, jammed, timed out waiting for a stable reading.
  /// [DeviceCheckOutcome.message] carries whatever detail the hardware layer
  /// supplied.
  deviceRefused,

  /// The hardware layer itself declared the operation unsupported on this
  /// platform/build (e.g. a cash drawer kick on a platform with no serial
  /// port support at all) — distinct from [deviceRefused]: nothing was
  /// attempted against real hardware, because there was never a possibility
  /// of it working here.
  notSupportedOnPlatform,

  /// This [DeviceClass] has no check implemented yet. An honest gap — see
  /// stated outright — never a silent, plausible-looking success.
  notImplemented,

  /// Anything else, including an exception raised inside the hardware layer.
  /// Caught here so a settings screen never crashes because a port was busy
  /// (И30) — the caller always gets an outcome, never an escaping exception.
  unexpectedError,
}

@immutable
class DeviceCheckOutcome {
  const DeviceCheckOutcome._({required this.reason, required this.message});

  final DeviceCheckReason reason;

  /// Text fit to show on a settings screen as-is — never just "проверка не
  /// удалась" with nothing else. Always non-empty.
  final String message;

  bool get succeeded => reason == DeviceCheckReason.ok;

  /// Reconstructs an outcome received over the wire (plan 2b, task 4 —
  /// `lib/domain/wire/device_wire.dart`).
  ///
  /// Every other factory below computes [message] itself from a
  /// [DeviceClass]/detail string, which is correct for a check that just ran
  /// in this process but wrong for one relayed from another: the till already
  /// built the exact, final text (an [invalidBinding] detail, a driver's
  /// error string) and the browser must show that text verbatim, not
  /// regenerate its own guess at it from a narrower set of wire fields. This
  /// factory is the one place that bypasses the private constructor to accept
  /// [reason] and [message] exactly as sent, so the two bindings of
  /// [DeviceCheck] carry identical information rather than the HTTP side
  /// silently discarding whatever a named factory's parameters do not cover.
  factory DeviceCheckOutcome.wire({
    required DeviceCheckReason reason,
    required String message,
  }) => DeviceCheckOutcome._(reason: reason, message: message);

  factory DeviceCheckOutcome.ok([String message = 'Проверка пройдена']) =>
      DeviceCheckOutcome._(reason: DeviceCheckReason.ok, message: message);

  factory DeviceCheckOutcome.notConfigured(DeviceClass deviceClass) =>
      DeviceCheckOutcome._(
        reason: DeviceCheckReason.notConfigured,
        message:
            'Устройство класса ${deviceClass.name} не привязано к этому '
            'терминалу',
      );

  factory DeviceCheckOutcome.invalidBinding(
    DeviceClass deviceClass,
    String detail,
  ) => DeviceCheckOutcome._(
    reason: DeviceCheckReason.invalidBinding,
    message:
        'Привязка устройства класса ${deviceClass.name} на этом терминале '
        'некорректна: $detail',
  );

  factory DeviceCheckOutcome.driverNotLive(DeviceClass deviceClass) =>
      DeviceCheckOutcome._(
        reason: DeviceCheckReason.driverNotLive,
        message:
            'Устройство класса ${deviceClass.name} привязано, но эта сборка '
            'не может с ним работать — проверять нечем',
      );

  factory DeviceCheckOutcome.connectionFailed(String message) =>
      DeviceCheckOutcome._(
        reason: DeviceCheckReason.connectionFailed,
        message: message,
      );

  factory DeviceCheckOutcome.deviceRefused(String message) =>
      DeviceCheckOutcome._(
        reason: DeviceCheckReason.deviceRefused,
        message: message,
      );

  factory DeviceCheckOutcome.notSupportedOnPlatform(String message) =>
      DeviceCheckOutcome._(
        reason: DeviceCheckReason.notSupportedOnPlatform,
        message: message,
      );

  factory DeviceCheckOutcome.notImplemented(DeviceClass deviceClass) =>
      DeviceCheckOutcome._(
        reason: DeviceCheckReason.notImplemented,
        message:
            'Проверка для устройств класса ${deviceClass.name} ещё не '
            'реализована',
      );

  factory DeviceCheckOutcome.unexpectedError(String message) =>
      DeviceCheckOutcome._(
        reason: DeviceCheckReason.unexpectedError,
        message: message,
      );

  @override
  String toString() => 'DeviceCheckOutcome(${reason.name}: $message)';
}
