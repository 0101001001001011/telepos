import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/domain/terminal/terminal_identity.dart';

/// Личность в настройках этого клиента: реестр на десктопе, localStorage в
/// браузере — одна и та же реализация, разные хранилища под ней.
class PrefsTerminalIdentity implements TerminalIdentity {
  PrefsTerminalIdentity(this._prefs);

  static const _key = 'terminal_id';

  final SharedPreferences _prefs;

  @override
  Future<int?> currentId() async => _prefs.getInt(_key);

  @override
  Future<void> remember(int terminalId) async {
    await _prefs.setInt(_key, terminalId);
  }

  @override
  Future<void> forget() async {
    await _prefs.remove(_key);
  }
}
