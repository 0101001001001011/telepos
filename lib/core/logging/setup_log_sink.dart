/// Where the setup wizard's log lines end up.
///
/// The wizard is the screen most likely to be debugged over someone's shoulder,
/// so its log has to reach whoever is looking. On a till that means a file next
/// to the application; in a browser it means the console, where Playwright and
/// devtools can read it. Neither is more real than the other — see
/// docs/ARCHITECTURE.md, "Debugging".
library;

export 'setup_log_sink_native.dart'
    if (dart.library.js_interop) 'setup_log_sink_web.dart';
