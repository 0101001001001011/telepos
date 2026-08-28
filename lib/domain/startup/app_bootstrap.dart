/// Progress reported while the application comes up: a fraction from 0 to 1 and
/// a line to show the operator.
typedef BootProgress = void Function(double progress, String message);

/// How far the application got before it was ready to be used.
enum AppInitStatus {
  success,

  noKey,

  absentMandatoryData,

  supportEnded,

  syncSuspended,

  authorizationFailure,

  databaseFailure,
}

/// Bringing the application up: the database, the configuration, the licence
/// and the background jobs.
///
/// The splash screen used to construct the native boot sequence itself, which
/// made the first thing drawn on screen the owner of drift, the updater and the
/// Telegram sync engine. It never needed any of that — it needed a progress
/// number and a verdict.
///
/// In a browser this resolves to the backend's own boot: that process started
/// long before the page loaded, so the implementation reports what already
/// happened rather than making it happen again.
abstract interface class AppBootstrap {
  Future<AppInitStatus> start({required BootProgress onProgress});
}
