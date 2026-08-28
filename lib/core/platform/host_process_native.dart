import 'dart:io' as io;

/// Result of a finished command, narrowed to what callers actually read.
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

Future<HostProcessResult> runProcess(
  String executable,
  List<String> arguments, {
  bool runInShell = false,
  String? workingDirectory,
}) async {
  final r = await io.Process.run(
    executable,
    arguments,
    runInShell: runInShell,
    workingDirectory: workingDirectory,
  );
  return HostProcessResult(
    exitCode: r.exitCode,
    stdout: r.stdout.toString(),
    stderr: r.stderr.toString(),
  );
}

/// Launches a detached command — used by the updater to hand off to an
/// installer and by the appliance tooling to restart a session.
Future<void> startDetached(
  String executable,
  List<String> arguments, {
  bool runInShell = false,
  String? workingDirectory,
}) async {
  await io.Process.start(
    executable,
    arguments,
    runInShell: runInShell,
    workingDirectory: workingDirectory,
    mode: io.ProcessStartMode.detached,
  );
}

/// Returns `void` rather than `Never` so the signature matches the web
/// stand-in, where terminating the application is not a thing that happens.
void exitApp([int code = 0]) => io.exit(code);

bool get canRunProcesses => true;
