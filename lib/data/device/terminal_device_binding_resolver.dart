/// Decodes `TerminalDeviceBindings` rows into domain `DeviceBinding`s and
/// validates each against a catalog.
///
/// `TerminalDao.deviceBindingsFor` (`lib/data/database/daos/terminal_dao.dart`)
/// deliberately returns raw drift rows and says so in its doc comment:
/// "decoding parametersJson/optionsJson and picking a catalog to validate
/// against is the assembling side's job (plan 2, task 3), not the DAO's."
/// This file is that job, factored out of `lib/app/di/hardware_module.dart`
/// so the two other production readers of a terminal's device bindings
/// (`lib/presentation/controllers/payment/payment_controller.dart` for the
/// Kaspi payment terminal, `lib/presentation/common/mixins/barcode_scanner_mixin.dart`
/// for the scanner) do not each re-implement row decoding and validation.
library;

import 'dart:convert';

import 'package:telepos/data/database/app_database.dart' as db;
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/terminal/device_binding.dart';

/// Every *enabled and valid* binding on terminal [terminalId], optionally
/// narrowed to [deviceClass].
///
/// A row that fails [DeviceBinding.validateAgainst] — an unknown profile id,
/// a missing required parameter, an option value the profile does not
/// permit — is skipped rather than thrown: one malformed row must not stop
/// every other device on the terminal from resolving. This mirrors why a
/// device failure must never block a sale (И30, docs/system-architecture.md,
/// section 8) extended to configuration errors, not just hardware failures.
/// A disabled row (`enabled = false`) is skipped for the same reason a
/// missing row is — the operator turned it off on purpose.
Future<List<DeviceBinding>> resolveTerminalDeviceBindings({
  required db.AppDatabase database,
  required int terminalId,
  required DeviceProfileCatalog catalog,
  DeviceClass? deviceClass,
}) async {
  final rows = await database.terminalDao.deviceBindingsFor(terminalId);
  final result = <DeviceBinding>[];

  for (final row in rows) {
    if (!row.enabled) continue;

    final rowClass = _deviceClassFromStored(row.deviceClass);
    if (rowClass == null) continue; // Written by a newer build; don't guess.
    if (deviceClass != null && rowClass != deviceClass) continue;

    final binding = DeviceBinding(
      deviceClass: rowClass,
      profileId: row.profileId,
      parameters: _decodeStringMap(row.parametersJson),
      options: _decodeStringMap(row.optionsJson),
      enabled: row.enabled,
    );

    try {
      binding.validateAgainst(catalog);
    } on ArgumentError {
      continue;
    }

    result.add(binding);
  }

  return result;
}

/// Matches [stored] against `DeviceClass.values` by name, the same rule the
/// rest of this codebase applies to every enum stored in the database
/// (`lib/data/terminal/terminal_repository_local.dart`'s
/// `_enumFromStored`/`_pointModeFromStored`): an unrecognised name means a
/// newer build wrote this row, and guessing which class it "must" be would
/// risk resolving the wrong device. `null` here is silently skipped by the
/// caller rather than thrown, because one unrecognised row must not stop
/// every other binding on the terminal from resolving.
DeviceClass? _deviceClassFromStored(String stored) {
  for (final value in DeviceClass.values) {
    if (value.name == stored) return value;
  }
  return null;
}

Map<String, String> _decodeStringMap(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry('$key', '$value'));
    }
  } catch (_) {
    // Malformed JSON is treated as "nothing supplied" — validateAgainst then
    // refuses the binding for whatever required parameter is missing,
    // instead of this function throwing on behalf of one bad row.
  }
  return const {};
}
