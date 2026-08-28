/// Где вкладка держит секрет своего терминала — задача 5 плана «знакомство
/// терминала с кассой» (шаг 2 спеки).
///
/// `localStorage`, а не `sessionStorage`: секрет обязан пережить не только
/// F5, но и закрытие вкладки/браузера — он про то, какое это устройство, а
/// не про то, кто на нём сейчас вошёл (см. докстринг `TerminalSecretStorage`,
/// `lib/domain/terminal/terminal_secret_storage.dart`, про то, почему это не
/// то же самое различие, что уже сделано для `SessionTokenStore`). Токен
/// сеанса (`SessionTokenStore`, `wt_session_token_store.dart`) хранится
/// рядом, но в другом хранилище браузера и под другими ключами — то же
/// решение, тем же приёмом, каким уже разведены токен и его срок годности
/// там.
///
/// # Почему `dart:js_interop`, а не `package:web`
///
/// Тот же довод, что и у `SessionTokenStore`: пакет не подключён в
/// `pubspec.yaml`, и заводить зависимость ради второго объекта браузера не
/// стоит — `window.localStorage` реализует ту же форму `Storage`, что и
/// `window.sessionStorage`, только под другим именем на `window`.
///
/// # Почему это отдельный файл, а не часть `wt_session_token_store.dart`
///
/// Оба файла существуют по одной и той же причине — `dart:js_interop` не
/// собирается под `flutter test` (VM), а `LoginNotifier` обязан
/// проверяться без браузера. Слить их в один файл значило бы, что тест,
/// которому нужен только один из двух двойников, тянет за собой оба.
library;

import 'dart:js_interop';

import 'package:telepos/domain/terminal/terminal_secret_storage.dart';

/// `window.localStorage` — тот же приём именованного пути, что и
/// `window.sessionStorage` в `wt_session_token_store.dart`.
@JS('window.localStorage')
external _JSStorage get _localStorage;

/// Та же структурная форма `Storage`, что и в `wt_session_token_store.dart`
/// — не второе определение одного и того же JS-класса (`extension type`
/// не заводит рантайм-тип, только структурное сопоставление на границе
/// компиляции), а копия ровно того объёма, который здесь нужен.
extension type _JSStorage._(JSObject _) implements JSObject {
  external JSString? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

class TerminalSecretStore implements TerminalSecretStorage {
  const TerminalSecretStore();

  static const _idKey = 'telepos.terminal.id';
  static const _secretKey = 'telepos.terminal.secret';

  /// Отдельные ключи, а не один JSON-объект — тот же приём, что у
  /// `SessionTokenStore`: запись, сделанная до появления второго поля (или
  /// испорченная вручную через devtools), читается как «улики нет», а не
  /// как ошибка разбора JSON.
  @override
  StoredTerminalSecret? read() {
    final idRaw = _localStorage.getItem(_idKey)?.toDart;
    final secret = _localStorage.getItem(_secretKey)?.toDart;
    if (idRaw == null || secret == null || secret.isEmpty) return null;
    final id = int.tryParse(idRaw);
    if (id == null) return null;
    return (terminalId: id, secret: secret);
  }

  @override
  void write(int terminalId, String secret) {
    _localStorage.setItem(_idKey, '$terminalId');
    _localStorage.setItem(_secretKey, secret);
  }

  @override
  void clear() {
    _localStorage.removeItem(_idKey);
    _localStorage.removeItem(_secretKey);
  }
}
