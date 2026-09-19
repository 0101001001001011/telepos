import 'package:sqlite3/common.dart' show SqliteException;
import 'package:telepos/core/errors/named_refusal.dart';

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
/// - [NamedRefusal] (`WireRefusal`, `WtProtocolError`): the **code** in the
///   machine-readable form `refusal(<code>): <reason>` — see
///   [namedRefusalText]. `ErrorLocalizer` reads that form back and shows the
///   cashier the dictionary phrase for the code.
/// - Anything else: the type name alone — or [unnamedErrorText] when the name
///   is not a name (see [readableTypeName]). An arbitrary exception's own
///   `toString()`/`message` is not this function's to trust — nothing here
///   guarantees some other exception type doesn't embed the same kind of
///   secret in its own message.
///
/// # Why named refusals are not a type name (live acceptance, 2026-09-13)
///
/// The till answered `WtProtocolError(debt_customer_required: …)` and the
/// cashier read «Ошибка сохранения: minified:du». In dart2js
/// `runtimeType.toString()` is the minified name, so for every named refusal
/// this function turned the one word the screen needed — the code — into
/// noise, and nothing downstream could recover it: by then the exception is
/// a string. The code is therefore kept **here**, at the only point where the
/// object still exists; translation stays in `ErrorLocalizer`, the only point
/// that has a locale.
String safeErrorText(Object error) {
  if (error is SqliteException) {
    final buffer = StringBuffer('SqliteException: ${error.message}');
    final explanation = error.explanation;
    if (explanation != null && explanation.isNotEmpty) {
      buffer.write(', $explanation');
    }
    return buffer.toString();
  }
  if (error is NamedRefusal) return namedRefusalText(error);
  return readableTypeName(error.runtimeType.toString());
}

/// What [safeErrorText] says when it cannot name the error honestly.
///
/// `ErrorLocalizer` shows it as «неизвестная причина» — not a guess.
const unnamedErrorText = 'unnamed error';

/// The shape a code must have to travel: a wire identifier, nothing else.
///
/// A code is written by the till, not by the database, but this function
/// does not take that on trust — anything that is not an identifier
/// (`x; password=…`, a sentence, an empty string) is not carried at all.
final _codeShape = RegExp(r'^[a-z][a-z0-9_]{0,63}$');

final _refusalShape = RegExp(
  r'^refusal\(([a-z][a-z0-9_]{0,63})\)(?:: ([\s\S]*))?$',
);

/// A named refusal as text: `refusal(<code>)` or `refusal(<code>): <reason>`.
///
/// The reason is carried because it is safe by construction (I144: the
/// handler writes it, not the database) and because a few dictionary phrases
/// need it — the product name in «нет на остатке». Whether it reaches the
/// screen is decided by the dictionary (`withMessage`), never here; for a code
/// the dictionary does not know, `ErrorLocalizer` shows the code alone.
String namedRefusalText(NamedRefusal refusal) {
  if (!_codeShape.hasMatch(refusal.code)) return unnamedErrorText;
  final reason = refusal.reasonText.trim();
  return reason.isEmpty
      ? 'refusal(${refusal.code})'
      : 'refusal(${refusal.code}): $reason';
}

/// The inverse of [namedRefusalText]; `null` for any other text.
({String code, String reason})? parseNamedRefusalText(String text) {
  final match = _refusalShape.firstMatch(text);
  if (match == null) return null;
  return (code: match.group(1)!, reason: match.group(2) ?? '');
}

/// A runtime type name, or [unnamedErrorText] when it is not a name.
///
/// dart2js minifies type names (`minified:dl`): on the web build the name
/// says nothing, and printing it next to «Ошибка поиска:» dresses noise as a
/// reason. Split out as a pure function so the minified case is testable on
/// the Dart VM, where names are always readable.
String readableTypeName(String raw) =>
    raw.startsWith('minified:') ? unnamedErrorText : raw;
