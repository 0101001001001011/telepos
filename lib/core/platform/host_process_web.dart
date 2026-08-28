/// A browser cannot spawn processes or terminate the host application.
///
/// The features that reach for these — self-update, installer hand-off, the
/// single-instance check — do not exist on web, so rather than throwing, the
/// calls report failure in the shape the callers already handle. Check
/// [canRunProcesses] before offering such a feature in the UI.
library;

class HostProcessResult {
  const HostProcessResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

const _unsupported = HostProcessResult(
  exitCode: -1,
  stdout: '',
  stderr: 'Running processes is not available in a web build',
);

Future<HostProcessResult> runProcess(
  String executable,
  List<String> arguments, {
  bool runInShell = false,
  String? workingDirectory,
}) async => _unsupported;

Future<void> startDetached(
  String executable,
  List<String> arguments, {
  bool runInShell = false,
  String? workingDirectory,
}) async {}

/// Nothing to exit — closing the tab is the user's business, not ours.
void exitApp([int code = 0]) {}

bool get canRunProcesses => false;
