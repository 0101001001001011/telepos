/// Where this browser terminal's own enrolment secret is kept — задача 5
/// плана «знакомство терминала с кассой» (шаг 2 спеки).
///
/// # Не то же самое, что [SessionTokenStorage]
///
/// `SessionTokenStorage` (`lib/domain/auth/session_token_storage.dart`)
/// answers "who is logged in on this tab" — its real implementation
/// (`SessionTokenStore`, `lib/web/wt_session_token_store.dart`) is
/// deliberately `sessionStorage`: a token that must die with the tab, so a
/// shared kiosk tablet does not stay logged in for the next person.
///
/// This contract answers a different question — "which physical device is
/// this browser" — and the two must never share a cell or a lifetime. The
/// secret earned here is not proof of who is using the till right now; it is
/// proof of *which terminal row* this browser already is, independent of any
/// cashier session. Mixing them (same storage key, same frame, same
/// clearing point) would make a logout — which is supposed to end only the
/// session — also forget the terminal's own identity, forcing a fresh
/// `terminals.register` on the very next login and defeating the whole point
/// of task 5.
///
/// # Why survives a tab close, not just F5
///
/// [SessionTokenStorage]'s docstring explains why it must die with the tab.
/// This one is the opposite case for the opposite reason: the terminal row a
/// browser earned is the identity of the *device*, the same kind of thing
/// `TerminalIdentity` (`lib/domain/terminal/terminal_identity.dart`) already
/// persists for the desktop till across restarts via `SharedPreferences`.
/// Losing it on tab close would mean every browser terminal at a POS
/// station re-enrols itself (a fresh row, task 4's secret discarded) on
/// every page reload that happens to also close the tab — exactly the
/// accumulation task 5 exists to stop, see the `LoginNotifier`
/// (`lib/presentation/controllers/auth/login_controller.dart`) docstring at
/// `_resolveTerminalId`.
///
/// # Pure Dart on purpose
///
/// Same reason as [SessionTokenStorage]: `LoginNotifier` and its tests run
/// on the VM, and the real implementation ([TerminalSecretStore],
/// `lib/web/wt_terminal_secret_store.dart`) imports `dart:js_interop`,
/// which does not exist there. Only the browser binding registers an
/// implementation (`lib/web/main_web.dart`); a desktop process never enrols
/// itself this way (`HostCapabilities.ownsData` — `_resolveTerminalId` takes
/// the `self()` branch instead), so nothing registers this contract there,
/// and a caller checks `GetIt.isRegistered` first, the same way it already
/// does for [SessionTokenStorage].
library;

/// The secret this browser earned enrolling itself, paired with the id the
/// till gave it in the same call ([TerminalRepository.register]). Neither
/// half is useful alone: the id is visible to any session through
/// `terminals.list` and proves nothing by itself, and a secret without the
/// id it belongs to would make the till search for the row it matches
/// instead of checking one.
typedef StoredTerminalSecret = ({int terminalId, String secret});

abstract interface class TerminalSecretStorage {
  /// The secret this browser earned enrolling itself, or `null` if it has
  /// never registered (fresh browser/profile), the record was cleared, or
  /// what is stored cannot be read as a valid pair — a corrupted store reads
  /// the same as an absent one: there is nothing left to recover from either.
  StoredTerminalSecret? read();

  /// Remembers a freshly issued secret, replacing whatever was there for
  /// both fields at once — a store holding the id of one enrolment and the
  /// secret of another would prove nothing.
  void write(int terminalId, String secret);

  /// Forgets the stored secret. Idempotent: clearing an already-empty store
  /// is not an error. Called when the till has refused the stored secret —
  /// terminal deleted, secret no longer matches — so the next attempt falls
  /// through to a fresh `register()` instead of retrying the same refusal.
  void clear();
}
