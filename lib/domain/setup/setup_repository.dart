import 'setup_draft.dart';

/// Committing the first-launch wizard.
///
/// The wizard used to write its own results: it resolved the database, created
/// accounts, inserted users, wrote fiscal settings into preferences, kicked off
/// the catalog import and started a sync — around 390 lines of infrastructure
/// inside a screen controller. None of that can happen in a browser, and none
/// of it was the wizard's business.
///
/// The wizard now collects a [SetupDraft] and hands it over once. Whether that
/// lands in a local database or travels to a backend over HTTP is the binding's
/// concern. See docs/ARCHITECTURE.md.
abstract interface class SetupRepository {
  /// Commits the whole draft. Throws if the till could not be configured —
  /// there is no partial success to report, because a half-configured till
  /// cannot take money.
  Future<void> completeSetup(SetupDraft draft);
}
