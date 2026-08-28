import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile.dart';

/// The contract over the device profile catalog: look up profiles by class,
/// or one profile by id.
///
/// This is a contract, not a class of constants — plan 2b adds an
/// implementation that is edited from the UI, same as И124 requires for the
/// country/rate reference data. The built-in set shipped in
/// `lib/data/device/device_profile_catalog_builtin.dart` is one
/// implementation of this contract, not the only one there will ever be.
abstract interface class DeviceProfileCatalog {
  /// Every profile available for [deviceClass]. Empty only if the class is
  /// genuinely unconfigurable, which should never happen for a built-in
  /// catalog — every `DeviceClass` needs at least one profile or a terminal
  /// cannot be set up for that kind of device at all.
  List<DeviceProfile> forClass(DeviceClass deviceClass);

  /// The profile named [id], or `null` if no such profile exists.
  ///
  /// `null` — never a fallback to some other profile — is load-bearing: a
  /// binding pointing at an id this catalog does not recognise must fail
  /// loudly (`DeviceBinding.validateAgainst`), not silently run as whatever
  /// profile happens to come first. Substituting a similar profile would
  /// produce a plausibly working device of the wrong model.
  DeviceProfile? byId(String id);
}
