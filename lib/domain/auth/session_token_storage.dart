/// Where the browser terminal's own session token is kept.
///
/// Pure Dart on purpose: [LoginNotifier] (`lib/presentation/controllers/auth/login_controller.dart`)
/// and its tests run on the VM, and the real implementation
/// ([SessionTokenStore], `lib/web/wt_session_token_store.dart`) imports
/// `dart:js_interop`, which does not exist there — that is the whole reason
/// the storage was split into its own file in the first place. This contract
/// is what shared code sees; only the browser binding registers an
/// implementation (`lib/web/main_web.dart`).
///
/// A desktop process never persists a token across a restart the way a
/// browser tab survives F5 — its login is per-run — so nothing registers this
/// for the desktop binding, and a caller asks `GetIt.isRegistered` before
/// reaching for one, the same way it already does for [SessionTokenStorage]'s
/// browser-only siblings (`ScannerRulesRepository` in
/// `hardware_settings_screen.dart`, `FirstLaunchRepository` in
/// `splash_screen.dart`).
abstract interface class SessionTokenStorage {
  /// The token of a session this terminal minted for itself, or `null` if
  /// there is none.
  String? read();

  /// The till-declared expiry of the token [read] would return, or `null` if
  /// there is no token, or (only possible from a store written before this
  /// field existed) a token was persisted without one.
  ///
  /// Added phase-2 fix wave, second round, task 6 (2026-08-21). Before this,
  /// only the token survived a tab reload — the expiry `[LoginNotifier]`
  /// learned when the session was minted lived in `_lastKnownExpiresAt`, an
  /// in-memory field on the notifier itself, and F5 always starts a fresh
  /// notifier. The till never hands back an expired session record (it
  /// sweeps those into `null` first, `SessionRegistry.watch`), so the most
  /// ordinary case — close the tab overnight, come back after the till has
  /// long since forgotten the session — always arrived at a fresh notifier
  /// as bare `null`, indistinguishable from an owner-revoked session, and
  /// the screen told the operator "Сеанс завершён на кассе" for something
  /// the till never did. Persisting the expiry alongside the token lets
  /// `_restoreSession` repopulate `_lastKnownExpiresAt` before the first
  /// `watchSession` event ever arrives.
  DateTime? readExpiresAt();

  /// Remembers a freshly minted token and the moment the till says it stops
  /// being valid on its own, replacing whatever was there for both.
  void write(String token, DateTime expiresAt);

  /// Forgets the token and its expiry. Idempotent: clearing an already-empty
  /// store is not an error.
  void clear();
}
