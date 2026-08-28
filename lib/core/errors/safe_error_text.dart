import 'package:sqlite3/common.dart' show SqliteException;

/// A description of [error] safe to show in a browser frame, write to a log,
/// or print on a setup-wizard screen — anywhere that is not the till's own
/// trusted process.
///
/// **Never call `error.toString()` for this.** `SqliteException.toString()`
/// (`package:sqlite3`, `lib/src/exception.dart`) appends
/// `causingStatement` and, right after it, `parametersToStatement` — the
/// literal values bound to the failed statement. It only masks binary
/// (`Uint8List`) parameters as `blob (N bytes)`; every text parameter is
/// printed as-is via `.toString()`. `Users.passwordEnc` is a text column
/// (`PinCredential`'s `pbkdf2$sha256$<iterations>$<salt>$<key>` string), so a
/// failing statement that touches it — `UPDATE users SET password_enc = ?`,
/// the very statement `AuthService._upgradeStoredPin` runs right after a
/// successful login — would otherwise carry the freshly hashed PIN into
/// whatever surface prints the exception.
///
/// The rule: type name plus a *cleaned* message, never the raw object.
/// - [SqliteException]: `message` and `explanation` only — never
///   `causingStatement` or `parametersToStatement`, which is exactly the pair
///   `toString()` uses to carry the parameter list.
/// - Anything else: the type name alone. An arbitrary exception's own
///   `toString()`/`message` is not this function's to trust — nothing here
///   guarantees some other exception type doesn't embed the same kind of
///   secret in its own message.
String safeErrorText(Object error) {
  if (error is SqliteException) {
    final buffer = StringBuffer('SqliteException: ${error.message}');
    final explanation = error.explanation;
    if (explanation != null && explanation.isNotEmpty) {
      buffer.write(', $explanation');
    }
    return buffer.toString();
  }
  return error.runtimeType.toString();
}
