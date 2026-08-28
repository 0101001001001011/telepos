import 'package:meta/meta.dart';

import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';

/// "This terminal, this class → this profile, this address" —
/// docs/system-architecture.md, section 8, "Класс устройства, а не модель".
///
/// Everything here differs between two units of the same model: the
/// connection parameter values (an IP for a networked printer, a COM port
/// for a serial scale, a merchant id and key for a payment terminal —
/// whatever the profile's `connectionParams` declare, И141), whether the
/// device is enabled at all, and any choice the operator made among what
/// the profile allows (e.g. installed paper width, when the profile
/// supports more than one). What is instead true of every unit of the
/// model — the protocol, which parameters exist at all, the supported
/// paper widths themselves, the default baud rate — belongs on
/// `DeviceProfile`, not here.
///
/// A single `address: String?` field cannot express this: a serial scale
/// needs one COM port, a payment terminal needs a host, a port, a merchant
/// id and a key. [parameters] is a string-keyed bag instead, validated
/// against the profile's declared keys rather than trusted blindly.
///
/// [options] is a second, deliberately separate string-keyed bag: it is not
/// about *reaching* the device, it is the operator's pick among several
/// physical configurations the model supports (plan 2, task 1, fix round
/// 2) — e.g. which of the widths a printer supports is actually installed.
/// Conflating this with [parameters] would mean a connection detail and an
/// operator choice share one bag with no way to tell them apart.
@immutable
class DeviceBinding {
  const DeviceBinding({
    required this.deviceClass,
    required this.profileId,
    this.parameters = const <String, String>{},
    this.options = const <String, String>{},
    this.enabled = true,
  });

  final DeviceClass deviceClass;

  /// References `DeviceProfile.id` in whatever `DeviceProfileCatalog` this
  /// binding is validated against. Not resolved eagerly — a binding can be
  /// constructed and held before its catalog is available; validation is a
  /// deliberate, separate step ([validateAgainst]).
  final String profileId;

  /// Connection parameter values, keyed by `DeviceConnectionParam.key` from
  /// the profile named by [profileId] — e.g. `{'comPort': 'COM3'}` for a
  /// serial scale, `{'ipAddress': '192.168.1.50', 'port': '9100'}` for a
  /// networked printer. Values are plain strings by design (plan 2, task 1,
  /// fix round 1: "keep it simple ... do not build a type system for
  /// parameters"); a settings screen renders and parses them.
  final Map<String, String> parameters;

  /// Chosen option values, keyed by `DeviceOption.key` from the profile
  /// named by [profileId] — e.g. `{'paperWidthMm': '80'}`. Choosing a value
  /// outside the profile's permitted set is refused by [validateAgainst];
  /// leaving an option unset is not — most installations never touch most
  /// options, and forcing a choice everywhere would be ceremony for its own
  /// sake. `ThisPosEntries.paperWidth` (the value this replaces) migrates
  /// here, not into [parameters] — plan 2, task 2.
  final Map<String, String> options;

  final bool enabled;

  /// Confirms this binding names a real profile of the right class, that
  /// [parameters] is exactly what that profile's protocol needs — no more,
  /// no less — and that every chosen [options] value is one the profile
  /// actually permits.
  ///
  /// Throws [ArgumentError] if [catalog] does not recognise [profileId] —
  /// an unknown profile id is refused, never silently substituted for a
  /// similar one, because substitution would produce a plausibly working
  /// device of the wrong model.
  ///
  /// Throws [ArgumentError] if the named profile belongs to a different
  /// [DeviceClass] than this binding declares — e.g. a scale profile bound
  /// as a receipt printer. That mismatch is a silently wrong configuration,
  /// not a usable one, so it fails loudly here instead.
  ///
  /// Throws [ArgumentError], naming the missing key, if [parameters] is
  /// missing a value (or has a blank one) for a parameter the profile marks
  /// required — И141.
  ///
  /// Throws [ArgumentError], naming the unknown key, if [parameters]
  /// supplies a key the profile never declared. An unrecognised key is
  /// refused rather than silently dropped: silently dropping a parameter is
  /// how a device ends up talking to the wrong place.
  ///
  /// Throws [ArgumentError], naming the key, if [options] supplies a key the
  /// profile never declared.
  ///
  /// Throws [ArgumentError], naming the option and the offending value, if
  /// [options] chooses a value the profile does not permit for that option
  /// — e.g. `58` for a printer whose profile only permits `80`. A printer
  /// that only supports 80mm must not silently accept 58mm: the receipt
  /// would come out wrong and nothing would complain.
  void validateAgainst(DeviceProfileCatalog catalog) {
    final profile = catalog.byId(profileId);
    if (profile == null) {
      throw ArgumentError.value(
        profileId,
        'profileId',
        'no device profile with this id exists in the catalog',
      );
    }
    if (profile.deviceClass != deviceClass) {
      throw ArgumentError.value(
        profileId,
        'profileId',
        'profile is for ${profile.deviceClass}, not $deviceClass',
      );
    }

    final declaredKeys = profile.connectionParams.map((p) => p.key).toSet();
    for (final suppliedKey in parameters.keys) {
      if (!declaredKeys.contains(suppliedKey)) {
        throw ArgumentError.value(
          suppliedKey,
          'parameters',
          'profile ${profile.id} does not declare a connection parameter '
              'with this key',
        );
      }
    }

    for (final param in profile.connectionParams) {
      if (!param.isRequired) continue;
      final value = parameters[param.key];
      if (value == null || value.trim().isEmpty) {
        throw ArgumentError.value(
          param.key,
          'parameters',
          'profile ${profile.id} requires this connection parameter',
        );
      }
    }

    final declaredOptionKeys = profile.options.map((o) => o.key).toSet();
    for (final suppliedKey in options.keys) {
      if (!declaredOptionKeys.contains(suppliedKey)) {
        throw ArgumentError.value(
          suppliedKey,
          'options',
          'profile ${profile.id} does not declare an option with this key',
        );
      }
    }

    for (final option in profile.options) {
      final chosen = options[option.key];
      if (chosen == null) continue; // Unset is fine — see [options] doc.
      if (!option.allowedValues.contains(chosen)) {
        throw ArgumentError.value(
          chosen,
          'options[${option.key}]',
          'profile ${profile.id} does not permit "$chosen" for option '
              '${option.key}; allowed: ${option.allowedValues}',
        );
      }
    }
  }

  /// Whether a driver built from [other] would reach the same device, over the
  /// same transport, with the same settings, as one built from this binding.
  ///
  /// Exists for one caller and one purpose: `DeviceCheckLocal` builds a driver
  /// from the binding as saved *now*, and when that binding has not changed
  /// the driver it builds points at the same endpoint the app's live driver is
  /// already holding. Some endpoints admit one client at a time — a network
  /// ESC/POS printer on port 9100, an exclusive serial port — so a second
  /// connect to the same place is refused, and the operator is told
  /// `connectionFailed` about a printer that works. This predicate is how the
  /// check knows to borrow the live driver instead of building a rival one.
  ///
  /// **What it compares is exactly what a driver builder reads**, no more:
  /// [deviceClass], [profileId], [parameters] and [options]. Every one of
  /// `hardware_module.dart`'s four `build*` functions reads some subset of
  /// those four and nothing else — `buildLabelPrinterService` is the only one
  /// that reads [options] (`paperWidthMm`, `labelHeightMm`), which is why they
  /// are compared here rather than dismissed as cosmetic: a label size changed
  /// and saved must produce a fresh driver, or the check would test the old
  /// size and re-create finding I2 one field over.
  ///
  /// [enabled] is deliberately **not** compared. No `build*` function reads
  /// it — it decides whether a binding is used at all, not where it points —
  /// and two bindings that differ only there still name the same endpoint, so
  /// forcing a second connection over that difference would be the very thing
  /// this predicate exists to avoid.
  ///
  /// If a `build*` function ever starts reading another field, it must be
  /// added here. A driver input this misses is a stale driver reused.
  bool describesSameDeviceAs(DeviceBinding other) =>
      deviceClass == other.deviceClass &&
      profileId == other.profileId &&
      _sameStringMap(parameters, other.parameters) &&
      _sameStringMap(options, other.options);

  static bool _sameStringMap(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    // Values are non-nullable `String`, so a key missing from `b` reads as
    // null and fails this comparison — equal lengths plus every entry equal
    // is genuine map equality here, no separate containsKey needed.
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}

/// The one *enabled* binding of [deviceClass] among [bindings], or `null` if
/// none exists or more than one does.
///
/// Pulled out as a small, pure, presentation-safe helper (final review
/// finding C4) so a presentation file that needs "this terminal's label
/// printer" — or any other single-binding-per-class device — does not have
/// to import `lib/data` to get it, and so more than one binding of a class
/// is refused rather than picked arbitrarily, the same rule
/// `hardware_module.dart`'s `_resolveSingleBinding` applies (docs/system-architecture.md,
/// И30: refusing to choose a device is safe, choosing the wrong one is not).
/// That function is not reused directly because it also logs through a
/// `Talker`, which this — a pure domain function with no logging
/// dependency — deliberately does not need.
DeviceBinding? singleEnabledBindingOfClass(
  List<DeviceBinding> bindings,
  DeviceClass deviceClass,
) {
  final matches = bindings
      .where((b) => b.deviceClass == deviceClass && b.enabled)
      .toList(growable: false);
  return matches.length == 1 ? matches.single : null;
}
