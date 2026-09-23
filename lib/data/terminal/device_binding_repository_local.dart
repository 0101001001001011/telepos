import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:telepos/data/database/app_database.dart' as db;
import 'package:telepos/data/database/watch_source.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';

/// Drift-backed [DeviceBindingRepository] — see that interface's doc comment
/// for why this exists alongside `LocalTerminalRepository` rather than as a
/// method on it.
///
/// Reads via `TerminalDao.deviceBindingsFor` (already exists, used by
/// `resolveTerminalDeviceBindings` — `lib/data/device/terminal_device_binding_resolver.dart`).
/// This repository does **not** reuse that function directly: it filters
/// out disabled rows, which is right for `hardware_module.dart` (only
/// active devices should be registered) but wrong here — a settings screen
/// needs to redraw a disabled device's last profile/parameters so turning it
/// back on doesn't lose them.
///
/// Writes with an explicit delete-then-insert inside a transaction, the same
/// pattern `TerminalDao.ensureSelf` uses for its own race — `insert` alone
/// would violate `TerminalDeviceBindings`'s unique key
/// `(terminalId, deviceClass, bindingKey)` on a second save for the same
/// class, and a naive `insertOnConflictUpdate()` targets the table's
/// *primary* key (`id`, autoincrement, never supplied here), not this
/// composite unique constraint. [bindingKey] is always the device class's
/// own name — never the profile id — so that switching a terminal's profile
/// for a class still collides with, and replaces, the previous row instead
/// of adding a sibling one; the migration's per-model `bindingKey` scheme
/// (`lib/data/database/migrations/device_binding_migration.dart`) is for a
/// terminal that may have two bindings of the same class (two label
/// printers), which this simple one-binding-per-class settings UI does not
/// attempt to manage.
class LocalDeviceBindingRepository implements DeviceBindingRepository {
  LocalDeviceBindingRepository(this._db, this._catalog);

  final db.AppDatabase _db;
  final DeviceProfileCatalog _catalog;

  @override
  Future<List<DeviceBinding>> forTerminal(int terminalId) async =>
      _toDomain(await _db.terminalDao.deviceBindingsFor(terminalId));

  /// Читает тем же [forTerminal] — см. `lib/data/database/watch_source.dart`.
  ///
  /// Сигнал приходит на **любую** запись в `TerminalDeviceBindings`, включая
  /// чужого терминала: drift будит по таблице, а не по строке. Значение при
  /// этом всегда верное — читает тот же `where`, — и кадр, в котором ничего не
  /// поменялось, дешевле, чем список того, что кого касается.
  @override
  Stream<List<DeviceBinding>> watchForTerminal(int terminalId) => watchTables(
    _db,
    [_db.terminalDeviceBindings],
    () => forTerminal(terminalId),
  );

  /// Один разбор строк на оба чтения. Второй его копией начиналось бы ровно то
  /// расхождение, ради которого разбор привязки уже сведён в один файл
  /// (`terminal_wire.dart`).
  List<DeviceBinding> _toDomain(List<db.TerminalDeviceBinding> rows) {
    final result = <DeviceBinding>[];
    for (final row in rows) {
      final deviceClass = _classFromStored(row.deviceClass);
      if (deviceClass == null)
        continue; // Written by a newer build; don't guess.
      result.add(
        DeviceBinding(
          deviceClass: deviceClass,
          profileId: row.profileId,
          parameters: _decodeMap(row.parametersJson),
          options: _decodeMap(row.optionsJson),
          enabled: row.enabled,
        ),
      );
    }
    return result;
  }

  @override
  Future<void> save(int terminalId, DeviceBinding binding) async {
    // Throws ArgumentError before anything is written — a partially-valid
    // binding must never reach the table (see interface doc comment).
    binding.validateAgainst(_catalog);

    await _db.transaction(() async {
      await (_db.delete(_db.terminalDeviceBindings)..where(
            (b) =>
                b.terminalId.equals(terminalId) &
                b.deviceClass.equals(binding.deviceClass.name),
          ))
          .go();

      await _db
          .into(_db.terminalDeviceBindings)
          .insert(
            db.TerminalDeviceBindingsCompanion.insert(
              terminalId: terminalId,
              deviceClass: binding.deviceClass.name,
              profileId: binding.profileId,
              bindingKey: binding.deviceClass.name,
              parametersJson: Value(jsonEncode(binding.parameters)),
              optionsJson: Value(jsonEncode(binding.options)),
              enabled: Value(binding.enabled),
            ),
          );
    });
  }

  DeviceClass? _classFromStored(String stored) {
    for (final value in DeviceClass.values) {
      if (value.name == stored) return value;
    }
    return null;
  }

  Map<String, String> _decodeMap(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', '$value'));
      }
    } catch (_) {
      // Malformed JSON is treated as "nothing supplied" — the same rule
      // `resolveTerminalDeviceBindings` applies to the same columns.
    }
    return const {};
  }
}
