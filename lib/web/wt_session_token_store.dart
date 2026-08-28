/// Где вкладка держит токен сеанса.
///
/// `sessionStorage`, а не `localStorage`: токен обязан пережить F5 и обрыв
/// связи посреди чека, но умереть вместе со вкладкой. `localStorage` оставил
/// бы вход открытым на общем планшете до следующего человека.
///
/// # Почему `dart:js_interop`, а не `package:web`
///
/// `package:web` не подключён в `pubspec.yaml`, и заводить зависимость ради
/// одного объекта браузера не стоит. Тем же способом уже читает документ
/// `lib/web/wt_session.dart:49-65` — внешние объявления через `@JS(...)` и
/// `extension type ... implements JSObject`, без пакета.
///
/// # Почему это отдельный файл, а не часть `wt_auth_repository.dart`
///
/// `dart:js_interop` не существует на VM: файл, его импортировавший, не
/// собирается под `flutter test`. `WtAuthRepository` обязан проверяться без
/// браузера, поэтому чтение/запись токена вынесены сюда, а сам репозиторий —
/// чистый Dart поверх диспетчера.
library;

import 'dart:js_interop';

import 'package:telepos/domain/auth/session_token_storage.dart';

/// `window.sessionStorage` — вложенное глобальное свойство, а не отдельный
/// конструктор: имя в `@JS(...)` содержит путь, как `Math.PI` в примерах
/// `dart:js_interop`.
@JS('window.sessionStorage')
external _JSStorage get _sessionStorage;

/// Форма `Storage` ровно в том объёме, который здесь нужен. Структурная
/// типизация: сопоставление с настоящим `Storage` идёт по именам методов, а не
/// по декларации JS-класса, — поэтому у типа нет своего `@JS(...)`.
extension type _JSStorage._(JSObject _) implements JSObject {
  external JSString? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

class SessionTokenStore implements SessionTokenStorage {
  const SessionTokenStore();

  static const _key = 'telepos.session';

  /// Отдельный ключ, а не JSON-объект в [_key]: [read] и [readExpiresAt]
  /// независимы (см. докстринг контракта, `session_token_storage.dart`), и
  /// это сохраняет обратную совместимость с записью, положенной до задачи 6
  /// второго круга — токен без этого ключа читается как «улики нет», а не
  /// как ошибка разбора JSON.
  static const _expiresAtKey = 'telepos.session.expiresAt';

  @override
  String? read() => _sessionStorage.getItem(_key)?.toDart;

  @override
  DateTime? readExpiresAt() {
    final raw = _sessionStorage.getItem(_expiresAtKey)?.toDart;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  @override
  void write(String token, DateTime expiresAt) {
    _sessionStorage.setItem(_key, token);
    _sessionStorage.setItem(_expiresAtKey, expiresAt.toUtc().toIso8601String());
  }

  @override
  void clear() {
    _sessionStorage.removeItem(_key);
    _sessionStorage.removeItem(_expiresAtKey);
  }
}
